class_name TileInfo
extends RefCounted
## One structure on the grid (wall, mirror, lever, door...).
## Treated as immutable: switch state lives in GameState.toggled / GameState.held.

var kind: int = 0
## LEVER / WALL_BUTTON: the direction the face points, i.e. out of the wall into the room.
var dir := Vector2i.ZERO
## Channel shared by levers, buttons and doors.
var id := 0


static func make(k: int, d: Vector2i = Vector2i.ZERO, i: int = 0) -> TileInfo:
	var t := TileInfo.new()
	t.kind = k
	t.dir = d
	t.id = i
	return t


func clone() -> TileInfo:
	return TileInfo.make(kind, dir, id)
