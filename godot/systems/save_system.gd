extends Node

# Quicksave (F5) / quickload (F9). Autoloaded as "SaveSystem".
# Saves to user://savegame.json. Find that folder with
# Project > Open User Data Folder (in the editor).
#
# What is saved: current level, race, story flags, skills and character level,
# inventory and gold, known spells, faction reputation (quest progress comes from flags and items),
# player position/look direction and Health/Stamina/Magicka. Things not driven by flags (e.g. a
# door you left open) reset when you load.

const SAVE_PATH := "user://savegame.json"
const SAVE_VERSION := 5   # 2: skills, 3: inventory, 4: spells, 5: reputation

var _pending_player_state: Dictionary = {}


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quicksave"):
		save_game()
	elif event.is_action_pressed("quickload"):
		load_game()


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func save_game() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false   # e.g. on the character creation screen
	if DialogueManager.is_active or player.is_dead:
		player.show_message("You can't save right now.")
		return false

	var data := {
		"version": SAVE_VERSION,
		"level": get_tree().current_scene.scene_file_path,
		"race": GameState.race_data.resource_path,
		"flags": GameState.flags,
		"skills": Skills.to_dict(),
		"inventory": Inventory.to_dict(),
		"spells": Spellbook.to_dict(),
		"reputation": Reputation.to_dict(),
		"player": player.get_save_data(),
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: can't write %s (error %d)" % [SAVE_PATH, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	player.show_message("Game saved.")
	return true


func load_game() -> bool:
	if not has_save():
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.show_message("No save yet. Press F5 to save.")
		return false

	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or not int(data.get("version", 0)) in range(1, SAVE_VERSION + 1):
		push_error("SaveSystem: %s is damaged or from a newer version of the game." % SAVE_PATH)
		return false

	if DialogueManager.is_active:
		DialogueManager.end()
	QuestLog.silent = true   # restoring flags/items isn't "progress" - don't announce it
	GameState.set_race(load(data["race"]))
	GameState.flags = data["flags"]
	if data.has("skills"):
		Skills.from_dict(data["skills"])
	else:
		Skills.reset(GameState.race_data)   # version 1 saves had no skills
	if data.has("inventory"):
		Inventory.from_dict(data["inventory"])
	else:
		Inventory.reset()                   # versions 1-2 had no inventory
	if data.has("spells"):
		Spellbook.from_dict(data["spells"])
	else:
		Spellbook.reset(GameState.race_data)   # versions 1-3 had no spells
	if data.has("reputation"):
		Reputation.from_dict(data["reputation"])
	else:
		Reputation.reset()                     # versions 1-4 had no reputation
	QuestLog.silent = false
	QuestLog.reset_baseline()
	_pending_player_state = data["player"]
	get_tree().change_scene_to_file(data["level"])
	return true


## Called by the player when it spawns. Returns {} unless a load is in progress.
func take_pending_player_state() -> Dictionary:
	var state := _pending_player_state
	_pending_player_state = {}
	return state


func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)
