extends RefCounted
## Levels are ASCII maps plus an optional "extras" list for tiles that need parameters.
##
## Map legend:
##   #  wall             .  land             ~  water            *  ice floor
##   @  player start     G  goal
##   r  rubber box (ball bounces)   s  sticky box (ball drops)   v  void box (ball vanishes)
##   /  mirror "/"       |  mirror "\"       ^  spikes           p  piston        %  splitter
##
## Extras (tiles with a direction and/or channel id):
##   {"kind": "lever",        "pos": Vector2i(x, y), "dir": Vector2i(0, 1), "id": 0}
##   {"kind": "wall_button",  "pos": ..., "dir": <direction the face points, out of the wall>, "id": 0}
##   {"kind": "floor_button", "pos": ..., "id": 0}
##   {"kind": "door",         "pos": ..., "id": 0}
## Levers and wall buttons must sit where the map has a wall.

const BOX_CHARS := {"r": "rubber", "s": "sticky", "v": "void"}

const LEVELS := [
	
	#Shows Movement
	{
		"name": "1 - Welcome",
		"map": [
			"#######",
			"#.@..G#",
			"#######",
		],
		"balls": {"normal": 2},
	},
	#Boxes bridge
	{
		"name": "2 - Boxes as Bridges",
		"map": [
			"##########",
			"#@..r~..G#",
			"##########",
		],
		"balls": {"normal": 2},
	},
	#Piston Power
	{
		"name": "3 - Pistons",
		"map": [
			"##########",
			"#p..@...G#",
			"##########",
		],
		"balls": {"normal": 2},
	},
	{
		# Swap Balls
		"name": "4 - The Pain Train (Swap Balls with Q and E)",
		"map": [
			"############",
			"#@........G#",
			"############",
		],
		"balls": {"painful": 2, "normal": 1},
		"health": 3,
	},
	{
		# Pathing
		"name": "5 - Do try not to die",
		"map": [
			"######",
			"p...G#",
			"#.@..#",			
			"######",
		],
		"balls": {"painful": 3},
		"health": 3,
	},
	{
		"name": "6 - Buttons",
		"map": [
			"#########",
			"####.####",
			"####r####",
			"#@.....G#",
			"#########",
		],
		"extras": [
			{"kind": "floor_button", "pos": Vector2i(4, 1), "id": 0},
			{"kind": "door", "pos": Vector2i(6, 3), "id": 0},
		],
		"balls": {"normal": 2},
	},
	{
		# Slippy
		"name": "7 - Chilly Floors",
		"map": [
			"############",
			"#.@*******G#",
			"############",
		],
		"balls": {"normal": 3},
		"health": 3,
	},
	{
		# Spikes
		"name": "8 - Spiky",
		"map": [
			"############",
			"#.........G#",
			"#^.@.......#",
			"############",
		],
		"balls": {"normal": 3},
		"health": 3,
	},
	{
		# Spikyboxes
		"name": "9 - The box is hungry - (Pay attention to the balls)",
		"map": [
			"############",
			"#@..v..~..G#",
			"############",
		],
		"balls": {"normal": 4},
		"health": 3,
	},
	{
		# Introduces mirrors
		"name": "10 - Mirrors",
		"map": [
			"#########",
			"#/.r..###",
			"#.#######",
			"#.@....G#",
			"#########",
		],
		"extras": [
			{"kind": "floor_button", "pos": Vector2i(5, 1), "id": 0},
			{"kind": "door", "pos": Vector2i(6, 3), "id": 0},
		],
		"balls": {"normal": 3},
		"health": 3,
	},
	{
		# First actual puzzle
		"name": "11 - Roundabout",
		"map": [
			"#########",
			"#./|#####",
			"#..r#####",
			"#..@.~.G#",
			"#########",
		],
		"balls": {"normal": 3},
		"health": 3,
	},
	{
		# Wall Buttons
		"name": "12 - Push Latch",
		"map": [
			"##########",
			"#.########",
			"#.########",
			"#@......G#",
			"##########",
		],
		"extras": [
			{"kind": "wall_button", "pos": Vector2i(1, 0), "dir": Vector2i(0, 1), "id": 0},
			{"kind": "door", "pos": Vector2i(7, 3), "id": 0},
		],
		"balls": {"normal": 3, "painful": 2},
		"health": 3,
	},
	{
		# Wall levers
		"name": "13 - Levers can't be punched man",
		"map": [
			"#########",
			"##@....G#",
			"##.#.####",
			"##.#.####",
			"#^../####",
			"#########",
		],
		"extras": [
			{"kind": "lever", "pos": Vector2i(2, 5), "dir": Vector2i(0, -1), "id": 0},
			{"kind": "door", "pos": Vector2i(6, 1), "id": 0},
		],
		"balls": {"normal": 2},
		"health": 3,
	},
	
	{
		# Kitchen-sink test room, not a designed puzzle: use it to try every tile.
		"name": "3 - Sandbox",
		"map": [
			"############",
			"#@.....%...#",
			"#..r..*****#",
			"#.....*~~~G#",
			"#..^../....#",
			"############",
		],
		"extras": [
			{"kind": "lever", "pos": Vector2i(3, 0), "dir": Vector2i(0, 1), "id": 0},
			{"kind": "wall_button", "pos": Vector2i(11, 2), "dir": Vector2i(-1, 0), "id": 0},
			{"kind": "floor_button", "pos": Vector2i(5, 2), "id": 0},
			{"kind": "door", "pos": Vector2i(8, 4), "id": 0},
		],
		"balls": {"normal": 3, "painful": 2},
		"health": 3,
	}
]


static func build(index: int) -> GameState:
	var def: Dictionary = LEVELS[index]
	var rows: Array = def["map"]
	var s := GameState.new()
	s.height = rows.size()
	s.width = (rows[0] as String).length()

	for y in s.height:
		var row: String = rows[y]
		assert(row.length() == s.width, "Level row %d has a different length" % y)
		for x in s.width:
			var p := Vector2i(x, y)
			s.floors[p] = GameState.Floor.LAND
			var ch := row[x]
			match ch:
				"#":
					s.tiles[p] = TileInfo.make(GameState.Kind.WALL)
				"~":
					s.floors[p] = GameState.Floor.WATER
				"*":
					s.floors[p] = GameState.Floor.ICE
				"@":
					s.player_pos = p
				"G":
					s.tiles[p] = TileInfo.make(GameState.Kind.GOAL)
				"r", "s", "v":
					var b := Box.new()
					b.kind = BOX_CHARS[ch]
					b.pos = p
					s.boxes.append(b)
				"/":
					s.tiles[p] = TileInfo.make(GameState.Kind.MIRROR_SLASH)
				"|":
					s.tiles[p] = TileInfo.make(GameState.Kind.MIRROR_BACK)
				"^":
					s.tiles[p] = TileInfo.make(GameState.Kind.SPIKES)
				"p":
					s.tiles[p] = TileInfo.make(GameState.Kind.PISTON)
				"%":
					s.tiles[p] = TileInfo.make(GameState.Kind.SPLITTER)

	for e: Dictionary in def.get("extras", []):
		var kind := _extra_kind(e["kind"])
		s.tiles[e["pos"]] = TileInfo.make(kind, e.get("dir", Vector2i.ZERO), e.get("id", 0))

	s.inventory = (def["balls"] as Dictionary).duplicate()
	s.max_health = def.get("health", 3)
	s.health = s.max_health
	return s


static func _extra_kind(name: String) -> int:
	match name:
		"lever":
			return GameState.Kind.LEVER
		"wall_button":
			return GameState.Kind.WALL_BUTTON
		"floor_button":
			return GameState.Kind.FLOOR_BUTTON
		"door":
			return GameState.Kind.DOOR
	push_error("Unknown extra tile kind: %s" % name)
	return GameState.Kind.WALL
