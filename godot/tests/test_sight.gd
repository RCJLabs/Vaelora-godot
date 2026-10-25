extends "res://tests/test_base.gd"
# Sight (systems/sight.gd): Weak Point marks a wolf (+50% damage; Exposed: x2;
# Lasting Mark: longer; Marked for Death: a kill while marked heals). Ill Fortune
# curses it: some of its blows at you go astray (Spreading Misfortune: its pack
# too). Foresight widens the parry and dodge windows (Long Foresight: longer;
# Counterseer: parries give Magicka). True Sight marks enemies through walls
# (Hunter's Eye: with their health). Moment of Clarity: nothing lands, blows x2.
var f := 0
var step := 0
var wait := 0
var p
var SG
var C
var w1
var w2
var w3

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func spell(id: String) -> SpellData:
	return load("res://spells/%s.tres" % id)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	SG = autoload("Sight"); C = autoload("Character")
	match step:
		0:
			w1 = n("GreyfangPack/Wolf1"); w2 = n("GreyfangPack/Wolf2"); w3 = n("GreyfangPack/Wolf3")
			for w in [w1, w2, w3]: w.set_physics_process(false)
			p.global_position = w1.global_position + Vector3(0, 0.2, 12)
			wait = 5
		1:
			ok(autoload("Skills").SKILLS["sight"]["attribute"] == "presence", "a Sight skill (Presence)")
			for id in ["weak_point", "ill_fortune", "foresight", "true_sight", "moment_of_clarity"]:
				ok(("res://spells/%s.tres" % id) in autoload("Spellbook").SPELL_FILES and autoload("Trade").stock("maren").has("tome_" + id), "%s: registered and sold" % id)
			# Weak Point.
			var before: float = w1.stats.health
			w1.stats.take_damage(10.0)
			var plain: float = before - w1.stats.health
			ok(SG.cast(spell("weak_point"), w1.global_position, 1.0, p) == 1 and w1.effects.has("weak_point"), "Weak Point marks the wolf")
			w1.stats.health = w1.stats.max_health
			before = w1.stats.health
			w1.stats.take_damage(10.0)
			near(before - w1.stats.health, plain * 1.5, 0.01, "+50% damage")
			w1.effects.clear()
			C.perks.append("exposed"); C.perks.append("lasting_mark")
			SG.cast(spell("weak_point"), w1.global_position, 1.0, p)
			w1.stats.health = w1.stats.max_health
			before = w1.stats.health
			w1.stats.take_damage(10.0)
			near(before - w1.stats.health, plain * 1.5 * 1.33, 0.01, "Exposed: about double")
			ok(w1.effects.active["weak_point"]["time_left"] > 10.0 * 1.9, "Lasting Mark: twice as long", w1.effects.active["weak_point"]["time_left"])
			# Marked for Death.
			C.perks.append("marked_for_death")
			SG.cast(spell("weak_point"), w1.global_position, 1.0, p)
			p.stats.health = 50.0
			w1.stats.take_damage(10000.0, true)
			ok(is_equal_approx(p.stats.health, 75.0), "Marked for Death: killing it heals 25", p.stats.health)
			C.perks.clear()
			p.stats.health = p.stats.max_health
			# Ill Fortune.
			ok(SG.cast(spell("ill_fortune"), w2.global_position, 1.0, p) == 1 and w2.effects.has("ill_fortune"), "Ill Fortune curses a wolf")
			var missed := 0
			for i in 300:
				if SG.blow_misses(w2, p): missed += 1
			ok(missed > 60 and missed < 140, "about a third of its blows go astray", missed)
			var plain_misses := 0
			for i in 300:
				if SG.blow_misses(w3, p): plain_misses += 1
			ok(plain_misses == 0, "an uncursed wolf never misses for it", plain_misses)
			C.perks.append("spreading_misfortune")
			w2.effects.clear()
			w3.global_position = w2.global_position + Vector3(1.5, 0, 0)
			ok(SG.cast(spell("ill_fortune"), w2.global_position, 1.0, p) == 2 and w3.effects.has("ill_fortune"), "Spreading Misfortune: the one beside it too")
			C.perks.clear()
			# Foresight.
			p.effects.apply("foresight")
			near(p.stats.modifier("parry_window"), 3.0, 0.001, "Foresight: parry window x3")
			near(p.stats.modifier("dodge_iframes"), 2.0, 0.001, "and dodges untouchable twice as long")
			p.effects.clear()
			C.perks.append("long_foresight_1")
			p.effects.apply("foresight")
			near(p.effects.active["foresight"]["time_left"], 12.0, 0.01, "Long Foresight: 12 s")
			C.perks.append("counterseer")
			p.stats.magicka = 10.0
			p.combat._parried()
			ok(is_equal_approx(p.stats.magicka, 30.0), "Counterseer: a parry gives 20 Magicka", p.stats.magicka)
			C.perks.clear()
			p.effects.clear()
			# True Sight.
			p.effects.apply("true_sight")
			wait = 2
		2:
			ok(SG.is_marked_by_true_sight(w2) and SG.is_marked_by_true_sight(w3), "True Sight marks the wolves")
			ok(not SG.is_marked_by_true_sight(w1), "but not the dead one")
			var mark: Label3D = w2.get_node("TrueSightMark")
			ok(mark.no_depth_test, "through walls")
			C.perks.append("hunters_eye")
			wait = 2
		3:
			ok(w2.get_node("TrueSightMark").text.ends_with("%"), "Hunter's Eye: with its health", w2.get_node("TrueSightMark").text)
			C.perks.clear()
			p.effects.clear()
			wait = 2
		4:
			ok(not SG.is_marked_by_true_sight(w2), "the marks go when it ends")
			# Moment of Clarity.
			p.effects.apply("moment_of_clarity")
			var hp: float = p.stats.health
			ok(p.receive_attack(20.0, w2, 0.0) == "dodged" and p.stats.health == hp, "Moment of Clarity: nothing lands")
			near(SG.damage_mult(p), 2.0, 0.001, "and your blows do double")
			p.effects.clear()
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "sight")
			ok(perks.size() >= 20, "20+ Sight perks", perks.size())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
