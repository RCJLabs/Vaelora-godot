extends Node

# Glamour: what minds see and believe. Autoloaded as "Glamour". Its spells
# (SpellData.glamour) are cast by player_magic.gd through cast() and act on
# enemies that know about it: wolves and bandit-kind (they have frighten()).
#   decoy  a shimmering copy of you where you aim: nearby enemies go for it
#          instead, until it has taken DECOY_HITS hits or its time is up
#   fear   enemies in the radius run from you for a while, then come back
#   charm  the enemy nearest where you aim fights for you: it goes for the
#          nearest other enemy, and its packmates turn on it. When it wears
#          off, it remembers whose side it's on. Hitting it yourself breaks it.
#   frenzy the enemy nearest where you aim attacks whoever's nearest, its own
#          or another pack's (you, when nobody else is near), and its packmates
#          turn on it. Hitting it doesn't break it.
# And one self spell, Invisibility (effects/invisible.tres): enemies lose you
# (systems/targeting.gd) and head home, or go for your companion. Attacking or
# casting anything ends it.
# The Vael's own kind (wisps), stone guardians and The First aren't fooled:
# it's Vael magic to begin with, and the guardians have no minds to fool. Nor is
# anything with `glamour_proof` true (the hollow wolf: nothing left in it to fool).
#
# Enemies ask target_for() each frame for who to go after. With no decoys and
# nobody charmed or frenzied (almost always), that's the player, at once.

const DECOY_HITS := 3
## How far a decoy draws enemies from, and how far a charmed enemy looks for a fight.
const DECOY_PULL := 18.0
const CHARM_SEEK := 16.0
## Packmates this close to a charmed or frenzied enemy turn on it.
const TURN_ON_TRAITOR := 10.0
const COLORS := {"charm": Color(0.95, 0.45, 0.9), "frenzy": Color(1.0, 0.3, 0.15)}
const DECOY_SCRIPT := preload("res://glamour/decoy.gd")

var _spells := {}   # enemy -> {"kind": "charm" or "frenzy", "left": seconds}
var _marks := {}    # enemy -> the light over its head while it lasts


## Who `enemy` should go after: the player, a decoy, or another enemy (when
## charmed or frenzied, or when a packmate is). null: nobody (charmed, with no
## one to fight).
func target_for(enemy: Node3D, player: Node3D) -> Node3D:
	if _spells.is_empty() and get_tree().get_nodes_in_group("decoy").is_empty():
		return player
	match kind_of(enemy):
		"calm":
			return null   # Shrine's Peace: nobody
		"charm":
			var ordered := Command.order_for_bound() if enemy.has_meta("bound") else null
			return ordered if ordered else _nearest(enemy, _foes_of(enemy), CHARM_SEEK)   # Pack Leader (Command)
		"frenzy":
			var anyone := _nearest(enemy, _others(enemy), CHARM_SEEK)
			return anyone if anyone else player
	var traitor := _nearest(enemy, _spells.keys().filter(func(e): return is_instance_valid(e) and e.get_parent() == enemy.get_parent()), TURN_ON_TRAITOR)
	if traitor:
		return traitor
	var decoy := _nearest(enemy, get_tree().get_nodes_in_group("decoy"), DECOY_PULL)
	return decoy if decoy else player


## "charm", "frenzy", "calm" or "".
func kind_of(enemy: Node) -> String:
	return _spells[enemy]["kind"] if _spells.has(enemy) else ""


func is_charmed(enemy: Node) -> bool:
	return kind_of(enemy) == "charm"


## Something hit `target`. If it was you and it's charmed, the charm breaks.
func struck(target, by) -> void:   # untyped: an arrow's shooter may be gone
	if is_instance_valid(target) and kind_of(target) in ["charm", "calm"] and is_instance_valid(by) and by.is_in_group("player") \
			and not target.has_meta("bound"):   # a stray arrow doesn't break a binding
		_end(target)


## Can Glamour touch it at all?
func susceptible(node: Node) -> bool:
	return node.has_method("frighten") and not node.get("glamour_proof") and not _dead(node)


## A Glamour spell going off at `center` (where the player aimed). `power` scales
## how long it lasts. Returns how many enemies (or decoys) it touched.
func cast(spell: SpellData, center: Vector3, power: float, caster: Node3D) -> int:
	var seconds := spell.duration * power
	match spell.glamour:
		"decoy":
			# On the ground under where you aimed (not halfway up whatever you aimed at).
			var down := PhysicsRayQueryParameters3D.create(center + Vector3.UP, center + Vector3.DOWN * 6.0, 1)
			var ground := caster.get_world_3d().direct_space_state.intersect_ray(down)
			if not ground.is_empty():
				center = ground["position"]
			var decoy := DECOY_SCRIPT.new()
			decoy.lifetime = seconds
			decoy.hits_left = DECOY_HITS
			decoy.color = spell.color
			caster.get_parent().add_child(decoy)
			decoy.global_position = center
			decoy.look_at_from_position(center, Vector3(caster.global_position.x, center.y, caster.global_position.z) + Vector3(0.001, 0, 0), Vector3.UP)
			return 1
		"fear":
			var touched := _in_radius(caster, center, spell.radius)
			for enemy in touched:
				enemy.frighten(seconds)
			return touched.size()
		"charm", "frenzy":
			var touched := _in_radius(caster, center, spell.radius)
			var enemy := _nearest_to_point(center, touched)
			if enemy:
				enthrall(enemy, spell.glamour, seconds)
				return 1
	return 0


## Makes `enemy` fight for you ("charm") or fight anyone ("frenzy") for `seconds`.
func enthrall(enemy: Node3D, kind: String, seconds: float) -> void:
	if not susceptible(enemy):
		return
	_spells[enemy] = {"kind": kind, "left": seconds}
	if _marks.has(enemy) and is_instance_valid(_marks[enemy]):
		_marks[enemy].queue_free()
	var mark := OmniLight3D.new()
	mark.name = "CharmMark" if kind == "charm" else "FrenzyMark"
	mark.light_color = COLORS[kind]
	mark.light_energy = 2.0
	mark.omni_range = 2.5
	mark.position = Vector3(0, 2.2, 0)
	enemy.add_child(mark)
	_marks[enemy] = mark
	if enemy.has_method("join_hunt"):
		enemy.join_hunt()   # idle or not, it's in the fight now


## Makes `enemy` fight for you for `seconds`.
func charm(enemy: Node3D, seconds: float) -> void:
	enthrall(enemy, "charm", seconds)


## Makes `enemy` stop fighting anyone for `seconds` (Shrine's Peace). Hitting it ends it.
func calm(enemy: Node3D, seconds: float) -> void:
	if not susceptible(enemy):
		return
	_spells[enemy] = {"kind": "calm", "left": seconds}
	if _marks.has(enemy) and is_instance_valid(_marks[enemy]):
		_marks[enemy].queue_free()
	var mark := OmniLight3D.new()
	mark.name = "CalmMark"
	mark.light_color = Color(0.85, 0.9, 1.0)
	mark.light_energy = 1.5
	mark.omni_range = 2.5
	mark.position = Vector3(0, 2.2, 0)
	enemy.add_child(mark)
	_marks[enemy] = mark


func _physics_process(delta: float) -> void:
	for enemy in _spells.keys():
		_spells[enemy]["left"] -= delta
		if not is_instance_valid(enemy) or _spells[enemy]["left"] <= 0.0 or _dead(enemy):
			_end(enemy)
	# Invisibility ends when you attack or cast.
	var player := get_tree().get_first_node_in_group("player")
	if player and player.get("effects") and player.effects.has("invisible"):
		Hints.show_once("invisible", "Invisible: enemies lose you, but attacking or casting ends it. The wisps see straight through it.")
		if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("cast"):
			player.effects.remove("invisible")


func _end(enemy) -> void:
	_spells.erase(enemy)
	if _marks.has(enemy):
		if is_instance_valid(_marks[enemy]):
			_marks[enemy].queue_free()
		_marks.erase(enemy)


## Forget everyone (a new level, or a load).
func reset() -> void:
	for enemy in _spells.keys():
		_end(enemy)


# Enemies (that Glamour works on) other than `enemy`, and not charmed themselves.
func _foes_of(enemy: Node) -> Array:
	return _others(enemy).filter(func(e): return not is_charmed(e))


# Every other living enemy Glamour works on.
func _others(enemy: Node) -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(e): return e != enemy and susceptible(e) and e.is_visible_in_tree())


func _in_radius(caster: Node3D, center: Vector3, radius: float) -> Array:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), center)
	query.collision_mask = 4
	var found := []
	for hit in caster.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var body: Object = hit["collider"]
		if not body in found and susceptible(body):
			found.append(body)
	return found


func _nearest(from: Node3D, candidates: Array, max_distance: float) -> Node3D:
	var best: Node3D = null
	var best_dist := max_distance
	for c in candidates:
		if not is_instance_valid(c):
			continue
		var d: float = from.global_position.distance_to(c.global_position)
		if d < best_dist:
			best = c
			best_dist = d
	return best


func _nearest_to_point(point: Vector3, candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for c in candidates:
		var d: float = point.distance_to(c.global_position)
		if d < best_dist:
			best = c
			best_dist = d
	return best


func _dead(node: Node) -> bool:
	var states = node.get("State")
	return states != null and states.has("DEAD") and node.state == states["DEAD"]
