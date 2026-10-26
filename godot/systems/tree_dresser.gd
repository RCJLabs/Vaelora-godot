extends Node

# Greybox trees, fuller: every pine crown in a level (a MeshInstance3D named
# "Canopy" or "Crown" whose mesh is a cone, a CylinderMesh with no top) is swapped,
# as it enters the tree, for three stacked, faceted cones, darker at the bottom and
# each tree a slightly different green (from where it stands, so the same every
# time). Works on hand-made levels and generated ones alike; collision is untouched.
# Autoloaded as "TreeDresser". docs/godot-starter/LOOK.md, "Trees and houses".

const LAYERS := [   # radius, height (shares of the cone's), centre (share of height above its middle), shade
	[1.0, 0.5, -0.25, 0.8],
	[0.78, 0.45, 0.0, 1.0],
	[0.52, 0.4, 0.3, 1.18],
]

var _meshes := {}   # [radius, height, shade, variant] -> CylinderMesh


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node) -> void:
	if node is MeshInstance3D and (node.name == &"Canopy" or node.name == &"Crown"):
		_dress.call_deferred(node)


func is_pine(crown: MeshInstance3D) -> bool:
	return crown.mesh is CylinderMesh and is_zero_approx(crown.mesh.top_radius) and not crown.has_meta("dressed")


func _dress(crown: MeshInstance3D) -> void:
	if not is_instance_valid(crown) or not crown.is_inside_tree() or not is_pine(crown):
		return
	crown.set_meta("dressed", true)
	var cone: CylinderMesh = crown.mesh
	var base: Color = Color(0.15, 0.25, 0.12)
	if cone.material is StandardMaterial3D:
		base = cone.material.albedo_color
	var spot := crown.global_position
	var variant := absi(hash(Vector2i(roundi(spot.x * 10.0), roundi(spot.z * 10.0)))) % 4
	var tint: Color = [Color(1, 1, 1), Color(0.9, 1.05, 0.9), Color(1.08, 1.04, 0.85), Color(0.85, 0.95, 1.0)][variant]
	for i in LAYERS.size():
		var l: Array = LAYERS[i]
		var layer := MeshInstance3D.new()
		layer.name = "CrownLayer%d" % i
		layer.mesh = _layer_mesh(cone.bottom_radius * l[0], cone.height * l[1], (base * tint * l[3]).clamp(), variant)
		layer.transform = crown.transform * Transform3D(Basis(Vector3.UP, 0.5 * i + variant), Vector3(0, cone.height * l[2], 0))
		layer.cast_shadow = crown.cast_shadow
		layer.layers = crown.layers
		crown.get_parent().add_child(layer)
	crown.visible = false


func _layer_mesh(radius: float, height: float, color: Color, variant: int) -> CylinderMesh:
	var key := "%.2f/%.2f/%s/%d" % [radius, height, color.to_html(false), variant]
	if not _meshes.has(key):
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = radius
		m.height = height
		m.radial_segments = 7   # faceted: low-poly needles, not a smooth party hat
		m.rings = 1
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 1.0
		m.material = mat
		_meshes[key] = m
	return _meshes[key]
