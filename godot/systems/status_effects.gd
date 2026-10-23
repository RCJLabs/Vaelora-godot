class_name StatusEffects
extends Node

# The status effects currently on one character. Add as a child named
# "StatusEffects" next to its "Stats" node (player, wolves, any NPC).
#   $StatusEffects.apply("bleeding")      $StatusEffects.has("burning")
#   $StatusEffects.modifier("move_speed") -> 1.0 if nothing changes it
#
# Damage/healing over time is applied to the sibling Stats node.

signal changed

@export var stats_path: NodePath = ^"../Stats"

# effect id -> {"data": StatusEffectData, "time_left": float, "stacks": int}
var active: Dictionary = {}

@onready var _stats: Stats = get_node_or_null(stats_path)


## Applies an effect by id (or StatusEffectData). Returns true if it changed anything.
func apply(effect, stacks: int = 1) -> bool:
	var data: StatusEffectData = effect if effect is StatusEffectData else EffectLibrary.get_effect(effect)
	if data == null or (_stats and _stats.is_dead):
		return false
	if active.has(data.id):
		var entry: Dictionary = active[data.id]
		match data.stacking:
			StatusEffectData.Stacking.IGNORE:
				return false
			StatusEffectData.Stacking.STACK:
				entry["stacks"] = mini(entry["stacks"] + stacks, data.max_stacks)
		entry["time_left"] = data.duration
	else:
		active[data.id] = {"data": data, "time_left": data.duration, "stacks": mini(stacks, data.max_stacks)}
	changed.emit()
	return true


func remove(id: String) -> void:
	if active.erase(id):
		changed.emit()


func clear() -> void:
	active.clear()
	changed.emit()


func has(id: String) -> bool:
	return active.has(id)


func stacks(id: String) -> int:
	return active[id]["stacks"] if active.has(id) else 0


## Product of every active effect's multiplier for `key` (once per stack).
func modifier(key: String) -> float:
	var result := 1.0
	for entry in active.values():
		var data: StatusEffectData = entry["data"]
		if data.modifiers.has(key):
			result *= pow(float(data.modifiers[key]), entry["stacks"])
	return result


func _process(delta: float) -> void:
	if active.is_empty():
		return
	if _stats and _stats.is_dead:
		clear()
		return
	var expired := []
	for id in active:
		var entry: Dictionary = active[id]
		var data: StatusEffectData = entry["data"]
		var n: int = entry["stacks"]
		if _stats:
			if data.health_per_second < 0.0:
				_stats.take_damage(-data.health_per_second * n * delta, true)
			elif data.health_per_second > 0.0:
				_stats.heal(data.health_per_second * n * delta)
			if data.stamina_per_second != 0.0:
				_stats.stamina = clampf(_stats.stamina + data.stamina_per_second * n * delta, 0.0, _stats.max_stamina)
			if data.magicka_per_second != 0.0:
				_stats.magicka = clampf(_stats.magicka + data.magicka_per_second * n * delta, 0.0, _stats.max_magicka)
		if data.duration > 0.0:
			entry["time_left"] -= delta
			if entry["time_left"] <= 0.0:
				expired.append(id)
		if _stats and _stats.is_dead:
			break
	for id in expired:
		active.erase(id)
	changed.emit()


func to_array() -> Array:
	var out := []
	for id in active:
		out.append({"id": id, "time_left": active[id]["time_left"], "stacks": active[id]["stacks"]})
	return out


func from_array(data: Array) -> void:
	active.clear()
	for e in data:
		var effect := EffectLibrary.get_effect(e["id"])
		if effect:
			active[e["id"]] = {"data": effect, "time_left": float(e["time_left"]), "stacks": int(e["stacks"])}
	changed.emit()
