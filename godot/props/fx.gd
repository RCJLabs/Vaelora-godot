class_name Fx
extends RefCounted

# Small particle effects, until there's art: hit sparks, fire embers, chimney and
# campfire smoke, and the motes in the air (fireflies, ash, dust). CPU particles
# with a soft round sprite, so they work on every renderer; counts kept small for
# phones, and the ambient ones scale with the graphics preset (none on Low).
# docs/godot-starter/LOOK.md, "Effects".

static var _sprite: Texture2D
static var _materials := {}


## A soft white dot, made once (a radial gradient).
static func sprite() -> Texture2D:
	if _sprite == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 32
		t.height = 32
		_sprite = t
	return _sprite


## A camera-facing, alpha-blended (or glowing) quad material for particles.
static func material(glow := false) -> StandardMaterial3D:
	var key := "glow" if glow else "soft"
	if not _materials.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_texture = sprite()
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		if glow:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_materials[key] = m
	return _materials[key]


static func _particles(amount: int, lifetime: float, size: float, glow: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = material(glow)
	p.mesh = quad
	return p


## How much of the ambient effects the preset allows (0 on Low).
static func ambient_share() -> float:
	# Looked up, not named: this class can be parsed before the autoloads exist.
	var settings := (Engine.get_main_loop() as SceneTree).root.get_node_or_null("Settings")
	if settings == null:
		return 1.0
	return float(settings.QUALITY[settings.graphics_quality].get("clutter", 1.0))


## A one-off burst at `at`: sparks off a blocked blow (`sparks`), or dust off a hit.
static func burst(tree: SceneTree, at: Vector3, sparks: bool) -> void:
	var scene := tree.current_scene
	if scene == null:
		return
	var p := _particles(16 if sparks else 10, 0.35 if sparks else 0.5, 0.07 if sparks else 0.12, sparks)
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 2.5 if sparks else 0.8
	p.initial_velocity_max = 5.0 if sparks else 1.8
	p.gravity = Vector3(0, -9.8 if sparks else -1.5, 0)
	p.scale_amount_min = 0.6
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.85, 0.45, 1) if sparks else Color(0.85, 0.8, 0.72, 0.7))
	ramp.set_color(1, Color(1.0, 0.4, 0.1, 0) if sparks else Color(0.7, 0.66, 0.6, 0))
	p.color_ramp = ramp
	scene.add_child(p)
	p.global_position = at
	p.emitting = true
	p.finished.connect(p.queue_free)


## Embers rising off a fire, under `parent` at `offset`.
static func embers(parent: Node3D, offset := Vector3(0, 0.3, 0)) -> CPUParticles3D:
	var p := _particles(14, 1.6, 0.05, true)
	p.name = "Embers"
	p.position = offset
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.4
	p.gravity = Vector3(0.2, 0.4, 0)
	var ramp := Gradient.new()
	ramp.set_color(0, Color(1.0, 0.75, 0.3, 1))
	ramp.set_color(1, Color(1.0, 0.3, 0.05, 0))
	p.color_ramp = ramp
	parent.add_child(p)
	return p


## Smoke drifting up from `offset` under `parent` (a chimney, a campfire).
static func smoke(parent: Node3D, offset: Vector3, amount := 8, color := Color(0.58, 0.57, 0.56, 0.55)) -> CPUParticles3D:
	var p := _particles(amount, 6.0, 1.3, false)
	p.name = "Smoke"
	p.position = offset
	p.direction = Vector3.UP
	p.spread = 12.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 0.8
	p.gravity = Vector3(0.25, 0.05, 0.1)   # a light breeze
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var grow := Curve.new()
	grow.add_point(Vector2(0, 0.4))
	grow.add_point(Vector2(1, 2.4))
	p.scale_amount_curve = grow
	var ramp := Gradient.new()
	ramp.set_color(0, color)
	ramp.set_color(1, Color(color.r, color.g, color.b, 0))
	p.color_ramp = ramp
	p.visibility_aabb = AABB(Vector3(-4, -1, -4), Vector3(8, 14, 8))
	parent.add_child(p)
	return p


## Motes in the air round the camera, by kind: "fireflies" (glowing, at night),
## "pollen" (pale specks by day), "ash" (grey flakes, slowly falling), "dust" (gold).
static func motes(kind: String) -> CPUParticles3D:
	var looks := {
		"fireflies": [Color(0.8, 1.0, 0.45, 1), 0.1, true, 60],
		"pollen": [Color(1.0, 0.98, 0.85, 0.6), 0.04, false, 50],
		"ash": [Color(0.78, 0.78, 0.8, 0.95), 0.1, false, 100],
		"dust": [Color(1.0, 0.85, 0.5, 0.8), 0.06, true, 60],
	}
	var l: Array = looks.get(kind, looks["pollen"])
	var p := _particles(int(l[3] * ambient_share()), 7.0, l[1], l[2])
	p.name = "Motes"
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(14, 3, 14)
	p.local_coords = false   # they stay where they are as you walk through them
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.05
	p.initial_velocity_max = 0.3
	p.gravity = Vector3(0, -0.15 if kind == "ash" else 0.0, 0)
	p.hue_variation_min = -0.02
	p.hue_variation_max = 0.02
	var clear := Color(l[0].r, l[0].g, l[0].b, 0)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.8, 1.0])
	ramp.colors = PackedColorArray([clear, l[0], l[0], clear])   # fade in, hang, fade out
	p.color_ramp = ramp
	p.visibility_aabb = AABB(Vector3(-20, -6, -20), Vector3(40, 14, 40))
	return p
