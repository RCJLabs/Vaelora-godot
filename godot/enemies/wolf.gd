extends CharacterBody3D

# A Greyfang wolf. Wanders near where it was placed, chases the player who
# comes close, bites, and gives up if dragged too far from home.
# Finds its way around obstacles with its NavigationAgent3D, using the level's
# NavigationRegion3D. Without one it simply runs straight at its target.
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
## Chance (0-1) that a bite makes the target bleed.
@export var bleed_chance: float = 0.25

@onready var stats: Stats = $Stats
@onready var effects: StatusEffects = $StatusEffects
@onready var model: Node3D = $Model
@onready var agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var state := State.IDLE
var home: Vector3

var _bite_left := 0.0
var _wander_target: Vector3
var _wander_wait := 0.0
var _knockback := Vector3.ZERO
var _fur: StandardMaterial3D
var _flank_angle := 0.0     # where around the player this wolf is heading
var _close_in := false      # within 4 m and circling in on its flank spot
var _blocked_time := 0.0    # how long a packmate has been in the way


func _ready() -> void:
	add_to_group("persistent")
	home = global_position
	_wander_target = home
	stats.died.connect(_on_died)
	stats.damaged.connect(_on_damaged)
	# Own copy of the fur material so only this wolf flashes when hit.
	_fur = ($Model/Body as MeshInstance3D).mesh.surface_get_material(0).duplicate()
	for part in model.get_children():
		if part is MeshInstance3D and part.name != "Eyes":
			part.material_override = _fur
	WorldState.restore(self)


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
				_start_hunt()
			else:
				_wander(delta)
		State.CHASE:
			if from_home > leash_range:
				state = State.RETURN
			elif dist <= bite_range:
				state = State.ATTACK
			elif dist < 4.0:
				_close_in_on(player, delta)
			else:
				_close_in = false
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


# Start chasing, and tell the pack (the WolfPack parent, if any) so the
# others join in instead of wandering while their packmates fight.
func _start_hunt() -> void:
	state = State.CHASE
	if get_parent().has_method("alert"):
		get_parent().alert(self)


## Called by the pack when a packmate starts hunting.
func join_hunt() -> void:
	if state == State.IDLE or state == State.RETURN:
		state = State.CHASE


# Up close, head for a spot beside the player rather than the player's exact
# position, so a pack spreads around you instead of queueing up. Each wolf
# starts from the side it's already on, and circles further round if a
# packmate is in its way.
func _close_in_on(player: Node3D, delta: float) -> void:
	var from_player := global_position - player.global_position
	if not _close_in:
		_close_in = true
		_flank_angle = atan2(from_player.z, from_player.x) + randf_range(-0.5, 0.5)
		_blocked_time = 0.0
	if _blocked_by_packmate():
		_blocked_time += delta
		if _blocked_time > 0.5:
			_blocked_time = 0.0
			_flank_angle += deg_to_rad(70.0)
	else:
		_blocked_time = 0.0
	var side := Vector3(cos(_flank_angle), 0.0, sin(_flank_angle))
	_move_toward(player.global_position + side, run_speed, delta)


func _blocked_by_packmate() -> bool:
	if Vector2(get_real_velocity().x, get_real_velocity().z).length() > 1.0:
		return false   # still making progress
	for i in get_slide_collision_count():
		var other := get_slide_collision(i).get_collider()
		if other != self and other is CharacterBody3D and other.has_signal("died"):
			return true
	return false


func _bite(player: Node) -> void:
	_bite_left = bite_cooldown
	player.stats.take_damage(bite_damage)
	if randf() < bleed_chance and player.get("effects"):
		player.effects.apply("bleeding")
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
	var step := _next_path_point(target) - global_position
	step.y = 0.0
	if step.length() < 0.05:
		step = dir
	step = step.normalized()
	speed *= stats.modifier("move_speed")
	velocity.x = step.x * speed
	velocity.z = step.z * speed
	_face(global_position + step, delta)


# Next corner on the way to `target`, or the target itself when there's no
# navigation (no NavigationRegion3D in the level, or the map isn't ready yet).
func _next_path_point(target: Vector3) -> Vector3:
	if agent == null or NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return target
	if agent.target_position.distance_to(target) > 0.5:   # don't re-plan every frame
		agent.target_position = target
	if agent.is_navigation_finished():
		return target
	return agent.get_next_path_position()


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
		_start_hunt()   # hit from outside aggro range: it still comes for you
	stats.take_damage(damage)


var _flash_tween: Tween


## Spells and weapons can leave status effects (e.g. Flames -> burning).
func add_effect(id: String) -> void:
	effects.apply(id)


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
	_become_corpse(true)
	died.emit()


func _become_corpse(animate: bool) -> void:
	state = State.DEAD
	collision_layer = 8   # layer 4 "loot": the E ray finds it, the player walks through it
	collision_mask = 0
	prompt = "Skin wolf"
	velocity = Vector3.ZERO
	$Model/Eyes.visible = false
	if animate:
		var tween := create_tween().set_parallel()
		tween.tween_property(model, "rotation:z", deg_to_rad(90), 0.4)
		tween.tween_property(model, "position:y", -0.25, 0.4)
	else:
		model.rotation.z = deg_to_rad(90)
		model.position.y = -0.25


# --- WorldState: dead wolves stay dead, skinned ones are gone ---------------------

func get_persist_state() -> Dictionary:
	return {"dead": state == State.DEAD, "skinned": _skinned,
			"position": [global_position.x, global_position.y, global_position.z]}


func apply_persist_state(saved: Dictionary) -> void:
	if not saved["dead"]:
		return   # living wolves start back at their den
	var p: Array = saved["position"]
	global_position = Vector3(p[0], p[1], p[2])
	_skinned = saved["skinned"]
	_become_corpse(false)
	if _skinned:
		queue_free()
