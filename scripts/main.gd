extends Node2D
## Turn controller. Every player action (shoot or wait) runs exactly one Sim tick.
##
## Undo checkpoints are taken:
##   - right before the player shoots (if anything changed since the last checkpoint)
##   - right after any tick in which the player moved (ball hit OR an ice slide step)
## so each ice step is its own undo step.

const CELL := 48

const SHOOT_ACTIONS := {
	"shoot_up": Vector2i(0, -1),
	"shoot_down": Vector2i(0, 1),
	"shoot_left": Vector2i(-1, 0),
	"shoot_right": Vector2i(1, 0),
}

@onready var board: BoardView = $Board
@onready var hud: Hud = $HUD

var level_index := 0
var state: GameState
var history: Array[GameState] = []
var dirty := false   # true if `state` has changed since the newest checkpoint
var selected_kind := "normal"


func _ready() -> void:
	_register_inputs()
	_load_level(0)


# ---------------------------------------------------------------- input

func _register_inputs() -> void:
	_bind("shoot_up", [KEY_UP, KEY_W])
	_bind("shoot_down", [KEY_DOWN, KEY_S])
	_bind("shoot_left", [KEY_LEFT, KEY_A])
	_bind("shoot_right", [KEY_RIGHT, KEY_D])
	_bind("wait", [KEY_SPACE])
	_bind("undo", [KEY_U])
	_bind("restart", [KEY_R])
	_bind("ball_next", [KEY_E])
	_bind("ball_prev", [KEY_Q])


func _bind(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k as Key
		InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		_load_level(level_index)
		return
	if event.is_action_pressed("undo"):
		_undo()
		return
	if event.is_action_pressed("ball_next"):
		_cycle_ball(1)
		return
	if event.is_action_pressed("ball_prev"):
		_cycle_ball(-1)
		return

	if state.won:
		if event.is_action_pressed("wait"):
			_load_level(level_index + 1)
		return
	if state.dead:
		return

	for action: String in SHOOT_ACTIONS:
		if event.is_action_pressed(action):
			_shoot(SHOOT_ACTIONS[action])
			return
	if event.is_action_pressed("wait"):
		_wait()


# ---------------------------------------------------------------- turns

func _shoot(dir: Vector2i) -> void:
	if state.inventory.get(selected_kind, 0) <= 0:
		_refresh("No %s balls left" % selected_kind)
		return
	_checkpoint()
	state.inventory[selected_kind] -= 1
	var b := Ball.new()
	b.kind = selected_kind
	b.pos = state.player_pos
	b.dir = dir
	state.balls.append(b)
	_advance()


func _wait() -> void:
	if Sim.is_idle(state):
		return
	_advance()


func _advance() -> void:
	var result: Dictionary = Sim.step(state)
	dirty = true
	if result["player_moved"] and not state.dead and not state.won:
		_checkpoint()
	_refresh()


# ---------------------------------------------------------------- undo / restart

func _checkpoint() -> void:
	if dirty:
		history.push_back(state.clone())
		dirty = false


func _undo() -> void:
	# If nothing changed since the newest checkpoint, that checkpoint IS the current state,
	# so drop it and go back one more.
	if not dirty and history.size() > 1:
		history.pop_back()
	state = history.back().clone()
	dirty = false
	_refresh()


func _load_level(index: int) -> void:
	level_index = index % LevelData.LEVELS.size()
	state = LevelData.build(level_index)
	history.clear()
	history.append(state.clone())
	dirty = false
	selected_kind = state.inventory.keys()[0]
	board.position = (get_viewport_rect().size - Vector2(state.width, state.height) * CELL) / 2.0
	_refresh()


# ---------------------------------------------------------------- ball selection / UI

func _cycle_ball(step: int) -> void:
	var kinds: Array = state.inventory.keys()
	if kinds.is_empty():
		return
	var i := kinds.find(selected_kind)
	selected_kind = kinds[(i + step + kinds.size()) % kinds.size()]
	_refresh()


func _refresh(note: String = "") -> void:
	board.set_state(state, CELL)
	var msg := note
	if state.won:
		msg = "Level complete! Press Space for the next level."
	elif state.dead:
		msg = "Dead. Z to undo, R to restart."
	elif msg == "" and _out_of_balls() and Sim.is_idle(state):
		msg = "No balls left. Z to undo, R to restart."
	var level_name: String = LevelData.LEVELS[level_index]["name"]
	hud.show_state(state, level_name, selected_kind, msg)


func _out_of_balls() -> bool:
	if not state.balls.is_empty():
		return false
	for k: String in state.inventory:
		if state.inventory[k] > 0:
			return false
	return true
