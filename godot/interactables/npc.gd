extends StaticBody3D

# A character you can talk to. Set Display Name and Dialogue File in the Inspector.
# Set Race and Role and the game swaps the plain capsule for a greybox person
# (systems/figure.gd) in the capsule's colour, or Cloth's if you set one.
# Tick Routine and they keep a day by the clock (see "Routine" below).
# Crouched, E picks their pocket instead of talking; guards stop you while you
# have a bounty here (systems/crime.gd, docs/godot-starter/CRIME.md).

@export var display_name: String = "Stranger"
@export_file("*.json") var dialogue_file: String
## A race's file name in races/ (human, elf, orc, small_folk, deepfolk, ashen, passenger). Empty: keep the capsule.
@export var race := ""
## What they do, which decides what they wear: one of Figure.ROLES (guard, merchant, priest...).
@export var role := "commoner"
## Their clothes' colour. Left clear, the capsule's colour.
@export var cloth := Color(0, 0, 0, 0)
@export var sitting := false

@export_group("Routine")
## A day by the clock: from Wake Hour at the spot they were placed, wandering a
## little; from Gather Hour at the level's "Gathering" marker (a Marker3D, if it has
## one: the inn, the square), with the others; from Sleep Hour, home: they walk to
## the nearest free door in the "home_door" group and go in, until morning. No door
## nearby: they stay out. Off: they stand where they were placed, all day.
## docs/godot-starter/ROUTINES.md.
@export var routine := false
@export var wake_hour := 7.0
@export var gather_hour := 18.0
@export var sleep_hour := 21.5
## How far they wander from their spot by day (metres).
@export var wander := 3.0

enum Phase { DAY, GATHER, HOME }
const WALK_SPEED := 1.3
const HOME_RANGE := 60.0   # the furthest a door can be and still be theirs

var phase := -1
var inside := false        # gone in for the night: hidden, no collision
var _spot := Vector3.ZERO  # where they stand by day
var _facing := 0.0         # and which way they face there (back to it when they stop)
var _home: Node3D          # their door
var _gather: Node3D
var _path := PackedVector3Array()
var _idle := 0.0
var _last_hour := -1.0
var _layer := 1
var _rng := RandomNumberGenerator.new()
var _walked := 0.0
var _set_up := false
var _watch := 0.0          # guards: seconds to the next look for wanted people

var prompt: String:
	get:
		if _picking():
			var why := Crime.why_not_pick(self)
			if why != "":
				return why
			return "Pickpocket %s (%d%%)%s" % [display_name, roundi(Crime.pick_chance(self) * 100.0), Crime.watched_tag(self)]
		return "Talk to %s" % display_name


func _ready() -> void:
	add_to_group("people")   # witnesses (systems/crime.gd)
	if race != "":
		_dress()
	if routine:
		_spot = global_position
		_facing = rotation.y
		_layer = collision_layer
		_rng.seed = hash(name)
		_setup_routine.call_deferred()
	elif role != "guard":
		set_physics_process(false)


func _setup_routine() -> void:
	var scene := get_tree().current_scene
	_gather = scene.find_child("Gathering", true, false) as Node3D if scene else null
	var best := HOME_RANGE
	for door in get_tree().get_nodes_in_group("home_door"):
		if door.has_meta("home_of") or not door is Node3D:
			continue
		var d: float = door.global_position.distance_to(_spot)
		if d < best:
			best = d
			_home = door
	if _home:
		_home.set_meta("home_of", name)
	_set_up = true


## Where the clock says they should be.
func phase_for(hour: float) -> Phase:
	var sleeping := hour >= sleep_hour or hour < wake_hour
	if sleeping and _home:
		return Phase.HOME
	if hour >= gather_hour and hour < sleep_hour and _gather:
		return Phase.GATHER
	return Phase.DAY


func _physics_process(delta: float) -> void:
	if role == "guard":
		_watch_for_wanted(delta)
	if not _set_up:
		return
	var hour := WorldClock.hour
	var jumped := _last_hour >= 0.0 and absf(fposmod(hour - _last_hour + 12.0, 24.0) - 12.0) > 0.5   # slept, waited, travelled
	var first := _last_hour < 0.0
	_last_hour = hour
	var now := phase_for(hour)
	if now != phase or jumped:
		phase = now
		_head_for(_target(), first or jumped)
	if DialogueManager.is_active:
		return   # nobody walks off mid-sentence
	if _path.is_empty():
		if not inside:   # stood still: face the stall again, or the others at the gathering
			var face := _facing
			if phase == Phase.GATHER:
				var to_middle := _gather.global_position - global_position
				face = atan2(-to_middle.x, -to_middle.z)
			rotation.y = lerp_angle(rotation.y, face, minf(4.0 * delta, 1.0))
		if phase == Phase.DAY and wander > 0.0 and not inside:
			_idle -= delta
			if _idle <= 0.0:
				_idle = _rng.randf_range(6.0, 14.0)
				var a := _rng.randf() * TAU
				_head_for(_spot + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.5, wander), false)
		return
	var next := _path[0]
	var to := next - global_position
	to.y = 0.0
	var step := WALK_SPEED * delta
	if to.length() <= step:
		global_position = Vector3(next.x, next.y if absf(next.y - global_position.y) < 1.5 else global_position.y, next.z)
		_path.remove_at(0)
		if _path.is_empty() and phase == Phase.HOME:
			_go_in()
	else:
		global_position += to.normalized() * step
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), minf(8.0 * delta, 1.0))   # faces -Z
	_walked += step
	var figure := get_node_or_null("Figure") as Node3D
	if figure:
		figure.position.y = absf(sin(_walked * 4.0)) * 0.04   # a step's bob
		figure.rotation.z = sin(_walked * 4.0) * 0.03


## Where this phase wants them (on the ground).
func _target() -> Vector3:
	match phase:
		Phase.HOME:
			return door_step()
		Phase.GATHER:
			var a := float(absi(hash(name)) % 360) * PI / 180.0
			return _gather.global_position + Vector3(cos(a), 0, sin(a)) * 2.5
	return _spot


## Just outside their front door, on the ground (the door's middle is a metre up).
func door_step() -> Vector3:
	var front: Vector3 = _home.global_basis.z.normalized()
	return _home.global_position + front * 0.8 - Vector3(0, 1.0, 0)


## Set off for `to` along the navigation mesh (or straight there); with `snap`, just be there.
func _head_for(to: Vector3, snap: bool) -> void:
	if snap:
		_path = PackedVector3Array()
		global_position = to
		if phase == Phase.HOME:
			_go_in()
		else:
			_come_out()
		return
	if inside:
		_come_out()
		global_position = door_step()   # out of their own front door
	var map := get_world_3d().navigation_map
	_path = NavigationServer3D.map_get_path(map, global_position, to, true)
	if _path.is_empty():
		_path = PackedVector3Array([to])


func _go_in() -> void:
	inside = true
	visible = false
	collision_layer = 0


func _come_out() -> void:
	if not inside:
		return
	inside = false
	visible = true
	collision_layer = _layer


func interact(_player: Node) -> void:
	if _picking():
		Crime.pickpocket(self)
		return
	if role == "guard" and Crime.bounty_here() > 0:
		DialogueManager.start(Crime.GUARD_DIALOGUE, display_name)
		return
	DialogueManager.start(dialogue_file, display_name)


## Crouched at someone with pockets worth picking (guards have none).
func _picking() -> bool:
	return Stealth.is_sneaking() and Crime.why_not_pick(self) != "no"


## A guard who sees you while you have a bounty here stops you (twice a second).
func _watch_for_wanted(delta: float) -> void:
	_watch -= delta
	if _watch > 0.0:
		return
	_watch = 0.5
	if Crime.bounty_here() <= 0 or not Crime.guards_may_stop() or DialogueManager.is_active or get_tree().paused:
		return
	var player := Crime.player()
	if player == null or player.get("is_dead") == true or not Crime.sees(self, Crime.GUARD_RANGE):
		return
	DialogueManager.start(Crime.GUARD_DIALOGUE, display_name)


func _dress() -> void:
	var capsule := get_node_or_null("MeshInstance3D") as MeshInstance3D
	var colour := cloth
	if colour.a == 0.0:
		colour = Color(0.4, 0.38, 0.35)
		if capsule and capsule.mesh and capsule.mesh.surface_get_material(0) is StandardMaterial3D:
			colour = capsule.mesh.surface_get_material(0).albedo_color
	if capsule:
		capsule.visible = false
	add_child(Figure.build(race, role, colour, sitting))
	# Fit the collision capsule to their height (the interact ray aims at it).
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	var height := Figure.height_of(race) * (0.62 if role == "child" else 1.0)
	if shape and shape.shape is CapsuleShape3D and not sitting and not is_equal_approx(height, 1.0):
		var fitted := shape.shape.duplicate() as CapsuleShape3D
		fitted.height = maxf(fitted.height * height, fitted.radius * 2.0)
		shape.shape = fitted
		shape.position.y = fitted.height / 2.0
