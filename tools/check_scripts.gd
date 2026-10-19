extends SceneTree
## Headless script check: loads every game script and reports parse errors.
## Usage: godot --headless --path . --script res://tools/check_scripts.gd

func _init() -> void:
	var failures := 0
	var total := 0
	var stack: Array[String] = ["res://game"]
	while not stack.is_empty():
		var dir_path: String = stack.pop_back()
		var d := DirAccess.open(dir_path)
		if d == null:
			push_error("Cannot open " + dir_path)
			continue
		d.list_dir_begin()
		var name := d.get_next()
		while name != "":
			var full := dir_path + "/" + name
			if d.current_is_dir() and not name.begins_with("."):
				stack.append(full)
			elif name.ends_with(".gd"):
				total += 1
				var res := load(full)
				if res == null:
					print("FAIL: " + full)
					failures += 1
			name = d.get_next()
		d.list_dir_end()
	print("Checked %d scripts, %d failures" % [total, failures])
	quit(1 if failures > 0 else 0)
