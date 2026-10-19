extends Node
## Central game state: selections, match results, and screen navigation.
## Screens never talk to each other directly - they go through GameState.

signal navigate(screen: String, payload: Dictionary)

const VERSION := "1.0.0"

var player_fighter: String = "volt"
var opponent_fighter: String = "brick"
var arena: String = "neon_pit"
var mode: String = "arcade"          ## arcade (vs AI) | demo (attract mode)
var last_results: Dictionary = {}    ## filled by the match before showing results
var match_counter: int = 0

func go(screen: String, payload: Dictionary = {}) -> void:
	navigate.emit(screen, payload)

func start_match(player: String, opponent: String, arena_id: String, p_mode: String = "arcade") -> void:
	player_fighter = player
	opponent_fighter = opponent
	arena = arena_id
	mode = p_mode
	match_counter += 1
	API.reset_for_new_match()
	go("match")

func difficulty() -> String:
	return Settings.difficulty

func is_demo() -> bool:
	return mode == "demo"

## Build the score payload from a finished match. Returns {} for demo matches
## (demo matches are never submitted).
func build_score_payload(results: Dictionary) -> Dictionary:
	if results.get("mode", "arcade") == "demo":
		return {}
	return {
		"player_name": Settings.display_name.strip_edges(),
		"fighter": String(results.get("fighter", "")),
		"opponent": String(results.get("opponent", "")),
		"mode": String(results.get("mode", "arcade")),
		"score": int(results.get("score", 0)),
		"kos": int(results.get("kos", 0)),
		"max_combo": int(results.get("max_combo", 0)),
		"duration": float(results.get("duration", 0.0)),
		"victory": bool(results.get("victory", false)),
		"client_match_id": String(results.get("match_id", "")),
		"client_version": VERSION,
	}

## Deterministic pseudo-random pick of an AI opponent (varied but reproducible
## per match counter so demo matches rotate fighters).
func pick_opponent() -> String:
	var fighters := ["volt", "brick", "phantom", "chaos", "titan", "glitch"]
	fighters.erase(player_fighter)
	return fighters[randi() % fighters.size()]
