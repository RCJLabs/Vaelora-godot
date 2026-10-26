extends StaticBody3D

# Something lying in the world you can take with E: an item, gold, or both.
# Once taken it stays gone (remembered with a flag, so it survives saving).
# Put it on physics layer 4 "loot" so the player walks through it but the
# interaction ray still finds it. Give it an owner (Belongs To) and taking it is
# stealing.

@export var item_id: String = ""
@export var item_count: int = 1
@export var gold: int = 0
## Shown as "Take <label>". Leave empty to use the item's name.
@export var label: String = ""
## Placed in a level: stays gone once taken. Off for drops made at runtime
## (an enemy's loot), which have no level path to remember.
@export var remember: bool = true
## Whose it is (a name, e.g. "Wenna Pike"). Taking it is theft: systems/crime.gd.
@export var belongs_to: String = ""

var _shown := ""
var _verb := "Take"
var prompt: String:
	get:
		if belongs_to != "":
			return "Steal %s%s" % [_shown, Crime.watched_tag()]
		return "%s %s" % [_verb, _shown]


func _ready() -> void:
	if remember and GameState.has_flag(_taken_flag()):
		queue_free()
		return
	var shown := label
	if shown == "" and item_id != "":
		shown = Inventory.get_item(item_id).display_name
	_verb = "Take and read" if item_id != "" and Inventory.get_item(item_id).is_readable() else "Take"
	_shown = shown


func interact(_player: Node) -> void:
	var took := {}
	if item_id != "":
		var amount := item_count
		if "green_thumb" in Character.perks and not Inventory.get_item(item_id).alchemy_effects.is_empty():
			amount *= 2   # Green Thumb (Alchemy)
		Inventory.add(item_id, amount)
		took[item_id] = amount
		if Inventory.get_item(item_id).is_readable():
			BookReader.open(item_id)   # read it on the spot; it stays in your pack
	if gold > 0:
		Inventory.add_gold(gold)
	if belongs_to != "":
		Crime.theft(took, gold, belongs_to)
	if remember:
		GameState.set_flag(_taken_flag())
	queue_free()


# Unique per pickup: level file + node path, e.g. "taken:test_level/Potion".
# Uses `owner` (the level this node was saved in), which is already set in _ready.
func _taken_flag() -> String:
	var level: Node = owner if owner else get_parent()
	return "taken:%s/%s" % [level.scene_file_path.get_file().get_basename(), level.get_path_to(self)]
