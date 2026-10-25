extends Node

# Merchants: what each one sells, what they'll pay, and at what price.
# Autoloaded as "Trade". The buy and sell screen is ui/trade_screen.gd; a
# dialogue choice opens it with "open_trade": "<merchant id>".
#
# Prices come from an item's value, your Presence and your Speech: you buy at
# x1.25 of the value (2.5% less per Presence point above 10, 0.3% less per
# Speech level above 15, never under x1.0) and sell at x0.45 (2% more per point,
# 0.2% per level, never over x0.7). Speech perks (Haggling) then take a little
# more off, but buying never drops under x0.85 and selling never tops x0.8, so
# selling never pays more than buying. A merchant you've talked round
# ("discount_flag") takes another 10% off. Trading teaches Speech.
#
# Each merchant has a purse: they can't buy more than they have, and it fills
# back up, with their stock, every RESTOCK_DAYS days. Things marked unique (the
# bow on Maren's wall, the tomes) don't come back once sold. Quest items and
# worthless things can't be sold.

const RESTOCK_DAYS := 3
const BUY_BASE := 1.25
const BUY_PER_POINT := 0.025
const SELL_BASE := 0.45
const SELL_PER_POINT := 0.02
const BUY_PER_SPEECH := 0.003
const SELL_PER_SPEECH := 0.002
const BUY_FLOOR := 0.85     # with perks and discounts
const SELL_CEILING := 0.8
const DISCOUNT := 0.9       # a merchant's discount_flag

## id -> {"name", "gold": purse, "stock": {item: count}, "unique": [items that don't restock]}
const MERCHANTS := {
	"maren": {
		"name": "Maren",
		"gold": 250,
		"stock": {"bread": 8, "water_flask": 8, "arrow": 40, "minor_healing_potion": 2,
				"hunting_bow": 1, "tome_candlelight": 1, "tome_stoneflesh": 1, "tome_healing_ward": 1,
				"book_swordsmans_rest": 1, "book_tide_table": 1,
				"leather_cap": 1, "leather_gloves": 1, "iron_cuirass": 1, "iron_gauntlets": 1, "iron_boots": 1,
				"tome_call_wolf": 1, "tome_bind": 1, "tome_summon_guardian": 1, "tome_raise_dead": 1,
				"tome_fire_rune": 1, "tome_frost_rune": 1, "tome_binding_rune": 1, "tome_ward_circle": 1, "tome_enchant_weapon": 1,
				"tome_weak_point": 1, "tome_ill_fortune": 1, "tome_foresight": 1, "tome_true_sight": 1, "tome_moment_of_clarity": 1,
				"smiths_hammer": 1, "iron_ingot": 10, "seasoned_wood": 6, "leather_strip": 6,
				"mortar_and_pestle": 1, "mountain_flower": 6, "river_reed": 6, "red_cap": 4, "blue_moss": 4, "moth_wing": 2},
		"unique": ["hunting_bow", "tome_candlelight", "tome_stoneflesh", "tome_healing_ward",
				"tome_call_wolf", "tome_bind", "tome_summon_guardian", "tome_raise_dead",
				"tome_fire_rune", "tome_frost_rune", "tome_binding_rune", "tome_ward_circle", "tome_enchant_weapon",
				"tome_weak_point", "tome_ill_fortune", "tome_foresight", "tome_true_sight", "tome_moment_of_clarity",
				"book_swordsmans_rest", "book_tide_table"],
		# Bought before the trading screen existed (a dialogue flag); kept set when bought now.
		"discount_flag": "maren_discount",   # talked round (Speech, dialogue/maren.json)
		"flags": {"hunting_bow": "bought_maren_bow", "tome_candlelight": "bought_tome_candlelight",
				"tome_stoneflesh": "bought_tome_stoneflesh", "tome_healing_ward": "bought_tome_healing_ward"},
	},
}

signal changed

var _stock := {}     # merchant -> {item: count}
var _gold := {}      # merchant -> purse
var _sold_out := {}  # merchant -> [unique items bought for good]
var _restocked := {} # merchant -> the day they last restocked


func _ready() -> void:
	reset()


func reset() -> void:
	_stock.clear(); _gold.clear(); _sold_out.clear(); _restocked.clear()


## What you pay `merchant` (or anyone, "") for one of `id`.
func buy_price(id: String, merchant: String = "") -> int:
	var item := Inventory.get_item(id)
	if item == null:
		return 0
	var price := item.value * buy_mult(merchant)
	if item.teaches_spell != "" or item.teaches_skill != "" or item.book_text != "":
		price *= Character.modifier("book_price")   # Price of Knowledge (Speech)
	if not item.alchemy_effects.is_empty():
		price *= Character.modifier("ingredient_price")   # Herb-Wise (Alchemy)
	return maxi(roundi(price), 1)


## What a merchant pays you for one of `id` (0: they won't buy it).
func sell_price(id: String) -> int:
	var item := Inventory.get_item(id)
	if item == null or item.quest_item:
		return 0
	return roundi(item.value * sell_mult())


func buy_mult(merchant: String = "") -> float:
	var mult := clampf(BUY_BASE - Attributes.above_base("presence") * BUY_PER_POINT
			- _speech_above() * BUY_PER_SPEECH, 1.0, 1.6) * Character.modifier("buy_price")
	var flag: String = MERCHANTS.get(merchant, {}).get("discount_flag", "")
	if flag != "" and GameState.has_flag(flag):
		mult *= DISCOUNT
	return maxf(mult, BUY_FLOOR)


func sell_mult() -> float:
	var mult := clampf(SELL_BASE + Attributes.above_base("presence") * SELL_PER_POINT
			+ _speech_above() * SELL_PER_SPEECH, 0.25, 0.7) * Character.modifier("sell_price")
	return minf(mult, SELL_CEILING)


func _speech_above() -> int:
	return Skills.levels.get("speech", Skills.START_LEVEL) - Skills.START_LEVEL


## The merchant's stock right now (restocked if it's been long enough).
func stock(merchant: String) -> Dictionary:
	_restock_if_due(merchant)
	return _stock[merchant]


func gold(merchant: String) -> int:
	_restock_if_due(merchant)
	return _gold[merchant]


## Why you can't buy one `id` from `merchant` right now, or "" if you can.
func why_not_buy(merchant: String, id: String) -> String:
	if stock(merchant).get(id, 0) <= 0:
		return "None left."
	if Inventory.gold < buy_price(id, merchant):
		return "You can't afford it."
	return ""


## Why `merchant` won't buy one `id` from you right now, or "" if they will.
func why_not_sell(merchant: String, id: String) -> String:
	var item := Inventory.get_item(id)
	if item == null or Inventory.count(id) <= 0:
		return "You don't have it."
	if item.quest_item:
		return "You'd better keep that."
	if sell_price(id) <= 0:
		return "%s won't give you anything for it." % MERCHANTS[merchant]["name"]
	if gold(merchant) < sell_price(id):
		return "%s can't afford it." % MERCHANTS[merchant]["name"]
	return ""


func buy(merchant: String, id: String) -> bool:
	if why_not_buy(merchant, id) != "":
		return false
	var price := buy_price(id, merchant)
	Inventory.add_gold(-price)
	_gold[merchant] += price
	Speech.traded(price)
	_stock[merchant][id] -= 1
	if _stock[merchant][id] <= 0:
		_stock[merchant].erase(id)
		if id in MERCHANTS[merchant].get("unique", []):
			_sold_out[merchant].append(id)
	var flag: String = MERCHANTS[merchant].get("flags", {}).get(id, "")
	if flag != "":
		GameState.set_flag(flag)
	Inventory.add(id)
	changed.emit()
	return true


func sell(merchant: String, id: String) -> bool:
	if why_not_sell(merchant, id) != "":
		return false
	var price := sell_price(id)
	Inventory.remove(id)
	Inventory.add_gold(price)
	Speech.traded(price)
	_gold[merchant] -= price
	if not id in MERCHANTS[merchant].get("unique", []):
		_stock[merchant][id] = _stock[merchant].get(id, 0) + 1   # it's theirs now
	changed.emit()
	return true


func _restock_if_due(merchant: String) -> void:
	var def: Dictionary = MERCHANTS[merchant]
	if not _sold_out.has(merchant):
		_sold_out[merchant] = []
		for id in def.get("flags", {}):   # bought in an older version, through dialogue
			if GameState.has_flag(def["flags"][id]):
				_sold_out[merchant].append(id)
	var every := 1 if "master_trader" in Character.perks else RESTOCK_DAYS   # Master Trader (Speech)
	if _restocked.has(merchant) and WorldClock.day - int(_restocked[merchant]) < every:
		return
	_restocked[merchant] = WorldClock.day
	_gold[merchant] = roundi(int(def["gold"]) * Character.modifier("merchant_gold"))   # Fat Purses (Speech)
	var fresh := {}
	for id in def["stock"]:
		if not id in _sold_out[merchant]:
			fresh[id] = maxi(int(def["stock"][id]), int(_stock.get(merchant, {}).get(id, 0)))
	_stock[merchant] = fresh


func to_dict() -> Dictionary:
	return {"stock": _stock.duplicate(true), "gold": _gold.duplicate(), "sold_out": _sold_out.duplicate(true),
			"restocked": _restocked.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	for merchant in data.get("stock", {}):
		if MERCHANTS.has(merchant):
			_stock[merchant] = {}
			for id in data["stock"][merchant]:
				_stock[merchant][id] = int(data["stock"][merchant][id])
	for merchant in data.get("gold", {}):
		_gold[merchant] = int(data["gold"][merchant])
	for merchant in data.get("sold_out", {}):
		_sold_out[merchant] = Array(data["sold_out"][merchant])
	for merchant in data.get("restocked", {}):
		_restocked[merchant] = int(data["restocked"][merchant])
