class_name PlayerCombat
extends Node

# The player's melee: light combos, charged heavy attacks, blocking, timed
# parries, dodging and being staggered. A child of the Player called "Combat".
#
#   Left click (tap)        light attack; tap again during a swing to combo
#   Left click (hold)       charge a heavy attack, release to strike
#   Right click (hold)      block, when the left hand isn't holding a spell
#                           (Q cycles Block / spells). Block just before a hit to parry.
#   Alt                     dodge in the direction you're moving (backwards if none)
#
# Every swing is an AttackData (windup -> active -> recovery). Enemies call
# receive_attack() when their attack lands, and it decides hit / blocked /
# parried / dodged. Numbers are drafts: the constants below and each weapon's
# .tres are the places to tune the feel.

signal attack_landed(target: Node, damage: float)
signal defended(result: String)   # "blocked", "parried", "dodged", "guard_broken"

enum State { READY, WINDUP, ACTIVE, RECOVERY, CHARGING, BLOCKING, DODGING, STAGGERED }

## Holding attack longer than this starts a heavy attack instead of a light one.
const TAP_TIME := 0.2
## After a swing ends, a click this soon still continues the combo.
const COMBO_GRACE := 0.4
## A queued combo swing starts once this share of the recovery has passed.
const COMBO_CANCEL := 0.5
## Blocking this soon before a hit lands is a parry.
const PARRY_WINDOW := 0.2
## Stamina spent per point of damage a block stops.
const BLOCK_STAMINA_PER_DAMAGE := 1.5
## Blocks only work against attacks within this angle of where you're looking.
const BLOCK_ANGLE := 75.0
const BLOCK_MOVE_MULT := 0.5
const DODGE_SPEED := 9.0
const DODGE_TIME := 0.3
const DODGE_IFRAMES := 0.22   # seconds of the dodge where nothing can hit you
const DODGE_STAMINA := 18.0
const DODGE_COOLDOWN := 0.2
const STAGGER_TIME := 0.6
const GUARD_BREAK_TIME := 1.0
const RIPOSTE_TIME := 2.0
## Engine slow-down when a swing connects ("hit stop"), in real seconds.
const HIT_STOP_LIGHT := 0.045
const HIT_STOP_HEAVY := 0.09
const HIT_STOP_PARRY := 0.12

var state := State.READY
var player: CharacterBody3D
var animator: WeaponAnimator
var attack_cast: ShapeCast3D

# From the equipped weapon (set_weapon).
var base_damage := 4.0
var base_stamina_cost := 5.0
var weapon_skill := "one_handed"
var light_attacks: Array[AttackData] = []
var heavy_attack: AttackData
var block_reduction := 0.3

var current_attack: AttackData
var combo_index := 0              # which light attack comes next
var is_heavy := false
var charge := 0.0                 # 0..1 for the heavy attack being charged / swung

var _state_time := 0.0
var _press_held := false          # attack is held, not yet a tap or a charge
var _press_time := 0.0
var _queued := false              # clicked during a swing: do the next combo swing
var _combo_grace_left := 0.0
var _hit_this_swing: Array = []
var _dodge_velocity := Vector3.ZERO
var _dodge_cooldown_left := 0.0
var _iframes_left := 0.0
var _stagger_left := 0.0
var _riposte_left := 0.0
var _hit_stops := 0


func _ready() -> void:
	player = get_parent()
	animator = player.get_node("Head/Camera3D/Weapon")
	attack_cast = player.get_node("Head/Camera3D/AttackCast")
	# The player's @onready vars aren't set yet (children are ready first).
	player.get_node("Stats").poise_broken.connect(func(): stagger(STAGGER_TIME))


## Takes the moveset from a weapon item, or fists when `item` is null.
func set_weapon(item: ItemData) -> void:
	if item:
		base_damage = item.damage
		base_stamina_cost = item.stamina_cost
		weapon_skill = item.weapon_skill
		block_reduction = item.block_reduction
		light_attacks = item.light_attacks.duplicate()
		heavy_attack = item.heavy_attack
		if light_attacks.is_empty():
			light_attacks = [_simple_attack(item.attack_cooldown)]
		attack_cast.target_position = Vector3(0, 0, -item.reach)
	else:
		base_damage = player.unarmed_damage
		base_stamina_cost = player.unarmed_stamina_cost
		weapon_skill = "one_handed"   # until there's a Hand-to-Hand skill
		block_reduction = 0.3
		light_attacks = [_fist_jab()]
		heavy_attack = _fist_heavy()
		attack_cast.target_position = Vector3(0, 0, -player.unarmed_reach)
	combo_index = 0
	if state != State.READY:
		_to_ready()


# --- input (called by the player) ---------------------------------------------------

func attack_pressed() -> void:
	match state:
		State.READY:
			_press_held = true
			_press_time = 0.0
		State.WINDUP, State.ACTIVE, State.RECOVERY:
			_queued = not is_heavy   # heavy attacks don't combo


func attack_released() -> void:
	if state == State.CHARGING:
		_start_attack(heavy_attack, true)
	elif _press_held and state == State.READY:
		_start_light()
	_press_held = false


func dodge_pressed(input_dir: Vector2) -> void:
	if state in [State.WINDUP, State.ACTIVE, State.DODGING, State.STAGGERED] or _dodge_cooldown_left > 0.0:
		return
	if not player.is_on_floor() or not player.stats.try_use_stamina(DODGE_STAMINA * player.stats.modifier("dodge_stamina")):
		return
	var local := Vector3(input_dir.x, 0.0, input_dir.y) if input_dir != Vector2.ZERO else Vector3.BACK
	_dodge_velocity = (player.transform.basis * local).normalized() * DODGE_SPEED
	_set_state(State.DODGING)
	_iframes_left = DODGE_IFRAMES
	_press_held = false
	animator.go("dodge", 0.08, 0.5)
	Sfx.play("dodge", -4.0)
	player.camera_kick(Vector3(0.0, 0.0, -signf(input_dir.x) * 4.0))


# --- every physics frame ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_state_time += delta
	_dodge_cooldown_left -= delta
	_iframes_left -= delta
	_riposte_left -= delta
	if _combo_grace_left > 0.0:
		_combo_grace_left -= delta
		if _combo_grace_left <= 0.0:
			combo_index = 0

	if not player.can_fight():
		if state != State.READY and state != State.STAGGERED:
			_to_ready()
		_press_held = false
		return

	if _press_held:
		_press_time += delta
		if _press_time >= TAP_TIME and state == State.READY and heavy_attack:
			_press_held = false
			_start_charging()

	match state:
		State.READY, State.BLOCKING:
			_update_block()
		State.CHARGING:
			charge = minf(_state_time / maxf(heavy_attack.charge_time, 0.01), 1.0)
			animator.set_charge(charge)
			player.hud.set_charge(charge)
		State.WINDUP:
			if _state_time >= current_attack.windup:
				_begin_active()
		State.ACTIVE:
			_sweep()
			if _state_time >= current_attack.active:
				_begin_recovery()
		State.RECOVERY:
			if _queued and not is_heavy and _state_time >= current_attack.recovery * COMBO_CANCEL:
				_queued = false
				_start_light()
			elif Input.is_action_pressed("cast") and Spellbook.current() == null:
				_update_block()   # blocking cancels the rest of a recovery
			elif _state_time >= current_attack.recovery:
				_to_ready()
				_combo_grace_left = COMBO_GRACE
		State.DODGING:
			if _state_time >= DODGE_TIME:
				_dodge_cooldown_left = DODGE_COOLDOWN
				_to_ready()
		State.STAGGERED:
			_stagger_left -= delta
			if _stagger_left <= 0.0:
				_to_ready()


# --- attacking ----------------------------------------------------------------------

func _start_light() -> void:
	if light_attacks.is_empty():
		return
	if combo_index >= light_attacks.size():
		combo_index = 0
	var attack := light_attacks[combo_index]
	if _start_attack(attack, false):
		combo_index = (combo_index + 1) % light_attacks.size()
		_combo_grace_left = 0.0


func _start_charging() -> void:
	if player.stats.stamina < _stamina_cost(heavy_attack):
		player.hud.flash_tired()
		return
	_set_state(State.CHARGING)
	is_heavy = true
	charge = 0.0
	combo_index = 0
	animator.go(heavy_attack.windup_pose, maxf(heavy_attack.charge_time * 0.5, 0.15), 0.5)


## Returns false if there isn't enough stamina.
func _start_attack(attack: AttackData, heavy: bool) -> bool:
	if not player.stats.try_use_stamina(_stamina_cost(attack)):
		player.hud.flash_tired()
		_to_ready()
		return false
	current_attack = attack
	is_heavy = heavy
	if not heavy:
		charge = 0.0
	_queued = false
	_set_state(State.WINDUP)
	animator.set_charge(0.0)
	player.hud.set_charge(0.0)
	# A charged heavy is already wound up, so it only needs a short final windup.
	animator.go(attack.windup_pose, attack.windup, 0.5)
	return true


func _begin_active() -> void:
	_set_state(State.ACTIVE)
	_hit_this_swing = []
	animator.go(current_attack.strike_pose, current_attack.active, 2.2, Vector3(0.0, 0.05, -0.18))
	var side := -1.0 if current_attack.windup_pose.ends_with("right") else 1.0
	player.camera_kick(Vector3(-1.2 if is_heavy else -0.6, side * 0.8, side * 1.5))
	Sfx.play("swing_heavy" if is_heavy else "swing_light", -6.0)
	if current_attack.lunge > 0.0:
		player.lunge(current_attack.lunge, current_attack.active)


func _begin_recovery() -> void:
	_set_state(State.RECOVERY)
	animator.go("rest", current_attack.recovery, -1.6)


# Every frame of the active window: anything newly in reach gets hit once.
func _sweep() -> void:
	if not current_attack.cleave and not _hit_this_swing.is_empty():
		return
	attack_cast.force_shapecast_update()
	for i in attack_cast.get_collision_count():
		var target := attack_cast.get_collider(i)
		if target == null or target in _hit_this_swing or not target.has_method("take_hit"):
			continue
		_hit_this_swing.append(target)
		_land_hit(target)
		if not current_attack.cleave:
			return


func _land_hit(target: Node) -> void:
	var stats: Stats = player.stats
	var damage := base_damage * current_attack.damage_mult * _charge_mult() \
			* GameState.race_data.melee_damage_mult * Attributes.melee_mult() \
			* Skills.weapon_damage_mult(weapon_skill) * stats.modifier("damage_dealt") \
			* stats.modifier("weapon_damage_" + weapon_skill)
	if _riposte_left > 0.0:
		damage *= stats.modifier("riposte_damage")
	var poise := current_attack.poise_damage * _charge_mult()
	target.take_hit(damage, player.global_position, current_attack.knockback, poise)
	Skills.add_xp(weapon_skill, 5.0 if is_heavy else 3.0)
	player.hud.flash_hit()
	var target_stats = target.get("stats")
	if target_stats is Stats:
		player.hud.show_enemy_health(target_stats)
	animator.kick(Vector3(0.0, 0.0, 0.04))
	Sfx.play("hit_heavy" if is_heavy else "hit_flesh")
	hit_stop(HIT_STOP_HEAVY if is_heavy else HIT_STOP_LIGHT)
	attack_landed.emit(target, damage)


# A partly charged heavy does 60% of its damage, a full one 100%.
func _charge_mult() -> float:
	return lerpf(0.6, 1.0, charge) if is_heavy else 1.0


func _stamina_cost(attack: AttackData) -> float:
	return base_stamina_cost * attack.stamina_mult * player.stats.modifier("attack_stamina")


# --- defending ------------------------------------------------------------------------

func _update_block() -> void:
	var wants := Input.is_action_pressed("cast") and Spellbook.current() == null
	if wants and state != State.BLOCKING:
		_set_state(State.BLOCKING)
		animator.go("block", 0.1, 0.5)
	elif not wants and state == State.BLOCKING:
		_to_ready()


func is_blocking() -> bool:
	return state == State.BLOCKING


## Enemies call this when their attack lands. Returns "hit", "blocked",
## "parried", "dodged" or "guard_broken"; the attacker reacts to the result.
func receive_attack(damage: float, attacker: Node3D, poise_damage: float = 0.0) -> String:
	var stats: Stats = player.stats
	if stats.is_dead:
		return "hit"
	if _iframes_left > 0.0:
		defended.emit("dodged")
		return "dodged"
	if state == State.BLOCKING and _facing(attacker):
		if _state_time <= PARRY_WINDOW * stats.modifier("parry_window"):
			_parried()
			return "parried"
		var share := Skills.block_share(block_reduction)
		var stopped := damage * share
		var cost := stopped * BLOCK_STAMINA_PER_DAMAGE * stats.modifier("block_stamina")
		Skills.add_xp("block", stopped / 4.0)
		if stats.stamina < cost:
			stats.use_stamina(stats.stamina)
			stats.take_damage(damage - stopped)
			stagger(GUARD_BREAK_TIME)
			Sfx.play("guard_break")
			defended.emit("guard_broken")
			return "guard_broken"
		stats.use_stamina(cost)
		stats.take_damage(damage - stopped)
		animator.kick(Vector3(0.0, -0.03, 0.06))
		player.hud.flash_block(false)
		Sfx.play("block", -3.0)
		player.camera_kick(Vector3(-1.0, 0.0, 0.0))
		defended.emit("blocked")
		return "blocked"
	stats.take_damage(damage)
	player.camera_kick(Vector3(-2.0, randf_range(-1.5, 1.5), randf_range(-3.0, 3.0)))
	stats.take_poise_damage(poise_damage)
	return "hit"


func _parried() -> void:
	Skills.add_xp("block", 6.0)
	player.stats.stamina = minf(player.stats.stamina + 10.0, player.stats.max_stamina)
	player.stats.changed.emit()
	_riposte_left = RIPOSTE_TIME
	animator.go("parry", 0.06, 0.4)
	player.hud.flash_block(true)
	Sfx.play("parry")
	hit_stop(HIT_STOP_PARRY)
	defended.emit("parried")


# Is the attacker roughly in front of the camera?
func _facing(attacker: Node3D) -> bool:
	if attacker == null:
		return true
	var to_attacker := attacker.global_position - player.global_position
	to_attacker.y = 0.0
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	if to_attacker.length() < 0.01:
		return true
	return rad_to_deg(forward.angle_to(to_attacker)) <= BLOCK_ANGLE


func stagger(seconds: float) -> void:
	if player.stats.is_dead:
		return
	_set_state(State.STAGGERED)
	_stagger_left = seconds
	_press_held = false
	_queued = false
	charge = 0.0
	animator.set_charge(0.0)
	player.hud.set_charge(0.0)
	animator.go("stagger", 0.1, 0.5)


# --- for the player's movement ------------------------------------------------------

## Speed multiplier while attacking, blocking or staggered.
func move_mult() -> float:
	match state:
		State.BLOCKING: return BLOCK_MOVE_MULT
		State.CHARGING: return 0.6
		State.WINDUP, State.ACTIVE: return 0.75
		State.STAGGERED: return 0.25
	return 1.0


func allows_sprint() -> bool:
	return state == State.READY or state == State.RECOVERY


## True while the dodge moves the player instead of the movement keys.
func dodge_velocity() -> Vector3:
	return _dodge_velocity if state == State.DODGING else Vector3.ZERO


## Spells and interaction wait until a swing or block is over.
func is_busy() -> bool:
	return state != State.READY


func can_attack() -> bool:
	return state in [State.READY, State.WINDUP, State.ACTIVE, State.RECOVERY]


# --- helpers ---------------------------------------------------------------------------

## Freezes the action for a moment (real time) so hits feel solid.
func hit_stop(seconds: float) -> void:
	_hit_stops += 1
	Engine.time_scale = 0.05
	await get_tree().create_timer(seconds, true, false, true).timeout
	_hit_stops -= 1
	if _hit_stops == 0:
		Engine.time_scale = 1.0


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _to_ready() -> void:
	var was_blocking := state == State.BLOCKING
	_set_state(State.READY)
	is_heavy = false
	charge = 0.0
	_queued = false
	animator.set_charge(0.0)
	player.hud.set_charge(0.0)
	if animator.pose_name() != "rest":
		animator.go("rest", 0.15 if was_blocking else 0.25)


# Weapons without a light combo in their .tres: one swing sized to the old cooldown.
func _simple_attack(cooldown: float) -> AttackData:
	var attack := AttackData.new()
	attack.windup = cooldown * 0.25
	attack.active = 0.1
	attack.recovery = maxf(cooldown * 0.75 - 0.1, 0.1)
	return attack


func _fist_jab() -> AttackData:
	var attack := AttackData.new()
	attack.windup_pose = "thrust_back"
	attack.strike_pose = "thrust_forward"
	attack.windup = 0.08
	attack.active = 0.1
	attack.recovery = 0.25
	attack.poise_damage = 4.0
	attack.knockback = 2.0
	return attack


func _fist_heavy() -> AttackData:
	var attack := _fist_jab()
	attack.charge_time = 0.5
	attack.windup = 0.06
	attack.recovery = 0.45
	attack.damage_mult = 2.0
	attack.stamina_mult = 2.0
	attack.poise_damage = 12.0
	attack.knockback = 5.0
	return attack
