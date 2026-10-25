extends Node

# Tidecraft: the pull of the two moons (docs/lore/MAGIC.md, school 8). Autoloaded
# as "Tidecraft". Its spells (SpellData.tide) are cast by player_magic.gd through
# cast(), and move whatever can be moved: anything with shove() (wolves,
# bandit-kind, wisps). Stone guardians and The First are too heavy.
#   pull   the enemy nearest where you aim is dragged to just in front of you, and reels
#   shove  everything in reach in front of you is hurled away, and reels
#   well   a well where you aim drags everything in its radius to the middle and
#          holds it there, pinned (slow), for a while
# All of them are stronger or weaker by the moons (WorldClock.tide_mult(): x0.6
# with Ilun dark and the Wanderer full, x1.4 with Ilun full or the Wanderer
# dark), which player_magic.gd puts into `power`: damage, how far things are
# thrown, how long a well lasts.

## How far in front of you a pulled enemy ends up.
const PULL_STOP := 2.2
const PULL_SPEED := 26.0
const PULL_STAGGER := 1.2
## Shove: how wide in front of you it reaches, and how hard and long it throws.
const SHOVE_ANGLE := 70.0
const SHOVE_SPEED := 24.0
const SHOVE_SECONDS := 0.35
const SHOVE_STAGGER := 1.5
## Well: how fast it drags at its edge (slower nearer the middle).
const WELL_DRAG := 7.0

var _drags := []   # {"node", "to": Node3D or null, "velocity": Vector3, "left": seconds}
var _wells := []   # {"center", "radius", "left", "scene", "mark": Node3D}


## A Tidecraft spell going off: `center` is where the player aimed. Returns what
## it touched (for XP and the enemy health bar).
func cast(spell: SpellData, center: Vector3, power: float, caster: Node3D, dual: bool = false) -> Array:
	match spell.tide:
		"pull":
			var enemy := _nearest_to_point(center, _movable_in_radius(caster, center, spell.radius))
			if enemy == null:
				return []
			_hurt(enemy, spell.damage * power, caster)
			enemy.stagger(PULL_STAGGER)
			_drags.append({"node": enemy, "to": caster, "velocity": Vector3.ZERO, "left": 2.0})
			return [enemy]
		"shove":
			var view: Node3D = caster.get("camera") if caster.get("camera") else caster
			var forward: Vector3 = -view.global_transform.basis.z
			forward.y = 0.0
			var touched := []
			for enemy in _movable_in_radius(caster, caster.global_position, spell.max_distance):
				var away: Vector3 = enemy.global_position - caster.global_position
				away.y = 0.0
				if away.length() > 0.01 and rad_to_deg(forward.angle_to(away)) > SHOVE_ANGLE:
					continue
				_hurt(enemy, spell.damage * power, caster)
				enemy.stagger(SHOVE_STAGGER)
				var direction: Vector3 = away.normalized() if away.length() > 0.01 else forward.normalized()
				_drags.append({"node": enemy, "to": null, "velocity": direction * SHOVE_SPEED * power, "left": SHOVE_SECONDS})
				touched.append(enemy)
			SpellBurst.spawn(caster.get_parent(), caster.global_position + forward.normalized() * 2.0 + Vector3.UP, 1.6, spell.color)
			return touched
		"well":
			# On the ground under where you aimed (not halfway up a wall).
			var down := PhysicsRayQueryParameters3D.create(center + Vector3.UP, center + Vector3.DOWN * 6.0, 1)
			var ground := caster.get_world_3d().direct_space_state.intersect_ray(down)
			if not ground.is_empty():
				center = ground["position"]
			var radius := spell.radius * (1.3 if dual else 1.0)
			var well := {"center": center, "radius": radius, "left": spell.duration * power,
					"scene": get_tree().current_scene, "mark": _make_mark(caster.get_parent(), center, radius, spell.color)}
			_wells.append(well)
			SpellBurst.spawn(caster.get_parent(), center, radius, spell.color)
			return _movable_in_radius(caster, center, radius)
	return []


## True while a well is pulling at `node`.
func in_well(node: Node3D) -> bool:
	for well in _wells:
		if _flat(node.global_position - well["center"]).length() <= well["radius"]:
			return true
	return false


func reset() -> void:
	_drags.clear()
	for well in _wells:
		if is_instance_valid(well["mark"]):
			well["mark"].queue_free()
	_wells.clear()


func _physics_process(delta: float) -> void:
	for drag in _drags.duplicate():
		var node = drag["node"]
		drag["left"] -= delta
		if not is_instance_valid(node) or _dead(node) or drag["left"] <= 0.0:
			_drags.erase(drag)
			continue
		if drag["to"] != null:
			# Pulled: towards whoever cast it, stopping just in front of them.
			if not is_instance_valid(drag["to"]):
				_drags.erase(drag)
				continue
			var to_caster := _flat(drag["to"].global_position - node.global_position)
			var left := to_caster.length() - PULL_STOP
			if left <= 0.05:
				node.shove(Vector3.ZERO)
				_drags.erase(drag)
				continue
			node.shove(to_caster.normalized() * minf(PULL_SPEED, left / delta))
		else:
			node.shove(drag["velocity"])
	for well in _wells.duplicate():
		well["left"] -= delta
		if well["left"] <= 0.0 or well["scene"] != get_tree().current_scene:   # over, or you've left
			if is_instance_valid(well["mark"]):
				well["mark"].queue_free()
			_wells.erase(well)
			continue
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player == null:
			continue
		for enemy in _movable_in_radius(player, well["center"], well["radius"]):
			var to_middle := _flat(well["center"] - enemy.global_position)
			var pull := WELL_DRAG * clampf(to_middle.length() / well["radius"], 0.0, 1.0)
			enemy.shove(to_middle.normalized() * minf(pull, to_middle.length() / delta) if to_middle.length() > 0.1 else Vector3.ZERO)
			if enemy.has_method("add_effect"):
				enemy.add_effect("pinned")
		if is_instance_valid(well["mark"]):
			well["mark"].rotate_y(delta * 1.5)


func _hurt(enemy: Node, damage: float, caster: Node3D) -> void:
	if damage > 0.0 and enemy.has_method("take_hit"):
		enemy.take_hit(damage, caster.global_position, 0.0, 0.0)
		Glamour.struck(enemy, caster)


# Enemies (layer 4) in reach of `center` that the tide can move.
func _movable_in_radius(caster: Node3D, center: Vector3, radius: float) -> Array:
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = sphere
	query.transform = Transform3D(Basis(), center)
	query.collision_mask = 4
	var found := []
	for hit in caster.get_world_3d().direct_space_state.intersect_shape(query, 32):
		var node: Object = hit["collider"]
		if node in found or not node.has_method("shove") or _dead(node):
			continue
		found.append(node)
	return found


# A dark ring on the ground where a well is, turning slowly.
func _make_mark(parent: Node, center: Vector3, radius: float, color: Color) -> Node3D:
	var mark := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 0.25
	ring.outer_radius = radius
	mark.mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(color, 0.7)
	mark.material_override = material
	mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mark)
	mark.global_position = center + Vector3.UP * 0.1
	return mark


func _nearest_to_point(point: Vector3, candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_dist := INF
	for c in candidates:
		var d: float = point.distance_to(c.global_position)
		if d < best_dist:
			best = c
			best_dist = d
	return best


func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _dead(node: Node) -> bool:
	var states = node.get("State")
	return states != null and states.has("DEAD") and node.state == states["DEAD"]
