class_name PlayerFootsteps
extends Node

# Footstep sounds: one every stride while walking or running on the ground, and a
# louder one when landing. The sound depends on what's underfoot: put a floor's
# StaticBody3D in the group "surface_stone" or "surface_wood"; anything else
# counts as soft ground (grass, dirt). Sounds: assets/sfx/footstep_<surface>_1..3.

## Metres per step, walking and sprinting (longer strides when running).
const WALK_STRIDE := 1.6
const SPRINT_STRIDE := 2.3
const TAKES := 3
const VOLUME_DB := -10.0

@onready var player: CharacterBody3D = get_parent()

var _distance := 0.0


func update(delta: float, landed: bool, fall_speed: float) -> void:
	if not player.is_on_floor():
		return
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	if landed and fall_speed > 2.5:
		_step(clampf((fall_speed - 2.5) * 1.5, 0.0, 6.0))
		_distance = 0.0
		return
	if speed < 0.5:
		_distance = WALK_STRIDE * 0.6   # the first step comes soon after starting off
		return
	_distance += speed * delta
	var stride := SPRINT_STRIDE if speed > player.walk_speed * 1.1 else WALK_STRIDE
	if _distance >= stride:
		_distance -= stride
		_step(0.0)


func _step(extra_db: float) -> void:
	Sfx.play_any("footstep_" + surface(), TAKES, VOLUME_DB + extra_db)


## "stone", "wood" or "soft": what the player is standing on.
func surface() -> String:
	for i in player.get_slide_collision_count():
		var collision := player.get_slide_collision(i)
		if collision.get_normal().y < 0.7:
			continue   # a wall, not the floor
		var floor_body := collision.get_collider() as Node
		if floor_body == null:
			continue
		if floor_body.is_in_group("surface_stone"):
			return "stone"
		if floor_body.is_in_group("surface_wood"):
			return "wood"
	return "soft"
