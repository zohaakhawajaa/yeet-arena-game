extends Node2D
class_name Fx
## Pooled combat effects: particle bursts, energy rings, dash trails,
## screen shake and hit-stop. Gameplay code calls into this; visuals stay
## separate from collision.

var world: Node2D
var fighters: Array = []
var hitstop_left: float = 0.0

var _burst_pool: Array[GPUParticles2D] = []
var _ring_pool: Array = []
var _trails: Array[Line2D] = []
var _shake_power: float = 0.0
var _world_base: Vector2 = Vector2.ZERO
var _glow_tex: Texture2D
var _reduced := false

func _ready() -> void:
	_glow_tex = _make_glow_texture()
	for i in 14:
		var p := GPUParticles2D.new()
		p.texture = _glow_tex
		p.one_shot = true
		p.explosiveness = 1.0
		p.emitting = false
		p.lifetime = 0.55
		p.amount = 22
		p.visibility_rect = Rect2(-400, -400, 800, 800)
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 180.0
		mat.initial_velocity_min = 120.0
		mat.initial_velocity_max = 340.0
		mat.gravity = Vector3(0, 420, 0)
		mat.damping_min = 1.0
		mat.damping_max = 3.0
		mat.scale_min = 0.6
		mat.scale_max = 1.6
		var grad := Gradient.new()
		grad.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
		grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.7), Color(1, 1, 1, 0.0)])
		var gt := GradientTexture1D.new()
		gt.gradient = grad
		mat.color_ramp = gt
		p.process_material = mat
		add_child(p)
		_burst_pool.append(p)
	for i in 6:
		var r := Ring.new()
		r.visible = false
		add_child(r)
		_ring_pool.append(r)

func setup(p_world: Node2D, p_fighters: Array) -> void:
	world = p_world
	fighters = p_fighters
	_world_base = p_world.position
	for f in fighters:
		var trail := Line2D.new()
		trail.width = 14.0
		trail.default_color = Color(1, 1, 1, 0.35)
		trail.joint_mode = Line2D.LINE_JOINT_ROUND
		trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
		trail.end_cap_mode = Line2D.LINE_CAP_ROUND
		trail.clear_points()
		world.add_child(trail)
		_trails.append(trail)

# ------------------------------------------------------------------ per frame

func _process(delta: float) -> void:
	_reduced = Settings.reduced_effects
	# Hit-stop: freeze gameplay timers while keeping effects running.
	if hitstop_left > 0.0:
		hitstop_left = maxf(0.0, hitstop_left - delta)
	# Dash trails follow the fighters.
	for i in fighters.size():
		var f = fighters[i]
		if not is_instance_valid(f):
			continue
		var trail := _trails[i]
		if f.state == f.State.DASH and not f.is_ko():
			trail.add_point(f.global_position + Vector2(0, -46))
			if trail.get_point_count() > 14:
				trail.remove_point(0)
			trail.default_color = Color(f.stats.accent, 0.5)
		else:
			if trail.get_point_count() > 0:
				trail.clear_points()
	# Screen shake decay on the world root.
	if world != null:
		if _shake_power > 0.001:
			_shake_power = maxf(0.0, _shake_power - delta * 46.0)
			world.position = _world_base + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake_power
		else:
			world.position = _world_base

func in_hitstop() -> bool:
	return hitstop_left > 0.0

# ------------------------------------------------------------------ effects

func burst(pos: Vector2, color: Color, power: float = 1.0) -> void:
	if _reduced:
		power *= 0.5
	for p in _burst_pool:
		if not p.emitting:
			p.global_position = pos
			p.modulate = color
			var m: ParticleProcessMaterial = p.process_material
			m.initial_velocity_min = 140.0 * power
			m.initial_velocity_max = 380.0 * power
			p.restart()
			p.emitting = true
			return
	# All busy: reuse the oldest (index 0).
	var p0 := _burst_pool[0]
	p0.global_position = pos
	p0.modulate = color
	p0.restart()
	p0.emitting = true

func ring(pos: Vector2, color: Color, size: float = 90.0) -> void:
	for r in _ring_pool:
		if not r.visible:
			r.begin(pos, color, size, _reduced)
			return

func shake(power: float) -> void:
	if _reduced:
		power *= 0.35
	_shake_power = maxf(_shake_power, power)

func hitstop(seconds: float) -> void:
	hitstop_left = maxf(hitstop_left, seconds)

func set_reduced(v: bool) -> void:
	_reduced = v

# ------------------------------------------------------------------ helpers

func _make_glow_texture() -> Texture2D:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length() / 15.5
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)

## Expanding neon ring, self-animating and self-freeing.
class Ring extends Node2D:
	var _t := 0.0
	var _dur := 0.35
	var _color := Color.WHITE
	var _size := 90.0
	var _reduced := false

	func begin(pos: Vector2, color: Color, size: float, reduced: bool) -> void:
		global_position = pos
		_color = color
		_size = size
		_reduced = reduced
		_t = 0.0
		visible = true
		modulate = Color(1, 1, 1, 1)
		queue_redraw()

	func _process(delta: float) -> void:
		if not visible:
			return
		_t += delta
		if _t >= _dur:
			visible = false
			clear_points_safe()
			return
		queue_redraw()

	func clear_points_safe() -> void:
		queue_redraw()

	func _draw() -> void:
		if not visible:
			return
		var k := _t / _dur
		var r := _size * (0.35 + k * 0.85)
		var alpha := 1.0 - k
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(_color, alpha * 0.9), 7.0 + 6.0 * (1.0 - k), true)
		draw_arc(Vector2.ZERO, r * 0.72, 0, TAU, 32, Color(Color.WHITE, alpha * 0.5), 3.0, true)
