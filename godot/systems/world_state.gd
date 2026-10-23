extends Node

# Remembers what changed in each location (level or interior), so the world
# stays the way you left it: dead wolves, open doors, emptied chests.
# Autoloaded as "WorldState". Saved with the game.
#
# To make a node remember itself:
#   1. add it to the group "persistent"
#   2. give it get_persist_state() -> Dictionary and apply_persist_state(state)
#   3. call WorldState.restore(self) at the end of its _ready()
# Its state is collected when you save or leave the location.
# (Simple one-time things - pickups, quest steps - use story flags instead.)

var data: Dictionary = {}   # "level_name/Node/Path" -> state Dictionary


## Unique key for a node: the level it's in + its path inside that level.
func key_for(node: Node) -> String:
	var level := node
	while level.get_parent() and level.get_parent() != node.get_tree().root:
		level = level.get_parent()
	return "%s/%s" % [level.scene_file_path.get_file().get_basename(), level.get_path_to(node)]


## Applies the remembered state to `node`, if there is one. Returns true if it did.
func restore(node: Node) -> bool:
	var key := key_for(node)
	if not data.has(key):
		return false
	node.apply_persist_state(data[key])
	return true


## Records every persistent node in the current location (before saving or leaving).
func collect() -> void:
	for node in get_tree().get_nodes_in_group("persistent"):
		if node.is_inside_tree() and not node.is_queued_for_deletion():
			data[key_for(node)] = node.get_persist_state()


func reset() -> void:
	data = {}


func to_dict() -> Dictionary:
	return data


func from_dict(saved: Dictionary) -> void:
	data = saved.duplicate(true)
