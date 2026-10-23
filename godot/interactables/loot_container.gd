extends StaticBody3D

# A chest, barrel or sack: E takes everything inside. Remembers being emptied
# (WorldState), so it stays empty after saving and coming back.

@export var container_name: String = "chest"
## Item id -> how many, e.g. {"iron_helmet": 1, "minor_healing_potion": 2}.
@export var contents: Dictionary = {}
@export var gold: int = 0

var prompt: String:
	get: return ("Search %s" % container_name) if not _is_empty() else ("%s (empty)" % container_name.capitalize())


func _ready() -> void:
	add_to_group("persistent")
	WorldState.restore(self)


func interact(player: Node) -> void:
	if _is_empty():
		player.show_message("Nothing left here.")
		return
	for id in contents:
		Inventory.add(id, int(contents[id]))
	if gold > 0:
		Inventory.add_gold(gold)
	contents = {}
	gold = 0


func _is_empty() -> bool:
	return contents.is_empty() and gold <= 0


func get_persist_state() -> Dictionary:
	return {"contents": contents, "gold": gold}


func apply_persist_state(state: Dictionary) -> void:
	contents = state["contents"]
	gold = int(state["gold"])
