extends "res://tests/test_base.gd"
# Runecraft (systems/runecraft.gd): a fire rune on the ground goes off when an
# enemy steps close: damage and burning, and it's spent; frost chills, binding
# holds; three at a time (the oldest goes); Wide Runes reach further; Chain Runes
# set off their neighbours; Living Runes go off twice; Ambusher's Runes double on
# the unaware. A ward-circle cuts the blows you take while you stand in it.
# Enchant Weapon adds 8 to every blow (Lasting Edge: twice as long). It trains
# Runecraft; 20+ perks; Maren sells the tomes.
var f := 0
var step := 0
var wait := 0
var p
var R
var C
var w
var at: Vector3

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func spell(id: String) -> SpellData:
	return load("res://spells/%s.tres" % id)

## A rune `metres` east of the wolf's home; the wolf is put back home, healthy and idle.
func rune(id: String, metres: float = 5.0) -> void:
	w.global_position = w.home
	w.state = w.State.IDLE
	w.stats.health = w.stats.max_health
	w.effects.clear()
	R.cast(spell(id), w.home + Vector3(metres, 0, 0), 1.0, p)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	R = autoload("Runecraft"); C = autoload("Character")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w = n("GreyfangPack/Wolf1")
			p.global_position = w.global_position + Vector3(0, 0.2, 25)
			wait = 5
		1:
			ok(autoload("Skills").SKILLS["runecraft"]["attribute"] == "intellect", "a Runecraft skill (Intellect)")
			for id in ["fire_rune", "frost_rune", "binding_rune", "ward_circle", "enchant_weapon"]:
				ok(("res://spells/%s.tres" % id) in autoload("Spellbook").SPELL_FILES and autoload("Trade").stock("maren").has("tome_" + id), "%s: registered and sold" % id)
			rune("fire_rune")
			ok(R.runes.size() == 1, "a fire rune on the ground")
			set_meta("xp", autoload("Skills").xp["runecraft"])
			wait = 10
		2:
			ok(R.runes.size() == 1 and w.stats.health == w.stats.max_health, "it waits: the wolf is 5 m off")
			w.global_position = R.runes[0]["node"].global_position + Vector3(1.0, 0, 0)   # steps close
			wait = 2
		3:
			near(w.stats.max_health - w.stats.health, 30.0, 0.5, "it goes off: 30")
			ok(w.effects.has("burning") and R.runes.is_empty(), "the wolf burns, and the rune is spent")
			ok(autoload("Skills").xp["runecraft"] > get_meta("xp"), "it trains Runecraft")
			rune("frost_rune", 0.0)
			wait = 2
		4:
			ok(w.effects.has("chilled"), "frost chills")
			rune("binding_rune", 0.0)
			wait = 2
		5:
			ok(w.effects.has("bound") and w.stats.health == w.stats.max_health, "a binding rune holds, and doesn't hurt")
			# Three at a time.
			for i in 4: rune("fire_rune", 8.0 + i * 3.0)
			ok(R.runes.size() == 3, "three at a time: the oldest goes", R.runes.size())
			R.reset()
			# Wide Runes: a wolf 2 m off (west: Wolf2 stands east of it).
			rune("fire_rune", -2.0)
			wait = 2
		6:
			ok(R.runes.size() == 1, "1.6 m to trigger: a wolf 2 m off doesn't")
			C.perks.append("wide_runes")
			wait = 2
		7:
			ok(R.runes.is_empty(), "Wide Runes: it does (2.4 m)")
			C.perks.clear()
			# Chain Runes: two runes 3 m apart, the wolf on one.
			rune("fire_rune", 0.0)
			R.cast(spell("fire_rune"), w.home + Vector3(3, 0, 0), 1.0, p)
			C.perks.append("chain_runes")
			wait = 2
		8:
			ok(R.runes.is_empty(), "Chain Runes: the neighbour goes off too")
			C.perks.clear()
			C.perks.append("living_runes")
			rune("fire_rune", 0.0)
			wait = 2
		9:
			ok(R.runes.size() == 1 and R.runes[0]["rearms"] == 0 and R.runes[0]["wait"] > 0.0, "Living Runes: it draws itself again", R.runes.size())
			C.perks.clear()
			R.reset()
			# Ambusher's Runes on an unaware wolf.
			C.perks.append("ambusher")
			rune("fire_rune", 0.0)
			wait = 2
		10:
			near(w.stats.max_health - w.stats.health, minf(60.0, w.stats.max_health), 0.5, "Ambusher's Runes: x2 on the unaware")
			C.perks.clear()
			R.reset()
			w.stats.health = w.stats.max_health
			w.state = w.State.IDLE
			# The ward-circle.
			R.cast(spell("ward_circle"), p.global_position, 1.0, p)
			wait = 2
		11:
			ok(p.effects.has("rune_ward"), "standing in the ward")
			near(p.stats.modifier("damage_taken"), 0.6, 0.001, "blows do 40% less")
			C.perks.append("steady_ward")
			wait = 2
		12:
			near(p.stats.modifier("damage_taken"), 0.6 * 0.67, 0.001, "Steady Ward: 60% less")
			C.perks.clear()
			p.global_position += Vector3(6, 0, 0)
			wait = 30
		13:
			ok(not p.effects.has("rune_ward"), "step out: it's gone")
			R.reset()
			# Enchant Weapon (on Wolf2: Wolf1 didn't survive the ambush).
			w = n("GreyfangPack/Wolf2")
			var c = p.combat
			c.is_heavy = false; c.is_bash = false; c.current_attack = c.light_attacks[0]
			var S = autoload("Skills")
			var level: int = S.levels[c.weapon_skill]
			w.stats.health = w.stats.max_health
			S.xp[c.weapon_skill] = 0.0
			c._land_hit(w)
			var plain: float = w.stats.max_health - w.stats.health
			p.effects.apply("rune_blade")
			near(p.effects.active["rune_blade"]["time_left"], 60.0, 0.01, "Enchant Weapon: a minute")
			w.stats.health = w.stats.max_health
			S.levels[c.weapon_skill] = level   # (the first blow's XP may have raised it)
			S.xp[c.weapon_skill] = 0.0
			c._land_hit(w)
			near(w.stats.max_health - w.stats.health, plain + 8.0 * w.stats.modifier("damage_taken"), 0.01, "+8 a blow (before the wolf's own damage taken)")
			p.effects.clear()
			C.perks.append("lasting_edge")
			p.effects.apply("rune_blade")
			near(p.effects.active["rune_blade"]["time_left"], 120.0, 0.01, "Lasting Edge: two minutes")
			C.perks.clear()
			p.effects.clear()
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "runecraft")
			ok(perks.size() >= 20, "20+ Runecraft perks", perks.size())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
