extends Node

# Spells the player knows and what the left hand is doing: one of them, or
# blocking (current_index -1, current() returns null). Q cycles through them.
# Autoloaded as "Spellbook".
#   Spellbook.learn("flames")    Spellbook.knows("flames")    Spellbook.current()

signal changed
signal learned(spell: SpellData)

## Every spell in the game. Add new spell files here.
const SPELL_FILES := [
	"res://spells/healing.tres",
	"res://spells/flames.tres",
	"res://spells/firebolt.tres",
	"res://spells/frost_burst.tres",
	"res://spells/healing_ward.tres",
	"res://spells/mending.tres",
	"res://spells/stoneflesh.tres",
	"res://spells/candlelight.tres",
	"res://spells/mirror_image.tres",
	"res://spells/fear.tres",
	"res://spells/charm.tres",
	"res://spells/frenzy.tres",
	"res://spells/invisibility.tres",
]

var known: Array = []        # spell ids, in the order learned
var current_index := 0      # -1 = left hand free to block

var _catalog: Dictionary = {}   # spell id -> SpellData


func _ready() -> void:
	for path in SPELL_FILES:
		var spell: SpellData = load(path)
		_catalog[spell.id] = spell
	reset(GameState.race_data)


func get_spell(id: String) -> SpellData:
	return _catalog.get(id)


func current() -> SpellData:
	if known.is_empty() or current_index < 0 or current_index >= known.size():
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


## Block -> first spell -> ... -> last spell -> Block.
func cycle() -> void:
	if known.is_empty():
		return
	current_index += 1
	if current_index >= known.size():
		current_index = -1
	changed.emit()


func ready_block() -> void:
	current_index = -1
	changed.emit()


func reset(race: RaceData) -> void:
	known = race.starting_spells.duplicate()
	current_index = 0
	changed.emit()


func to_dict() -> Dictionary:
	return {"known": known, "current": current().id if current() else ""}


func from_dict(data: Dictionary) -> void:
	known = data["known"].filter(func(id): return _catalog.has(id))
	current_index = known.find(data.get("current", ""))   # "" or unknown: block
	changed.emit()
