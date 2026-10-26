extends "res://tests/test_base.gd"
# The four peoples made playable after human, elf and orc (races/*.tres): each
# in the creator, and each one's power (Z). The walking, jumping and Maren's line
# for each are test_race's (one variant per race).
const PEOPLES := ["passenger", "ashen", "small_folk", "deepfolk"]
var f := 0
var step := 0
var wait := 0
var p
var C

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

## Become `race` (a fresh character) and use its power.
func become(race: String) -> bool:
	C.create(load("res://races/%s.tres" % race), "T", "soldier", [], {}, {})
	p.effects.clear()
	return C.use_power(0)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	C = autoload("Character")
	match step:
		0:
			for i in [1, 2, 3]: current_scene.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			var cc = load("res://ui/character_creation.tscn").instantiate()
			ok(cc.RACE_FILES.size() == 7, "seven races in the creator", cc.RACE_FILES.size())
			cc.free()
			for id in PEOPLES:
				var race: RaceData = load("res://races/%s.tres" % id)
				ok(C.ability_list.has(race.ability_id), "%s's power exists" % race.display_name, race.ability_id)
				ok(race.description != "" and race.traits != "", "%s is described" % race.display_name)
			ok(become("passenger") and p.effects.has("lanes_walk"), "Passenger: Lanes-Walk")
			near(p.stats.modifier("awareness_rate"), 0.33, 0.001, "enemies notice a sneaking Passenger at a third of the rate")
			near(autoload("GameState").race_data.reputation_gain_mult, 0.85, 0.001, "and reputation comes slower (they're blamed)")
			ok(become("ashen") and p.effects.has("wisp_grace") and p.effects.has("kinship"), "Ashen: Kinship")
			ok(p.effects.active["wisp_grace"]["time_left"] <= 60.0, "the wisps let you be for a minute")
			near(p.stats.modifier("damage_taken"), 0.85, 0.001, "and 15% less damage")
			ok(become("small_folk") and p.effects.has("fortunes_favour"), "Small folk: Fortune's Favour")
			ok(autoload("Spellbook").known.is_empty(), "small folk know no spells at the start", autoload("Spellbook").known)
			p.stats.max_health = 100000.0; p.stats.health = 100000.0
			var missed := [0]
			p.stats.missed.connect(func(): missed[0] += 1)
			for i in 600:
				p.stats.take_damage(1.0)
			ok(missed[0] > 150 and missed[0] < 260, "about a third of 600 blows miss", missed[0])
			var ticks_before: float = p.stats.health
			p.stats.take_damage(5.0, true)
			ok(p.stats.health < ticks_before, "burning and bleeding still land")
			p.effects.clear()
			ok(become("deepfolk") and p.effects.has("steadfast"), "Deepfolk: Steadfast")
			near(p.stats.modifier("poise_damage_taken"), 0.25, 0.001, "a quarter of the poise damage")
			near(p.stats.modifier("damage_taken"), 0.85, 0.001, "and 15% less damage")
			ok(C.cooldowns.has("steadfast") and not C.use_power(0), "then it waits")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
