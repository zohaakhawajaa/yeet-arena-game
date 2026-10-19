extends Node
## Integration test: talks to the real FastAPI backend through the game's API client.
## Requires the backend to be running (see run_tests.bat).
##
## Run: godot --headless --path . --fixed-fps 60 res://tests/godot/api_test.tscn -- --no-audio

var _event := ""
var _args: Array = []
var _match_id := ""

func _ready() -> void:
	API.submit_succeeded.connect(_on_submit_ok)
	API.submit_failed.connect(_on_submit_err)
	API.scores_loaded.connect(_on_scores_loaded)
	API.scores_failed.connect(_on_scores_failed)
	API.stats_loaded.connect(_on_stats_loaded)
	API.stats_failed.connect(_on_stats_failed)

	_match_id = "itest-%d-%d" % [int(Time.get_unix_time_from_system()), randi() % 100000]
	_settings()
	_run()

func _settings() -> void:
	var env_url := OS.get_environment("YEET_API_URL")
	if env_url != "":
		Settings.api_url = env_url
	Settings.display_name = "ITEST"
	Settings.save_settings()

func _run() -> void:
	print("[api] target ", Settings.api_url)
	API.check_health()
	var waited := 0.0
	while not API.online and waited < 10.0:
		waited += 0.1
		await get_tree().create_timer(0.1).timeout
	if not API.online:
		_fail("backend unreachable at " + Settings.api_url + " (start it with start_backend.bat)")
		return
	pass_step("health check reports online")

	# 1) Client-side validation must reject a malformed payload without hitting the network.
	API.submit_score({
		"player_name": "X",
		"fighter": "nobody",
		"opponent": "volt",
		"mode": "arcade",
		"score": -10,
		"kos": 0,
		"max_combo": 0,
		"duration": 1.0,
		"victory": false,
		"client_match_id": "",
		"client_version": "1.0.0",
	})
	if not await _wait(4.0):
		_fail("no answer for the invalid payload")
		return
	if _event != "submit_err":
		_fail("invalid payload was accepted (event=" + _event + ")")
		return
	pass_step("client validation rejects bad payload: " + str(_args[0]))
	_reset()

	# 2) Valid submission built the same way the game does it.
	var payload := GameState.build_score_payload({
		"fighter": "volt",
		"opponent": "brick",
		"mode": "arcade",
		"score": 4242,
		"kos": 2,
		"max_combo": 6,
		"duration": 57.5,
		"victory": true,
		"match_id": _match_id,
	})
	API.submit_score(payload)
	if not await _wait(8.0):
		_fail("no answer for a valid submission")
		return
	if _event != "submit_ok":
		_fail("valid submission failed: " + str(_args))
		return
	var result: Dictionary = _args[0]
	if not result.has("rank"):
		_fail("submission response has no rank")
		return
	pass_step("submission accepted, rank " + str(result.get("rank")))
	_reset()

	# 3) The submitted score must come back from the leaderboard.
	API.fetch_scores("volt", 50)
	if not await _wait(8.0):
		_fail("no answer for the score list")
		return
	if _event != "scores_loaded":
		_fail("score list failed: " + str(_args))
		return
	var data: Dictionary = _args[0]
	var scores: Array = data.get("scores", [])
	var found := false
	for s in scores:
		if String(s.get("client_match_id", "")) == _match_id:
			found = true
			break
	if not found:
		_fail("submitted match %s not present in %d returned scores" % [_match_id, scores.size()])
		return
	pass_step("leaderboard returns the submitted match (count %s)" % str(data.get("count")))
	_reset()

	# 4) Stats endpoint shape used by the leaderboard screen.
	API.fetch_stats()
	if not await _wait(8.0):
		_fail("no answer for stats")
		return
	if _event != "stats_loaded":
		_fail("stats failed: " + str(_args))
		return
	var stats: Dictionary = _args[0]
	for key in ["total_matches", "top_fighter", "average_score"]:
		if not stats.has(key):
			_fail("stats missing key: " + key)
			return
	pass_step("stats expose total_matches=%s top_fighter=%s" % [str(stats["total_matches"]), str(stats["top_fighter"])])

	print("[api] ALL_API_OK")
	AudioMan.hard_stop()
	await get_tree().process_frame
	get_tree().quit(0)

# ---------------------------------------------------------------- signal sinks

func _on_submit_ok(result: Dictionary) -> void:
	_event = "submit_ok"
	_args = [result]

func _on_submit_err(reason: String, code: int) -> void:
	_event = "submit_err"
	_args = [reason, code]

func _on_scores_loaded(data: Dictionary) -> void:
	_event = "scores_loaded"
	_args = [data]

func _on_scores_failed(reason: String) -> void:
	_event = "scores_failed"
	_args = [reason]

func _on_stats_loaded(data: Dictionary) -> void:
	_event = "stats_loaded"
	_args = [data]

func _on_stats_failed(reason: String) -> void:
	_event = "stats_failed"
	_args = [reason]

# -------------------------------------------------------------------- helpers

func _reset() -> void:
	_event = ""
	_args = []

func _wait(timeout: float) -> bool:
	var t := 0.0
	while _event == "" and t < timeout:
		t += 0.05
		await get_tree().create_timer(0.05).timeout
	return _event != ""

func pass_step(msg: String) -> void:
	print("[api] PASS ", msg)

func _fail(msg: String) -> void:
	print("[api] FAIL ", msg)
	AudioMan.hard_stop()
	get_tree().quit(1)
