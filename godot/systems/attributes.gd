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
## Carry weight: this much at Strength 10, and this much more per point.
const CARRY_BASE := 120.0
const CARRY_PER_POINT := 10.0

const ATTRIBUTES := {
	"strength": {
		"name": "Strength", "short": "STR",
		"description": "+3% melee damage and +10 carry weight per point; heavy weapons are clumsy without it. Its skills learn faster.",
	},
	"endurance": {
		"name": "Endurance", "short": "END",
		"description": "+5 max Health and +3 max Stamina per point. Its skills learn faster.",
	},
	"agility": {
		"name": "Agility", "short": "AGI",
		"description": "+1% movement speed and +4% Stamina regeneration per point. Its skills learn faster.",
	},
	"intellect": {
		"name": "Intellect", "short": "INT",
		"description": "+5 max Magicka and +2% spell power per point. Its skills learn faster.",
	},
	"willpower": {
		"name": "Willpower", "short": "WIL",
		"description": "+5% Magicka regeneration per point; harmful effects on you wear off 4% sooner per point. Its skills learn faster.",
	},
	"presence": {
		"name": "Presence", "short": "PRE",
		"description": "+3% reputation gains per point. Its skills learn faster. Later: prices, persuasion.",
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
## How much you can carry before you're over-encumbered.
func carry_capacity() -> float: return maxf(CARRY_BASE + above_base("strength") * CARRY_PER_POINT, 20.0)
## Harmful effects on you last this share of their time (Willpower).
func harmful_duration_mult() -> float: return clampf(1.0 - above_base("willpower") * 0.04, 0.4, 1.6)
## Heavy weapons (over 10 weight) want Strength: 10, plus 1 per 2 weight over 10
## (iron mace 11, steel greatsword 14). 0 for anything lighter.
func strength_needed(weight: float) -> float: return 10.0 + (weight - 10.0) / 2.0 if weight > 10.0 else 0.0
## Points of Strength short of what `weight` wants (0 if none).
func strength_short(weight: float) -> float: return maxf(strength_needed(weight) - value("strength"), 0.0)
## A heavy weapon without the Strength for it: -4% damage and +6% stamina per point short.
func heavy_damage_mult(weight: float) -> float: return maxf(1.0 - strength_short(weight) * 0.04, 0.6)
func heavy_stamina_mult(weight: float) -> float: return 1.0 + strength_short(weight) * 0.06
## Skill XP from the skill's governing attribute: +3% per point above 10.
func skill_xp_mult(attribute: String) -> float: return maxf(1.0 + above_base(attribute) * 0.03, 0.5) if ATTRIBUTES.has(attribute) else 1.0


func to_dict() -> Dictionary:
	return values


func from_dict(data: Dictionary) -> void:
	reset(GameState.race_data)   # attributes added since the save keep their race value
	for id in data:
		if ATTRIBUTES.has(id):
			values[id] = int(data[id])
	changed.emit()
