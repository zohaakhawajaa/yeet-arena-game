extends MenuScreen
## Fighter select: procedural preview + roster grid + stat sheet.

var preview_art: FighterArt
var _grid: GridContainer
var _buttons: Dictionary = {}
var _name_lbl: Label
var _tag_lbl: Label
var _ability_lbl: Label
var _ability_desc: Label
var _stat_rows: Dictionary = {}
var _pros_lbl: Label
var _cons_lbl: Label
var _selected := "volt"

func build() -> void:
	make_back_button("title")
	footer("CHOOSE YOUR FIGHTER · ARROWS/CLICK · ENTER CONFIRM")

	var head := header("CHOOSE YOUR FIGHTER", "Every fighter has a signature YEET and a different game plan.")
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	head.offset_left = 90.0
	head.offset_top = 26.0
	head.offset_right = 700.0
	head.offset_bottom = 110.0
	add_child(head)

	# ---- preview stage (left)
	var stage := Control.new()
	stage.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	stage.offset_left = 60.0
	stage.offset_top = 40.0
	stage.offset_right = 520.0
	stage.offset_bottom = 560.0
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stage)

	var platform := Platform.new()
	platform.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(platform)

	preview_art = FighterArt.new()
	preview_art.position = Vector2(230.0, 400.0)
	stage.add_child(preview_art)

	# ---- roster grid (right)
	var right := UIStyle.vbox(10)
	right.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	right.offset_left = -700.0
	right.offset_top = -290.0
	right.offset_right = -70.0
	right.offset_bottom = 300.0
	add_child(right)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	right.add_child(_grid)

	for id in FighterCatalog.ids():
		var stats := FighterCatalog.get_fighter(id)
		var b := UIStyle.button(stats.display_name.to_upper(), Vector2(196, 52), "secondary")
		var fid: String = id
		b.pressed.connect(_select.bind(fid))
		_grid.add_child(b)
		_buttons[fid] = b

	right.add_child(UIStyle.spacer(6))

	# ---- stat sheet
	var sheet := UIStyle.panel("dark")
	right.add_child(sheet)
	var sbox := UIStyle.vbox(6)
	sheet.add_child(sbox)

	_name_lbl = UIStyle.label("VOLT", 34, UIStyle.COL_CYAN, true)
	sbox.add_child(_name_lbl)
	_tag_lbl = UIStyle.label("", 18, UIStyle.COL_TEXT_DIM, false)
	sbox.add_child(_tag_lbl)
	sbox.add_child(UIStyle.line())

	var stats_row := UIStyle.hbox(18)
	sbox.add_child(stats_row)
	var bars := UIStyle.vbox(4)
	bars.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(bars)
	for key in ["speed", "power", "toughness", "mobility", "technique"]:
		var bar := UIStyle.stat_bar(key.to_upper(), 0.5, UIStyle.COL_CYAN)
		bars.add_child(bar)
		_stat_rows[key] = bar

	var ability_box := UIStyle.vbox(2)
	ability_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats_row.add_child(ability_box)
	_ability_lbl = UIStyle.label("", 20, UIStyle.COL_AMBER, true)
	ability_box.add_child(_ability_lbl)
	_ability_desc = UIStyle.label("", 16, UIStyle.COL_TEXT_DIM, false)
	_ability_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ability_box.add_child(_ability_desc)
	_pros_lbl = UIStyle.label("", 16, UIStyle.COL_SUCCESS, false)
	ability_box.add_child(_pros_lbl)
	_cons_lbl = UIStyle.label("", 16, UIStyle.COL_DANGER, false)
	ability_box.add_child(_cons_lbl)

	right.add_child(UIStyle.spacer(4))
	var actions := UIStyle.hbox(10)
	right.add_child(actions)
	var rand_btn := UIStyle.button("RANDOM", Vector2(160, 52), "secondary")
	rand_btn.pressed.connect(_random)
	actions.add_child(rand_btn)
	var go := UIStyle.button("NEXT: ARENA", Vector2(240, 52), "primary")
	go.pressed.connect(func() -> void:
		GameState.player_fighter = _selected
		GameState.go("arena_select"))
	actions.add_child(go)

	_select("volt")

func _select(id: String) -> void:
	_selected = id
	var stats := FighterCatalog.get_fighter(id)
	if stats == null:
		return
	preview_art.setup(stats, 0)
	preview_art.state = Fighter.State.IDLE
	preview_art.grounded = true
	preview_art.speed_k = 0.0

	_name_lbl.text = stats.display_name.to_upper()
	_name_lbl.add_theme_color_override("font_color", stats.accent)
	_tag_lbl.text = stats.tagline
	_ability_lbl.text = stats.ability_name.to_upper()
	_ability_desc.text = stats.ability_desc
	_pros_lbl.text = "PROS: " + ", ".join(stats.pros) if stats.pros.size() > 0 else ""
	_cons_lbl.text = "CONS: " + ", ".join(stats.cons) if stats.cons.size() > 0 else ""

	# Stat bars: FighterStats exposes stat_* helpers returning 0..1.
	_set_bar("speed", stats.stat_speed())
	_set_bar("power", stats.stat_power())
	_set_bar("toughness", stats.stat_toughness())
	_set_bar("mobility", stats.stat_mobility())
	_set_bar("technique", stats.stat_technique())

	for fid in _buttons.keys():
		var b := _buttons[fid] as Button
		var is_sel: bool = fid == id
		b.add_theme_color_override("font_color", stats.accent if is_sel else UIStyle.COL_TEXT)
		b.self_modulate = Color(1, 1, 1) if is_sel else Color(0.72, 0.72, 0.8)

func _set_bar(key: String, value: float) -> void:
	var bar: Control = _stat_rows[key]
	UIStyle.set_stat_value(bar, value)

func _random() -> void:
	var ids := FighterCatalog.ids()
	_select(ids[randi() % ids.size()])

class Platform extends Control:
	func _draw() -> void:
		var w := size.x
		var h := size.y
		# Arena pedestal glow
		draw_colored_polygon(PackedVector2Array([
			Vector2(w * 0.08, h * 0.78),
			Vector2(w * 0.92, h * 0.78),
			Vector2(w * 0.80, h * 0.96),
			Vector2(w * 0.20, h * 0.96),
		]), Color(UIStyle.COL_VIOLET, 0.10))
		draw_line(Vector2(w * 0.08, h * 0.78), Vector2(w * 0.92, h * 0.78), Color(UIStyle.COL_CYAN, 0.5), 2.0)
		# Backdrop rings
		var c := Vector2(w * 0.45, h * 0.42)
		for i in 3:
			draw_arc(c, 60.0 + float(i) * 46.0, 0.0, TAU, 64, Color(UIStyle.COL_CYAN, 0.06 - float(i) * 0.015), 2.0)
