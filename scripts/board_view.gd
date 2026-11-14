class_name BoardView
extends Node2D
## Draws a GameState. Uses res://art/<name>.png when present, otherwise simple shapes.

@export var tick_time := 0.15   # seconds per cell; bigger = slower
const BALL_R := 0.16            # ball radius in cells

var _ghosts: Array = []   # balls removed this tick, drawn finishing their move

const TILE_SPRITES := {
	GameState.Kind.WALL: "wall",
	GameState.Kind.SPIKES: "spikes",
	GameState.Kind.PISTON: "piston",
	GameState.Kind.SPLITTER: "splitter",
	GameState.Kind.GOAL: "goal",
	GameState.Kind.MIRROR_SLASH: "mirror_slash",
	GameState.Kind.MIRROR_BACK: "mirror_back",
}

var state: GameState
var cell := 48

var _from := {}
var _to := {}
var _fromdir := {}
var _todir := {}
var _t := 1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


# ---------------------------------------------------------------- state / animation

func set_state(s: GameState, cell_size: int, animate := false, start_t := 0.0) -> void:
	state = s
	cell = cell_size
	_ghosts.clear()
	if animate:
		for key in _to:
			if key is Ball and not s.balls.has(key):
				_ghosts.append({
					"from": _to[key],
					"dir": _todir.get(key, Vector2(key.dir)),
					"kind": key.kind,
				})
	_from = _to
	_fromdir = _todir
	_to = {"player": Vector2(s.player_pos)}
	_todir = {}
	for b: Box in s.boxes:
		_to[b] = Vector2(b.pos)
	for ball: Ball in s.balls:
		_to[ball] = Vector2(ball.pos)
		_todir[ball] = Vector2(ball.dir)
		# Freshly shot ball: start on the player instead of popping in one cell away
		if animate and not _from.has(ball):
			var origin := Vector2(ball.pos - ball.dir)
			if origin == _from.get("player", Vector2(-1, -1)):
				_from[ball] = origin
				_fromdir[ball] = Vector2(ball.dir)
	if animate:
		_t = start_t
	else:
		_t = 1.0
		_from = _to
		_fromdir = _todir
	queue_redraw()


func _process(delta: float) -> void:
	if _t < 1.0:
		_t = minf(1.0, _t + delta / tick_time)
		queue_redraw()

func _vp(key: Variant) -> Vector2:
	if not _to.has(key):
		return Vector2(key.pos) if key is Object else Vector2.ZERO
	var to: Vector2 = _to[key]
	return Vector2(_from.get(key, to)).lerp(to, _t)


## A bounce in place is drawn as: travel out to touch the wall, come back.
func _ball_vp(ball: Ball) -> Vector2:
	if not _to.has(ball):
		return Vector2(ball.pos)   # just shot, sits on the player until the next tick
	var to: Vector2 = _to[ball]
	var from: Vector2 = _from.get(ball, to)
	var fd: Vector2 = _fromdir.get(ball, Vector2(ball.dir))
	if from == to and fd == -Vector2(ball.dir):
		var reach := 0.5 - BALL_R
		return to + fd * reach * (1.0 - absf(2.0 * _t - 1.0))
	return from.lerp(to, _t)

func _center(v: Vector2) -> Vector2:
	return (v + Vector2(0.5, 0.5)) * cell


func _cell_rect(p: Vector2i) -> Rect2:
	return Rect2(Vector2(p) * cell, Vector2(cell, cell))


# ---------------------------------------------------------------- sprites

func _spr(sprite_name: String, center: Vector2, size: float, rot := 0.0) -> bool:
	var tex := Sprites.tex(sprite_name)
	if tex == null:
		return false
	draw_set_transform(center, rot)
	draw_texture_rect(tex, Rect2(Vector2(-size, -size) / 2.0, Vector2(size, size)), false)
	draw_set_transform(Vector2.ZERO, 0.0)
	return true


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if state == null:
		return
	for y in state.height:
		for x in state.width:
			_draw_floor(Vector2i(x, y))
	for p: Vector2i in state.tiles:
		_draw_tile(p, state.tiles[p])
	for b: Box in state.boxes:
		_draw_box(b)
	for ball: Ball in state.balls:
		_draw_ball(ball)
	for g in _ghosts:
		var gc := _center(Vector2(g["from"]).lerp(Vector2(g["from"]) + Vector2(g["dir"]), _t))
		if not _spr("ball_" + g["kind"], gc, cell * BALL_R * 2.0):
			draw_circle(gc, cell * BALL_R, Ball.KINDS[g["kind"]]["color"])
	_draw_player()


func _label(r: Rect2, text: String) -> void:
	draw_string(ThemeDB.fallback_font, r.position + Vector2(0, cell * 0.66), text,
		HORIZONTAL_ALIGNMENT_CENTER, cell, 22, Color.WHITE)


func _draw_floor(p: Vector2i) -> void:
	var r := _cell_rect(p)
	var sprite_name: String = {
		GameState.Floor.WATER: "water",
		GameState.Floor.ICE: "ice",
	}.get(state.floor_at(p), "floor")
	if _spr(sprite_name, r.get_center(), cell):
		return
	var color := Color(0.16, 0.18, 0.22)
	match state.floor_at(p):
		GameState.Floor.WATER:
			color = Color(0.10, 0.30, 0.60)
		GameState.Floor.ICE:
			color = Color(0.60, 0.85, 0.95)
	draw_rect(r, color)
	draw_rect(r, Color(0, 0, 0, 0.25), false, 1.0)


func _draw_tile(p: Vector2i, t: TileInfo) -> void:
	var r := _cell_rect(p)
	var c := r.get_center()

	# sprite path
	match t.kind:
		GameState.Kind.FLOOR_BUTTON:
			if _spr("floor_button_on" if state.held.get(t.id, false) else "floor_button", c, cell):
				return
		GameState.Kind.DOOR:
			if _spr("door_open" if state.is_open(t.id) else "door_closed", c, cell):
				return
		GameState.Kind.WALL_BUTTON, GameState.Kind.LEVER:
			var base := "wall_button" if t.kind == GameState.Kind.WALL_BUTTON else "lever"
			var is_on: bool = state.toggled.get(t.id, false)
			if _spr(base + ("_on" if is_on else ""), c, cell, Vector2(t.dir).angle() + PI / 2.0):
				return
		_:
			if TILE_SPRITES.has(t.kind) and _spr(TILE_SPRITES[t.kind], c, cell):
				return

	# shape fallback
	var wall_color := Color(0.30, 0.30, 0.35)
	match t.kind:
		GameState.Kind.WALL:
			draw_rect(r, wall_color)

		GameState.Kind.MIRROR_SLASH:
			draw_line(r.position + Vector2(4, cell - 4), r.position + Vector2(cell - 4, 4), Color.CYAN, 5.0)

		GameState.Kind.MIRROR_BACK:
			draw_line(r.position + Vector2(4, 4), r.position + Vector2(cell - 4, cell - 4), Color.CYAN, 5.0)

		GameState.Kind.SPIKES:
			var w := cell / 3.0
			for i in 3:
				var x0 := r.position.x + i * w
				draw_colored_polygon(PackedVector2Array([
					Vector2(x0, r.end.y - 4),
					Vector2(x0 + w, r.end.y - 4),
					Vector2(x0 + w / 2.0, r.position.y + 6),
				]), Color(0.85, 0.20, 0.20))

		GameState.Kind.PISTON:
			draw_rect(r.grow(-4), Color(0.90, 0.60, 0.15))
			_label(r, "P")

		GameState.Kind.SPLITTER:
			var h := cell * 0.38
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0),
			]), Color(0.65, 0.35, 0.85))

		GameState.Kind.FLOOR_BUTTON:
			var pressed: bool = state.held.get(t.id, false)
			draw_rect(r.grow(-12), Color(0.3, 0.85, 0.4) if pressed else Color(0.5, 0.5, 0.55))

		GameState.Kind.WALL_BUTTON, GameState.Kind.LEVER:
			draw_rect(r, wall_color)
			var on: bool = state.toggled.get(t.id, false)
			var at := c + Vector2(t.dir) * (cell * 0.5 - 7.0)
			if t.kind == GameState.Kind.LEVER:
				draw_circle(at, 7.0, Color.YELLOW if on else Color(0.55, 0.50, 0.20))
			else:
				draw_rect(Rect2(at - Vector2(7, 7), Vector2(14, 14)),
					Color(0.3, 0.9, 0.4) if on else Color(0.9, 0.3, 0.3))

		GameState.Kind.DOOR:
			var brown := Color(0.55, 0.35, 0.20)
			if state.is_open(t.id):
				draw_rect(r.grow(-3), brown, false, 2.0)
			else:
				draw_rect(r.grow(-3), brown)

		GameState.Kind.GOAL:
			draw_arc(c, cell * 0.30, 0.0, TAU, 24, Color.GOLD, 4.0)


func _draw_box(b: Box) -> void:
	if _spr("box_" + b.kind, _center(_vp(b)), cell - 4):
		return
	var col: Color = Box.KINDS[b.kind]["color"]
	var r := Rect2(_vp(b) * cell, Vector2(cell, cell)).grow(-6)
	draw_rect(r, col)
	draw_rect(r, Color(0, 0, 0, 0.5), false, 2.0)


func _draw_ball(ball: Ball) -> void:
	var c := _center(_ball_vp(ball))
	if not _spr("ball_" + ball.kind, c, cell * BALL_R * 2.0):
		var col: Color = Ball.KINDS[ball.kind]["color"]
		draw_circle(c, cell * BALL_R, col)
	if ball.power > 1:
		draw_arc(c, cell * 0.22, 0.0, TAU, 16, Color.ORANGE, 2.0)


func _draw_player() -> void:
	var c := _center(_vp("player"))
	if _spr("player_dead" if state.dead else "player", c, cell - 4):
		return
	draw_circle(c, cell * 0.32, Color(0.85, 0.2, 0.2) if state.dead else Color(0.25, 0.55, 0.95))
	draw_arc(c, cell * 0.32, 0.0, TAU, 24, Color.WHITE, 2.0)
