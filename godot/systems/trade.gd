extends Node

# Merchants: what each one sells, what they'll pay, and at what price.
# Autoloaded as "Trade". The buy and sell screen is ui/trade_screen.gd; a
# dialogue choice opens it with "open_trade": "<merchant id>".
#
# Prices come from an item's value and your Presence: you buy at x1.25 of the
# value (2.5% less per point above 10, never under x1.0) and sell at x0.45
# (2% more per point, never over x0.7), so selling never pays more than buying.
# Speech will feed in too, once it exists.
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

## id -> {"name", "gold": purse, "stock": {item: count}, "unique": [items that don't restock]}
const MERCHANTS := {
	"maren": {
		"name": "Maren",
		"gold": 250,
		"stock": {"bread": 8, "water_flask": 8, "arrow": 40, "minor_healing_potion": 2,
				"hunting_bow": 1, "tome_candlelight": 1, "tome_stoneflesh": 1, "tome_healing_ward": 1},
		"unique": ["hunting_bow", "tome_candlelight", "tome_stoneflesh", "tome_healing_ward"],
		# Bought before the trading screen existed (a dialogue flag); kept set when bought now.
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


## What you pay for one of `id`.
func buy_price(id: String) -> int:
	var item := Inventory.get_item(id)
	return maxi(roundi(item.value * buy_mult()), 1) if item else 0


## What a merchant pays you for one of `id` (0: they won't buy it).
func sell_price(id: String) -> int:
	var item := Inventory.get_item(id)
	if item == null or item.quest_item:
		return 0
	return roundi(item.value * sell_mult())


func buy_mult() -> float:
	return clampf(BUY_BASE - Attributes.above_base("presence") * BUY_PER_POINT, 1.0, 1.6)


func sell_mult() -> float:
	return clampf(SELL_BASE + Attributes.above_base("presence") * SELL_PER_POINT, 0.25, 0.7)


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
	if Inventory.gold < buy_price(id):
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
	var price := buy_price(id)
	Inventory.add_gold(-price)
	_gold[merchant] += price
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
	if _restocked.has(merchant) and WorldClock.day - int(_restocked[merchant]) < RESTOCK_DAYS:
		return
	_restocked[merchant] = WorldClock.day
	_gold[merchant] = int(def["gold"])
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
