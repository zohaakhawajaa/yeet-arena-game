extends Node2D
class_name Arena
## Playfield visuals + hazard simulation. The match director owns the rules
## (safe rect, damage); this node owns everything drawn and the hazard timing.

const W := 1280.0
const FLOOR_Y := 640.0

var def: ArenaDef
var fx: Fx = null
var time := 0.0

# Safe-zone presentation (driven by the match each frame).
var safe_rect := Rect2(64, 70, 1152, 570)
var warn_level := 0.0        ## 0..1 flashing intensity during a shrink warning
var phase_index := 1
var shrink_active := false

# Hazards
var hazard_enabled := false
var _vent_state := "idle"    ## idle | telegraph | active
var _vent_timer := 0.0
var _vent_slot := 0
var _vent_positions: Array[float] = [300.0, 640.0, 980.0]

var _orbs: Array = []
var _orb_timer := 0.0
var _fighters: Array = []

func setup(p_def: ArenaDef, p_fx: Fx = null) -> void:
	def = p_def
	fx = p_fx
	hazard_enabled = def.hazard != "none"
	queue_redraw()

func set_fighters(fighters: Array) -> void:
	_fighters = fighters

func set_safe_rect(r: Rect2) -> void:
	safe_rect = r
	queue_redraw()

func set_phase(p_index: int, p_warn: float, p_shrinking: bool) -> void:
	phase_index = p_index
	warn_level = p_warn
	shrink_active = p_shrinking
	queue_redraw()

# ------------------------------------------------------------------ update

func _process(delta: float) -> void:
	time += delta
	if hazard_enabled:
		_update_vent(delta)
		_update_orbs(delta)
	queue_redraw()

func _update_vent(delta: float) -> void:
	if def.hazard != "vent":
		return
	_vent_timer -= delta
	if _vent_timer <= 0.0:
		match _vent_state:
			"idle":
				_vent_state = "telegraph"
				_vent_timer = 2.4
				_vent_slot = randi() % _vent_positions.size()
				AudioMan.play_sfx("hazard_warn", -6.0)
			"telegraph":
				_vent_state = "active"
				_vent_timer = 0.85
				if fx:
					var pos := Vector2(_vent_positions[_vent_slot], FLOOR_Y)
					fx.burst(pos + Vector2(0, -60), def.accent, 1.4)
					fx.ring(pos + Vector2(0, -10), def.grid_color, 120.0)
					fx.shake(7.0)
				AudioMan.play_sfx("yeet_impact", -10.0, 0.1)
			"active":
				_vent_state = "idle"
				_vent_timer = randf_range(7.0, 9.5)
	_apply_vent_hits()

func vent_hit_rect() -> Rect2:
	var cx := _vent_positions[_vent_slot]
	return Rect2(cx - 34.0, FLOOR_Y - 250.0, 68.0, 250.0)

func _apply_vent_hits() -> void:
	if _vent_state != "active":
		return
	var rect := vent_hit_rect()
	for f in _fighters:
		if not is_instance_valid(f) or f.is_ko():
			continue
		var p: Vector2 = f.global_position + Vector2(0, -44)
		if rect.has_point(p):
			var dir := -1.0 if p.x > rect.get_center().x else 1.0
			f.hazard_hit(14.0, dir, 380.0)

func _update_orbs(delta: float) -> void:
	if def.hazard != "orbs":
		return
	_orb_timer -= delta
	if _orb_timer <= 0.0 and _orbs.size() < 3:
		_orb_timer = randf_range(4.5, 6.5)
		var dir := 1.0 if randf() < 0.5 else -1.0
		var start_x := -40.0 if dir > 0.0 else W + 40.0
		_orbs.append({
			"pos": Vector2(start_x, randf_range(300.0, 580.0)),
			"dir": dir,
			"speed": randf_range(90.0, 140.0),
			"age": 0.0,
			"phase": randf_range(0, TAU),
		})
		AudioMan.play_sfx("hazard_warn", -12.0)
	var remove: Array = []
	for orb in _orbs:
		orb["pos"] = orb["pos"] + Vector2(float(orb["dir"]) * float(orb["speed"]) * delta, sin(time * 3.0 + float(orb["phase"])) * 24.0 * delta)
		orb["age"] = float(orb["age"]) + delta
		if orb["pos"].x < -80.0 or orb["pos"].x > W + 80.0 or float(orb["age"]) > 14.0:
			remove.append(orb)
			continue
		for f in _fighters:
			if not is_instance_valid(f) or f.is_ko():
				continue
			var p: Vector2 = f.global_position + Vector2(0, -44)
			if p.distance_to(orb["pos"]) < 34.0:
				if f.hazard_hit(10.0, -float(orb["dir"]), 220.0):
					if fx:
						fx.burst(orb["pos"], def.accent, 1.0)
						fx.ring(orb["pos"], def.grid_color, 70.0)
					remove.append(orb)
					break
	for orb in remove:
		_orbs.erase(orb)

# ------------------------------------------------------------------ queries

func active_hazard_rects() -> Array:
	var out: Array = []
	if def != null and def.hazard == "vent" and _vent_state == "active":
		out.append(vent_hit_rect())
	return out

func telegraph_rects() -> Array:
	var out: Array = []
	if def != null and def.hazard == "vent" and _vent_state == "telegraph":
		out.append(vent_hit_rect())
	return out

func orb_positions() -> Array:
	return _orbs

func vent_state() -> String:
	return _vent_state

func vent_slot_x() -> float:
	return _vent_positions[_vent_slot]

# ------------------------------------------------------------------ draw

func _draw() -> void:
	if def == null:
		return
	_draw_floor()
	_draw_walls()
	_draw_vent_slots()
	_draw_telegraphs()
	_draw_vent_fire()
	_draw_orbs()
	_draw_safe_zone()

func _draw_floor() -> void:
	# Floor slab
	draw_rect(Rect2(0, FLOOR_Y, W, 80), def.floor_color)
	draw_rect(Rect2(0, FLOOR_Y, W, 3), def.grid_color)
	# Perspective-ish grid
	var alpha_step := 0.16
	for i in 11:
		var y := FLOOR_Y + 8.0 + pow(float(i), 1.5) * 2.4
		draw_line(Vector2(0, y), Vector2(W, y), Color(def.grid_color, alpha_step * (1.0 - float(i) / 12.0)), 1.5, true)
	for i in 17:
		var x := float(i) * 80.0
		draw_line(Vector2(x, FLOOR_Y + 2), Vector2(W * 0.5 + (x - W * 0.5) * 1.6, 720.0), Color(def.grid_color, 0.10), 1.2, true)
	# Floor energy pulses
	var pulse_x := fmod(time * 120.0, W)
	draw_rect(Rect2(pulse_x - 60.0, FLOOR_Y + 2, 120.0, 76.0), Color(def.accent, 0.05))

func _draw_walls() -> void:
	# Side pillar bars at the hard bounds.
	for x in [64.0, W - 64.0]:
		draw_rect(Rect2(x - 5, 70, 10, FLOOR_Y - 70), Color(def.glow_color, 0.55))
		draw_rect(Rect2(x - 11, 70, 22, FLOOR_Y - 70), Color(def.glow_color, 0.12))
		for i in 8:
			var y := 90.0 + float(i) * 68.0
			draw_rect(Rect2(x - 8, y, 16, 4), Color(def.accent, 0.5))
	# Ceiling line
	draw_rect(Rect2(64, 68, W - 128, 3), Color(def.glow_color, 0.4))

func _draw_safe_zone() -> void:
	# Outside tint while the arena is smaller than full.
	if warn_level > 0.0 or shrink_active or phase_index > 1:
		var tint := Color(1.0, 0.2, 0.3, 0.05 + 0.05 * sin(time * 6.0) * warn_level)
		# 4 bands outside the safe rect.
		var r := safe_rect
		draw_rect(Rect2(0, 0, r.position.x, H_()), tint)
		draw_rect(Rect2(r.end.x, 0, W - r.end.x, H_()), tint)
		draw_rect(Rect2(r.position.x, 0, r.size.x, r.position.y), tint)
		draw_rect(Rect2(r.position.x, r.end.y, r.size.x, H_() - r.end.y), tint)
	# Border
	var col := def.accent
	var pulse := 0.55
	if warn_level > 0.0:
		col = Color(1.0, 0.85, 0.2, 1.0)
		pulse = 0.5 + 0.5 * absf(sin(time * 9.0))
	elif phase_index > 1:
		col = Color(1.0, 0.35, 0.3, 1.0)
	var a := 0.35 + 0.5 * pulse * (warn_level if warn_level > 0.0 else 0.4)
	var r2 := safe_rect
	# Dashed border
	var dash := 22.0
	var gap := 14.0
	var perimeter_segs := [
		[Vector2(r2.position.x, r2.position.y), Vector2(r2.end.x, r2.position.y)],
		[Vector2(r2.end.x, r2.position.y), Vector2(r2.end.x, r2.end.y)],
		[Vector2(r2.end.x, r2.end.y), Vector2(r2.position.x, r2.end.y)],
		[Vector2(r2.position.x, r2.end.y), Vector2(r2.position.x, r2.position.y)],
	]
	var lw := 4.0 + 3.0 * warn_level
	for seg in perimeter_segs:
		var a0: Vector2 = seg[0]
		var b0: Vector2 = seg[1]
		var seg_len := a0.distance_to(b0)
		var dirn := (b0 - a0).normalized()
		var t := 0.0
		while t < seg_len:
			var t2 := minf(t + dash, seg_len)
			draw_line(a0 + dirn * t, a0 + dirn * t2, Color(col, a), lw, true)
			t = t2 + gap
	# Corner markers
	for corner in [r2.position, Vector2(r2.end.x, r2.position.y), r2.end, Vector2(r2.position.x, r2.end.y)]:
		draw_circle(corner, 7.0, Color(col, a))
		draw_circle(corner, 3.5, Color(1, 1, 1, a))

func H_() -> float:
	return 720.0

func _draw_vent_slots() -> void:
	if def.hazard != "vent":
		return
	for i in _vent_positions.size():
		var x := _vent_positions[i]
		var active_now := _vent_state != "idle" and i == _vent_slot
		draw_rect(Rect2(x - 40, FLOOR_Y - 6, 80, 8), Color(0.1, 0.08, 0.06, 1))
		for s in 5:
			draw_rect(Rect2(x - 36 + s * 16, FLOOR_Y - 4, 10, 4), Color(def.grid_color, 0.8 if active_now else 0.28))

func _draw_telegraphs() -> void:
	for rect: Rect2 in telegraph_rects():
		var pulse := 0.35 + 0.35 * absf(sin(time * 11.0))
		draw_rect(rect, Color(1.0, 0.55, 0.1, 0.10 + 0.10 * pulse))
		# Warning chevrons rising
		for i in 4:
			var y := FLOOR_Y - fmod(time * 160.0 + i * 60.0, 240.0)
			var cx := rect.get_center().x
			draw_colored_polygon(PackedVector2Array([
				Vector2(cx - 16, y), Vector2(cx, y - 12), Vector2(cx + 16, y)]),
				Color(1.0, 0.7, 0.2, 0.5 * pulse))
		draw_rect(rect, Color(1.0, 0.5, 0.1, 0.7), false, 3.0)

func _draw_vent_fire() -> void:
	if _vent_state != "active":
		return
	var rect := vent_hit_rect()
	for i in 8:
		var k := float(i) / 8.0
		var col := Color(1.0, 0.9 - k * 0.5, 0.25 - k * 0.2, 0.55 - k * 0.05)
		var inset := k * 14.0
		draw_rect(Rect2(rect.position.x + inset, rect.position.y + inset * 2, rect.size.x - inset * 2, rect.size.y), col)
	# Sparks
	for i in 6:
		var x := rect.get_center().x + randf_range(-30, 30)
		var y := rect.position.y + randf_range(0, 120)
		draw_circle(Vector2(x, y), randf_range(1.5, 3.5), Color(1, 1, 0.7, 0.8))

func _draw_orbs() -> void:
	for orb in _orbs:
		var pos: Vector2 = orb["pos"]
		var pulse := 0.7 + 0.3 * sin(time * 5.0 + float(orb["phase"]))
		var r := 16.0 * pulse
		draw_circle(pos, r + 8.0, Color(def.accent, 0.10))
		# Rotating diamond
		var rot := time * 2.4 + float(orb["phase"])
		var pts := PackedVector2Array()
		for i in 4:
			pts.append(pos + Vector2(cos(rot + i * PI * 0.5), sin(rot + i * PI * 0.5)) * r)
		draw_colored_polygon(pts, Color(def.glow_color, 0.55))
		draw_circle(pos, r * 0.45, Color(1, 1, 1, 0.85))
		draw_circle(pos, r * 0.2, def.accent)
