extends StaticBody3D

# The roadside shrine (side quest "Silent Shrine"). Its prayers stopped working.
# Until it's rekindled, using it (E) opens res://dialogue/shrine.json: pray (nothing
# answers), read the inscription, offer Wisp Essence ("shrine_rekindled").
# Rekindled, the candle burns bright, and praying:
#   - after dark, the first time: something answers ("shrine_answered");
#   - otherwise heals you fully and blesses you, once a day.

const DIALOGUE := "res://dialogue/shrine.json"

@onready var candle_light: OmniLight3D = $CandleLight

var prompt: String = "Pray at the shrine"
var _base_energy := 0.5


func _ready() -> void:
	_base_energy = candle_light.light_energy
	if GameState.has_flag("shrine_rekindled"):
		_kindle(false)
	GameState.flag_set.connect(func(flag): if flag == "shrine_rekindled": _kindle(true))


func interact(player: Node) -> void:
	if not GameState.has_flag("shrine_rekindled"):
		DialogueManager.start(DIALOGUE, "Roadside shrine")
		return
	if WorldClock.is_night() and not GameState.has_flag("shrine_answered"):
		GameState.set_flag("shrine_answered")
		player.show_message("You say the old words in the dark, and something answers. Not a voice: a pull, faint and patient, from somewhere above and to the north, the way the tide pulls at a boat. Then the candle steadies, and you're alone again.")
		return
	var today := "shrine_blessed_day_%d" % WorldClock.day
	if GameState.has_flag(today):
		player.show_message("The candle burns steady. You've had today's blessing.")
		return
	GameState.set_flag(today)
	player.stats.refill()
	player.effects.apply("blessing")
	player.show_message("Warmth runs through you, and every ache eases. The shrine remembers how.")


func _kindle(animate: bool) -> void:
	candle_light.light_color = Color(1, 0.85, 0.6)
	# The candle flickers (flicker_light.gd), so turn up what it flickers around.
	if animate:
		create_tween().tween_method(candle_light.set_base_energy, _base_energy, _base_energy * 4.0, 1.5)
	else:
		candle_light.set_base_energy(_base_energy * 4.0)
