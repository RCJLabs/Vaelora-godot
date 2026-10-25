extends Node3D

# "Hallam and the Hundred Lights", sung round the fire on Lanternfast (put it
# under the Lanternfast StoryPresence, at the fire). While you're within
# `radius`, the next verse shows every VERSE_EVERY seconds; after the last, one
# Passenger voice sings the last line differently. Then "heard_hallam_sung".

@export var radius: float = 12.0

const VERSE_EVERY := 10.0
const VERSES := [
	"When the lights came down they were many, and hungry, / and they crept through the shutters to drink children's breath.",
	"Hallam the Lamplighter, a farmer's son, / took a lantern and hook when the long day was done.",
	"A hundred nights hunting, a light every night, / and he put each one out, and the valley grew bright.",
	"On the hundredth the last light begged him to stay. / \"You should have stayed in the sky,\" said Hallam, and walked away.",
]
const LAST := "Under the cheering, one voice, a Passenger's, sings the last line on its own: \"The lanterns are for finding. The lanterns are for finding.\""

var verse := 0
var _left := 1.0


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or player.global_position.distance_to(global_position) > radius:
		return
	_left -= delta
	if _left > 0.0:
		return
	_left = VERSE_EVERY
	var hud = player.get("hud")
	if verse < VERSES.size():
		if hud:
			hud.show_message("(Round the fire, they sing) " + VERSES[verse], VERSE_EVERY - 1.0)
	elif verse == VERSES.size():
		if hud:
			hud.show_message(LAST, VERSE_EVERY - 1.0)
		GameState.set_flag("heard_hallam_sung")
	else:
		verse = -1   # start again
	verse += 1
