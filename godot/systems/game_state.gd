extends Node

# Global game data that survives scene changes.
# Autoloaded as "GameState" (Project Settings > Globals > Autoload), so any
# script can read GameState.race or GameState.flags directly.

var race: String = "Human"   # set by character creation later
var flags: Dictionary = {}   # story memory, e.g. flags["met_maren"] = true


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func set_flag(flag_name: String) -> void:
	flags[flag_name] = true
