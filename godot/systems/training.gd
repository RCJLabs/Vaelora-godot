extends Node

# Trainers: people who teach a skill for gold. Autoloaded as "Training". The
# screen is ui/training_screen.gd; a dialogue choice opens it with
# "open_training": "<trainer id>".
#
# A lesson raises the skill by one level (Skills.raise: it counts toward your
# character level). It costs 10 gold + 3 per level you're at now, you can take
# LESSONS_PER_LEVEL lessons per character level (from anyone), and each trainer
# only teaches up to their own level.

const LESSONS_PER_LEVEL := 5
const COST_BASE := 10
const COST_PER_LEVEL := 3

## id -> {"name", "skill", "max": the highest level they can teach you to}
const TRAINERS := {
	"brannoc": {"name": "Brannoc", "skill": "one_handed", "max": 40},
	"ostap": {"name": "Ostap", "skill": "archery", "max": 40},
	"zora": {"name": "Zora", "skill": "glamour", "max": 50},
	"aurel": {"name": "Magister Aurel", "skill": "tidecraft", "max": 50},
}


## What the next lesson in `skill` costs.
func cost(skill: String) -> int:
	return COST_BASE + COST_PER_LEVEL * int(Skills.levels[skill])


func lessons_left() -> int:
	return maxi(LESSONS_PER_LEVEL - Skills.trained_this_level, 0)


## Why `trainer` can't teach you now, or "" if they can.
func why_not(trainer: String) -> String:
	var def: Dictionary = TRAINERS[trainer]
	var skill: String = def["skill"]
	if Skills.levels[skill] >= int(def["max"]):
		return "%s has nothing left to teach you in %s." % [def["name"], Skills.SKILLS[skill]["name"]]
	if lessons_left() <= 0:
		return "You've had all the lessons you can take in for now. Come back after your next level."
	if Inventory.gold < cost(skill):
		return "You can't afford the lesson."
	return ""


## One lesson: gold to them, a level to you.
func train(trainer: String) -> bool:
	if why_not(trainer) != "":
		return false
	var skill: String = TRAINERS[trainer]["skill"]
	Inventory.add_gold(-cost(skill))
	Skills.trained_this_level += 1
	Skills.raise(skill)
	return true
