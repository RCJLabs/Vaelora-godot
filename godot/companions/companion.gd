extends CharacterBody3D

# Someone travelling with you (systems/companions.gd makes them). Follows a few
# metres behind, fights what's fighting you, and does what you tell them: talk
# to them (E) to have them wait, follow again, or go home.
#   FOLLOW  keeps up; if you leave them far behind (a door, a cellar), catches up
#   WAIT    stands where you left them
#   FIGHT   an enemy in the fight within FIGHT_RADIUS: the one pointed out (Command),
#           else the best by _score(): whatever's on you (more so when you're hurt),
#           casters and archers, the staggered, what's on them, the nearest; and they
#           stick with their choice unless another is clearly better.
#           Brannoc goes round an enemy that's fighting you to its far side (it can't
#           guard you both); Zora keeps her distance and backs off from what closes in.
#   RETREAT badly hurt, they fall back behind you for a few seconds
#   DOWN    knocked down at 0 health: out of the fight, and enemies leave them be.
#           Help them up (E) or they get up on their own after DOWN_SECONDS.
#           Companions don't die.
# They read telegraphs (a bandit's wind-up, a wolf's crouch) three times in four:
# Brannoc raises his guard (a blow from in front does a quarter), Zora jumps back out
# of reach. Enemies go for them as readily as for you (systems/targeting.gd). Waiting,
# they still hit back at whatever's hitting them. Out of a fight they heal.
#
# Greybox: a capsule, with a floating name and health while hurt.

enum State { FOLLOW, WAIT, FIGHT, DOWN, RETREAT }

signal defended(result: String)   # "blocked" (a blow on the guard) or "dodged" (a jump back)

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
## Reading a blow coming: they do three times in four, this long before it lands.
const READ_CHANCE := 0.75
const READ_LEAD := 0.25
const GUARD_TIME := 0.6
const GUARD_LETS_THROUGH := 0.25
const DODGE_TIME := 0.3
const DODGE_SPEED := 9.0
## A ranged companion backs off from anything after them closer than this.
const KEEP_CLEAR := 3.5
## Under this share of their health they fall back behind you, for up to RETREAT_TIME.
const RETREAT_BELOW := 0.25
const RETREAT_TIME := 5.0
const RETREAT_COOLDOWN := 12.0
## Metres better another target has to score before they switch.
const STICK := 3.0
## Brannoc goes round an enemy fighting you till he's this far round it from you
## (cos of about 115 degrees), for at most FLANK_TIME on one target.
const FLANK_DOT := -0.4
const FLANK_TIME := 3.0

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
var base_max_health := 100.0   # before Command (systems/command.gd) raises it
var next_blow_mult := 1.0      # Coordinated Strike: the next blow lands harder
var _ordered_enemy: Node3D = null   # pointed out (Command): goes for it, even if it hasn't noticed
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
var _body: Node3D
var _look := {}   # race, role, cloth (Companions.DEFS)
var _label: Label3D
var _agent: NavigationAgent3D
var _guard_left := 0.0
var _dodge_left := 0.0
var _dodge_dir := Vector3.ZERO
var _read := {}            # enemy instance id -> whether they caught this wind-up
var _retreat_left := 0.0
var _retreat_cooldown := 0.0
var _flank_left := FLANK_TIME
var _flanking: Node3D       # the enemy they're going round
var _back_off_turn := 0.0   # backing off into something: turn the way out this far (radians)
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func setup(id: String, def: Dictionary) -> void:
	companion_id = id
	display_name = def["name"]
	dialogue_file = def["dialogue"]
	damage = def.get("damage", damage)
	reach = def.get("reach", reach)
	attack_interval = def.get("attack_interval", attack_interval)
	ranged = def.get("ranged", false)
	base_max_health = def.get("health", max_health)
	max_health = base_max_health * Command.health_mult()
	health = max_health
	name = "Companion_" + id
	_look = def


func _ready() -> void:
	add_to_group("companion")
	collision_layer = 1   # like the people who stand around: you talk to them, and bump into them
	collision_mask = 1
	var shape := CollisionShape3D.new()
	shape.shape = CapsuleShape3D.new()
	shape.position.y = 0.9
	add_child(shape)
	_body = Figure.build(_look.get("race", "human"), _look.get("role", "commoner"), _look.get("cloth", Color(0.35, 0.45, 0.6)))
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
		_get_up(1.0 if "battlefield_aid" in Character.perks else HELPED_UP)   # Battlefield Aid (Command)
	else:
		DialogueManager.start(dialogue_file, display_name)


## An enemy's attack landing (the same call the player gets). Returns "hit",
## "blocked" (guarding, and it came from in front) or "dodged" (mid-jump).
func receive_attack(amount: float, attacker: Node3D, _poise: float = 0.0) -> String:
	if is_down:
		return "hit"
	if _dodge_left > 0.0:
		return "dodged"
	var blocked := _guard_left > 0.0 and is_instance_valid(attacker) and _in_front(attacker.global_position)
	if blocked:
		amount *= GUARD_LETS_THROUGH
	if state == State.WAIT and "hold_the_line" in Character.perks:
		amount *= 0.5
	if "commanders_aura" in Character.perks:
		amount *= 0.75
	health = maxf(health - amount, 0.0)
	_since_hit = 0.0
	_last_attacker = attacker
	if health <= 0.0:
		_go_down()
	_update_label()
	if blocked:
		defended.emit("blocked")
		return "blocked"
	return "hit"


## The Command key: go for `enemy`.
func attack_order(enemy: Node3D) -> void:
	_ordered_enemy = enemy
	if state == State.WAIT:
		order(State.FOLLOW)   # an order to fight is an order to move


## Wait or follow (from their dialogue). While they're down, it's what they'll do when they get up.
func order(new_state: State) -> void:
	_ordered = new_state
	if not is_down:
		state = new_state


func _go_down() -> void:
	_ordered = State.WAIT if state == State.WAIT else State.FOLLOW
	state = State.DOWN
	_guard_left = 0.0
	_dodge_left = 0.0
	_retreat_left = 0.0
	_down_left = 8.0 if "unbowed" in Character.perks else DOWN_SECONDS   # Unbowed (Command)
	target = null
	_body.rotation.x = deg_to_rad(80)   # laid on the ground (the figure's origin is at its feet)
	_body.position = Vector3(0, 0.25, -0.85)
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("hud"):
		player.hud.notify("%s is down! Help them up (%s)." % [display_name, Hints.key("interact")])


func _get_up(share: float) -> void:
	health = max_health * share
	state = _ordered
	_body.rotation.x = 0.0
	_body.position = Vector3.ZERO
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
	max_health = base_max_health * Command.health_mult()   # Command can change mid-fight
	health = minf(health, max_health)
	if _since_hit > REGEN_DELAY and health < max_health:
		health = minf(health + REGEN_PER_SECOND * (2.0 if "hardened" in Character.perks else 1.0) * delta, max_health)
		_update_label()
	_guard_left -= delta
	_dodge_left -= delta
	_retreat_cooldown -= delta
	_read_blows()
	if _dodge_left > 0.0:
		velocity.x = _dodge_dir.x * DODGE_SPEED
		velocity.z = _dodge_dir.z * DODGE_SPEED
		move_and_slide()
		return
	if state == State.WAIT:
		# Waiting, but not standing there to be bitten: hit back at what's in reach.
		var attacker := _last_attacker if is_instance_valid(_last_attacker) and not _calm(_last_attacker) else null
		if attacker and _flat_distance(attacker) <= reach * 1.3:
			_strike(attacker)
	else:
		target = _find_target(player)
		state = State.FIGHT if target else State.FOLLOW
		if target and _should_retreat():
			_retreat_left = RETREAT_TIME
			_retreat_cooldown = RETREAT_COOLDOWN
		if _retreat_left > 0.0:
			_retreat_left -= delta
			if target:
				state = State.RETREAT
	match state:
		State.FOLLOW:
			var dist := global_position.distance_to(player.global_position)
			if dist > CATCH_UP_DISTANCE:
				arrive_behind(player)
			elif dist > FOLLOW_DISTANCE:
				_move(player.global_position, _run_speed() if dist > FOLLOW_DISTANCE * 2.0 else _run_speed() * 0.6)
			else:
				_move(Vector3.ZERO, 0.0)
		State.WAIT:
			_move(Vector3.ZERO, 0.0)
		State.FIGHT:
			if _guard_left > 0.0:
				_move(Vector3.ZERO, 0.0)   # behind the guard
				_face(target.global_position)
			elif ranged:
				_fight_at_range(target)
			else:
				_fight_close(target, player)
		State.RETREAT:
			# Behind you, away from the fight: whatever's on them is nearer you now.
			var away := player.global_position - target.global_position
			away.y = 0.0
			var spot := player.global_position + (away.normalized() if away.length() > 0.1 else Vector3.BACK) * 2.5
			if global_position.distance_to(spot) > 0.8:
				_move(spot, _run_speed())
			else:
				_move(Vector3.ZERO, 0.0)
				_face(target.global_position)
	move_and_slide()


# Close in and strike. On an enemy that's fighting you, go round to its far side first:
# it can't face you both, and a blow from behind gets past a guard.
func _fight_close(enemy: Node3D, player: Node3D) -> void:
	var near_you: bool = enemy.has_meta("foe") and enemy.get_meta("foe") == player and _flat(enemy, player) < 4.0
	var from_enemy := global_position - enemy.global_position
	from_enemy.y = 0.0
	var to_you := player.global_position - enemy.global_position
	to_you.y = 0.0
	if enemy != _flanking:
		_flanking = enemy
		_flank_left = FLANK_TIME
	_flank_left -= get_physics_process_delta_time()
	if near_you and _flank_left > 0.0 and to_you.length() > 0.1 and from_enemy.length() > 0.1 and from_enemy.normalized().dot(to_you.normalized()) > FLANK_DOT:
		# Not round it yet: round its flank (the side they're already on), not through it.
		var side := to_you.normalized().cross(Vector3.UP)
		if side.dot(from_enemy) < 0.0:
			side = -side
		_move(enemy.global_position + side * reach * 1.2 - to_you.normalized() * reach * 0.6, _run_speed())
	elif _flat_distance(enemy) > reach:
		_move(enemy.global_position, _run_speed())
	else:
		_strike(enemy)


# Keep a few metres off: back away from anything that's after them and too close,
# step round anything in the way, and throw from range.
func _fight_at_range(enemy: Node3D) -> void:
	var pressing := _nearest_on_me(KEEP_CLEAR)
	if not pressing:
		_back_off_turn = 0.0
	if pressing:
		var away := global_position - pressing.global_position
		away.y = 0.0
		if Vector2(get_real_velocity().x, get_real_velocity().z).length() < 1.5:
			_back_off_turn = wrapf(_back_off_turn + 0.12, -PI, PI)   # against a wall: work round it
		_move(global_position + away.normalized().rotated(Vector3.UP, _back_off_turn) * 3.0, _run_speed())
	elif _flat_distance(enemy) > reach:
		_move(enemy.global_position, _run_speed())
	elif not Stealth.clear_line(self, enemy):
		var to := enemy.global_position - global_position
		to.y = 0.0
		_move(global_position + to.normalized().cross(Vector3.UP) * 2.0, _run_speed() * 0.7)
	else:
		_strike(enemy)


# --- reading blows ---------------------------------------------------------------------

## An enemy after them about to land a blow: maybe they see it coming (READ_CHANCE,
## decided once per wind-up) and guard or jump back.
func _read_blows() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		var id: int = enemy.get_instance_id()
		var left := _blow_in(enemy)
		if left == INF or not (enemy.has_meta("foe") and enemy.get_meta("foe") == self):
			_read.erase(id)
			continue
		if left > READ_LEAD or _flat_distance(enemy) > 4.0 or _read.has(id):
			continue
		_read[id] = randf() < READ_CHANCE
		if _read[id]:
			_defend(enemy)


## Seconds until `enemy`'s blow lands (INF: none coming): a bandit's swing (bandit.gd,
## ATTACK wind-up) or a wolf's bite (wolf.gd, _windup_left).
func _blow_in(enemy: Node) -> float:
	if enemy.get("bite_windup") != null:
		return enemy._windup_left if enemy._windup_left > 0.0 else INF
	if enemy.has_method("ranged") and enemy._attack != null and enemy.state == enemy.State.ATTACK and enemy._phase == enemy.Phase.WINDUP:
		return enemy._attack.windup - enemy._phase_time
	return INF


func _defend(enemy: Node3D) -> void:
	if ranged:
		var away := global_position - enemy.global_position
		away.y = 0.0
		_dodge_dir = away.normalized().rotated(Vector3.UP, randf_range(-0.6, 0.6))
		_dodge_left = DODGE_TIME
		defended.emit("dodged")
	else:
		_guard_left = GUARD_TIME
		_face(enemy.global_position)


## Badly hurt, with something after them, and not told to go for something: fall back.
func _should_retreat() -> bool:
	return _retreat_left <= 0.0 and _retreat_cooldown <= 0.0 and health < max_health * RETREAT_BELOW \
			and not is_instance_valid(_ordered_enemy) and _nearest_on_me(6.0) != null


## The nearest enemy after them within `radius`.
func _nearest_on_me(radius: float) -> Node3D:
	var best: Node3D = null
	var best_dist := radius
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_meta("foe") and enemy.get_meta("foe") == self and not _calm(enemy) and not Glamour._dead(enemy):
			var d := _flat_distance(enemy)
			if d < best_dist:
				best = enemy
				best_dist = d
	return best


func _in_front(at: Vector3) -> bool:
	var to := at - global_position
	to.y = 0.0
	var forward := -global_basis.z
	forward.y = 0.0
	return to.length() < 0.1 or rad_to_deg(forward.angle_to(to)) < 70.0


func _strike(enemy: Node3D) -> void:
	_move(Vector3.ZERO, 0.0)
	_face(enemy.global_position)
	if _attack_left > 0.0:
		return
	_attack_left = attack_interval * (0.8 if "battle_drill" in Character.perks else 1.0)
	var dealt := damage * Command.damage_mult() * next_blow_mult
	next_blow_mult = 1.0
	if ranged:
		_throw_bolt(enemy, dealt)
		return
	enemy.take_hit(dealt, global_position, 3.0, 16.0 if "vanguard" in Character.perks else 8.0)
	Command.ally_dealt(dealt)
	Targeting.provoke(enemy, self)


func _run_speed() -> float:
	return RUN_SPEED * (1.25 if "swift_escort" in Character.perks else 1.0)


# A bolt of fire from chest height at the enemy's middle; it does the damage when it lands.
func _throw_bolt(enemy: Node3D, dealt: float) -> void:
	var bolt: SpellBolt = BOLT_SCENE.instantiate()
	bolt.shooter = self
	bolt.damage = dealt
	bolt.poise_damage = 8.0 if "vanguard" in Character.perks else 4.0
	bolt.color = bolt_color
	bolt.hit.connect(func(target, landed):
		Command.ally_dealt(landed)
		Targeting.provoke(target, self))
	get_parent().add_child(bolt)
	var from := global_position + Vector3(0, 1.3, 0)
	bolt.launch(from, (enemy.global_position + Vector3(0, 0.6, 0)) - from, 22.0, 0.7)


func _flat_distance(node: Node3D) -> float:
	return _flat(node, self)


func _flat(a: Node3D, b: Node3D) -> float:
	return Vector2(a.global_position.x - b.global_position.x, a.global_position.z - b.global_position.z).length()


## Puts them a couple of metres behind the player (on arrival in a level, or to catch up).
func arrive_behind(player: Node3D) -> void:
	var back := player.global_transform.basis.z
	back.y = 0.0
	global_position = player.global_position + back.normalized() * 2.0 + Vector3.UP * 0.1
	velocity = Vector3.ZERO


# The enemy to fight: the one pointed out, else the best-scoring living enemy that's in
# the fight (not idle, not heading home, not fleeing, not charmed onto your side),
# within FIGHT_RADIUS of the player or of them. They keep their target unless another
# scores STICK better.
func _find_target(player: Node3D) -> Node3D:
	if is_instance_valid(_ordered_enemy) and not Glamour._dead(_ordered_enemy) and _ordered_enemy.is_visible_in_tree():
		return _ordered_enemy   # pointed out: that one, wherever it is and whatever it's doing
	_ordered_enemy = null
	var best: Node3D = null
	var best_score := INF
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy.has_method("take_hit") or not enemy.is_visible_in_tree() or _calm(enemy) or Glamour.is_charmed(enemy):
			continue
		if minf(enemy.global_position.distance_to(player.global_position), enemy.global_position.distance_to(global_position)) >= FIGHT_RADIUS:
			continue
		var score := _score(enemy, player) - (STICK if enemy == target else 0.0)
		if score < best_score:
			best = enemy
			best_score = score
	return best


## How much they'd rather not fight `enemy` (metres, roughly: lower is better). Its
## distance, less a bonus for each reason to go for it.
func _score(enemy: Node3D, player: Node3D) -> float:
	var score := _flat_distance(enemy)
	var after_you: bool = enemy.has_meta("foe") and enemy.get_meta("foe") == player
	if after_you and _flat(enemy, player) < 4.0:
		var hurt: bool = player.get("stats") != null and player.stats.health < player.stats.max_health * 0.35
		score -= 8.0 if hurt else 4.0   # on you: help
	if enemy.has_meta("foe") and enemy.get_meta("foe") == self:
		score -= 2.0
	if enemy.has_method("ranged") and enemy.ranged():
		score -= 8.0 if ranged else 3.0   # the archer or caster you can't reach while you fight
		if enemy.state in [enemy.State.CAST, enemy.State.SHOOT]:
			score -= 3.0   # mid-cast: a hit breaks it
	if enemy.has_method("is_staggered") and enemy.is_staggered():
		score -= 2.0   # free hits
	return score


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
