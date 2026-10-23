extends Node

# How each faction feels about you. Autoloaded as "Reputation".
# Factions and rank names are in res://factions/factions.json.
#   Reputation.add("riverwatch", 10)       Reputation.value("riverwatch")
#   Reputation.rank("riverwatch") -> "Friendly"
# Values run from -100 to 100. Gains (not losses) are multiplied by the race's
# reputation_gain_mult - Humans get on with people more easily.
#
# Dialogue: "add_reputation": {"riverwatch": 10} as an action, and the
# conditions "requires_reputation": {"riverwatch": 10} (at least) and
# "requires_reputation_below": {"riverwatch": 0}.

signal changed
signal notice(text: String)

const FACTIONS_FILE := "res://factions/factions.json"

var factions: Dictionary = {}   # faction id -> data from the JSON
var ranks: Array = []           # [{"min", "name"}], highest first
var values: Dictionary = {}     # faction id -> current reputation


func _ready() -> void:
	var data = JSON.parse_string(FileAccess.get_file_as_string(FACTIONS_FILE))
	if not data is Dictionary:
		push_error("Reputation: %s is missing or not valid JSON." % FACTIONS_FILE)
		return
	factions = data["factions"]
	ranks = data["ranks"]
	reset()


func value(id: String) -> int:
	return values.get(id, 0)


func rank(id: String) -> String:
	for r in ranks:
		if value(id) >= r["min"]:
			return r["name"]
	return ranks[-1]["name"]


## Has the player come across this faction yet? (Unknown ones are hidden in the menu.)
func known(id: String) -> bool:
	var faction: Dictionary = factions[id]
	return value(id) != 0 or Conditions.met(faction.get("known_when", {})) \
			or (faction.has("also_known_when") and Conditions.met(faction["also_known_when"]))


func add(id: String, amount: int) -> void:
	if not factions.has(id):
		push_error("Reputation: unknown faction '%s'. Is it in %s?" % [id, FACTIONS_FILE])
		return
	if amount > 0:
		amount = roundi(amount * GameState.race_data.reputation_gain_mult)
	var old_rank := rank(id)
	values[id] = clampi(value(id) + amount, -100, 100)
	var name: String = factions[id]["name"]
	notice.emit("%s reputation %+d" % [name, amount])
	if rank(id) != old_rank:
		notice.emit("%s now sees you as %s" % [name, rank(id)])
	changed.emit()


func reset() -> void:
	values = {}
	changed.emit()


func to_dict() -> Dictionary:
	return values


func from_dict(data: Dictionary) -> void:
	values = {}
	for id in data:
		if factions.has(id):
			values[id] = int(data[id])
	changed.emit()
