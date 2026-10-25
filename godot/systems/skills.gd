extends Node

# Skills that improve by doing (Skyrim style) plus character levels.
# Autoloaded as "Skills".
#
#  - Each skill has a level (starts at 15, max 100). Using it gives XP; enough
#    XP raises the level. Race sets starting bonuses and how fast XP comes.
#  - Every SKILL_UPS_PER_LEVEL skill increases raise your character level.
#    Each character level gives one bonus to spend in the Tab menu:
#    +10 max Health, Stamina or Magicka.
#
# To add a skill: add an entry to SKILLS, then call Skills.add_xp("id", amount)
# wherever the player does that thing.

signal changed                                   # anything changed (menus refresh)
signal skill_increased(skill_id: String, new_level: int)
signal leveled_up(new_level: int)
signal level_bonus_spent(stat: String, amount: int)

const SKILLS := {
	"one_handed": {
		"name": "One-Handed",
		"description": "+1% damage with swords, axes, maces and daggers per level. Improves when your swings land.",
	},
	"two_handed": {
		"name": "Two-Handed",
		"description": "+1% greatsword damage per level. Improves when your swings land.",
	},
	"archery": {
		"name": "Archery",
		"description": "+1% bow damage per level. Improves when your arrows hit.",
	},
	"block": {
		"name": "Block",
		"description": "+0.5% of a hit blocked per level (up to 95%). Improves when you block or parry.",
	},
	"athletics": {
		"name": "Athletics",
		"description": "-0.5% sprint stamina cost per level. Improves as you sprint.",
	},
	"destruction": {
		"name": "Ruin",
		"description": "+1% damage from Ruin spells (fire, frost, storm) per level. Improves with spell damage dealt.",
	},
	"alteration": {
		"name": "Shaping",
		"description": "+1% to Shaping spells (stone, light, force) per level, and cheaper with perks. Improves as you cast them.",
	},
	"restoration": {
		"name": "Mending",
		"description": "+1% healing from Mending spells per level. Improves with health restored.",
	},
	"glamour": {
		"name": "Glamour",
		"description": "+1% to how long Glamour spells (decoys, fear, charm) last per level. Improves as you cast them.",
	},
	"tidecraft": {
		"name": "Tidecraft",
		"description": "+1% to Tidecraft spells (pull, shove, wells, moon-crush, the lifting tide) per level. They're also stronger or weaker by the moons. Improves as you cast them.",
	},
}
const START_LEVEL := 15
const MAX_LEVEL := 100
const SKILL_UPS_PER_LEVEL := 5
const LEVEL_BONUS := 10

var levels: Dictionary = {}     # skill id -> level
var xp: Dictionary = {}         # skill id -> XP towards the next level
var character_level := 1
var skill_ups_toward_level := 0
var unspent_level_ups := 0
var bonus := {"health": 0, "stamina": 0, "magicka": 0}   # from level-ups


func _ready() -> void:
	reset(GameState.race_data)   # so levels run on their own (F6)


## New character: race bonuses applied, everything else back to the start.
func reset(race: RaceData) -> void:
	for id in SKILLS:
		levels[id] = START_LEVEL + int(race.skill_bonuses.get(id, 0))
		xp[id] = 0.0
	character_level = 1
	skill_ups_toward_level = 0
	unspent_level_ups = 0
	bonus = {"health": 0, "stamina": 0, "magicka": 0}
	changed.emit()


## XP needed to go from the skill's current level to the next.
func xp_needed(id: String) -> float:
	return 5.0 + levels[id] * 0.5


func add_xp(id: String, amount: float) -> void:
	if levels[id] >= MAX_LEVEL:
		return
	var player := get_tree().get_first_node_in_group("player")
	var trait_mult: float = player.stats.modifier("skill_xp") if player else 1.0   # traits, Adaptable
	xp[id] += amount * GameState.race_data.skill_xp_mult * trait_mult
	while levels[id] < MAX_LEVEL and xp[id] >= xp_needed(id):
		xp[id] -= xp_needed(id)
		levels[id] += 1
		skill_increased.emit(id, levels[id])
		_count_skill_up()
	changed.emit()


func _count_skill_up() -> void:
	skill_ups_toward_level += 1
	if skill_ups_toward_level >= SKILL_UPS_PER_LEVEL:
		skill_ups_toward_level -= SKILL_UPS_PER_LEVEL
		character_level += 1
		unspent_level_ups += 1
		leveled_up.emit(character_level)


## stat: "health", "stamina" or "magicka".
func spend_level_up(stat: String) -> void:
	if unspent_level_ups <= 0 or not bonus.has(stat):
		return
	unspent_level_ups -= 1
	bonus[stat] += LEVEL_BONUS
	level_bonus_spent.emit(stat, LEVEL_BONUS)
	changed.emit()


## A permanent bonus from something other than levelling (e.g. a quest reward).
func grant_bonus(stat: String, amount: int) -> void:
	bonus[stat] += amount
	level_bonus_spent.emit(stat, amount)
	changed.emit()


# --- effects other scripts ask for -------------------------------------------

func one_handed_damage_mult() -> float:
	return weapon_damage_mult("one_handed")


## +1% damage per level above the start for the skill a weapon uses.
func weapon_damage_mult(skill_id: String) -> float:
	return 1.0 + (levels.get(skill_id, START_LEVEL) - START_LEVEL) * 0.01


## Share of a hit stopped by a block: the weapon's own share, plus the Block skill.
func block_share(weapon_share: float) -> float:
	return minf(weapon_share + (levels["block"] - START_LEVEL) * 0.005, 0.95)


## +1% per level above the start for whichever skill powers a spell.
func spell_power_mult(skill_id: String) -> float:
	return 1.0 + (levels[skill_id] - START_LEVEL) * 0.01


func athletics_stamina_mult() -> float:
	return maxf(1.0 - (levels["athletics"] - START_LEVEL) * 0.005, 0.5)


# --- saving ----------------------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"levels": levels, "xp": xp,
		"character_level": character_level,
		"skill_ups_toward_level": skill_ups_toward_level,
		"unspent_level_ups": unspent_level_ups,
		"bonus": bonus,
	}


func from_dict(data: Dictionary) -> void:
	reset(GameState.race_data)
	for id in SKILLS:   # skills added after the save was made keep their start values
		if data["levels"].has(id):
			levels[id] = int(data["levels"][id])
			xp[id] = float(data["xp"][id])
	character_level = int(data["character_level"])
	skill_ups_toward_level = int(data["skill_ups_toward_level"])
	unspent_level_ups = int(data["unspent_level_ups"])
	for stat in bonus:
		bonus[stat] = int(data["bonus"].get(stat, 0))
	changed.emit()
