extends Node
## Headless smoke test: boots every menu through the real router and logs progress.
## Run: godot --headless --path . --fixed-fps 60 res://tests/godot/menu_smoke.tscn

const SCREENS: Array[String] = [
	"title",
	"fighter_select",
	"arena_select",
	"how_to_play",
	"settings",
	"leaderboard",
]

var _main: Node
var _idx := 0
var _frames := 0

func _ready() -> void:
	var packed: PackedScene = load("res://game/scenes/main.tscn")
	if packed == null:
		push_error("[smoke] could not load main.tscn")
		get_tree().quit(1)
		return
	_main = packed.instantiate()
	add_child(_main)
	print("[smoke] main booted")

func _process(_delta: float) -> void:
	_frames += 1
	if _frames % 14 != 0:
		return
	if _idx < SCREENS.size():
		var s: String = SCREENS[_idx]
		_main.call("show_screen_now", s, {})
		print("[smoke] showed ", s)
		_idx += 1
		if _idx >= SCREENS.size():
			print("[smoke] ALL_MENUS_OK")
	elif _frames > SCREENS.size() * 14 + 30:
		print("[smoke] done")
		AudioMan.hard_stop()
		await get_tree().process_frame
		await get_tree().process_frame
		get_tree().quit(0)
