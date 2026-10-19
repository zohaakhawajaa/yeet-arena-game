extends MenuScreen
## Settings: audio, video, gameplay, identity, backend URL + connection test.

var _name_edit: LineEdit
var _url_edit: LineEdit
var _status: Label

func build() -> void:
	make_back_button("title")
	footer("SETTINGS SAVE AUTOMATICALLY")
	online_badge()

	var head := header("SETTINGS", "Everything persists to user://settings.cfg")
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	head.offset_left = 90.0
	head.offset_top = 26.0
	head.offset_right = 700.0
	head.offset_bottom = 110.0
	add_child(head)

	var cols := UIStyle.hbox(30)
	cols.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cols.offset_left = 90.0
	cols.offset_top = 120.0
	cols.offset_right = -90.0
	cols.offset_bottom = -80.0
	add_child(cols)

	# ---- audio
	var c1 := UIStyle.vbox(10)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(c1)
	c1.add_child(_h("AUDIO"))
	c1.add_child(_slider("MASTER VOLUME", Settings.master_volume, "master_volume"))
	c1.add_child(_slider("MUSIC VOLUME", Settings.music_volume, "music_volume"))
	c1.add_child(_slider("SFX VOLUME", Settings.sfx_volume, "sfx_volume"))
	var mute := UIStyle.button("MUTED: %s" % ("ON" if Settings.muted else "OFF"), Vector2(240, 44), "secondary")
	mute.pressed.connect(_toggle_mute.bind(mute))
	c1.add_child(mute)

	# ---- video
	c1.add_child(UIStyle.spacer(8))
	c1.add_child(_h("VIDEO"))
	var fs := UIStyle.button("FULLSCREEN: %s" % ("ON" if Settings.fullscreen else "OFF"), Vector2(240, 44), "secondary")
	fs.pressed.connect(_toggle_fullscreen.bind(fs))
	c1.add_child(fs)
	var fx := UIStyle.button("REDUCED EFFECTS: %s" % ("ON" if Settings.reduced_effects else "OFF"), Vector2(240, 44), "secondary")
	fx.pressed.connect(_toggle_fx.bind(fx))
	c1.add_child(fx)

	# ---- gameplay + network
	var c2 := UIStyle.vbox(10)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(c2)
	c2.add_child(_h("GAMEPLAY"))
	c2.add_child(_difficulty_row())
	var name_lbl := UIStyle.label("DISPLAY NAME", 17, UIStyle.COL_TEXT_DIM, false)
	c2.add_child(name_lbl)
	_name_edit = LineEdit.new()
	_name_edit.text = Settings.display_name
	_name_edit.max_length = 16
	_name_edit.placeholder_text = "2-16 characters"
	_name_edit.custom_minimum_size = Vector2(300, 44)
	_name_edit.text_changed.connect(_on_name_changed)
	c2.add_child(_name_edit)

	c2.add_child(UIStyle.spacer(8))
	c2.add_child(_h("BACKEND (LEADERBOARD)"))
	var url_lbl := UIStyle.label("API URL", 17, UIStyle.COL_TEXT_DIM, false)
	c2.add_child(url_lbl)
	_url_edit = LineEdit.new()
	_url_edit.text = Settings.api_url
	_url_edit.placeholder_text = "http://127.0.0.1:8000"
	_url_edit.custom_minimum_size = Vector2(360, 44)
	_url_edit.text_submitted.connect(_on_url_submitted)
	c2.add_child(_url_edit)
	var row := UIStyle.hbox(10)
	c2.add_child(row)
	var test := UIStyle.button("TEST CONNECTION", Vector2(220, 44), "secondary")
	test.pressed.connect(_test)
	row.add_child(test)
	var save := UIStyle.button("SAVE URL", Vector2(150, 44), "secondary")
	save.pressed.connect(_save_url)
	row.add_child(save)
	_status = UIStyle.label("", 17, UIStyle.COL_TEXT_DIM, false)
	c2.add_child(_status)
	var defaults := UIStyle.button("RESET TO DEFAULTS", Vector2(240, 44), "danger")
	defaults.pressed.connect(_reset)
	c2.add_child(defaults)

	API.health_changed.connect(_on_health)

func _h(text: String) -> Label:
	return UIStyle.label(text, 24, UIStyle.COL_CYAN, true)

func _slider(label_text: String, value: float, prop: String) -> Control:
	var box := UIStyle.vbox(2)
	var lbl := UIStyle.label("%s  %d%%" % [label_text, int(round(value * 100.0))], 17, UIStyle.COL_TEXT_DIM, false)
	box.add_child(lbl)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(320, 26)
	s.value_changed.connect(_on_slider.bind(prop, lbl, label_text))
	box.add_child(s)
	return box

func _on_slider(v: float, prop: String, lbl: Label, label_text: String) -> void:
	match prop:
		"master_volume":
			Settings.set_master(v)
		"music_volume":
			Settings.set_music(v)
		"sfx_volume":
			Settings.set_sfx(v)
	if is_instance_valid(lbl):
		lbl.text = "%s  %d%%" % [label_text, int(round(v * 100.0))]

func _difficulty_row() -> Control:
	var box := UIStyle.vbox(2)
	box.add_child(UIStyle.label("AI DIFFICULTY", 17, UIStyle.COL_TEXT_DIM, false))
	var row := UIStyle.hbox(8)
	for d in ["easy", "normal", "hard"]:
		var b := UIStyle.button(d.to_upper(), Vector2(110, 42), "primary" if Settings.difficulty == d else "secondary")
		b.pressed.connect(_set_difficulty.bind(d))
		row.add_child(b)
	box.add_child(row)
	return box

func _set_difficulty(d: String) -> void:
	Settings.set_difficulty(d)

func _toggle_mute(b: Button) -> void:
	Settings.set_muted(not Settings.muted)
	b.text = "MUTED: %s" % ("ON" if Settings.muted else "OFF")

func _toggle_fullscreen(b: Button) -> void:
	Settings.set_fullscreen(not Settings.fullscreen)
	b.text = "FULLSCREEN: %s" % ("ON" if Settings.fullscreen else "OFF")

func _toggle_fx(b: Button) -> void:
	Settings.set_reduced_effects(not Settings.reduced_effects)
	b.text = "REDUCED EFFECTS: %s" % ("ON" if Settings.reduced_effects else "OFF")

func _on_name_changed(t: String) -> void:
	Settings.set_display_name(t)

func _on_url_submitted(_t: String) -> void:
	_save_url()

func _save_url() -> void:
	Settings.set_api_url(_url_edit.text)
	_status.text = "URL SAVED · TESTING…"
	_status.add_theme_color_override("font_color", UIStyle.COL_CYAN)
	API.check_health()

func _test() -> void:
	_status.text = "CONTACTING BACKEND…"
	_status.add_theme_color_override("font_color", UIStyle.COL_CYAN)
	API.check_health()

func _on_health(online: bool) -> void:
	if not is_instance_valid(_status):
		return
	if online:
		_status.text = "BACKEND ONLINE — leaderboard ready."
		_status.add_theme_color_override("font_color", UIStyle.COL_SUCCESS)
	else:
		_status.text = "BACKEND OFFLINE — offline saves are disabled, game still playable."
		_status.add_theme_color_override("font_color", UIStyle.COL_DANGER)

func _reset() -> void:
	Settings.master_volume = 1.0
	Settings.music_volume = 0.7
	Settings.sfx_volume = 0.9
	Settings.muted = false
	Settings.reduced_effects = false
	Settings.difficulty = "normal"
	Settings.set_api_url("http://127.0.0.1:8000")
	Settings.save_settings()
	Settings.volume_changed.emit()
	_status.text = "DEFAULTS RESTORED (reopen settings to refresh sliders)."
	_status.add_theme_color_override("font_color", UIStyle.COL_AMBER)
