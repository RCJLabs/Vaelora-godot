extends Node3D

# Put wolves (or any enemy with a `died` signal) under this node.
# When all of them are dead, sets `cleared_flag` - quests and dialogue check it.
# When one starts hunting the player, the others join in (alert()).
# On load, if the flag is already set, the pack doesn't respawn. Individual
# dead wolves are remembered by WorldState, so a half-killed pack stays that way.

@export var cleared_flag: String = "wolves_cleared"
@export_multiline var cleared_message: String = "The last of the Greyfang pack falls."

var _alive := 0


func _ready() -> void:
	var members := get_children().filter(func(c): return c.has_signal("died"))
	if GameState.has_flag(cleared_flag):
		for member in members:
			member.queue_free()
		return
	# Members restore themselves first (WorldState); only count the living.
	for member in members:
		if member.get("state") != null and member.state == member.State.DEAD:
			continue
		_alive += 1
		member.died.connect(_on_member_died)


## A member started hunting: the rest of the pack joins in.
func alert(_by: Node) -> void:
	for member in get_children():
		if member.has_method("join_hunt"):
			member.join_hunt()


func _on_member_died() -> void:
	_alive -= 1
	if _alive == 0:
		GameState.set_flag(cleared_flag)
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.show_message(cleared_message)
