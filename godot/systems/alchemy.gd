extends Node

# Alchemy: herbs into potions. Autoloaded as "Alchemy". The brewing screen is
# ui/alchemy_screen.gd (a mortar and pestle opens it anywhere).
# docs/godot-starter/ALCHEMY.md.
#
# Every ingredient has up to three effects (ItemData.alchemy_effects). Brew two or
# three together and you get a potion of every effect at least two of them share.
# How strong it is (weak / standard / strong) comes from your Alchemy skill and
# perks when you brew it; it's a separate item for each (potion_<effect>_<tier>).
# Drinking one (Inventory.use -> drink) restores, or puts a timed effect on you.
# A poison coats your weapon instead: the next few hits put venom in what they
# strike (effects/venom.tres: 3 a second for 10 s, per dose; doses stack to 5).

const EFFECTS := {
	"restore_health":  {"name": "Healing",     "restore": "health"},
	"restore_stamina": {"name": "Vigour",      "restore": "stamina"},
	"restore_magicka": {"name": "Clarity",     "restore": "magicka"},
	"regeneration":    {"name": "Regeneration", "effect": "potion_regeneration"},
	"swiftness":       {"name": "Swiftness",   "effect": "potion_swiftness"},
	"might":           {"name": "Might",       "effect": "potion_might"},
	"resist":          {"name": "Resistance",  "effect": "potion_resist"},
	"cure":            {"name": "Cure",        "cure": true},
	"poison":          {"name": "Poison",      "poison": true},
}
const TIER_NAMES := ["Weak", "", "Strong"]
const TIER_MULT := [1.0, 1.6, 2.4]
const RESTORE := 40.0          # a weak restoring potion
const DURATION := 45.0         # a weak timed potion, seconds
const POISON_HITS := 3         # a weak poison coats this many hits
const TIER_LEVELS := [0, 40, 75]   # Alchemy level for standard / strong
const BREW_XP := 6.0           # per potion, x the tier

var poison_hits_left := 0      # your weapon's coat
var poison_doses := 1          # venom per hit: 1 + the poison's tier


## The tier (0 weak, 1 standard, 2 strong) you'd brew at now.
func tier() -> int:
	var level: int = Skills.levels.get("alchemy", Skills.START_LEVEL)
	var t := 0
	for i in TIER_LEVELS.size():
		if level >= TIER_LEVELS[i]:
			t = i
	if "purity" in Character.perks:
		t += 1
	return mini(t, 2)


func potion_id(effect: String, t: int) -> String:
	return "potion_%s_%d" % [effect, t]


## The effects `ingredients` (item ids) would brew together: those at least two share.
func shared_effects(ingredients: Array) -> Array:
	var counts := {}
	for id in ingredients:
		var item := Inventory.get_item(id)
		if item == null:
			continue
		for effect in item.alchemy_effects:
			counts[effect] = counts.get(effect, 0) + 1
	var out := []
	for effect in EFFECTS:   # in a fixed order
		if counts.get(effect, 0) >= 2:
			out.append(effect)
	return out


## Why these can't be brewed, or "".
func why_not(ingredients: Array) -> String:
	if ingredients.size() < 2 or ingredients.size() > 3:
		return "Choose two or three ingredients."
	for id in ingredients:
		if Inventory.count(id) <= 0 or ingredients.count(id) > 1:
			return "Each ingredient once, and you need one of each."
	if shared_effects(ingredients).is_empty():
		return "They have nothing in common: it would only make sludge."
	return ""


## Brews: uses one of each (Efficient Brewer: maybe not) and gives a potion of every
## shared effect (Experimenter: one more with three; Master Brewer: two of each).
## Returns the potion ids made.
func brew(ingredients: Array) -> Array:
	if why_not(ingredients) != "":
		return []
	var made := []
	var t := tier()
	var each := 2 if "master_brewer" in Character.perks else 1
	for effect in shared_effects(ingredients):
		Inventory.add(potion_id(effect, t), each)
		for i in each:
			made.append(potion_id(effect, t))
	if ingredients.size() == 3 and "experimenter" in Character.perks and not made.is_empty():
		Inventory.add(made[0])
		made.append(made[0])
	for id in ingredients:
		if not ("efficient_brewer" in Character.perks and randf() < 0.25):
			Inventory.remove(id)
	Skills.add_xp("alchemy", BREW_XP * (t + 1) * made.size())
	return made


## Drinking a brewed (or bought) potion. Returns false if it isn't one.
func drink(item: ItemData, player: Node) -> bool:
	if item.potion_effect == "" or not EFFECTS.has(item.potion_effect):
		return false
	var def: Dictionary = EFFECTS[item.potion_effect]
	var mult: float = TIER_MULT[item.potion_tier] * Character.modifier("potion_potency")
	var stats: Stats = player.stats
	if "hardened_stomach" in Character.perks and stats.health < stats.max_health * 0.25:
		mult *= 1.5
	if def.has("restore"):
		var amount := RESTORE * mult * Character.modifier("restore_potency")
		match def["restore"]:
			"health":
				stats.heal(amount)
				if "field_medic" in Character.perks:
					_cure(player)
			"stamina":
				stats.stamina = minf(stats.stamina + amount, stats.max_stamina)
			"magicka":
				stats.magicka = minf(stats.magicka + amount, stats.max_magicka)
	elif def.has("effect"):
		player.effects.apply(def["effect"])
		player.effects.active[def["effect"]]["time_left"] = DURATION * TIER_MULT[item.potion_tier] * Character.modifier("potion_duration")
	elif def.get("cure", false):
		_cure(player)
	elif def.get("poison", false):
		poison_hits_left = roundi(POISON_HITS * TIER_MULT[item.potion_tier]) + (2 if "poisoner" in Character.perks else 0)
		poison_doses = 1 + item.potion_tier
		player.hud.notify("Your weapon is coated (%d hits)." % poison_hits_left)
	if "steady_hand" in Character.perks:
		stats.stamina = minf(stats.stamina + 10.0, stats.max_stamina)
	stats.changed.emit()
	return true


func _cure(player: Node) -> void:
	for id in player.effects.active.keys():
		if player.effects.active[id]["data"].is_harmful:
			player.effects.remove(id)


## A blow of yours landed on `target` (PlayerCombat calls this): the coat goes in.
func blade_hit(target: Node) -> void:
	var effects = target.get("effects")
	if poison_hits_left <= 0 or not effects is StatusEffects:
		return
	poison_hits_left -= 1
	effects.apply("venom", poison_doses + (1 if "potent_poisons" in Character.perks else 0))
	if "concentrated_poison" in Character.perks:
		Sight._apply(target, "bad_omen", 10.0)


func reset() -> void:
	poison_hits_left = 0
	poison_doses = 1


func to_dict() -> Dictionary:
	return {"poison_hits_left": poison_hits_left, "poison_doses": poison_doses}


func from_dict(data: Dictionary) -> void:
	poison_hits_left = int(data.get("poison_hits_left", 0))
	poison_doses = int(data.get("poison_doses", 1))
