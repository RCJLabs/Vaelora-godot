extends StaticBody3D

# Something lying in the world you can take with E: an item, gold, or both.
# Once taken it stays gone (remembered with a flag, so it survives saving).
# Put it on physics layer 4 "loot" so the player walks through it but the
# interaction ray still finds it.

@export var item_id: String = ""
@export var item_count: int = 1
@export var gold: int = 0
## Shown as "Take <label>". Leave empty to use the item's name.
@export var label: String = ""
## Placed in a level: stays gone once taken. Off for drops made at runtime
## (an enemy's loot), which have no level path to remember.
@export var remember: bool = true

var prompt: String


func _ready() -> void:
	if remember and GameState.has_flag(_taken_flag()):
		queue_free()
		return
	var shown := label
	if shown == "" and item_id != "":
		shown = Inventory.get_item(item_id).display_name
	prompt = "Take %s" % shown


func interact(_player: Node) -> void:
	if item_id != "":
		Inventory.add(item_id, item_count)
	if gold > 0:
		Inventory.add_gold(gold)
	if remember:
		GameState.set_flag(_taken_flag())
	queue_free()


# Unique per pickup: level file + node path, e.g. "taken:test_level/Potion".
# Uses `owner` (the level this node was saved in), which is already set in _ready.
func _taken_flag() -> String:
	var level: Node = owner if owner else get_parent()
	return "taken:%s/%s" % [level.scene_file_path.get_file().get_basename(), level.get_path_to(self)]
