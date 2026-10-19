class_name PlayerController
extends Node
## Translates keyboard input into a fighter intent. Edge-latches the YEET key
## so holding the button can never machine-gun the special.

var fighter: Fighter
var _yeet_armed := true

func bind(f: Fighter) -> void:
	fighter = f

func get_intent() -> Dictionary:
	var intent := {
		"move": Input.get_axis("move_left", "move_right"),
		"jump": Input.is_action_just_pressed("jump"),
		"light": Input.is_action_just_pressed("attack_light"),
		"heavy": Input.is_action_just_pressed("attack_heavy"),
		"yeet": false,
		"dash": Input.is_action_just_pressed("dash"),
		"guard": Input.is_action_pressed("move_down"),
	}
	if Input.is_action_pressed("yeet"):
		if _yeet_armed:
			intent["yeet"] = true
			_yeet_armed = false
	else:
		_yeet_armed = true
	return intent

func reset_latch() -> void:
	_yeet_armed = false
