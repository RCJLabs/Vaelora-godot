extends CharacterBody3D

# A stone guardian: a boss that stands as a statue until its BossArena wakes it.
# Built from boxes and posed in code (no animation needed), like the bandits.
#
#   Slam:   both arms rise over its head (about 1 s, eyes flare), then smash the
#           ground in front: big damage in a circle. Afterwards its fists are stuck
#           for a moment: hits then do 1.5x damage. Step out, dodge, or block (costly).
#   Sweep:  one arm swings out to the side, then sweeps a wide arc in front.
#   Phase 2 (half health): eyes turn red, it winds up faster and moves quicker,
#           and each slam sends a shockwave rolling outward along the floor: jump it.
# Heavy and hard to stagger: poise breaks only after a lot of hits; then it
# kneels for a few seconds. Weapons and spells hurt it the same.
# Stays dead once killed (WorldState), and drops a Guardian Heart.

signal died
signal phase_changed(phase: int)

enum State { DORMANT, CHASE, WINDUP, STRIKE, RECOVER, STAGGER, DEAD }

@export var display_name: String = "Stone Guardian"
@export var speed: float = 2.3
@export var turn_speed: float = 2.2         # radians per second
@export var slam_damage: float = 30.0
@export var slam_radius: float = 2.4
@export var slam_reach: float = 2.6         # how far in front the slam lands
@export var sweep_damage: float = 22.0
@export var sweep_radius: float = 3.6
@export var shockwave_damage: float = 15.0
@export var shockwave_range: float = 10.0
@export var punish_mult: float = 1.5
@export var stagger_time: float = 3.0

@onready var stats: Stats = $Stats
@onready var effects: StatusEffects = $StatusEffects
@onready var model: Node3D = $Model
@onready var left_arm: Node3D = $Model/LeftShoulder
@onready var right_arm: Node3D = $Model/RightShoulder
@onready var eye_light: OmniLight3D = $Model/Head/EyeLight

const WINDUP := {"slam": 1.1, "sweep": 0.8}
const RECOVER := {"slam": 1.4, "sweep": 0.7}

var state := State.DORMANT
var phase := 1
var prompt := ""
var _attack := ""
var _state_left := 0.0
var _cooldown := 0.0
var _eye_material: StandardMaterial3D
var _stone_material: StandardMaterial3D
var _player: Node3D
var _tween: Tween


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("persistent")
	stats.died.connect(_on_died)
	stats.damaged.connect(_on_damaged)
	stats.poise_broken.connect(func(): _stagger())
	_eye_material = StandardMaterial3D.new()
	_eye_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_eye_material.albedo_color = Color(0.2, 0.25, 0.3)   # dark while dormant
	for eye in [$Model/Head/EyeL, $Model/Head/EyeR]:
		eye.material_override = _eye_material
	_stone_material = $Model/Body.mesh.material.duplicate()
	for part in model.find_children("*", "MeshInstance3D", true, false):
		if not part.name.begins_with("Eye"):
			part.material_override = _stone_material
	eye_light.light_energy = 0.0
	WorldState.restore(self)


func is_defeated() -> bool:
	return state == State.DEAD


## The arena calls this when the player walks in.
func wake(player: Node3D) -> void:
	if state != State.DORMANT:
		return
	_player = player
	state = State.CHASE
	_cooldown = 1.2
	Sfx.play_at("guardian_wake", global_position)
	var tween := create_tween().set_parallel()
	tween.tween_property(_eye_material, "albedo_color", Color(0.55, 0.85, 1.0), 0.8)
	tween.tween_property(eye_light, "light_energy", 2.0, 0.8)
	Hints.show_once("boss_guardian", "Watch its arms. Raised high: a slam, so step out of reach or dodge. Swung to the side: a sweep. After a slam its fists are stuck; that's your opening.")


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	if state == State.DEAD or state == State.DORMANT:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("player")
	var target_velocity := Vector3.ZERO
	if _player and not _player.is_dead:
		target_velocity = _think(delta)
	velocity.x = target_velocity.x
	velocity.z = target_velocity.z
	move_and_slide()


func _think(delta: float) -> Vector3:
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	_state_left -= delta
	_cooldown -= delta
	match state:
		State.CHASE:
			_turn_toward(to_player, delta, 1.0)
			if _cooldown <= 0.0 and dist < 3.4:
				_start_attack("sweep" if dist < 3.0 and randf() < 0.45 else "slam")
				return Vector3.ZERO
			if dist > 2.6:
				return -global_transform.basis.z * speed * (1.3 if phase == 2 else 1.0)
		State.WINDUP:
			_turn_toward(to_player, delta, 0.5)   # commits: turns slowly while winding up
			if _state_left <= 0.0:
				_strike()
		State.STRIKE:
			if _state_left <= 0.0:
				state = State.RECOVER
				_state_left = RECOVER[_attack]
		State.RECOVER:
			if _state_left <= 0.0:
				state = State.CHASE
				_cooldown = randf_range(0.5, 1.0) * (0.7 if phase == 2 else 1.0)
				_pose("rest", 0.4)
		State.STAGGER:
			if _state_left <= 0.0:
				state = State.CHASE
				_cooldown = 0.8
				_pose("rest", 0.5)
	return Vector3.ZERO


func _turn_toward(direction: Vector3, delta: float, rate: float) -> void:
	if direction.length() < 0.1:
		return
	var want := atan2(-direction.x, -direction.z)
	rotation.y = rotate_toward(rotation.y, want, turn_speed * rate * delta)


func _start_attack(attack: String) -> void:
	_attack = attack
	state = State.WINDUP
	_state_left = WINDUP[attack] * (0.75 if phase == 2 else 1.0)
	_pose(attack + "_windup", _state_left * 0.8)
	Sfx.play_at("guardian_windup", global_position, -2.0)
	var flare := create_tween()
	flare.tween_property(eye_light, "light_energy", 5.0, _state_left)
	flare.tween_property(eye_light, "light_energy", 2.0, 0.3)


func _strike() -> void:
	state = State.STRIKE
	_state_left = 0.25
	_pose(_attack + "_strike", 0.12)
	if _attack == "slam":
		var center := global_position - global_transform.basis.z * slam_reach
		Sfx.play_at("guardian_slam", center, 4.0)
		SpellBurst.spawn(_world(), center + Vector3.UP * 0.1, slam_radius, Color(0.6, 0.55, 0.45))
		if _player.global_position.distance_to(center) < slam_radius + 0.4 and _player.global_position.y - center.y < 1.4:
			_player.receive_attack(slam_damage, self, 70.0)
		if phase == 2:
			_shockwave(center)
	else:
		Sfx.play_at("swing_heavy", global_position, 4.0)
		var to_player := _player.global_position - global_position
		to_player.y = 0.0
		var forward := -global_transform.basis.z
		if to_player.length() < sweep_radius and rad_to_deg(forward.angle_to(to_player)) < 100.0:
			_player.receive_attack(sweep_damage, self, 45.0)


# A ring rolling outward along the floor; it hits whoever is standing on the floor
# where it passes (jump over it).
func _shockwave(center: Vector3) -> void:
	var ring := Node3D.new()
	ring.set_script(load("res://enemies/shockwave.gd"))
	ring.set("damage", shockwave_damage)
	ring.set("max_radius", shockwave_range)
	ring.set("source", self)
	_world().add_child(ring)
	ring.global_position = center


func _world() -> Node:
	var level := get_tree().current_scene
	return level if level else get_parent()


## Weapons, arrows and spells. While it's recovering from a slam, hits do extra.
func take_hit(damage: float, _from_position: Vector3, _knockback: float = 5.0, poise_damage: float = 0.0, _heavy: bool = false) -> String:
	if state == State.DEAD:
		return "hit"
	if state == State.DORMANT:
		Sfx.play_at("block", global_position, -4.0)
		return "blocked"   # just a statue for now
	var mult := punish_mult if state == State.RECOVER and _attack == "slam" else 1.0
	stats.take_damage(damage * mult)
	if state != State.DEAD:
		stats.take_poise_damage(poise_damage)
	return "hit"


func add_effect(id: String) -> void:
	effects.apply(id)


func _stagger() -> void:
	if state == State.DEAD or state == State.DORMANT:
		return
	state = State.STAGGER
	_state_left = stagger_time
	_pose("kneel", 0.3)
	Sfx.play_at("guard_break", global_position, 4.0)


func _on_damaged(_amount: float) -> void:
	var flash := create_tween()
	flash.tween_property(_stone_material, "albedo_color", Color(0.9, 0.85, 0.8), 0.04)
	flash.tween_property(_stone_material, "albedo_color", Color(0.42, 0.4, 0.38), 0.2)
	if phase == 1 and stats.health <= stats.max_health * 0.5 and stats.health > 0.0:
		_enter_phase_two()


func _enter_phase_two() -> void:
	phase = 2
	Sfx.play_at("guardian_wake", global_position, 4.0)
	var tween := create_tween().set_parallel()
	tween.tween_property(_eye_material, "albedo_color", Color(1.0, 0.3, 0.15), 0.6)
	eye_light.light_color = Color(1.0, 0.35, 0.2)
	phase_changed.emit(2)


func _on_died() -> void:
	state = State.DEAD
	collision_layer = 0
	_eye_material.albedo_color = Color(0.1, 0.1, 0.1)
	eye_light.light_energy = 0.0
	Sfx.play_at("guardian_crumble", global_position, 4.0)
	# Crumble: every part drops and tumbles a little.
	for part in model.find_children("*", "MeshInstance3D", true, false):
		var tween := part.create_tween().set_parallel()
		var drop: float = part.global_position.y - global_position.y - 0.25
		tween.tween_property(part, "global_position:y", part.global_position.y - drop, randf_range(0.4, 0.8)).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tween.tween_property(part, "rotation", part.rotation + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)), 0.6)
	_drop_heart()
	died.emit()


func _drop_heart() -> void:
	var drop := StaticBody3D.new()
	drop.set_script(load("res://interactables/pickup.gd"))
	drop.set("item_id", "guardian_heart")
	drop.set("remember", false)
	drop.collision_layer = 8
	drop.collision_mask = 0
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3.ONE * 0.4
	shape.shape = box
	drop.add_child(shape)
	var mesh := MeshInstance3D.new()
	var gem := BoxMesh.new()
	gem.size = Vector3.ONE * 0.22
	mesh.mesh = gem
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.albedo_color = Color(1.0, 0.55, 0.3)
	mesh.material_override = glow_material
	mesh.rotation = Vector3(0.6, 0.6, 0.0)
	drop.add_child(mesh)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.5, 0.3)
	glow.omni_range = 2.5
	drop.add_child(glow)
	_world().add_child(drop)
	drop.global_position = global_position + Vector3.UP * 0.4


# --- poses. It faces -Z, so its right arm is on +X. Arm pivots: X 0 = hanging,
# 90 = forward, 180 = straight up; Z tilts the arm out to the side. Lean < 0 bends forward.

const POSES := {
	"rest":         {"left": Vector3(10, 0, -8), "right": Vector3(10, 0, 8), "lean": 0.0, "twist": 0.0, "low": 0.0},
	"slam_windup":  {"left": Vector3(190, 0, -10), "right": Vector3(190, 0, 10), "lean": 10.0, "twist": 0.0, "low": 0.0},
	"slam_strike":  {"left": Vector3(60, 0, -5), "right": Vector3(60, 0, 5), "lean": -28.0, "twist": 0.0, "low": 0.0},
	"sweep_windup": {"left": Vector3(20, 0, -10), "right": Vector3(0, 0, 95), "lean": 0.0, "twist": -55.0, "low": 0.0},
	"sweep_strike": {"left": Vector3(20, 0, -10), "right": Vector3(0, 0, 95), "lean": -8.0, "twist": 65.0, "low": 0.0},
	"kneel":        {"left": Vector3(30, 0, -20), "right": Vector3(30, 0, 20), "lean": -25.0, "twist": 0.0, "low": 0.7},
}


func _pose(pose_name: String, seconds: float) -> void:
	var pose: Dictionary = POSES[pose_name]
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(left_arm, "rotation_degrees", pose["left"], seconds)
	_tween.tween_property(right_arm, "rotation_degrees", pose["right"], seconds)
	_tween.tween_property(model, "rotation_degrees", Vector3(pose["lean"], pose["twist"], 0.0), seconds)
	_tween.tween_property(model, "position:y", -pose["low"], seconds)


# --- persistence -------------------------------------------------------------------------

func get_persist_state() -> Dictionary:
	return {"dead": state == State.DEAD}


func apply_persist_state(saved: Dictionary) -> void:
	if saved.get("dead", false):
		state = State.DEAD
		died.emit()
		queue_free()
