extends Node2D
class_name FighterArt
## Procedural, articulated fighter visual. No sprites: limbs, torso, helmet
## and effects are drawn per-frame from the parent fighter's state. Collision
## lives on the Fighter body, never here.

var stats: FighterStats
var fighter_index := 0

# Live pose inputs (written by Fighter._push_art_params).
var facing := 1
var state: Fighter.State = Fighter.State.IDLE
var attack_kind := ""
var attack_phase := 0
var phase_k := 0.0
var yeet_charge := 0.0
var speed_k := 0.0
var grounded := true
var hurt_k := 0.0
var ko_k := 0.0
var victory_k := 0.0
var dash_k := 0.0
var guard_k := 0.0
var paused := false

var _time := 0.0
var _flash := 0.0
var _time_off := 0.0

# Body proportions (set in setup from body_type).
var _shoulder := 12.0
var _limb_w := 7.5
var _torso_w := 26.0
var _head_r := 10.5
var _hip_y := -44.0
var _shoulder_y := -74.0
var _head_y := -87.0

const OUTLINE := Color(0.02, 0.02, 0.07, 1.0)

func setup(p_stats: FighterStats, p_index: int) -> void:
	stats = p_stats
	fighter_index = p_index
	_time_off = float(p_index) * 1.73
	match stats.body_type:
		1:  # BRICK - heavy frame
			_shoulder = 17.0
			_limb_w = 11.5
			_torso_w = 40.0
			_head_r = 11.0
			_hip_y = -42.0
			_shoulder_y = -72.0
			_head_y = -85.0
		2:  # PHANTOM - slight, floating
			_shoulder = 11.0
			_limb_w = 6.5
			_torso_w = 23.0
			_head_r = 10.0
		3:  # CHAOS - wiry + spikes
			_shoulder = 12.5
			_limb_w = 8.0
			_torso_w = 27.0
		4:  # TITAN - massive
			_shoulder = 16.0
			_limb_w = 11.0
			_torso_w = 38.0
			_head_r = 11.5
			_hip_y = -46.0
			_shoulder_y = -78.0
			_head_y = -91.0
		5:  # GLITCH - lean tech
			_shoulder = 11.5
			_limb_w = 7.0
			_torso_w = 24.0
	queue_redraw()

func set_flash(v: float) -> void:
	_flash = clampf(v, 0.0, 1.0)

func _process(delta: float) -> void:
	if paused:
		return
	_time += delta
	_flash = maxf(0.0, _flash - delta * 5.5)
	queue_redraw()

# ------------------------------------------------------------------ draw

func _draw() -> void:
	if stats == null:
		return
	_render(Color(1, 1, 1, 1))
	if _flash > 0.01:
		_render(Color(1, 1, 1, _flash))

func _c(c: Color) -> Color:
	return c * _mul

var _mul := Color(1, 1, 1, 1)

func _render(cm: Color) -> void:
	_mul = cm
	var t := _time + _time_off
	var prim := _c(stats.primary)
	var second := _c(stats.secondary)
	var accent := _c(stats.accent)
	var dark_prim := prim.darkened(0.35)
	var dark_second := second.darkened(0.35)

	# ---- pose parameters (all angles: 0 = limb hangs down, + rotates toward +x / forward)
	var bob := 0.0
	var lean := 0.0
	var a1f := 0.2    # front arm upper/fore
	var a2f := 0.25
	var a1b := -0.15  # back arm
	var a2b := -0.2
	var l1f := 0.05   # front leg upper/fore
	var l2f := 0.0
	var l1b := -0.05
	var l2b := 0.0
	var charge_ball := 0.0

	match state:
		Fighter.State.IDLE:
			bob = sin(t * 2.3) * 1.6
			lean = 0.03
			a1f = 0.2 + sin(t * 2.3) * 0.06
			a2f = 0.3
			a1b = -0.18 - sin(t * 2.3) * 0.05
			a2b = -0.25
			l1f = 0.1
			l1b = -0.1
		Fighter.State.RUN:
			var ph := t * 13.0
			var sk := clampf(speed_k, 0.25, 1.3)
			l1f = 0.85 * sk * sin(ph)
			l2f = maxf(0.0, 0.5 + 0.5 * sin(ph + 2.2))
			l1b = -0.85 * sk * sin(ph)
			l2b = maxf(0.0, 0.5 + 0.5 * sin(ph + 2.2 + PI))
			a1f = -0.55 * sk * sin(ph)
			a2f = 0.55
			a1b = 0.55 * sk * sin(ph)
			a2b = 0.5
			lean = 0.16 * sk
			bob = -absf(sin(ph)) * 2.2 * sk
		Fighter.State.JUMP:
			lean = 0.08
			l1f = 0.55
			l2f = 1.0
			l1b = 0.1
			l2b = 0.5
			a1f = -0.7
			a2f = 0.4
			a1b = -1.0
			a2b = 0.3
		Fighter.State.FALL:
			lean = 0.05
			l1f = 0.35
			l2f = 0.35
			l1b = -0.15
			l2b = 0.15
			a1f = -1.2 + sin(t * 9.0) * 0.1
			a2f = 0.5
			a1b = -1.45
			a2b = 0.4
		Fighter.State.DASH:
			lean = 0.5
			bob = -3.0
			l1f = 0.95
			l2f = 0.25
			l1b = -0.9
			l2b = 0.85
			a1f = -2.3
			a2f = -0.25
			a1b = -2.5
			a2b = -0.2
		Fighter.State.GUARD:
			var gk := clampf(guard_k, 0.0, 1.0)
			a1f = lerpf(0.2, 1.0, gk)
			a2f = lerpf(0.3, -1.7, gk)
			a1b = lerpf(-0.18, 0.75, gk)
			a2b = lerpf(-0.25, -1.5, gk)
			lean = lerpf(0.03, -0.06, gk)
			l1f = 0.28
			l1b = -0.28
			bob = -1.0 * gk
		Fighter.State.ATTACK:
			var pose := _attack_pose(t)
			a1f = pose["a1f"]
			a2f = pose["a2f"]
			a1b = pose["a1b"]
			a2b = pose["a2b"]
			l1f = pose["l1f"]
			l2f = pose["l2f"]
			l1b = pose["l1b"]
			l2b = pose["l2b"]
			lean = pose["lean"]
			bob = pose["bob"]
			charge_ball = pose["charge"]
		Fighter.State.HURT:
			var hk := clampf(hurt_k, 0.0, 1.0)
			lean = -0.3 + hk * 0.12
			bob = 2.0
			a1f = -1.5 + sin(t * 28.0) * 0.35
			a2f = -0.6
			a1b = -1.15 + cos(t * 24.0) * 0.3
			a2b = -0.5
			l1f = 0.5
			l2f = 0.3
			l1b = -0.35
			l2b = 0.55
		Fighter.State.KO:
			var kk := clampf(ko_k, 0.0, 1.0)
			lean = -0.1
			a1f = lerpf(0.2, -1.9, kk)
			a2f = lerpf(0.3, -0.4, kk)
			a1b = lerpf(-0.18, -2.3, kk)
			a2b = lerpf(-0.25, -0.3, kk)
			l1f = lerpf(0.1, 0.55, kk)
			l1b = lerpf(-0.1, -0.35, kk)
			l2f = 0.2
			l2b = 0.3
		Fighter.State.VICTORY:
			var vk := clampf(victory_k, 0.0, 1.0)
			bob = -absf(sin(t * 5.0)) * 4.0 * vk
			a1f = lerpf(0.2, -2.75, vk) + sin(t * 5.0) * 0.12
			a2f = lerpf(0.3, -0.25, vk)
			a1b = lerpf(-0.18, -2.95, vk) - sin(t * 5.0) * 0.12
			a2b = lerpf(-0.25, -0.2, vk)
			l1f = 0.18
			l1b = -0.18
			lean = 0.0

	# ---- global transform: flip by facing, fall for KO
	var ko_rot := -ko_k * PI * 0.5
	var rot := (lean * float(facing)) + (ko_rot * float(facing))
	draw_set_transform(Vector2(0, bob), rot, Vector2(float(facing), 1.0))

	# ---- limbs
	var hip := Vector2(0, _hip_y)
	var sh := Vector2(0, _shoulder_y)
	var leg_w := _limb_w * (1.15 if stats.body_type in [1, 4] else 1.0)
	var arm_w := _limb_w
	var thigh := absf(_hip_y) * 0.52
	var shin := absf(_hip_y) * 0.48
	var upper_arm := 16.0
	var fore_arm := 16.0

	# Back leg & arm (darker, drawn first)
	_limb(hip + Vector2(-3, 0), l1b, thigh, l2b, shin, leg_w * 0.9, dark_prim)
	_limb(sh + Vector2(-_shoulder * 0.55, 2), a1b, upper_arm, a2b, fore_arm, arm_w * 0.85, dark_prim)
	# Front leg
	_limb(hip + Vector2(3, 0), l1f, thigh, l2f, shin, leg_w, prim)

	# Torso (rounded slab)
	var torso_rect := Rect2(Vector2(-_torso_w * 0.5, _shoulder_y), Vector2(_torso_w, _hip_y - _shoulder_y))
	var torso_sb := StyleBoxFlat.new()
	torso_sb.bg_color = second
	torso_sb.set_corner_radius_all(7)
	torso_sb.border_color = OUTLINE
	torso_sb.set_border_width_all(2)
	draw_style_box(torso_sb, torso_rect)
	# Chest accent stripe + energy core
	draw_rect(Rect2(Vector2(-_torso_w * 0.5 + 3, _shoulder_y + 6), Vector2(_torso_w - 6, 4)), dark_second)
	var pulse := 0.6 + 0.4 * sin(t * 4.0)
	var core_r := 4.2 * pulse
	draw_circle(Vector2(0, _shoulder_y + 14), core_r + 2.5, _c(Color(stats.accent, 0.35 * pulse)))
	draw_circle(Vector2(0, _shoulder_y + 14), core_r, accent)

	# Body-type signatures
	match stats.body_type:
		1: # BRICK: rivets + visor slab
			draw_circle(Vector2(-_torso_w * 0.5 + 5, _shoulder_y + 5), 2.2, dark_second)
			draw_circle(Vector2(_torso_w * 0.5 - 5, _shoulder_y + 5), 2.2, dark_second)
		2: # PHANTOM: flowing scarf ribbons
			_scarf(t, sh + Vector2(0, 4), second, accent)
		3: # CHAOS: head spikes handled later; torso slash marks
			draw_line(Vector2(-6, _shoulder_y + 18), Vector2(4, _shoulder_y + 24), accent, 2.5, true)
			draw_line(Vector2(-4, _shoulder_y + 10), Vector2(7, _shoulder_y + 16), accent, 2.0, true)
		4: # TITAN: pauldrons + belt
			draw_circle(sh + Vector2(-_shoulder - 2, 4), 9.5, OUTLINE)
			draw_circle(sh + Vector2(-_shoulder - 2, 4), 7.5, second)
			draw_circle(sh + Vector2(_shoulder + 2, 4), 9.5, OUTLINE)
			draw_circle(sh + Vector2(_shoulder + 2, 4), 7.5, prim)
			draw_rect(Rect2(Vector2(-_torso_w * 0.5 + 2, _hip_y - 6), Vector2(_torso_w - 4, 5)), dark_second)
		5: # GLITCH: circuit lines
			draw_line(Vector2(-_torso_w * 0.5 + 4, _shoulder_y + 10), Vector2(-4, _shoulder_y + 10), accent, 1.6, true)
			draw_line(Vector2(-4, _shoulder_y + 10), Vector2(-4, _hip_y - 4), accent, 1.6, true)
			draw_line(Vector2(4, _shoulder_y + 8), Vector2(6, _hip_y - 4), dark_second, 1.6, true)

	# Head (helmet + visor)
	var head_c := Vector2(0, _head_y)
	draw_circle(head_c, _head_r + 2.0, OUTLINE)
	draw_circle(head_c, _head_r, second)
	# Visor toward facing (+x in body space)
	var visor := Rect2(Vector2(1, _head_y - 3.0), Vector2(_head_r - 0.5, 6.0))
	var visor_sb := StyleBoxFlat.new()
	visor_sb.bg_color = Color(stats.accent, 0.95)
	visor_sb.set_corner_radius_all(3)
	draw_style_box(visor_sb, visor)
	# Helmet top plate
	draw_arc(head_c, _head_r - 2.0, PI * 1.05, PI * 1.95, 12, dark_second, 3.0, true)

	match stats.body_type:
		3: # CHAOS spikes
			var spike_base := head_c + Vector2(-4, -_head_r + 1)
			for i in 3:
				var bx := spike_base.x + i * 5.0
				var tip := Vector2(bx + 2.0 + sin(t * 7.0 + i) * 1.5, spike_base.y - 7.0 - float(i % 2) * 3.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(bx, spike_base.y), tip, Vector2(bx + 4.5, spike_base.y)]), prim)
		5: # GLITCH antenna
			var base := head_c + Vector2(2, -_head_r)
			draw_line(base, base + Vector2(4, -11), _c(Color(0.7, 0.8, 0.9, 1)), 2.0, true)
			draw_circle(base + Vector2(4, -11), 2.6 + pulse, _c(Color(stats.accent, 0.9)))

	# Front arm (topmost)
	_limb(sh + Vector2(_shoulder * 0.55, 2), a1f, 16.0, a2f, 16.0, arm_w, prim)

	# YEET charge ball between the hands
	if charge_ball > 0.01:
		var mid_a := (a1f + a1b) * 0.5
		var hand := sh + Vector2(sin(mid_a), cos(mid_a)) * 20.0
		var ball_r := 5.0 + 20.0 * charge_ball
		draw_circle(hand, ball_r + 6.0, _c(Color(stats.accent, 0.22 * charge_ball)))
		draw_circle(hand, ball_r, Color(1, 1, 1, (0.35 + 0.5 * charge_ball) * _mul.a))
		draw_circle(hand, ball_r * 0.45, _c(stats.accent))

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_mul = Color(1, 1, 1, 1)

# ------------------------------------------------------------------ pieces

func _limb(root: Vector2, a1: float, len1: float, a2: float, len2: float, w: float, col: Color) -> void:
	var p1 := root + Vector2(sin(a1), cos(a1)) * len1
	var p2 := p1 + Vector2(sin(a1 + a2), cos(a1 + a2)) * len2
	# Outline pass
	draw_line(root, p1, OUTLINE, w + 3.0, true)
	draw_line(p1, p2, OUTLINE, w + 3.0, true)
	draw_circle(root, (w + 3.0) * 0.5, OUTLINE)
	draw_circle(p1, (w + 3.0) * 0.5, OUTLINE)
	draw_circle(p2, (w + 3.0) * 0.5, OUTLINE)
	# Fill pass
	draw_line(root, p1, col, w, true)
	draw_line(p1, p2, col, w, true)
	draw_circle(root, w * 0.5, col)
	draw_circle(p1, w * 0.5, col)
	draw_circle(p2, w * 0.5, col)

func _scarf(t: float, anchor: Vector2, col: Color, accent: Color) -> void:
	for ribbon in 2:
		var pts := PackedVector2Array()
		var w0 := 6.0 - ribbon * 2.0
		for i in 6:
			var fl := float(i)
			var wave := sin(t * 6.0 + fl * 1.1 + float(ribbon) * 2.0 + _time_off) * (2.0 + fl * 1.4)
			pts.append(anchor + Vector2(-fl * 7.0 - ribbon * 3.0, wave + fl * 1.8 + ribbon * 2.0))
		for i in pts.size() - 1:
			var w_seg := w0 * (1.0 - float(i) / float(pts.size()))
			draw_line(pts[i], pts[i + 1], Color(col, 0.9), w_seg, true)
		draw_circle(pts[0], w0 * 0.5, accent)

func _attack_pose(t: float) -> Dictionary:
	## Piecewise pose for light / heavy / yeet across startup/active/recovery.
	var out := {
		"a1f": 0.2, "a2f": 0.3, "a1b": -0.18, "a2b": -0.25,
		"l1f": 0.1, "l2f": 0.0, "l1b": -0.1, "l2b": 0.0,
		"lean": 0.05, "bob": 0.0, "charge": 0.0,
	}
	var k := clampf(phase_k, 0.0, 1.0)
	match attack_kind:
		"light":
			match attack_phase:
				0:
					out["a1f"] = lerpf(0.2, -1.5, k)
					out["a2f"] = lerpf(0.3, -0.7, k)
					out["a1b"] = lerpf(-0.18, 0.7, k)
					out["lean"] = lerpf(0.03, -0.05, k)
				1:
					var e := 1.0 - pow(1.0 - k, 3.0)
					out["a1f"] = lerpf(-1.5, 1.5, e)
					out["a2f"] = lerpf(-0.7, 0.02, e)
					out["a1b"] = lerpf(0.7, -0.9, e)
					out["lean"] = lerpf(-0.05, 0.18, e)
					out["l1f"] = 0.35
					out["l1b"] = -0.3
				2:
					out["a1f"] = lerpf(1.5, 0.2, k)
					out["a2f"] = lerpf(0.02, 0.3, k)
					out["a1b"] = lerpf(-0.9, -0.18, k)
					out["lean"] = lerpf(0.18, 0.03, k)
		"heavy":
			match attack_phase:
				0:
					out["a1f"] = lerpf(0.2, -2.35, k)
					out["a2f"] = lerpf(0.3, -0.35, k)
					out["a1b"] = lerpf(-0.18, -2.5, k)
					out["a2b"] = lerpf(-0.25, -0.3, k)
					out["bob"] = 3.0 * k
					out["lean"] = lerpf(0.03, -0.12, k)
				1:
					var e := 1.0 - pow(1.0 - k, 4.0)
					out["a1f"] = lerpf(-2.35, 1.25, e)
					out["a2f"] = lerpf(-0.35, 0.4, e)
					out["a1b"] = lerpf(-2.5, 1.05, e)
					out["a2b"] = lerpf(-0.3, 0.45, e)
					out["lean"] = lerpf(-0.12, 0.22, e)
					out["bob"] = lerpf(3.0, -1.0, e)
					out["l1f"] = 0.4
					out["l1b"] = -0.35
				2:
					out["a1f"] = lerpf(1.25, 0.2, k)
					out["a2f"] = lerpf(0.4, 0.3, k)
					out["a1b"] = lerpf(1.05, -0.18, k)
					out["a2b"] = lerpf(0.45, -0.25, k)
					out["lean"] = lerpf(0.22, 0.03, k)
		_:
			# YEET: dramatic charge, huge throw.
			match attack_phase:
				0:
					out["a1f"] = lerpf(0.2, -2.25, k)
					out["a2f"] = lerpf(0.3, -0.45, k)
					out["a1b"] = lerpf(-0.18, -2.45, k)
					out["a2b"] = lerpf(-0.25, -0.4, k)
					out["bob"] = 4.0 * k
					out["lean"] = lerpf(0.03, -0.16, k)
					out["charge"] = k
					out["l1f"] = 0.3
					out["l1b"] = -0.3
				1:
					var e := 1.0 - pow(1.0 - k, 5.0)
					out["a1f"] = lerpf(-2.25, 1.55, e)
					out["a2f"] = lerpf(-0.45, 0.08, e)
					out["a1b"] = lerpf(-2.45, 1.35, e)
					out["a2b"] = lerpf(-0.4, 0.12, e)
					out["lean"] = lerpf(-0.16, 0.34, e)
					out["bob"] = lerpf(4.0, -4.0, e)
					out["charge"] = maxf(0.0, 1.0 - k * 3.0)
					out["l1f"] = 0.55
					out["l1b"] = -0.45
				2:
					out["a1f"] = lerpf(1.55, 0.2, k)
					out["a2f"] = lerpf(0.08, 0.3, k)
					out["a1b"] = lerpf(1.35, -0.18, k)
					out["lean"] = lerpf(0.34, 0.03, k)
					out["bob"] = lerpf(-4.0, 0.0, k)
	return out
