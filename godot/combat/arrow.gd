class_name Arrow
extends Node3D

# A flying arrow. Moves under (reduced) gravity and checks the path it covers
# each frame with a ray, so even fast arrows can't skip through thin targets.
# Hits anything with take_hit() on the enemies layer; sticks into the world.

signal hit(target: Node, damage: float)

const GRAVITY_SCALE := 0.6
const LIFETIME := 8.0         # seconds in flight before it's removed
const STUCK_LIFETIME := 15.0  # seconds it stays stuck in the ground or a wall

var velocity := Vector3.ZERO
var damage := 10.0
var poise_damage := 5.0
var shooter: Node3D

var _life := LIFETIME
var _stuck := false


## Starts the arrow at `from`, flying along `direction` at `speed` m/s.
func launch(from: Vector3, direction: Vector3, speed: float) -> void:
	global_position = from
	velocity = direction.normalized() * speed
	_face_velocity()


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	if _stuck:
		return
	velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * GRAVITY_SCALE * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)   # world + enemies
	if shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = to
		_face_velocity()
		return
	global_position = result["position"]
	var target: Object = result["collider"]
	if target.has_method("take_hit"):
		var origin := shooter.global_position if is_instance_valid(shooter) else from
		target.take_hit(damage, origin, 1.5, poise_damage)
		hit.emit(target, damage)
		Sfx.play_at("hit_flesh", global_position, -4.0)
		queue_free()
	else:
		_stuck = true
		_life = STUCK_LIFETIME
		Sfx.play_at("arrow_thud", global_position, -6.0)


func _face_velocity() -> void:
	if velocity.length() > 0.1 and absf(velocity.normalized().y) < 0.999:
		look_at(global_position + velocity, Vector3.UP)
