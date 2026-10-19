extends Control
## Root of the game. Owns screen transitions, the global fader and boot sequence.

const SCREEN_PATHS := {
	"title": "res://game/scenes/menus/title.tscn",
	"fighter_select": "res://game/scenes/menus/fighter_select.tscn",
	"arena_select": "res://game/scenes/menus/arena_select.tscn",
	"how_to_play": "res://game/scenes/menus/how_to_play.tscn",
	"settings": "res://game/scenes/menus/settings_screen.tscn",
	"leaderboard": "res://game/scenes/menus/leaderboard.tscn",
	"match": "res://game/scenes/gameplay/match.tscn",
}

var _current: Node
var _transitioning := false
var _pending: Dictionary = {}

@onready var screens: Control = $Screens
@onready var fader: ColorRect = $Overlay/Fader

func _ready() -> void:
	UIStyle.apply_theme(self)
	Settings.apply_on_startup()
	GameState.navigate.connect(_on_navigate)
	fader.color = Color(0.01, 0.01, 0.03, 0.0)
	_show_immediately("title", {})
	API.check_health()

func _on_navigate(screen: String, payload: Dictionary) -> void:
	if _transitioning:
		# Queue the most recent request instead of dropping it.
		_pending = {"screen": screen, "payload": payload}
		return
	_do_transition(screen, payload)

func _do_transition(screen: String, payload: Dictionary) -> void:
	_transitioning = true
	fader.mouse_filter = Control.MOUSE_FILTER_STOP
	var t := create_tween()
	t.tween_property(fader, "color:a", 1.0, 0.16)
	await t.finished
	_show_immediately(screen, payload)
	await get_tree().process_frame
	var t2 := create_tween()
	t2.tween_property(fader, "color:a", 0.0, 0.22)
	await t2.finished
	fader.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transitioning = false
	if not _pending.is_empty():
		var nxt: Dictionary = _pending
		_pending = {}
		_do_transition(nxt["screen"], nxt["payload"])

func _show_immediately(screen: String, payload: Dictionary) -> void:
	if _current != null and is_instance_valid(_current):
		_current.queue_free()
		_current = null
	for child in screens.get_children():
		child.free()
	if not SCREEN_PATHS.has(screen):
		push_error("Unknown screen: " + screen)
		return
	var packed: PackedScene = load(SCREEN_PATHS[screen])
	var inst: Node = packed.instantiate()
	screens.add_child(inst)
	_current = inst
	if inst is Control:
		inst.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if inst.has_method("setup"):
		inst.setup(payload)
	if screen != "match":
		AudioMan.play_music("music_menu")

## Used by tests / tools to swap screens without animation.
func show_screen_now(screen: String, payload: Dictionary = {}) -> void:
	_show_immediately(screen, payload)
