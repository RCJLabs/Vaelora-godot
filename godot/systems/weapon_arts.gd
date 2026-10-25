extends Node

# Weapon arts: a special attack for each kind of weapon, earned by skill.
# Autoloaded as "WeaponArts". docs/godot-starter/COMBAT.md, "Weapon arts".
#
# Learned at UNLOCK in the weapon's skill, stronger at 50 and 75 (+25% each).
# Press Weapon Art (F, or D-pad right). Costs Stamina and has a cooldown. What
# each one does is PlayerCombat's (it owns the swing and the reach); this has the
# list, the rules and the cooldown.

const UNLOCK := 25
const TIERS := [50, 75]
const STAMINA := 30.0
const COOLDOWN := 8.0
const XP := 8.0

## weapon kind -> {name, skill, what}. "shield" is used while blocking with a shield.
const ARTS := {
	"sword":      {"name": "Flurry", "skill": "one_handed", "what": "three quick cuts at whatever's in front of you"},
	"dagger":     {"name": "Gutting Strike", "skill": "one_handed", "what": "a lunge for double, triple on an enemy that hasn't noticed you, and it bleeds"},
	"axe":        {"name": "Rend", "skill": "one_handed", "what": "a deep chop that leaves them bleeding three times over"},
	"mace":       {"name": "Skull Crack", "skill": "one_handed", "what": "a blow for half as much again that always staggers"},
	"greatsword": {"name": "Whirlwind", "skill": "two_handed", "what": "a full turn that hits everything around you"},
	"bow":        {"name": "Volley", "skill": "archery", "what": "three arrows at once, in a spread"},
	"shield":     {"name": "Shield Charge", "skill": "block", "what": "a rush that knocks back and staggers everything in front of you"},
	"unarmed":    {"name": "Palm Strike", "skill": "unarmed", "what": "a blow that hurls them back and staggers them"},
}

var cooldown_left := 0.0


func _ready() -> void:
	Skills.skill_increased.connect(_on_skill_increased)


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


## The art for what you hold now ("" if none): the weapon's, or the shield's while blocking.
func kind_for(main_item: ItemData, blocking_with_shield: bool) -> String:
	if blocking_with_shield:
		return "shield"
	if main_item == null:
		return "unarmed"
	return main_item.weapon_type if ARTS.has(main_item.weapon_type) else ""


func knows(kind: String) -> bool:
	return ARTS.has(kind) and Skills.levels.get(ARTS[kind]["skill"], Skills.START_LEVEL) >= UNLOCK


## 1, 2 or 3 by the art's skill.
func tier(kind: String) -> int:
	var level: int = Skills.levels.get(ARTS[kind]["skill"], Skills.START_LEVEL)
	var t := 1
	for need in TIERS:
		if level >= need:
			t += 1
	return t


func power(kind: String) -> float:
	return 1.0 + 0.25 * (tier(kind) - 1)


## Why it can't be used now, or "".
func why_not(kind: String, stamina: float) -> String:
	if kind == "" or not ARTS.has(kind):
		return "This has no weapon art."
	if not knows(kind):
		return "%s: learned at %s %d." % [ARTS[kind]["name"], Skills.SKILLS[ARTS[kind]["skill"]]["name"], UNLOCK]
	if cooldown_left > 0.0:
		return "%s in %d s." % [ARTS[kind]["name"], ceili(cooldown_left)]
	if stamina < STAMINA:
		return "Too tired for %s." % ARTS[kind]["name"]
	return ""


## It's going off: the cooldown starts and the skill improves.
func used(kind: String) -> void:
	cooldown_left = COOLDOWN
	Skills.add_xp(ARTS[kind]["skill"], XP)


func _on_skill_increased(skill: String, level: int) -> void:
	if level != UNLOCK:
		return
	for kind in ARTS:
		if ARTS[kind]["skill"] == skill:
			var player := get_tree().get_first_node_in_group("player")
			if player:
				player.hud.notify("Weapon art: %s (%s). Press %s." % [ARTS[kind]["name"], kind, InputHints.label("weapon_art")])


func reset() -> void:
	cooldown_left = 0.0
