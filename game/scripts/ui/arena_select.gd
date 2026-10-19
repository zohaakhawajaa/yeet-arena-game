extends MenuScreen
## Arena select: preview + list + hazard info, then FIGHT!.

var _preview: ArenaPreview
var _name_lbl: Label
var _desc_lbl: Label
var _hazard_lbl: Label
var _difficulty_lbl: Label
var _buttons: Dictionary = {}
var _selected := "neon_pit"

func build() -> void:
	make_back_button("fighter_select")
	footer("PICK YOUR BATTLEGROUND · HAZARDS ARE ALWAYS ON")

	var head := header("CHOOSE THE ARENA", "The cage shrinks every match. Hazards do not care who you are.")
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	head.offset_left = 90.0
	head.offset_top = 26.0
	head.offset_right = 760.0
	head.offset_bottom = 110.0
	add_child(head)

	_preview = ArenaPreview.new()
	_preview.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	_preview.offset_left = 70.0
	_preview.offset_top = -120.0
	_preview.offset_right = 70.0 + 520.0
	_preview.offset_bottom = -120.0 + 292.0
	add_child(_preview)

	var info := UIStyle.vbox(4)
	info.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	info.offset_left = 70.0
	info.offset_top = 190.0
	info.offset_right = 590.0
	info.offset_bottom = 330.0
	add_child(info)
	_name_lbl = UIStyle.label("", 34, UIStyle.COL_CYAN, true)
	info.add_child(_name_lbl)
	_desc_lbl = UIStyle.label("", 18, UIStyle.COL_TEXT_DIM, false)
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(_desc_lbl)
	_hazard_lbl = UIStyle.label("", 18, UIStyle.COL_AMBER, false)
	info.add_child(_hazard_lbl)

	# Right column: arena buttons + fight action.
	var right := UIStyle.vbox(12)
	right.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	right.offset_left = -520.0
	right.offset_top = -220.0
	right.offset_right = -90.0
	right.offset_bottom = 300.0
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(right)

	var roster_lbl := UIStyle.label("ARENAS", 20, UIStyle.COL_TEXT_DIM, false)
	right.add_child(roster_lbl)

	for id in ArenaCatalog.ids():
		var arena := ArenaCatalog.get_arena(id)
		var b := UIStyle.button(arena.display_name.to_upper(), Vector2(360, 54), "secondary")
		var aid: String = id
		b.pressed.connect(_select.bind(aid))
		right.add_child(b)
		_buttons[aid] = b

	right.add_child(UIStyle.spacer(6))

	var diff_row := UIStyle.hbox(10)
	right.add_child(diff_row)
	_difficulty_lbl = UIStyle.label("", 18, UIStyle.COL_TEXT_DIM, false)
	_difficulty_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diff_row.add_child(_difficulty_lbl)
	var diff_btn := UIStyle.button("CYCLE DIFFICULTY", Vector2(220, 44), "secondary")
	diff_btn.pressed.connect(_cycle_difficulty)
	diff_row.add_child(diff_btn)

	right.add_child(UIStyle.spacer(4))

	var fight := UIStyle.button("FIGHT!", Vector2(360, 68), "primary")
	fight.pressed.connect(_fight)
	right.add_child(fight)

	_select("neon_pit")
	_refresh_difficulty()

func _select(id: String) -> void:
	_selected = id
	var arena := ArenaCatalog.get_arena(id)
	if arena == null:
		return
	_preview.setup(arena)
	_name_lbl.text = arena.display_name.to_upper()
	_name_lbl.add_theme_color_override("font_color", arena.accent)
	_desc_lbl.text = arena.description
	match arena.hazard:
		"none":
			_hazard_lbl.text = "HAZARD: NONE — clean fighting, shrinking cage only."
			_hazard_lbl.add_theme_color_override("font_color", UIStyle.COL_SUCCESS)
		"vent":
			_hazard_lbl.text = "HAZARD: VENT BLASTS — floor vents erupt on a timer."
			_hazard_lbl.add_theme_color_override("font_color", UIStyle.COL_DANGER)
		"orbs":
			_hazard_lbl.text = "HAZARD: VOID ORBS — drifting orbs knock you around."
			_hazard_lbl.add_theme_color_override("font_color", UIStyle.COL_DANGER)
	for aid in _buttons.keys():
		var b := _buttons[aid] as Button
		var is_sel: bool = aid == id
		b.add_theme_color_override("font_color", arena.accent if is_sel else UIStyle.COL_TEXT)
		b.self_modulate = Color(1, 1, 1) if is_sel else Color(0.72, 0.72, 0.8)
	GameState.arena = id

func _cycle_difficulty() -> void:
	var order := ["easy", "normal", "hard"]
	var idx := order.find(Settings.difficulty)
	if idx == -1:
		idx = 1
	Settings.set_difficulty(order[(idx + 1) % order.size()])
	_refresh_difficulty()

func _refresh_difficulty() -> void:
	_difficulty_lbl.text = "AI DIFFICULTY: " + Settings.difficulty.to_upper()

func _fight() -> void:
	GameState.start_match(GameState.player_fighter, GameState.pick_opponent(), _selected, "arcade")
