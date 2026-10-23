extends Node3D

# A ring of force rolling outward along the floor from a slam (StoneGuardian,
# phase 2). It hits the player once if it passes under them while they're on the
# floor, so jumping clears it (dodging and blocking work too).

var damage := 15.0
var max_radius := 10.0
var speed := 6.5
var source: Node3D
var _radius := 0.4
var _hit := false
var _ring: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.9
	torus.outer_radius = 1.0
	_ring.mesh = torus
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(1.0, 0.55, 0.3, 0.8)
	_ring.material_override = _material
	_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ring)
	_ring.position.y = 0.15


func _physics_process(delta: float) -> void:
	_radius += speed * delta
	_ring.scale = Vector3(_radius, 2.5, _radius)   # thicker band than the torus' default
	_material.albedo_color.a = 0.8 * (1.0 - _radius / max_radius)
	if _radius >= max_radius:
		queue_free()
		return
	var player := get_tree().get_first_node_in_group("player")
	if _hit or player == null or player.is_dead:
		return
	var offset: Vector3 = player.global_position - global_position
	var flat := Vector2(offset.x, offset.z).length()
	if absf(flat - _radius) < 0.45 and player.is_on_floor() and absf(offset.y) < 0.6:
		_hit = true
		player.receive_attack(damage, source if is_instance_valid(source) else self, 25.0)
