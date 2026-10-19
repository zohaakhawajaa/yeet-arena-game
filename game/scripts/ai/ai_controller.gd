class_name AIController
extends Node
## Personality-driven AI state machine. Produces the same intent dictionary a
## human does - no cheating, no reaction faster than its reaction delay, and
## every action respects cooldowns and ranges.

enum AIState { IDLE, APPROACH, SPACE, ATTACK, DEFEND, YEET, DASH_OUT, HAZARD, RECOVER }

const DIFFICULTY_PROFILES := {
	"easy": {
		"reaction": 0.45, "block": 0.18, "special": 0.15, "aggro": 0.40,
		"mistake": 0.30, "dash": 0.25, "spacing_err": 70.0, "jump": 0.10,
	},
	"normal": {
		"reaction": 0.25, "block": 0.42, "special": 0.40, "aggro": 0.65,
		"mistake": 0.13, "dash": 0.55, "spacing_err": 34.0, "jump": 0.22,
	},
	"hard": {
		"reaction": 0.12, "block": 0.70, "special": 0.62, "aggro": 0.90,
		"mistake": 0.04, "dash": 0.85, "spacing_err": 14.0, "jump": 0.35,
	},
}

const PERSONALITIES := {
	"volt":   {"aggro": 1.18, "heavy": 0.25, "dash": 0.60, "block": 0.90, "range": 74.0},
	"brick":  {"aggro": 0.95, "heavy": 0.70, "dash": 0.45, "block": 0.85, "range": 86.0},
	"phantom": {"aggro": 0.85, "heavy": 0.30, "dash": 1.70, "block": 1.30, "range": 68.0},
	"chaos":  {"aggro": 1.30, "heavy": 0.45, "dash": 1.10, "block": 0.55, "range": 72.0},
	"titan":  {"aggro": 0.80, "heavy": 0.60, "dash": 0.55, "block": 1.15, "range": 80.0},
	"glitch": {"aggro": 1.02, "heavy": 0.40, "dash": 1.05, "block": 1.35, "range": 72.0},
}

var fighter: Fighter
var opponent: Fighter
var arena_ref: Node = null

var profile: Dictionary = DIFFICULTY_PROFILES["normal"]
var personality: Dictionary = PERSONALITIES["volt"]

var _state: int = AIState.IDLE
var _state_until := 0.0
var _decision_in := 0.0
var _time := 0.0
var _press: Dictionary = {}
var _retreat_mode := false

func bind(f: Fighter) -> void:
	fighter = f
	personality = PERSONALITIES.get(f.stats.id, PERSONALITIES["volt"])

func configure(difficulty: String, p_arena_ref: Node = null) -> void:
	profile = DIFFICULTY_PROFILES.get(difficulty, DIFFICULTY_PROFILES["normal"])
	arena_ref = p_arena_ref

func get_intent() -> Dictionary:
	var delta := fighter.get_physics_process_delta_time()
	_time += delta

	var intent := {
		"move": 0.0, "jump": false, "light": false, "heavy": false,
		"yeet": false, "dash": false, "guard": false,
	}
	# Consume one-frame presses decided earlier.
	for action in _press.keys():
		if _press[action]:
			intent[action] = true
			_press[action] = false

	if fighter.is_ko() or not fighter.inputs_enabled:
		return intent
	if fighter.state == Fighter.State.HURT:
		_state = AIState.RECOVER
		_state_until = _time + 0.22

	if _time >= _decision_in:
		_decide()
		_decision_in = _time + float(profile["reaction"]) * randf_range(0.7, 1.3)

	if _time < _state_until:
		return _intent_for_state(intent)
	return intent

# ------------------------------------------------------------------ decide

func _decide() -> void:
	if fighter == null or opponent == null:
		return
	var dist := fighter.distance_to_opponent()

	# 1) Arena danger has absolute priority.
	if arena_ref != null and arena_ref.has_method("fighter_in_danger") and arena_ref.fighter_in_danger(fighter):
		_state = AIState.HAZARD
		_state_until = _time + 0.45
		return

	# 2) React to an incoming attack (with reaction-delayed probability).
	var opp_attacking := opponent.state == Fighter.State.ATTACK and opponent.attack_phase <= 1
	if opp_attacking and dist < 130.0 and randf() < float(profile["block"]) * float(personality["block"]):
		_state = AIState.DEFEND
		_state_until = _time + randf_range(0.22, 0.5)
		return
	# 3) React to a YEET windup by creating space.
	if opponent.state == Fighter.State.ATTACK and opponent.attack_kind == "yeet" and dist < 160.0:
		if randf() < float(profile["block"]) * 0.8:
			_state = AIState.DASH_OUT
			_state_until = _time + 0.3
			return

	# 4) Mistakes: occasionally do nothing.
	if randf() < float(profile["mistake"]):
		_state = AIState.IDLE
		_state_until = _time + randf_range(0.15, 0.4)
		return

	# 5) Attack decisions.
	var reach := float(personality["range"])
	var aggro := float(profile["aggro"]) * float(personality["aggro"])
	if fighter.state == Fighter.State.HURT:
		return
	if dist <= reach + 12.0 and fighter.is_control_state():
		var yeet_range := stats_yeet_range() * 0.92
		if fighter.yeet_ready() and dist <= yeet_range and randf() < float(profile["special"]):
			_state = AIState.YEET
			_state_until = _time + 0.35
			_press["yeet"] = true
			return
		# Heavy if opponent is slow/recovering, otherwise mix.
		var want_heavy := randf() < float(personality["heavy"])
		if opponent.state == Fighter.State.HURT:
			want_heavy = randf() < float(personality["heavy"]) + 0.15
		_press["heavy" if want_heavy else "light"] = true
		_state = AIState.ATTACK
		_state_until = _time + 0.12
		return

	# 6) Movement intent.
	var preferred := reach * 0.75 + float(profile["spacing_err"]) * randf_range(0.6, 1.4)
	if dist > preferred + 25.0:
		_state = AIState.APPROACH
		_retreat_mode = false
		# Occasionally dash to close the gap.
		if dist > 260.0 and fighter.dash_cd <= 0.0 and randf() < float(profile["dash"]) * 0.4:
			_press["dash"] = true
	elif dist < preferred - 35.0 and randf() < aggro * 0.35:
		_state = AIState.APPROACH  # keep pressing even at close range
		_retreat_mode = true       # but drift out while doing it
	else:
		_state = AIState.SPACE
		_retreat_mode = randf() < 0.4 and dist < reach * 0.8
	# Sometimes jump to vary approach.
	if randf() < float(profile["jump"]) * 0.3 and fighter.grounded and dist > 180.0:
		_press["jump"] = true
	_state_until = _time + float(profile["reaction"]) * randf_range(1.0, 2.2)

func stats_yeet_range() -> float:
	return fighter.stats.yeet_range

# ------------------------------------------------------------------ act

func _intent_for_state(intent: Dictionary) -> Dictionary:
	var tdir := signf(opponent.global_position.x - fighter.global_position.x) if opponent else 1.0
	match _state:
		AIState.APPROACH:
			intent["move"] = -tdir if _retreat_mode else tdir
			# Re-press attacks if we closed in during this window.
			var dist := fighter.distance_to_opponent()
			if dist <= float(personality["range"]) + 6.0 and fighter.is_control_state() and randf() < 0.12:
				_press["heavy" if randf() < float(personality["heavy"]) else "light"] = true
		AIState.SPACE:
			intent["move"] = tdir if _retreat_mode else 0.0
			if _retreat_mode and fighter.dash_cd <= 0.0 and randf() < 0.01:
				_press["dash"] = true
		AIState.DEFEND:
			intent["guard"] = true
		AIState.YEET:
			# Step in slightly then the buffered press fires.
			intent["move"] = tdir * 0.5
		AIState.DASH_OUT:
			intent["move"] = -tdir
			if fighter.dash_cd <= 0.0 and fighter.grounded:
				_press["dash"] = true
				_state_until = _time  # one dash is enough
		AIState.HAZARD:
			# Run to the center of the arena, jump if needed.
			var center := 640.0
			var to_center := signf(center - fighter.global_position.x)
			intent["move"] = to_center
			if not fighter.grounded:
				pass
		AIState.RECOVER:
			if randf() < 0.5:
				intent["guard"] = true
			else:
				intent["move"] = -tdir
		_:
			pass
	# One-frame presses decided above get folded into the intent.
	for action in _press.keys():
		if _press[action]:
			intent[action] = true
			_press[action] = false
	return intent

func reset_memory() -> void:
	_state = AIState.IDLE
	_press.clear()
