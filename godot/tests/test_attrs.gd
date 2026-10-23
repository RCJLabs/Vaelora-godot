extends "res://tests/test_base.gd"
# Race attributes: pools, regen and multipliers for a race, the Tab menu's attribute row, and save/load.
# Argument: race file name (default orc).
var f := 0
var started := false
var race := "orc"
var saved_str := 0

# Expected values per race (from races/*.tres via Attributes).
const EXPECT := {
	"orc": {"max_health": 140, "max_stamina": 121, "max_magicka": 60, "stamina_regen": 15.0, "magicka_regen": 5.0,
		"melee": 1.09, "spell": 0.96, "rep": 0.97,
		"row": ["Strength  13", "Endurance  12", "Agility  10", "Intellect  8", "Willpower  10", "Presence  9"]},
}

func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		race = arg("orc")
		var r = load("res://races/%s.tres" % race)
		autoload("GameState").set_race(r); autoload("Attributes").reset(r); autoload("Skills").reset(r)
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		return false
	f += 1
	if f == 3:
		var p = get_first_node_in_group("player"); var A = autoload("Attributes")
		if EXPECT.has(race):
			var e: Dictionary = EXPECT[race]
			near(p.stats.max_health, e["max_health"], 0.5, "%s max health" % race)
			near(p.stats.max_stamina, e["max_stamina"], 0.5, "%s max stamina" % race)
			near(p.stats.max_magicka, e["max_magicka"], 0.5, "%s max magicka" % race)
			near(p.stats.stamina_regen, e["stamina_regen"], 0.05, "%s stamina regen" % race)
			near(p.stats.magicka_regen, e["magicka_regen"], 0.01, "%s magicka regen" % race)
			near(A.melee_mult(), e["melee"], 0.006, "%s melee multiplier" % race)
			near(A.spell_mult(), e["spell"], 0.006, "%s spell multiplier" % race)
			near(A.reputation_mult(), e["rep"], 0.006, "%s reputation multiplier" % race)
		else:
			ok(p.stats.max_health > 0 and p.stats.max_magicka > 0, "%s pools are set" % race)
		autoload("CharacterMenu").open()
	if f == 5:
		var row: Array = autoload("CharacterMenu").get_node("%AttributeRow").get_children().map(func(l): return l.text)
		if EXPECT.has(race):
			ok(row == EXPECT[race]["row"], "Tab menu attribute row", row)
		else:
			ok(row.size() == 6, "Tab menu shows six attributes", row)
		autoload("CharacterMenu").close()
		saved_str = autoload("Attributes").value("strength")
		autoload("SaveSystem").save_game("quicksave"); autoload("Attributes").increase("strength", 5)
	if f == 8: autoload("SaveSystem").load_game("quicksave")
	if f == 14:
		ok(autoload("Attributes").value("strength") == saved_str, "strength back to the saved value after load",
				autoload("Attributes").value("strength"))
		autoload("SaveSystem").delete_save()
		return done()
	return false
