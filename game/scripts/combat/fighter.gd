class_name Fighter
extends CharacterBody2D
## One combatant: state machine, movement, attacks, YEET, guard, damage.
## Controllers (player or AI) only produce an "intent" each frame; all rules
## live here so human and AI play by exactly the same laws.

enum State { IDLE, RUN, JUMP, FALL, DASH, ATTACK, HURT, GUARD, KO, VICTORY }

signal hit_landed(attacker: Fighter, victim: Fighter, info: Dictionary)
signal damaged(victim: Fighter, attacker: Fighter, info: Dictionary)
signal ko(loser: Fighter, winner: Fighter)
signal parried(defender: Fighter, attacker: Fighter)

const GRAVITY := 1850.0
const TERMINAL := 1450.0
const CONTROL_STATES: Array = [State.IDLE, State.RUN, State.JUMP, State.FALL, State.GUARD]
const BUFFER_TIME := 0.16
const COMBO_WINDOW := 1.45

var stats: FighterStats
var fx: Node = null               ## Fx (loosely typed to avoid hard dependency)
var opponent: Fighter = null
var controller: Node = null
var is_player := false
var fighter_index := 0
var inputs_enabled := true

var max_hp := 100
var hp := 100
var state: State = State.IDLE
var facing := 1
var grounded := true
var spawn_pos := Vector2.ZERO

# timers
var state_time := 0.0
var dash_cd := 0.0
var yeet_cd := 0.0
var invuln := 0.0
var guard_time := 0.0
var parry_left := 0.0
var hurt_time := 0.0
var coyote := 0.0
var error_sound_cd := 0.0

# attack bookkeeping
var attack_kind := ""
var attack_phase := 0             ## 0 startup, 1 active, 2 recovery
var phase_time := 0.0
var hit_connected := false
var lunge := 0.0

# input buffer
var buffer: Dictionary = {}       ## action name -> seconds left

# combo / stats
var combo := 0
var max_combo := 0
var combo_timer := 0.0
var damage_dealt := 0.0

var intent: Dictionary = {"move": 0.0, "jump": false, "light": false, "heavy": false, "yeet": false, "dash": false, "guard": false}

@onready var body_shape: CollisionShape2D = $BodyShape
@onready var hurtbox: Area2D = $Hurtbox
@onready var hitbox: Area2D = $Hitbox
@onready var hit_shape: CollisionShape2D = $Hitbox/Shape
@onready var art: Node2D = $Art

func _ready() -> void:
	spawn_pos = global_position
	hit_shape.shape.size = Vector2(40, 40)
	z_index = 5

func setup(p_stats: FighterStats, p_index: int, p_is_player: bool) -> void:
	stats = p_stats
	fighter_index = p_index
	is_player = p_is_player
	max_hp = stats.max_hp
	hp = max_hp
	facing = 1 if p_index == 0 else -1
	if art.has_method("setup"):
		art.setup(stats, p_index)

func reset_for_round() -> void:
	global_position = spawn_pos
	hp = max_hp
	state = State.IDLE
	combo = 0
	max_combo = 0
	combo_timer = 0.0
	yeet_cd = 0.0
	dash_cd = 0.0
	invuln = 0.0
	buffer.clear()
	velocity = Vector2.ZERO
	facing = 1 if fighter_index == 0 else -1
	inputs_enabled = true

# ------------------------------------------------------------------ helpers

func is_ko() -> bool:
	return state == State.KO

func is_control_state() -> bool:
	return state in CONTROL_STATES

func can_act() -> bool:
	return inputs_enabled and is_control_state() and not is_ko()

func distance_to_opponent() -> float:
	if opponent == null:
		return 0.0
	return absf(opponent.global_position.x - global_position.x)

func opponent_in_front() -> bool:
	if opponent == null:
		return true
	return signf(opponent.global_position.x - global_position.x) == float(facing)

func yeet_ready() -> bool:
	return yeet_cd <= 0.0

func set_controller(c: Node) -> void:
	controller = c
	if c.has_method("bind"):
		c.bind(self)

# ------------------------------------------------------------------ main tick

func _physics_process(delta: float) -> void:
	if fx != null and fx.in_hitstop():
		return
	_update_timers(delta)

	if controller != null and inputs_enabled:
		intent = controller.get_intent()
	else:
		intent = _empty_intent()

	match state:
		State.KO:
			_tick_ko(delta)
		State.ATTACK:
			_tick_attack(delta)
		State.HURT:
			_tick_hurt(delta)
		_:
			_tick_control(delta)

	move_and_slide()
	_apply_bounds(delta)
	_push_art_params()
	# Safety watchdog: never stay invalid.
	if not is_finite(global_position.x) or not is_finite(global_position.y):
		global_position = spawn_pos
		velocity = Vector2.ZERO
		state = State.IDLE

func _empty_intent() -> Dictionary:
	return {"move": 0.0, "jump": false, "light": false, "heavy": false, "yeet": false, "dash": false, "guard": false}

func _update_timers(delta: float) -> void:
	dash_cd = maxf(0.0, dash_cd - delta)
	yeet_cd = maxf(0.0, yeet_cd - delta)
	invuln = maxf(0.0, invuln - delta)
	error_sound_cd = maxf(0.0, error_sound_cd - delta)
	state_time += delta
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0 and combo > 0:
			combo = 0
	for action in buffer.keys():
		buffer[action] -= delta
		if buffer[action] <= 0.0:
			buffer.erase(action)
	if state == State.GUARD:
		guard_time += delta
		parry_left = maxf(0.0, parry_left - delta)

func _buffer_edges() -> void:
	## Store fresh button presses so they can fire when recovery ends.
	if not inputs_enabled:
		return
	for action in ["jump", "light", "heavy", "yeet", "dash"]:
		if intent[action]:
			buffer[action] = BUFFER_TIME

func _consume(action: String) -> bool:
	if buffer.has(action):
		buffer.erase(action)
		return true
	return false

# ------------------------------------------------------------------ control

func _tick_control(delta: float) -> void:
	_buffer_edges()

	# Gravity / ground bookkeeping.
	if not grounded:
		velocity.y = minf(velocity.y + GRAVITY * stats.gravity_scale * delta, TERMINAL)

	var move := float(intent["move"])

	# Guard.
	if state == State.GUARD or (intent["guard"] and grounded and state in [State.IDLE, State.RUN]):
		if intent["guard"] and grounded:
			if state != State.GUARD:
				_enter_guard()
			_guard_move(move, delta)
			return
		else:
			_exit_guard()

	# Dash (edge-buffered).
	if (state in [State.IDLE, State.RUN]) and _consume("dash") and dash_cd <= 0.0 and grounded:
		_start_dash(move)
		return

	# Jump.
	if _consume("jump") and (grounded or coyote > 0.0) and state in [State.IDLE, State.RUN, State.FALL, State.JUMP]:
		velocity.y = stats.jump_velocity
		grounded = false
		coyote = 0.0
		state = State.JUMP
		state_time = 0.0
		AudioMan.play_sfx("jump", -6.0)

	# Attacks (allowed grounded or airborne).
	if state in [State.IDLE, State.RUN, State.JUMP, State.FALL]:
		if _consume("yeet"):
			if yeet_cd <= 0.0:
				_start_attack("yeet")
				return
			else:
				_yeet_denied()
		if _consume("light"):
			_start_attack("light")
			return
		if _consume("heavy"):
			_start_attack("heavy")
			return

	# Movement.
	var target := move * stats.move_speed
	if state in [State.JUMP, State.FALL]:
		target *= stats.air_control
	var rate := stats.accel if absf(move) > 0.01 else stats.accel * 1.5
	velocity.x = move_toward(velocity.x, target, rate * delta)

	# Facing follows the opponent during control states.
	if opponent != null and absf(move) < 0.01:
		facing = 1 if opponent.global_position.x >= global_position.x else -1
	elif absf(move) > 0.01:
		facing = 1 if move > 0.0 else -1

	# Resolve state label.
	if state != State.GUARD:
		if not grounded:
			state = State.FALL if velocity.y > 40.0 else State.JUMP
		elif absf(velocity.x) > 25.0:
			state = State.RUN
		else:
			state = State.IDLE

func _enter_guard() -> void:
	state = State.GUARD
	guard_time = 0.0
	parry_left = stats.parry_window if stats.parry else 0.0
	state_time = 0.0

func _exit_guard() -> void:
	if state == State.GUARD:
		state = State.IDLE
		state_time = 0.0

func _guard_move(move: float, delta: float) -> void:
	var target := move * stats.move_speed * 0.35
	velocity.x = move_toward(velocity.x, target, stats.accel * 0.7 * delta)
	if absf(move) > 0.01:
		facing = 1 if move > 0.0 else -1
	elif opponent != null:
		facing = 1 if opponent.global_position.x >= global_position.x else -1
	# Standing guard holds still.
	state = State.GUARD

func _start_dash(move: float) -> void:
	state = State.DASH
	state_time = 0.0
	var dir := facing
	if absf(move) > 0.01:
		dir = 1 if move > 0.0 else -1
	facing = dir
	dash_cd = stats.dash_cooldown
	invuln = maxf(invuln, stats.dash_invuln)
	velocity.x = dir * stats.dash_speed
	velocity.y = minf(velocity.y, 0.0)
	AudioMan.play_sfx("dash", -5.0)
	if fx:
		fx.burst(global_position + Vector2(0, -40), stats.accent, 0.6)

func _start_attack(kind: String) -> void:
	state = State.ATTACK
	attack_kind = kind
	attack_phase = 0
	phase_time = 0.0
	hit_connected = false
	state_time = 0.0
	lunge = 0.0
	match kind:
		"light":
			lunge = 150.0
		"heavy":
			lunge = 210.0
		"yeet":
			lunge = 60.0
			yeet_cd = stats.yeet_cooldown
			AudioMan.play_sfx("yeet_charge", -3.0)
			if fx:
				fx.burst(global_position + Vector2(18 * facing, -60), stats.accent, 0.7)

func _tick_attack(delta: float) -> void:
	_buffer_edges()
	phase_time += delta
	# Slight forward lunge that decays quickly.
	lunge = move_toward(lunge, 0.0, 700.0 * delta)
	velocity.x = move_toward(velocity.x, facing * lunge, 1400.0 * delta)
	if not grounded:
		velocity.y = minf(velocity.y + GRAVITY * stats.gravity_scale * delta, TERMINAL)
	else:
		velocity.y = 0.0
	if opponent != null and attack_phase == 0:
		# Still allowed to re-face during startup.
		facing = 1 if opponent.global_position.x >= global_position.x else -1

	var startup: float
	var active: float
	var recovery: float
	match attack_kind:
		"light":
			startup = stats.light_startup
			active = stats.light_active
			recovery = stats.light_recovery
		"heavy":
			startup = stats.heavy_startup
			active = stats.heavy_active
			recovery = stats.heavy_recovery
		_:
			startup = stats.yeet_windup
			active = stats.yeet_active
			recovery = stats.yeet_recovery

	match attack_phase:
		0:
			_position_hitbox()
			if phase_time >= startup:
				attack_phase = 1
				phase_time = 0.0
				hit_connected = false
				_position_hitbox()
		1:
			_position_hitbox()
			_check_hit()
			if phase_time >= active:
				attack_phase = 2
				phase_time = 0.0
		2:
			if phase_time >= recovery:
				state = State.IDLE if grounded else State.FALL
				state_time = 0.0
				attack_kind = ""
				_buffer_edges_after_recovery()

func _buffer_edges_after_recovery() -> void:
	# Buffer stays valid: presses made during recovery fire immediately now.
	if not inputs_enabled:
		return
	for action in ["jump", "light", "heavy", "yeet", "dash"]:
		if intent[action]:
			buffer[action] = BUFFER_TIME

func _yeet_denied() -> void:
	if error_sound_cd <= 0.0:
		AudioMan.play_sfx("error", -10.0)
		error_sound_cd = 0.4

func _position_hitbox() -> void:
	var w: float
	var h: float
	var reach: float
	var cy: float
	match attack_kind:
		"light":
			reach = stats.light_range
			w = reach
			h = 54.0
			cy = -56.0
		"heavy":
			reach = stats.heavy_range
			w = reach
			h = 62.0
			cy = -50.0
		_:
			reach = stats.yeet_range
			w = reach + 16.0
			h = 92.0
			cy = -52.0
	hit_shape.shape.size = Vector2(w, h)
	hitbox.position = Vector2(facing * (w * 0.5 + 6.0), cy)

func _check_hit() -> void:
	if hit_connected or opponent == null:
		return
	if not hitbox.overlaps_area(opponent.hurtbox):
		return
	hit_connected = true
	var info := _make_hit_info()
	var outcome := opponent.take_hit(self, info)
	if outcome == "whiff":
		hit_connected = false
		return

func _make_hit_info() -> Dictionary:
	var base_damage := 0
	var kb := 0.0
	var launch := 0.0
	match attack_kind:
		"light":
			base_damage = stats.light_damage
			kb = stats.light_knockback
			launch = stats.light_launch
		"heavy":
			base_damage = stats.heavy_damage
			kb = stats.heavy_knockback
			launch = stats.heavy_launch
		_:
			base_damage = stats.yeet_damage
			kb = stats.yeet_knockback
			launch = stats.yeet_launch
	# Combo damage scaling keeps long strings from deleting health bars.
	var scale := maxf(0.45, 1.0 - 0.07 * float(maxi(combo - 1, 0)))
	base_damage = int(round(base_damage * scale))
	var crit := false
	if stats.crit_chance > 0.0 and attack_kind != "yeet":
		crit = randf() < stats.crit_chance
		if crit:
			base_damage = int(round(base_damage * stats.crit_mult))
	return {
		"damage": base_damage,
		"knockback": kb,
		"launch": launch,
		"dir": facing,
		"kind": attack_kind,
		"attack_kind": attack_kind,
		"crit": crit,
	}

# ------------------------------------------------------------------ taking hits

## Called by the attacker. Returns "hit" | "blocked" | "parried" | "armor" | "whiff".
func take_hit(attacker: Fighter, info: Dictionary) -> String:
	if is_ko():
		return "whiff"
	if invuln > 0.0:
		AudioMan.play_sfx("whiff", -8.0)
		if fx:
			fx.burst(global_position + Vector2(0, -44), Color("aab4d8"), 0.5)
		return "whiff"

	var dir := int(info["dir"])
	var dmg := float(info["damage"])
	var kb := float(info["knockback"])
	var launch := float(info["launch"])
	var kind := String(info["kind"])

	# Parry (GLITCH): perfectly timed guard.
	if state == State.GUARD and stats.parry and parry_left > 0.0:
		parry_left = 0.0
		attacker.force_hurt(0.7, -dir)
		yeet_cd = 0.0
		AudioMan.play_sfx("combo_up", -2.0, 0.02)
		if fx:
			fx.ring(global_position + Vector2(0, -50), Color.WHITE, 80.0)
			fx.burst(global_position + Vector2(0, -50), stats.accent, 1.1)
			fx.shake(7.0)
		parried.emit(self, attacker)
		return "parried"

	# Guard reduces damage and push.
	if state == State.GUARD and opponent_is_front(attacker):
		dmg *= (1.0 - stats.guard_reduction)
		kb *= 0.3
		launch *= 0.25
		AudioMan.play_sfx("block", -5.0)
		_damage(dmg, attacker, "blocked", kind)
		velocity.x = float(dir) * kb
		velocity.y = -launch
		if hp <= 0.0:
			_die(attacker)
		return "blocked"

	# Super armor (BRICK): damage lands but the attack is not interrupted.
	if state == State.ATTACK and stats.super_armor:
		_damage(dmg, attacker, "armor", kind)
		velocity.x += float(dir) * kb * 0.12
		_flash()
		if hp <= 0.0:
			_die(attacker)
		return "armor"

	# Clean hit.
	dmg *= stats.damage_taken_mult
	kb *= stats.knockback_taken_mult
	_damage(dmg, attacker, "hit", kind)
	velocity = Vector2(float(dir) * kb, -launch)
	hurt_time = clampf(0.17 + kb / 2600.0, 0.17, 0.6)
	state = State.HURT
	state_time = 0.0
	_flash()
	if hp <= 0.0:
		_die(attacker)
	return "hit"

func opponent_is_front(attacker: Fighter) -> bool:
	return signf(attacker.global_position.x - global_position.x) == float(facing)

func _damage(amount: float, attacker: Fighter, outcome: String, attack_kind: String = "hazard") -> void:
	hp = maxf(0.0, hp - amount)
	if attacker != null:
		if outcome == "hit":
			attacker.combo += 1
			attacker.combo_timer = COMBO_WINDOW
			attacker.max_combo = maxi(attacker.max_combo, attacker.combo)
		attacker.damage_dealt += amount
	var info := {
		"damage": amount,
		"kind": outcome,
		"attack_kind": attack_kind,
		"attacker_index": attacker.fighter_index if attacker != null else -1,
		"combo": attacker.combo if attacker != null else 0,
	}
	damaged.emit(self, attacker, info)
	if attacker != null:
		hit_landed.emit(attacker, self, info)

func force_hurt(duration: float, dir: int) -> void:
	if is_ko():
		return
	state = State.HURT
	state_time = 0.0
	hurt_time = duration
	velocity = Vector2(dir * 180.0, -120.0)
	_flash()

## Damage from arena hazards (no attacker, no combo credit).
## Returns true if the hit connected.
func hazard_hit(amount: float, dir_x: float, launch: float = 260.0) -> bool:
	if is_ko() or invuln > 0.0:
		return false
	_damage(amount, null, "hazard")
	velocity = Vector2(dir_x * 240.0, -launch)
	if not (state == State.ATTACK and stats.super_armor):
		state = State.HURT
		state_time = 0.0
		hurt_time = 0.28
	_flash()
	if hp <= 0.0:
		_die(null)
	return true

func _flash() -> void:
	if art.has_method("set_flash"):
		art.set_flash(1.0)

func _die(attacker: Fighter) -> void:
	if state == State.KO:
		return
	state = State.KO
	state_time = 0.0
	velocity = Vector2(velocity.x * 0.4, -320.0)
	invuln = 999.0
	ko.emit(self, attacker)

func _tick_hurt(delta: float) -> void:
	_buffer_edges()
	if not grounded:
		velocity.y = minf(velocity.y + GRAVITY * stats.gravity_scale * delta, TERMINAL)
	velocity.x = move_toward(velocity.x, 0.0, 620.0 * delta)
	if state_time >= hurt_time:
		state = State.FALL if not grounded else State.IDLE
		state_time = 0.0

func _tick_ko(delta: float) -> void:
	if not grounded:
		velocity.y = minf(velocity.y + GRAVITY * stats.gravity_scale * delta, TERMINAL)
	velocity.x = move_toward(velocity.x, 0.0, 480.0 * delta)

func celebrate() -> void:
	if state != State.KO:
		state = State.VICTORY
		state_time = 0.0
		velocity = Vector2.ZERO

# ------------------------------------------------------------------ bounds

func _apply_bounds(delta: float) -> void:
	var match_node: Node = get_parent().get_parent() if get_parent() != null else null
	var b := Rect2(64, 70, 1152, 570)
	if match_node != null and match_node.has_method("get_hard_bounds"):
		b = match_node.get_hard_bounds()

	# Side walls: clamp and kill outward velocity.
	var prev_x := global_position.x
	global_position.x = clampf(global_position.x, b.position.x, b.end.x)
	if not is_equal_approx(prev_x, global_position.x):
		if signf(velocity.x) == signf(global_position.x - prev_x):
			velocity.x = 0.0

	# Ceiling.
	if global_position.y < b.position.y:
		global_position.y = b.position.y
		if velocity.y < 0.0:
			velocity.y = 0.0

	# Virtual floor.
	if global_position.y >= b.end.y:
		global_position.y = b.end.y
		if not grounded and velocity.y > 120.0:
			AudioMan.play_sfx("land", -12.0)
			if fx:
				fx.burst(global_position + Vector2(0, -4), Color("8f9ad0"), 0.35)
		grounded = true
		velocity.y = 0.0
	else:
		grounded = false

	coyote = 0.1 if grounded else maxf(0.0, coyote - delta)

func is_on_floor_by_contact() -> bool:
	return grounded

# ------------------------------------------------------------------ art bridge

func _push_art_params() -> void:
	if art == null:
		return
	art.facing = facing
	art.state = state
	art.attack_kind = attack_kind
	art.attack_phase = attack_phase
	art.phase_k = clampf(phase_time / maxf(0.0001, _current_attack_duration()), 0.0, 1.0)
	art.yeet_charge = _yeet_charge_k()
	art.speed_k = clampf(absf(velocity.x) / maxf(stats.move_speed, 1.0), 0.0, 1.4)
	art.grounded = grounded
	art.hurt_k = clampf(state_time / maxf(hurt_time, 0.001), 0.0, 1.0) if state == State.HURT else 0.0
	art.ko_k = clampf(state_time / 0.5, 0.0, 1.0) if state == State.KO else 0.0
	art.victory_k = clampf(state_time / 0.4, 0.0, 1.0) if state == State.VICTORY else 0.0
	art.dash_k = clampf(state_time / maxf(stats.dash_time, 0.001), 0.0, 1.0) if state == State.DASH else 0.0
	art.guard_k = clampf(guard_time / 0.18, 0.0, 1.0) if state == State.GUARD else 0.0
	art.paused = fx != null and fx.in_hitstop()

func _current_attack_duration() -> float:
	match attack_kind:
		"light": return stats.light_startup + stats.light_active + stats.light_recovery
		"heavy": return stats.heavy_startup + stats.heavy_active + stats.heavy_recovery
		"yeet": return stats.yeet_windup + stats.yeet_active + stats.yeet_recovery
	return 1.0

func _yeet_charge_k() -> float:
	if state == State.ATTACK and attack_kind == "yeet":
		if attack_phase == 0:
			return clampf(phase_time / maxf(stats.yeet_windup, 0.001), 0.0, 1.0)
		return 1.0
	return 0.0
