extends Node3D

# Brings wisps out at night: when night falls (WorldClock), `count` wisps
# appear within `radius` of this node; at dawn the survivors fade away. Killed
# ones come back the next night. They fight together (alert()).
#
# Once `drain_flag` is set (main quest 1 starts it), something is draining them:
# `drain_delay` seconds into each night, one calm wisp drifts into the crystal at
# this node's centre, dims, and streaks away north (wisp.drain_away). Only one a
# night, so the rest are still there to fight. The first time the player is
# close enough to see it, a message says so.

@export var count: int = 3
@export var radius: float = 7.0

## The story flag after which the wisps are being drained. Empty: never.
@export var drain_flag: String = "wrong_things_started"
## Seconds of night before one is drained (if none is calm then, it tries again every few seconds).
@export var drain_delay: float = 30.0
## Height of the crystal above this node: where drained wisps go.
@export var drain_height: float = 1.55
@export var witness_range: float = 25.0

const WISP_SCENE := preload("res://enemies/wisp.tscn")

var _night_active := false
var _drain_left := 0.0
var _drained_tonight := false


func _process(delta: float) -> void:
	var night := WorldClock.is_night()
	if night and not _night_active:
		_night_active = true
		_drain_left = drain_delay
		_drained_tonight = false
		_spawn()
	elif night and not _drained_tonight and draining():
		_drain_left -= delta
		if _drain_left <= 0.0:
			_drained_tonight = drain_one() != null
			_drain_left = 3.0   # nobody calm: try again shortly
	elif not night and _night_active:
		_night_active = false
		for wisp in get_children():
			if wisp.has_method("fade_out"):
				wisp.fade_out()


func draining() -> bool:
	return drain_flag != "" and GameState.has_flag(drain_flag)


## Drains one calm wisp. Returns it, or null if none was calm.
func drain_one() -> Node:
	for wisp in get_children():
		if wisp.has_method("drain_away") and wisp.drain_away(global_position + Vector3.UP * drain_height):
			var player := get_tree().get_first_node_in_group("player")
			if player and player.global_position.distance_to(global_position) < witness_range \
					and not GameState.has_flag("saw_wisp_drained"):
				GameState.set_flag("saw_wisp_drained")
				player.show_message("A wisp drifts into the crystal, dims, and streaks away north. Then it's gone.")
			return wisp
	return null


func _spawn() -> void:
	for i in count:
		var wisp := WISP_SCENE.instantiate()
		var angle := TAU * i / count + randf_range(-0.4, 0.4)
		wisp.position = Vector3(cos(angle), 0.0, sin(angle)) * randf_range(radius * 0.4, radius) + Vector3.UP * 1.8
		add_child(wisp)


## A wisp started fighting: the others join in.
func alert(_by: Node) -> void:
	for wisp in get_children():
		if wisp.has_method("join_hunt"):
			wisp.join_hunt()
