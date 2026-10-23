extends Node

# Spells the player knows and which one is ready in the left hand.
# Autoloaded as "Spellbook".
#   Spellbook.learn("flames")    Spellbook.knows("flames")    Spellbook.current()

signal changed
signal learned(spell: SpellData)

## Every spell in the game. Add new spell files here.
const SPELL_FILES := [
	"res://spells/healing.tres",
	"res://spells/flames.tres",
]

var known: Array = []        # spell ids, in the order learned
var current_index := 0

var _catalog: Dictionary = {}   # spell id -> SpellData


func _ready() -> void:
	for path in SPELL_FILES:
		var spell: SpellData = load(path)
		_catalog[spell.id] = spell
	reset(GameState.race_data)


func get_spell(id: String) -> SpellData:
	return _catalog.get(id)


func current() -> SpellData:
	if known.is_empty():
		return null
	return _catalog[known[current_index]]


func knows(id: String) -> bool:
	return id in known


func learn(id: String) -> void:
	if knows(id) or not _catalog.has(id):
		return
	known.append(id)
	learned.emit(_catalog[id])
	changed.emit()


func select(id: String) -> void:
	if knows(id):
		current_index = known.find(id)
		changed.emit()


func cycle() -> void:
	if known.size() > 1:
		current_index = (current_index + 1) % known.size()
		changed.emit()


func reset(race: RaceData) -> void:
	known = race.starting_spells.duplicate()
	current_index = 0
	changed.emit()


func to_dict() -> Dictionary:
	return {"known": known, "current": known[current_index] if not known.is_empty() else ""}


func from_dict(data: Dictionary) -> void:
	known = data["known"].filter(func(id): return _catalog.has(id))
	current_index = maxi(known.find(data.get("current", "")), 0)
	changed.emit()
