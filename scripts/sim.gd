class_name Sim
extends RefCounted
## Pure game logic: no nodes, no drawing. step() advances a GameState by one tick.
##
## Tick order:
##   1. Slide phase: boxes and the player that are on ice move one more tile.
##   2. Every ball acts once, in spawn order (move / bounce / hit / split / pop).
##   3. Floor buttons are re-evaluated, then the goal is checked.
## Sliding happens first so that nothing ever moves more than one tile per tick from ice alone.

const ALL_DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
]


## True when nothing is moving, so waiting would change nothing.
static func is_idle(s: GameState) -> bool:
	if not s.balls.is_empty() or s.player_slide != Vector2i.ZERO:
		return false
	for b: Box in s.boxes:
		if b.slide != Vector2i.ZERO:
			return false
	return true


static func step(s: GameState) -> Dictionary:
	var start := s.player_pos

	_slide_phase(s)

	var survivors: Array[Ball] = []
	var spawned: Array[Ball] = []
	for ball: Ball in s.balls:
		if not _step_ball(s, ball, spawned):
			survivors.append(ball)
	survivors.append_array(spawned)
	s.balls = survivors

	_update_buttons(s)

	if not s.dead and s.tile_kind_at(s.player_pos) == GameState.Kind.GOAL:
		s.won = true

	return {
		"player_moved": s.player_pos != start,
		"dead": s.dead,
		"won": s.won,
	}


# ---------------------------------------------------------------- sliding

static func _slide_phase(s: GameState) -> void:
	for box: Box in s.boxes.duplicate():
		if box.slide == Vector2i.ZERO:
			continue
		var d: Vector2i = box.slide
		if not push_box(s, box, d):
			box.slide = Vector2i.ZERO
	if s.player_slide != Vector2i.ZERO:
		if not move_player(s, s.player_slide, 1):
			s.player_slide = Vector2i.ZERO


# ---------------------------------------------------------------- balls

## Returns true if the ball should be removed.
static func _step_ball(s: GameState, ball: Ball, spawned: Array[Ball]) -> bool:
	ball.lifetime -= 1
	if ball.lifetime < 0:
		return true

	var target: Vector2i = ball.pos + ball.dir

	# 1. The player is in the way: the ball hits them.
	if target == s.player_pos:
		return _hit_player(s, ball)

	# 2. A box is in the way: push it, then react according to the box kind.
	var box: Box = s.box_at(target)
	if box != null:
		var response: int = Box.KINDS[box.kind]["response"]
		push_box_n(s, box, ball.dir, ball.power)
		match response:
			Box.Response.BOUNCE:
				ball.dir = -ball.dir
				return _after_bounce(s, ball)
			Box.Response.STOP:
				if ball.refund:
					s.inventory[ball.kind] = s.inventory.get(ball.kind, 0) + 1
				return true
			_:
				return true  # VANISH

	# 3. Edge of the map acts like a wall.
	if not s.in_bounds(target):
		ball.dir = -ball.dir
		return _after_bounce(s, ball)

	# 4. Tiles.
	var t: TileInfo = s.tiles.get(target)
	if t == null:
		return _move_ball(s, ball, target)

	match t.kind:
		GameState.Kind.WALL, GameState.Kind.LEVER:
			ball.dir = -ball.dir
			return _after_bounce(s, ball)

		GameState.Kind.WALL_BUTTON:
			# Only counts if the ball flies into the face of the button.
			if ball.dir == -t.dir:
				s.toggled[t.id] = not s.toggled.get(t.id, false)
			ball.dir = -ball.dir
			return _after_bounce(s, ball)

		GameState.Kind.DOOR:
			if s.is_open(t.id):
				return _move_ball(s, ball, target)
			ball.dir = -ball.dir
			return _after_bounce(s, ball)

		GameState.Kind.PISTON:
			ball.power = 2
			ball.dir = -ball.dir
			return _after_bounce(s, ball)

		GameState.Kind.SPIKES:
			return true  # popped, not refunded

		GameState.Kind.MIRROR_SLASH:
			# "/" : right->up, up->right, left->down, down->left
			ball.pos = target
			ball.dir = Vector2i(-ball.dir.y, -ball.dir.x)
			_check_levers(s, ball)
			return false

		GameState.Kind.MIRROR_BACK:
			# "\" : right->down, down->right, left->up, up->left
			ball.pos = target
			ball.dir = Vector2i(ball.dir.y, ball.dir.x)
			_check_levers(s, ball)
			return false

		GameState.Kind.SPLITTER:
			# Right -> one ball up, one ball down (perpendicular, moving apart).
			ball.pos = target
			var d := ball.dir
			ball.dir = Vector2i(d.y, d.x)
			var twin := ball.clone()
			twin.dir = Vector2i(-d.y, -d.x)
			twin.refund = false
			spawned.append(twin)
			return false

		_:
			# Floor buttons, goal tile: balls fly straight over them.
			return _move_ball(s, ball, target)


static func _move_ball(s: GameState, ball: Ball, target: Vector2i) -> bool:
	ball.pos = target
	_check_levers(s, ball)
	return false


## A ball that bounced in place on the player's own tile hits the player
## (e.g. shooting into an adjacent wall).
static func _after_bounce(s: GameState, ball: Ball) -> bool:
	if ball.pos == s.player_pos:
		return _hit_player(s, ball)
	return false


static func _hit_player(s: GameState, ball: Ball) -> bool:
	var dmg: int = Ball.KINDS[ball.kind]["damage"]
	if dmg > 0:
		s.health -= dmg
		if s.health <= 0:
			s.dead = true
	if ball.refund:
		s.inventory[ball.kind] = s.inventory.get(ball.kind, 0) + 1
	if not s.dead:
		move_player(s, ball.dir, ball.power)
	return true


## A lever is on a wall and faces one open tile. It flips when a ball enters that tile
## travelling along the wall (perpendicular to the lever's facing).
static func _check_levers(s: GameState, ball: Ball) -> void:
	for o: Vector2i in ALL_DIRS:
		var t: TileInfo = s.tiles.get(ball.pos + o)
		if t == null or t.kind != GameState.Kind.LEVER:
			continue
		if t.dir != -o:
			continue
		if ball.dir.x * o.x + ball.dir.y * o.y != 0:
			continue
		s.toggled[t.id] = not s.toggled.get(t.id, false)


# ---------------------------------------------------------------- movement

## Moves the player up to `steps` tiles, one at a time, stopping at the first obstacle.
## Returns true if they moved at all. Sets player_slide when they end on ice.
static func move_player(s: GameState, dir: Vector2i, steps: int) -> bool:
	var moved := false
	for i in steps:
		var dest: Vector2i = s.player_pos + dir
		if not s.in_bounds(dest) or s.blocks_movement(dest) or s.box_at(dest) != null:
			break
		s.player_pos = dest
		moved = true
		if s.floor_at(dest) == GameState.Floor.WATER:
			s.dead = true  # drowned
			break
	if moved and s.floor_at(s.player_pos) == GameState.Floor.ICE:
		s.player_slide = dir
	else:
		s.player_slide = Vector2i.ZERO
	return moved


## Pushes a box one tile. Returns true if it moved or was consumed.
static func push_box(s: GameState, box: Box, dir: Vector2i) -> bool:
	var dest: Vector2i = box.pos + dir
	if not s.in_bounds(dest) or s.blocks_movement(dest) or dest == s.player_pos:
		return false

	var other: Box = s.box_at(dest)
	if other != null:
		var effect: String = Box.COMBOS.get("%s>%s" % [box.kind, other.kind], "blocked")
		match effect:
			"chain":
				if not push_box(s, other, dir):
					return false
			"destroy_target":
				s.boxes.erase(other)
			"destroy_both":
				s.boxes.erase(other)
				s.boxes.erase(box)
				return true
			_:
				return false

	if s.floor_at(dest) == GameState.Floor.WATER:
		s.floors[dest] = GameState.Floor.LAND   # the box fills the water and is used up
		s.boxes.erase(box)
		return true

	box.pos = dest
	box.slide = dir if s.floor_at(dest) == GameState.Floor.ICE else Vector2i.ZERO
	return true


static func push_box_n(s: GameState, box: Box, dir: Vector2i, steps: int) -> bool:
	var moved := false
	for i in steps:
		if not s.boxes.has(box):
			break
		if push_box(s, box, dir):
			moved = true
		else:
			break
	return moved


# ---------------------------------------------------------------- buttons

static func _update_buttons(s: GameState) -> void:
	s.held.clear()
	for p: Vector2i in s.tiles:
		var t: TileInfo = s.tiles[p]
		if t.kind == GameState.Kind.FLOOR_BUTTON and s.box_at(p) != null:
			s.held[t.id] = true
