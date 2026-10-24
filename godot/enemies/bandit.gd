extends CharacterBody3D

# A bandit: a humanoid that fights with the same AttackData swings as the
# player, so everything the player can do to wolves it can do back - and more.
#
#   - Its attacks are telegraphed: the sword arm winds up and the blade glints
#     (white for normal swings, red for the slower heavy). Block, parry or dodge.
#   - It raises its guard when you swing at it. A raised guard stops most of a
#     hit and makes your weapon bounce. Heavy attacks and shield bashes break
#     the guard; so does running its stamina out. Spells go straight through.
#   - Some (the leader) parry: your swing is thrown back and you stagger.
#   - A parried swing or broken poise staggers it: that's your opening.
#
# Dead bandits can be searched (E) for their gold and loot. WorldState keeps
# them dead and searched. Put them under a WolfPack-style node (enemy_pack.gd)
# so they fight together and the camp has a "cleared" flag.

signal died

enum State { IDLE, CHASE, ENGAGE, ATTACK, GUARD, STAGGER, RETURN, DEAD, FLEE }

## How many members of a group may swing at the player at once. The rest
## circle and guard, so a fight against three stays readable (and fair).
const MAX_ATTACKERS := 1
enum Phase { WINDUP, ACTIVE, RECOVERY }

@export var display_name: String = "Bandit"
@export var run_speed: float = 4.6       # slower than the player's sprint (8): you can flee
@export var aggro_range: float = 12.0
@export var leash_range: float = 28.0
## Distance it likes to fight from, and how far its swings reach.
@export var fight_range: float = 1.8
@export var reach: float = 2.2
@export var attack_damage: float = 10.0
@export var attacks: Array[AttackData] = []   # the combo, in order
@export var heavy_attack: AttackData
## Chance (0-1) it raises its guard when it sees you start a swing.
@export var guard_chance: float = 0.5
## Share of a hit its guard stops, and the chance a guarded hit is parried instead.
@export var guard_reduction: float = 0.85
@export var parry_chance: float = 0.0
@export var stagger_time: float = 1.1
@export var max_health: float = 60.0
@export_group("Loot")
@export var gold: int = 10
## Item id -> count, given when the body is searched.
@export var loot: Dictionary = {}
## Model in the right hand (a first-person weapon scene works).
@export var weapon_scene: PackedScene

@onready var stats: Stats = $Stats
@onready var effects: StatusEffects = $StatusEffects
@onready var model: Node3D = $Model
@onready var right_arm: Node3D = $Model/RightArm
@onready var left_arm: Node3D = $Model/LeftArm
@onready var weapon_holder: Node3D = $Model/RightArm/Hand
@onready var agent: NavigationAgent3D = get_node_or_null("NavigationAgent3D")

var prompt: String = ""   # set when it's a corpse
var state := State.IDLE
var home: Vector3
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _attack: AttackData
var _phase := Phase.WINDUP
var _phase_time := 0.0
var _combo_left := 0
var _is_heavy := false
var _hit_done := false
var _think_left := 0.5
var _guard_left := 0.0
var _stagger_left := 0.0
var _flee_left := 0.0
var _strafe := 1.0
var _knockback := Vector3.ZERO
var _searched := false
var _cloth: StandardMaterial3D
var _cloth_color: Color   # what a hit flash fades back to
var _glint: StandardMaterial3D   # the blade's material, flashed as the telegraph
var _pose_tween: Tween

# Arm poses (rotation in degrees). Arms hang down; +X swings them forward and up.
const ARM_POSES := {
	"rest":       [Vector3(25, 0, -8), Vector3(15, 0, 8)],
	"high_right": [Vector3(120, 35, -60), Vector3(30, 0, 10)],
	"low_left":   [Vector3(45, -40, 40), Vector3(20, 0, 10)],
	"high_left":  [Vector3(120, -35, 60), Vector3(30, 0, 10)],
	"low_right":  [Vector3(45, 40, -40), Vector3(20, 0, 10)],
	"overhead":   [Vector3(160, 0, -15), Vector3(140, 0, 10)],
	"low_center": [Vector3(55, 0, 0), Vector3(50, 0, 0)],
	"guard":      [Vector3(85, -55, 35), Vector3(70, 30, -20)],
	"stagger":    [Vector3(-15, 20, -30), Vector3(-10, -20, 30)],
}


func _ready() -> void:
	add_to_group("captors")   # beaten by bandits in Hardcore, you wake in their cage (systems/defeat.gd)
	add_to_group("persistent")
	add_to_group("enemy")
	home = global_position
	stats.max_health = max_health
	stats.refill()
	stats.died.connect(_on_died)
	stats.damaged.connect(_on_damaged)
	stats.poise_broken.connect(func(): stagger(stagger_time))
	_cloth = ($Model/Body as MeshInstance3D).mesh.surface_get_material(0).duplicate()
	$Model/Body.material_override = _cloth
	_cloth_color = _cloth.albedo_color
	if weapon_scene:
		var held := weapon_scene.instantiate()
		weapon_holder.add_child(held)
		_glint = _find_blade_material(held)
	_pose("rest", 0.01)
	WorldState.restore(self)


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_on_floor():
		velocity.y -= gravity * delta
	var player := get_tree().get_first_node_in_group("player")
	var paused: bool = player == null or player.is_dead or DialogueManager.is_active
	# Who it's after: the player or a companion, unless Glamour says otherwise.
	var foe: Node3D = null if paused else Targeting.foe_for(self, player)
	if foe == null:
		_move(Vector3.ZERO, 0.0, delta)
	else:
		_think(foe, delta)
	var push := _knockback
	velocity += push
	move_and_slide()
	velocity -= push
	_knockback = _knockback.move_toward(Vector3.ZERO, 25.0 * delta)
	if _glint:
		var target := 0.0
		if state == State.ATTACK and _phase == Phase.WINDUP:
			target = 6.0 if _is_heavy else 3.0
			_glint.emission = Color(1.0, 0.25, 0.15) if _is_heavy else Color(1.0, 0.9, 0.7)
		_glint.emission_energy_multiplier = lerpf(_glint.emission_energy_multiplier, target, minf(delta * 14.0, 1.0))


func _think(player: Node3D, delta: float) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	var from_home := Vector2(global_position.x - home.x, global_position.z - home.z).length()

	match state:
		State.IDLE:
			_move(Vector3.ZERO, 0.0, delta)
			if dist < aggro_range:
				_start_fight()
		State.RETURN:
			if from_home < 1.0:
				state = State.IDLE
				stats.refill()
			elif dist < aggro_range * 0.5:
				state = State.CHASE
			else:
				_move(home, run_speed * 0.7, delta)
		State.CHASE:
			if from_home > leash_range:
				state = State.RETURN
			elif dist <= fight_range + 0.4:
				state = State.ENGAGE
				_think_left = randf_range(0.2, 0.6)
			else:
				_move(player.global_position, run_speed, delta)
		State.ENGAGE:
			_engage(player, to_player, dist, delta)
		State.ATTACK:
			_face(player.global_position, delta * (0.35 if _phase != Phase.RECOVERY else 1.0))
			_move(Vector3.ZERO, 0.0, delta)
			_update_attack(player, delta)
		State.GUARD:
			_face(player.global_position, delta)
			_move(Vector3.ZERO, 0.0, delta)
			_guard_left -= delta
			if _guard_left <= 0.0:
				_pose("rest", 0.2)
				state = State.ENGAGE
				_think_left = randf_range(0.1, 0.4)
		State.STAGGER:
			_move(Vector3.ZERO, 0.0, delta)
			_stagger_left -= delta
			if _stagger_left <= 0.0:
				_pose("rest", 0.25)
				state = State.ENGAGE
		State.FLEE:
			_flee_left -= delta
			if _flee_left <= 0.0:
				state = State.CHASE   # the fear wears off
			else:
				var away := -to_player.normalized() if dist > 0.1 else global_transform.basis.z
				_move(global_position + away * 4.0, run_speed, delta)


# In range: circle a little, keep its distance, and pick the next move.
func _engage(player: Node3D, to_player: Vector3, dist: float, delta: float) -> void:
	if dist > fight_range + 1.5:
		state = State.CHASE
		return
	_face(player.global_position, delta)
	var side := to_player.normalized().cross(Vector3.UP) * _strafe
	var step := side * 0.4
	if dist > fight_range + 0.2:
		step += to_player.normalized()
	elif dist < fight_range - 0.5:
		step -= to_player.normalized()
	_move(global_position + step, run_speed * 0.45, delta, false)

	# You're winding up a swing: maybe raise the guard.
	var combat = player.get("combat")
	if combat and combat.state == combat.State.WINDUP and dist < reach + 1.0 and randf() < guard_chance * delta * 8.0:
		_start_guard(randf_range(0.5, 0.9))
		return
	_think_left -= delta
	if _think_left > 0.0:
		return
	_think_left = randf_range(0.5, 1.1)
	if randf() < 0.3:
		_strafe = -_strafe
	var roll := randf()
	if roll < 0.75 and _attackers() >= MAX_ATTACKERS:
		if randf() < 0.4:   # someone else is swinging: wait your turn, maybe behind a guard
			_start_guard(randf_range(0.4, 0.8))
	elif roll < 0.6 and not attacks.is_empty():
		_start_attack(false)
	elif roll < 0.75 and heavy_attack:
		_start_attack(true)
	elif roll < 0.9:
		_start_guard(randf_range(0.6, 1.2))


# Packmates swinging at the player right now.
func _attackers() -> int:
	var count := 0
	for other in get_parent().get_children():
		if other != self and other.get("state") == State.ATTACK:
			count += 1
	return count


func _start_fight() -> void:
	state = State.CHASE
	Hints.show_once("bandits", "Bandits raise their guard against quick swings. Hold %s for a heavy attack (or bash with a shield) to break it. Watch for the glint before they swing." % Hints.key("attack"))
	if get_parent().has_method("alert"):
		get_parent().alert(self)


## Called by its pack when a packmate starts fighting.
func join_hunt() -> void:
	if state == State.IDLE or state == State.RETURN:
		state = State.CHASE


# --- attacking ----------------------------------------------------------------------------

func _start_attack(heavy: bool) -> void:
	_is_heavy = heavy
	_combo_left = 1 if heavy else randi_range(1, attacks.size())
	_begin_swing(heavy_attack if heavy else attacks[0])


func _begin_swing(attack: AttackData) -> void:
	state = State.ATTACK
	_attack = attack
	_phase = Phase.WINDUP
	_phase_time = 0.0
	_hit_done = false
	_pose(attack.windup_pose, attack.windup * 0.8)


func _update_attack(player: Node3D, delta: float) -> void:
	_phase_time += delta
	match _phase:
		Phase.WINDUP:
			if _phase_time >= _attack.windup:
				_phase = Phase.ACTIVE
				_phase_time = 0.0
				_pose(_attack.strike_pose, _attack.active, Tween.EASE_IN)
				Sfx.play_at("swing_heavy" if _is_heavy else "swing_light", global_position, -2.0)
				if _attack.lunge > 0.0:
					_knockback = -global_transform.basis.z * _attack.lunge
		Phase.ACTIVE:
			if not _hit_done:
				_try_hit(player)
			if _phase_time >= _attack.active:
				_phase = Phase.RECOVERY
				_phase_time = 0.0
				_pose("rest", _attack.recovery)
		Phase.RECOVERY:
			if _phase_time >= _attack.recovery:
				_combo_left -= 1
				var index := attacks.size() - _combo_left
				if _combo_left > 0 and not _is_heavy and index < attacks.size():
					_begin_swing(attacks[index])
				else:
					state = State.ENGAGE
					_think_left = randf_range(0.3, 0.8)


func _try_hit(player: Node3D) -> void:
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var forward := -global_transform.basis.z
	forward.y = 0.0
	if to_player.length() > reach or rad_to_deg(forward.angle_to(to_player)) > 55.0:
		return
	_hit_done = true
	var damage := attack_damage * _attack.damage_mult
	var result := "hit"
	if player.has_method("receive_attack"):
		result = player.receive_attack(damage, self, _attack.poise_damage)
	elif player.has_method("take_hit"):   # another enemy (one of them is charmed)
		result = player.take_hit(damage, global_position, 3.0, _attack.poise_damage, _is_heavy)
	match result:
		"hit":
			Sfx.play_at("hit_heavy" if _is_heavy else "hit_flesh", player.global_position, -2.0)
		"parried":
			stagger(stagger_time * 1.3)
		"blocked", "guard_broken":
			_pose("rest", 0.3)   # bounced off the guard


# --- defending ------------------------------------------------------------------------------

func _start_guard(seconds: float) -> void:
	state = State.GUARD
	_guard_left = seconds
	_pose("guard", 0.12)


## Called by the player's weapons, arrows (knockback and poise from the attack)
## and spells (no knockback or poise: spells ignore the guard).
## Returns "hit", "blocked" or "parried", so the attacker can react.
func take_hit(damage: float, from_position: Vector3, knockback: float = 5.0, poise_damage: float = 0.0, heavy: bool = false) -> String:
	if state == State.DEAD:
		return "hit"
	if state == State.IDLE or state == State.RETURN:
		_start_fight()
	var is_spell := knockback <= 0.0 and poise_damage <= 0.0
	if state == State.GUARD and not is_spell and _facing(from_position):
		if heavy or stats.stamina < damage:
			_guard_broken(damage)
			return "hit"
		if randf() < parry_chance:
			Sfx.play_at("parry", global_position, -2.0)
			_pose("high_right", 0.08)
			_guard_left = 0.1   # then straight back into the fight
			return "parried"
		stats.use_stamina(damage)
		stats.take_damage(damage * (1.0 - guard_reduction))
		_guard_left = maxf(_guard_left, 0.3)
		model.position.z = 0.08
		create_tween().tween_property(model, "position:z", 0.0, 0.15)
		return "blocked"
	if knockback > 0.0:
		var push := global_position - from_position
		push.y = 0.0
		_knockback = push.normalized() * knockback * 0.6
	stats.take_damage(damage)
	if state != State.DEAD and not stats.take_poise_damage(poise_damage) and knockback > 0.0 and state != State.STAGGER:
		_flinch()
	return "hit"


func _guard_broken(damage: float) -> void:
	Sfx.play_at("guard_break", global_position)
	stats.use_stamina(stats.stamina)
	stats.take_damage(damage * 0.6)
	if state != State.DEAD:
		stagger(stagger_time)


func _facing(from_position: Vector3) -> bool:
	var to := from_position - global_position
	to.y = 0.0
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return to.length() < 0.01 or rad_to_deg(forward.angle_to(to)) < 70.0


## Reels for `seconds`: can't attack or guard. Cancels a swing in progress.
## Fear (Glamour): runs from you for `seconds`, then comes back.
func frighten(seconds: float) -> void:
	if state == State.DEAD:
		return
	state = State.FLEE
	_flee_left = seconds
	_pose("rest", 0.2)


func stagger(seconds: float) -> void:
	if state == State.DEAD:
		return
	state = State.STAGGER
	_stagger_left = seconds
	_pose("stagger", 0.12)
	var tween := create_tween()
	tween.tween_property(model, "rotation:x", deg_to_rad(-12), 0.12)
	tween.tween_property(model, "rotation:x", 0.0, seconds * 0.7)


func _flinch() -> void:
	var tween := create_tween()
	tween.tween_property(model, "rotation:x", deg_to_rad(-8), 0.05)
	tween.tween_property(model, "rotation:x", 0.0, 0.15)


## Spells and weapons can leave status effects (e.g. axes -> bleeding).
func add_effect(id: String) -> void:
	effects.apply(id)


func _on_damaged(_amount: float) -> void:
	var tween := create_tween()
	tween.tween_property(_cloth, "albedo_color", Color(0.8, 0.2, 0.15), 0.05)
	tween.tween_property(_cloth, "albedo_color", _cloth_color, 0.25)


# --- moving -----------------------------------------------------------------------------------

func _move(target: Vector3, speed: float, delta: float, turn: bool = true) -> void:
	var dir := target - global_position
	dir.y = 0.0
	if speed <= 0.0 or dir.length() < 0.1:
		velocity.x = move_toward(velocity.x, 0.0, 25.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 25.0 * delta)
		return
	var step := _next_path_point(target) - global_position
	step.y = 0.0
	if step.length() < 0.05:
		step = dir
	step = step.normalized() * speed * stats.modifier("move_speed")
	velocity.x = step.x
	velocity.z = step.z
	if turn:
		_face(global_position + step, delta)


func _next_path_point(target: Vector3) -> Vector3:
	if agent == null or NavigationServer3D.map_get_iteration_id(agent.get_navigation_map()) == 0:
		return target
	if agent.target_position.distance_to(target) > 0.5:
		agent.target_position = target
	if agent.is_navigation_finished():
		return target
	return agent.get_next_path_position()


func _face(target: Vector3, delta: float) -> void:
	var dir := target - global_position
	if Vector2(dir.x, dir.z).length() < 0.05:
		return
	rotation.y = lerp_angle(rotation.y, atan2(-dir.x, -dir.z), minf(8.0 * delta, 1.0))


# Arms: tween both shoulders to a named pose.
func _pose(pose: String, seconds: float, ease_type: Tween.EaseType = Tween.EASE_OUT) -> void:
	var data: Array = ARM_POSES.get(pose, ARM_POSES["rest"])
	if _pose_tween:
		_pose_tween.kill()
	_pose_tween = create_tween().set_parallel().set_ease(ease_type).set_trans(Tween.TRANS_QUAD)
	_pose_tween.tween_property(right_arm, "rotation_degrees", data[0], maxf(seconds, 0.01))
	_pose_tween.tween_property(left_arm, "rotation_degrees", data[1], maxf(seconds, 0.01))


func _find_blade_material(node: Node) -> StandardMaterial3D:
	# The first MeshInstance3D named Blade / Head / Ball gets its own glowing material.
	for part in node.get_children():
		if part is MeshInstance3D and part.name in ["Blade", "Head", "Ball"]:
			var mat: StandardMaterial3D = part.mesh.surface_get_material(0).duplicate()
			mat.emission_enabled = true
			mat.emission_energy_multiplier = 0.0
			part.material_override = mat
			return mat
	return null


# --- death and loot -----------------------------------------------------------------------------

## Dead bandits can be searched with E.
func interact(_player: Node) -> void:
	if state != State.DEAD or _searched:
		return
	_searched = true
	prompt = "%s (searched)" % display_name
	for id in loot:
		Inventory.add(id, int(loot[id]))
	if gold > 0:
		Inventory.add_gold(gold)


func _on_died() -> void:
	_become_corpse(true)
	died.emit()


func _become_corpse(animate: bool) -> void:
	state = State.DEAD
	collision_layer = 8   # layer 4 "loot": the E ray finds it, the player walks through
	collision_mask = 1    # still rests on the ground
	prompt = "%s (searched)" % display_name if _searched else "Search %s" % display_name.to_lower()
	velocity = Vector3.ZERO
	if _pose_tween:
		_pose_tween.kill()
	if animate:
		var tween := create_tween().set_parallel()
		tween.tween_property(model, "rotation:x", deg_to_rad(88), 0.5)
		tween.tween_property(model, "position:y", -0.75, 0.5)
	else:
		model.rotation.x = deg_to_rad(88)
		model.position.y = -0.75


# --- WorldState: dead bandits stay dead (and searched) ------------------------------------

func get_persist_state() -> Dictionary:
	return {"dead": state == State.DEAD, "searched": _searched,
			"position": [global_position.x, global_position.y, global_position.z]}


func apply_persist_state(saved: Dictionary) -> void:
	if not saved["dead"]:
		return
	var p: Array = saved["position"]
	global_position = Vector3(p[0], p[1], p[2])
	_searched = saved["searched"]
	_become_corpse(false)
