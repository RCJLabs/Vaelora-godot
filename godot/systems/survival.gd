extends Node

# Survival mode (chosen at character creation): hunger, thirst, fatigue and
# cold. Autoloaded as "Survival". Does nothing for characters without the mode.
#
# Each need runs 0 (fine) to 100 (dire). Passing 25 / 50 / 75 gives the stage's
# status effect (effects/survival_*.tres): small penalties at first, serious
# ones at the end. Food and drink (items with ease_* values) bring them down,
# sleeping (beds, campfires: RestMenu) clears fatigue, and fires, shelter and
# daylight warm you up. Rates are per in-game hour (WorldClock).

signal changed

const NEEDS := ["hunger", "thirst", "fatigue", "cold"]
## Rise per in-game hour while awake. Asleep, hunger and thirst rise at half speed.
const RATES := {"hunger": 3.0, "thirst": 4.0, "fatigue": 3.5}
## Fatigue recovered per hour of sleep (8 hours clears it).
const SLEEP_RECOVERY := 12.5
## Cold, per in-game hour: outdoors at night, at dawn/dusk, by day, and indoors or by a fire.
const COLD_NIGHT := 12.0
const COLD_TWILIGHT := 3.0
const COLD_DAY := -10.0
const COLD_SHELTER := -60.0
const STAGES := [25.0, 50.0, 75.0]
const EFFECTS := {
	"hunger": ["peckish", "hungry", "starving"],
	"thirst": ["thirsty", "parched", "dehydrated"],
	"fatigue": ["tired", "weary", "exhausted"],
	"cold": ["chilly", "cold", "freezing"],
}

var values := {"hunger": 0.0, "thirst": 0.0, "fatigue": 0.0, "cold": 0.0}


func active() -> bool:
	return bool(Character.modes.get("survival", false))


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not active() or player == null or get_tree().paused or DialogueManager.is_active or player.is_dead:
		return
	tick(delta * WorldClock.TIME_SCALE / 3600.0, false)


## `hours` of in-game time passing (asleep or awake).
func tick(hours: float, sleeping: bool) -> void:
	if not active():
		return
	var slow := 0.5 if sleeping else 1.0
	values["hunger"] += RATES["hunger"] * hours * slow
	values["thirst"] += RATES["thirst"] * hours * slow
	values["fatigue"] += (-SLEEP_RECOVERY if sleeping else RATES["fatigue"]) * hours
	values["cold"] += _cold_rate(sleeping) * hours
	for need in NEEDS:
		values[need] = clampf(values[need], 0.0, 100.0)
	_apply_effects()
	changed.emit()


## Eating / drinking: lowers each need by the item's ease_* amounts.
func ease(item: ItemData) -> void:
	if not active():
		return
	values["hunger"] = maxf(values["hunger"] - item.ease_hunger, 0.0)
	values["thirst"] = maxf(values["thirst"] - item.ease_thirst, 0.0)
	values["fatigue"] = maxf(values["fatigue"] - item.ease_fatigue, 0.0)
	values["cold"] = maxf(values["cold"] - item.ease_cold, 0.0)
	_apply_effects()
	changed.emit()


## 0, 1, 2 or 3: which stage a need is at.
func stage(need: String) -> int:
	var result := 0
	for threshold in STAGES:
		if values[need] >= threshold:
			result += 1
	return result


## Is the player indoors (a level without day and night) or next to a fire?
func sheltered() -> bool:
	var player := get_tree().get_first_node_in_group("player")
	var level := get_tree().current_scene
	if level and level.find_child("DayNight", false, false) == null:
		return true
	if player:
		for source in get_tree().get_nodes_in_group("heat_source"):
			var radius = source.get("heat_radius")
			if source.global_position.distance_to(player.global_position) <= (radius if radius != null else 4.0):
				return true
	return false


func _cold_rate(sleeping: bool) -> float:
	if sheltered():
		return COLD_SHELTER
	var light := WorldClock.daylight()
	var rate := COLD_NIGHT if light <= 0.0 else (COLD_TWILIGHT if light < 0.6 else COLD_DAY)
	return rate * (1.5 if sleeping and rate > 0.0 else 1.0)   # sleeping rough is colder


func _apply_effects() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var effects: StatusEffects = player.effects
	for need in NEEDS:
		var current := stage(need)
		for i in 3:
			var id: String = "survival_" + EFFECTS[need][i]
			if i == current - 1:
				if not effects.has(id):
					effects.apply(id)
					_hint(need)
			elif effects.has(id):
				effects.remove(id)


func _hint(need: String) -> void:
	if need == "cold":
		Hints.show_once("cold", "You're getting cold. Nights are cold outdoors: stand by a campfire or go indoors to warm up.")
	else:
		Hints.show_once("survival", "Survival: eat and drink from %s → Inventory, and sleep at a bed or campfire. Your needs show in %s → Skills." % [Hints.key("character_menu"), Hints.key("character_menu")])


## "Hunger 32%   Thirst 41%   Fatigue 20%   Cold 0%"
func text() -> String:
	var parts := []
	for need in NEEDS:
		parts.append("%s %d%%" % [need.capitalize(), roundi(values[need])])
	return "   ".join(parts)


func reset() -> void:
	values = {"hunger": 0.0, "thirst": 0.0, "fatigue": 0.0, "cold": 0.0}
	changed.emit()


func to_dict() -> Dictionary:
	return values.duplicate()


func from_dict(data: Dictionary) -> void:
	reset()
	for need in NEEDS:
		values[need] = float(data.get(need, 0.0))
	# Effects come back with the player's save; re-check them once it exists.
	_apply_effects.call_deferred()
