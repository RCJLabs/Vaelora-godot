extends "res://props/campfire.gd"

# A fire you made from firewood (Bushcraft.make_camp): a campfire like any other
# (cook, rest, warmth) that burns out after a few in-game hours, resting included.
# Ember Ward (Survival perk): it heals you while you're in its warmth. It builds
# its own logs and flame, and isn't saved: a fire doesn't outlast a reload.

var hours_left := 3.0
var _out_at := 0.0              # WorldClock time (days * 24 + hour) it goes out


func _ready() -> void:
	super()
	add_to_group("camp_fire")
	_out_at = _now() + hours_left
	for angle in [45.0, -45.0]:
		var log_mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.9, 0.12, 0.14)
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.32, 0.2, 0.11)
		box.material = wood
		log_mesh.mesh = box
		log_mesh.position = Vector3(0, 0.07, 0)
		log_mesh.rotation.y = deg_to_rad(angle)
		add_child(log_mesh)
	var flame := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.25
	cone.height = 0.6
	var fire := StandardMaterial3D.new()
	fire.albedo_color = Color(1.0, 0.55, 0.15)
	fire.emission_enabled = true
	fire.emission = Color(1.0, 0.5, 0.1)
	fire.emission_energy_multiplier = 3.0
	cone.material = fire
	flame.mesh = cone
	flame.position = Vector3(0, 0.4, 0)
	flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1, 0.6, 0.3)
	light.light_energy = 2.0
	light.omni_range = 8.0
	light.position = Vector3(0, 0.7, 0)
	add_child(light)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.4
	cylinder.height = 0.5
	shape.shape = cylinder
	shape.position = Vector3(0, 0.25, 0)
	add_child(shape)


func _now() -> float:
	return WorldClock.day * 24.0 + WorldClock.hour


func _process(delta: float) -> void:
	if _now() >= _out_at:
		queue_free()
		return
	if "ember_ward" in Character.perks:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.global_position.distance_to(global_position) <= heat_radius:
			player.stats.heal(1.0 * delta)
