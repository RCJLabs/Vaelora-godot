extends "res://tests/test_base.gd"
# The Survival skill (systems/bushcraft.gd): cooking meals at a campfire (they
# restore more with skill and leave a buff), foraging plants that grow back,
# making camp from firewood, and in Survival mode needs that rise slower.
var f := 0
var step := 0
var wait := 0
var p
var B
var C
var I
var S
var SV
var fire

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {"survival": true})
	change_scene_to_file("res://levels/test_level.tscn")

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	B = autoload("Bushcraft"); C = autoload("Character"); I = autoload("Inventory"); S = autoload("Skills"); SV = autoload("Survival")
	match step:
		0:
			for i in [1, 2, 3]: current_scene.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			wait = 5
		1:
			ok(S.SKILLS["survival"]["attribute"] == "endurance", "a Survival skill (Endurance)")
			for id in B.RECIPES:
				ok(I.get_item(id) != null and I.get_item(id).cooked, "%s is a cooked dish" % id)
			# Cooking.
			S.levels["survival"] = 15; S.xp["survival"] = 0.0
			I.add("raw_wolf_meat", 2); I.add("red_cap"); I.add("water_flask")
			ok(B.cookable().has("wolf_stew"), "you can cook a stew", B.cookable())
			ok(B.cook("wolf_stew") == 1 and I.count("wolf_stew") == 1 and I.count("red_cap") == 0, "cook a wolf stew")
			ok(S.xp["survival"] > 0.0, "and Survival improves")
			# Eating: more with skill, and a buff.
			p.stats.health = 10.0
			I.use("wolf_stew")
			near(p.stats.health, 45.0, 0.01, "the stew restores 35")
			ok(p.effects.has("well_fed_stew") and is_equal_approx(p.stats.modifier("health_regen"), 1.5), "and you're Well Fed")
			S.levels["survival"] = 55
			near(B.food_mult(I.get_item("cooked_wolf_meat")), 1.2, 0.001, "at 55: cooked food +20%")
			near(B.food_mult(I.get_item("bread")), 1.0, 0.001, "plain bread isn't cooked")
			S.levels["survival"] = 15
			C.perks.append("camp_chef")
			I.add("bread"); I.add("mountain_flower")
			ok(B.cook("herb_bread") == 2, "Camp Chef: two")
			ok(B.cook("cooked_wolf_meat") == 1, "but plain meat stays one")
			C.perks.clear()
			C.perks.append("living_off_the_land")
			ok(not B.sickens(I.get_item("raw_wolf_meat")), "Living off the Land: raw meat won't make you sick")
			C.perks.clear()
			# The campfire menu lists what you can cook.
			I.add("apple"); I.add("river_reed"); I.add("water_flask")
			var camp = current_scene.get_node("Campfire")
			camp.interact(p)
			wait = 2
		2:
			var RM = autoload("RestMenu")
			var labels: Array = RM._buttons.get_children().map(func(b): return b.text)
			ok(labels.has("Cook Apple Tea"), "the campfire offers Apple Tea", labels)
			RM._cook_meal("apple_tea")
			ok(I.count("apple_tea") == 1, "and cooks it")
			RM.close()
			# Foraging.
			var plant = current_scene.get_node("MountainFlowers1")
			var flowers: int = I.count("mountain_flower")
			ok(plant.is_ready() and plant.prompt == "Pick Mountain Flower", "a mountain flower to pick", plant.prompt)
			plant.interact(p)
			ok(I.count("mountain_flower") == flowers + 1 and not plant.is_ready(), "picked, and it's bare")
			ok(plant.prompt == "", "nothing to pick now")
			var W = autoload("WorldClock")
			W.advance(24.0 * 3.0)
			ok(plant.is_ready(), "three days later it's grown back")
			C.perks.append("forager"); C.perks.append("green_thumb")
			plant.interact(p)
			ok(I.count("mountain_flower") == flowers + 1 + 4, "Forager and Green Thumb: (1 + 1) x 2")
			C.perks.append("regrowth")
			W.advance(24.0)
			ok(plant.is_ready(), "Regrowth: a day")
			C.perks.clear()
			ok(plant.get_persist_state().has("picked_at"), "a picked plant is saved")
			# Making camp.
			I.add("firewood", 2)
			var fires: int = get_nodes_in_group("camp_fire").size()
			ok(I.use("firewood"), "two firewood make a fire", B.why_not_camp(p))
			fire = get_nodes_in_group("camp_fire").back() if get_nodes_in_group("camp_fire").size() > fires else null
			ok(fire != null and I.count("firewood") == 0, "there's a fire at your feet")
			ok(fire.is_in_group("heat_source") and SV.sheltered(), "it's warm")
			ok(not I.use("firewood"), "no firewood, no fire")
			W.advance(4.0)
			wait = 2
		3:
			ok(not is_instance_valid(fire) or fire.is_queued_for_deletion(), "it burns out after three hours")
			# Survival mode: needs rise slower with skill and perks.
			S.levels["survival"] = 15; S.xp["survival"] = 0.0   # cooking and picking raised it
			SV.values["hunger"] = 0.0
			SV.tick(10.0, false)
			var base: float = SV.values["hunger"]
			SV.values["hunger"] = 0.0
			S.levels["survival"] = 100
			SV.tick(10.0, false)
			near(SV.values["hunger"], base * 0.75, 0.01, "at 100: hunger rises a quarter slower")
			C.perks.append("iron_stomach")
			SV.values["hunger"] = 0.0
			SV.tick(10.0, false)
			near(SV.values["hunger"], base * 0.75 * 0.75, 0.01, "Iron Stomach: and a quarter more")
			C.perks.append("winter_born")
			SV.values["cold"] = 90.0
			SV.tick(0.01, false)
			ok(SV.values["cold"] < 75.0, "Winter-Born: never Freezing", SV.values["cold"])
			C.perks.clear()
			ok(autoload("Trade").stock("maren").has("firewood"), "Maren sells firewood")
			var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "survival")
			ok(perks.size() >= 20, "20+ Survival perks", perks.size())
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
