class_name PlayerMagic
extends Node

# The player's spellcasting. A child of the Player called "Magic".
#
#   Right click (hold)   cast the ready spell with the left hand (Q picks the spell)
#   Left click (hold)    also casts it, with the right hand, when you hold no weapon
#   Both                 dual-cast: x2.2 power for x2.6 Magicka (spells with can_dual_cast)
#
# Streams drain Magicka while held. Bolts, areas and self spells charge while
# held and go off on release once fully charged (released early = fizzle, free).
# Wards stop part of a hit from the front while held (PlayerCombat asks
# ward_share()). Numbers live in each spell's .tres; the constants are the
# shared rules.

signal cast(spell: SpellData, dual: bool)

enum State { IDLE, CHANNEL, CHARGE }

const DUAL_POWER := 2.2
const DUAL_COST := 2.6
## Wards: Magicka spent per point of damage they stop.
const WARD_MAGICKA_PER_DAMAGE := 0.8
const WARD_ANGLE := 75.0
## After a charged spell goes off, this long before the next can start.
const RECAST_DELAY := 0.25
const BOLT_SCENE := preload("res://combat/spell_bolt.tscn")

var state := State.IDLE
var spell: SpellData
var charge := 0.0
var dual := false
var player: CharacterBody3D
var combat: PlayerCombat

var _cooldown := 0.0
var left_hand: Node3D           # the SpellHand node (orb, light, particles)
var right_hand: Node3D          # a mirrored copy, shown when the right hand is free
var _candle: OmniLight3D


func _ready() -> void:
	player = get_parent()
	combat = player.get_node("Combat")
	left_hand = player.get_node("Head/Camera3D/SpellHand")
	right_hand = left_hand.duplicate()
	right_hand.name = "SpellHandRight"
	right_hand.position.x = -left_hand.position.x
	left_hand.get_parent().add_child.call_deferred(right_hand)
	_candle = OmniLight3D.new()
	_candle.name = "Candlelight"
	_candle.position = Vector3(0.3, 2.3, 0.2)
	_candle.light_color = Color(1, 0.92, 0.75)
	_candle.light_energy = 1.6
	_candle.omni_range = 12.0
	_candle.visible = false
	player.add_child.call_deferred(_candle)


## True when no weapon is held and a spell is ready: left click casts too.
func right_hand_free() -> bool:
	return combat.main_item == null and combat.left_hand() == PlayerCombat.Hand.SPELL


## Share of a hit the ward stops right now (0 if no ward is up).
func ward_share(attacker: Node3D) -> float:
	if state != State.CHANNEL or spell == null or spell.style != SpellData.Style.WARD:
		return 0.0
	if not _in_front(attacker):
		return 0.0
	var share: float = spell.ward_strength * player.stats.modifier("ward_strength")
	if dual:
		share = 1.0 - (1.0 - share) * 0.4
	return minf(share, 0.95)


## A hit the ward stopped `stopped` damage of. Returns false if the ward
## didn't have the Magicka to hold (it breaks: the hit goes through).
func ward_absorb(stopped: float) -> bool:
	var cost := stopped * WARD_MAGICKA_PER_DAMAGE * _cost_mult()
	if not player.stats.try_use_magicka(cost):
		_stop()
		return false
	Skills.add_xp(spell.skill, stopped / 4.0)
	Spellcraft.ward_stopped(stopped, player, spell.skill)   # Ward Absorb (Mending)
	return true


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	_candle.visible = player.effects.has("candlelight")
	spell = Spellbook.current()
	var left := Input.is_action_pressed("cast") and combat.left_hand() == PlayerCombat.Hand.SPELL
	var right := Input.is_action_pressed("attack") and right_hand_free()
	var allowed: bool = spell != null and player.can_fight() and combat.state == PlayerCombat.State.READY
	# Nothing to do unless a hand is held, or a charged spell was just released.
	if not allowed or (not (left or right) and state != State.CHARGE):
		_stop()
		_update_visuals(delta, false, false)
		return
	match spell.style:
		SpellData.Style.STREAM, SpellData.Style.WARD:
			dual = left and right and spell.can_dual_cast
			_channel(delta)
		_:
			_charge(delta, left or right, left and right)
	_update_visuals(delta, left, right)


# --- held spells: streams and wards -------------------------------------------------

func _channel(delta: float) -> void:
	var cost := spell.magicka_per_second * delta * _cost_mult() * (DUAL_COST if dual else 1.0)
	if not player.stats.try_use_magicka(cost):
		_stop()
		return
	state = State.CHANNEL
	player.is_casting = true
	if spell.style == SpellData.Style.WARD:
		return   # the ward works when something hits it (ward_share)
	Stealth.make_noise(player.global_position, "spell")   # a stream is loud the whole time
	var power := spell.power_per_second * delta * _power_mult() * (_dual_power() if dual else 1.0)
	match spell.effect:
		SpellData.Effect.DAMAGE_STREAM:
			_damage_stream(power * player.stats.modifier("damage_dealt"))
		SpellData.Effect.DRAIN_STREAM, SpellData.Effect.SIPHON_STREAM:   # Drawing: take it, keep it
			Drawing.drained(_damage_stream(power * player.stats.modifier("damage_dealt")), spell, player)
		SpellData.Effect.HEAL_SELF:
			var healed := minf(power * Spellcraft.heal_mult(player, spell.skill), player.stats.max_health - player.stats.health)
			player.stats.heal(healed)
			Spellcraft.healed(healed, player, spell.skill)   # Respite, Cleansing Light, Shared Light
			Skills.add_xp(spell.skill, healed / 5.0)   # 1 XP per 5 health actually restored


## Hurts everything in the stream; returns the Health it actually took.
func _damage_stream(damage: float) -> float:
	var dealt := 0.0
	var cast_shape: ShapeCast3D = player.spell_cast
	cast_shape.target_position = Vector3(0, 0, -spell.range)
	cast_shape.force_shapecast_update()
	for i in cast_shape.get_collision_count():
		var target := cast_shape.get_collider(i)
		if target and target.has_method("take_hit") and not Binding.is_bound(target):
			var stats = target.get("stats")
			var before: float = stats.health if stats else damage
			target.take_hit(damage * Spellcraft.hit_mult(target, spell), player.global_position, 0.0)
			var took: float = before - stats.health if stats else damage
			dealt += took
			Spellcraft.landed(target, spell, took, player, true)
			if stats and stats.is_dead and spell.skill == "drawing":
				Drawing.killed(player)
			Glamour.struck(target, player)
			if spell.applies_effect != "" and target.has_method("add_effect"):
				target.add_effect(spell.applies_effect)
			Skills.add_xp(spell.skill, damage / 5.0)   # 1 XP per 5 damage dealt
			_show_target(target)
	return dealt


# --- charged spells: bolts, areas, self -----------------------------------------------

func _charge(delta: float, holding: bool, both: bool) -> void:
	if state != State.CHARGE:
		if not holding or _cooldown > 0.0:
			return
		if player.stats.magicka < spell.magicka_cost * _cost_mult():
			player.hud.flash_magicka()
			_cooldown = 0.4
			return
		state = State.CHARGE
		charge = 0.0
		dual = false
	charge = minf(charge + delta / maxf(spell.charge_time * player.stats.modifier("charge_time")
			* player.stats.modifier("charge_time_" + spell.skill), 0.05), 1.0)
	if both and charge >= 1.0 and spell.can_dual_cast:
		dual = true   # both hands held once charged: it goes off dual-cast
	player.hud.set_charge(charge)
	if holding:
		return
	# Released.
	if charge >= 1.0:
		_release()
	_stop()
	_cooldown = RECAST_DELAY


func _release() -> void:
	var cost := spell.magicka_cost * _cost_mult() * (DUAL_COST if dual else 1.0)
	if not player.stats.try_use_magicka(cost):
		player.hud.flash_magicka()
		return
	Stealth.make_noise(player.global_position, "spell")
	var power := _power_mult() * (_dual_power() if dual else 1.0)
	var cast_spell := Spellcraft.scaled(spell, player)   # the school's radius perks
	match spell.style:
		SpellData.Style.BOLT:
			_fire_bolt(spell.damage * power * player.stats.modifier("damage_dealt"))
		SpellData.Style.AREA:
			if spell.glamour != "":
				Glamour.cast(cast_spell, _aim_point(), power, player)
				Skills.add_xp(spell.skill, cost / 5.0)
			elif spell.drawing != "":
				Drawing.cast(spell, _aim_point(), power, player)
				Skills.add_xp(spell.skill, cost / 5.0)
			elif spell.sight != "":
				Sight.cast(spell, _aim_point(), power, player)
				Skills.add_xp(spell.skill, cost / 5.0)
			elif spell.rune != "":
				Runecraft.cast(spell, _aim_point(), power, player)
				Skills.add_xp(spell.skill, cost / 5.0)
			elif spell.binding != "":
				Binding.cast(spell, _aim_point(), power, player, cost)
				Skills.add_xp(spell.skill, cost / 5.0)
			elif spell.tide != "":
				for target in Tidecraft.cast(cast_spell, _aim_point(), power, player, dual):
					if spell.damage > 0.0:
						_show_target(target)
				Skills.add_xp(spell.skill, cost / 5.0)
			else:
				_burst(spell.damage * power * player.stats.modifier("damage_dealt"), cast_spell.radius)
		SpellData.Style.SELF:
			player.effects.apply(spell.self_effect)
			if spell.skill == "restoration" and Spellcraft.any("cleanse", "restoration"):
				Spellcraft.cleanse(player)   # Cleansing Light
			Skills.add_xp(spell.skill, cost / 6.0)
	player.camera_kick(Vector3(-0.8 if not dual else -1.6, 0.0, 0.0))
	Sfx.play("spell_cast", -2.0 if dual else -5.0)
	cast.emit(spell, dual)


func _fire_bolt(damage: float) -> void:
	var bolt: SpellBolt = BOLT_SCENE.instantiate()
	bolt.shooter = player
	bolt.damage = damage
	bolt.poise_damage = 16.0 if dual else 8.0
	bolt.applies_effect = spell.applies_effect
	bolt.color = spell.color
	var thrown := spell
	bolt.damage_for = func(target: Node, base: float) -> float: return base * Spellcraft.hit_mult(target, thrown)
	bolt.hit.connect(func(target, dealt):
		Skills.add_xp(thrown.skill, dealt / 5.0)
		Spellcraft.landed(target, thrown, dealt, player)
		_show_target(target))
	player.get_parent().add_child(bolt)
	var camera: Camera3D = player.camera
	var forward := -camera.global_transform.basis.z
	bolt.launch(camera.global_position + forward * 1.1 + camera.global_transform.basis.y * -0.12, forward,
			spell.projectile_speed, 1.5 if dual else 1.0)


# Where you're aiming: the first thing (ground, wall, enemy) the view hits, up
# to the spell's max_distance.
func _aim_point() -> Vector3:
	var camera: Camera3D = player.camera
	var from := camera.global_position
	var to: Vector3 = from - camera.global_transform.basis.z * spell.max_distance * player.stats.modifier("spell_range_" + spell.skill)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4)
	query.exclude = [player.get_rid()]
	var result := player.get_world_3d().direct_space_state.intersect_ray(query)
	return result["position"] if not result.is_empty() else to


# Where you're aiming: everything in the radius is hit, full damage at the
# centre down to half at the edge.
func _burst(damage: float, base_radius: float) -> void:
	var center := _aim_point()
	var radius := base_radius * (1.3 if dual else 1.0)
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var area := PhysicsShapeQueryParameters3D.new()
	area.shape = sphere
	area.transform = Transform3D(Basis(), center)
	area.collision_mask = 4
	var hits := []
	for hit in player.get_world_3d().direct_space_state.intersect_shape(area, 16):
		var target: Object = hit["collider"]
		if target in hits or not target.has_method("take_hit"):
			continue
		hits.append(target)
		var falloff := lerpf(1.0, 0.5, clampf(target.global_position.distance_to(center) / radius, 0.0, 1.0))
		var stats = target.get("stats")
		var before: float = stats.health if stats else 0.0
		target.take_hit(damage * falloff * Spellcraft.hit_mult(target, spell), center, 5.0, 12.0 if not dual else 20.0)
		Glamour.struck(target, player)
		Spellcraft.landed(target, spell, before - stats.health if stats else damage * falloff, player)
		if spell.applies_effect != "" and target.has_method("add_effect"):
			target.add_effect(spell.applies_effect)
		Skills.add_xp(spell.skill, damage * falloff / 5.0)
		_show_target(target)
	SpellBurst.spawn(player.get_parent(), center, radius, spell.color)
	Sfx.play_at("spell_impact", center)


# --- helpers ---------------------------------------------------------------------------

func _power_mult() -> float:
	return Skills.spell_power_mult(spell.skill) * Attributes.spell_mult() \
			* player.stats.modifier("spell_power") * player.stats.modifier("spell_power_" + spell.skill) \
			* Spellcraft.power_mult(spell, player) \
			* (Drawing.power_mult() if spell.skill == "drawing" else 1.0)   # one spell's perks and Tidecraft's moons (Spellcraft); Drawing by your corruption


func _cost_mult() -> float:
	return player.stats.modifier("spell_cost") * player.stats.modifier("spell_cost_" + spell.skill) * Spellcraft.cost_mult(spell, player)


func _dual_power() -> float:
	return DUAL_POWER * player.stats.modifier("dual_power")   # Twin Flames (Ruin)


func _in_front(attacker: Node3D) -> bool:
	if attacker == null:
		return true
	var to := attacker.global_position - player.global_position
	to.y = 0.0
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	return to.length() < 0.01 or rad_to_deg(forward.angle_to(to)) <= WARD_ANGLE


func _show_target(target: Node) -> void:
	var target_stats = target.get("stats")
	if target_stats is Stats:
		player.hud.show_enemy_health(target_stats)
	player.hud.flash_hit()


func _stop() -> void:
	if state == State.CHARGE:
		player.hud.set_charge(0.0)
	state = State.IDLE
	charge = 0.0
	dual = false
	player.is_casting = false


# Hand glow and particles: which hands are casting, and how hard.
func _update_visuals(delta: float, left_active: bool, right_active: bool) -> void:
	var hand_free := combat.left_hand() == PlayerCombat.Hand.SPELL
	right_hand.visible = right_hand_free()
	for hand in [left_hand, right_hand]:
		var active: bool = (hand == left_hand and left_active) or (hand == right_hand and right_active)
		active = active and state != State.IDLE
		var streaming := active and state == State.CHANNEL
		hand.get_node("Fire").emitting = streaming and spell.effect == SpellData.Effect.DAMAGE_STREAM and spell.style == SpellData.Style.STREAM
		hand.get_node("HealSparks").emitting = streaming and (spell.effect == SpellData.Effect.HEAL_SELF or spell.style == SpellData.Style.WARD)
		var glow := 0.4
		if active:
			glow = 2.5 + randf() * 0.8 if state == State.CHANNEL else 0.8 + charge * 3.0
		var light: OmniLight3D = hand.get_node("Light")
		light.light_energy = lerpf(light.light_energy, glow, minf(delta * 15.0, 1.0))
		hand.get_node("Orb").scale = Vector3.ONE * (1.0 + (0.4 if state == State.CHANNEL and active else charge * 0.8 if active else 0.0))
	left_hand.visible = hand_free
