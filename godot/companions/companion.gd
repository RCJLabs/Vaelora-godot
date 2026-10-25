extends CharacterBody3D

# Someone travelling with you (systems/companions.gd makes them). Follows a few
# metres behind, fights what's fighting you, and does what you tell them: talk
# to them (E) to have them wait, follow again, or go home.
#   FOLLOW  keeps up; if you leave them far behind (a door, a cellar), catches up
#   WAIT    stands where you left them
#   FIGHT   the nearest enemy that's after you or them, within FIGHT_RADIUS
#   DOWN    knocked down at 0 health: out of the fight, and enemies leave them be.
#           Help them up (E) or they get up on their own after DOWN_SECONDS.
#           Companions don't die.
# Enemies go for them as readily as for you (systems/targeting.gd). Waiting, they
# still hit back at whatever's hitting them. Out of a fight they heal.
#
# Greybox: a capsule, with a floating name and health while hurt.

enum State { FOLLOW, WAIT, FIGHT, DOWN }

const BOLT_SCENE := preload("res://combat/spell_bolt.tscn")

const FOLLOW_DISTANCE := 3.0
const CATCH_UP_DISTANCE := 40.0   # further than this, they simply arrive behind you
const FIGHT_RADIUS := 15.0
const RUN_SPEED := 6.5
const DOWN_SECONDS := 20.0
## Share of their health they get back when they get up (helped, or on their own).
const HELPED_UP := 0.5
const GOT_UP := 0.3
## Out of a fight (not hit for this long) they heal this much a second.
const REGEN_DELAY := 6.0
const REGEN_PER_SECOND := 3.0

var companion_id := ""
var display_name := "Companion"
var dialogue_file := ""
var damage := 10.0
## Metres they can hit from: melee for Brannoc, Zora's fire for her.
var reach := 1.9
var attack_interval := 1.2
## Throws a bolt (Zora's fire) instead of striking in melee.
var ranged := false
var bolt_color := Color(1, 0.5, 0.15)
var max_health := 100.0
var health := 100.0
var state := State.FOLLOW
var target: Node3D = null
var is_down: bool:
	get: return state == State.DOWN

var prompt: String:
	get: return ("Help %s up" if is_down else "Talk to %s") % display_name

var _attack_left := 0.0
var _down_left := 0.0
var _since_hit := 100.0
var _last_attacker: Node3D = null
var _ordered := State.FOLLOW   # what they were doing before they went down
var _body: MeshInstance3D
var _label: Label3D
var _agent: NavigationAgent3D
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func setup(id: String, def: Dictionary) -> void:
	companion_id = id
	display_name = def["name"]
	dialogue_file = def["dialogue"]
	damage = def.get("damage", damage)
	reach = def.get("reach", reach)
	attack_interval = def.get("attack_interval", attack_interval)
	ranged = def.get("ranged", false)
	max_health = def.get("health", max_health)
	health = max_health
	name = "Companion_" + id


func _ready() -> void:
	add_to_group("companion")
	collision_layer = 1   # like the people who stand around: you talk to them, and bump into them
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 0.9
	add_child(shape)
	_body = MeshInstance3D.new()
	_body.mesh = CapsuleMesh.new()
	_body.position.y = 0.9
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.45, 0.6)
	_body.material_override = mat
	add_child(_body)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = 2.3
	_label.font_size = 40
	_label.pixel_size = 0.004
	_label.no_depth_test = true
	add_child(_label)
	_update_label()
	_agent = NavigationAgent3D.new()
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 0.8
	add_child(_agent)


func interact(_player: Node) -> void:
	if is_down:
		_get_up(HELPED_UP)
	else:
		DialogueManager.start(dialogue_file, display_name)


## An enemy's attack landing (the same call the player gets). Returns "hit".
func receive_attack(amount: float, attacker: Node3D, _poise: float = 0.0) -> String:
	if is_down:
		return "hit"
	health = maxf(health - amount, 0.0)
	_since_hit = 0.0
	_last_attacker = attacker
	if health <= 0.0:
		_go_down()
	_update_label()
	return "hit"


## Wait or follow (from their dialogue). While they're down, it's what they'll do when they get up.
func order(new_state: State) -> void:
	_ordered = new_state
	if not is_down:
		state = new_state


func _go_down() -> void:
	_ordered = State.WAIT if state == State.WAIT else State.FOLLOW
	state = State.DOWN
	_down_left = DOWN_SECONDS
	target = null
	_body.rotation.x = deg_to_rad(80)
	_body.position.y = 0.35
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("hud"):
		player.hud.notify("%s is down! Help them up (%s)." % [display_name, Hints.key("interact")])


func _get_up(share: float) -> void:
	health = max_health * share
	state = _ordered
	_body.rotation.x = 0.0
	_body.position.y = 0.9
	_update_label()


func _update_label() -> void:
	if _label == null:
		return
	_label.visible = health < max_health
	_label.text = "%s  %d / %d%s" % [display_name, ceili(health), int(max_health), "  (down)" if is_down else ""]


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null or DialogueManager.is_active:
		_move(Vector3.ZERO, 0.0)
		move_and_slide()
		return
	_attack_left -= delta
	_since_hit += delta
	if is_down:
		_move(Vector3.ZERO, 0.0)
		_down_left -= delta
		if _down_left <= 0.0:
			_get_up(GOT_UP)
		move_and_slide()
		return
	if _since_hit > REGEN_DELAY and health < max_health:
		health = minf(health + REGEN_PER_SECOND * delta, max_health)
		_update_label()
	if state == State.WAIT:
		# Waiting, but not standing there to be bitten: hit back at what's in reach.
		var attacker := _last_attacker if is_instance_valid(_last_attacker) and not _calm(_last_attacker) else null
		if attacker and _flat_distance(attacker) <= reach * 1.3:
			_strike(attacker)
	else:
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
			if _flat_distance(target) > reach:
				_move(target.global_position, RUN_SPEED)
			else:
				_strike(target)
	move_and_slide()


func _strike(enemy: Node3D) -> void:
	_move(Vector3.ZERO, 0.0)
	_face(enemy.global_position)
	if _attack_left > 0.0:
		return
	_attack_left = attack_interval
	if ranged:
		_throw_bolt(enemy)
		return
	enemy.take_hit(damage, global_position, 3.0, 8.0)
	Targeting.provoke(enemy, self)


# A bolt of fire from chest height at the enemy's middle; it does the damage when it lands.
func _throw_bolt(enemy: Node3D) -> void:
	var bolt: SpellBolt = BOLT_SCENE.instantiate()
	bolt.shooter = self
	bolt.damage = damage
	bolt.poise_damage = 4.0
	bolt.color = bolt_color
	bolt.hit.connect(func(target, _dealt): Targeting.provoke(target, self))
	get_parent().add_child(bolt)
	var from := global_position + Vector3(0, 1.3, 0)
	bolt.launch(from, (enemy.global_position + Vector3(0, 0.6, 0)) - from, 22.0, 0.7)


func _flat_distance(node: Node3D) -> float:
	return Vector2(node.global_position.x - global_position.x, node.global_position.z - global_position.z).length()


## Puts them a couple of metres behind the player (on arrival in a level, or to catch up).
func arrive_behind(player: Node3D) -> void:
	var back := player.global_transform.basis.z
	back.y = 0.0
	global_position = player.global_position + back.normalized() * 2.0 + Vector3.UP * 0.1
	velocity = Vector3.ZERO


# The nearest living enemy that's in the fight (not idle, not heading home, not
# fleeing, not charmed onto your side), within FIGHT_RADIUS of the player or of them.
func _find_target(player: Node3D) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("take_hit") or not enemy.is_visible_in_tree() or _calm(enemy) or Glamour.is_charmed(enemy):
			continue
		var d: float = minf(enemy.global_position.distance_to(player.global_position), enemy.global_position.distance_to(global_position))
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
