extends Node

# The quest journal. Autoloaded as "QuestLog".
#
# Quests are written in res://quests/quests.json. A quest has no state of its
# own: whether it's started, which objectives are done and whether it's
# complete are all worked out from story flags and the inventory, using the
# same conditions as dialogue (systems/conditions.gd). So quests are saved
# automatically along with the flags and items.
#
# Watches for flag and inventory changes and announces what changed:
# "Quest started", "Objective complete", "Quest completed".

signal notice(text: String)
signal changed

const QUESTS_FILE := "res://quests/quests.json"

var quests: Dictionary = {}     # quest id -> data from the JSON
var silent := false             # true while loading a save, so nothing is announced

var _last: Dictionary = {}      # quest id -> status() from the last check


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(QUESTS_FILE))
	if not data is Dictionary:
		push_error("QuestLog: %s is missing or not valid JSON." % QUESTS_FILE)
		return
	quests = data
	GameState.flag_set.connect(func(_flag): _check())
	Inventory.changed.connect(_check)
	reset_baseline()


## What the journal shows for one quest:
## {"state": "hidden"/"active"/"completed",
##  "objectives": [{"text", "done"}],   only the visible ones
##  "outcome": text or ""}
func status(id: String) -> Dictionary:
	var quest: Dictionary = quests[id]
	var completed := Conditions.met(quest.get("completed_when", {"requires_flag": "__never__"}))
	var started := completed or Conditions.met(quest.get("started_when", {}))

	var visible: Array = quest["objectives"].filter(func(o): return Conditions.met(o.get("show_when", {})))
	var objectives := []
	var later_done := completed
	# Walk backwards: an objective counts as done if a later one is (you can't
	# have handed the shards over without having found them).
	for i in range(visible.size() - 1, -1, -1):
		var o: Dictionary = visible[i]
		var done: bool = later_done or Conditions.met(o.get("done_when", {"requires_flag": "__never__"}))
		later_done = done
		objectives.push_front({"text": o["text"], "done": done})

	var outcome := ""
	for o in quest.get("outcomes", []):
		if Conditions.met(o["when"]):
			outcome = o["text"]
			break
	return {
		"state": "completed" if completed else ("active" if started else "hidden"),
		"objectives": objectives,
		"outcome": outcome,
	}


## The first objective not done yet, or "".
func current_objective(id: String) -> String:
	for o in status(id)["objectives"]:
		if not o["done"]:
			return o["text"]
	return ""


## Remember the current state without announcing anything (after loading, new game).
func reset_baseline() -> void:
	for id in quests:
		_last[id] = status(id)
	changed.emit()


func _check() -> void:
	if silent:
		return
	for id in quests:
		var now := status(id)
		var before: Dictionary = _last.get(id, {"state": "hidden", "objectives": []})
		var title: String = quests[id]["title"]
		if now["state"] == "completed" and before["state"] != "completed":
			notice.emit("Quest completed: %s" % title)
		elif now["state"] == "active" and before["state"] == "hidden":
			notice.emit("Quest started: %s" % title)
			var next := current_objective(id)
			if next != "":
				notice.emit("  " + next)
		elif now["state"] == "active":
			var done_before: int = before["objectives"].filter(func(o): return o["done"]).size()
			var done_now: int = now["objectives"].filter(func(o): return o["done"]).size()
			if done_now > done_before:
				notice.emit("Objective complete")
				var next := current_objective(id)
				if next != "":
					notice.emit("  " + next)
		_last[id] = now
	changed.emit()
