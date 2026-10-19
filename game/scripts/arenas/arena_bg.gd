extends Node2D
class_name ArenaBG
## Full-screen animated arena backdrop: gradient sky, neon skyline,
## sweeping spotlights, drifting embers and a faint watermark.
## Lives in its own CanvasLayer so screen shake never moves it.

const W := 1280.0
const H := 720.0
const FLOOR_Y := 640.0

var def: ArenaDef
var time := 0.0
var _particles: Array = []
var _windows: Array = []
var _skyline_a: PackedVector2Array
var _skyline_b: PackedVector2Array

func setup(p_def: ArenaDef) -> void:
	def = p_def
	_build_skyline()
	_build_embers()
	queue_redraw()

func _build_skyline() -> void:
	## Deterministic procedural skyline (seeded from the arena id).
	var seed_v := 0
	for i in def.id.length():
		seed_v = (seed_v * 31 + def.id.unicode_at(i)) % 100000
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	_skyline_a = _skyline_strip(rng, 46.0, 120.0)
	_skyline_b = _skyline_strip(rng, 70.0, 190.0)
	_windows.clear()
	for i in 46:
		_windows.append({
			"x": rng.randf_range(40.0, W - 40.0),
			"y": rng.randf_range(FLOOR_Y - 170.0, FLOOR_Y - 40.0),
			"phase": rng.randf_range(0.0, TAU),
			"h": rng.randf_range(1.5, 3.0),
		})

func _build_embers() -> void:
	_particles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 99173
	for i in 34:
		_particles.append({
			"pos": Vector2(rng.randf_range(0, W), rng.randf_range(80, FLOOR_Y)),
			"speed": rng.randf_range(12.0, 42.0),
			"drift": rng.randf_range(-10.0, 10.0),
			"r": rng.randf_range(1.0, 2.6),
			"phase": rng.randf_range(0.0, TAU),
		})

func _process(delta: float) -> void:
	time += delta
	for p in _particles:
		p["pos"] = p["pos"] + Vector2(p["drift"] * delta, -p["speed"] * delta)
		if p["pos"].y < 60.0:
			p["pos"] = Vector2(randf_range(20, W - 20), FLOOR_Y + randf_range(0, 40))
	queue_redraw()

func _draw() -> void:
	if def == null:
		return
	# --- gradient sky
	var steps := 26
	for i in steps:
		var k := float(i) / float(steps - 1)
		var col := def.bg_top.lerp(def.bg_bottom, k)
		draw_rect(Rect2(0, H * k * (FLOOR_Y + 40) / H, W, (FLOOR_Y + 40) / steps + 2), col)
	# --- horizon glow
	draw_rect(Rect2(0, FLOOR_Y - 26, W, 26), Color(def.glow_color, 0.10))
	draw_rect(Rect2(0, FLOOR_Y - 3, W, 3), Color(def.glow_color, 0.55))
	# --- distant skyline (two layers)
	_draw_skyline(_skyline_b, def.silhouette_color.lightened(0.06), 1.0)
	_draw_skyline(_skyline_a, def.silhouette_color, 1.6)
	# --- blinking windows
	for w in _windows:
		var tw := 0.5 + 0.5 * sin(time * 1.4 + float(w["phase"]))
		draw_rect(Rect2(float(w["x"]), float(w["y"]), 2.0, float(w["h"])), Color(def.accent, 0.10 + 0.25 * tw))
	# --- sweeping spotlights
	_spotlight(Vector2(150, -20), sin(time * 0.55) * 0.9, def.accent)
	_spotlight(Vector2(W - 150, -20), sin(time * 0.47 + 2.1) * 0.9, def.grid_color)
	_spotlight(Vector2(W * 0.5, -30), sin(time * 0.33 + 4.0) * 0.55, def.glow_color)
	# --- drifting embers
	for p in _particles:
		var tw := 0.55 + 0.45 * sin(time * 2.2 + float(p["phase"]))
		var pos: Vector2 = p["pos"]
		draw_circle(pos, float(p["r"]) + 2.5, Color(def.accent, 0.06 * tw))
		draw_circle(pos, float(p["r"]), Color(def.grid_color, 0.25 * tw))
	# --- faint watermark
	var f: Font = UIStyle.head(64)
	draw_string(f, Vector2(W * 0.5 - 300, H * 0.46), "YEET ARENA", HORIZONTAL_ALIGNMENT_LEFT, 600, 64, Color(1, 1, 1, 0.035))
	draw_string(f, Vector2(W * 0.5 - 296, H * 0.46 + 4), "YEET ARENA", HORIZONTAL_ALIGNMENT_LEFT, 600, 64, Color(def.grid_color, 0.03))

func _draw_skyline(strip: PackedVector2Array, col: Color, extra_h: float) -> void:
	if strip.is_empty():
		return
	var pts := PackedVector2Array(strip)
	pts.append(Vector2(W, FLOOR_Y))
	pts.append(Vector2(0, FLOOR_Y))
	draw_colored_polygon(pts, col)

func _spotlight(origin: Vector2, swing: float, col: Color) -> void:
	var dir := Vector2(swing * 0.9, 1.0).normalized()
	var left := Vector2(dir.rotated(-0.22)) * 760.0
	var right := Vector2(dir.rotated(0.22)) * 760.0
	draw_colored_polygon(PackedVector2Array([origin, origin + left, origin + right]), Color(col, 0.05))

func _skyline_strip(rng: RandomNumberGenerator, min_h: float, max_h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.append(Vector2(0, FLOOR_Y))
	var x := 0.0
	while x < W:
		var w := rng.randf_range(30.0, 90.0)
		var h := rng.randf_range(min_h, max_h)
		pts.append(Vector2(x, FLOOR_Y - h))
		pts.append(Vector2(x + w, FLOOR_Y - h))
		x += w
	pts.append(Vector2(x, FLOOR_Y))
	return pts
