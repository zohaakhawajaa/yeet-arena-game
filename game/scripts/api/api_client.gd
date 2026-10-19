extends Node
## HTTP client for the FastAPI backend. Non-blocking, timeout-aware, offline-friendly.
## Emits signals so the UI never waits on the network.

signal health_changed(online: bool)
signal scores_loaded(data: Dictionary)
signal scores_failed(reason: String)
signal stats_loaded(data: Dictionary)
signal stats_failed(reason: String)
signal submit_succeeded(result: Dictionary)
signal submit_failed(reason: String, http_code: int)

const TIMEOUT_SEC := 4.0
const VALID_FIGHTERS: Array[String] = ["volt", "brick", "phantom", "chaos", "titan", "glitch"]
const VALID_MODES: Array[String] = ["arcade", "demo"]

var online: bool = false
var last_error: String = ""
var _checking := false
var _fetching := false
var _submitting := false
var _submitted_matches: Dictionary = {}   ## match_id -> true (duplicate guard)

func base_url() -> String:
	var url := Settings.api_url.strip_edges()
	if url.ends_with("/"):
		url = url.substr(0, url.length() - 1)
	return url

## Ask the backend for health; updates `online`. Safe to call often (coalesced).
func check_health() -> void:
	if _checking:
		return
	_checking = true
	var res := await _request("/health", HTTPClient.METHOD_GET)
	_checking = false
	var was_online := online
	online = res["ok"] and res["code"] == 200
	if not online:
		last_error = String(res["error"]) if res["error"] != "" else "backend unreachable"
	if online != was_online:
		health_changed.emit(online)

func fetch_scores(fighter: String = "", limit: int = 10, offset: int = 0) -> void:
	if _fetching:
		return
	_fetching = true
	var query := "?limit=%d&offset=%d" % [clampi(limit, 1, 100), clampi(offset, 0, 10000)]
	if fighter != "":
		query += "&fighter=" + fighter.uri_encode()
	var res := await _request("/api/scores" + query, HTTPClient.METHOD_GET)
	_fetching = false
	if res["ok"] and res["code"] == 200:
		var data: Variant = res["json"]
		if data is Dictionary:
			online = true
			scores_loaded.emit(data)
			return
	scores_failed.emit(_friendly_error(res))

func fetch_stats() -> void:
	var res := await _request("/api/stats", HTTPClient.METHOD_GET)
	if res["ok"] and res["code"] == 200 and res["json"] is Dictionary:
		online = true
		stats_loaded.emit(res["json"])
	else:
		stats_failed.emit(_friendly_error(res))

## Validate a result payload locally, then POST it exactly once per match id.
## Returns immediately; result arrives via submit_succeeded/submit_failed.
func submit_score(payload: Dictionary) -> void:
	var validation_error := validate_payload(payload)
	if validation_error != "":
		submit_failed.emit("invalid payload: " + validation_error, 0)
		return
	var match_id := String(payload.get("client_match_id", ""))
	if match_id != "" and _submitted_matches.has(match_id):
		submit_failed.emit("match already submitted", 409)
		return
	if _submitting:
		submit_failed.emit("a submission is already in progress", 409)
		return
	_submitting = true
	var res := await _request("/api/scores", HTTPClient.METHOD_POST, payload)
	_submitting = false
	if res["ok"] and res["code"] in [200, 201] and res["json"] is Dictionary:
		online = true
		if match_id != "":
			_submitted_matches[match_id] = true
		submit_succeeded.emit(res["json"])
	else:
		if match_id != "":
			_submitted_matches.erase(match_id)
		submit_failed.emit(_friendly_error(res), int(res["code"]))

## Pure client-side validation mirroring the server rules.
## Returns "" when valid, otherwise a short reason.
func validate_payload(p: Dictionary) -> String:
	var name := String(p.get("player_name", ""))
	if name.length() < 2 or name.length() > 16:
		return "player_name must be 2-16 characters"
	for ch in name:
		if ch.unicode_at(0) < 32:
			return "player_name contains control characters"
	if not String(p.get("fighter", "")) in VALID_FIGHTERS:
		return "unknown fighter"
	if not String(p.get("mode", "")) in VALID_MODES:
		return "unknown match mode"
	if not p.has("score") or not p["score"] is int or int(p["score"]) < 0:
		return "score must be a non-negative integer"
	if int(p["score"]) > 5_000_000:
		return "score out of range"
	if not p.has("kos") or not p["kos"] is int or int(p["kos"]) < 0 or int(p["kos"]) > 99:
		return "kos out of range"
	if not p.has("max_combo") or not p["max_combo"] is int or int(p["max_combo"]) < 0 or int(p["max_combo"]) > 999:
		return "max_combo out of range"
	if not p.has("duration") or not p["duration"] is float and not p["duration"] is int:
		return "duration must be a number"
	if float(p["duration"]) < 0.0 or float(p["duration"]) > 600.0:
		return "duration out of range"
	if not p.has("victory") or not p["victory"] is bool:
		return "victory must be a boolean"
	if String(p.get("client_match_id", "")).length() > 64:
		return "client_match_id too long"
	return ""

func _request(path: String, method: int, body: Variant = null) -> Dictionary:
	var out := {"ok": false, "code": 0, "json": null, "error": ""}
	var req := HTTPRequest.new()
	req.timeout = TIMEOUT_SEC
	add_child(req)
	var headers := PackedStringArray(["Content-Type: application/json; charset=utf-8"])
	var request_body := ""
	if body != null:
		request_body = JSON.stringify(body)
	var err := req.request(base_url() + path, headers, method, request_body)
	if err != OK:
		req.queue_free()
		out["error"] = "could not start request (err %d)" % err
		return out
	var response: Array = await req.request_completed
	req.queue_free()
	var result: int = response[0]
	var code: int = response[1]
	var body_bytes: PackedByteArray = response[3]
	if result != HTTPRequest.RESULT_SUCCESS:
		out["error"] = "no response from backend (code %d)" % result
		return out
	out["ok"] = true
	out["code"] = code
	if body_bytes.size() > 0:
		var parsed: Variant = JSON.parse_string(body_bytes.get_string_from_utf8())
		if parsed == null:
			out["error"] = "malformed JSON from backend"
			out["ok"] = false
		else:
			out["json"] = parsed
	return out

func _friendly_error(res: Dictionary) -> String:
	if not res["ok"]:
		var why := String(res.get("error", ""))
		if why == "":
			why = "no response"
		return "Leaderboard service is offline (%s). Start the backend to save scores." % why
	var code := int(res["code"])
	var json: Variant = res["json"]
	if json is Dictionary and json.has("detail"):
		return str(json["detail"])
	match code:
		400: return "The server rejected the request."
		404: return "Record not found."
		429: return "Too many submissions — try again in a moment."
		_: return "Server error (HTTP %d)." % code

func reset_for_new_match() -> void:
	_submitted_matches.clear()
