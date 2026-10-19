class_name ArenaCatalog
extends RefCounted
## Static lookup for arena definitions.

const PATHS := {
	"neon_pit": "res://game/resources/arenas/neon_pit.tres",
	"reactor_core": "res://game/resources/arenas/reactor_core.tres",
	"void_circuit": "res://game/resources/arenas/void_circuit.tres",
}

static var _cache: Dictionary = {}

static func ids() -> Array:
	return PATHS.keys()

static func has(arena_id: String) -> bool:
	return PATHS.has(arena_id)

static func get_arena(arena_id: String) -> ArenaDef:
	if not PATHS.has(arena_id):
		push_error("Unknown arena id: " + arena_id)
		return null
	if not _cache.has(arena_id):
		_cache[arena_id] = load(PATHS[arena_id])
	return _cache[arena_id]

static func all() -> Array:
	var out: Array = []
	for aid in PATHS:
		out.append(get_arena(aid))
	return out
