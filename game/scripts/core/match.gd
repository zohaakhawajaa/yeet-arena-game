extends Node2D
## Match director: countdown, clock, arena phases, KO/time ending, pause,
## demo mode, scoring and results hand-off. Gameplay rules live in Fighter;
## this node owns the session.

enum MatchState { COUNTDOWN, FIGHT, ENDED }

const MATCH_TIME := 60.0
const HARD_BOUNDS := Rect2(64, 70, 1152, 570)
const SHRINK_EVENTS := [
	{"warn": 15.0, "shrink": 18.0, "inset": 72.0, "label": "ARENA CONTRACTING"},
	{"warn": 35.0, "shrink": 38.0, "inset": 158.0, "label": "ARENA CONTRACTING"},
	{"warn": 47.0, "shrink": 50.0, "inset": 236.0, "label": "FINAL PHASE"},
]

var state: MatchState = MatchState.COUNTDOWN
var time_left := MATCH_TIME
var elapsed := 0.0
var countdown_left := 3.4
var demo := false
var demo_grace := 1.0

var player_fighter: Fighter
var opp_fighter: Fighter
var fighters: Array = []
var winner: Fighter = null
var end_reason := ""
var result_shown := false
var _danger_tick := [0.0, 0.0]
var _warned_events: Dictionary = {}
var _safe_inset := 0.0
var _current_phase := 1
var _match_id := ""

@onready var world: Node2D = $World
@onready var arena: Arena = $World/Arena
@onready var fx: Fx = $World/Fx
@onready var bg: ArenaBG = $ArenaBG/BG
@onready var hud: CanvasLayer = $HUD
@onready var overlay_root: Node2D = $World

func _ready() -> void:
	_setup()

func _setup() -> void:
	demo = GameState.is_demo()
	_match_id = "%08x%08x" % [randi(), randi()]

	var p_stats := FighterCatalog.get_fighter(GameState.player_fighter)
	var o_stats := FighterCatalog.get_fighter(GameState.opponent_fighter)
	var a_def := ArenaCatalog.get_arena(GameState.arena)

	bg.setup(a_def)
	arena.setup(a_def, fx)

	# Fighters
	player_fighter = $World/Fighter1
	opp_fighter = $World/Fighter2
	player_fighter.setup(p_stats, 0, not demo)
	opp_fighter.setup(o_stats, 1, false)
	player_fighter.fx = fx
	opp_fighter.fx = fx
	player_fighter.opponent = opp_fighter
	opp_fighter.opponent = player_fighter
	fighters = [player_fighter, opp_fighter]
	arena.set_fighters(fighters)

	# Controllers
	if demo:
		var ai1 := AIController.new()
		var ai2 := AIController.new()
		world.add_child(ai1)
		world.add_child(ai2)
		ai1.configure("normal", self)
		ai2.configure("hard", self)
		player_fighter.set_controller(ai1)
		opp_fighter.set_controller(ai2)
		ai1.opponent = opp_fighter
		ai2.opponent = player_fighter
	else:
		var pc := PlayerController.new()
		world.add_child(pc)
		player_fighter.set_controller(pc)
		var ai := AIController.new()
		world.add_child(ai)
		ai.configure(GameState.difficulty(), self)
		opp_fighter.set_controller(ai)
		ai.opponent = player_fighter

	fx.setup(world, fighters)
	player_fighter.inputs_enabled = false
	opp_fighter.inputs_enabled = false

	# Signals
	for f in fighters:
		f.ko.connect(_on_ko)
		f.damaged.connect(_on_damaged)
		f.hit_landed.connect(_on_hit_landed)
		f.parried.connect(_on_parried)

	if hud.has_method("setup"):
		hud.setup(self)
	AudioMan.play_music("music_match")
	arena.set_safe_rect(get_safe_rect())

func get_hard_bounds() -> Rect2:
	return HARD_BOUNDS

func get_safe_rect() -> Rect2:
	var vertical := _safe_inset * 0.55
	return Rect2(
		HARD_BOUNDS.position.x + _safe_inset,
		HARD_BOUNDS.position.y + vertical,
		HARD_BOUNDS.size.x - _safe_inset * 2.0,
		HARD_BOUNDS.size.y - vertical
	)

func fighter_in_danger(f: Fighter) -> bool:
	var r := get_safe_rect()
	var p := f.global_position
	return p.x < r.position.x + 6.0 or p.x > r.end.x - 6.0 or p.y < r.position.y + 6.0

# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	if fx.in_hitstop():
		return
	match state:
		MatchState.COUNTDOWN:
			_tick_countdown(delta)
		MatchState.FIGHT:
			_tick_fight(delta)
		MatchState.ENDED:
			_tick_ended(delta)
	_update_danger(delta)
	if hud.has_method("update_hud"):
		hud.update_hud(delta)

func _tick_countdown(delta: float) -> void:
	var prev := ceilf(countdown_left)
	countdown_left -= delta
	var now := ceilf(countdown_left)
	if now != prev and now > 0 and now <= 3:
		AudioMan.play_sfx("count_beep", -4.0)
		_announce(str(int(now)), Color("2ee9f7"), 0.85)
	if countdown_left <= 0.0:
		state = MatchState.FIGHT
		player_fighter.inputs_enabled = true
		opp_fighter.inputs_enabled = true
		AudioMan.play_sfx("go", -2.0)
		_announce("FIGHT!", Color("ff3cac"), 0.9)
		if demo:
			demo_grace = 1.0

func _tick_fight(delta: float) -> void:
	elapsed += delta
	time_left = maxf(0.0, time_left - delta)
	_process_arena_phases()
	if player_fighter.is_ko() or opp_fighter.is_ko():
		return  # KO signal already resolved the match
	if time_left <= 0.0:
		_end_by_time()

func _process_arena_phases() -> void:
	var t := elapsed
	var target_inset := 0.0
	var warn := 0.0
	var shrinking := false
	var phase := 1
	for i in SHRINK_EVENTS.size():
		var ev: Dictionary = SHRINK_EVENTS[i]
		var warn_t := float(ev["warn"])
		var shrink_t := float(ev["shrink"])
		var inset := float(ev["inset"])
		if t >= warn_t and t < shrink_t:
			warn = 1.0
			if not _warned_events.has(i):
				_warned_events[i] = true
				AudioMan.play_sfx("arena_warning", -4.0)
				_announce(String(ev["label"]), Color("ffc24b"), 1.4)
		if t >= shrink_t:
			target_inset = inset
			phase = i + 2
			if t < shrink_t + 2.0:
				shrinking = true
	_safe_inset = target_inset
	if shrinking:
		# Smoothly interpolate from the previous inset.
		for i in SHRINK_EVENTS.size():
			var ev2: Dictionary = SHRINK_EVENTS[i]
			if t >= float(ev2["shrink"]) and t < float(ev2["shrink"]) + 2.0:
				var k := clampf((t - float(ev2["shrink"])) / 2.0, 0.0, 1.0)
				k = k * k * (3.0 - 2.0 * k)
				var from_inset := float(SHRINK_EVENTS[i - 1]["inset"]) if i > 0 else 0.0
				_safe_inset = lerpf(from_inset, float(ev2["inset"]), k)
				break
	_current_phase = phase
	arena.set_phase(phase, warn, shrinking)
	arena.set_safe_rect(get_safe_rect())

func _update_danger(delta: float) -> void:
	if state != MatchState.FIGHT:
		return
	for i in fighters.size():
		var f: Fighter = fighters[i]
		if f.is_ko():
			continue
		if fighter_in_danger(f):
			_danger_tick[i] += delta
			if _danger_tick[i] >= 0.5:
				_danger_tick[i] = 0.0
				var dmg_tick := 3.0 + float(_current_phase)
				f.hazard_hit(dmg_tick, 1.0 if f.global_position.x < 640.0 else -1.0, 90.0)
				if f.is_player:
					AudioMan.play_sfx("error", -14.0)
		else:
			_danger_tick[i] = 0.0

func _tick_ended(delta: float) -> void:
	if demo:
		if demo_grace <= 0.0:
			GameState.go("title")
			return
		demo_grace -= delta
		return
	if not result_shown:
		demo_grace -= delta
		if demo_grace <= 0.0:
			_show_results()

# ------------------------------------------------------------------ end

func _on_ko(loser: Fighter, killed_by: Fighter) -> void:
	if state == MatchState.ENDED:
		return
	var w: Fighter = null
	if killed_by != null and killed_by != loser:
		w = killed_by
	else:
		w = opp_fighter if loser == player_fighter else player_fighter
	_end_match(w, "KO")

func _end_by_time() -> void:
	if state == MatchState.ENDED:
		return
	var w: Fighter = null
	if not player_fighter.is_ko() and not opp_fighter.is_ko():
		if player_fighter.hp > opp_fighter.hp:
			w = player_fighter
		elif opp_fighter.hp > player_fighter.hp:
			w = opp_fighter
	_end_match(w, "TIME")

func _end_match(w: Fighter, reason: String) -> void:
	state = MatchState.ENDED
	winner = w
	end_reason = reason
	demo_grace = 2.6 if not demo else 3.0
	player_fighter.inputs_enabled = false
	opp_fighter.inputs_enabled = false
	if reason == "KO":
		fx.hitstop(0.16)
		fx.shake(14.0)
		AudioMan.play_sfx("ko_hit", -1.0)
		_announce("K.O.!", Color("ff4d63"), 1.6)
	else:
		_announce("TIME!", Color("ffc24b"), 1.6)
		AudioMan.play_sfx("count_beep", -2.0)
	if winner != null and not winner.is_ko():
		winner.celebrate()
	if hud.has_method("show_result_banner"):
		hud.show_result_banner(winner == player_fighter if winner != null else null, reason)

func _show_results() -> void:
	if result_shown:
		return
	result_shown = true
	var victory := winner == player_fighter and not player_fighter.is_ko()
	var results := {
		"match_id": _match_id,
		"fighter": GameState.player_fighter,
		"opponent": GameState.opponent_fighter,
		"arena": GameState.arena,
		"mode": GameState.mode,
		"victory": victory,
		"draw": winner == null,
		"kos": 1 if end_reason == "KO" and victory else 0,
		"max_combo": player_fighter.max_combo,
		"duration": elapsed,
		"time_left": time_left,
		"damage_dealt": int(player_fighter.damage_dealt),
		"hp_left": int(player_fighter.hp),
		"winner_name": (winner.stats.display_name if winner != null else "—"),
		"score": _compute_score(victory),
	}
	GameState.last_results = results
	var results_node: Control = ResultsScreen.new()
	hud.add_child(results_node)
	results_node.setup(results)
	AudioMan.play_music("music_menu", 1.2)

func _compute_score(victory: bool) -> int:
	var kos := 1 if end_reason == "KO" and victory else 0
	var score := int(player_fighter.damage_dealt) * 10
	score += player_fighter.max_combo * 60
	score += kos * 500
	score += int(time_left) * 15
	score += int(player_fighter.hp) * 5
	if victory:
		score += 1500
	return maxi(score, 0)

# ------------------------------------------------------------------ combat fx

func _on_damaged(victim: Fighter, attacker: Fighter, info: Dictionary) -> void:
	var kind := String(info["kind"])
	var pos := victim.global_position + Vector2(0, -50)
	var dmg := float(info["damage"])
	match kind:
		"hit":
			fx.burst(pos, attacker.stats.accent if attacker else victim.stats.accent, 1.0)
			fx.shake(3.5 + dmg * 0.35)
		"blocked":
			fx.burst(pos, Color("cfe2ff"), 0.5)
		"armor":
			fx.burst(pos, Color("ffc24b"), 0.6)
		"hazard":
			fx.burst(pos, Color("ff7a4d"), 0.9)
			fx.shake(4.0)

func _on_hit_landed(attacker: Fighter, victim: Fighter, info: Dictionary) -> void:
	var outcome := String(info["kind"])
	var attack_kind := String(info.get("attack_kind", "light"))
	var dmg := float(info["damage"])
	var crit := bool(info.get("crit", false))

	if outcome == "blocked":
		AudioMan.play_sfx("block", -6.0)
		return
	if outcome == "armor":
		AudioMan.play_sfx("block", -12.0, 0.05)
		return

	var hit_pos := victim.global_position + Vector2(0, -48)
	if crit:
		fx.ring(hit_pos, Color("ffc24b"), 90.0)
		AudioMan.play_sfx("punch_heavy", -2.0, 0.12)
		fx.hitstop(0.07)

	match attack_kind:
		"light":
			AudioMan.play_sfx("punch_light", -4.0)
			fx.hitstop(0.035)
		"heavy":
			AudioMan.play_sfx("punch_heavy", -3.0)
			fx.hitstop(0.06)
		"yeet":
			fx.hitstop(0.13)
			fx.shake(16.0)
			fx.ring(hit_pos, attacker.stats.accent, 130.0)
			fx.burst(hit_pos, attacker.stats.accent, 1.8)
			AudioMan.play_sfx("yeet_impact", -1.0)

	if attacker.combo >= 2:
		AudioMan.play_sfx("combo_up", -8.0, 0.05)
	if dmg >= 10.0:
		fx.ring(victim.global_position + Vector2(0, -44), Color(1, 1, 1, 0.5), 50.0)

func _on_parried(defender: Fighter, attacker: Fighter) -> void:
	_announce("PARRY!", defender.stats.accent, 0.8)
	fx.shake(6.0)

# ------------------------------------------------------------------ pause / demo input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if demo:
			if demo_grace <= 0.0:
				GameState.go("title")
				get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("pause"):
			if state in [MatchState.COUNTDOWN, MatchState.FIGHT]:
				_open_pause()
				get_viewport().set_input_as_handled()

func _open_pause() -> void:
	if get_tree().paused:
		return
	var pause: Control = PauseMenu.new()
	hud.add_child(pause)
	get_tree().paused = true

# ------------------------------------------------------------------ util

func _announce(text: String, color: Color, duration: float) -> void:
	if hud.has_method("announce"):
		hud.announce(text, color, duration)

func safe_inset() -> float:
	return _safe_inset

func phase_index() -> int:
	return _current_phase
