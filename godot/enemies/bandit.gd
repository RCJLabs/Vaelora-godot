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
# It hunts by sight and sound (systems/stealth.gd): it has to see you in front of it,
# hears footsteps, fights and spells, and goes to look (INVESTIGATE), then searches
# round about (SEARCH) before giving up. Out of sight while chasing, it goes to where
# it last saw you rather than where you are. A friend who starts a fight shouts, and a
# dead friend it sees sets it searching. docs/godot-starter/SNEAK.md.
#
# Dead bandits can be searched (E) for their gold and loot. WorldState keeps
# them dead and searched. Put them under a WolfPack-style node (enemy_pack.gd)
# so they fight together and the camp has a "cleared" flag.

signal died

enum State { IDLE, CHASE, ENGAGE, ATTACK, GUARD, STAGGER, RETURN, DEAD, FLEE, INVESTIGATE, SEARCH }

## How many members of a group may swing at the player at once. The rest
## circle and guard, so a fight against three stays readable (and fair).
const MAX_ATTACKERS := 1
enum Phase { WINDUP, ACTIVE, RECOVERY }

const LOSE_SIGHT := 2.5      # seconds out of sight while chasing before it goes to where it last saw you
const SEARCH_TIME := 8.0     # seconds it looks round where the noise was (or you were) before giving up
const SEARCH_RADIUS := 5.0   # how far from that spot it wanders, looking
const SHOUT := 15.0          # starting a fight, it shouts: anyone who can hear this far comes to look
const BODY_SIGHT := 14.0     # it notices a dead friend this far off (in view)
const INVESTIGATE_TIME := 12.0   # gives up getting to a spot it can't reach

@export var display_name: String = "Bandit"
@export var run_speed: float = 4.6       # slower than the player's sprint (8): you can flee
@export var aggro_range: float = 12.0
@export var leash_range: float = 28.0
## Needs to see you to notice you standing (in front of it, in the clear), and hears
## noise (systems/stealth.gd). Off: notices anyone in range, as wolves do.
@export var hunts_by_sight := true
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
@export_group("Look")
## A greybox person (systems/figure.gd) instead of the scene's placeholder body:
## a race (races/ file name), a role (Figure.ROLES) and the colour of their clothes.
@export var look_race := "human"
@export var look_role := "bandit"
@export var look_cloth := Color(0.33, 0.24, 0.16)
## Mix the race and shade the clothes per enemy (from its place in the scene, so the
## same each time), so a camp isn't one person five times. Off for named people.
@export var look_vary := true

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
var _lift_left := 0.0   # the Lifting Tide holds it up this much longer
var _lift_to := 0.0
var _searched := false
var _goal := Vector3.ZERO        # where it's going to look (INVESTIGATE), or searching round (SEARCH)
var _wander := Vector3.ZERO      # the spot it's looking at now, searching
var _search_left := 0.0
var _look_left := 0.0
var _last_seen := Vector3.INF    # where it last saw who it's after (INF: not yet; it's told where you are)
var _unseen := 0.0               # seconds it hasn't
var _body_check := 0.0
var _bodies_seen := {}           # instance ids of dead friends it has already found
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
	_dress()
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
	if _lift_left > 0.0:
		_lift_left -= delta
		velocity.y = clampf((_lift_to - global_position.y) * 4.0, -2.0, 6.0)   # held up by the tide
	elif not is_on_floor():
		velocity.y -= gravity * delta
	var player := get_tree().get_first_node_in_group("player")
	var paused: bool = player == null or player.is_dead or DialogueManager.is_active
	# Who it's after: the player or a companion, unless Glamour says otherwise.
	var foe: Node3D = null if paused else Targeting.foe_for(self, player)
	if paused:
		_move(Vector3.ZERO, 0.0, delta)
	elif foe == null:
		_lost(delta)
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
			if Stealth.notices(self, player, aggro_range, dist, delta):
				_start_fight()
			else:
				_look_for_bodies(delta)
		State.RETURN:
			if from_home < 1.0:
				state = State.IDLE
				stats.refill()
			elif Stealth.notices(self, player, aggro_range * 0.5, dist, delta):
				state = State.CHASE
			else:
				_move(home, run_speed * 0.7, delta)
		State.INVESTIGATE, State.SEARCH:
			if Stealth.notices(self, player, aggro_range, dist, delta):
				_start_fight()
			else:
				_search(delta)
		State.CHASE:
			if not _last_seen.is_finite():
				_last_seen = player.global_position   # a friend's shout, or a crime: it knows where you were
			if not hunts_by_sight or Stealth.clear_line(self, player):
				_last_seen = player.global_position
				_unseen = 0.0
			else:
				_unseen += delta
			if from_home > leash_range or Stealth.lost_track(self, delta):
				state = State.RETURN
			elif _unseen > LOSE_SIGHT:
				_investigate(_last_seen)   # lost you: go and look where you were
			elif dist <= fight_range + 0.4 and _unseen < 0.5:
				state = State.ENGAGE
				_think_left = randf_range(0.2, 0.6)
			else:
				_move(player.global_position if _unseen < 0.5 else _last_seen, run_speed, delta)
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


# Nobody to go after (you've turned invisible, say): back home.
func _lost(delta: float) -> void:
	match state:
		State.IDLE:
			_move(Vector3.ZERO, 0.0, delta)
		State.STAGGER, State.FLEE:
			_think(self, delta)   # these don't need a target to play out
		State.INVESTIGATE, State.SEARCH:
			_search(delta)        # nobody to see: keep looking
		_:
			if state == State.ATTACK or state == State.GUARD:
				_pose("rest", 0.2)
			if Vector2(global_position.x - home.x, global_position.z - home.z).length() < 1.0:
				state = State.IDLE
			else:
				state = State.RETURN
				_move(home, run_speed * 0.7, delta)


func _start_fight() -> void:
	state = State.CHASE
	_unseen = 0.0
	_last_seen = Vector3.INF
	Stealth.noise(global_position, SHOUT, self)   # a shout: anyone near comes to look
	Hints.show_once("bandits", "Bandits raise their guard against quick swings. Hold %s for a heavy attack (or bash with a shield) to break it. Watch for the glint before they swing." % Hints.key("attack"))
	if get_parent().has_method("alert"):
		get_parent().alert(self)


## Called by its pack when a packmate starts fighting.
func join_hunt() -> void:
	if state in [State.IDLE, State.RETURN, State.INVESTIGATE, State.SEARCH]:
		state = State.CHASE
		_unseen = 0.0
		_last_seen = Vector3.INF


# --- hearing and searching (systems/stealth.gd) ---------------------------------------

## A noise at `where` (Stealth.make_noise, noise, step): if it isn't already fighting,
## it goes to look.
func hear(where: Vector3) -> void:
	if not hunts_by_sight:
		return
	if state in [State.IDLE, State.RETURN, State.INVESTIGATE, State.SEARCH]:
		_investigate(where)


func _investigate(where: Vector3) -> void:
	if state == State.ATTACK or state == State.GUARD:
		_pose("rest", 0.2)
	state = State.INVESTIGATE
	_goal = where
	_search_left = INVESTIGATE_TIME   # to get there


## Going to look, then looking round, then home.
func _search(delta: float) -> void:
	_search_left -= delta
	if state == State.INVESTIGATE:
		var to_goal := Vector2(_goal.x - global_position.x, _goal.z - global_position.z).length()
		if to_goal < 1.5 or _search_left <= 0.0:
			state = State.SEARCH
			_search_left = SEARCH_TIME
			_wander = _goal
			_look_left = 0.0
		else:
			_move(_goal, run_speed * 0.6, delta)
		return
	if _search_left <= 0.0:
		state = State.RETURN   # nothing there
		return
	_look_left -= delta
	if _look_left <= 0.0:
		_look_left = randf_range(1.2, 2.2)
		var angle := randf() * TAU
		_wander = _goal + Vector3(cos(angle), 0, sin(angle)) * randf_range(1.0, SEARCH_RADIUS)
	if Vector2(_wander.x - global_position.x, _wander.z - global_position.z).length() > 0.8:
		_move(_wander, run_speed * 0.4, delta)
	else:
		_move(Vector3.ZERO, 0.0, delta)
		rotation.y += delta * 1.5   # looking round


## Every half second while idle: a dead friend in view sets it searching where they lie.
func _look_for_bodies(delta: float) -> void:
	if not hunts_by_sight:
		return
	_body_check -= delta
	if _body_check > 0.0:
		return
	_body_check = 0.5
	for other in get_parent().get_children():
		if other == self or other.get("state") != State.DEAD or _bodies_seen.has(other.get_instance_id()):
			continue
		if global_position.distance_to(other.global_position) < BODY_SIGHT and Stealth.in_view(self, other):
			_bodies_seen[other.get_instance_id()] = true
			_investigate(other.global_position)
			return


## Searching: it's heard something or lost you, and is looking (it notices you sooner).
func is_alert() -> bool:
	return state == State.INVESTIGATE or state == State.SEARCH


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
	if state in [State.IDLE, State.RETURN, State.INVESTIGATE, State.SEARCH]:
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


## Tidecraft moves it (systems/tidecraft.gd): `push` (metres a second, flat)
## replaces whatever knockback it has this frame.
func shove(push: Vector3) -> void:
	if state != State.DEAD:
		push.y = 0.0
		_knockback = push

## The Lifting Tide (systems/tidecraft.gd): rise `height` metres and hang there,
## helpless, for `seconds`; then gravity has it again.
func lift(height: float, seconds: float) -> void:
	if state == State.DEAD:
		return
	_lift_to = global_position.y + height
	_lift_left = seconds
	stagger(seconds + 0.6)


## Reeling from a broken guard or a heavy blow (Knockout, Unarmed).
func is_staggered() -> bool:
	return state == State.STAGGER


## Hasn't noticed you: a sneak attack lands (systems/stealth.gd). Searching counts:
## it's looking for you, but hasn't found you.
func is_unaware() -> bool:
	return state == State.IDLE or state == State.INVESTIGATE or state == State.SEARCH


## After you (or a companion), for the HUD's eye.
func is_hunting() -> bool:
	return state in [State.CHASE, State.ENGAGE, State.ATTACK, State.GUARD, State.STAGGER]


func is_lifted() -> bool:
	return _lift_left > 0.0


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


## Who turns up in this kind of crowd (look_vary picks one). Bandits: mostly human,
## some orcs and elves.
func vary_races() -> Array:
	return ["human", "human", "human", "orc", "elf"]


## Clothes look_vary picks from (empty: keep look_cloth, only shaded). Bandits wear
## what they've got: leather, moss, grey wool, rust.
func vary_cloths() -> Array:
	return [Color(0.33, 0.24, 0.16), Color(0.24, 0.3, 0.18), Color(0.34, 0.33, 0.31), Color(0.42, 0.22, 0.14)]


## Swap the scene's placeholder body for a figure of look_race / look_role, with its
## arms hung on the scene's own shoulder pivots (which the poses swing) and the
## weapon in the hand. The clothes get their own material: hit flashes tint it.
func _dress() -> void:
	if look_vary:
		var where := str(get_path())
		look_race = vary_races()[absi(hash(where + "/race")) % vary_races().size()]
		var cloths := vary_cloths()
		if not cloths.is_empty():
			look_cloth = cloths[absi(hash(where + "/cloth")) % cloths.size()]
		var shade := float(absi(hash(where + "/shade")) % 100) / 100.0   # 0..1
		look_cloth = look_cloth.darkened(0.3 * shade) if shade < 0.5 else look_cloth.lightened(0.25 * (shade - 0.5))
	for part in ["Body", "LegL", "LegR", "Head", "Hood", "Mask", "RightArm/Arm", "LeftArm/Arm"]:
		var old := model.get_node_or_null(part)
		if old:
			old.get_parent().remove_child(old)
			old.free()
	var figure := Figure.build(look_race, look_role, look_cloth, false, 1, false, true)
	model.add_child(figure)
	_cloth = figure.get_meta("cloth_material")
	for arm in [[right_arm, 1.0], [left_arm, -1.0]]:
		arm[0].position = Figure.shoulder(look_race, arm[1])
		Figure.arm(arm[0], look_race, _cloth)
	weapon_holder.position.y = -Figure.hand_drop(look_race)


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
