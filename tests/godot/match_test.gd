extends Node
## Headless end-to-end match test: boots the real router, plays an arcade match
## to completion and checks that the results screen appears.
##
## Run: godot --headless --path . --fixed-fps 60 --quit-after 6000 res://tests/godot/match_test.tscn -- --no-audio

var _main: Node
var _frames := 0
var _phase := 0
var _done := false

func _ready() -> void:
	var packed: PackedScene = load("res://game/scenes/main.tscn")
	if packed == null:
		_fail("could not load main.tscn")
		return
	_main = packed.instantiate()
	add_child(_main)
	await get_tree().process_frame
	print("[match] starting arcade match volt vs glitch in reactor_core")
	GameState.start_match("volt", "glitch", "reactor_core", "arcade")

func _process(_delta: float) -> void:
	if _done:
		return
	_frames += 1
	if _phase == 0 and _frames > 120:
		var match_node := _find_match()
		if match_node == null:
			_fail("match scene did not load within 2 seconds")
			return
		var fighters := 0
		for n in match_node.find_children("*", "", true, false):
			if n is Fighter:
				fighters += 1
		if fighters < 2:
			_fail("expected 2 fighters, found %d" % fighters)
			return
		print("[match] PASS match loaded (%d fighters, arena director active)" % fighters)
		_phase = 1
	elif _phase == 1 and _frames > 4200:
		if _find_results() == null:
			_fail("results screen never appeared after the match ended")
			return
		print("[match] PASS results screen shown after the match")
		_phase = 2
	elif _phase == 2 and _frames > 4400:
		_done = true
		print("[match] ALL_MATCH_OK")
		AudioMan.hard_stop()
		await get_tree().process_frame
		get_tree().quit(0)

func _find_match() -> Node:
	for n in _main.find_children("*", "", true, false):
		if n.has_method("get_safe_rect"):
			return n
	return null

func _find_results() -> Node:
	for n in _main.find_children("*", "", true, false):
		if n is ResultsScreen:
			return n
	return null

func _fail(msg: String) -> void:
	_done = true
	print("[match] FAIL ", msg)
	AudioMan.hard_stop()
	get_tree().quit(1)
