extends Node3D

# Put wolves (or any enemy with a `died` signal) under this node.
# When all of them are dead, sets `cleared_flag` - quests and dialogue check it.
# On load, if the flag is already set, the pack doesn't respawn.

@export var cleared_flag: String = "wolves_cleared"
@export_multiline var cleared_message: String = "The last of the Greyfang pack falls."

var _alive := 0


func _ready() -> void:
	var members := get_children().filter(func(c): return c.has_signal("died"))
	if GameState.has_flag(cleared_flag):
		for member in members:
			member.queue_free()
		return
	_alive = members.size()
	for member in members:
		member.died.connect(_on_member_died)


func _on_member_died() -> void:
	_alive -= 1
	if _alive == 0:
		GameState.set_flag(cleared_flag)
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.show_message(cleared_message)
