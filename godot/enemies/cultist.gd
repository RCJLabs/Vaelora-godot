extends "res://enemies/bandit.gd"

# A hooded cultist: one of the people doing the draining (main quest 4, "The
# Barrow"). Fights exactly like a bandit (bandit.tscn with this script swapped
# in), but in grey-violet robes, and doesn't take prisoners: beaten by one in
# Hardcore you're found or left for dead, never caged.

## Stays still, unseeing, until this story flag is set (e.g. their hidden room is
## opened), so they don't press against a wall at a player on the other side.
@export var wait_for_flag: String = ""

const ROBE := Color(0.2, 0.18, 0.24)


func _ready() -> void:
	if look_role == "bandit":   # the scene's default: dress as the Mercy, unless the level chose
		look_role = "mercy"
		look_cloth = ROBE
	super()
	remove_from_group("captors")
	if wait_for_flag != "" and not GameState.has_flag(wait_for_flag) and state != State.DEAD:
		set_physics_process(false)
		GameState.flag_set.connect(func(flag): if flag == wait_for_flag: set_physics_process(true))


## The Mercy are hollowing mages: humans, elves and Passengers.
func vary_races() -> Array:
	return ["human", "human", "elf", "passenger"]


## The Mercy dress alike.
func vary_cloths() -> Array:
	return []
