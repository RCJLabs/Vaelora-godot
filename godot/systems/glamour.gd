extends Node

# Glamour: what minds see and believe. Autoloaded as "Glamour". Its spells
# (SpellData.glamour) are cast by player_magic.gd through cast() and act on
# enemies that know about it: wolves and bandit-kind (they have frighten()).
#   decoy  a shimmering copy of you where you aim: nearby enemies go for it
#          instead, until it has taken DECOY_HITS hits or its time is up
#   fear   enemies in the radius run from you for a while, then come back
#   charm  the enemy nearest where you aim fights for you: it goes for the
#          nearest other enemy, and its packmates turn on it. When it wears
#          off, it remembers whose side it's on.
# The Vael's own kind (wisps), stone guardians and The First aren't fooled:
# it's Vael magic to begin with, and the guardians have no minds to fool. Nor is
# anything with `glamour_proof` true (the hollow wolf: nothing left in it to fool).
#
# Enemies ask target_for() each frame for who to go after. With no decoys and
# nobody charmed (almost always), that's the player, at once.

const DECOY_HITS := 3
## How far a decoy draws enemies from, and how far a charmed enemy looks for a fight.
const DECOY_PULL := 18.0
const CHARM_SEEK := 16.0
## Packmates this close to a charmed enemy turn on it.
const TURN_ON_TRAITOR := 10.0
const CHARM_COLOR := Color(0.95, 0.45, 0.9)
const DECOY_SCRIPT := preload("res://glamour/decoy.gd")

var _charmed := {}   # enemy -> seconds left
var _marks := {}     # enemy -> the light over its head while charmed


## Who `enemy` should go after: the player, a decoy, or another enemy (when
## charmed, or when a packmate has been charmed). null: nobody (charmed, with
## no one to fight), so it stands where it is.
func target_for(enemy: Node3D, player: Node3D) -> Node3D:
	if _charmed.is_empty() and get_tree().get_nodes_in_group("decoy").is_empty():
		return player
	if _charmed.has(enemy):
		return _nearest(enemy, _foes_of(enemy), CHARM_SEEK)
	var traitor := _nearest(enemy, _charmed.keys().filter(func(e): return is_instance_valid(e) and e.get_parent() == enemy.get_parent()), TURN_ON_TRAITOR)
	if traitor:
		return traitor
	var decoy := _nearest(enemy, get_tree().get_nodes_in_group("decoy"), DECOY_PULL)
	return decoy if decoy else player


func is_charmed(enemy: Node) -> bool:
	return _charmed.has(enemy)


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
		"charm":
			var touched := _in_radius(caster, center, spell.radius)
			var enemy := _nearest_to_point(center, touched)
			if enemy:
				charm(enemy, seconds)
				return 1
	return 0


## Makes `enemy` fight for you for `seconds`.
func charm(enemy: Node3D, seconds: float) -> void:
	if not susceptible(enemy):
		return
	_charmed[enemy] = seconds
	if not _marks.has(enemy):
		var mark := OmniLight3D.new()
		mark.name = "CharmMark"
		mark.light_color = CHARM_COLOR
		mark.light_energy = 2.0
		mark.omni_range = 2.5
		mark.position = Vector3(0, 2.2, 0)
		enemy.add_child(mark)
		_marks[enemy] = mark
	if enemy.has_method("join_hunt"):
		enemy.join_hunt()   # idle or not, it's in the fight now


func _physics_process(delta: float) -> void:
	for enemy in _charmed.keys():
		_charmed[enemy] -= delta
		if not is_instance_valid(enemy) or _charmed[enemy] <= 0.0 or _dead(enemy):
			_end_charm(enemy)


func _end_charm(enemy) -> void:
	_charmed.erase(enemy)
	if _marks.has(enemy):
		if is_instance_valid(_marks[enemy]):
			_marks[enemy].queue_free()
		_marks.erase(enemy)


## Forget everyone (a new level, or a load).
func reset() -> void:
	for enemy in _charmed.keys():
		_end_charm(enemy)


# Enemies (that Glamour works on) other than `enemy`, and not charmed themselves.
func _foes_of(enemy: Node) -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(e): return e != enemy and susceptible(e) and not _charmed.has(e) and e.is_visible_in_tree())


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
