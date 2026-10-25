class_name PlayerCombat
extends Node

# The player's fighting: light combos, charged heavy attacks, blocking, timed
# parries, shield bashes, bows, dodging and being staggered. A child of the
# Player called "Combat".
#
#   Left click (tap)        light attack; tap again during a swing to combo
#   Left click (hold)       charge a heavy attack, release to strike
#                           (bow: hold to draw, release to loose an arrow)
#   Right click (hold)      what the left hand does (left_hand()):
#                             free hand     block, or cast the ready spell (Q cycles)
#                             shield        block (left click while blocking = bash)
#                             two-handed    block with the weapon
#                             bow           aim (zoom)
#                           Block just before a hit to parry.
#   Alt                     dodge in the direction you're moving (backwards if none)
#
# Every swing is an AttackData (windup -> active -> recovery). Enemies call
# receive_attack() when their attack lands, and it decides hit / blocked /
# parried / dodged. Targets can answer a hit with "blocked" or "parried"
# (humanoid enemies do), which bounces the swing. Numbers are drafts: the
# constants below and each weapon's .tres are the places to tune the feel.

signal attack_landed(target: Node, damage: float)
signal defended(result: String)   # "blocked", "parried", "dodged", "guard_broken", "warded"

enum State { READY, WINDUP, ACTIVE, RECOVERY, CHARGING, BLOCKING, DODGING, STAGGERED, DRAWING }
enum Hand { BLOCK, SPELL, SHIELD, TWO_HANDED, BOW }

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
## When an enemy blocks your swing, you're stuck this long; when it parries, you stagger.
const RECOIL_TIME := 0.35
const PARRIED_TIME := 1.0
## Bows: arrows fired below this much draw are cancelled; weakest arrow at that draw.
const MIN_DRAW := 0.15
const BOW_RECOVERY := 0.3
## Engine slow-down when a swing connects ("hit stop"), in real seconds.
const HIT_STOP_LIGHT := 0.045
const HIT_STOP_HEAVY := 0.09
const HIT_STOP_PARRY := 0.12
## The space a swing reaches: width (wider when cleaving), height, and how far
## below the view line its centre sits (metres). Reach comes from the weapon.
const SWING_WIDTH := 0.9
const SWING_WIDTH_CLEAVE := 1.8
const SWING_HEIGHT := 1.4
const SWING_DROP := 0.25
const ARROW_SCENE := preload("res://combat/arrow.tscn")

var state := State.READY
var player: CharacterBody3D
var animator: WeaponAnimator        # right hand: the weapon
var off_animator: WeaponAnimator    # left hand: the shield, when there is one
var attack_cast: ShapeCast3D

# From the equipped weapon (set_weapon) and shield (set_shield).
var main_item: ItemData
var shield_item: ItemData
var base_damage := 4.0
var base_stamina_cost := 5.0
var weapon_skill := "one_handed"
var light_attacks: Array[AttackData] = []
var heavy_attack: AttackData
var block_reduction := 0.3

var current_attack: AttackData
var combo_index := 0              # which light attack comes next
var is_heavy := false
var is_bash := false
var charge := 0.0                 # 0..1 for the heavy attack being charged / bow being drawn

var _state_time := 0.0
var _press_held := false          # attack is held, not yet a tap or a charge
var _press_time := 0.0
var _queued := false              # clicked during a swing: do the next combo swing
var _combo_grace_left := 0.0
var _hit_this_swing: Array = []
var _dodge_velocity := Vector3.ZERO
var _dodge_cooldown_left := 0.0
var _iframes_left := 0.0
var _block_toggled := false   # Settings.toggle_block: guard latched up
var _stagger_left := 0.0
var _riposte_left := 0.0
var _counter_left := 0.0   # Counter-Strike (Light Armour): after a dodge, the next hit is harder
var _combo_target: Node = null   # Combination (Unarmed): who the run of punches is on
var _combo_hits := 0
var _combo_left := 0.0
var _hit_stops := 0


func _ready() -> void:
	player = get_parent()
	animator = player.get_node("Head/Camera3D/Weapon")
	off_animator = player.get_node("Head/Camera3D/OffHand")
	attack_cast = player.get_node("Head/Camera3D/AttackCast")
	# The player's @onready vars aren't set yet (children are ready first).
	player.get_node("Stats").poise_broken.connect(func(): stagger(STAGGER_TIME))


## Takes the moveset from a weapon item, or fists when `item` is null.
func set_weapon(item: ItemData) -> void:
	main_item = item
	if item:
		base_damage = item.damage * Smithing.damage_mult(item)   # improved at a forge
		base_stamina_cost = item.stamina_cost * Smithing.stamina_mult(item)
		weapon_skill = item.weapon_skill
		block_reduction = item.block_reduction
		light_attacks = item.light_attacks.duplicate()
		heavy_attack = item.heavy_attack
		if light_attacks.is_empty() and item.weapon_kind == ItemData.WeaponKind.MELEE:
			light_attacks = [_simple_attack(item.attack_cooldown)]
		attack_cast.target_position = Vector3(0, 0, -item.reach)
	else:
		base_damage = player.unarmed_damage
		base_stamina_cost = player.unarmed_stamina_cost
		weapon_skill = "unarmed"
		block_reduction = 0.3
		light_attacks = [_fist_jab()]
		heavy_attack = _fist_heavy()
		attack_cast.target_position = Vector3(0, 0, -player.unarmed_reach)
	combo_index = 0
	_to_ready()
	animator.go(_rest_pose(), 0.2)


## The off-hand shield, or null.
func set_shield(item: ItemData) -> void:
	shield_item = item
	off_animator.visible = item != null
	if state != State.READY:
		_to_ready()


## What the left hand does with right-click right now.
func left_hand() -> Hand:
	if main_item and main_item.weapon_kind == ItemData.WeaponKind.BOW:
		return Hand.BOW
	if main_item and main_item.two_handed:
		return Hand.TWO_HANDED
	if shield_item:
		return Hand.SHIELD
	return Hand.SPELL if Spellbook.current() else Hand.BLOCK


## Spells need a free left hand, and no swing or block in progress.
func can_cast() -> bool:
	return left_hand() == Hand.SPELL and state == State.READY


func is_bow() -> bool:
	return left_hand() == Hand.BOW


# --- input (called by the player) ---------------------------------------------------

func attack_pressed() -> void:
	if player.magic.right_hand_free():
		return   # an empty right hand casts the ready spell instead (PlayerMagic)
	match state:
		State.READY:
			if is_bow():
				_start_drawing()
			else:
				_press_held = true
				_press_time = 0.0
		State.BLOCKING:
			if left_hand() == Hand.SHIELD and shield_item.bash_attack:
				_start_bash()
		State.WINDUP, State.ACTIVE, State.RECOVERY:
			_queued = not is_heavy and not is_bash and not is_bow()   # heavies and bashes don't combo


func attack_released() -> void:
	if state == State.CHARGING:
		_start_attack(heavy_attack, true)
	elif state == State.DRAWING:
		_loose_arrow()
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
	_iframes_left = DODGE_IFRAMES * player.stats.modifier("dodge_iframes")
	_press_held = false
	animator.go("dodge" if not is_bow() else "bow_rest", 0.08, 0.5)
	if shield_item:
		off_animator.go("dodge", 0.08, 0.5)
	Sfx.play("dodge", -4.0)
	player.camera_kick(Vector3(0.0, 0.0, -signf(input_dir.x) * 4.0))


# --- every physics frame ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if Settings.toggle_block and Input.is_action_just_pressed("cast") and player.can_fight():
		_block_toggled = not _block_toggled   # Settings → Accessibility → Toggle block
	_state_time += delta
	_dodge_cooldown_left -= delta
	_iframes_left -= delta
	_riposte_left -= delta
	_counter_left -= delta
	_combo_left -= delta
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
		State.DRAWING:
			var draw_time := maxf(main_item.draw_time * player.stats.modifier("draw_time"), 0.05)
			charge = minf(_state_time / draw_time, 1.0)
			animator.set_charge(charge * 0.5)
			player.hud.set_charge(charge)
		State.WINDUP:
			if _state_time >= current_attack.windup:
				_begin_active()
		State.ACTIVE:
			_sweep()
			if state == State.ACTIVE and _state_time >= current_attack.active:
				_begin_recovery()
		State.RECOVERY:
			if _queued and _state_time >= current_attack.recovery * COMBO_CANCEL:
				_queued = false
				_start_light()
			elif _wants_block() and not is_bow():
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
	if player.stats.stamina < _stamina_cost(heavy_attack, true):
		player.hud.flash_tired()
		return
	_set_state(State.CHARGING)
	is_heavy = true
	charge = 0.0
	combo_index = 0
	animator.go(heavy_attack.windup_pose, maxf(heavy_attack.charge_time * 0.5, 0.15), 0.5)


func _start_bash() -> void:
	var bash: AttackData = shield_item.bash_attack
	if not player.stats.try_use_stamina(shield_item.stamina_cost * bash.stamina_mult * player.stats.modifier("attack_stamina")):
		player.hud.flash_tired()
		return
	current_attack = bash
	is_heavy = false
	is_bash = true
	charge = 0.0
	_queued = false
	_set_state(State.WINDUP)
	off_animator.go(bash.windup_pose, bash.windup, 0.5)


## Returns false if there isn't enough stamina.
func _start_attack(attack: AttackData, heavy: bool) -> bool:
	if not player.stats.try_use_stamina(_stamina_cost(attack, heavy)):
		player.hud.flash_tired()
		_to_ready()
		return false
	current_attack = attack
	is_heavy = heavy
	is_bash = false
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
	Stealth.make_noise(player.global_position, "melee")
	if is_bash:
		off_animator.go(current_attack.strike_pose, current_attack.active, 2.0)
		player.camera_kick(Vector3(-0.8, 0.0, 0.0))
		Sfx.play("swing_light", -8.0)
	else:
		animator.go(current_attack.strike_pose, current_attack.active, 2.2, Vector3(0.0, 0.05, -0.18))
		var side := -1.0 if current_attack.windup_pose.ends_with("right") else 1.0
		player.camera_kick(Vector3(-1.2 if is_heavy else -0.6, side * 0.8, side * 1.5))
		Sfx.play("swing_heavy" if is_heavy or (main_item and main_item.two_handed) else "swing_light", -6.0)
	if current_attack.lunge > 0.0:
		player.lunge(current_attack.lunge, current_attack.active)


func _begin_recovery() -> void:
	_set_state(State.RECOVERY)
	if is_bash:
		off_animator.go("block" if _wants_block() else "rest", current_attack.recovery, -1.6)
	else:
		animator.go(_rest_pose(), current_attack.recovery, -1.6)


# Every frame of the active window: anything newly in reach gets hit once.
func _sweep() -> void:
	if not current_attack.cleave and not _hit_this_swing.is_empty():
		return
	for target in _targets_in_reach():
		if target in _hit_this_swing or not target.has_method("take_hit") or Binding.is_bound(target):
			continue   # (your own called things: the swing passes through them)
		_hit_this_swing.append(target)
		_land_hit(target)
		if state != State.ACTIVE or not current_attack.cleave:
			return   # bounced off a block, or one target per swing


## Enemies inside the swing's reach (a box in front of the camera, reaching a
## little lower than the view so low enemies like wolves are easy to hit),
## nearest to the crosshair first. Cleaving swings use a wider box.
func _targets_in_reach() -> Array:
	var camera: Camera3D = player.camera
	var reach := -attack_cast.target_position.z
	var box := BoxShape3D.new()
	box.size = Vector3(SWING_WIDTH_CLEAVE if current_attack.cleave else SWING_WIDTH, SWING_HEIGHT, reach)
	var basis := camera.global_transform.basis
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = box
	query.collision_mask = attack_cast.collision_mask
	query.transform = Transform3D(basis, camera.global_position - basis.z * reach * 0.5 - basis.y * SWING_DROP)
	var found := []
	for hit in player.get_world_3d().direct_space_state.intersect_shape(query, 16):
		if not hit["collider"] in found:
			found.append(hit["collider"])
	# Closest to the line through the crosshair wins.
	var eye := camera.global_position
	var forward := -basis.z
	found.sort_custom(func(a, b):
		var da: Vector3 = a.global_position - eye
		var db: Vector3 = b.global_position - eye
		return (da - forward * da.dot(forward)).length() < (db - forward * db.dot(forward)).length())
	return found


func _land_hit(target: Node) -> void:
	var stats: Stats = player.stats
	var skill := "block" if is_bash else weapon_skill
	var damage := (shield_item.damage * Smithing.damage_mult(shield_item) if is_bash else base_damage) * current_attack.damage_mult * _charge_mult()
	damage *= Attributes.melee_mult() * stats.modifier("damage_dealt")
	if not is_bash:
		damage *= GameState.race_data.melee_damage_mult * Skills.weapon_damage_mult(skill) \
				* stats.modifier("weapon_damage_" + skill)
		if main_item:
			damage *= Attributes.heavy_damage_mult(main_item.weight)   # heavy, without the Strength for it
	if _riposte_left > 0.0:
		damage *= stats.modifier("riposte_damage")
	if _counter_left > 0.0:
		damage *= Armor.COUNTER_MULT
		_counter_left = 0.0
	if is_heavy:
		damage *= stats.modifier("heavy_attack_damage")   # Momentum (Heavy Armour)
	if main_item == null and not is_bash and Armor.has_perk("fists_of_steel"):
		var hands := Inventory.equipped_item("hands")
		if Armor.kind_of(hands) == "heavy":
			damage += hands.armor   # gauntlets as knuckles
	if main_item == null and not is_bash:
		damage = _unarmed_damage(target, damage)
	damage *= Sight.damage_mult(player)   # Moment of Clarity, Read the Fight
	var rune_blade: bool = not is_bash and player.effects.has("rune_blade")   # Enchant Weapon (Runecraft)
	if rune_blade:
		damage += Runecraft.BLADE_DAMAGE * stats.modifier("enchant_damage")
	var poise := current_attack.poise_damage * _charge_mult() * stats.modifier("poise_dealt") \
			* (1.0 if is_bash else Smithing.poise_mult(main_item))   # Heavy Hand
	var heavy := is_heavy
	var sneak := Stealth.sneak_attack_mult(target, "melee", null if is_bash else main_item)
	if sneak > 1.0:
		damage *= sneak
		if Stealth.has_perk("poised_strike"):
			poise *= 3.0
			heavy = true
	var result = target.take_hit(damage, player.global_position, current_attack.knockback, poise, heavy)
	Glamour.struck(target, player)
	if result == "blocked" or result == "parried":
		_bounced(result == "parried")
		return
	if sneak > 1.0:
		Stealth.sneak_attack_landed(target, sneak)
	if current_attack.applies_effect != "" and randf() < current_attack.effect_chance and target.has_method("add_effect"):
		target.add_effect(current_attack.applies_effect)
	if main_item == null and not is_bash:
		_unarmed_landed(target)
	if not is_bash:
		Alchemy.blade_hit(target)   # a poisoned blade
	if rune_blade and target.has_method("add_effect") and randf() < (1.0 if "searing_edge" in Character.perks else 0.3):
		target.add_effect("burning")
	Skills.add_xp(skill, 5.0 if is_heavy else 3.0)
	player.hud.flash_hit()
	_show_target_health(target)
	(off_animator if is_bash else animator).kick(Vector3(0.0, 0.0, 0.04))
	Sfx.play("hit_heavy" if is_heavy or is_bash else "hit_flesh")
	hit_stop(HIT_STOP_HEAVY if is_heavy else HIT_STOP_LIGHT)
	attack_landed.emit(target, damage)


# --- fists (the Unarmed skill's perks, docs/godot-starter/UNARMED.md) ------------------

func _unarmed_damage(target: Node, damage: float) -> float:
	if Armor.has_perk("combination"):   # each punch in a run on one target: +15%, up to +60%
		_combo_hits = mini(_combo_hits + 1, 4) if target == _combo_target and _combo_left > 0.0 else 0
		_combo_target = target
		_combo_left = 1.5
		damage *= 1.0 + 0.15 * _combo_hits
	if is_heavy and Armor.has_perk("knockout") and target.has_method("is_staggered") and target.is_staggered():
		damage *= 3.0
	if is_heavy and Armor.has_perk("elemental_fist") and Spellbook.current() != null and Spellbook.current().skill == "destruction":
		damage *= 1.5   # the readied Ruin spell rides the punch
	return damage


func _unarmed_landed(target: Node) -> void:
	if Armor.has_perk("open_wounds") and randf() < 0.2 and target.has_method("add_effect"):
		target.add_effect("bleeding")
	if Armor.has_perk("brawlers_recovery"):
		player.stats.stamina = minf(player.stats.stamina + 2.0, player.stats.max_stamina)
	if Armor.has_perk("spirit_fist"):
		player.stats.magicka = minf(player.stats.magicka + 3.0, player.stats.max_magicka)
	var stats = target.get("stats")
	if is_heavy and Armor.has_perk("quivering_palm") and stats != null and not stats.is_dead \
			and stats.health < stats.max_health * 0.15:
		stats.take_damage(stats.health * 10.0, true)   # finished: a heavy punch on the nearly beaten
		player.hud.notify("Quivering Palm")


# The enemy blocked (you're stuck a moment) or parried (you stagger).
func _bounced(parried: bool) -> void:
	_show_target_health(null)
	if parried:
		Sfx.play("parry", -2.0)
		hit_stop(HIT_STOP_PARRY)
		stagger(PARRIED_TIME)
		return
	Sfx.play("block", -2.0)
	hit_stop(HIT_STOP_LIGHT)
	(off_animator if is_bash else animator).kick(Vector3(0.0, 0.04, 0.1))
	player.camera_kick(Vector3(1.0, 0.0, 0.0))
	_set_state(State.RECOVERY)
	_queued = false
	combo_index = 0
	var recoil := AttackData.new()
	recoil.recovery = current_attack.recovery + RECOIL_TIME
	current_attack = recoil
	animator.go(_rest_pose(), recoil.recovery, -1.6)


func _show_target_health(target: Node) -> void:
	if target == null:
		return
	var target_stats = target.get("stats")
	if target_stats is Stats:
		player.hud.show_enemy_health(target_stats)


# A partly charged heavy does 60% of its damage, a full one 100%.
func _charge_mult() -> float:
	return lerpf(0.6, 1.0, charge) if is_heavy else 1.0


func _stamina_cost(attack: AttackData, heavy: bool = false) -> float:
	var cost: float = base_stamina_cost * attack.stamina_mult * player.stats.modifier("attack_stamina")
	if main_item:
		cost *= Attributes.heavy_stamina_mult(main_item.weight)
	if heavy:
		cost *= player.stats.modifier("heavy_stamina")
	return cost


# --- bows ----------------------------------------------------------------------------

func _start_drawing() -> void:
	if Inventory.count(main_item.ammo) <= 0:
		player.hud.flash_tired()
		player.hud.notify("No arrows")
		return
	_set_state(State.DRAWING)
	charge = 0.0
	animator.go("bow_draw", main_item.draw_time * player.stats.modifier("draw_time"), 0.6)


func _loose_arrow() -> void:
	if charge < MIN_DRAW or not player.stats.try_use_stamina(base_stamina_cost * player.stats.modifier("attack_stamina")):
		_to_ready()
		return
	Inventory.remove(main_item.ammo, 1)
	var power := lerpf(0.3, 1.0, (charge - MIN_DRAW) / (1.0 - MIN_DRAW))
	var stats: Stats = player.stats
	var arrow: Arrow = ARROW_SCENE.instantiate()
	arrow.shooter = player
	arrow.damage = base_damage * power * Skills.weapon_damage_mult("archery") \
			* stats.modifier("damage_dealt") * stats.modifier("weapon_damage_archery")
	arrow.poise_damage = lerpf(3.0, 15.0, power)
	arrow.sneaking = player.is_sneaking
	Stealth.make_noise(player.global_position, "archery")
	arrow.hit.connect(_on_arrow_hit)
	player.get_parent().add_child(arrow)
	var camera: Camera3D = player.camera
	var forward := -camera.global_transform.basis.z
	arrow.launch(camera.global_position + forward * 0.6, forward, main_item.arrow_speed * lerpf(0.55, 1.0, power))
	Sfx.play("bow_release", -3.0)
	player.camera_kick(Vector3(-0.8, 0.0, 0.0))
	animator.kick(Vector3(0.0, 0.0, 0.05))
	var recovery := AttackData.new()
	recovery.recovery = BOW_RECOVERY
	current_attack = recovery
	is_heavy = false
	charge = 0.0
	player.hud.set_charge(0.0)
	animator.set_charge(0.0)
	_set_state(State.RECOVERY)
	animator.go("bow_rest", BOW_RECOVERY)


func _on_arrow_hit(target: Node, _damage: float) -> void:
	Skills.add_xp("archery", 4.0)
	player.hud.flash_hit()
	_show_target_health(target)


# --- defending ------------------------------------------------------------------------

func _wants_block() -> bool:
	if not left_hand() in [Hand.BLOCK, Hand.SHIELD, Hand.TWO_HANDED]:
		_block_toggled = false
		return false
	if Settings.toggle_block:
		return _block_toggled
	return Input.is_action_pressed("cast")


func _update_block() -> void:
	var wants := _wants_block()
	if wants and state != State.BLOCKING:
		_set_state(State.BLOCKING)
		if left_hand() == Hand.SHIELD:
			off_animator.go("block", 0.08, 0.5)
			animator.go("lowered", 0.12)
		else:
			animator.go("block", 0.1, 0.5)
	elif not wants and state == State.BLOCKING:
		_to_ready()


func is_blocking() -> bool:
	return state == State.BLOCKING


## Share of a hit the current block stops (before the Block skill).
func guard_share() -> float:
	if left_hand() == Hand.SHIELD:
		return Smithing.block_reduction(shield_item)   # improved shields block more
	if main_item == null:
		return minf(block_reduction * player.stats.modifier("fist_block"), 0.8)   # Martial Guard
	return block_reduction


## Enemies call this when their attack lands. Returns "hit", "blocked",
## "parried", "dodged" or "guard_broken"; the attacker reacts to the result.
func receive_attack(damage: float, attacker: Node3D, poise_damage: float = 0.0) -> String:
	var stats: Stats = player.stats
	if stats.is_dead:
		return "hit"
	if Sight.blow_misses(attacker, player):   # Ill Fortune, Prescience, Moment of Clarity
		defended.emit("dodged")
		return "dodged"
	if _iframes_left > 0.0:
		if Armor.has_perk("counter_strike"):
			_counter_left = Armor.COUNTER_TIME
		defended.emit("dodged")
		return "dodged"
	var ward: float = player.magic.ward_share(attacker)
	if ward > 0.0 and player.magic.ward_absorb(damage * ward):
		stats.take_damage(damage * (1.0 - ward))
		player.hud.flash_block(false)
		Sfx.play("ward_hit", -3.0)
		defended.emit("warded")
		return "blocked"
	if state == State.BLOCKING and _facing(attacker):
		if _state_time <= PARRY_WINDOW * stats.modifier("parry_window"):
			_parried()
			return "parried"
		var share := Skills.block_share(guard_share())
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
		_guard_animator().kick(Vector3(0.0, -0.03, 0.06))
		player.hud.flash_block(false)
		Sfx.play("block", -3.0)
		player.camera_kick(Vector3(-1.0, 0.0, 0.0))
		defended.emit("blocked")
		return "blocked"
	var outcome := {}
	var taken := Armor.adjust_hit(damage, attacker, player, outcome)   # armour perks
	if taken <= 0.0:
		defended.emit(outcome.get("result", "dodged"))
		return outcome.get("result", "dodged")
	Armor.hit_taken(damage)   # trains Light / Heavy Armour
	stats.take_damage(taken)
	player.camera_kick(Vector3(-2.0, randf_range(-1.5, 1.5), randf_range(-3.0, 3.0)))
	stats.take_poise_damage(poise_damage)
	return "hit"


func _parried() -> void:
	Skills.add_xp("block", 6.0)
	if player.effects.has("foresight") and "counterseer" in Character.perks:
		player.stats.magicka = minf(player.stats.magicka + 20.0, player.stats.max_magicka)
	player.stats.stamina = minf(player.stats.stamina + 10.0, player.stats.max_stamina)
	player.stats.changed.emit()
	_riposte_left = RIPOSTE_TIME
	if left_hand() == Hand.SHIELD:
		off_animator.go("bash", 0.06, 0.4)
	else:
		animator.go("parry", 0.06, 0.4)
	player.hud.flash_block(true)
	Sfx.play("parry")
	hit_stop(HIT_STOP_PARRY)
	defended.emit("parried")


func _guard_animator() -> WeaponAnimator:
	return off_animator if left_hand() == Hand.SHIELD else animator


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


## True during a dodge's invulnerable frames (traps check this for unblockable hits).
func is_invulnerable() -> bool:
	return _iframes_left > 0.0


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
	animator.go("stagger" if not is_bow() else "bow_rest", 0.1, 0.5)
	if shield_item:
		off_animator.go("stagger", 0.1, 0.5)


# --- for the player's movement ------------------------------------------------------

## Speed multiplier while attacking, blocking or staggered.
func move_mult() -> float:
	match state:
		State.BLOCKING: return BLOCK_MOVE_MULT
		State.CHARGING, State.DRAWING: return 0.6
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


func _rest_pose() -> String:
	return "bow_rest" if is_bow() else "rest"


func _set_state(new_state: State) -> void:
	state = new_state
	_state_time = 0.0


func _to_ready() -> void:
	var was_blocking := state == State.BLOCKING
	_set_state(State.READY)
	is_heavy = false
	is_bash = false
	charge = 0.0
	_queued = false
	animator.set_charge(0.0)
	player.hud.set_charge(0.0)
	if animator.pose_name() != _rest_pose():
		animator.go(_rest_pose(), 0.15 if was_blocking else 0.25)
	if shield_item and off_animator.pose_name() != "rest":
		off_animator.go("rest", 0.15)


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
