extends Node

# Core attributes. Autoloaded as "Attributes".
# Every attribute starts at 10; races add or subtract (RaceData.attribute_bonuses).
# Each point above 10 adds the "per_point" amounts below (below 10 subtracts).
# Character creation and level-ups will hand out points later (ROADMAP 1b).
#
# The list is a first draft: rename, add or remove entries here - the Tab menu
# and character creation read it. Code that uses an attribute asks for one of
# the derived values (health_bonus(), melee_mult(), ...).

signal changed

const BASE := 10

const ATTRIBUTES := {
	"strength": {
		"name": "Strength", "short": "STR",
		"description": "+3% melee damage per point. Later: carry weight, heavy weapons.",
	},
	"endurance": {
		"name": "Endurance", "short": "END",
		"description": "+5 max Health and +3 max Stamina per point.",
	},
	"agility": {
		"name": "Agility", "short": "AGI",
		"description": "+1% movement speed and +4% Stamina regeneration per point.",
	},
	"intellect": {
		"name": "Intellect", "short": "INT",
		"description": "+5 max Magicka and +2% spell power per point.",
	},
	"willpower": {
		"name": "Willpower", "short": "WIL",
		"description": "+5% Magicka regeneration per point. Later: resisting effects.",
	},
	"presence": {
		"name": "Presence", "short": "PRE",
		"description": "+3% reputation gains per point. Later: prices, persuasion.",
	},
}

var values: Dictionary = {}   # attribute id -> value


func _ready() -> void:
	reset(GameState.race_data)


func reset(race: RaceData) -> void:
	for id in ATTRIBUTES:
		values[id] = BASE + int(race.attribute_bonuses.get(id, 0))
	changed.emit()


func value(id: String) -> int:
	return values.get(id, BASE)


## Points above (or below) 10.
func above_base(id: String) -> int:
	return value(id) - BASE


func increase(id: String, amount: int = 1) -> void:
	values[id] = value(id) + amount
	changed.emit()


# --- derived values other systems use -----------------------------------------------

func health_bonus() -> float: return above_base("endurance") * 5.0
func stamina_bonus() -> float: return above_base("endurance") * 3.0
func magicka_bonus() -> float: return above_base("intellect") * 5.0
func melee_mult() -> float: return maxf(1.0 + above_base("strength") * 0.03, 0.1)
func spell_mult() -> float: return maxf(1.0 + above_base("intellect") * 0.02, 0.1)
func move_speed_mult() -> float: return maxf(1.0 + above_base("agility") * 0.01, 0.1)
func stamina_regen_mult() -> float: return maxf(1.0 + above_base("agility") * 0.04, 0.1)
func magicka_regen_mult() -> float: return maxf(1.0 + above_base("willpower") * 0.05, 0.1)
func reputation_mult() -> float: return maxf(1.0 + above_base("presence") * 0.03, 0.1)


func to_dict() -> Dictionary:
	return values


func from_dict(data: Dictionary) -> void:
	reset(GameState.race_data)   # attributes added since the save keep their race value
	for id in data:
		if ATTRIBUTES.has(id):
			values[id] = int(data[id])
	changed.emit()
