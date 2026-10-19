extends MenuScreen
## Leaderboard: backend scoreboard with filter, refresh, stats + offline state.

var _rows: VBoxContainer
var _status: Label
var _filter: OptionButton
var _summary: Label
var _refresh_btn: Button
var _filter_id := ""

func build() -> void:
	make_back_button("title")
	footer("SCORES ARE STORED SERVER-SIDE (SQLITE) · START THE BACKEND TO RANK ONLINE")
	online_badge()

	var head := header("LEADERBOARD", "Top runs from every arena. Filter by fighter, refresh anytime.")
	head.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	head.offset_left = 90.0
	head.offset_top = 22.0
	head.offset_right = 800.0
	head.offset_bottom = 108.0
	add_child(head)

	# Controls row
	var controls := UIStyle.hbox(10)
	controls.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	controls.offset_left = 90.0
	controls.offset_top = 116.0
	controls.offset_right = 1000.0
	controls.offset_bottom = 162.0
	add_child(controls)

	_filter = OptionButton.new()
	_filter.custom_minimum_size = Vector2(230, 42)
	_filter.add_item("ALL FIGHTERS")
	_filter.set_item_metadata(0, "")
	_filter.selected = 0
	var idx := 1
	for f in FighterCatalog.all_fighters():
		_filter.add_item(f.display_name.to_upper())
		_filter.set_item_metadata(idx, f.id)
		idx += 1
	_filter.item_selected.connect(_on_filter)
	controls.add_child(_filter)

	_refresh_btn = UIStyle.button("REFRESH", Vector2(150, 42), "primary")
	_refresh_btn.pressed.connect(_refresh)
	controls.add_child(_refresh_btn)

	_summary = UIStyle.label("", 17, UIStyle.COL_TEXT_DIM, false)
	_summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	controls.add_child(_summary)

	# Header row
	var hdr := UIStyle.hbox(0)
	hdr.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hdr.offset_left = 90.0
	hdr.offset_top = 172.0
	hdr.offset_right = -260.0
	hdr.offset_bottom = 200.0
	add_child(hdr)
	hdr.add_child(_cell("#", 52, UIStyle.COL_CYAN))
	hdr.add_child(_cell("PLAYER", 230, UIStyle.COL_CYAN))
	hdr.add_child(_cell("FIGHTER", 160, UIStyle.COL_CYAN))
	hdr.add_child(_cell("SCORE", 130, UIStyle.COL_CYAN))
	hdr.add_child(_cell("KOs", 90, UIStyle.COL_CYAN))
	hdr.add_child(_cell("COMBO", 100, UIStyle.COL_CYAN))
	hdr.add_child(_cell("RESULT", 120, UIStyle.COL_CYAN))

	var sep := UIStyle.line()
	sep.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	sep.offset_left = 90.0
	sep.offset_top = 202.0
	sep.offset_right = -260.0
	sep.offset_bottom = 204.0
	add_child(sep)

	# Scrollable rows
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 90.0
	scroll.offset_top = 212.0
	scroll.offset_right = -260.0
	scroll.offset_bottom = -70.0
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_rows = UIStyle.vbox(2)
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)

	# Right rail: stats snapshot
	var rail := UIStyle.panel("dark")
	rail.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
	rail.offset_left = -240.0
	rail.offset_top = -180.0
	rail.offset_right = -40.0
	rail.offset_bottom = 240.0
	add_child(rail)
	var railbox := UIStyle.vbox(6)
	rail.add_child(railbox)
	railbox.add_child(UIStyle.label("SERVER STATS", 22, UIStyle.COL_MAGENTA, true))
	_status = UIStyle.label("", 16, UIStyle.COL_TEXT_DIM, false)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	railbox.add_child(_status)

	API.scores_loaded.connect(_on_scores)
	API.scores_failed.connect(_on_failed)
	API.stats_loaded.connect(_on_stats)
	API.stats_failed.connect(_on_stats_failed)

	_show_message("Loading scores…", UIStyle.COL_CYAN)
	_refresh()

func _cell(text: String, width: float, color: Color) -> Label:
	var l := UIStyle.label(text, 16, color, true)
	l.custom_minimum_size = Vector2(width, 0)
	return l

func _on_filter(index: int) -> void:
	_filter_id = String(_filter.get_item_metadata(index))
	_refresh()

func _refresh() -> void:
	_refresh_btn.disabled = true
	_show_message("Loading scores…", UIStyle.COL_CYAN)
	API.fetch_scores(_filter_id, 50)
	API.fetch_stats()

func _show_message(msg: String, color: Color) -> void:
	for c in _rows.get_children():
		c.queue_free()
	var lbl := UIStyle.label(msg, 18, color, false)
	_rows.add_child(lbl)

func _clear_rows() -> void:
	for c in _rows.get_children():
		c.queue_free()

func _on_scores(payload: Dictionary) -> void:
	_refresh_btn.disabled = false
	_clear_rows()
	var scores: Array = payload.get("scores", [])
	var count := int(payload.get("count", 0))
	if scores.is_empty():
		_show_message("No scores yet. Play an arcade match and submit your run!", UIStyle.COL_TEXT_DIM)
		_summary.text = "0 entries"
		return
	_summary.text = "%d entries shown · %d total recorded" % [scores.size(), count]
	var rank := 1
	for s in scores:
		_rows.add_child(_make_row(rank, s))
		rank += 1

func _make_row(rank: int, s: Dictionary) -> Control:
	var row := UIStyle.hbox(0)
	row.custom_minimum_size = Vector2(0, 30)
	var victory := bool(s.get("victory", false))
	var accent: Color = UIStyle.COL_SUCCESS if victory else UIStyle.COL_TEXT
	var fighter_id := String(s.get("fighter", ""))
	var fighter_name := fighter_id.to_upper()
	var f := FighterCatalog.get_fighter(fighter_id)
	if f != null:
		fighter_name = f.display_name.to_upper()
	row.add_child(_cell(str(rank), 52, accent))
	row.add_child(_cell(String(s.get("player_name", "?")), 230, accent))
	row.add_child(_cell(fighter_name, 160, accent))
	row.add_child(_cell(str(int(s.get("score", 0))), 130, accent))
	row.add_child(_cell(str(int(s.get("kos", 0))), 90, accent))
	row.add_child(_cell("x%d" % int(s.get("max_combo", 0)), 100, accent))
	row.add_child(_cell("WIN" if victory else "LOSS", 120,
		UIStyle.COL_SUCCESS if victory else UIStyle.COL_DANGER))
	return row

func _on_failed(reason: String) -> void:
	_refresh_btn.disabled = false
	_clear_rows()
	var msg := "Leaderboard offline.\n\n%s" % reason
	msg += "\n\nStart the backend with start_backend.bat, then hit REFRESH."
	_show_message(msg, UIStyle.COL_TEXT_DIM)
	_summary.text = "offline"

func _on_stats(payload: Dictionary) -> void:
	if not is_instance_valid(_status):
		return
	var total := int(payload.get("total_matches", payload.get("count", 0)))
	var top := String(payload.get("top_fighter", "—"))
	var avg := float(payload.get("average_score", 0.0))
	_status.text = "MATCHES SUBMITTED: %d\nTOP FIGHTER: %s\nAVERAGE SCORE: %d\n\nPlaceholder-free stats straight from SQLite." % [total, top.to_upper(), int(avg)]
	_status.add_theme_color_override("font_color", UIStyle.COL_TEXT)

func _on_stats_failed(reason: String) -> void:
	if not is_instance_valid(_status):
		return
	_status.text = "Stats unavailable.\n\n%s" % reason
	_status.add_theme_color_override("font_color", UIStyle.COL_TEXT_DIM)
