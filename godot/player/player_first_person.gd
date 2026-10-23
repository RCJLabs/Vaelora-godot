extends CharacterBody3D

# First-person controller for Godot 4.
# Attach to the root CharacterBody3D of player.tscn.
#
# Scene structure (origin of Player = the player's FEET):
#   Player (CharacterBody3D)        <- this script
#   ├── CollisionShape3D            CapsuleShape3D r=0.4 h=1.8, position y=0.9
#   ├── Head (Node3D)               position y=1.6, rotates up/down
#   │   └── Camera3D                Current = ON
#   │       └── InteractRay (RayCast3D)  Target Position (0, 0, -2.5)
#   ├── Stats (systems/stats.gd)    Health / Stamina / Magicka
#   └── HUD (instance of ui/hud.tscn)
#
# Controls: WASD move, Shift sprint, Space jump, mouse look, E interact,
# F5 quicksave, F9 quickload, Esc releases the mouse, left-click recaptures it.

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
@export var mouse_sensitivity: float = 0.002
@export var ground_accel: float = 40.0   # how fast you reach full speed on the ground
@export var air_accel: float = 8.0       # how much you can steer mid-air
## If the player falls below this height they get put back at the spawn point
## (and a warning is printed, because it means collision isn't working).
@export var kill_y: float = -50.0

@export_group("Stamina & falling")
@export var sprint_stamina_per_second: float = 12.0
## After running out, you can't sprint again until stamina is back to this.
@export var stamina_to_sprint_again: float = 20.0
## Landing faster than this (m/s) hurts. 9 m/s is roughly a 4 m drop.
@export var safe_fall_speed: float = 9.0
@export var fall_damage_per_speed: float = 10.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var hud: CanvasLayer = $HUD
@onready var stats: Stats = $Stats

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3
var is_dead := false
var _exhausted := false   # ran out of stamina; no sprinting until it recovers


func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	_apply_race(GameState.race_data)
	hud.track_stats(stats)
	stats.died.connect(_on_died)
	_ensure_input_actions()
	_check_collision_setup()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var saved := SaveSystem.take_pending_player_state()
	if not saved.is_empty():
		apply_save_data(saved)


func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active or is_dead:
		return   # the dialogue box owns the mouse and keys while talking

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)          # body turns left/right
		head.rotate_x(-event.relative.y * mouse_sensitivity)     # head tilts up/down
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

	var talking: bool = DialogueManager.is_active or is_dead

	if Input.is_action_just_pressed("jump") and is_on_floor() and not talking:
		velocity.y = jump_velocity

	var input_dir := Vector2.ZERO if talking else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Only drains stamina while actually moving (not when pushing against a wall).
	# From a standstill you walk for a split second, then the sprint kicks in.
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	if stats.stamina <= 0.0:
		_exhausted = true
	elif stats.stamina >= stamina_to_sprint_again:
		_exhausted = false
	var sprinting := Input.is_action_pressed("sprint") and direction != Vector3.ZERO \
			and is_on_floor() and moving and not _exhausted
	if sprinting:
		stats.use_stamina(sprint_stamina_per_second * delta)
	var target_speed := sprint_speed if sprinting else walk_speed
	var accel := ground_accel if is_on_floor() else air_accel

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.move_toward(direction * target_speed, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	var was_in_air := not is_on_floor()
	var fall_speed := -velocity.y
	move_and_slide()
	if was_in_air and is_on_floor() and fall_speed > safe_fall_speed:
		stats.take_damage((fall_speed - safe_fall_speed) * fall_damage_per_speed)

	if talking:
		hud.set_prompt("")
	else:
		_update_interaction()

	if global_position.y < kill_y:
		push_warning("Player fell below kill_y. Collision is not working - turn on Debug > Visible Collision Shapes.")
		global_position = spawn_position
		velocity = Vector3.ZERO


func _on_died() -> void:
	is_dead = true
	hud.set_prompt("")
	show_message("You have died.")
	await get_tree().create_timer(2.5).timeout
	if SaveSystem.has_save():
		SaveSystem.load_game()   # like Skyrim: back to your last save
	else:
		global_position = spawn_position
		velocity = Vector3.ZERO
		stats.refill()
		is_dead = false


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"pitch": head.rotation.x,
		"health": stats.health,
		"stamina": stats.stamina,
		"magicka": stats.magicka,
	}


func apply_save_data(data: Dictionary) -> void:
	var p: Array = data["position"]
	global_position = Vector3(p[0], p[1], p[2])
	rotation.y = data["yaw"]
	head.rotation.x = data["pitch"]
	stats.health = data["health"]
	stats.stamina = data["stamina"]
	stats.magicka = data["magicka"]
	stats.changed.emit()


# Race modifiers from res://races/*.tres (chosen on the character creation screen).
func _apply_race(race: RaceData) -> void:
	walk_speed *= race.move_speed_mult
	sprint_speed *= race.move_speed_mult
	# Jump height grows with the square of jump speed, so take the square root.
	jump_velocity *= sqrt(race.jump_height_mult)
	stats.setup(race.health, race.stamina, race.magicka)


# Whatever the crosshair points at within reach: if it has an `interact(player)`
# method it's usable. Its optional `prompt` property is shown on screen.
func _update_interaction() -> void:
	var target: Object = interact_ray.get_collider() if interact_ray.is_colliding() else null
	if target == null or not target.has_method("interact"):
		hud.set_prompt("")
		return

	var prompt = target.get("prompt")
	hud.set_prompt("[E] %s" % (prompt if prompt else "Use"))
	if Input.is_action_just_pressed("interact"):
		target.interact(self)


func show_message(text: String) -> void:
	hud.show_message(text)


# Prints a clear error for the most common "falls through the floor" mistakes.
func _check_collision_setup() -> void:
	var found_shape := false
	for child in get_children():
		if child is CollisionShape3D:
			if child.shape == null:
				push_error("Player: CollisionShape3D '%s' has no Shape. Inspector > Shape > New CapsuleShape3D." % child.name)
			elif child.disabled:
				push_error("Player: CollisionShape3D '%s' is Disabled. Untick Disabled in the Inspector." % child.name)
			else:
				found_shape = true
	if not found_shape:
		push_error("Player: no working CollisionShape3D as a DIRECT child of the CharacterBody3D.")
	if collision_mask == 0:
		push_error("Player: Collision > Mask is empty, so it can't collide with anything. Tick layer 1.")


# Adds default key bindings if they are missing from Project Settings > Input Map,
# so the script works even when copied into a fresh project.
func _ensure_input_actions() -> void:
	var defaults := {
		"move_forward": KEY_W, "move_back": KEY_S,
		"move_left": KEY_A, "move_right": KEY_D,
		"jump": KEY_SPACE, "sprint": KEY_SHIFT, "interact": KEY_E,
		"quicksave": KEY_F5, "quickload": KEY_F9,
	}
	for action in defaults:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key_event := InputEventKey.new()
			key_event.physical_keycode = defaults[action]
			InputMap.action_add_event(action, key_event)
