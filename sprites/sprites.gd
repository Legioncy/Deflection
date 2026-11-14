class_name Sprites
extends RefCounted

const FOLDER := "res://sprites/"
static var _cache := {}

## Loads res://sprites/<name>.png once. Returns null if the file doesn't exist.
static func tex(sprite_name: String) -> Texture2D:
	if not _cache.has(sprite_name):
		var path := FOLDER + sprite_name + ".png"
		_cache[sprite_name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[sprite_name]
