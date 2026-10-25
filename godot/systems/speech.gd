extends Node

# Speech: persuading, intimidating and bribing in conversation, and haggling.
# Autoloaded as "Speech". docs/godot-starter/SPEECH.md.
#
# A dialogue choice can carry a check:
#   {"text": "You don't want this fight.", "next": "backs_off", "fail_next": "draws",
#    "check": {"id": "inquisitor_marked", "kind": "persuade", "difficulty": 60}}
#   {"text": "The Order takes donations, I hear.", "next": "backs_off",
#    "check": {"id": "inquisitor_bribe", "kind": "bribe", "gold": 150}}
# The choice shows what it takes and what you have ("[Persuade 60 · you 42]"):
# there's no dice. Persuade is Speech + 2 per Presence point above 10;
# intimidate is Speech + 2 per Strength point above 10; perks add to each.
# A bribe always works if you can pay; Speech and perks make it cheaper.
# Passing teaches Speech once per check; failing goes to "fail_next" and the
# choice doesn't come back (flag speech_failed_<id>).

const KINDS := {"persuade": "presence", "intimidate": "strength"}
const PER_POINT := 2               # check score per attribute point above 10
const BRIBE_PER_LEVEL := 0.004     # -0.4% of a bribe per Speech level above 15
const BRIBE_FLOOR := 0.5
const PASS_XP := 5.0               # + difficulty / 5
const TRADE_XP_PER_GOLD := 0.05    # Speech XP per gold of a sale or purchase


func level() -> int:
	return Skills.levels.get("speech", Skills.START_LEVEL)


## Your score for a "persuade" or "intimidate" check now.
func score(kind: String) -> int:
	var total := level() + PER_POINT * Attributes.above_base(KINDS[kind])
	for id in Character.perks:
		total += int(Character.perk_list[id].get("check_bonus", {}).get(kind, 0))
		total += int(Character.perk_list[id].get("check_bonus", {}).get("all", 0))
	return total


## What a bribe of `gold` (the price the dialogue names) costs you.
func bribe_cost(gold: int) -> int:
	var mult := maxf(1.0 - BRIBE_PER_LEVEL * (level() - Skills.START_LEVEL), BRIBE_FLOOR)
	return maxi(roundi(gold * mult * Character.modifier("bribe_cost")), 1)


func passes(check: Dictionary) -> bool:
	if check.get("kind", "") == "bribe":
		return Inventory.gold >= bribe_cost(int(check.get("gold", 0)))
	return score(check["kind"]) >= int(check.get("difficulty", 0))


## Shown before the choice text: "[Persuade 60 · you 42] ", "[Bribe 120 gold] ".
func label(check: Dictionary) -> String:
	var kind: String = check.get("kind", "")
	if kind == "bribe":
		return "[Bribe %d gold] " % bribe_cost(int(check.get("gold", 0)))
	return "[%s %d · you %d] " % [kind.capitalize(), int(check.get("difficulty", 0)), score(kind)]


## A failed check isn't offered again.
func is_spent(check: Dictionary) -> bool:
	return GameState.has_flag("speech_failed_" + str(check.get("id", "")))


## The player picked the choice: pay, teach, remember. True = it worked.
func resolve(check: Dictionary) -> bool:
	var id := str(check.get("id", ""))
	if not passes(check):
		GameState.set_flag("speech_failed_" + id)
		if "learn_from_it" in Character.perks:
			_teach(id, int(check.get("difficulty", 0)), 0.5)
		return false
	if check.get("kind", "") == "bribe":
		Inventory.add_gold(-bribe_cost(int(check.get("gold", 0))))
		_teach(id, roundi(check.get("gold", 0) / 5.0), 1.0)
	else:
		_teach(id, int(check.get("difficulty", 0)), 1.0)
	return true


func _teach(id: String, difficulty: int, share: float) -> void:
	var flag := "speech_taught_" + id
	if GameState.has_flag(flag):
		return
	GameState.set_flag(flag)
	Skills.add_xp("speech", (PASS_XP + difficulty / 5.0) * share)


## Buying and selling teaches Speech (Trade calls it).
func traded(gold: int) -> void:
	Skills.add_xp("speech", gold * TRADE_XP_PER_GOLD)
