extends "res://tests/test_base.gd"
# Smithing (systems/smithing.gd): forging items from recipes at a forge, improving
# what you carry a quality step at a time (Fine at the start, a step more every 25
# levels), and what quality does: weapon damage, armour, shield blocks. Quality
# belongs to the item id and goes with the last copy. The forge near Maren opens
# the screen; a smith's hammer does too with Field Smith.
var f := 0
var step := 0
var wait := 0
var p
var SM
var C
var I
var S

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
	SM = autoload("Smithing"); C = autoload("Character"); I = autoload("Inventory"); S = autoload("Skills")
	match step:
		0:
			for i in [1, 2, 3]: current_scene.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			wait = 5
		1:
			ok(S.SKILLS["smithing"]["attribute"] == "strength", "a Smithing skill (Strength)")
			for id in SM.RECIPES:
				ok(I.get_item(id) != null, "recipe %s makes a real item" % id)
				for material in SM.RECIPES[id]["needs"]:
					ok(I.get_item(material) != null, "%s needs a real %s" % [id, material])
			for id in ["iron_sword", "steel_greatsword", "hunting_bow", "wooden_shield", "iron_cuirass", "leather_cuirass"]:
				ok(SM.MATERIALS.has(I.get_item(id).material), "%s can be improved" % id)
			var stock: Dictionary = autoload("Trade").stock("maren")
			ok(stock.has("iron_ingot") and stock.has("seasoned_wood") and stock.has("smiths_hammer"), "Maren sells ingots, wood and the hammer")
			# Forging.
			S.levels["smithing"] = 15; S.xp["smithing"] = 0.0
			I.add("iron_ingot", 6); I.add("wolf_pelt", 1)
			ok(SM.forge("leather_strip") and I.count("leather_strip") == 3 and I.count("wolf_pelt") == 0, "a pelt makes three strips")
			var swords: int = I.count("iron_sword")
			ok(SM.forge("iron_sword") and I.count("iron_sword") == swords + 1, "forge an iron sword")
			ok(I.count("iron_ingot") == 4 and I.count("leather_strip") == 2, "it used two ingots and a strip")
			ok(S.xp["smithing"] > 0.0, "and Smithing improves")
			ok(SM.why_not_forge("steel_ingot") != "", "steel needs Steel Smithing")
			C.perks.append("thrifty_smith")
			ok(SM.needs("iron_cuirass") == {"iron_ingot": 3, "leather_strip": 2}, "Thrifty Smith: one less ingot", SM.needs("iron_cuirass"))
			C.perks.clear()
			# Improving: Fine at the start, no further.
			I.equip("iron_sword")
			wait = 2
		2:
			var base: float = p.combat.base_damage
			near(base, 15.0, 0.01, "a plain iron sword: 15")
			ok(SM.improve("iron_sword") and SM.quality_of("iron_sword") == 1, "improve it: Fine")
			ok(I.count("iron_ingot") == 3, "it used an ingot")
			ok(SM.display_name("iron_sword") == "Iron Sword (Fine)", "the name says so", SM.display_name("iron_sword"))
			ok(SM.why_not_improve("iron_sword") != "", "at Smithing 15, Fine is as good as it gets")
			S.levels["smithing"] = 50
			ok(SM.max_quality() == 3, "at 50: Exquisite", SM.max_quality())
			ok(SM.improve("iron_sword") and SM.quality_of("iron_sword") == 2, "Superior")
			wait = 2
		3:
			near(p.combat.base_damage, 15.0 * 1.08, 0.01, "two steps: +8% damage")
			C.perks.append("ironwright")
			near(SM.damage_mult(I.get_item("iron_sword")), 1.16, 0.001, "Ironwright: twice that")
			C.perks.append("weaponsmith")
			near(SM.damage_mult(I.get_item("iron_sword")), 1.24, 0.001, "and Weaponsmith: half again")
			C.perks.clear()
			# Armour.
			var cuirass: ItemData = I.get_item("leather_cuirass")
			var before: float = autoload("Armor").piece_armor(cuirass)
			I.add("leather_strip", 1)
			ok(SM.improve("leather_cuirass"), "improve the leather cuirass")
			near(autoload("Armor").piece_armor(cuirass) / before, 1.04, 0.001, "+4% armour")
			C.perks.append("close_fitted")
			ok(autoload("Armor").piece_armor(cuirass) > before * 1.04 + 4.0, "Close-Fitted: +5 more")
			C.perks.clear()
			# A shield blocks more.
			var shield: ItemData = I.get_item("wooden_shield")
			I.add("wooden_shield"); I.add("seasoned_wood", 2)
			SM.improve("wooden_shield"); SM.improve("wooden_shield")
			ok(SM.block_reduction(shield) > shield.block_reduction, "an improved shield blocks more", SM.block_reduction(shield))
			# Quality goes with the last copy.
			I.remove("wooden_shield", I.count("wooden_shield"))
			ok(SM.quality_of("wooden_shield") == 0, "sell the last one and it's forgotten")
			# Saved.
			var d: Dictionary = SM.to_dict()
			SM.reset()
			SM.from_dict(d)
			ok(SM.quality_of("iron_sword") == 2, "quality is saved")
			# Salvage.
			ok(SM.why_not_salvage("iron_mace") != "", "salvage needs the perk")
			C.perks.append("salvage")
			I.add("iron_mace")
			var ingots: int = I.count("iron_ingot")
			ok(SM.salvage("iron_mace") and I.count("iron_ingot") == ingots + 1 and I.count("iron_mace") == 0, "Salvage: a mace gives back an ingot")
			C.perks.clear()
			# Masterwork.
			C.perks.append("masterwork")
			I.add("iron_ingot", 2)
			SM.forge("iron_helmet")
			ok(SM.quality_of("iron_helmet") == 1, "Masterwork: it comes out Fine")
			C.perks.clear()
			# The hammer.
			I.add("smiths_hammer")
			ok(not I.use("smiths_hammer"), "the hammer needs Field Smith")
			C.perks.append("field_smith")
			ok(I.use("smiths_hammer"), "with it, the hammer works")
			wait = 2
		4:
			var SS = autoload("SmithingScreen")
			ok(SS.is_open and not SS.at_forge and SS.mode == "improve", "the hammer opens improving only")
			SS.set_mode("forge")
			SS.select("iron_helmet")
			ok(not SS.act(), "no forging without a forge")
			SS.close()
			C.perks.clear()
			# The forge near Maren.
			var forge: Node = current_scene.get_node_or_null("Forge")
			ok(forge != null and forge.is_in_group("heat_source"), "a forge near Maren, and it's warm")
			forge.interact(p)
			ok(SS.is_open and SS.at_forge and SS.mode == "forge", "it opens the forge")
			I.add("iron_ingot", 2)
			SS.select("iron_boots")
			ok(SS.act() and I.count("iron_boots") >= 1, "forge iron boots at the screen")
			SS.set_mode("improve")
			ok(SS.entries().has("iron_boots"), "and they're there to improve", SS.entries())
			SS.close()
			ok(not SS.is_open and not paused, "and it closes")
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "smithing")
			ok(perks.size() >= 20, "20+ Smithing perks", perks.size())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
