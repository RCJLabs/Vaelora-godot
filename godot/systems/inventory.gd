extends Node

# The player's items and gold. Autoloaded as "Inventory".
#   Inventory.add("wolf_pelt")           Inventory.remove("wolf_pelt", 2)
#   Inventory.count("wolf_pelt")         Inventory.gold += 10  (or add_gold)
#   Inventory.use("minor_healing_potion")

signal changed
signal item_added(item: ItemData, amount: int)
signal gold_added(amount: int)

## Every item in the game. Add new item files here.
const ITEM_FILES := [
	"res://items/wolf_pelt.tres",
	"res://items/minor_healing_potion.tres",
]

var items: Dictionary = {}   # item id -> how many
var gold: int = 0

var _catalog: Dictionary = {}   # item id -> ItemData


func _ready() -> void:
	for path in ITEM_FILES:
		var item: ItemData = load(path)
		_catalog[item.id] = item


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
	if items[id] == 0:
		items.erase(id)
	changed.emit()
	return true


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
	if item == null or item.type != ItemData.Type.CONSUMABLE or player == null or count(id) == 0:
		return false
	var stats: Stats = player.stats
	stats.heal(item.restore_health)
	stats.stamina = minf(stats.stamina + item.restore_stamina, stats.max_stamina)
	stats.magicka = minf(stats.magicka + item.restore_magicka, stats.max_magicka)
	stats.changed.emit()
	remove(id)
	return true


func reset() -> void:
	items = {}
	gold = 0
	changed.emit()


func to_dict() -> Dictionary:
	return {"items": items, "gold": gold}


func from_dict(data: Dictionary) -> void:
	items = {}
	for id in data["items"]:
		if _catalog.has(id):   # skip items removed from the game since the save
			items[id] = int(data["items"][id])
	gold = int(data["gold"])
	changed.emit()
