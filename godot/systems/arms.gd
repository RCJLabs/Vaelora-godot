extends Node

# The martial perks that are more than a number: crits, bleeding, staggers,
# executions, momentum, cleaving and the rest. Autoloaded as "Arms".
# docs/godot-starter/COMBAT.md, "Martial perk trees".
#
# Perks in character/perks.json carry the fields below; this sums or multiplies
# them over the perks you have whose condition holds (Armor.perk_applies: e.g.
# "when_skill": "one_handed", "when_weapon": "axe", "when_shield": true).
# Plain numbers (damage, stamina, reach, speed) are ordinary "modifiers".
#
#   crit          chance a blow lands double                         (summed)
#   bleed         chance a blow makes them bleed                     (summed)
#   stagger       chance a blow staggers them                        (summed)
#   heavy_stagger heavy blows always stagger                         (any)
#   execute       x damage to an enemy under a quarter health        (multiplied)
#   duel          x damage with no other enemy within DUEL_RANGE     (multiplied)
#   vs_staggered  x damage to a staggered enemy                      (multiplied)
#   vs_beasts     x damage to wolves and other beasts                (multiplied)
#   rage          x damage while you're under half health            (multiplied)
#   charge        x damage for an attack begun at a sprint           (multiplied)
#   long_shot     x arrow damage past LONG_SHOT metres               (multiplied)
#   momentum      +damage per hit landed in a row, up to MOMENTUM_MAX (summed)
#   cleave        share of a heavy blow that hits others near it     (summed)
#   quake         heavy blows stagger everything near them           (any)
#   kill_stamina  Stamina back on a kill                             (summed)
#   kill_free     the next swing after a kill costs no Stamina       (any)
#   poise_guard   x stagger you take while attacking (0: none)       (multiplied)
#   retaliate     x damage for RETALIATE_TIME after you block a blow (multiplied)

const DUEL_RANGE := 8.0
const LONG_SHOT := 25.0
const MOMENTUM_MAX := 5
const MOMENTUM_TIME := 2.5      # seconds between hits before it's lost
const CLEAVE_RADIUS := 2.5
const QUAKE_RADIUS := 3.0
const RETALIATE_TIME := 2.0
const KILL_FREE_TIME := 3.0

var crit_landed := false        # the last blow was a crit (the HUD says so)
var _momentum := 0
var _momentum_left := 0.0
var _retaliate_left := 0.0
var _kill_free_left := 0.0


## The perks that count now.
func _active() -> Array:
	return Character.perks.filter(func(id): return Character.perk_list.has(id) and Armor.perk_applies(Character.perk_list[id]))


func sum(key: String) -> float:
	var total := 0.0
	for id in _active():
		total += float(Character.perk_list[id].get(key, 0.0))
	return total


func prod(key: String) -> float:
	var total := 1.0
	for id in _active():
		total *= float(Character.perk_list[id].get(key, 1.0))
	return total


func any(key: String) -> bool:
	return _active().any(func(id): return Character.perk_list[id].get(key, false))


func _process(delta: float) -> void:
	_momentum_left -= delta
	if _momentum_left <= 0.0:
		_momentum = 0
	_retaliate_left -= delta
	_kill_free_left -= delta


# --- hitting -----------------------------------------------------------------------

## What a blow (or arrow) on `target` is multiplied by. Rolls the crit.
func hit_mult(target: Node, player: Node3D, charged_from_sprint: bool = false, distance: float = 0.0) -> float:
	var mult := 1.0
	crit_landed = randf() < sum("crit")
	if crit_landed:
		mult *= 2.0
	var stats = target.get("stats")
	if stats and stats.health < stats.max_health * 0.25:
		mult *= prod("execute")
	if target.has_method("is_staggered") and target.is_staggered():
		mult *= prod("vs_staggered")
	if target.is_in_group("beast"):
		mult *= prod("vs_beasts")
	if player.stats.health < player.stats.max_health * 0.5:
		mult *= prod("rage")
	if charged_from_sprint:
		mult *= prod("charge")
	if distance >= LONG_SHOT:
		mult *= prod("long_shot")
	if _alone_with(target, player):
		mult *= prod("duel")
	if _retaliate_left > 0.0:
		mult *= prod("retaliate")
	if player.effects.has("invisible"):
		mult *= prod("unseen_strike")   # Shade's Edge (Glamour)
	if target.get("_afraid"):
		mult *= prod("vs_afraid")   # Panic (Glamour)
	mult *= 1.0 + sum("momentum") * _momentum
	return mult


func _alone_with(target: Node, player: Node3D) -> bool:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy != target and enemy is Node3D and not Glamour._dead(enemy) and not Binding.is_bound(enemy) \
				and enemy.global_position.distance_to(player.global_position) <= DUEL_RANGE:
			return false
	return true


## A blow landed: bleeding, staggers, cleaving, momentum, and what a kill gives.
func landed(target: Node, damage: float, player: Node3D, heavy: bool) -> void:
	_momentum = mini(_momentum + 1, MOMENTUM_MAX)
	_momentum_left = MOMENTUM_TIME
	if target.has_method("add_effect") and randf() < sum("bleed"):
		target.add_effect("bleeding")
	if randf() < sum("stagger") or (heavy and any("heavy_stagger")):
		_stagger(target, player)
	if heavy:
		var share := sum("cleave")
		var quake := any("quake")
		if share > 0.0 or quake:
			for other in get_tree().get_nodes_in_group("enemy"):
				if other == target or not other is Node3D or not other.has_method("take_hit") or Glamour._dead(other) \
						or Binding.is_bound(other) or other.global_position.distance_to(target.global_position) > maxf(CLEAVE_RADIUS, QUAKE_RADIUS):
					continue
				if share > 0.0 and other.global_position.distance_to(target.global_position) <= CLEAVE_RADIUS:
					other.take_hit(damage * share, player.global_position, 3.0, 10.0)
				if quake:
					_stagger(other, player)
	var stats = target.get("stats")
	if stats and stats.is_dead:
		killed(player)


func _stagger(target: Node, player: Node3D) -> void:
	if target.has_method("stagger") and not Glamour._dead(target):
		target.stagger(1.2)
	elif target.has_method("take_hit"):
		target.take_hit(0.0, player.global_position, 0.0, 999.0)


func killed(player: Node3D) -> void:
	var stamina := sum("kill_stamina")
	if stamina > 0.0:
		player.stats.stamina = minf(player.stats.stamina + stamina, player.stats.max_stamina)
	if any("kill_free"):
		_kill_free_left = KILL_FREE_TIME


## Blade Dance: the next swing after a kill is free (PlayerCombat asks before charging Stamina).
func free_swing() -> bool:
	if _kill_free_left > 0.0:
		_kill_free_left = 0.0
		return true
	return false


# --- defending ---------------------------------------------------------------------

## You were hit: momentum is lost.
func hurt() -> void:
	_momentum = 0


## You blocked a blow: Retaliation readies.
func blocked() -> void:
	if prod("retaliate") > 1.0:
		_retaliate_left = RETALIATE_TIME


func reset() -> void:
	_momentum = 0
	_retaliate_left = 0.0
	_kill_free_left = 0.0
	crit_landed = false
