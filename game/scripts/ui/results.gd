extends Control
class_name ResultsScreen
## Post-match overlay: outcome banner, score breakdown, online submission
## and navigation back into the loop.

var results: Dictionary = {}
var _submitted := false
var _submit_btn: Button
var _status: Label
var _name_edit: LineEdit
var _score_lbl: Label
var _heading: Label
var _count_tween: Tween
var _ready_for_input := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	AudioMan.play_sfx("ui_click", -8.0)
	_api_connect()
	var t := create_tween()
	t.tween_interval(0.05)
	t.tween_callback(func() -> void: _ready_for_input = true)

func _api_connect() -> void:
	if not API.submit_succeeded.is_connected(_on_submit_ok):
		API.submit_succeeded.connect(_on_submit_ok)
	if not API.submit_failed.is_connected(_on_submit_err):
		API.submit_failed.connect(_on_submit_err)

func setup(p_results: Dictionary) -> void:
	results = p_results
	if not is_node_ready():
		await ready
	_fill()

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := UIStyle.vbox(10)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(560, 0)
	center.add_child(box)

	_heading = UIStyle.label("", 84, UIStyle.COL_TEXT, true)
	_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_heading)

	var sub := UIStyle.label("", 22, UIStyle.COL_TEXT_DIM, false)
	sub.name = "Sub"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	box.add_child(UIStyle.line())

	# Stats table
	var grid := GridContainer.new()
	grid.name = "Stats"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(grid)
	for row in [["FINAL SCORE", "score"], ["KOs", "kos"], ["MAX COMBO", "max_combo"],
			["DAMAGE DEALT", "damage_dealt"], ["TIME SURVIVED", "duration"], ["HP REMAINING", "hp_left"]]:
		var k := UIStyle.label(String(row[0]), 20, UIStyle.COL_TEXT_DIM, false)
		grid.add_child(k)
		var v := UIStyle.label("—", 22, UIStyle.COL_TEXT, true)
		v.name = "V_" + String(row[1])
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.custom_minimum_size = Vector2(180, 0)
		grid.add_child(v)
	_score_lbl = grid.get_node("V_score") as Label

	box.add_child(UIStyle.line())

	# Submission row
	var sub2 := UIStyle.hbox(10)
	sub2.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(sub2)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "YOUR NAME (2-16 chars)"
	_name_edit.max_length = 16
	_name_edit.custom_minimum_size = Vector2(240, 44)
	_name_edit.text = Settings.display_name
	_name_edit.text_changed.connect(func(t: String) -> void:
		Settings.set_display_name(t if t.strip_edges().length() >= 2 else t))
	_name_edit.text_submitted.connect(func(_t: String) -> void: _submit())
	sub2.add_child(_name_edit)
	_submit_btn = UIStyle.button("SUBMIT SCORE", Vector2(190, 44), "secondary")
	_submit_btn.pressed.connect(_submit)
	sub2.add_child(_submit_btn)

	_status = UIStyle.label("", 18, UIStyle.COL_TEXT_DIM, false)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_status)

	box.add_child(UIStyle.line())

	# Navigation
	var nav := UIStyle.hbox(12)
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(nav)
	var rematch := UIStyle.button("REMATCH", Vector2(170, 52))
	rematch.pressed.connect(func() -> void:
		GameState.go("match"))
	nav.add_child(rematch)
	var fs := UIStyle.button("CHANGE FIGHTER", Vector2(200, 52), "secondary")
	fs.pressed.connect(func() -> void:
		GameState.go("fighter_select"))
	nav.add_child(fs)
	var menu := UIStyle.button("MAIN MENU", Vector2(170, 52), "secondary")
	menu.pressed.connect(func() -> void:
		GameState.go("title"))
	nav.add_child(menu)

	var hint := UIStyle.label("ENTER — SUBMIT SCORE", 16, UIStyle.COL_TEXT_DIM, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	rematch.grab_focus.call_deferred()

func _fill() -> void:
	if results.is_empty():
		return
	var victory := bool(results.get("victory", false))
	var draw := bool(results.get("draw", false))
	if draw:
		_heading.text = "DRAW"
		_heading.add_theme_color_override("font_color", UIStyle.COL_AMBER)
		AudioMan.play_sfx("count_beep", -6.0)
	elif victory:
		_heading.text = "VICTORY"
		_heading.add_theme_color_override("font_color", UIStyle.COL_SUCCESS)
		AudioMan.play_sfx("victory", -2.0)
	else:
		_heading.text = "DEFEAT"
		_heading.add_theme_color_override("font_color", UIStyle.COL_DANGER)
		AudioMan.play_sfx("defeat", -3.0)
	_heading.scale = Vector2(1.8, 1.8)
	var ht := create_tween()
	ht.tween_property(_heading, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	var reason := String(results.get("winner_name", ""))
	if draw:
		reason = "BOTH FIGHTERS FELL"
	elif victory:
		reason = "YOU DEFEATED " + reason
	else:
		reason = reason + " WINS"
	_set_sub(reason)

	_set_value("max_combo", str(results.get("max_combo", 0)))
	_set_value("kos", str(results.get("kos", 0)))
	_set_value("damage_dealt", str(results.get("damage_dealt", 0)))
	var dur := float(results.get("duration", 0.0))
	_set_value("duration", "%d:%02d" % [int(dur) / 60, int(dur) % 60])
	_set_value("hp_left", str(results.get("hp_left", 0)))
	_count_score(int(results.get("score", 0)))

	if bool(results.get("draw", false)) or String(results.get("mode", "")) == "demo":
		_submit_btn.disabled = true
		_status.text = ""
		_name_edit.editable = false

	# Intro: block navigation clicks until the heading lands.
	_set_nav_enabled(false)
	var t := create_tween()
	t.tween_interval(0.55)
	t.tween_callback(func() -> void: _set_nav_enabled(true))

func _set_nav_enabled(on: bool) -> void:
	var nav := _find_nav()
	if nav == null:
		return
	var first: Button = null
	for b in nav.get_children():
		if b is Button:
			(b as Button).disabled = not on
			if on and first == null:
				first = b
	if first != null:
		first.grab_focus.call_deferred()

func _find_nav() -> Container:
	for child in get_tree().get_nodes_in_group("results_nav"):
		return child as Container
	# Fallback: search by structure.
	var c := _root_box()
	if c != null:
		for grand in c.get_children():
			if grand is HBoxContainer:
				var b0 := grand.get_child(0) if grand.get_child_count() > 0 else null
				if b0 is Button:
					return grand as Container
	return null

func _root_box() -> Container:
	var cc := get_child(1) as CenterContainer if get_child_count() > 1 else null
	if cc != null and cc.get_child_count() > 0:
		return cc.get_child(0) as Container
	return null

func _set_sub(text: String) -> void:
	# The sub label sits directly under the heading.
	var box := _root_box()
	if box == null:
		return
	for child in box.get_children():
		if child is Label and child.name == "Sub":
			(child as Label).text = text
			return

func _set_value(key: String, text: String) -> void:
	var box := _root_box()
	if box == null:
		return
	var grid := box.get_node_or_null("Stats") as GridContainer
	if grid == null:
		return
	var lbl := grid.get_node_or_null("V_" + key) as Label
	if lbl != null:
		lbl.text = text

func _count_score(target: int) -> void:
	if _score_lbl == null:
		return
	if _count_tween != null and _count_tween.is_valid():
		_count_tween.kill()
	_count_tween = create_tween()
	_count_tween.tween_method(_count_tick, 0.0, float(target), 1.0)
	_count_tween.tween_callback(_count_done.bind())

func _count_tick(v: float) -> void:
	if _score_lbl != null:
		_score_lbl.text = str(int(v))

func _count_done() -> void:
	if _score_lbl != null:
		_score_lbl.text = str(results.get("score", 0))
		_score_lbl.add_theme_color_override("font_color", UIStyle.COL_AMBER)

func _submit() -> void:
	if _submitted:
		return
	var payload := GameState.build_score_payload(results)
	if payload.is_empty():
		_status.text = "DEMO MATCHES ARE NOT SUBMITTED"
		_status.add_theme_color_override("font_color", UIStyle.COL_TEXT_DIM)
		return
	var validation: String = API.validate_payload(payload) if API.has_method("validate_payload") else ""
	if validation != "":
		_status.text = "INVALID: " + validation
		_status.add_theme_color_override("font_color", UIStyle.COL_DANGER)
		AudioMan.play_sfx("submit_err", -4.0)
		return
	_submitted = true
	_submit_btn.disabled = true
	_name_edit.editable = false
	_status.text = "SUBMITTING…"
	_status.add_theme_color_override("font_color", UIStyle.COL_CYAN)
	Settings.set_display_name(String(payload["player_name"]))
	API.submit_score(payload)

func _on_submit_ok(result: Dictionary) -> void:
	if not is_instance_valid(self):
		return
	_submit_btn.text = "SUBMITTED"
	_status.text = "SAVED · RANK #%s" % str(int(result.get("rank", 0)))
	_status.add_theme_color_override("font_color", UIStyle.COL_SUCCESS)
	AudioMan.play_sfx("submit_ok", -4.0)

func _on_submit_err(reason: String, http_code: int) -> void:
	if not is_instance_valid(self):
		return
	_submitted = false
	_submit_btn.disabled = false
	if reason.begins_with("invalid payload"):
		_status.text = "LOCAL CHECK · " + reason.substr(16, 60).to_upper()
		_status.add_theme_color_override("font_color", UIStyle.COL_DANGER)
	elif http_code == 409:
		_status.text = "ALREADY SAVED · " + reason.substr(0, 60)
		_status.add_theme_color_override("font_color", UIStyle.COL_AMBER)
	else:
		_status.text = "NOT SAVED (%d) — %s · TRY AGAIN" % [http_code, reason.substr(0, 48)]
		_status.add_theme_color_override("font_color", UIStyle.COL_DANGER)
	AudioMan.play_sfx("submit_err", -4.0)

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_for_input:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not _name_edit.has_focus():
				_submit()
				get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if API.submit_succeeded.is_connected(_on_submit_ok):
		API.submit_succeeded.disconnect(_on_submit_ok)
	if API.submit_failed.is_connected(_on_submit_err):
		API.submit_failed.disconnect(_on_submit_err)
