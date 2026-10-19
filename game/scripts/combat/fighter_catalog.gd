class_name FighterCatalog
extends RefCounted
## Static lookup for the six fighters. Resources load lazily and are cached.

const PATHS := {
	"volt": "res://game/resources/fighters/volt.tres",
	"brick": "res://game/resources/fighters/brick.tres",
	"phantom": "res://game/resources/fighters/phantom.tres",
	"chaos": "res://game/resources/fighters/chaos.tres",
	"titan": "res://game/resources/fighters/titan.tres",
	"glitch": "res://game/resources/fighters/glitch.tres",
}

static var _cache: Dictionary = {}

static func ids() -> Array:
	return PATHS.keys()

static func has(fighter_id: String) -> bool:
	return PATHS.has(fighter_id)

static func get_fighter(fighter_id: String) -> FighterStats:
	if not PATHS.has(fighter_id):
		push_error("Unknown fighter id: " + fighter_id)
		return null
	if not _cache.has(fighter_id):
		_cache[fighter_id] = load(PATHS[fighter_id])
	return _cache[fighter_id]

static func all_fighters() -> Array:
	var out: Array = []
	for fid in PATHS:
		out.append(get_fighter(fid))
	return out
