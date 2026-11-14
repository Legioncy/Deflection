class_name BoardView
extends Node2D
## Draws a GameState with simple shapes, so the game runs with zero art assets.
## Swap the _draw_* helpers for Sprite2D / TileMapLayer rendering later; the logic never touches this.

var state: GameState
var cell := 48


func set_state(s: GameState, cell_size: int) -> void:
	state = s
	cell = cell_size
	queue_redraw()


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
	_draw_player()


func _cell_rect(p: Vector2i) -> Rect2:
	return Rect2(Vector2(p) * cell, Vector2(cell, cell))


func _label(r: Rect2, text: String) -> void:
	draw_string(ThemeDB.fallback_font, r.position + Vector2(0, cell * 0.66), text,
		HORIZONTAL_ALIGNMENT_CENTER, cell, 22, Color.WHITE)


func _draw_floor(p: Vector2i) -> void:
	var r := _cell_rect(p)
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
	var col: Color = Box.KINDS[b.kind]["color"]
	var r := _cell_rect(b.pos).grow(-6)
	draw_rect(r, col)
	draw_rect(r, Color(0, 0, 0, 0.5), false, 2.0)


func _draw_ball(ball: Ball) -> void:
	var col: Color = Ball.KINDS[ball.kind]["color"]
	var c := _cell_rect(ball.pos).get_center()
	draw_circle(c, cell * 0.16, col)
	draw_line(c, c + Vector2(ball.dir) * cell * 0.30, col, 2.0)
	if ball.power > 1:
		draw_arc(c, cell * 0.22, 0.0, TAU, 16, Color.ORANGE, 2.0)


func _draw_player() -> void:
	var c := _cell_rect(state.player_pos).get_center()
	draw_circle(c, cell * 0.32, Color(0.85, 0.2, 0.2) if state.dead else Color(0.25, 0.55, 0.95))
	draw_arc(c, cell * 0.32, 0.0, TAU, 24, Color.WHITE, 2.0)
