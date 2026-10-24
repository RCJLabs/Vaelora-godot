extends "res://enemies/bandit.gd"

# A hooded cultist: one of the people doing the draining (main quest 4, "The
# Barrow"). Fights exactly like a bandit (bandit.tscn with this script swapped
# in), but in grey-violet robes, and doesn't take prisoners: beaten by one in
# Hardcore you're found or left for dead, never caged.

## Stays still, unseeing, until this story flag is set (e.g. their hidden room is
## opened), so they don't press against a wall at a player on the other side.
@export var wait_for_flag: String = ""

const ROBE := Color(0.2, 0.18, 0.24)
const HOOD := Color(0.12, 0.11, 0.15)
const MASK := Color(0.75, 0.8, 0.78)


func _ready() -> void:
	super()
	remove_from_group("captors")
	_cloth.albedo_color = ROBE
	_cloth_color = ROBE
	for part in [["Hood", HOOD], ["Mask", MASK], ["LegL", ROBE], ["LegR", ROBE]]:
		var mesh := get_node_or_null("Model/" + part[0]) as MeshInstance3D
		if mesh:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = part[1]
			mesh.material_override = mat
	if wait_for_flag != "" and not GameState.has_flag(wait_for_flag) and state != State.DEAD:
		set_physics_process(false)
		GameState.flag_set.connect(func(flag): if flag == wait_for_flag: set_physics_process(true))
