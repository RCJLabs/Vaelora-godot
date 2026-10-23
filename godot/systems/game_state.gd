extends Node

# Global game data that survives scene changes.
# Autoloaded as "GameState" (Project Settings > Globals > Autoload), so any
# script can read GameState.race or GameState.flags directly.

const DEFAULT_RACE := "res://races/human.tres"

var race: String = "Human"        # name only, used by dialogue conditions
var race_data: RaceData           # full stats/modifiers of the chosen race
var flags: Dictionary = {}        # story memory, e.g. flags["met_maren"] = true


func _ready() -> void:
	# Lets levels run on their own (F6) without going through character creation.
	set_race(load(DEFAULT_RACE))


func set_race(data: RaceData) -> void:
	race_data = data
	race = data.display_name


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func set_flag(flag_name: String) -> void:
	flags[flag_name] = true
