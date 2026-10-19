extends Control
class_name ArenaPreview
## Animated arena thumbnail: gradient sky, skyline, floor grid, hazard cue.

var def: ArenaDef
var _t := 0.0
var _sky: PackedVector2Array

func setup(p_def: ArenaDef) -> void:
	def = p_def
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	_sky = PackedVector2Array()
	_sky.append(Vector2(0, 0))
	var x := 0.0
	while x < 420.0:
		var w := rng.randf_range(26.0, 60.0)
		var h := rng.randf_range(24.0, 92.0)
		_sky.append(Vector2(x, 200.0 - h))
		_sky.append(Vector2(x + w, 200.0 - h))
		x += w
	queue_redraw()

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var w := maxf(size.x, 420.0)
	var h := maxf(size.y, 236.0)
	var floor_y := h * 0.78
	if def != null:
		var steps := 14
		for i in steps:
			var k := float(i) / float(steps - 1)
			draw_rect(Rect2(0, floor_y * float(i) / float(steps), w, floor_y / float(steps) + 2.0),
				def.bg_top.lerp(def.bg_bottom, k))
		# skyline
		if not _sky.is_empty():
			var pts := PackedVector2Array()
			for p in _sky:
				pts.append(p)
			pts.append(Vector2(_sky[_sky.size() - 1].x, floor_y))
			pts.append(Vector2(0, floor_y))
			draw_colored_polygon(pts, Color(def.silhouette_color, 0.95))
		# spotlights
		var swing := sin(_t * 0.7) * 0.5
		var origin := Vector2(w * 0.3, -10.0)
		var dir := Vector2(swing, 1.0).normalized()
		var l := Vector2(dir.rotated(-0.25)) * 320.0
		var r := Vector2(dir.rotated(0.25)) * 320.0
		draw_colored_polygon(PackedVector2Array([origin, origin + l, origin + r]), Color(def.accent, 0.07))
		# floor
		draw_rect(Rect2(0, floor_y, w, h - floor_y), def.floor_color)
		for i in 9:
			var y := floor_y + 6.0 + float(i) * (h - floor_y) / 9.0
			draw_line(Vector2(0, y), Vector2(w, y), Color(def.grid_color, 0.22), 1.0)
		for i in 7:
			var gx := float(i) * w / 6.0
			draw_line(Vector2(gx, floor_y), Vector2(w * 0.5 + (gx - w * 0.5) * 1.5, h), Color(def.grid_color, 0.16), 1.0)
		# hazard cue
		if def.hazard == "vent":
			var pulse := 0.4 + 0.4 * absf(sin(_t * 3.0))
			var vx := w * 0.5
			draw_rect(Rect2(vx - 14.0, floor_y - 70.0, 28.0, 70.0), Color(1.0, 0.5, 0.15, 0.18 + 0.12 * pulse))
			for i in 3:
				var y := floor_y - fmod(_t * 90.0 + float(i) * 34.0, 70.0)
				draw_colored_polygon(PackedVector2Array([
					Vector2(vx - 9.0, y), Vector2(vx, y - 8.0), Vector2(vx + 9.0, y)]),
					Color(1.0, 0.7, 0.2, 0.5))
		elif def.hazard == "orbs":
			for i in 2:
				var ox := fmod(_t * 60.0 + float(i) * 200.0, w + 80.0) - 40.0
				var oy := floor_y - 90.0 + sin(_t * 2.0 + float(i)) * 40.0
				draw_circle(Vector2(ox, oy), 11.0, Color(def.accent, 0.12))
				draw_circle(Vector2(ox, oy), 7.0, Color(def.glow_color, 0.7))
				draw_circle(Vector2(ox, oy), 3.0, Color(1, 1, 1, 0.85))
	# frame
	draw_rect(Rect2(0, 0, w, h), Color(def.accent if def != null else Color(1, 1, 1), 0.35), false, 2.0)
