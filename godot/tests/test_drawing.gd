extends "res://tests/test_base.gd"
# Drawing (systems/drawing.gd), the forbidden school: stronger the more corrupted
# you are (+15% a tier); everything it takes stains you. Draw, a stream that takes
# life and gives half back; Siphon Magic, which gives Magicka; Hollowing Touch
# (hollowed, and Health back); the Great Drawing (everything around you). Where
# you learn it: Halina when you're Stained (and the rest at Hollowing), a book in
# the Barrow, and on its own at Hollowing; the mastery at Drawing 75. Nobody sells it.
var f := 0
var step := 0
var wait := 0
var p
var D
var C
var CO
var SB
var w1
var w2

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
	D = autoload("Drawing"); C = autoload("Character"); CO = autoload("Corruption"); SB = autoload("Spellbook")
	match step:
		0:
			w1 = n("GreyfangPack/Wolf1"); w2 = n("GreyfangPack/Wolf2")
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			p.global_position = w1.global_position + Vector3(0, 0.2, 3)
			p.rotation.y = 0.0
			p.head.rotation.x = deg_to_rad(-12)
			wait = 5
		1:
			ok(autoload("Skills").SKILLS["drawing"]["attribute"] == "willpower", "a Drawing skill (Willpower)")
			for id in ["draw", "siphon_magic", "hollowing_touch", "great_drawing"]:
				ok(("res://spells/%s.tres" % id) in SB.SPELL_FILES, "%s exists" % id)
			var stock: Dictionary = autoload("Trade").stock("maren")
			ok(not stock.keys().any(func(k): return k in ["tome_draw", "tome_siphon_magic", "tome_hollowing_touch"]), "nobody sells it")
			ok(FileAccess.get_file_as_string("res://levels/test_dungeon.tscn").contains('item_id = "tome_siphon_magic"'), "a book in the Barrow")
			# Power by corruption.
			near(D.power_mult(), 1.0, 0.001, "clean: plain")
			CO.value = 55.0
			near(D.power_mult(), 1.3, 0.001, "Stained: +30%")
			C.perks.append("embrace_the_stain")
			near(D.power_mult(), 1.6, 0.001, "Embrace the Stain: +60%")
			C.perks.clear()
			CO.value = 0.0
			# What it takes, and what it gives.
			p.stats.health = 50.0
			D.drained(20.0, spell("draw"), p)
			near(p.stats.health, 60.0, 0.01, "Draw: half of what it takes comes back")
			near(CO.value, 1.0, 0.01, "and it stains you (0.05 a point)")
			p.stats.magicka = 0.0
			D.drained(20.0, spell("siphon_magic"), p)
			near(p.stats.magicka, 30.0, 0.01, "Siphon Magic: one and a half Magicka a point")
			C.perks.append("quiet_hunger_1")
			var before: float = CO.value
			D.drained(20.0, spell("draw"), p)
			near(CO.value - before, 0.75, 0.01, "Quiet Hunger: a quarter less stain")
			C.perks.clear()
			CO.value = 0.0
			# The real stream, on a wolf in front of you.
			SB.learn("draw")
			p.magic.spell = spell("draw")
			p.stats.health = 50.0
			p.stats.magicka = 200.0
			var wolf_hp: float = w1.stats.health
			for i in 10: p.magic._channel(0.1)
			ok(w1.stats.health < wolf_hp, "Draw hurts the wolf", [wolf_hp, w1.stats.health])
			near(p.stats.health - 50.0, (wolf_hp - w1.stats.health) * 0.5, 0.5, "and half of it is yours")
			ok(CO.value > 0.0, "and you're stained by it", CO.value)
			p.magic._stop()
			# Hollowing Touch.
			w1.stats.health = w1.stats.max_health
			p.stats.health = 50.0
			before = CO.value
			ok(D.cast(spell("hollowing_touch"), w1.global_position, 1.0, p) == 1, "Hollowing Touch")
			ok(w1.effects.has("hollowed") and is_equal_approx(w1.stats.modifier("move_speed"), 0.6), "the wolf is hollowed")
			near(p.stats.health, 75.0, 0.01, "you take 25 back")
			near(CO.value - before, 2.0, 0.01, "and it stains you 2")
			# The Great Drawing.
			w1.stats.health = w1.stats.max_health; w2.stats.health = w2.stats.max_health
			w1.effects.clear()
			p.stats.health = 20.0
			var got: int = D.cast(spell("great_drawing"), p.global_position, 1.0, p)
			ok(got >= 2, "the Great Drawing takes from every wolf near you", got)
			ok(p.stats.health > 20.0 + 30.0, "and all of it is yours", p.stats.health)
			# Comes to you at Hollowing.
			SB.known.erase("draw")
			CO.value = 75.0
			CO.add(10.0, "test")
			ok(SB.knows("draw"), "at Hollowing, Draw comes on its own")
			# The mastery at Drawing 75.
			var S = autoload("Skills")
			S.levels["drawing"] = 74
			S.raise("drawing")
			ok(SB.knows("great_drawing"), "at Drawing 75, the Great Drawing comes too")
			# Halina.
			CO.value = 55.0
			var GS = autoload("GameState")
			var DM = autoload("DialogueManager")
			DM.start("res://dialogue/halina.json", "Halina")
			var t: Array = DM._choices.map(func(c): return c["text"])
			DM.choose(t.find("You've got grey fingers. So do I."))
			t = DM._choices.map(func(c): return c["text"])
			ok(t.has("Teach me to do what you do.") and not t.has("Teach me the rest."), "Stained: Halina will teach you", t)
			DM.choose(t.find("Teach me to do what you do."))
			ok(autoload("Inventory").count("tome_draw") == 1 and GS.has_flag("halina_taught_draw"), "Halina's Lesson (Draw)")
			DM.end()
			CO.value = 85.0
			DM.start("res://dialogue/halina.json", "Halina")
			t = DM._choices.map(func(c): return c["text"])
			ok(t.has("Teach me the rest."), "Hollowing: the rest", t)
			DM.choose(t.find("Teach me the rest."))
			ok(autoload("Inventory").count("tome_hollowing_touch") == 1, "The Second Lesson (Hollowing Touch)")
			DM.end()
			CO.value = 0.0
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "drawing")
			ok(perks.size() >= 20, "20+ Drawing perks", perks.size())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
