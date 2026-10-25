extends StaticBody3D

# A chest, barrel or sack: E takes everything inside. Remembers being emptied
# (WorldState), so it stays empty after saving and coming back.
# Locked (lock_level 0-4, Novice to Master): E picks the lock (ui/lockpick_screen.gd)
# or opens it with its key. Once open it stays open.

@export var container_name: String = "chest"
## Item id -> how many, e.g. {"iron_helmet": 1, "minor_healing_potion": 2}.
@export var contents: Dictionary = {}
@export var gold: int = 0
## -1: not locked. 0-4: Novice, Apprentice, Adept, Expert, Master (systems/lockpicking.gd).
@export_range(-1, 4) var lock_level: int = -1
## An item that opens it without picking. Optional.
@export var key_id: String = ""

var prompt: String:
	get:
		if is_locked():
			if key_id != "" and Inventory.count(key_id) > 0:
				return "Unlock %s" % container_name
			return "Pick the lock (%s)" % Lockpicking.LEVEL_NAMES[lock_level]
		return ("Search %s" % container_name) if not _is_empty() else ("%s (empty)" % container_name.capitalize())


func _ready() -> void:
	add_to_group("persistent")
	WorldState.restore(self)


func interact(player: Node) -> void:
	if is_locked():
		if key_id != "" and Inventory.count(key_id) > 0:
			unlock()
			player.show_message("The key turns.")
		elif Inventory.count("lockpick") <= 0:
			player.show_message("It's locked (%s). You need a lockpick." % Lockpicking.LEVEL_NAMES[lock_level])
			return
		else:
			LockpickScreen.open(lock_level, self)
			return
	if _is_empty():
		player.show_message("Nothing left here.")
		return
	for id in contents:
		Inventory.add(id, int(contents[id]))
	if gold > 0:
		Inventory.add_gold(gold)
	contents = {}
	gold = 0


func is_locked() -> bool:
	return lock_level >= 0


## Picked or opened with the key (Lockpicking calls it). Treasure Hunter and Scavenger
## add to what's inside, once.
func unlock() -> void:
	if not is_locked():
		return
	lock_level = -1
	if "treasure_hunter" in Character.perks:
		gold = roundi(gold * 1.5)
	if "scavenger" in Character.perks:
		contents["lockpick"] = int(contents.get("lockpick", 0)) + randi_range(1, 2)


func _is_empty() -> bool:
	return contents.is_empty() and gold <= 0


func get_persist_state() -> Dictionary:
	return {"contents": contents, "gold": gold, "lock_level": lock_level}


func apply_persist_state(state: Dictionary) -> void:
	contents = state["contents"]
	gold = int(state["gold"])
	lock_level = int(state.get("lock_level", lock_level))
