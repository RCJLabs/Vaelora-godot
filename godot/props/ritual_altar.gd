extends StaticBody3D

# The stone slab at the Hollow Oak (main quest 5). Once the boss is dead
# (`ready_flag`), it holds the cult's sealed letter: take it (E) for the
# cliffhanger. Nothing to do with it before or after.

@export var ready_flag: String = "first_slain"
@export var taken_flag: String = "read_letter"
@export var item_id: String = "cult_letter"
@export_multiline var message: String = "Under a stone on the slab: a letter, sealed with the circle and three lines, and a map of all Vaelora. A dozen places are marked on it. This valley is only one of them."

var prompt: String:
	get: return "Take the sealed letter" if GameState.has_flag(ready_flag) and not GameState.has_flag(taken_flag) else ""


func interact(player: Node) -> void:
	if prompt == "":
		return
	Inventory.add(item_id)
	GameState.set_flag(taken_flag)
	player.show_message(message)
