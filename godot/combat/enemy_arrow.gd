class_name EnemyArrow
extends Node3D

# An arrow loosed at the player (or a companion) by an enemy archer (enemies/bandit.gd,
# archer). Flies like the player's (combat/arrow.gd): reduced gravity, a ray along
# each frame's path. Whoever it strikes takes it through receive_attack(), so a raised
# shield or a parry stops it and a dodge lets it by, as with a sword. It doesn't hit
# other enemies. Where it lands, enemies can hear it (Stealth.noise).

const GRAVITY_SCALE := 0.6
const LIFETIME := 6.0
const STUCK_LIFETIME := 10.0
const LAND_NOISE := 4.0   # metres an arrow striking the ground is heard at

var velocity := Vector3.ZERO
var damage := 12.0
var poise_damage := 8.0
var shooter: Node3D

var _life := LIFETIME
var _stuck := false


## Makes the arrow's look (a shaft and a head) and starts it at `from` along `direction`.
func launch(from: Vector3, direction: Vector3, speed: float) -> void:
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.025, 0.025, 0.7)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.32, 0.18)
	box.material = wood
	shaft.mesh = box
	add_child(shaft)
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
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)   # world (and companions) + the player
	if shooter is CollisionObject3D:
		query.exclude = [shooter.get_rid()]
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		global_position = to
		_face_velocity()
		return
	global_position = result["position"]
	var target: Object = result["collider"]
	if target.has_method("receive_attack"):
		var answer: String = target.receive_attack(damage, shooter if is_instance_valid(shooter) else self, poise_damage)
		Sfx.play_at("hit_flesh" if answer == "hit" else "block", global_position, -4.0)
		queue_free()
	else:
		_stuck = true
		_life = STUCK_LIFETIME
		Sfx.play_at("arrow_thud", global_position, -6.0)
		Stealth.noise(global_position, LAND_NOISE)


func _face_velocity() -> void:
	if velocity.length() > 0.1 and absf(velocity.normalized().y) < 0.999:
		look_at(global_position + velocity, Vector3.UP)
