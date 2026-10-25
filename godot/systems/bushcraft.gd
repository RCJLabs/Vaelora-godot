extends Node

# The Survival skill: cooking, foraging, making camp, and (in Survival mode)
# needs that rise slower. Autoloaded as "Bushcraft" ("Survival" is the mode,
# systems/survival.gd). docs/godot-starter/SURVIVAL.md, "The Survival skill".
#
#   Cooking   at a campfire (RestMenu): recipes into meals. Cooked food restores
#             more with skill, and a meal leaves a "well fed" buff.
#   Foraging  plants in the world (props/forage_plant.gd) give ingredients and
#             grow back in a few days.
#   Camp      two firewood from the pack make a campfire wherever you are
#             (props/camp_fire.gd); it burns a few hours.
#   Needs     Survival mode only: hunger, thirst, fatigue and cold rise up to a
#             quarter slower at 100, more with perks.

## What you can cook at a campfire: meal id -> {"needs": {item: n}}.
const RECIPES := {
	"cooked_wolf_meat": {"needs": {"raw_wolf_meat": 1}},
	"hunters_skewer":   {"needs": {"raw_wolf_meat": 1, "mountain_flower": 1}},
	"wolf_stew":        {"needs": {"raw_wolf_meat": 1, "red_cap": 1, "water_flask": 1}},
	"herb_bread":       {"needs": {"bread": 1, "mountain_flower": 1}},
	"apple_tea":        {"needs": {"apple": 1, "river_reed": 1, "water_flask": 1}},
}
const MEAL_DURATION := 300.0    # seconds a meal's buff lasts
const CAMP_FIREWOOD := 2
const CAMP_HOURS := 3.0         # in-game hours a fire you make burns
const RARE_FINDS := ["nightshade", "moth_wing"]
## Survival mode: what each need's rise is multiplied by, per perk key.
const NEED_KEYS := {"hunger": "hunger_rate", "thirst": "thirst_rate", "fatigue": "fatigue_rate", "cold": "cold_rate"}

const CAMP_SCENE := preload("res://props/camp_fire.gd")


func _level() -> int:
	return Skills.levels.get("survival", Skills.START_LEVEL)


# --- needs (Survival mode) ---------------------------------------------------------

## How fast `need` rises: 1.0 at 15, 0.75 at 100, times perks.
func need_mult(need: String) -> float:
	return (1.0 - 0.25 * (_level() - Skills.START_LEVEL) / 85.0) * Character.modifier(NEED_KEYS[need])


## Winter-Born: cold never gets past "cold" to "freezing".
func cold_cap() -> float:
	return 74.9 if "winter_born" in Character.perks else 100.0


## Survival mode XP: a little for every hour you get through.
func hours_survived(hours: float) -> void:
	Skills.add_xp("survival", hours * 0.5)


# --- cooking -----------------------------------------------------------------------

## The recipes you have what you need for, in RECIPES' order.
func cookable() -> Array:
	return RECIPES.keys().filter(func(id): return why_not_cook(id) == "")


func why_not_cook(id: String) -> String:
	if not RECIPES.has(id):
		return "There's no such dish."
	var need: Dictionary = RECIPES[id]["needs"]
	for item in need:
		if Inventory.count(item) < need[item]:
			return "You need %s." % Inventory.get_item(item).display_name
	return ""


## Cooks one (Camp Chef: a meal makes two; plain meat doesn't). Returns how many.
func cook(id: String) -> int:
	if why_not_cook(id) != "":
		return 0
	var need: Dictionary = RECIPES[id]["needs"]
	for item in need:
		Inventory.remove(item, need[item])
	var made := 2 if "camp_chef" in Character.perks and id != "cooked_wolf_meat" else 1
	Inventory.add(id, made)
	Skills.add_xp("survival", 2.0 + Inventory.get_item(id).value / 5.0)
	return made


## Cooked food restores more: +0.5% a level, and Good Cook.
func food_mult(item: ItemData) -> float:
	if not item.cooked:
		return 1.0
	return (1.0 + 0.005 * (_level() - Skills.START_LEVEL)) * Character.modifier("meal_potency")


## Something was eaten (Inventory.use): a meal's buff, Gourmand, and no sickness
## from raw food with Living off the Land.
func ate(item: ItemData, player: Node) -> void:
	if item.meal_effect != "":
		player.effects.apply(item.meal_effect)
		player.effects.active[item.meal_effect]["time_left"] = MEAL_DURATION * (2.0 if "hearty_meals" in Character.perks else 1.0)
	if item.cooked and "gourmand" in Character.perks:
		player.effects.remove("poisoned")
		player.stats.stamina = minf(player.stats.stamina + 20.0, player.stats.max_stamina)


func sickens(item: ItemData) -> bool:
	return item.side_effect != "" and not "living_off_the_land" in Character.perks


# --- foraging ----------------------------------------------------------------------

## What picking a plant of `item_id` gives: Forager +1, Green Thumb (Alchemy) x2,
## Wild Harvest: sometimes something rare as well.
func forage(item_id: String, amount: int) -> Dictionary:
	var n := amount + (1 if "forager" in Character.perks else 0)
	if "green_thumb" in Character.perks:
		n *= 2
	var got := {item_id: n}
	if "wild_harvest" in Character.perks and randf() < 0.25:
		var rare: String = RARE_FINDS[randi() % RARE_FINDS.size()]
		got[rare] = got.get(rare, 0) + 1
	for id in got:
		Inventory.add(id, got[id])
	Skills.add_xp("survival", 1.5)
	return got


## Days a picked plant takes to grow back (Regrowth: one).
func regrow_days(base: int) -> int:
	return 1 if "regrowth" in Character.perks else base


# --- making camp -------------------------------------------------------------------

func why_not_camp(player: Node) -> String:
	if Inventory.count("firewood") < CAMP_FIREWOOD:
		return "You need %d firewood to make a fire." % CAMP_FIREWOOD
	var level := get_tree().current_scene
	if level == null or level.find_child("DayNight", false, false) == null:
		return "Not in here."
	if _ground(player) == null:
		return "There's no ground to build it on."
	return ""


## Where the fire goes: the ground a step and a half in front of you, or null.
func _ground(player: Node3D) -> Variant:
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	var spot := player.global_position + forward.normalized() * 1.5
	var query := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 1.5, spot + Vector3.DOWN * 3.0, 1)
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if hit else null


## Lays a fire at your feet (Inventory.use on firewood). Returns it, or null.
func make_camp(player: Node3D) -> Node3D:
	var reason := why_not_camp(player)
	if reason != "":
		player.hud.notify(reason)
		return null
	Inventory.remove("firewood", CAMP_FIREWOOD)
	var fire: Node3D = CAMP_SCENE.new()
	fire.hours_left = CAMP_HOURS * (2.0 if "firestarter" in Character.perks else 1.0)
	var at: Vector3 = _ground(player)
	get_tree().current_scene.add_child(fire)
	fire.global_position = at
	Skills.add_xp("survival", 3.0)
	player.hud.notify("You make a fire.")
	return fire
