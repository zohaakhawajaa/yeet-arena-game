extends Node
## Central design system: theme, colors, fonts and widget factories.
## Every screen calls UIStyle.apply_theme() so the whole game shares one visual identity.

const FONT_HEAD := preload("res://game/assets/fonts/Orbitron.ttf")
const FONT_BODY_R := preload("res://game/assets/fonts/Rajdhani-Regular.ttf")
const FONT_BODY_B := preload("res://game/assets/fonts/Rajdhani-Bold.ttf")
const FONT_BODY_SB := preload("res://game/assets/fonts/Rajdhani-SemiBold.ttf")

const COL_BG := Color("07070f")
const COL_PANEL := Color("101024")
const COL_PANEL_LIGHT := Color("181833")
const COL_MAGENTA := Color("ff3cac")
const COL_CYAN := Color("2ee9f7")
const COL_VIOLET := Color("8a5cff")
const COL_AMBER := Color("ffc24b")
const COL_TEXT := Color("eaf2ff")
const COL_TEXT_DIM := Color("94a0c4")
const COL_DANGER := Color("ff4d63")
const COL_SUCCESS := Color("4dffa1")
const COL_EDGE := Color("2a2a55")

var theme: Theme
var _bold_cache: Dictionary = {}
var _hover_tween: Array = []

func _ready() -> void:
	theme = _build_theme()

func _build_theme() -> Theme:
	var t := Theme.new()
	var body := FontVariation.new()
	body.base_font = FONT_BODY_R
	t.default_font = body
	t.default_font_size = 20

	# Labels
	t.set_color("font_color", "Label", COL_TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.5))
	t.set_constant("shadow_offset_x", "Label", 0)
	t.set_constant("shadow_offset_y", "Label", 2)

	# Buttons (screens may override per-variant)
	t.set_stylebox("normal", "Button", _button_stylebox("secondary"))
	t.set_stylebox("hover", "Button", _button_stylebox("secondary", "hover"))
	t.set_stylebox("pressed", "Button", _button_stylebox("secondary", "pressed"))
	t.set_stylebox("focus", "Button", _button_stylebox("secondary", "focus"))
	t.set_stylebox("disabled", "Button", _button_stylebox("secondary", "disabled"))
	t.set_color("font_color", "Button", COL_TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", COL_BG)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("5a6180"))
	t.set_font_size("font_size", "Button", 21)
	var btn_font := FontVariation.new()
	btn_font.base_font = FONT_BODY_B
	t.set_font("font", "Button", btn_font)

	# Panels
	t.set_stylebox("panel", "PanelContainer", _panel_stylebox("dark"))

	# LineEdit (player name / API URL)
	var le_normal := StyleBoxFlat.new()
	le_normal.bg_color = Color("0a0a1cd9")
	le_normal.border_color = COL_EDGE
	le_normal.set_border_width_all(2)
	le_normal.set_corner_radius_all(4)
	le_normal.content_margin_left = 12.0
	le_normal.content_margin_right = 12.0
	le_normal.content_margin_top = 6.0
	le_normal.content_margin_bottom = 6.0
	t.set_stylebox("normal", "LineEdit", le_normal)
	var le_focus := le_normal.duplicate()
	le_focus.border_color = COL_CYAN
	le_focus.shadow_color = Color(COL_CYAN, 0.4)
	le_focus.shadow_size = 8
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_color("font_color", "LineEdit", COL_TEXT)
	t.set_color("font_placeholder_color", "LineEdit", COL_TEXT_DIM)
	t.set_color("caret_color", "LineEdit", COL_CYAN)
	t.set_color("selection_color", "LineEdit", Color("2ee9f755"))

	# OptionButton
	t.set_stylebox("normal", "OptionButton", _button_stylebox("secondary"))
	t.set_stylebox("hover", "OptionButton", _button_stylebox("secondary", "hover"))
	t.set_stylebox("pressed", "OptionButton", _button_stylebox("secondary", "pressed"))
	t.set_stylebox("focus", "OptionButton", _button_stylebox("secondary", "focus"))
	t.set_stylebox("selected", "OptionButton", _button_stylebox("primary", "normal"))
	t.set_color("font_color", "OptionButton", COL_TEXT)
	t.set_font_size("font_size", "OptionButton", 19)

	# CheckBox / CheckButton text
	t.set_color("font_color", "CheckBox", COL_TEXT)
	t.set_color("font_hover_color", "CheckBox", Color.WHITE)
	t.set_color("font_color", "CheckButton", COL_TEXT)

	# HSlider
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color("12122e")
	sl.set_corner_radius_all(3)
	t.set_stylebox("slider", "HSlider", sl)
	var grab := StyleBoxFlat.new()
	grab.bg_color = COL_CYAN
	grab.set_corner_radius_all(3)
	grab.shadow_color = Color(COL_CYAN, 0.6)
	grab.shadow_size = 6
	t.set_stylebox("grabber_area", "HSlider", grab)
	t.set_stylebox("grabber_area_highlight", "HSlider", grab)

	# Tooltips
	var tip := _panel_stylebox("dark")
	tip.content_margin_left = 10.0
	tip.content_margin_right = 10.0
	tip.content_margin_top = 6.0
	tip.content_margin_bottom = 6.0
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", COL_TEXT)

	# Popups (fighter detail / confirm dialogs if any)
	t.set_stylebox("panel", "PopupPanel", _panel_stylebox("dark"))

	# Tree/ItemList unlikely to be used, but keep readable text colors
	t.set_color("font_color", "ItemList", COL_TEXT)
	t.set_color("font_selected_color", "ItemList", Color.WHITE)
	return t

func apply_theme(c: Control) -> void:
	c.theme = theme

func head(size: int, color: Color = COL_TEXT) -> Font:
	## Heading font (Orbitron) rendered at a size, cached.
	var key := "%d_%s" % [size, color.to_html()]
	if not _bold_cache.has(key):
		var v := FontVariation.new()
		v.base_font = FONT_HEAD
		v.variation_embolden = 0.35
		v.variation_opentype = {"wght": 800.0}
		_bold_cache[key] = v
	return _bold_cache[key]

func body_font(size: int, bold: bool = true) -> Font:
	var f := FontVariation.new()
	f.base_font = FONT_BODY_B if bold else FONT_BODY_R
	return f

# ---------------------------------------------------------------- widget helpers

func button(text: String, min_size := Vector2(240, 54), style := "primary") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var stylebox := _button_stylebox(style)
	b.add_theme_stylebox_override("normal", stylebox.duplicate())
	b.add_theme_stylebox_override("hover", _button_stylebox(style, "hover"))
	b.add_theme_stylebox_override("pressed", _button_stylebox(style, "pressed"))
	b.add_theme_stylebox_override("focus", _button_stylebox(style, "focus"))
	b.add_theme_stylebox_override("disabled", _button_stylebox(style, "disabled"))
	b.add_theme_color_override("font_color", COL_TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", COL_BG)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color("5a6180"))
	b.add_theme_font_size_override("font_size", 21)
	b.add_theme_font_override("font", FONT_BODY_B)
	_sfx_hook(b)
	return b

func label(text: String, size: int = 20, color: Color = COL_TEXT, use_head: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if use_head:
		l.add_theme_font_override("font", head(size, color))
	else:
		var fv := FontVariation.new()
		fv.base_font = FONT_BODY_B if color != COL_TEXT_DIM else FONT_BODY_R
		l.add_theme_font_override("font", fv)
	return l

func title(text: String, size: int = 40, color: Color = COL_TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", head(size, color))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l

func panel(style := "primary") -> PanelContainer:
	var p := PanelContainer.new()
	var sb := _panel_stylebox(style)
	p.add_theme_stylebox_override("panel", sb)
	return p

func vbox(sep: int = 10) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v

func hbox(sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h

func spacer(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, px)
	return c

func spacer_x(px: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px, 0)
	return c

func expand() -> Control:
	var c := Control.new()
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c

## Horizontal stat bar used on the fighter select screen.
func stat_bar(name_text: String, value: float, color: Color = COL_CYAN) -> Control:
	var row := hbox(8)
	var name_lbl := label(name_text, 16, COL_TEXT_DIM)
	name_lbl.custom_minimum_size = Vector2(120, 0)
	row.add_child(name_lbl)
	var bar := ProgressBar.new()
	bar.name = "Bar"
	bar.min_value = 0
	bar.max_value = 1
	bar.value = clampf(value, 0, 1)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(180, 14)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("0b0b1c")
	bg.set_corner_radius_all(3)
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(3)
	fill.shadow_color = Color(color, 0.5)
	fill.shadow_size = 6
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	var val_lbl := label(str(int(round(value * 100))), 16, COL_TEXT)
	val_lbl.name = "Val"
	val_lbl.custom_minimum_size = Vector2(36, 0)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)
	return row

## Update a stat_bar row created above.
func set_stat_value(row: Control, value: float) -> void:
	var v := clampf(value, 0.0, 1.0)
	var bar := row.get_node_or_null("Bar") as ProgressBar
	if bar != null:
		bar.value = v
	var val := row.get_node_or_null("Val") as Label
	if val != null:
		val.text = str(int(round(v * 100.0)))

func line(color: Color = COL_EDGE) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", _line_style(color))
	return p

## Small pill badge (arena phase, ONLINE/OFFLINE, version tags).
func badge(text: String, color: Color) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color, 0.14)
	sb.border_color = color
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(10)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	p.add_theme_stylebox_override("panel", sb)
	var l := label(text, 14, color)
	p.add_child(l)
	return p

# ---------------------------------------------------------------- styleboxes

func _button_stylebox(base: String, state: String = "normal") -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(4)
	sb.content_margin_left = 18.0
	sb.content_margin_right = 18.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 8.0
	sb.set_border_width_all(2)
	match base:
		"primary":
			sb.bg_color = Color("ff3cac") if state != "pressed" else Color("ffd7ee")
			sb.border_color = Color("ff7ac6")
			sb.shadow_color = Color("ff3cac", 0.55)
			sb.shadow_size = 10
		"secondary":
			sb.bg_color = Color("141430")
			sb.border_color = COL_CYAN
			sb.shadow_color = Color("2ee9f7", 0.35)
			sb.shadow_size = 8
		_:
			sb.bg_color = Color("12122a")
			sb.border_color = COL_EDGE
	match state:
		"hover":
			sb.bg_color = sb.bg_color.lightened(0.16)
			sb.border_color = sb.border_color.lightened(0.25)
			sb.shadow_size = 14
		"pressed":
			sb.bg_color = sb.border_color.lightened(0.35)
			sb.shadow_size = 2
		"focus":
			sb.border_color = Color.WHITE
			sb.shadow_color = Color(sb.border_color, 0.8)
			sb.shadow_size = 16
			sb.bg_color = sb.bg_color.lightened(0.1)
		"disabled":
			sb.bg_color = Color("0d0d1e")
			sb.border_color = Color("2a2a45")
			sb.shadow_size = 0
	return sb

func _panel_stylebox(kind: String) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 16.0
	sb.content_margin_bottom = 16.0
	match kind:
		"primary":
			sb.bg_color = Color("0d0d22e6")
			sb.border_color = COL_MAGENTA
			sb.set_border_width_all(2)
			sb.shadow_color = Color("ff3cac", 0.30)
			sb.shadow_size = 12
		"secondary":
			sb.bg_color = Color("0c0c20e6")
			sb.border_color = COL_CYAN
			sb.set_border_width_all(2)
			sb.shadow_color = Color("2ee9f7", 0.25)
			sb.shadow_size = 10
		"dark":
			sb.bg_color = Color("0a0a1ad9")
			sb.border_color = COL_EDGE
			sb.set_border_width_all(1)
		_:
			sb.bg_color = Color("101024e6")
			sb.border_color = COL_EDGE
			sb.set_border_width_all(1)
	return sb

func _line_style(color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	return sb

# ---------------------------------------------------------------- audio hookup

func _sfx_hook(b: Button) -> void:
	b.mouse_entered.connect(func():
		if AudioMan != null: AudioMan.play_ui("hover"))
	b.focus_entered.connect(func():
		if AudioMan != null: AudioMan.play_ui("hover"))
	b.pressed.connect(func():
		if AudioMan != null: AudioMan.play_ui("click"))

## Fade a full-screen dimmer rect in/out for scene transitions.
func fade_rect() -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.01, 0.01, 0.04, 0.0)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	return r
