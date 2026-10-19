extends Control
class_name PauseMenu
## In-match pause overlay. Built in code, processes while the tree is paused.

var _resume_btn: Button
var _settings_box: Control

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := UIStyle.vbox(14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := UIStyle.title("PAUSED", 56, UIStyle.COL_CYAN)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	box.add_child(UIStyle.line())

	_resume_btn = UIStyle.button("RESUME")
	_resume_btn.pressed.connect(resume)
	box.add_child(_resume_btn)

	var restart := UIStyle.button("RESTART MATCH", Vector2(240, 54), "secondary")
	restart.pressed.connect(_restart)
	box.add_child(restart)

	var settings_btn := UIStyle.button("SETTINGS", Vector2(240, 54), "secondary")
	settings_btn.pressed.connect(_toggle_settings)
	box.add_child(settings_btn)

	_settings_box = _build_settings()
	_settings_box.visible = false
	box.add_child(_settings_box)

	var menu := UIStyle.button("QUIT TO MENU", Vector2(240, 54), "danger")
	menu.pressed.connect(_to_menu)
	box.add_child(menu)

	box.add_child(UIStyle.line())
	var hint := UIStyle.label("ESC — RESUME", 18, UIStyle.COL_TEXT_DIM, false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	_resume_btn.grab_focus.call_deferred()

func _build_settings() -> Control:
	var box := UIStyle.vbox(8)
	box.alignment = BoxContainer.ALIGNMENT_CENTER

	box.add_child(_slider_row("MASTER", "master_volume"))
	box.add_child(_slider_row("MUSIC", "music_volume"))
	box.add_child(_slider_row("SFX", "sfx_volume"))

	var diff := UIStyle.label("DIFFICULTY", 18, UIStyle.COL_TEXT_DIM, false)
	diff.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(diff)
	var row := UIStyle.hbox(8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for d in ["easy", "normal", "hard"]:
		var b := UIStyle.button(d.to_upper(), Vector2(120, 40), "secondary" if Settings.difficulty != d else "primary")
		var d_name: String = d
		b.pressed.connect(func() -> void:
			Settings.set_difficulty(d_name)
			_refresh_difficulty_buttons(row))
		row.add_child(b)
	box.add_child(row)

	var reduced := UIStyle.button("REDUCED EFFECTS: %s" % ("ON" if Settings.reduced_effects else "OFF"), Vector2(260, 40), "secondary")
	reduced.pressed.connect(func() -> void:
		Settings.set_reduced_effects(not Settings.reduced_effects)
		reduced.text = "REDUCED EFFECTS: %s" % ("ON" if Settings.reduced_effects else "OFF"))
	box.add_child(reduced)
	return box

func _refresh_difficulty_buttons(row: HBoxContainer) -> void:
	var i := 0
	for d in ["easy", "normal", "hard"]:
		var b := row.get_child(i) as Button
		if b != null:
			b.text = d.to_upper()
		i += 1

func _slider_row(label_text: String, prop: String) -> Control:
	var row := UIStyle.hbox(10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl := UIStyle.label(label_text, 18, UIStyle.COL_TEXT_DIM, false)
	lbl.custom_minimum_size = Vector2(90, 0)
	row.add_child(lbl)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.custom_minimum_size = Vector2(260, 24)
	s.value = float(Settings.get(prop))
	s.value_changed.connect(_on_volume_changed.bind(prop))
	row.add_child(s)
	return row

func _on_volume_changed(v: float, prop: String) -> void:
	match prop:
		"master_volume":
			Settings.set_master(v)
		"music_volume":
			Settings.set_music(v)
		"sfx_volume":
			Settings.set_sfx(v)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		resume()
		get_viewport().set_input_as_handled()

func resume() -> void:
	get_tree().paused = false
	queue_free()

func _restart() -> void:
	get_tree().paused = false
	GameState.go("match")

func _to_menu() -> void:
	get_tree().paused = false
	GameState.go("title")

func _toggle_settings() -> void:
	_settings_box.visible = not _settings_box.visible
