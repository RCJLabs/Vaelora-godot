extends "res://tests/test_base.gd"
# Alchemy (systems/alchemy.gd): two or three ingredients that share an effect brew a
# potion of it; how strong (weak / standard / strong) comes from your skill; drinking
# restores or puts a timed effect on you; a poison coats your weapon with venom.
# Ingredients from Maren, the Barrow and skinned wolves; the brewing screen opens from
# a mortar and pestle in the pack.
var f := 0
var step := 0
var wait := 0
var p
var A
var C
var I
var S
var w1

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	A = autoload("Alchemy"); C = autoload("Character"); I = autoload("Inventory"); S = autoload("Skills")
	match step:
		0:
			for i in [1, 2, 3]: current_scene.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			w1 = current_scene.get_node("GreyfangPack/Wolf1")
			wait = 5
		1:
			ok(S.SKILLS["alchemy"]["attribute"] == "intellect", "an Alchemy skill (Intellect)")
			for e in A.EFFECTS:
				for t in 3:
					ok(I.get_item(A.potion_id(e, t)) != null, "%s exists" % A.potion_id(e, t))
			# What brews.
			ok(A.shared_effects(["mountain_flower", "red_cap"]) == ["restore_health"], "flower + red cap: Healing")
			ok(A.shared_effects(["red_cap", "nightshade", "wolf_fang"]) == ["might", "poison"], "red cap + nightshade + fang: Might and Poison",
					A.shared_effects(["red_cap", "nightshade", "wolf_fang"]))
			ok(A.why_not(["mountain_flower", "red_cap"]) != "", "you need them in your pack")
			I.add("mountain_flower", 2); I.add("red_cap", 2); I.add("blue_moss"); I.add("nightshade", 2); I.add("wolf_fang", 2)
			ok(A.why_not(["mountain_flower"]) != "", "one isn't enough")
			ok(A.why_not(["mountain_flower", "blue_moss"]) != "", "nothing in common: sludge")
			S.levels["alchemy"] = 15; S.xp["alchemy"] = 0.0
			var made: Array = A.brew(["mountain_flower", "red_cap"])
			ok(made == ["potion_restore_health_0"] and I.count("potion_restore_health_0") == 1, "a Weak Potion of Healing", made)
			ok(I.count("mountain_flower") == 1 and I.count("red_cap") == 1, "it uses one of each")
			ok(S.xp["alchemy"] > 0.0, "and Alchemy improves", S.xp["alchemy"])
			S.levels["alchemy"] = 40
			made = A.brew(["red_cap", "nightshade", "wolf_fang"])
			ok(made.has("potion_might_1") and made.has("potion_poison_1"), "at 40: standard potions, two at once", made)
			S.levels["alchemy"] = 75
			ok(A.tier() == 2, "at 75: strong")
			S.levels["alchemy"] = 15
			C.perks.append("purity")
			ok(A.tier() == 1, "Purity: a step stronger")
			C.perks.erase("purity")
			C.perks.append("master_brewer")
			I.add("mountain_flower"); I.add("red_cap")
			made = A.brew(["mountain_flower", "red_cap"])
			ok(made.size() == 2, "Master Brewer: two of each", made)
			C.perks.clear()
			# Drinking.
			p.stats.health = 10.0
			ok(I.use("potion_restore_health_0") and is_equal_approx(p.stats.health, 50.0), "a weak Healing potion restores 40", p.stats.health)
			C.perks.append("physician")
			p.stats.health = 10.0
			I.use("potion_restore_health_0")
			near(p.stats.health, 60.0, 0.01, "Physician: +25%")
			C.perks.clear()
			ok(I.use("potion_might_1") and p.effects.has("potion_might"), "Might goes on you")
			near(p.effects.active["potion_might"]["time_left"], 45.0 * 1.6, 0.01, "standard: 72 s")
			near(p.stats.modifier("damage_dealt"), 1.2, 0.001, "your blows do 20% more")
			p.effects.apply("bleeding")
			I.add("potion_cure_0")
			ok(I.use("potion_cure_0") and not p.effects.has("bleeding"), "Cure ends bleeding")
			# Poison: a coat of venom.
			ok(I.use("potion_poison_1") and A.poison_hits_left == 5, "a standard poison coats 5 hits", A.poison_hits_left)
			A.blade_hit(w1)
			ok(w1.effects.stacks("venom") == 2 and A.poison_hits_left == 4, "a hit puts in two doses", [w1.effects.stacks("venom"), A.poison_hits_left])
			wait = 30
		2:
			ok(w1.stats.health < w1.stats.max_health, "the venom bites", w1.stats.health)
			ok(w1.effects.modifier("move_speed") < 1.0, "and slows it")
			# The coat survives a save.
			var d: Dictionary = A.to_dict()
			A.reset()
			A.from_dict(d)
			ok(A.poison_hits_left == 4 and A.poison_doses == 2, "the coat is saved")
			A.reset()
			# Where ingredients come from.
			var stock: Dictionary = autoload("Trade").stock("maren")
			ok(stock.has("mortar_and_pestle") and stock.has("mountain_flower"), "Maren sells the mortar and herbs")
			var price: int = autoload("Trade").buy_price("mountain_flower", "maren")
			C.perks.append("herbwise")
			ok(autoload("Trade").buy_price("mountain_flower", "maren") < price or price <= 1, "Herb-Wise: cheaper herbs")
			C.perks.clear()
			var barrow := FileAccess.get_file_as_string("res://levels/test_dungeon.tscn")
			ok(barrow.contains('item_id = "nightshade"') and barrow.contains('item_id = "grave_dust"'), "nightshade and grave dust in the Barrow")
			ok(FileAccess.get_file_as_string("res://enemies/wolf.gd").contains('Inventory.add("wolf_fang"'), "skinning a wolf gives a fang")
			# The brewing screen.
			I.add("mortar_and_pestle")
			ok(I.use("mortar_and_pestle"), "using the mortar")
			wait = 2
		3:
			var AS = autoload("AlchemyScreen")
			ok(AS.is_open and paused, "opens the brewing screen")
			I.add("river_reed"); I.add("moth_wing")
			ok(AS.ingredients().has("river_reed"), "it lists what you carry", AS.ingredients())
			AS.toggle("river_reed"); AS.toggle("moth_wing")
			var made: Array = AS.brew()
			ok(made.size() == 2 and made.has("potion_swiftness_0") and made.has("potion_cure_0"), "reed + moth wing: Swiftness and Cure", made)
			AS.close()
			ok(not AS.is_open and not paused, "and closes")
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "alchemy")
			ok(perks.size() >= 20, "20+ Alchemy perks", perks.size())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
