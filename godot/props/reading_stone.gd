extends StaticBody3D

# Where to take a reading with the Collegium rune-glass (side quest "Readings
# Under the Wanderer"): at the stone circle, at night, once per night, three
# nights. Sets readings_1, readings_2, readings_3 in turn. A "night" runs from
# noon to noon, so 23:00 and 02:00 the same night count once.

const ITEM := "rune_glass"
const READINGS := 3
const RESULTS := [
	"The needle trembles, then points north. It shouldn't point anywhere: the stones' power is supposed to sit still, like water in a well. (Reading 1 of 3.)",
	"North again, steadier, and the crystal clouds at the edges as if something's being pulled through it. (Reading 2 of 3.)",
	"The needle points north and doesn't move at all, like a compass. The stones aren't waking. They're being drained, steadily, like a river running out of a lake. (Reading 3 of 3.)",
]

var prompt: String:
	get: return "Take a reading" if can_read() else ""


func can_read() -> bool:
	return Inventory.count(ITEM) > 0 and done_count() < READINGS and WorldClock.is_night() \
			and not GameState.has_flag(_tonight_flag())


func done_count() -> int:
	var count := 0
	for i in READINGS:
		if GameState.has_flag("readings_%d" % (i + 1)):
			count += 1
	return count


func interact(player: Node) -> void:
	if not can_read():
		if Inventory.count(ITEM) > 0 and done_count() < READINGS:
			player.show_message("Already read tonight. The glass needs a fresh night." if WorldClock.is_night() else "The rune-glass only works at night.")
		return
	var n := done_count()
	GameState.set_flag(_tonight_flag())
	GameState.set_flag("readings_%d" % (n + 1))
	player.show_message(RESULTS[n])


# Noon to noon: the small hours belong to the night before.
func _tonight_flag() -> String:
	return "reading_night_%d" % (WorldClock.day if WorldClock.hour >= 12.0 else WorldClock.day - 1)
