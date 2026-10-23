class_name PlayerTraversal
extends Node

# Mantling and vaulting. A child of the Player called "Traversal".
#
#   Jump facing a ledge between MIN_LEDGE and MAX_LEDGE high: climb onto it.
#   Hold jump in the air near a ledge: grab it and pull up.
#   Sprint + jump at a low, thin obstacle (a fence, a crate edge): vault over it.
#
# It looks for a wall in front, then for a flat top with room to stand on it,
# and moves the player up and over along a short path (no physics during the
# move, so it can't get stuck halfway). Ledge heights are measured from your
# feet; you're 1.8 m tall.

const MIN_LEDGE := 0.45
const MAX_LEDGE := 2.1
## In the air you can grab a ledge up to this far above your feet.
const MAX_GRAB := 1.4
## Vaults: obstacles up to this high and this thick (metres), while sprinting.
const MAX_VAULT_HEIGHT := 1.25
const MAX_VAULT_DEPTH := 0.9
const STAMINA := 10.0
const REACH := 0.9            # how far in front to look for a wall
const BODY_RADIUS := 0.4
const BODY_HEIGHT := 1.8

var player: CharacterBody3D
var busy := false
var _path: Array = []          # [{"to": Vector3, "time": float}, ...]
var _from := Vector3.ZERO
var _segment_time := 0.0


var _hint_check := 0.0


func _ready() -> void:
	player = get_parent()


# Every half second while walking: a climbable ledge right in front? Hint once.
func _physics_process(delta: float) -> void:
	_hint_check -= delta
	if _hint_check > 0.0 or busy or not player.is_on_floor() or GameState.has_flag("hint_climb"):
		return
	_hint_check = 0.5
	if Vector2(player.velocity.x, player.velocity.z).length() > 1.0 and not find_ledge().is_empty():
		Hints.show_once("climb", "Press %s facing a ledge to climb onto it, or sprint and jump at a low fence to vault it." % Hints.key("jump"))


## Tries to start a mantle or vault. Returns true if it did (then don't jump).
## `in_air`: grabbing a ledge mid-jump (lower reach).
func try_start(in_air: bool, sprinting: bool) -> bool:
	if busy or player.stats.stamina < STAMINA:
		return false
	var ledge := find_ledge(in_air)
	if ledge.is_empty():
		return false
	var forward: Vector3 = ledge["forward"]
	var top: Vector3 = ledge["top"]
	var height: float = ledge["height"]
	_path = []
	var vault: bool = ledge.has("landing") and not in_air and (sprinting or not ledge["deep"])
	if vault:
		# Vault: up, over the top, and down the far side, all in one quick move.
		var over := top + forward * 0.2 + Vector3.UP * 0.15
		_path.append({"to": over, "time": 0.12 + height * 0.08})
		_path.append({"to": ledge["landing"], "time": 0.2})
		Skills.add_xp("athletics", 1.5)
	else:
		# Mantle: rise to the top of the ledge, then step onto it.
		var rise := Vector3(player.global_position.x, top.y + 0.05, player.global_position.z) + forward * 0.15
		_path.append({"to": rise, "time": 0.15 + height * 0.17})
		_path.append({"to": top + forward * 0.35 + Vector3.UP * 0.05, "time": 0.16})
		Skills.add_xp("athletics", 1.0 + height)
	player.stats.use_stamina(STAMINA * player.stats.modifier("climb_stamina"))
	busy = true
	_from = player.global_position
	_segment_time = 0.0
	player.velocity = Vector3.ZERO
	player.camera_kick(Vector3(-4.0 if _path.size() == 2 and height > 1.0 else -2.0, 0.0, 0.0))
	Sfx.play("dodge", -8.0)
	return true


## Moves the player along the path. Called by the player instead of its
## normal movement while busy.
func update(delta: float) -> void:
	if _path.is_empty():
		busy = false
		return
	var segment: Dictionary = _path[0]
	_segment_time += delta
	var t := clampf(_segment_time / maxf(segment["time"], 0.01), 0.0, 1.0)
	player.global_position = _from.lerp(segment["to"], ease(t, -1.8))
	if t >= 1.0:
		_from = segment["to"]
		_segment_time = 0.0
		_path.pop_front()
		if _path.is_empty():
			busy = false
			player.velocity = -player.global_transform.basis.z * 1.5   # a little momentum


## Looks for something to climb in front of the player. Returns {} or
## {"top": Vector3, "height": float, "forward": Vector3, "landing": Vector3 (vaults only)}.
func find_ledge(in_air: bool = false) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var feet := player.global_position
	var forward := -player.global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# 1. A wall in front, somewhere between knee and head height.
	var wall := {}
	for height: float in [0.35, 0.9, 1.5]:
		var from := feet + Vector3.UP * height
		wall = _ray(space, from, from + forward * REACH)
		if not wall.is_empty():
			break
	if wall.is_empty() or wall["normal"].y > 0.5:
		return {}
	# 2. The top of it: look down just past the wall's face (close, so thin
	# things like fences are found too).
	var max_height := MAX_GRAB if in_air else MAX_LEDGE
	var probe: Vector3 = wall["position"] + forward * 0.05
	probe.y = feet.y + max_height + 0.3
	var top := _ray(space, probe, Vector3(probe.x, feet.y + MIN_LEDGE * (0.4 if in_air else 1.0), probe.z))
	if top.is_empty() or top["normal"].y < 0.7:
		return {}
	var height: float = top["position"].y - feet.y
	if height > max_height or (not in_air and height < MIN_LEDGE):
		return {}
	# 3. Room for the head on the way up, and room to stand on top.
	var head := feet + Vector3.UP * (BODY_HEIGHT - 0.1)
	if not _ray(space, head, head + Vector3.UP * (height + 0.15)).is_empty():
		return {}
	var stand: Vector3 = top["position"] + forward * 0.35
	var room_on_top := _fits(space, stand)
	var result := {"top": top["position"], "height": height, "forward": forward}
	# Deep enough to stand on? (A fence top isn't: you vault it instead.)
	var deeper: Vector3 = top["position"] + forward * 0.4
	var second := _ray(space, deeper + Vector3.UP * 0.3, deeper + Vector3.DOWN * 0.3)
	result["deep"] = not second.is_empty() and absf(second["position"].y - top["position"].y) < 0.2
	# 4. Vaults: is it thin, with ground on the far side?
	var far: Vector3 = wall["position"] + forward * (MAX_VAULT_DEPTH + BODY_RADIUS)
	var beyond := _ray(space, Vector3(far.x, top["position"].y + 0.2, far.z), Vector3(far.x, feet.y - 0.6, far.z))
	if height <= MAX_VAULT_HEIGHT and not beyond.is_empty() and absf(beyond["position"].y - feet.y) < 0.5 and _fits(space, beyond["position"]):
		result["landing"] = beyond["position"] + Vector3.UP * 0.02
	if not (result["deep"] and room_on_top) and not result.has("landing"):
		return {}   # nowhere to stand on top and no way over
	return result


func _ray(space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)   # the world only
	query.exclude = [player.get_rid()]
	return space.intersect_ray(query)


# Would a standing player fit with their feet at `feet`?
func _fits(space: PhysicsDirectSpaceState3D, feet: Vector3) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = BODY_RADIUS - 0.05
	capsule.height = BODY_HEIGHT - 0.1
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.collision_mask = 1
	query.transform = Transform3D(Basis(), feet + Vector3.UP * (BODY_HEIGHT * 0.5 + 0.05))
	query.exclude = [player.get_rid()]
	return space.intersect_shape(query, 1).is_empty()
