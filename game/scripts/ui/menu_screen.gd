extends Control
class_name MenuScreen
## Shared chrome for menu screens: animated backdrop, header, footer,
## keyboard back handling. Child screens override build().

var payload: Dictionary = {}
var back_screen := ""
var _t := 0.0
var _orbs: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_rng.seed = 0x5EED
	for i in 7:
		_orbs.append({
			"p": Vector2(_rng.randf_range(0.0, 1280.0), _rng.randf_range(0.0, 720.0)),
			"r": _rng.randf_range(140.0, 340.0),
			"sp": _rng.randf_range(5.0, 16.0),
			"ph": _rng.randf_range(0.0, TAU),
			"col": [UIStyle.COL_CYAN, UIStyle.COL_MAGENTA, UIStyle.COL_VIOLET][i % 3],
		})
	build()

func build() -> void:
	pass

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	# Vertical gradient
	var steps := 24
	for i in steps:
		var k := float(i) / float(steps - 1)
		var col := UIStyle.COL_BG.lerp(Color("0d0d22"), k)
		draw_rect(Rect2(0, 720.0 * float(i) / float(steps), 1280.0, 720.0 / float(steps) + 2.0), col)
	# Drifting glow orbs
	for o in _orbs:
		var pos: Vector2 = o["p"]
		var drift := Vector2(sin(_t * 0.12 + float(o["ph"])), cos(_t * 0.09 + float(o["ph"]))) * 40.0
		var col: Color = o["col"]
		draw_circle(pos + drift, float(o["r"]), Color(col, 0.035))
		draw_circle(pos + drift, float(o["r"]) * 0.5, Color(col, 0.02))
	# Grid
	var g: Color = Color(UIStyle.COL_EDGE, 0.35)
	for i in 17:
		var y := float(i) * 45.0
		draw_line(Vector2(0, y), Vector2(1280, y), g, 1.0)
	for i in 29:
		var x := float(i) * 46.0
		draw_line(Vector2(x, 0), Vector2(x, 720), g, 1.0)
	# Scanline sweep
	var sy := fmod(_t * 90.0, 900.0) - 90.0
	draw_rect(Rect2(0, sy, 1280.0, 60.0), Color(UIStyle.COL_CYAN, 0.02))
	# Vignette edges
	draw_rect(Rect2(0, 0, 1280.0, 3.0), Color(UIStyle.COL_CYAN, 0.25))
	draw_rect(Rect2(0, 717.0, 1280.0, 3.0), Color(UIStyle.COL_MAGENTA, 0.25))

# ---------------------------------------------------------------- helpers

func header(text: String, sub: String = "") -> Control:
	var box := UIStyle.vbox(2)
	var t := UIStyle.title(text, 46, UIStyle.COL_TEXT)
	box.add_child(t)
	if sub != "":
		var s := UIStyle.label(sub, 18, UIStyle.COL_TEXT_DIM, false)
		box.add_child(s)
	return box

func make_back_button(target: String) -> Button:
	back_screen = target
	var b := UIStyle.button("BACK", Vector2(150, 46), "secondary")
	b.pressed.connect(func() -> void:
		GameState.go(target))
	b.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	b.offset_left = 34.0
	b.offset_top = -76.0
	b.offset_right = 184.0
	b.offset_bottom = -30.0
	add_child(b)
	return b

func online_badge() -> Control:
	var row := UIStyle.hbox(8)
	var dot := ColorRect.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.color = UIStyle.COL_SUCCESS if API.online else UIStyle.COL_TEXT_DIM
	dot.name = "Dot"
	row.add_child(dot)
	var lbl := UIStyle.label("ONLINE" if API.online else "OFFLINE", 16,
		UIStyle.COL_SUCCESS if API.online else UIStyle.COL_TEXT_DIM, false)
	lbl.name = "Txt"
	row.add_child(lbl)
	row.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	row.offset_left = -220.0
	row.offset_top = 24.0
	row.offset_right = -34.0
	row.offset_bottom = 52.0
	add_child(row)
	var upd := func(online: bool) -> void:
		if not is_instance_valid(row):
			return
		(dot as ColorRect).color = UIStyle.COL_SUCCESS if online else UIStyle.COL_TEXT_DIM
		(lbl as Label).text = "ONLINE" if online else "OFFLINE"
		(lbl as Label).add_theme_color_override("font_color",
			UIStyle.COL_SUCCESS if online else UIStyle.COL_TEXT_DIM)
	API.health_changed.connect(upd)
	return row

func footer(text: String) -> void:
	var lbl := UIStyle.label(text, 16, UIStyle.COL_TEXT_DIM, false)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	lbl.offset_left = 34.0
	lbl.offset_top = -34.0
	lbl.offset_right = -34.0
	lbl.offset_bottom = -10.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(lbl)

func _unhandled_input(event: InputEvent) -> void:
	if back_screen == "":
		return
	if event.is_action_pressed("back") or event.is_action_pressed("pause"):
		GameState.go(back_screen)
		get_viewport().set_input_as_handled()
