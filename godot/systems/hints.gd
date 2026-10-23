extends Node

# One-time tutorial hints: the first time something happens, a short tip
# appears above the prompt. Autoloaded as "Hints".
#   Hints.show_once("parry", "Block just before a hit to parry it.")
# Each hint shows once per character (remembered as a story flag, so it's
# saved), and not at all with Settings > Tutorial hints off. Button names come
# from InputHints, so they match the keyboard or gamepad.


func show_once(id: String, text: String) -> void:
	var flag := "hint_" + id
	if not Settings.show_hints or GameState.has_flag(flag):
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	GameState.set_flag(flag)
	player.hud.show_hint(text)


## "[Right-click]" or "[LT]": the button for an action, for hint text.
func key(action: String) -> String:
	return "[%s]" % InputHints.label(action)
