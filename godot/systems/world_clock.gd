extends Node

# The time of day. Autoloaded as "WorldClock".
#   WorldClock.hour        0.0 - 24.0 (fractional: 13.5 = half past one in the afternoon)
#   WorldClock.day         1, 2, 3...
#   WorldClock.advance(8)  skip ahead (sleeping)
# Time runs TIME_SCALE times faster than real time while you play (Skyrim uses 20:
# a day lasts 72 real minutes), and stops in menus, conversations and interiors'
# loading. Survival needs and the day/night lighting (levels/day_night.gd) read it.

signal hour_passed(day: int, hour: int)   # every in-game hour, on the hour
signal advanced(hours: float)            # skipped ahead (sleep)

const TIME_SCALE := 20.0
const START_HOUR := 8.0

var day := 1
var hour := START_HOUR


func _process(delta: float) -> void:
	if get_tree().paused or get_tree().get_first_node_in_group("player") == null or DialogueManager.is_active:
		return
	_add_hours(delta * TIME_SCALE / 3600.0)


## Skips `hours` ahead at once (sleeping, waiting).
func advance(hours: float) -> void:
	_add_hours(hours)
	advanced.emit(hours)


func _add_hours(hours: float) -> void:
	var before := floori(hour)
	hour += hours
	while hour >= 24.0:
		hour -= 24.0
		day += 1
	if floori(hour) != before:
		hour_passed.emit(day, floori(hour))


## Hours until the next `target` o'clock (e.g. 6.0 for dawn).
func hours_until(target: float) -> float:
	return fposmod(target - hour, 24.0)


func is_night() -> bool:
	return hour < 6.0 or hour >= 20.0


## 0 at midnight, 1 at noon: how bright and warm the day is.
func daylight() -> float:
	return clampf(sin((hour - 6.0) / 12.0 * PI) * 1.3, 0.0, 1.0)


## "Day 3, 14:05"
func text() -> String:
	var minutes := int(hour * 60.0)
	return "Day %d, %02d:%02d" % [day, minutes / 60, minutes % 60]


func reset() -> void:
	day = 1
	hour = START_HOUR


func to_dict() -> Dictionary:
	return {"day": day, "hour": hour}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	hour = float(data.get("hour", START_HOUR))
