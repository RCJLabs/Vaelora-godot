extends Node

# Saving and loading, with slots. Autoloaded as "SaveSystem".
#   F5 = quicksave (its own slot), F9 = load the most recent save.
#   The pause menu (Esc) saves to / loads from manual slots 1-5.
# Saves live in user://saves/<slot>.json. Find that folder with
# Project > Open User Data Folder (in the editor).
#
# What is saved: current level, race, story flags, skills and character level,
# inventory and gold, known spells, faction reputation, play time, player
# position/look direction and Health/Stamina/Magicka. Quest progress comes
# from flags and items. Things not driven by flags (e.g. a door you left
# open) reset when you load.

const SAVE_DIR := "user://saves/"
const OLD_SAVE_PATH := "user://savegame.json"   # before slots existed
const SAVE_VERSION := 6   # 2: skills, 3: inventory, 4: spells, 5: reputation, 6: slots + play time
const QUICKSAVE := "quicksave"
const MANUAL_SLOTS := ["slot_1", "slot_2", "slot_3", "slot_4", "slot_5"]

var _pending_player_state: Dictionary = {}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	if FileAccess.file_exists(OLD_SAVE_PATH) and not FileAccess.file_exists(_path(QUICKSAVE)):
		DirAccess.rename_absolute(OLD_SAVE_PATH, _path(QUICKSAVE))   # keep the old save as the quicksave


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quicksave"):
		save_game(QUICKSAVE)
	elif event.is_action_pressed("quickload"):
		load_game()


func slot_title(slot: String) -> String:
	if slot == QUICKSAVE:
		return "Quicksave"
	return "Slot %s" % slot.trim_prefix("slot_")


## True if `slot` has a save. With no slot: true if any save exists.
func has_save(slot: String = "") -> bool:
	if slot != "":
		return FileAccess.file_exists(_path(slot))
	return not list_saves().is_empty()


## Every save, newest first: [{"slot": "slot_1", "meta": {...}}, ...]
func list_saves() -> Array:
	var saves := []
	for slot in [QUICKSAVE] + MANUAL_SLOTS:
		if has_save(slot):
			var data = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
			if data is Dictionary:
				saves.append({"slot": slot, "meta": data.get("meta", {})})
	saves.sort_custom(func(a, b): return a["meta"].get("saved_at", 0) > b["meta"].get("saved_at", 0))
	return saves


func most_recent_slot() -> String:
	var saves := list_saves()
	return saves[0]["slot"] if not saves.is_empty() else ""


## One line describing a save, for menus.
func describe(meta: Dictionary) -> String:
	var minutes := int(meta.get("play_time", 0.0) / 60.0)
	return "%s, level %d  -  %s  -  %dh %02dm played  -  %s" % [
		meta.get("race", "?"), meta.get("character_level", 1), meta.get("location", "?"),
		minutes / 60, minutes % 60, meta.get("saved_at_text", "")]


func save_game(slot: String = QUICKSAVE) -> bool:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false   # e.g. on the title screen
	if DialogueManager.is_active or player.is_dead:
		player.show_message("You can't save right now.")
		return false

	var level := get_tree().current_scene
	var data := {
		"version": SAVE_VERSION,
		"meta": {
			"saved_at": Time.get_unix_time_from_system(),
			"saved_at_text": Time.get_datetime_string_from_system(false, true).substr(0, 16),
			"race": GameState.race,
			"character_level": Skills.character_level,
			"location": level.name.capitalize(),   # "TestLevel" -> "Test Level"
			"play_time": GameState.play_time,
		},
		"level": level.scene_file_path,
		"race": GameState.race_data.resource_path,
		"flags": GameState.flags,
		"play_time": GameState.play_time,
		"skills": Skills.to_dict(),
		"inventory": Inventory.to_dict(),
		"spells": Spellbook.to_dict(),
		"reputation": Reputation.to_dict(),
		"player": player.get_save_data(),
	}
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveSystem: can't write %s (error %d)" % [_path(slot), FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(data, "\t"))
	player.show_message("Game saved (%s)." % slot_title(slot))
	return true


## Loads `slot`, or the most recent save if no slot is given.
func load_game(slot: String = "") -> bool:
	if slot == "":
		slot = most_recent_slot()
	if slot == "" or not has_save(slot):
		var player := get_tree().get_first_node_in_group("player")
		if player:
			player.show_message("No save yet. Press F5 to save.")
		return false

	var data = JSON.parse_string(FileAccess.get_file_as_string(_path(slot)))
	if not data is Dictionary or not int(data.get("version", 0)) in range(1, SAVE_VERSION + 1):
		push_error("SaveSystem: %s is damaged or from a newer version of the game." % _path(slot))
		return false

	if DialogueManager.is_active:
		DialogueManager.end()
	get_tree().paused = false
	QuestLog.silent = true   # restoring flags/items isn't "progress" - don't announce it
	GameState.set_race(load(data["race"]))
	GameState.flags = data["flags"]
	GameState.play_time = float(data.get("play_time", 0.0))
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


## Deletes one slot, or every save if no slot is given.
func delete_save(slot: String = "") -> void:
	for s in ([slot] if slot != "" else [QUICKSAVE] + MANUAL_SLOTS):
		if has_save(s):
			DirAccess.remove_absolute(_path(s))
	if slot == "" and FileAccess.file_exists(OLD_SAVE_PATH):
		DirAccess.remove_absolute(OLD_SAVE_PATH)


func _path(slot: String) -> String:
	return SAVE_DIR + slot + ".json"
