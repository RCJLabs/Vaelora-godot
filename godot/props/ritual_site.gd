extends Node3D

# The cult's ritual site at the Hollow Oak (main quest 5, "What They Made").
# By day it's an empty clearing (the first visit says so: "come back after
# dark"). At night, the first time the player comes within `radius`, the ritual
# is under way: `started_flag` is set (the cultists, waiting on it, wake), and
# the Arena (a BossArena around the oak) starts watching for the player, which
# wakes the boss and shows its health bar. Everything in `hidden_until_start`
# (the boss, the cultists) is invisible, frozen and untouchable until then.

@export var arena: NodePath
@export var boss: NodePath
@export var hidden_until_start: Array[NodePath] = []
@export var radius: float = 20.0
@export var require_night: bool = true
@export var started_flag: String = "ritual_started"
@export var slain_flag: String = "first_slain"
## Set the first time you come by day (so the day message shows once). Each site its own.
@export var seen_by_day_flag: String = "ritual_site_seen_by_day"
@export_multiline var day_message: String = "A clearing around a great hollow oak: a cold fire pit, a stone slab, cage marks in the moss. Nobody here. The notes said: in the dark of the Wanderer. Come back after nightfall."
@export_multiline var night_message: String = "Hooded figures stand around the oak, chanting. In the hollow's shadow something huge shifts, and the light leaking out of it is the colour of the wisps."

var _started := false
var _layers := {}   # hidden node -> its collision layer


func _ready() -> void:
	var arena_node: Area3D = get_node_or_null(arena)
	if GameState.has_flag(slain_flag):
		_started = true
		var boss_node := get_node_or_null(boss)
		if boss_node and not boss_node.is_defeated():
			boss_node.queue_free()   # killed on an earlier visit
		return
	if arena_node:
		arena_node.monitoring = false   # no fight until the ritual has begun
	for path in hidden_until_start:
		_set_hidden(get_node_or_null(path), true)


func _physics_process(_delta: float) -> void:
	if _started:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or player.global_position.distance_to(global_position) > radius:
		return
	if require_night and not WorldClock.is_night():
		if not GameState.has_flag(seen_by_day_flag):
			GameState.set_flag(seen_by_day_flag)
			player.show_message(day_message)
		return
	start(player)


## The ritual begins: the cultists wake and the arena arms.
func start(player: Node3D) -> void:
	if _started:
		return
	_started = true
	for path in hidden_until_start:
		_set_hidden(get_node_or_null(path), false)
	GameState.set_flag(started_flag)
	Sfx.play_at("ritual_drone", global_position)
	player.show_message(night_message)
	var arena_node: Area3D = get_node_or_null(arena)
	if arena_node:
		arena_node.monitoring = true
	var boss_node := get_node_or_null(boss)
	if boss_node and boss_node.has_method("wake"):
		# Already standing in the arena when it arms: the fight starts anyway.
		if arena_node and arena_node.overlaps_body(player):
			arena_node._on_body_entered(player)


# Hides a node and everything in it: invisible, not processing, no collision.
func _set_hidden(node: Node, hide_it: bool) -> void:
	if node == null:
		return
	node.visible = not hide_it
	node.process_mode = Node.PROCESS_MODE_DISABLED if hide_it else Node.PROCESS_MODE_INHERIT
	var bodies: Array = node.find_children("*", "CollisionObject3D", true, false)
	if node is CollisionObject3D:
		bodies.append(node)
	for body in bodies:
		if hide_it:
			_layers[body] = body.collision_layer
			body.collision_layer = 0
		elif _layers.has(body):
			body.collision_layer = _layers[body]


func is_started() -> bool:
	return _started
