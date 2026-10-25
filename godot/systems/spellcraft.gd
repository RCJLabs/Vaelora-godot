extends Node

# The magic perks that are more than a number, for Ruin, Shaping, Mending,
# Glamour and Tidecraft. Autoloaded as "Spellcraft". docs/godot-starter/MAGIC.md,
# "Perk trees".
#
# A school's perk fields count for that school's spells (a Ruin perk for Ruin):
#   spell_crit     chance a hit lands double                       (summed)
#   spell_execute  x damage to an enemy under a quarter health     (multiplied)
#   spell_stagger  chance a hit staggers                           (summed)
#   chain          share of a hit that arcs to the nearest other enemy within CHAIN_RANGE
#   kill_magicka   Magicka back on a kill                          (summed)
#   effect_time    x how long the spell's effect stays on them     (multiplied)
#   low_magicka    x damage while you're under a quarter Magicka   (multiplied)
#   heal_stamina   share of healing that's Stamina too             (summed)
#   battle_heal    x healing with an enemy within 10 m             (multiplied)
#   low_heal       x healing under a quarter of your health        (multiplied)
#   night_heal     x healing at night                              (multiplied)
#   cleanse        healing ends poison, bleeding, burning, venom   (any)
#   shared_light   healing reaches your companion within 6 m too   (any)
#   ward_magicka   share of what a ward stops that comes back as Magicka
#   tide_swing     x how much the moons sway Tidecraft             (multiplied)
#   no_neap        the moons never weaken Tidecraft                (any)
# And from any perk: last_breath (Mending), moon_power, and the always-on buffs
# _process keeps up (Deep Reserves, Lantern Mind, Living Stone, Stone Ward).
# Per-spell numbers are plain modifiers: spell_power_<id>, spell_cost_<id>,
# spell_radius_<school>, dual_power.

const CHAIN_RANGE := 5.0
const LAST_BREATH_COOLDOWN := 600.0   # seconds
const LAST_BREATH_HEAL := 50.0
const CLEANSED := ["poisoned", "bleeding", "burning", "venom"]

var _last_breath_left := 0.0


func _school(school: String) -> Array:
	return Character.perks.filter(func(id): return Character.perk_list.has(id) and Character.perk_list[id]["skill"] == school)


func sum(key: String, school: String) -> float:
	var total := 0.0
	for id in _school(school):
		total += float(Character.perk_list[id].get(key, 0.0))
	return total


func prod(key: String, school: String) -> float:
	var total := 1.0
	for id in _school(school):
		total *= float(Character.perk_list[id].get(key, 1.0))
	return total


func any(key: String, school: String = "") -> bool:
	var ids: Array = Character.perks if school == "" else _school(school)
	return ids.any(func(id): return Character.perk_list.has(id) and Character.perk_list[id].get(key, false))


# --- power and cost ------------------------------------------------------------------

## Folded into PlayerMagic._power_mult: one spell's perks, the moons, Moonborn.
func power_mult(spell: SpellData, player: Node) -> float:
	var mult: float = player.stats.modifier("spell_power_" + spell.id)
	if spell.tide != "":
		var tide := WorldClock.tide_mult()
		tide = 1.0 + (tide - 1.0) * prod("tide_swing", "tidecraft")
		if any("no_neap", "tidecraft"):
			tide = maxf(tide, 1.0)
		mult *= tide
	if any("moon_power") and WorldClock.tide_mult() > 1.15:
		mult *= 1.2   # Moonborn: a high tide strengthens every spell
	if player.stats.magicka < player.stats.max_magicka * 0.25:
		mult *= prod("low_magicka", spell.skill)
	return mult


func cost_mult(spell: SpellData, player: Node) -> float:
	return player.stats.modifier("spell_cost_" + spell.id)


## A copy of `spell` with its school's radius perks (Wide Blast, Spreading Spell...).
func scaled(spell: SpellData, player: Node) -> SpellData:
	var radius: float = player.stats.modifier("spell_radius_" + spell.skill)
	if is_equal_approx(radius, 1.0):
		return spell
	var copy: SpellData = spell.duplicate()
	copy.radius *= radius
	return copy


# --- hits ----------------------------------------------------------------------------

## What a hit by `spell` on `target` is multiplied by (rolls the crit).
func hit_mult(target: Node, spell: SpellData) -> float:
	var mult := 2.0 if randf() < sum("spell_crit", spell.skill) else 1.0
	var player := get_tree().get_first_node_in_group("player") as Node3D
	mult *= Combos.riptide_mult(target, player)   # Riptide
	var stats = target.get("stats")
	if stats and stats.health < stats.max_health * 0.25:
		mult *= prod("spell_execute", spell.skill)
	return mult


## A hit by `spell` landed on `target` for `dealt`. Streams hit every frame, so
## they don't roll staggers.
func landed(target: Node, spell: SpellData, dealt: float, player: Node3D, stream: bool = false) -> void:
	var school := spell.skill
	Combos.spell_landed(target, spell, player)   # Shatter
	if spell.applies_effect != "":
		var effects = target.get("effects")
		if effects is StatusEffects and effects.active.has(spell.applies_effect):
			var entry: Dictionary = effects.active[spell.applies_effect]
			entry["time_left"] = maxf(entry["time_left"], entry["data"].duration * prod("effect_time", school))   # once, not every frame
	if not stream and randf() < sum("spell_stagger", school) and target.has_method("stagger") and not Glamour._dead(target):
		target.stagger(1.0)
	var share := sum("chain", school)
	if share > 0.0 and dealt > 0.0:
		var next := _nearest_other(target, player)
		if next:
			next.take_hit(dealt * share, target.global_position, 0.0)
			SpellBurst.spawn(next.get_parent(), next.global_position + Vector3(0, 0.6, 0), 0.5, spell.color)
	var stats = target.get("stats")
	if stats and stats.is_dead:
		player.stats.magicka = minf(player.stats.magicka + sum("kill_magicka", school), player.stats.max_magicka)


func _nearest_other(target: Node, player: Node3D) -> Node3D:
	var best: Node3D = null
	var best_dist := CHAIN_RANGE
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy == target or not enemy is Node3D or not enemy.has_method("take_hit") or Glamour._dead(enemy) or Binding.is_bound(enemy):
			continue
		var d: float = enemy.global_position.distance_to(target.global_position)
		if d < best_dist:
			best = enemy
			best_dist = d
	return best


# --- healing and wards ---------------------------------------------------------------

func heal_mult(player: Node3D, school: String) -> float:
	var mult := 1.0
	if player.stats.health < player.stats.max_health * 0.25:
		mult *= prod("low_heal", school)
	if WorldClock.is_night():
		mult *= prod("night_heal", school)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy is Node3D and not Glamour._dead(enemy) and not Binding.is_bound(enemy) \
				and enemy.global_position.distance_to(player.global_position) <= 10.0:
			mult *= prod("battle_heal", school)
			break
	return mult


## You healed `amount` with a `school` spell: Respite, Cleansing Light, Shared Light.
func healed(amount: float, player: Node3D, school: String) -> void:
	player.stats.stamina = minf(player.stats.stamina + amount * sum("heal_stamina", school), player.stats.max_stamina)
	if any("cleanse", school):
		cleanse(player)
	if any("shared_light", school):
		var companion := Companions.body()
		if companion and not companion.is_down and companion.global_position.distance_to(player.global_position) <= 6.0:
			companion.health = minf(companion.health + amount, companion.max_health)


func cleanse(player: Node) -> void:
	for id in CLEANSED:
		player.effects.remove(id)


## A ward stopped `stopped`: Ward Absorb gives some back.
func ward_stopped(stopped: float, player: Node, school: String) -> void:
	player.stats.magicka = minf(player.stats.magicka + stopped * sum("ward_magicka", school), player.stats.max_magicka)


## Stone Body: in Stoneflesh, nothing staggers you.
func poise_taken_mult(player: Node) -> float:
	return 0.0 if any("stone_body", "alteration") and player.effects.has("stoneflesh") else 1.0


# --- always-on -----------------------------------------------------------------------

func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or get_tree().paused:
		return
	var stats: Stats = player.stats
	_keep(player, "deep_reserves", any("deep_reserves") and stats.magicka < stats.max_magicka * 0.5)
	_keep(player, "lantern_mind", any("lantern_mind") and player.effects.has("candlelight"))
	_keep(player, "living_stone", any("living_stone") and player.effects.has("stoneflesh"))
	_keep(player, "stone_ward", any("stone_ward") and player.effects.has("stoneflesh"))
	_last_breath_left -= delta
	if any("last_breath") and _last_breath_left <= 0.0 and not stats.is_dead and stats.health > 0.0 \
			and stats.health < stats.max_health * 0.1:
		stats.heal(LAST_BREATH_HEAL)
		_last_breath_left = LAST_BREATH_COOLDOWN
		player.hud.notify("Last Breath: the light holds you up.")


func _keep(player: Node, id: String, on: bool) -> void:
	if on and not player.effects.has(id):
		player.effects.apply(id)
	elif not on and player.effects.has(id):
		player.effects.remove(id)


func reset() -> void:
	_last_breath_left = 0.0
