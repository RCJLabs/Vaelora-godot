extends CharacterBody3D

# Someone travelling with you (systems/companions.gd makes them). Follows a few
# metres behind, fights what's fighting you, and does what you tell them: talk
# to them (E) to have them wait, follow again, or go home.
#   FOLLOW  keeps up; if you leave them far behind (a door, a cellar), catches up
#   WAIT    stands where you left them
#   FIGHT   the nearest enemy that's after you, within FIGHT_RADIUS of you
#
# Greybox: a capsule, and enemies don't fight back at companions yet (they only
# ever target the player), so a companion can't be hurt.

enum State { FOLLOW, WAIT, FIGHT }

const FOLLOW_DISTANCE := 3.0
const CATCH_UP_DISTANCE := 40.0   # further than this, they simply arrive behind you
const FIGHT_RADIUS := 15.0
const RUN_SPEED := 6.5

var companion_id := ""
var display_name := "Companion"
var dialogue_file := ""
var damage := 10.0
## Metres they can hit from: melee for Brannoc, Zora's fire for her.
var reach := 1.9
var attack_interval := 1.2
var state := State.FOLLOW
var target: Node3D = null

var prompt: String:
	get: return "Talk to %s" % display_name

var _attack_left := 0.0
var _agent: NavigationAgent3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func setup(id: String, def: Dictionary) -> void:
	companion_id = id
	display_name = def["name"]
	dialogue_file = def["dialogue"]
	damage = def.get("damage", damage)
	reach = def.get("reach", reach)
	attack_interval = def.get("attack_interval", attack_interval)
	name = "Companion_" + id


func _ready() -> void:
	add_to_group("companion")
	collision_layer = 1   # like the people who stand around: you talk to them, and bump into them
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 0.9
	add_child(shape)
	var mesh := MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	mesh.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.45, 0.6)
	mesh.material_override = mat
	add_child(mesh)
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.8
	add_child(_agent)


func interact(_player: Node) -> void:
	DialogueManager.start(dialogue_file, display_name)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or DialogueManager.is_active:
		_move(Vector3.ZERO, 0.0)
		move_and_slide()
		return
	_attack_left -= delta
	if state != State.WAIT:
		target = _find_target(player)
		state = State.FIGHT if target else State.FOLLOW
	match state:
		State.FOLLOW:
			var dist := global_position.distance_to(player.global_position)
			if dist > CATCH_UP_DISTANCE:
				arrive_behind(player)
			elif dist > FOLLOW_DISTANCE:
				_move(player.global_position, RUN_SPEED if dist > FOLLOW_DISTANCE * 2.0 else RUN_SPEED * 0.6)
			else:
				_move(Vector3.ZERO, 0.0)
		State.WAIT:
			_move(Vector3.ZERO, 0.0)
		State.FIGHT:
			var flat := Vector2(target.global_position.x - global_position.x, target.global_position.z - global_position.z).length()
			if flat > reach:
				_move(target.global_position, RUN_SPEED)
			else:
				_move(Vector3.ZERO, 0.0)
				_face(target.global_position)
				if _attack_left <= 0.0:
					_attack_left = attack_interval
					target.take_hit(damage, global_position, 3.0, 8.0)
	move_and_slide()


## Puts them a couple of metres behind the player (on arrival in a level, or to catch up).
func arrive_behind(player: Node3D) -> void:
	var back := player.global_transform.basis.z
	back.y = 0.0
	global_position = player.global_position + back.normalized() * 2.0 + Vector3.UP * 0.1
	velocity = Vector3.ZERO


# The nearest living enemy near the player that's after them (not idle, not heading
# home, not fleeing, not charmed onto your side).
func _find_target(player: Node3D) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("take_hit") or not enemy.is_visible_in_tree() or _calm(enemy) or Glamour.is_charmed(enemy):
			continue
		var d: float = enemy.global_position.distance_to(player.global_position)
		if d < FIGHT_RADIUS and d < best_dist:
			best = enemy
			best_dist = d
	return best


func _calm(enemy: Node) -> bool:
	var states = enemy.get("State")
	if states == null:
		return false
	for calm_state in ["IDLE", "DEAD", "RETURN", "DORMANT", "FLEE"]:
		if states.has(calm_state) and enemy.state == states[calm_state]:
			return true
	return false


func _move(to: Vector3, speed: float) -> void:
	if speed <= 0.0:
		velocity.x = move_toward(velocity.x, 0.0, 0.5)
		velocity.z = move_toward(velocity.z, 0.0, 0.5)
		return
	var next := to
	if NavigationServer3D.map_get_iteration_id(_agent.get_navigation_map()) != 0:
		if _agent.target_position.distance_to(to) > 0.5:
			_agent.target_position = to
		if not _agent.is_navigation_finished():
			next = _agent.get_next_path_position()
	var step := next - global_position
	step.y = 0.0
	if step.length() < 0.05:
		step = to - global_position
		step.y = 0.0
	step = step.normalized()
	velocity.x = step.x * speed
	velocity.z = step.z * speed
	_face(global_position + step)


func _face(at: Vector3) -> void:
	var dir := at - global_position
	if Vector2(dir.x, dir.z).length() > 0.05:
		rotation.y = atan2(-dir.x, -dir.z)
