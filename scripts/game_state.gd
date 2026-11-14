class_name GameState
extends RefCounted
## Everything that changes during a level. clone() makes a full copy, which is what undo uses.

enum Floor { LAND, WATER, ICE }
enum Kind {
	WALL, MIRROR_SLASH, MIRROR_BACK, SPIKES, PISTON, SPLITTER,
	FLOOR_BUTTON, WALL_BUTTON, LEVER, DOOR, GOAL,
}

var width := 0
var height := 0

var floors: Dictionary = {}   # Vector2i -> Floor
var tiles: Dictionary = {}    # Vector2i -> TileInfo
var boxes: Array[Box] = []
var balls: Array[Ball] = []

var player_pos := Vector2i.ZERO
var player_slide := Vector2i.ZERO   # non-zero while sliding on ice
var health := 3
var max_health := 3

var inventory: Dictionary = {}   # ball kind (String) -> count
var toggled: Dictionary = {}     # channel id -> bool, flipped by levers and wall buttons
var held: Dictionary = {}        # channel id -> bool, true while a box sits on a floor button

var dead := false
var won := false


func clone() -> GameState:
	var c := GameState.new()
	c.width = width
	c.height = height
	c.floors = floors.duplicate()
	for p: Vector2i in tiles:
		c.tiles[p] = (tiles[p] as TileInfo).clone()
	for b: Box in boxes:
		c.boxes.append(b.clone())
	for b: Ball in balls:
		c.balls.append(b.clone())
	c.player_pos = player_pos
	c.player_slide = player_slide
	c.health = health
	c.max_health = max_health
	c.inventory = inventory.duplicate()
	c.toggled = toggled.duplicate()
	c.held = held.duplicate()
	c.dead = dead
	c.won = won
	return c


func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < width and p.y < height


func floor_at(p: Vector2i) -> int:
	return floors.get(p, Floor.LAND)


func tile_at(p: Vector2i) -> TileInfo:
	return tiles.get(p)


func tile_kind_at(p: Vector2i) -> int:
	var t: TileInfo = tiles.get(p)
	return t.kind if t != null else -1


func box_at(p: Vector2i) -> Box:
	for b: Box in boxes:
		if b.pos == p:
			return b
	return null


func is_open(id: int) -> bool:
	return toggled.get(id, false) or held.get(id, false)


## True if the player and boxes can't enter this tile.
func blocks_movement(p: Vector2i) -> bool:
	var t: TileInfo = tiles.get(p)
	if t == null:
		return false
	match t.kind:
		Kind.FLOOR_BUTTON, Kind.GOAL:
			return false
		Kind.DOOR:
			return not is_open(t.id)
		_:
			return true
