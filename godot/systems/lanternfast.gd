extends Node

# Lanternfast, the festival on the dark of the Wanderer (docs/lore/WORLD.md).
# Autoloaded as "Lanternfast". WorldClock says when (is_lanternfast(): from
# 18:00 on a dark day until 2:00); this keeps the story flag "lanternfast_now"
# set for exactly that long, so the world can follow it with what it already has:
#   - lanterns and the like: a StoryPresence with show_flag "lanternfast_now"
#   - people: dialogue start entries with requires_flag "lanternfast_now"
#   - the wisps don't attack tonight (enemies/wisp.gd)
# "saw_lanternfast" is set the first time, and stays.

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return   # the title screen, or between levels
	var now := WorldClock.is_lanternfast()
	if now == GameState.has_flag("lanternfast_now"):
		return
	if now:
		var first := not GameState.has_flag("saw_lanternfast")
		GameState.set_flag("lanternfast_now")
		GameState.set_flag("saw_lanternfast")
		if first and player.has_method("show_message"):
			player.show_message("Lanternfast. The Wanderer is dark tonight: a lantern in every window, and nobody sleeps before midnight.")
	else:
		GameState.clear_flag("lanternfast_now")
