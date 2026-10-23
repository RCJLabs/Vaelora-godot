class_name SpellBolt
extends Node3D

# A spell projectile (Firebolt): flies straight, glowing, and bursts on the
# first thing it touches. Like Arrow, it ray-checks the path each frame.

signal hit(target: Node, damage: float)

const LIFETIME := 4.0

var velocity := Vector3.ZERO
var damage := 20.0
var poise_damage := 8.0
var applies_effect := ""
var color := Color(1, 0.5, 0.15)
var shooter: Node3D
var _life := LIFETIME


func launch(from: Vector3, direction: Vector3, speed: float, size: float = 1.0) -> void:
	global_position = from
	velocity = direction.normalized() * speed
	scale = Vector3.ONE * size
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	$Core.material_override = material
	$Light.light_color = color


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	if shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = to
		return
	var target: Object = result["collider"]
	if target.has_method("take_hit"):
		var origin := shooter.global_position if is_instance_valid(shooter) else from
		target.take_hit(damage, origin, 2.0, poise_damage)
		if applies_effect != "" and target.has_method("add_effect"):
			target.add_effect(applies_effect)
		hit.emit(target, damage)
	SpellBurst.spawn(get_parent(), result["position"], 0.8 * scale.x, color)
	Sfx.play_at("spell_impact", result["position"])
	queue_free()
