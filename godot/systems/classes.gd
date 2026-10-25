extends Node

# Classes: chosen at creation (a third choice next to race and background).
# Autoloaded as "Classes". docs/godot-starter/CLASSES.md.
#
# A class's five skills improve XP_MULT faster, and it gives a third power (the
# class power, R / D-pad left) only it has. It never stops you learning anything.
# Change it with Aurel's rite (the paid respec). The classes are data in
# res://character/classes.json; their powers are entries in abilities.json, and
# the ones that need more than an effect or a restore ("class": true) are here
# (activate()).

const FILE := "res://character/classes.json"
const XP_MULT := 1.2

const WAR_CRY_RADIUS := 8.0
const MARK_RANGE := 40.0
const VANISH_TIME := 8.0
const MOON_FAVOUR_TIME := 60.0
const MANTLE_RADIUS := 3.0
const MANTLE_DPS := 8.0
const FEAST_SHARE := 0.5        # Shadow Feast: a sneak attack heals this share of its damage
const RALLY_ALLY_MULT := 1.25
const BARGAIN_HEALTH := 30.0
const BARGAIN_MAGICKA := 60.0

var classes: Dictionary = {}
var moon_favour_left := 0.0
var _mantle_tick := 0.0


func _init() -> void:   # (not _ready: a test's _initialize creates a character first)
	var data = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if data is Dictionary:
		classes = data
	else:
		push_error("Classes: %s is missing or not valid JSON." % FILE)


## The class's five skills (none for "").
func skills_of(id: String) -> Array:
	return classes.get(id, {}).get("skills", [])


## Your class gives `skill` faster XP.
func has_skill(skill: String) -> bool:
	return skill in skills_of(Character.class_id)


func name_of(id: String) -> String:
	return classes.get(id, {}).get("name", "No class")


## "One-Handed, Two-Handed, Block, Heavy Armour, Smithing"
func skills_text(id: String) -> String:
	return ", ".join(skills_of(id).map(func(s): return Skills.SKILLS[s]["name"]))


## A class power that needs code (abilities.json "class": true). False if it
## can't go off now (nothing to aim at, too little Health...): no cooldown then.
func activate(id: String, player: Node3D) -> bool:
	match id:
		"war_cry":
			for enemy in _enemies_near(player.global_position, WAR_CRY_RADIUS):
				if enemy.has_method("stagger"):
					enemy.stagger(1.5)
			Stealth.make_noise(player.global_position, "melee")
			player.camera_kick(Vector3(-1.2, 0.0, 0.0))
			return true
		"hunters_mark":
			var target := _aimed(player)
			if target == null:
				player.hud.notify("Aim at an enemy to mark it.")
				return false
			target.effects.apply("hunters_mark")
			return true
		"vanish":
			player.effects.apply("invisible")
			player.effects.active["invisible"]["time_left"] = VANISH_TIME
			return true
		"quickened_blade":
			var spell := Spellbook.current()
			if not Spellblade.can_take(player.combat.main_item):
				player.hud.notify("Quickened Blade needs a melee weapon in your hand.")
				return false
			if not Spellblade.can_hold(spell):
				player.hud.notify("Ready a damage spell (Firebolt, Frost Burst) first.")
				return false
			Spellblade.imbue(spell, player.magic.power_mult_for(spell), player)
			return true
		"moons_favour":
			moon_favour_left = MOON_FAVOUR_TIME
			return true
		"second_breath":
			player.stats.heal(player.stats.max_health * 0.5)
			player.stats.stamina = minf(player.stats.stamina + player.stats.max_stamina * 0.5, player.stats.max_stamina)
			return true
		"old_bargain":
			if player.stats.health <= BARGAIN_HEALTH:
				player.hud.notify("Not enough Health to bargain with.")
				return false
			player.stats.health -= BARGAIN_HEALTH
			player.stats.magicka = minf(player.stats.magicka + BARGAIN_MAGICKA, player.stats.max_magicka)
			return true
	return true


## Moon's Favour: the tide is high for you (WorldClock.tide asks).
func moon_favoured() -> bool:
	return moon_favour_left > 0.0


## Call the Host: one more bound creature (Binding.max_summons asks).
func extra_summons() -> int:
	return 1 if _player_has("call_the_host") else 0


## Rally: companions hit harder (Command.damage_mult asks).
func ally_mult() -> float:
	return RALLY_ALLY_MULT if _player_has("rally") else 1.0


## Shadow Feast: a sneak attack that did `damage` heals you (PlayerCombat calls it).
func sneak_attack_landed(damage: float, player: Node3D) -> void:
	if player.effects.has("shadow_feast"):
		player.stats.heal(damage * FEAST_SHARE)


func _process(delta: float) -> void:
	if get_tree().paused:
		return
	moon_favour_left = maxf(moon_favour_left - delta, 0.0)
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.effects.has("storm_mantle"):
		_mantle_tick = 0.0
		return
	_mantle_tick += delta
	if _mantle_tick < 0.5:
		return
	for enemy in _enemies_near(player.global_position, MANTLE_RADIUS):
		enemy.take_hit(MANTLE_DPS * _mantle_tick, player.global_position, 0.0, 0.0)
	_mantle_tick = 0.0


func _enemies_near(at: Vector3, radius: float) -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(e):
		return e is Node3D and e.is_visible_in_tree() and e.has_method("take_hit") and not Glamour._dead(e) \
				and not Binding.is_bound(e) and e.global_position.distance_to(at) <= radius)


func _aimed(player: Node3D) -> Node3D:
	var target := Command.aimed_enemy(player)
	if target and target.global_position.distance_to(player.global_position) <= MARK_RANGE and target.get("effects"):
		return target
	return null


func _player_has(effect: String) -> bool:
	var player := get_tree().get_first_node_in_group("player")
	return player != null and player.effects.has(effect)


func reset() -> void:
	moon_favour_left = 0.0
	_mantle_tick = 0.0
