extends Node3D

# A small trap dart: flies straight, checked by ray each frame (walls, the player,
# enemies). Hitting the player goes through receive_attack, so blocks, wards,
# dodges and parries work; an unblocked hit may poison.

var damage := 10.0
var poison_chance := 0.35
var velocity := Vector3.ZERO
var _life := 3.0
var _ignore_player := false   # dodged: it flies on past
var _mesh: MeshInstance3D


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var shaft := CylinderMesh.new()
	shaft.top_radius = 0.008
	shaft.bottom_radius = 0.012
	shaft.height = 0.22
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.22, 0.2)
	shaft.material = material
	_mesh.mesh = shaft
	_mesh.rotation_degrees.x = 90.0   # the cylinder's axis along -Z
	add_child(_mesh)


func launch(from: Vector3, direction: Vector3, speed: float) -> void:
	global_position = from
	velocity = direction.normalized() * speed
	look_at(from + velocity, Vector3.UP if absf(direction.normalized().y) < 0.99 else Vector3.RIGHT)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()
		return
	var step := velocity * delta
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + step, 1 | 2 | 4)
	if _ignore_player:
		var player := get_tree().get_first_node_in_group("player")
		if player:
			query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position += step
		return
	var body: Node = hit["collider"]
	if body.is_in_group("player"):
		var result: String = body.receive_attack(damage, self, 6.0)
		if result == "dodged":
			_ignore_player = true
			global_position += step
			return
		if result == "hit":
			Sfx.play("hit_flesh", -4.0)
			if randf() < poison_chance and body.get("effects"):
				body.effects.apply("poisoned")
		queue_free()
	elif body.has_method("take_hit"):
		body.take_hit(damage, global_position - velocity, 1.0, 4.0)
		queue_free()
	else:
		Sfx.play_at("arrow_thud", hit["position"], -6.0)
		global_position = hit["position"]
		set_physics_process(false)   # stuck in the wall
		get_tree().create_timer(4.0, false).timeout.connect(queue_free)
