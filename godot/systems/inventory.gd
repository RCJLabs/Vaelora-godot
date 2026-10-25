extends Node

# The player's items, gold and equipped gear. Autoloaded as "Inventory".
#   Inventory.add("wolf_pelt")           Inventory.remove("wolf_pelt", 2)
#   Inventory.count("wolf_pelt")         Inventory.add_gold(10)
#   Inventory.use("minor_healing_potion")
#   Inventory.equip("iron_sword")        Inventory.equipped_item("main_hand")
# Equipped items stay in the inventory (like Skyrim); removing the last one
# unequips it.

signal changed
signal item_added(item: ItemData, amount: int)
signal gold_added(amount: int)
signal equipment_changed

## Every item in the game. Add new item files here.
const ITEM_FILES := [
	"res://items/wolf_pelt.tres",
	"res://items/minor_healing_potion.tres",
	"res://items/rune_shard.tres",
	"res://items/charcoal_rubbing.tres",
	"res://items/posting_orders.tres",
	"res://items/collegium_letter.tres",
	"res://items/wanted_notice.tres",
	"res://items/wagon_manifest.tres",
	"res://items/marked_coin.tres",
	"res://items/supply_crate.tres",
	"res://items/cult_notes.tres",
	"res://items/book_hallam.tres",
	"res://items/book_charter.tres",
	"res://items/book_dimming.tres",
	"res://items/book_lantern.tres",
	"res://items/book_lullaby.tres",
	"res://items/book_riverwatch_roll.tres",
	"res://items/book_ilse_notebook.tres",
	"res://items/cult_letter.tres",
	"res://items/strongbox.tres",
	"res://items/rune_glass.tres",
	"res://items/iron_sword.tres",
	"res://items/hunting_dagger.tres",
	"res://items/leather_cuirass.tres",
	"res://items/leather_boots.tres",
	"res://items/mountain_flower.tres",
	"res://items/red_cap.tres",
	"res://items/blue_moss.tres",
	"res://items/nightshade.tres",
	"res://items/wolf_fang.tres",
	"res://items/river_reed.tres",
	"res://items/grave_dust.tres",
	"res://items/moth_wing.tres",
	"res://items/potion_restore_health_0.tres",
	"res://items/potion_restore_health_1.tres",
	"res://items/potion_restore_health_2.tres",
	"res://items/potion_restore_stamina_0.tres",
	"res://items/potion_restore_stamina_1.tres",
	"res://items/potion_restore_stamina_2.tres",
	"res://items/potion_restore_magicka_0.tres",
	"res://items/potion_restore_magicka_1.tres",
	"res://items/potion_restore_magicka_2.tres",
	"res://items/potion_regeneration_0.tres",
	"res://items/potion_regeneration_1.tres",
	"res://items/potion_regeneration_2.tres",
	"res://items/potion_swiftness_0.tres",
	"res://items/potion_swiftness_1.tres",
	"res://items/potion_swiftness_2.tres",
	"res://items/potion_might_0.tres",
	"res://items/potion_might_1.tres",
	"res://items/potion_might_2.tres",
	"res://items/potion_resist_0.tres",
	"res://items/potion_resist_1.tres",
	"res://items/potion_resist_2.tres",
	"res://items/potion_cure_0.tres",
	"res://items/potion_cure_1.tres",
	"res://items/potion_cure_2.tres",
	"res://items/potion_poison_0.tres",
	"res://items/potion_poison_1.tres",
	"res://items/potion_poison_2.tres",
	"res://items/mortar_and_pestle.tres",
	"res://items/iron_ingot.tres",
	"res://items/steel_ingot.tres",
	"res://items/leather_strip.tres",
	"res://items/seasoned_wood.tres",
	"res://items/smiths_hammer.tres",
	"res://items/lockpick.tres",
	"res://items/hunters_skewer.tres",
	"res://items/wolf_stew.tres",
	"res://items/herb_bread.tres",
	"res://items/apple_tea.tres",
	"res://items/firewood.tres",
	"res://items/leather_cap.tres",
	"res://items/leather_gloves.tres",
	"res://items/iron_cuirass.tres",
	"res://items/iron_gauntlets.tres",
	"res://items/iron_boots.tres",
	"res://items/iron_helmet.tres",
	"res://items/iron_axe.tres",
	"res://items/iron_mace.tres",
	"res://items/steel_greatsword.tres",
	"res://items/wooden_shield.tres",
	"res://items/hunting_bow.tres",
	"res://items/arrow.tres",
	"res://items/tome_firebolt.tres",
	"res://items/tome_frost_burst.tres",
	"res://items/tome_healing_ward.tres",
	"res://items/tome_mending.tres",
	"res://items/tome_stoneflesh.tres",
	"res://items/tome_draw.tres",
	"res://items/tome_siphon_magic.tres",
	"res://items/tome_hollowing_touch.tres",
	"res://items/tome_weak_point.tres",
	"res://items/tome_ill_fortune.tres",
	"res://items/tome_foresight.tres",
	"res://items/tome_true_sight.tres",
	"res://items/tome_moment_of_clarity.tres",
	"res://items/tome_fire_rune.tres",
	"res://items/tome_frost_rune.tres",
	"res://items/tome_binding_rune.tres",
	"res://items/tome_ward_circle.tres",
	"res://items/tome_enchant_weapon.tres",
	"res://items/tome_call_wolf.tres",
	"res://items/tome_bind.tres",
	"res://items/tome_summon_guardian.tres",
	"res://items/tome_raise_dead.tres",
	"res://items/tome_candlelight.tres",
	"res://items/tome_mirror_image.tres",
	"res://items/tome_fear.tres",
	"res://items/tome_charm.tres",
	"res://items/tome_frenzy.tres",
	"res://items/tome_invisibility.tres",
	"res://items/tome_pull.tres",
	"res://items/tome_tides_shove.tres",
	"res://items/tome_gravity_well.tres",
	"res://items/tome_moon_crush.tres",
	"res://items/tome_lifting_tide.tres",
	"res://items/book_swordsmans_rest.tres",
	"res://items/book_tide_table.tres",
	"res://items/bread.tres",
	"res://items/lantern_cake.tres",
	"res://items/apple.tres",
	"res://items/water_flask.tres",
	"res://items/raw_wolf_meat.tres",
	"res://items/cooked_wolf_meat.tres",
	"res://items/wisp_essence.tres",
	"res://items/guardian_heart.tres",
]

## What every new character starts with (equipped). Backgrounds will change this.
const STARTING_GEAR := ["iron_sword", "leather_cuirass", "leather_boots"]

var items: Dictionary = {}   # item id -> how many
var gold: int = 0
var equipped: Dictionary = {}   # slot name -> item id

var _catalog: Dictionary = {}   # item id -> ItemData


func _ready() -> void:
	for path in ITEM_FILES:
		var item: ItemData = load(path)
		_catalog[item.id] = item
	give_starting_gear()   # so levels run on their own (F6) armed


func get_item(id: String) -> ItemData:
	if not _catalog.has(id):
		push_error("Inventory: unknown item id '%s'. Is it listed in ITEM_FILES?" % id)
	return _catalog.get(id)


func add(id: String, amount: int = 1) -> void:
	var item := get_item(id)
	if item == null or amount <= 0:
		return
	items[id] = items.get(id, 0) + amount
	item_added.emit(item, amount)
	changed.emit()


## Returns false (and removes nothing) if there aren't enough.
func remove(id: String, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	items[id] -= amount
	if items[id] == 1 and equipped.get("main_hand", "") == id and equipped.get("off_hand", "") == id:
		unequip("off_hand")   # one left: it can't be in both hands
	if items[id] == 0:
		items.erase(id)
		Smithing.forget(id)   # an improved item's quality goes with the last copy
		for slot in equipped.keys():
			if equipped[slot] == id:
				unequip(slot)
	changed.emit()
	return true


## What everything you carry weighs (equipped things included).
## What you carry, for carry weight (worn armour weighs nothing with Unhindered / Conditioning).
func total_weight() -> float:
	var total := 0.0
	for id in items:
		var item := get_item(id)
		if item:
			total += item.weight * items[id]
	return total - Armor.weightless()


func count(id: String) -> int:
	return items.get(id, 0)


func add_gold(amount: int) -> void:
	gold += amount
	gold_added.emit(amount)
	changed.emit()


## Uses a consumable on the player. Returns false if it can't be used.
func use(id: String) -> bool:
	var item := get_item(id)
	var player := get_tree().get_first_node_in_group("player")
	if item != null and item.is_readable() and count(id) > 0:
		var first_time := not GameState.has_flag("read_" + id)   # BookReader sets it on opening
		BookReader.open(id)   # books are read, not used up
		if item.teaches_a_skill() and first_time:
			Skills.raise(item.teaches_skill)   # a skill book: the first reading teaches you something
		return true
	if item != null and item.tool == "alchemy" and count(id) > 0:
		AlchemyScreen.open.call_deferred()   # a mortar and pestle: brew, wherever you are
		return true
	if item != null and item.tool == "smithing" and count(id) > 0:
		if not "field_smith" in Character.perks:
			if player:
				player.hud.notify("You need a forge. (Field Smith lets you improve things anywhere.)")
			return false
		SmithingScreen.open.call_deferred(false)   # a smith's hammer: improve, wherever you are
		return true
	if item != null and item.tool == "camp" and player != null:
		return Bushcraft.make_camp(player) != null   # firewood: a fire where you stand
	if item == null or item.type != ItemData.Type.CONSUMABLE or player == null or count(id) == 0:
		return false
	if item.potion_effect != "":
		if Alchemy.drink(item, player):
			remove(id)
			return true
	if item.teaches_spell != "":
		if Spellbook.knows(item.teaches_spell):
			player.hud.notify("You already know %s" % Spellbook.get_spell(item.teaches_spell).display_name)
			return false
		Spellbook.learn(item.teaches_spell)
		remove(id)
		return true
	var stats: Stats = player.stats
	Survival.ease(item)
	if Bushcraft.sickens(item) and randf() < item.side_effect_chance:
		player.effects.apply(item.side_effect)
	if item.corruption > 0.0:
		Corruption.add(item.corruption, item.display_name)
	var food := Bushcraft.food_mult(item)   # cooked food: more with Survival
	stats.heal(item.restore_health * food)
	stats.stamina = minf(stats.stamina + item.restore_stamina * food, stats.max_stamina)
	stats.magicka = minf(stats.magicka + item.restore_magicka * food, stats.max_magicka)
	Bushcraft.ate(item, player)
	stats.changed.emit()
	remove(id)
	return true


# --- equipment ----------------------------------------------------------------------

func equip(id: String) -> bool:
	var item := get_item(id)
	if item == null or not item.is_equipment() or count(id) == 0:
		return false
	# Two-handed weapons and shields can't be used together.
	if item.slot_name() == "main_hand" and item.two_handed:
		equipped.erase("off_hand")
	elif item.slot_name() == "off_hand" and equipped_item("main_hand") and equipped_item("main_hand").two_handed:
		equipped.erase("main_hand")
	equipped[item.slot_name()] = id
	if item.slot_name() == "main_hand" and equipped.get("off_hand", "") == id and count(id) < 2:
		equipped.erase("off_hand")   # one of it can't be in both hands
	equipment_changed.emit()
	changed.emit()
	return true


## Why `id` can't go in the left hand (dual-wielding), or "".
func why_not_off_hand(id: String) -> String:
	var item := get_item(id)
	if item == null or item.type != ItemData.Type.WEAPON or item.weapon_kind != ItemData.WeaponKind.MELEE or item.two_handed:
		return "Only a one-handed weapon goes in the off hand."
	if count(id) == 0:
		return "You don't have it."
	if equipped.get("main_hand", "") == id and count(id) < 2:
		return "You'd need two of them."
	return ""


## A one-handed weapon in the left hand, for dual-wielding (a two-handed one in
## the right comes off).
func equip_off_hand(id: String) -> bool:
	if why_not_off_hand(id) != "":
		return false
	var main := equipped_item("main_hand")
	if main and main.two_handed:
		equipped.erase("main_hand")
	equipped["off_hand"] = id
	equipment_changed.emit()
	changed.emit()
	return true


func unequip(slot: String) -> void:
	if equipped.erase(slot):
		equipment_changed.emit()
		changed.emit()


func is_equipped(id: String) -> bool:
	return id in equipped.values()


func equipped_item(slot: String) -> ItemData:
	return get_item(equipped[slot]) if equipped.has(slot) else null


## Your armour rating: worn pieces, raised by Light / Heavy Armour (systems/armor.gd).
func armor_total() -> float:
	return Armor.rating()


func give_starting_gear() -> void:
	for id in STARTING_GEAR:
		if count(id) == 0:
			items[id] = 1
		equip(id)


func reset() -> void:
	items = {}
	gold = 0
	equipped = {}
	equipment_changed.emit()
	changed.emit()


func to_dict() -> Dictionary:
	return {"items": items, "gold": gold, "equipped": equipped}


func from_dict(data: Dictionary) -> void:
	items = {}
	for id in data["items"]:
		if _catalog.has(id):   # skip items removed from the game since the save
			items[id] = int(data["items"][id])
	gold = int(data["gold"])
	equipped = {}
	if data.has("equipped"):
		for slot in data["equipped"]:
			var id: String = data["equipped"][slot]
			if _catalog.has(id) and count(id) > 0:
				equipped[slot] = id
	else:
		give_starting_gear()   # saves from before equipment existed: don't leave them unarmed
	equipment_changed.emit()
	changed.emit()
