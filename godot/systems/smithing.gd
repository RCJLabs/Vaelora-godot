extends Node

# Smithing: forging weapons and armour, and improving what you have. Autoloaded
# as "Smithing". The screen is ui/smithing_screen.gd: a forge in the world opens
# it (props/forge.gd); with Field Smith, so does a smith's hammer in the pack
# (improving only). docs/godot-starter/SMITHING.md.
#
# Forging: a recipe turns materials (iron and steel ingots, leather strips,
# seasoned wood, wolf pelts) into an item that's already in the game.
# Improving: one of the item's material (ItemData.material) raises its quality a
# step, Fine to Legendary, up to a cap your Smithing level sets. Each step adds
# 4% to a weapon's damage (a shield: blocks and bashes better) or a piece's armour;
# perks for the material double it.
#
# Quality belongs to the item id, not one copy: improve your iron sword and every
# iron sword you carry is Fine. It's forgotten when the last copy leaves your pack
# (Inventory.remove), so you can't sell it and buy it back improved.

const QUALITY_NAMES := ["", "Fine", "Superior", "Exquisite", "Flawless", "Epic", "Legendary"]
const MAX_QUALITY := 6
const PER_STEP := 0.04          # damage / armour per quality step
const LEVELS_PER_STEP := 25     # one more step of cap every 25 levels (1 at the start)
const CLOSE_FITTED := 5.0       # flat armour per improved piece

## What improving each material uses up.
const MATERIALS := {
	"iron": "iron_ingot",
	"steel": "steel_ingot",
	"leather": "leather_strip",
	"wood": "seasoned_wood",
}
## Perks that double what improving a material does.
const MATERIAL_PERKS := {"iron": "ironwright", "steel": "steel_smithing", "leather": "leatherworker", "wood": "bowyer"}

## What you can forge: item id -> {"needs": {material id: n}, "makes": n, "perk": id}.
const RECIPES := {
	"leather_strip":   {"needs": {"wolf_pelt": 1}, "makes": 3},
	"steel_ingot":     {"needs": {"iron_ingot": 2}, "perk": "steel_smithing"},
	"hunting_dagger":  {"needs": {"iron_ingot": 1, "leather_strip": 1}},
	"iron_sword":      {"needs": {"iron_ingot": 2, "leather_strip": 1}},
	"iron_axe":        {"needs": {"iron_ingot": 2, "leather_strip": 1}},
	"iron_mace":       {"needs": {"iron_ingot": 3}},
	"steel_greatsword": {"needs": {"steel_ingot": 3, "leather_strip": 2}, "perk": "steel_smithing"},
	"hunting_bow":     {"needs": {"seasoned_wood": 2, "leather_strip": 1}},
	"arrow":           {"needs": {"seasoned_wood": 1, "iron_ingot": 1}, "makes": 12},
	"wooden_shield":   {"needs": {"seasoned_wood": 2, "iron_ingot": 1}},
	"iron_helmet":     {"needs": {"iron_ingot": 2}},
	"iron_gauntlets":  {"needs": {"iron_ingot": 1, "leather_strip": 1}},
	"iron_boots":      {"needs": {"iron_ingot": 2, "leather_strip": 1}},
	"iron_cuirass":    {"needs": {"iron_ingot": 4, "leather_strip": 2}},
	"leather_cap":     {"needs": {"wolf_pelt": 1, "leather_strip": 1}},
	"leather_gloves":  {"needs": {"wolf_pelt": 1}},
	"leather_boots":   {"needs": {"wolf_pelt": 1, "leather_strip": 1}},
	"leather_cuirass": {"needs": {"wolf_pelt": 2, "leather_strip": 2}},
}

var quality: Dictionary = {}    # item id -> 1..6


# --- quality ---------------------------------------------------------------------

func quality_of(id: String) -> int:
	return quality.get(id, 0)


## The highest quality you can improve `item` to now.
func max_quality(item: ItemData = null) -> int:
	var level: int = Skills.levels.get("smithing", Skills.START_LEVEL)
	var cap := 1 + level / LEVELS_PER_STEP
	for perk in ["master_smith_1", "master_smith_2", "master_smith_3"]:
		if perk in Character.perks:
			cap += 1
	if item and item.material == "steel" and "deep_forged" in Character.perks:
		cap += 1
	return mini(cap, MAX_QUALITY)


## "Iron Sword (Fine)".
func display_name(id: String) -> String:
	var item := Inventory.get_item(id)
	if item == null:
		return id
	var q := quality_of(id)
	return item.display_name if q == 0 else "%s (%s)" % [item.display_name, QUALITY_NAMES[q]]


## What one quality step adds to `item` (0.04, doubled by its material's perk, ...).
func _step(item: ItemData) -> float:
	var step := PER_STEP
	if MATERIAL_PERKS.get(item.material, "") in Character.perks:
		step *= 2.0
	if item.type == ItemData.Type.ARMOR:
		step *= 1.5 if "armourer" in Character.perks else 1.0
	else:
		step *= 1.5 if "weaponsmith" in Character.perks else 1.0
	if "legendary_touch" in Character.perks:
		step *= 1.25
	return step


## A weapon's (or a shield bash's) damage multiplier.
func damage_mult(item: ItemData) -> float:
	return 1.0 + quality_of(item.id) * _step(item) if item else 1.0


## A piece of armour: multiplier, and Close-Fitted's flat bonus.
func armor_mult(item: ItemData) -> float:
	return 1.0 + quality_of(item.id) * _step(item)


func armor_bonus(item: ItemData) -> float:
	return CLOSE_FITTED if quality_of(item.id) > 0 and "close_fitted" in Character.perks else 0.0


## A shield blocks more: what gets through is divided by its multiplier.
func block_reduction(item: ItemData) -> float:
	return 1.0 - (1.0 - item.block_reduction) / damage_mult(item)


## Balanced Blades: an improved weapon's attacks cost less.
func stamina_mult(item: ItemData) -> float:
	return 0.85 if item and quality_of(item.id) > 0 and "balanced_blades" in Character.perks else 1.0


## Heavy Hand: an improved weapon staggers more.
func poise_mult(item: ItemData) -> float:
	return 1.25 if item and quality_of(item.id) > 0 and "heavy_hand" in Character.perks else 1.0


# --- improving -------------------------------------------------------------------

## Why `id` can't be improved now, or "".
func why_not_improve(id: String) -> String:
	var item := Inventory.get_item(id)
	if item == null or Inventory.count(id) <= 0:
		return "You don't have it."
	if not MATERIALS.has(item.material):
		return "That can't be improved."
	var q := quality_of(id)
	if q >= MAX_QUALITY:
		return "It can't be any better."
	if q >= max_quality(item):
		return "That's as good as you can make it at your skill."
	var material: String = MATERIALS[item.material]
	if item.material == "steel" and not "steel_smithing" in Character.perks:
		return "You need Steel Smithing to work steel."
	if Inventory.count(material) <= 0:
		return "You need %s." % Inventory.get_item(material).display_name
	return ""


## One step better; uses one of its material (Careful Hands: maybe not).
func improve(id: String) -> bool:
	if why_not_improve(id) != "":
		return false
	var item := Inventory.get_item(id)
	if not ("careful_hands" in Character.perks and randf() < 0.25):
		Inventory.remove(MATERIALS[item.material])
	quality[id] = quality_of(id) + 1
	Skills.add_xp("smithing", 3.0 + item.value / 20.0)
	Inventory.equipment_changed.emit()   # an equipped weapon picks up its new damage
	Inventory.changed.emit()
	return true


# --- forging ---------------------------------------------------------------------

## What forging `id` uses, after Thrifty Smith (one less of the most-used material).
func needs(id: String) -> Dictionary:
	var out: Dictionary = RECIPES[id]["needs"].duplicate()
	if "thrifty_smith" in Character.perks:
		var most := ""
		for material in out:
			if most == "" or out[material] > out[most]:
				most = material
		if out[most] > 1:
			out[most] -= 1
	return out


func makes(id: String) -> int:
	var n: int = RECIPES[id].get("makes", 1)
	return n * 2 if id == "arrow" and "arrowsmith" in Character.perks else n


func why_not_forge(id: String) -> String:
	if not RECIPES.has(id):
		return "There's no way to make that."
	var perk: String = RECIPES[id].get("perk", "")
	if perk != "" and not perk in Character.perks:
		return "You need %s." % Character.perk_list[perk]["name"]
	var need := needs(id)
	for material in need:
		if Inventory.count(material) < need[material]:
			return "Not enough %s." % Inventory.get_item(material).display_name
	return ""


## Makes it. Masterwork: what you forge comes out at least Fine.
func forge(id: String) -> bool:
	if why_not_forge(id) != "":
		return false
	var need := needs(id)
	for material in need:
		Inventory.remove(material, need[material])
	Inventory.add(id, makes(id))
	var item := Inventory.get_item(id)
	if "masterwork" in Character.perks and MATERIALS.has(item.material) and quality_of(id) == 0:
		quality[id] = 1
	Skills.add_xp("smithing", 2.0 + item.value * makes(id) / 10.0)
	return true


# --- salvage ---------------------------------------------------------------------

## Salvage (perk): break one down for half its materials (at least one of the main one).
func salvage_yield(id: String) -> Dictionary:
	if not RECIPES.has(id) or RECIPES[id].get("makes", 1) > 1:
		return {}
	var out := {}
	var need: Dictionary = RECIPES[id]["needs"]
	for material in need:
		if need[material] / 2 > 0:
			out[material] = need[material] / 2
	if out.is_empty():
		out[need.keys()[0]] = 1
	return out


func why_not_salvage(id: String) -> String:
	if not "salvage" in Character.perks:
		return "You need Salvage."
	if salvage_yield(id).is_empty():
		return "There's nothing to get back from that."
	if Inventory.count(id) <= 0:
		return "You don't have it."
	if Inventory.is_equipped(id) and Inventory.count(id) == 1:
		return "Take it off first."
	return ""


func salvage(id: String) -> bool:
	if why_not_salvage(id) != "":
		return false
	var back := salvage_yield(id)
	Inventory.remove(id)
	for material in back:
		Inventory.add(material, back[material])
	Skills.add_xp("smithing", 1.0)
	return true


# --- saving ----------------------------------------------------------------------

## The last copy left your pack (Inventory.remove).
func forget(id: String) -> void:
	quality.erase(id)


func reset() -> void:
	quality = {}


func to_dict() -> Dictionary:
	return {"quality": quality.duplicate()}


func from_dict(data: Dictionary) -> void:
	quality = {}
	var saved: Dictionary = data.get("quality", {})
	for id in saved:
		quality[id] = int(saved[id])
