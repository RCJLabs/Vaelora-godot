class_name GroundCover
extends Node3D

# Grass, flowers, reeds and stones scattered over a level's ground, so greybox
# fields aren't bare: thousands of small meshes, drawn as MultiMeshes in CHUNK-sized
# cells (each culled on its own, and hidden past the preset's clutter range), the
# grass swaying in the wind (props/foliage.gdshader).
#
# Where: points in `area`, kept only where a ray from above lands first on a body in
# the "ground_cover" group (add it to the level's grass): so nothing grows on roads,
# paving, in rivers or under houses. The same points every time (`scatter_seed`).
# How much: `density` times the graphics preset's "clutter" (none on Low).
# docs/godot-starter/LOOK.md, "Ground cover".

const CHUNK := 20.0
const FOLIAGE_SHADER := preload("res://props/foliage.gdshader")

## What grows here: a key of STYLES.
@export_enum("meadow", "riverbank", "ashfield") var style := "meadow"
## The world rectangle (x, z) to cover.
@export var area := Rect2(-60, -60, 120, 120)
## How thick, against the style's own (1 = as designed, at High).
@export var density := 1.0
@export var scatter_seed := 1
## Highest ground to look for (rays start a little above it).
@export var top := 20.0

## Per style: what to scatter. per_m2 at density 1 on High; size = [min, max] scale;
## colors to pick from (tufts: the blades' tint; flowers: the heads').
const STYLES := {
	"meadow": [
		{"kind": "tuft", "per_m2": 0.6, "size": [0.8, 1.4], "colors": [Color(0.26, 0.36, 0.14), Color(0.3, 0.38, 0.13), Color(0.33, 0.35, 0.16)]},
		{"kind": "flower", "per_m2": 0.035, "size": [0.8, 1.2], "colors": [Color(0.95, 0.95, 0.9), Color(0.95, 0.78, 0.25), Color(0.65, 0.45, 0.9)]},
		{"kind": "stone", "per_m2": 0.006, "size": [0.15, 0.5], "colors": [Color(0.36, 0.36, 0.35), Color(0.3, 0.3, 0.29)]},
	],
	"riverbank": [
		{"kind": "tuft", "per_m2": 0.65, "size": [0.9, 1.6], "colors": [Color(0.22, 0.36, 0.15), Color(0.26, 0.38, 0.17)]},
		{"kind": "reed", "per_m2": 0.012, "size": [0.9, 1.4], "colors": [Color(0.42, 0.42, 0.22), Color(0.35, 0.4, 0.2)]},
		{"kind": "flower", "per_m2": 0.02, "size": [0.8, 1.1], "colors": [Color(0.95, 0.95, 0.9), Color(0.55, 0.65, 0.95)]},
		{"kind": "stone", "per_m2": 0.008, "size": [0.15, 0.45], "colors": [Color(0.34, 0.35, 0.34)]},
	],
	"ashfield": [
		{"kind": "tuft", "per_m2": 0.4, "size": [0.7, 1.2], "colors": [Color(0.4, 0.41, 0.35), Color(0.36, 0.37, 0.33), Color(0.44, 0.42, 0.33)]},
		{"kind": "stone", "per_m2": 0.02, "size": [0.15, 0.6], "colors": [Color(0.4, 0.4, 0.4), Color(0.3, 0.3, 0.32)]},
	],
}

var _built_for := -1.0   # the clutter factor the cover was last built at
static var _meshes := {}
static var _materials := {}


func _ready() -> void:
	Settings.changed.connect(func(): if not is_equal_approx(_factor(), _built_for): build())
	# At the end of the loading frame (the level's bodies are all in by then), so the
	# scatter's cost is part of the load, not a hitch a moment into play.
	build.call_deferred()


## The preset's clutter factor (0 on Low).
func _factor() -> float:
	return float(Settings.QUALITY[Settings.graphics_quality].get("clutter", 1.0)) * density


## Scatter everything again (at the current preset).
func build() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_built_for = _factor()
	if _built_for <= 0.0 or not is_inside_tree():
		return
	var space := get_world_3d().direct_space_state
	var rng := RandomNumberGenerator.new()
	var query := PhysicsRayQueryParameters3D.new()
	query.collision_mask = 1
	var range_end: float = Settings.QUALITY[Settings.graphics_quality].get("clutter_range", 60.0)
	for layer in STYLES[style]:
		rng.seed = hash([scatter_seed, style, layer["kind"]])
		var count := int(area.size.x * area.size.y * layer["per_m2"] * _built_for)
		var cells := {}   # Vector2i -> [Transform3D, Color]...
		for i in count:
			var x := area.position.x + rng.randf() * area.size.x
			var z := area.position.y + rng.randf() * area.size.y
			var spin := rng.randf() * TAU
			var size := rng.randf_range(layer["size"][0], layer["size"][1])
			var color: Color = layer["colors"][rng.randi() % layer["colors"].size()]
			color = color.darkened(rng.randf() * 0.15)
			query.from = Vector3(x, top, z)
			query.to = Vector3(x, top - 60.0, z)
			var hit := space.intersect_ray(query)
			if hit.is_empty() or not hit["collider"].is_in_group("ground_cover"):
				continue
			var shape := Basis(Vector3.UP, spin).scaled(Vector3.ONE * size)
			if layer["kind"] == "stone":
				shape = shape.scaled(Vector3(1.0, rng.randf_range(0.4, 0.8), rng.randf_range(0.7, 1.2)))
			var cell := Vector2i(floori(x / CHUNK), floori(z / CHUNK))
			if not cells.has(cell):
				cells[cell] = []
			cells[cell].append([Transform3D(shape, hit["position"]), color])
		for cell in cells:
			_add_chunk(layer["kind"], cells[cell], range_end)


func _add_chunk(kind: String, items: Array, range_end: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	mm.mesh = mesh_for(kind)
	mm.instance_count = items.size()
	for i in items.size():
		mm.set_instance_transform(i, items[i][0])
		mm.set_instance_custom_data(i, items[i][1])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = material_for(kind)
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if kind == "stone" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mmi.visibility_range_end = range_end * (1.6 if kind in ["stone", "reed"] else 1.0)
	add_child(mmi)


## How many of each kind are out: {"tuft": 5200, ...}.
func counts() -> Dictionary:
	var out := {}
	for mmi in get_children():
		out[mmi.multimesh.mesh.resource_name] = out.get(mmi.multimesh.mesh.resource_name, 0) + mmi.multimesh.instance_count
	return out


static func material_for(kind: String) -> Material:
	if not _materials.has(kind):
		var m := ShaderMaterial.new()
		m.shader = FOLIAGE_SHADER
		m.set_shader_parameter("sway", {"tuft": 0.09, "flower": 0.07, "reed": 0.12, "stone": 0.0}[kind])
		_materials[kind] = m
	return _materials[kind]


## The meshes, built once: UV.x is how much the instance's colour tints a vertex (1
## everywhere but a flower's stem), UV.y how much it sways (0 at the root).
static func mesh_for(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"tuft":
			for b in 9:   # a low clump: wide-rooted blades fanning out
				var a := TAU * b / 9.0 + 0.35 * (b % 2)
				var lean := Vector3(cos(a), 0, sin(a)) * (0.07 + 0.04 * (b % 3))
				var h := 0.16 + 0.05 * (b % 3)
				var side := Vector3(-sin(a), 0, cos(a)) * 0.035
				_blade(st, Vector3(cos(a), 0, sin(a)) * 0.02, side, Vector3(0, h, 0) + lean, Color(0.55, 0.55, 0.55), Color(1.0, 1.0, 1.0), 1.0)
		"reed":
			for b in 4:
				var a := TAU * b / 4.0
				var lean := Vector3(cos(a), 0, sin(a)) * 0.05
				var side := Vector3(-sin(a), 0, cos(a)) * 0.02
				_blade(st, Vector3(cos(a), 0, sin(a)) * 0.05, side, Vector3(0, 1.1 + 0.15 * b, 0) + lean, Color(0.5, 0.5, 0.5), Color(1, 1, 1), 1.0)
		"flower":
			var stem := Color(0.32, 0.5, 0.2)
			_blade(st, Vector3.ZERO, Vector3(0.012, 0, 0), Vector3(0, 0.32, 0), stem, stem, 0.0)
			_blade(st, Vector3.ZERO, Vector3(0, 0, 0.012), Vector3(0, 0.32, 0), stem, stem, 0.0)
			for petal in 5:   # a little star of a head, tinted by the instance
				var a := TAU * petal / 5.0
				var c := Vector3(0, 0.33, 0)
				var tip := c + Vector3(cos(a), 0.02, sin(a)) * 0.05
				var l := c + Vector3(cos(a - 0.6), 0, sin(a - 0.6)) * 0.02
				var r := c + Vector3(cos(a + 0.6), 0, sin(a + 0.6)) * 0.02
				for v in [[l, Vector2(1, 1)], [tip, Vector2(1, 1)], [r, Vector2(1, 1)]]:
					st.set_color(Color(1, 1, 1))
					st.set_uv(v[1])
					st.set_normal(Vector3.UP)
					st.add_vertex(v[0])
		"stone":
			var sphere := SphereMesh.new()
			sphere.radius = 0.5
			sphere.height = 0.7
			sphere.radial_segments = 7
			sphere.rings = 3
			st.create_from(sphere, 0)
			# Stones don't sway, and take the instance's colour all over.
			var arrays := st.commit_to_arrays()
			var uvs := PackedVector2Array()
			uvs.resize(arrays[Mesh.ARRAY_VERTEX].size())
			uvs.fill(Vector2(1, 0))
			arrays[Mesh.ARRAY_TEX_UV] = uvs
			var colors := PackedColorArray()
			colors.resize(uvs.size())
			colors.fill(Color(1, 1, 1))
			arrays[Mesh.ARRAY_COLOR] = colors
			var am := ArrayMesh.new()
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			am.resource_name = kind
			_meshes[kind] = am
			return am
	var mesh := st.commit()
	mesh.resource_name = kind
	_meshes[kind] = mesh
	return mesh


## One blade: a thin triangle from a root (2 points, side apart) up to a tip.
static func _blade(st: SurfaceTool, root: Vector3, side: Vector3, tip: Vector3, root_color: Color, tip_color: Color, tint: float) -> void:
	for v in [[root - side, root_color, 0.0], [tip, tip_color, 1.0], [root + side, root_color, 0.0]]:
		st.set_color(v[1])
		st.set_uv(Vector2(tint, v[2]))
		st.set_normal(Vector3.UP)   # lit like a lawn, not like knives
		st.add_vertex(v[0])
