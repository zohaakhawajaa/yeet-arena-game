extends MenuScreen
## Controls + mechanics reference, and the full roster breakdown.

func build() -> void:
	make_back_button("title")
	footer("CHAOS IS A COMBAT SPORT")

	var head := header("HOW TO PLAY", "Arcade fighting with a shrinking cage and no mercy.")
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	head.offset_left = 80.0
	head.offset_top = 20.0
	head.offset_right = 900.0
	head.offset_bottom = 100.0
	add_child(head)

	var cols := UIStyle.hbox(24)
	cols.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cols.offset_left = 80.0
	cols.offset_top = 110.0
	cols.offset_right = -80.0
	cols.offset_bottom = -70.0
	cols.add_theme_constant_override("separation", 24)
	add_child(cols)

	# ---- column 1: controls + mechanics
	var c1 := UIStyle.vbox(8)
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(c1)

	c1.add_child(_h("CONTROLS"))
	c1.add_child(_row("MOVE", "A / D  or  ← / →"))
	c1.add_child(_row("JUMP", "W  or  SPACE  or  ↑"))
	c1.add_child(_row("LIGHT ATTACK", "J"))
	c1.add_child(_row("HEAVY ATTACK", "K"))
	c1.add_child(_row("YEET (SPECIAL)", "L"))
	c1.add_child(_row("DASH (i-frames)", "SHIFT"))
	c1.add_child(_row("GUARD", "hold S / ↓"))
	c1.add_child(_row("PAUSE", "ESC"))
	c1.add_child(UIStyle.spacer(6))
	c1.add_child(_h("MECHANICS"))
	c1.add_child(_body("INPUT BUFFER 0.16s — your next action queues while you're still recovering."))
	c1.add_child(_body("COMBO SCALING — damage decays the longer a combo runs (floor 45%)."))
	c1.add_child(_body("YEET — a huge, slow special. Edge-latched: release the key before it re-arms."))
	c1.add_child(_body("GUARD — hold down. Blocks most damage but you still get pushed."))
	c1.add_child(_body("PARRY — GLITCH only: tap guard at the last moment to hard-counter."))
	c1.add_child(_body("SUPER ARMOR — BRICK only: light and heavy hits won't interrupt his swings."))

	# ---- column 2: fight rules + roster
	var c2 := UIStyle.vbox(8)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(c2)

	c2.add_child(_h("MATCH RULES"))
	c2.add_child(_body("60 seconds. Best damage wins. K.O. ends it instantly."))
	c2.add_child(_body("The safe zone contracts at 15s, 35s and 47s — yellow border means move."))
	c2.add_child(_body("Stand outside the safe zone and you take chip damage."))
	c2.add_child(_body("Score = damage x10 + combo bonus + KOs + time left + HP left."))
	c2.add_child(UIStyle.spacer(6))
	c2.add_child(_h("ROSTER"))
	for f in FighterCatalog.all_fighters():
		var line := UIStyle.label("%s — %s" % [f.display_name.to_upper(), f.ability_name], 17, f.accent, true)
		c2.add_child(line)
		c2.add_child(_body("     " + f.ability_desc))

func _h(text: String) -> Label:
	var l := UIStyle.label(text, 24, UIStyle.COL_CYAN, true)
	return l

func _body(text: String) -> Label:
	var l := UIStyle.label(text, 16, UIStyle.COL_TEXT_DIM, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l

func _row(label_text: String, value: String) -> Control:
	var row := UIStyle.hbox(10)
	var a := UIStyle.label(label_text, 17, UIStyle.COL_TEXT, true)
	a.custom_minimum_size = Vector2(190, 0)
	row.add_child(a)
	var b := UIStyle.label(value, 17, UIStyle.COL_AMBER, false)
	row.add_child(b)
	return row
