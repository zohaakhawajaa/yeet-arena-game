extends CanvasLayer
class_name MatchHUD
## In-match overlay: health/cooldown bars, clock, combo counter,
## announcement banners, danger vignette and the demo badge.

var match_ref: Node = null
var _root: Control
var _name_p: Label
var _name_o: Label
var _hp_p: ProgressBar
var _hp_o: ProgressBar
var _yeet_p: ProgressBar
var _yeet_o: ProgressBar
var _hp_text_p: Label
var _hp_text_o: Label
var _timer: Label
var _phase: Label
var _combo: Label
var _announce: Label
var _announce_tween: Tween
var _banner: Label
var _banner_sub: Label
var _demo_badge: Label
var _danger_rects: Array = []
var _disp_hp := [1.0, 1.0]
var _disp_yeet := [1.0, 1.0]
var _last_combo := 0

const PHASE_NAMES: Array[String] = ["OPEN", "TIGHT", "CLOSED", "FINAL"]

func _ready() -> void:
	layer = 10
	_build()

func setup(p_match: Node) -> void:
	match_ref = p_match
	var pf: Fighter = match_ref.player_fighter
	var of: Fighter = match_ref.opp_fighter
	_name_p.text = pf.stats.display_name.to_upper()
	_name_o.text = of.stats.display_name.to_upper()
	_name_p.add_theme_color_override("font_color", pf.stats.accent)
	_name_o.add_theme_color_override("font_color", of.stats.accent)
	if GameState.is_demo():
		_demo_badge.visible = true

func _build() -> void:
	_root = Control.new()
	_root.name = "Root"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# ---- top bar -------------------------------------------------------
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 28.0
	top.offset_right = -28.0
	top.offset_top = 16.0
	top.offset_bottom = 130.0
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(top)

	var left := _make_fighter_panel(true)
	top.add_child(left)
	top.add_child(UIStyle.spacer_x(10))
	var center := _make_clock_panel()
	top.add_child(center)
	top.add_child(UIStyle.spacer_x(10))
	var right := _make_fighter_panel(false)
	top.add_child(right)

	# ---- combo ---------------------------------------------------------
	_combo = UIStyle.label("x0", 72, UIStyle.COL_AMBER, true)
	_combo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	_combo.offset_left = -260.0
	_combo.offset_right = -60.0
	_combo.offset_top = 240.0
	_combo.offset_bottom = 330.0
	_combo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo.visible = false
	_root.add_child(_combo)

	# ---- announcement --------------------------------------------------
	_announce = UIStyle.label("", 76, UIStyle.COL_TEXT, true)
	_announce.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_announce.offset_left = -500.0
	_announce.offset_right = 500.0
	_announce.offset_top = -70.0
	_announce.offset_bottom = 60.0
	_announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_announce)

	# ---- result banner -------------------------------------------------
	_banner = UIStyle.label("", 96, UIStyle.COL_TEXT, true)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -500.0
	_banner.offset_right = 500.0
	_banner.offset_top = -150.0
	_banner.offset_bottom = -20.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.visible = false
	_root.add_child(_banner)

	_banner_sub = UIStyle.label("", 26, UIStyle.COL_TEXT_DIM, false)
	_banner_sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner_sub.offset_left = -500.0
	_banner_sub.offset_right = 500.0
	_banner_sub.offset_top = -10.0
	_banner_sub.offset_bottom = 40.0
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.visible = false
	_root.add_child(_banner_sub)

	# ---- danger vignette -----------------------------------------------
	for i in 4:
		var r := ColorRect.new()
		r.color = Color(1.0, 0.18, 0.24, 0.0)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_root.add_child(r)
		_danger_rects.append(r)
	_place_danger_rects()

	# ---- demo badge ----------------------------------------------------
	_demo_badge = UIStyle.label("DEMO — PRESS ANY KEY", 22, UIStyle.COL_CYAN, false)
	_demo_badge.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_demo_badge.offset_left = 32.0
	_demo_badge.offset_top = -52.0
	_demo_badge.offset_right = 420.0
	_demo_badge.offset_bottom = -20.0
	_demo_badge.visible = false
	_root.add_child(_demo_badge)

func _make_fighter_panel(is_left: bool) -> Control:
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.size_flags_stretch_ratio = 1.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_lbl := UIStyle.label("FIGHTER", 24, UIStyle.COL_TEXT, true)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_left else HORIZONTAL_ALIGNMENT_RIGHT
	box.add_child(name_lbl)

	var hp := ProgressBar.new()
	hp.custom_minimum_size = Vector2(0, 24)
	hp.show_percentage = false
	hp.max_value = 1.0
	hp.value = 1.0
	hp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_bar(hp, UIStyle.COL_SUCCESS, UIStyle.COL_DANGER)
	box.add_child(hp)

	var sub := HBoxContainer.new()
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hp_text := UIStyle.label("100 / 100", 16, UIStyle.COL_TEXT_DIM, false)
	hp_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if is_left else HORIZONTAL_ALIGNMENT_RIGHT
	sub.add_child(hp_text)
	box.add_child(sub)

	var yeet := ProgressBar.new()
	yeet.custom_minimum_size = Vector2(0, 9)
	yeet.show_percentage = false
	yeet.max_value = 1.0
	yeet.value = 1.0
	yeet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style_bar(yeet, UIStyle.COL_CYAN, UIStyle.COL_EDGE)
	box.add_child(yeet)

	if is_left:
		_name_p = name_lbl
		_hp_p = hp
		_hp_text_p = hp_text
		_yeet_p = yeet
	else:
		_name_o = name_lbl
		_hp_o = hp
		_hp_text_o = hp_text
		_yeet_o = yeet
	return box

func _style_bar(bar: ProgressBar, fill: Color, back: Color) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(back, 0.55)
	bg.set_corner_radius_all(3)
	bg.content_margin_left = 2
	bg.content_margin_right = 2
	bg.content_margin_top = 2
	bg.content_margin_bottom = 2
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)

func _make_clock_panel() -> Control:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_timer = UIStyle.label("1:00", 52, UIStyle.COL_TEXT, true)
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_timer)

	_phase = UIStyle.label("OPEN", 16, UIStyle.COL_CYAN, false)
	_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_phase)
	return box

func _place_danger_rects() -> void:
	var w := 1280.0
	var h := 720.0
	var t := 90.0
	# left, right, top, bottom strips
	(_danger_rects[0] as ColorRect).position = Vector2.ZERO
	(_danger_rects[0] as ColorRect).size = Vector2(t, h)
	(_danger_rects[1] as ColorRect).position = Vector2(w - t, 0)
	(_danger_rects[1] as ColorRect).size = Vector2(t, h)
	(_danger_rects[2] as ColorRect).position = Vector2.ZERO
	(_danger_rects[2] as ColorRect).size = Vector2(w, t)
	(_danger_rects[3] as ColorRect).position = Vector2(0, h - t)
	(_danger_rects[3] as ColorRect).size = Vector2(w, t)

# ------------------------------------------------------------------ per frame

func update_hud(delta: float) -> void:
	if match_ref == null:
		return
	var pf: Fighter = match_ref.player_fighter
	var of: Fighter = match_ref.opp_fighter
	if pf == null or of == null:
		return

	# Health
	var pf_frac := pf.hp / maxf(pf.max_hp, 1.0)
	var of_frac := of.hp / maxf(of.max_hp, 1.0)
	_disp_hp[0] = lerpf(_disp_hp[0], pf_frac, minf(1.0, delta * 9.0))
	_disp_hp[1] = lerpf(_disp_hp[1], of_frac, minf(1.0, delta * 9.0))
	_hp_p.value = _disp_hp[0]
	_hp_o.value = _disp_hp[1]
	_hp_text_p.text = "%d / %d" % [int(round(pf.hp)), int(round(pf.max_hp))]
	_hp_text_o.text = "%d / %d" % [int(round(of.hp)), int(round(of.max_hp))]

	# YEET cooldowns (fraction ready)
	var p_cd := pf.stats.yeet_cooldown
	var o_cd := of.stats.yeet_cooldown
	var py := 0.0 if p_cd <= 0.0 else 1.0 - clampf(pf.yeet_cd / p_cd, 0.0, 1.0)
	var oy := 0.0 if o_cd <= 0.0 else 1.0 - clampf(of.yeet_cd / o_cd, 0.0, 1.0)
	_disp_yeet[0] = lerpf(_disp_yeet[0], py, minf(1.0, delta * 12.0))
	_disp_yeet[1] = lerpf(_disp_yeet[1], oy, minf(1.0, delta * 12.0))
	_yeet_p.value = _disp_yeet[0]
	_yeet_o.value = _disp_yeet[1]

	# Clock
	var secs := int(ceilf(match_ref.time_left))
	_timer.text = "%d:%02d" % [secs / 60, secs % 60]
	if match_ref.time_left <= 10.0:
		_timer.add_theme_color_override("font_color", UIStyle.COL_DANGER)
		_timer.add_theme_color_override("font_outline_color", Color(1, 0.2, 0.3, 0.35 * absf(sin(Time.get_ticks_msec() / 200.0))))
	else:
		_timer.add_theme_color_override("font_color", UIStyle.COL_TEXT)

	# Phase
	var p_idx: int = match_ref.phase_index()
	var phase_txt := PHASE_NAMES[clampi(p_idx - 1, 0, PHASE_NAMES.size() - 1)]
	_phase.text = "PHASE %d · %s" % [p_idx, phase_txt]
	_phase.add_theme_color_override("font_color", UIStyle.COL_AMBER if p_idx > 1 else UIStyle.COL_CYAN)

	# Combo
	var combo: int = pf.combo
	if combo >= 2:
		if not _combo.visible or combo != _last_combo:
			_combo.text = "x%d" % combo
			if combo != _last_combo:
				_combo.scale = Vector2(1.35, 1.35)
				var tw := create_tween()
				tw.tween_property(_combo, "scale", Vector2.ONE, 0.14)
			_combo.visible = true
			_combo.add_theme_color_override("font_color",
				UIStyle.COL_DANGER if combo >= 10 else (UIStyle.COL_AMBER if combo >= 5 else UIStyle.COL_CYAN))
	else:
		_combo.visible = false
	_last_combo = combo

	# Danger vignette
	var in_danger: bool = match_ref.fighter_in_danger(pf)
	if in_danger:
		var pulse := 0.10 + 0.08 * absf(sin(Time.get_ticks_msec() / 160.0))
		for r in _danger_rects:
			(r as ColorRect).color = Color(1.0, 0.2, 0.26, pulse)
	else:
		for r in _danger_rects:
			(r as ColorRect).color.a = maxf(0.0, (r as ColorRect).color.a - delta * 2.5)

	# Low HP heartbeat on own bar
	if pf.hp / maxf(pf.max_hp, 1.0) <= 0.25 and pf.hp > 0.0:
		var hp_col := UIStyle.COL_DANGER.lerp(Color(1, 1, 1), 0.35 + 0.35 * absf(sin(Time.get_ticks_msec() / 140.0)))
		_hp_p.add_theme_stylebox_override("fill", _bar_stylebox(hp_col))

func _bar_stylebox(col: Color) -> StyleBoxFlat:
	var fg := StyleBoxFlat.new()
	fg.bg_color = col
	fg.set_corner_radius_all(3)
	return fg

# ------------------------------------------------------------------ banners

func announce(text: String, color: Color, duration: float) -> void:
	_announce.text = text
	_announce.add_theme_color_override("font_color", color)
	_announce.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	_announce.scale = Vector2(1.45, 1.45)
	_announce.modulate.a = 1.0
	if _announce_tween != null and _announce_tween.is_valid():
		_announce_tween.kill()
	_announce_tween = create_tween()
	_announce_tween.tween_property(_announce, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_announce_tween.parallel().tween_property(_announce, "modulate:a", 1.0, 0.1)
	_announce_tween.tween_interval(duration)
	_announce_tween.tween_property(_announce, "modulate:a", 0.0, 0.3)

func show_result_banner(victory: Variant, reason: String) -> void:
	var text := "DRAW"
	var col := UIStyle.COL_AMBER
	if victory is bool:
		if victory:
			text = "VICTORY"
			col = UIStyle.COL_SUCCESS
		else:
			text = "DEFEAT"
			col = UIStyle.COL_DANGER
	_banner.text = text
	_banner.add_theme_color_override("font_color", col)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
	_banner.visible = true
	_banner.modulate.a = 0.0
	_banner.scale = Vector2(2.0, 2.0)
	_banner_sub.text = reason
	_banner_sub.visible = true
	_banner_sub.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(1.6)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_hide_banner.bind())
	_banner_sub.modulate = Color(1, 1, 1, 1)
	var tw2 := create_tween()
	tw2.tween_interval(0.25)
	tw2.tween_property(_banner_sub, "modulate:a", 1.0, 0.2)

func _hide_banner() -> void:
	_banner.visible = false
	_banner_sub.visible = false
