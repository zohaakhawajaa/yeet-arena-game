extends MenuScreen
## Title screen: entry point, online badge, demo attract mode.

func build() -> void:
	footer("WASD MOVE · J LIGHT · K HEAVY · L YEET · SHIFT DASH · ESC PAUSE     v" + GameState.VERSION)
	online_badge()

	# Big logo block, left-of-centre.
	var logo := UIStyle.vbox(0)
	logo.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	logo.offset_left = 90.0
	logo.offset_top = -150.0
	logo.offset_right = 760.0
	logo.offset_bottom = 60.0
	add_child(logo)

	var t1 := UIStyle.label("YEET", 116, UIStyle.COL_TEXT, true)
	logo.add_child(t1)
	var t2 := UIStyle.label("ARENA", 116, UIStyle.COL_MAGENTA, true)
	logo.add_child(t2)
	var tag := UIStyle.label("CHAOS IS A COMBAT SPORT", 24, UIStyle.COL_CYAN, false)
	logo.add_child(UIStyle.spacer(6))
	logo.add_child(tag)
	var blurb := UIStyle.label("Six fighters. Three arenas. One shrinking cage.\nGuard the walls, parry the desperate, and YEET when it counts.", 19, UIStyle.COL_TEXT_DIM, false)
	logo.add_child(UIStyle.spacer(10))
	logo.add_child(blurb)

	# Buttons, right side.
	var menu := UIStyle.vbox(12)
	menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	menu.offset_left = -420.0
	menu.offset_top = -220.0
	menu.offset_right = -90.0
	menu.offset_bottom = 240.0
	menu.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(menu)

	menu.add_child(_btn("PLAY", "primary", _play))
	menu.add_child(_btn("WATCH DEMO", "secondary", _demo))
	menu.add_child(_btn("HOW TO PLAY", "secondary", func() -> void:
		GameState.go("how_to_play")))
	menu.add_child(_btn("LEADERBOARD", "secondary", func() -> void:
		GameState.go("leaderboard")))
	menu.add_child(_btn("SETTINGS", "secondary", func() -> void:
		GameState.go("settings")))
	menu.add_child(_btn("QUIT", "danger", func() -> void:
		get_tree().quit()))

	var first := menu.get_child(0) as Button
	if first != null:
		first.grab_focus.call_deferred()

	API.check_health()

func _btn(text: String, style: String, cb: Callable) -> Button:
	var b := UIStyle.button(text, Vector2(300, 58), style)
	b.pressed.connect(cb)
	return b

func _play() -> void:
	GameState.go("fighter_select")

func _demo() -> void:
	var roster := ["volt", "brick", "phantom", "chaos", "titan", "glitch"]
	var arenas := ["neon_pit", "reactor_core", "void_circuit"]
	var p: String = roster[randi() % roster.size()]
	var others := roster.duplicate()
	others.erase(p)
	var o: String = others[randi() % others.size()]
	var a: String = arenas[randi() % arenas.size()]
	GameState.start_match(p, o, a, "demo")
