class_name SpellBurst
extends Node3D

# The flash of a spell going off: a see-through sphere that swells and fades,
# with a light. Purely visual; the damage is dealt by whoever spawns it.


## Adds a burst of `radius` metres at `position` under `parent`.
static func spawn(parent: Node, position: Vector3, radius: float, color: Color) -> SpellBurst:
	var burst := SpellBurst.new()
	parent.add_child(burst)
	burst.global_position = position
	burst._play(radius, color)
	return burst


func _play(radius: float, color: Color) -> void:
	var mesh := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	mesh.mesh = sphere
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(color.r, color.g, color.b, 0.45)
	mesh.material_override = material
	mesh.scale = Vector3.ONE * radius * 0.2
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = radius * 2.5
	add_child(light)
	var tween := create_tween().set_parallel()
	tween.tween_property(mesh, "scale", Vector3.ONE * radius, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(material, "albedo_color:a", 0.0, 0.45)
	tween.tween_property(light, "light_energy", 0.0, 0.45)
	tween.chain().tween_callback(queue_free)
