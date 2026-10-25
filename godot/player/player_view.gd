class_name PlayerView
extends Node

# First or third person. A child of the Player called "View". V (R3 on a
# gamepad) switches; Settings.third_person remembers the choice for every
# character, and Esc > Settings has it too.
#
# The eye camera (Head/Camera3D) stays where it is in both views, and
# everything still aims from it: the interact ray, melee and spell casts, bolts
# and bursts. Third person adds a camera on a spring arm over your right
# shoulder (pulled in by walls) and shows a body. The crosshair is that camera's
# centre, so in third person the eye is turned each frame to look at whatever
# is under the crosshair (aim_rotation, which the player adds to the eye's
# rotation): what you see in the middle of the screen is what you hit.
#
# What you hold shows on the body too: each first-person model (weapon, shield,
# spell hands) has a copy on the body, rebuilt when equipment changes, that takes
# the same pose every frame, scaled out to arm's length from the shoulder. So
# third person swings, blocks, bashes and draws exactly as first person does.
#
# Render layers keep each camera to its own things: the first-person hands,
# weapons and spell glow are on VIEWMODEL_LAYER (set as they enter the tree),
# which the third-person camera doesn't draw; the body is on BODY_LAYER, which
# the eye camera doesn't.

const VIEWMODEL_LAYER := 1 << 10   # render layer 11
const BODY_LAYER := 1 << 11        # render layer 12
const ALL_LAYERS := (1 << 20) - 1
const ARM_LENGTH := 3.2
const SHOULDER := Vector3(0.8, 0.35, 0.0)
## How far the crosshair looks for something to aim at.
const AIM_DISTANCE := 60.0
## Closer than this, the body hides (it would fill the screen).
const BODY_HIDE_DISTANCE := 0.9
## The held copies: where the shoulders are on the body, and how much further out
## from them than the first-person model is from the eye.
const SHOULDERS := Vector3(0.0, 1.45, 0.0)
const REACH_SCALE := 1.35

var third_person := false
## Small pitch/yaw (radians) that points the eye at the crosshair; zero in first person.
var aim_rotation := Vector3.ZERO
var arm: SpringArm3D
var camera: Camera3D
var body: Node3D

var _player: CharacterBody3D
var _head: Node3D
var _eye: Camera3D
var _rig: Node3D          # on the body at the shoulders; holds the copies
var _held := {}           # first-person model -> its copy on the body
var _held_from := {}      # first-person model -> what its copy was built from


func _ready() -> void:
	_player = get_parent()
	_head = _player.get_node("Head")
	_eye = _head.get_node("Camera3D")
	_eye.cull_mask = ALL_LAYERS & ~BODY_LAYER

	arm = SpringArm3D.new()
	arm.name = "ThirdPersonArm"
	arm.position = SHOULDER
	arm.spring_length = ARM_LENGTH
	arm.collision_mask = 1   # the world
	arm.margin = 0.15
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	arm.shape = sphere
	arm.add_excluded_object(_player.get_rid())
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.cull_mask = ALL_LAYERS & ~VIEWMODEL_LAYER
	arm.add_child(camera)
	_head.add_child.call_deferred(arm)

	body = _make_body()
	_player.add_child.call_deferred(body)

	# First-person models come and go (weapons swap, the second spell hand is added
	# late): tag each as it enters the tree under the eye, and everything there now.
	get_tree().node_added.connect(_on_node_added)
	_tag(_eye)
	Settings.changed.connect(func(): if Settings.third_person != third_person: set_third_person(Settings.third_person))
	set_third_person.call_deferred(Settings.third_person)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_view") and not get_tree().paused and not DialogueManager.is_active:
		Settings.set_option("third_person", not third_person)   # Settings.changed switches the view
		get_viewport().set_input_as_handled()


func set_third_person(on: bool) -> void:
	third_person = on
	if not camera.is_inside_tree():
		return   # still being added: the deferred call from _ready comes back here
	if on:
		camera.make_current()
	else:
		_eye.make_current()
		aim_rotation = Vector3.ZERO
	body.visible = on


func _process(_delta: float) -> void:
	if not third_person or not camera.is_inside_tree():
		return
	camera.fov = _eye.fov   # including the bow's aiming zoom
	var kick: Vector3 = _player._camera_kick   # degrees, as the eye gets it
	camera.rotation = Vector3(deg_to_rad(kick.x), deg_to_rad(kick.y), deg_to_rad(kick.z))
	body.visible = arm.get_hit_length() > BODY_HIDE_DISTANCE
	_aim_eye_at_crosshair()
	_mirror_held()


## Where the crosshair is pointing, in the world (up to AIM_DISTANCE).
func crosshair_point() -> Vector3:
	var from := camera.global_position
	var to := from - camera.global_transform.basis.z * AIM_DISTANCE
	var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4 | 8)   # world, enemies, loot
	query.exclude = [_player.get_rid()]
	var hit := _player.get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else to


func _aim_eye_at_crosshair() -> void:
	var to_target := crosshair_point() - _head.global_position
	if to_target.length() < 0.3:
		aim_rotation = Vector3.ZERO
		return
	var d := (_head.global_transform.basis.inverse() * to_target).normalized()
	aim_rotation = Vector3(asin(clampf(d.y, -1.0, 1.0)), atan2(-d.x, -d.z), 0.0)


## The body's copy of a first-person model (Weapon, OffHand, SpellHand...), or null.
func held_copy(model_name: String) -> Node3D:
	var model := _eye.get_node_or_null(model_name)
	return _held.get(model) if model else null


# Each first-person model's copy on the body: rebuilt when what it holds changes,
# then posed like it, half following your look up and down.
func _mirror_held() -> void:
	_rig.rotation.x = _head.rotation.x * 0.5
	for model in _eye.get_children():
		if not model is Node3D or model is RayCast3D or model is ShapeCast3D:
			continue
		var built_from := ",".join(model.get_children().map(func(c): return str(c.get_instance_id())))
		if _held_from.get(model) != built_from:
			_held_from[model] = built_from
			if _held.has(model) and is_instance_valid(_held[model]):
				_held[model].queue_free()
			_held[model] = _copy_of(model)
			_rig.add_child(_held[model])
		var held: Node3D = _held[model]
		held.transform = Transform3D(model.transform.basis, model.transform.origin * REACH_SCALE)
		held.visible = model.visible


func _copy_of(model: Node3D) -> Node3D:
	var copy := Node3D.new()
	copy.name = model.name
	for child in model.get_children():
		copy.add_child(child.duplicate())
	for light in copy.find_children("*", "Light3D", true, false):
		light.free()   # the first-person one already lights the world
	for geometry in copy.find_children("*", "GeometryInstance3D", true, false):
		geometry.layers = BODY_LAYER
	return copy


func _on_node_added(node: Node) -> void:
	if _eye.is_ancestor_of(node):
		_tag(node)


# Puts the first-person models (everything drawn under the eye camera) on VIEWMODEL_LAYER.
func _tag(node: Node) -> void:
	if node is GeometryInstance3D:
		node.layers = VIEWMODEL_LAYER
	for child in node.get_children():
		_tag(child)


# Greybox: a capsule, with a darker band at eye height so you can see which way it faces.
func _make_body() -> Node3D:
	var root := Node3D.new()
	root.name = "Body"
	var capsule := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.8
	capsule.mesh = mesh
	capsule.position.y = 0.9
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.45, 0.38, 0.3)
	capsule.material_override = cloth
	capsule.layers = BODY_LAYER
	root.add_child(capsule)
	var visor := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 0.12, 0.2)
	visor.mesh = box
	visor.position = Vector3(0.0, 1.6, -0.28)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.15, 0.13, 0.12)
	visor.material_override = dark
	visor.layers = BODY_LAYER
	root.add_child(visor)
	_rig = Node3D.new()
	_rig.name = "Held"
	_rig.position = SHOULDERS
	root.add_child(_rig)
	root.visible = false
	return root
