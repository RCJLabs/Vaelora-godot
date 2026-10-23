extends CharacterBody3D

# A Greyfang wolf. Wanders near where it was placed, chases the player who
# comes close, bites, and gives up if dragged too far from home.
# Any node with take_hit(damage, from_position) can be hit by the player.

signal died

## Shown on the corpse. Empty while alive (the interaction ray can't see live wolves anyway).
var prompt: String = ""
var _skinned := false

enum State { IDLE, CHASE, ATTACK, RETURN, DEAD }

@export var run_speed: float = 6.0          # player walks 5, sprints 8: you can outrun it
@export var wander_speed: float = 1.5
@export var aggro_range: float = 14.0
@export var leash_range: float = 30.0       # max distance from home before it gives up
@export var bite_range: float = 1.7
@export var bite_damage: float = 5.0
@export var bite_cooldown: float = 1.5

@onready var stats: Stats = $Stats
@onready var model: Node3D = $Model

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var state := State.IDLE
var home: Vector3

var _bite_left := 0.0
var _wander_target: Vector3
var _wander_wait := 0.0
var _knockback := Vector3.ZERO
var _fur: StandardMaterial3D


func _ready() -> void:
	home = global_position
	_wander_target = home
	stats.died.connect(_on_died)
	stats.damaged.connect(_on_damaged)
	# Own copy of the fur material so only this wolf flashes when hit.
	_fur = ($Model/Body as MeshInstance3D).mesh.surface_get_material(0).duplicate()
	for part in model.get_children():
		if part is MeshInstance3D and part.name != "Eyes":
			part.material_override = _fur


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	_bite_left -= delta

	var player := get_tree().get_first_node_in_group("player")
	var paused: bool = player == null or player.is_dead or DialogueManager.is_active
	if paused:
		_move_toward(global_position, 0.0, delta)   # stand still
	else:
		_think(player, delta)

	var push := _knockback
	velocity += push
	move_and_slide()
	velocity -= push
	_knockback = _knockback.move_toward(Vector3.ZERO, 30.0 * delta)


func _think(player: Node3D, delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var from_home := Vector2(global_position.x - home.x, global_position.z - home.z).length()

	match state:
		State.IDLE:
			if dist < aggro_range:
				state = State.CHASE
			else:
				_wander(delta)
		State.CHASE:
			if from_home > leash_range:
				state = State.RETURN
			elif dist <= bite_range:
				state = State.ATTACK
			else:
				_move_toward(player.global_position, run_speed, delta)
		State.ATTACK:
			if dist > bite_range * 1.3:
				state = State.CHASE
			else:
				_move_toward(global_position, 0.0, delta)
				_face(player.global_position, delta)
				if _bite_left <= 0.0:
					_bite(player)
		State.RETURN:
			if from_home < 1.0:
				state = State.IDLE
				stats.refill()
			elif dist < aggro_range * 0.5:
				state = State.CHASE   # you followed it back: fight on
			else:
				_move_toward(home, run_speed * 0.7, delta)


func _bite(player: Node) -> void:
	_bite_left = bite_cooldown
	player.stats.take_damage(bite_damage)
	# small lunge so the bite reads visually
	var tween := create_tween()
	tween.tween_property(model, "position:z", -0.35, 0.08)
	tween.tween_property(model, "position:z", 0.0, 0.2)


func _wander(delta: float) -> void:
	var to_target := _wander_target - global_position
	to_target.y = 0.0
	if to_target.length() < 0.5:
		_move_toward(global_position, 0.0, delta)
		_wander_wait -= delta
		if _wander_wait <= 0.0:
			_wander_wait = randf_range(2.0, 5.0)
			_wander_target = home + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4))
	else:
		_move_toward(_wander_target, wander_speed, delta)


func _move_toward(target: Vector3, speed: float, delta: float) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if speed <= 0.0 or dir.length() < 0.1:
		velocity.x = move_toward(velocity.x, 0.0, 30.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 30.0 * delta)
		return
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(target, delta)


func _face(target: Vector3, delta: float) -> void:
	var dir := target - global_position
	if Vector2(dir.x, dir.z).length() < 0.05:
		return
	var target_yaw := atan2(-dir.x, -dir.z)   # the model faces -Z
	rotation.y = lerp_angle(rotation.y, target_yaw, minf(10.0 * delta, 1.0))


## Called by the player's sword (knockback 5) and spells (knockback 0).
func take_hit(damage: float, from_position: Vector3, knockback: float = 5.0) -> void:
	if state == State.DEAD:
		return
	if knockback > 0.0:
		var push := global_position - from_position
		push.y = 0.0
		_knockback = push.normalized() * knockback
	if state == State.IDLE or state == State.RETURN:
		state = State.CHASE   # hit from outside aggro range: it still comes for you
	stats.take_damage(damage)


var _flash_tween: Tween


func _on_damaged(_amount: float) -> void:
	if _flash_tween:
		_flash_tween.kill()   # spells hit every frame: restart instead of stacking
	var tween := create_tween()
	_flash_tween = tween
	tween.tween_property(_fur, "albedo_color", Color(0.8, 0.15, 0.1), 0.05)
	tween.tween_property(_fur, "albedo_color", Color(0.3, 0.3, 0.32), 0.25)


## Dead wolves can be skinned with E for a pelt.
func interact(_player: Node) -> void:
	if state != State.DEAD or _skinned:
		return
	_skinned = true
	prompt = ""
	collision_layer = 0   # nothing left to interact with
	Inventory.add("wolf_pelt")


func _on_died() -> void:
	state = State.DEAD
	collision_layer = 8   # layer 4 "loot": the E ray finds it, the player walks through it
	collision_mask = 0
	prompt = "Skin wolf"
	velocity = Vector3.ZERO
	$Model/Eyes.visible = false
	var tween := create_tween().set_parallel()
	tween.tween_property(model, "rotation:z", deg_to_rad(90), 0.4)
	tween.tween_property(model, "position:y", -0.25, 0.4)
	died.emit()
