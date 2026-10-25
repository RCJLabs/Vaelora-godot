extends "res://tests/test_base.gd"
# Classes (systems/classes.gd): chosen at creation, a class's five skills learn
# 20% faster, it's saved, and it can be changed after Aurel's rite (ClassScreen).
# Then each of the twelve class powers (R), one class at a time.
var f := 0
var step := 0
var wait := 0
var p
var C
var CL
var w1
var w3

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {}, "warrior")
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func face_wolf() -> void:
	p.global_position = w1.global_position + Vector3(0, 0.2, 1.4)
	p.rotation.y = 0.0
	p.head.rotation.x = deg_to_rad(-25)
	w1.stats.max_health = 1000.0; w1.stats.health = 1000.0
	w1.effects.clear()
	w3.global_position = w1.global_position + Vector3(20, 0, 0)
	n("GreyfangPack/Wolf2").global_position = w1.global_position + Vector3(-20, 0, 0)   # nothing else to aim at

## Become `id` and use its power. Returns whether it went off.
func power(id: String) -> bool:
	C.class_id = id
	C.cooldowns.clear()
	return C.use_power(2)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	C = autoload("Character"); CL = autoload("Classes")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w1 = n("GreyfangPack/Wolf1"); w3 = n("GreyfangPack/Wolf3")
			ok(CL.classes.size() == 12, "twelve classes", CL.classes.size())
			var covered := {}
			for id in CL.classes:
				ok(CL.skills_of(id).size() == 5, "%s has five skills" % id)
				ok(C.ability_list.has(CL.classes[id]["ability"]), "%s's power exists" % id)
				for s in CL.skills_of(id):
					ok(autoload("Skills").SKILLS.has(s), "%s: %s is a skill" % [id, s])
					covered[s] = true
			ok(covered.size() == autoload("Skills").SKILLS.size(), "together they cover every skill", covered.size())
			ok(C.class_id == "warrior" and C.powers()[2] == "war_cry", "created a Warrior: War Cry is the third power", C.powers())
			near(p.stats.modifier("skill_xp_one_handed"), 1.2, 0.001, "One-Handed (a Warrior skill) learns 20% faster")
			near(p.stats.modifier("skill_xp_archery"), 1.0, 0.001, "Archery doesn't")
			var saved: Dictionary = C.to_dict()
			ok(saved["class"] == "warrior", "the class is saved")
			saved["class"] = "nonsense"; C.from_dict(saved)
			ok(C.class_id == "", "an unknown class loads as none")
			saved["class"] = "warrior"; C.from_dict(saved)
			ok(InputMap.has_action("power_class"), "a Class power key")
			face_wolf()
			w1.global_position = p.global_position + Vector3(0, 0, -3)
			w3.global_position = p.global_position + Vector3(15, 0, 0)
			ok(power("warrior") and w1.is_staggered() and not w3.is_staggered(), "War Cry: the wolf 3 m away reels, the one 15 m away doesn't")
			ok(C.cooldowns.has("war_cry") and not C.use_power(2), "and then it waits")
			wait = 90
		1:
			face_wolf()
			p.global_position = w1.global_position + Vector3(0, 0.2, 6.0)   # (the aim cone is 12°: from a few steps back)
			p.head.rotation.x = deg_to_rad(-9)
			ok(power("ranger") and w1.effects.has("hunters_mark"), "Hunter's Mark on the wolf you aim at")
			near(w1.stats.modifier("damage_taken"), 1.3, 0.001, "it takes 30% more")
			p.rotation.y = PI   # aiming away
			ok(not power("ranger") and not C.cooldowns.has("hunters_mark"), "nothing aimed at: no mark, no cooldown")
			ok(power("thief") and p.effects.has("invisible") and p.effects.active["invisible"]["time_left"] <= 8.0, "Vanish: unseen, for 8 s")
			p.effects.remove("invisible")
			ok(power("mage") and is_equal_approx(p.stats.modifier("spell_cost"), 0.0), "Arcane Surge: spells cost nothing")
			p.effects.remove("arcane_surge")
			# Spellsword: Quickened Blade.
			autoload("Inventory").equip("iron_sword")
			autoload("Spellbook").learn("firebolt"); autoload("Spellbook").select("firebolt")
			p.stats.magicka = 50.0
			ok(power("spellsword") and autoload("Spellblade").active(), "Quickened Blade: Firebolt in the blade at once")
			near(p.stats.magicka, 50.0, 0.01, "for no Magicka")
			autoload("Spellblade").reset()
			autoload("Inventory").unequip("main_hand")
			ok(not power("spellsword"), "not with bare hands")
			# Nightblade: Shadow Feast.
			ok(power("nightblade") and p.effects.has("shadow_feast"), "Shadow Feast")
			p.stats.health = 20.0
			CL.sneak_attack_landed(30.0, p)
			near(p.stats.health, 35.0, 0.01, "a sneak attack for 30 heals 15")
			# Tide-Warden: Moon's Favour.
			ok(power("tide_warden") and is_equal_approx(autoload("WorldClock").tide(), 1.0), "Moon's Favour: the tide is high")
			CL.moon_favour_left = 0.0
			# Battlemage: Storm Mantle.
			face_wolf()
			ok(power("battlemage") and p.effects.has("storm_mantle"), "Storm Mantle")
			wait = 60
		2:
			ok(w1.stats.health < 1000.0 and w1.stats.health > 980.0, "the wolf beside you takes about 8 a second", w1.stats.health)
			p.effects.remove("storm_mantle")
			var before: int = autoload("Binding").max_summons()
			ok(power("binder") and autoload("Binding").max_summons() == before + 1, "Call the Host: one more bound creature")
			p.effects.remove("call_the_host")
			p.stats.health = 10.0; p.stats.stamina = 0.0
			ok(power("wayfarer"), "Second Breath")
			near(p.stats.health, 10.0 + p.stats.max_health * 0.5, 0.5, "half your Health back")
			near(p.stats.stamina, p.stats.max_stamina * 0.5, 0.5, "and half your Stamina")
			var ally: float = autoload("Command").damage_mult()
			ok(power("herald"), "Rally")
			near(autoload("Command").damage_mult() / ally, 1.25, 0.001, "companions hit 25% harder")
			near(p.stats.modifier("damage_dealt"), 1.25, 0.001, "and so do you")
			p.effects.remove("rally")
			p.stats.health = 100.0; p.stats.magicka = 0.0
			ok(power("hedge_witch"), "Old Bargain")
			ok(is_equal_approx(p.stats.health, 70.0) and is_equal_approx(p.stats.magicka, 60.0), "30 Health for 60 Magicka", [p.stats.health, p.stats.magicka])
			p.stats.health = 20.0
			ok(not power("hedge_witch") and is_equal_approx(p.stats.health, 20.0), "not when it would kill you")
			# Changing class after the rite.
			C.class_id = "warrior"
			var aurel: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://dialogue/aurel.json"))
			ok(aurel["nodes"]["unlearned"]["choices"].any(func(c): return c.get("open_class_screen", false)), "after the rite, Aurel offers a new class")
			autoload("ClassScreen").open()
			wait = 5
		3:
			var CS = autoload("ClassScreen")
			ok(CS.is_open and paused, "the class screen is up, the game paused")
			ok(CS.picked == "warrior" and CS._take.disabled, "it starts on your class")
			CS.pick("ranger")
			CS.take()
			ok(C.class_id == "ranger" and not CS.is_open and not paused, "Take this road: a Ranger now")
			near(p.stats.modifier("skill_xp_archery"), 1.2, 0.001, "Archery learns faster now")
			near(p.stats.modifier("skill_xp_one_handed"), 1.0, 0.001, "and One-Handed no longer")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
