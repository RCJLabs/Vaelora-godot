extends Node

# Spell-blades: a spell in one hand charges the weapon in the other.
# Autoloaded as "Spellblade". docs/godot-starter/COMBAT.md, "Spell-blades".
#
# With a one-handed weapon in the right hand and a damage spell ready in the left,
# charge the spell fully and press Attack instead of letting go: the spell goes
# into the blade (PlayerMagic.try_imbue pays its Magicka). The next BLOWS blows
# that land carry SHARE of the spell's damage and its effect (a fire blade burns,
# a frost blade chills), and count as the spell landing for combinations: a fire
# blade on a chilled enemy shatters. The charge fades after TIME seconds unused.
#
# Perks: Spellsword (One-Handed, blade_power), Lingering Charge (Ruin,
# blade_blows), Arc Discharge (Ruin, blade_discharge: the last charged blow bursts).

signal changed

const BLOWS := 3
const SHARE := 0.6
const TIME := 30.0
const DISCHARGE_RADIUS := 3.0

var spell: SpellData            # the spell in the blade (null: none)
var blows_left := 0
var _bonus := 0.0               # damage each charged blow adds
var _full := 0.0                # the spell's own damage, at the power it was cast with
var _time_left := 0.0
var _glow: OmniLight3D


## Spells that can go into a blade: charged ones that just do damage (and maybe an
## effect), not the schools' special casts.
func can_hold(s: SpellData) -> bool:
	return s != null and s.style in [SpellData.Style.BOLT, SpellData.Style.AREA] and s.damage > 0.0 \
			and s.glamour == "" and s.tide == "" and s.binding == "" and s.rune == "" \
			and s.sight == "" and s.drawing == ""


## A weapon that can take a charge: a melee one in the right hand.
func can_take(weapon: ItemData) -> bool:
	return weapon != null and weapon.type == ItemData.Type.WEAPON and weapon.weapon_kind == ItemData.WeaponKind.MELEE


func active() -> bool:
	return spell != null and blows_left > 0


## What a charged blow adds (0 when the blade isn't charged).
func bonus() -> float:
	return _bonus if active() else 0.0


## `s`, cast at `power` (the caster's spell power multiplier), goes into the blade.
func imbue(s: SpellData, power: float, player: Node3D) -> void:
	spell = s
	_full = s.damage * power * player.stats.modifier("damage_dealt")
	_bonus = _full * SHARE * Arms.prod("blade_power")   # Spellsword
	blows_left = BLOWS + int(Arms.sum("blade_blows"))   # Lingering Charge
	_time_left = TIME
	Skills.add_xp(s.skill, s.magicka_cost / 5.0)
	_show_glow(player)
	player.hud.notify("%s in your blade: %d blows." % [s.display_name, blows_left])
	changed.emit()


## A charged blow has landed on `target` (PlayerCombat calls this after the hit).
func landed(target: Node, player: Node3D) -> void:
	if not active():
		return
	var s := spell
	Combos.spell_landed(target, s, player)   # a fire blade on frost: Shatter
	if s.applies_effect != "" and target.has_method("add_effect") and not Glamour._dead(target):
		target.add_effect(s.applies_effect)
	Skills.add_xp(s.skill, _bonus / 5.0)
	blows_left -= 1
	if blows_left == 0:
		if Arms.any("blade_discharge"):
			_discharge(target, player)   # Arc Discharge
		_end(player, "The charge in your blade is spent.")
	else:
		changed.emit()


func _process(delta: float) -> void:
	if not active():
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_end(get_tree().get_first_node_in_group("player"), "The charge in your blade fades.")


## The last charged blow bursts: the spell's full damage to everything near.
func _discharge(at: Node, player: Node3D) -> void:
	var center: Vector3 = (at as Node3D).global_position if at is Node3D else player.global_position
	var sphere := SphereShape3D.new()
	sphere.radius = DISCHARGE_RADIUS
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), center)
	query.collision_mask = 4
	var hit := []
	for found in player.get_world_3d().direct_space_state.intersect_shape(query, 16):
		var target: Object = found["collider"]
		if target in hit or target == player or not target.has_method("take_hit") or Glamour._dead(target):
			continue
		hit.append(target)
		target.take_hit(_full, center, 5.0, 12.0)
		if spell.applies_effect != "" and target.has_method("add_effect"):
			target.add_effect(spell.applies_effect)
	SpellBurst.spawn(player.get_parent(), center, DISCHARGE_RADIUS, spell.color)
	Sfx.play_at("spell_impact", center)


func _end(player: Node, message: String) -> void:
	spell = null
	blows_left = 0
	_bonus = 0.0
	if _glow and is_instance_valid(_glow):
		_glow.visible = false
	if player and player.get("hud"):
		player.hud.notify(message)
	changed.emit()


## A light by the weapon, the spell's colour, while it's charged.
func _show_glow(player: Node3D) -> void:
	if _glow == null or not is_instance_valid(_glow):
		_glow = OmniLight3D.new()
		_glow.name = "BladeGlow"
		_glow.position = Vector3(0.38, -0.25, -0.75)
		_glow.omni_range = 1.6
		_glow.light_energy = 1.6
		player.camera.add_child(_glow)
	_glow.light_color = spell.color
	_glow.visible = true


func reset() -> void:
	if _glow and is_instance_valid(_glow):
		_glow.visible = false
	spell = null
	blows_left = 0
	_bonus = 0.0
	_glow = null
