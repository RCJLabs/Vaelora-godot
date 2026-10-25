extends Node

# Runecraft: runes, wards and magic stored in things. Autoloaded as "Runecraft".
# Its spells (SpellData.rune) are cast by player_magic.gd through cast().
# docs/godot-starter/RUNECRAFT.md; the lore is docs/lore/MAGIC.md ("Runecraft"):
# the trapper and artificer, who plans the battlefield before the fight.
#   fire / frost / binding  a rune on the ground where you aim. When an enemy
#          comes within TRIGGER metres it goes off: everything within BLAST
#          takes the spell's damage, and burns, chills or is held
#   ward   a circle on the ground where you stand: inside it, blows do 40% less
# (Enchant Weapon is a self spell: the effect rune_blade, which PlayerCombat
# reads: +8 damage and a chance to burn.)
# Runes last LIFETIME seconds; you can keep MAX_RUNES at once (perks: more), and
# a new one replaces the oldest.

const TRIGGER := 1.6
const BLAST := 2.5
const LIFETIME := 120.0
const MAX_RUNES := 3
const WARD_RADIUS := 3.0
const CHAIN_RADIUS := 4.0
const EFFECTS := {"fire": "burning", "frost": "chilled", "binding": "bound"}
const BLADE_DAMAGE := 8.0
const REARM_TIME := 3.0       # Living Runes: seconds before a rune that's gone off can go off again

var runes := []   # [{"node", "kind", "damage", "left", "rearms"}], oldest first
var wards := []   # [{"node", "left"}]


func max_runes() -> int:
	return MAX_RUNES + (2 if "more_runes_1" in Character.perks else 0) + (2 if "more_runes_2" in Character.perks else 0)


func radius_mult() -> float:
	return Character.modifier("rune_radius")


## A Runecraft spell going off. Returns 1 if it placed something.
func cast(spell: SpellData, center: Vector3, power: float, caster: Node3D) -> int:
	if spell.rune == "ward":
		var circle := _make_disc(WARD_RADIUS, spell.color, true)
		caster.get_parent().add_child(circle)
		circle.global_position = _ground(caster, caster.global_position)
		wards.append({"node": circle, "left": spell.duration * power})
		return 1
	while runes.size() >= max_runes():
		_remove(runes[0])
	var rune := _make_disc(0.6 * radius_mult(), spell.color, false)
	caster.get_parent().add_child(rune)
	rune.global_position = _ground(caster, center)
	runes.append({"node": rune, "kind": spell.rune, "damage": spell.damage * power * Character.modifier("rune_damage"),
			"left": LIFETIME * Character.modifier("rune_lifetime"), "rearms": 1 if "living_runes" in Character.perks else 0,
			"wait": 0.0})
	return 1


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	for entry in runes.duplicate():
		if not is_instance_valid(entry["node"]):
			runes.erase(entry)
			continue
		entry["left"] -= delta
		if entry["left"] <= 0.0:
			_remove(entry)
			continue
		entry["wait"] -= delta
		if entry["wait"] <= 0.0 and not _victims(entry["node"].global_position, TRIGGER * radius_mult()).is_empty():
			go_off(entry)
	for ward in wards.duplicate():
		ward["left"] -= delta
		if ward["left"] <= 0.0 or not is_instance_valid(ward["node"]):
			if is_instance_valid(ward["node"]):
				ward["node"].queue_free()
			wards.erase(ward)
		elif player and player.global_position.distance_to(ward["node"].global_position) <= WARD_RADIUS + 0.2:
			_refresh(player, "rune_ward")
			if "steady_ward" in Character.perks:
				_refresh(player, "rune_ward_steady")
			if "ward_of_renewal" in Character.perks:
				_refresh(player, "rune_ward_renewal")


## A rune goes off where it lies (an enemy stepped close, or a neighbour went off).
func go_off(entry: Dictionary) -> void:
	if not entry in runes:
		return
	var at: Vector3 = entry["node"].global_position
	var hits := 0
	for enemy in _victims(at, BLAST * radius_mult()):
		var damage: float = entry["damage"]
		if "ambusher" in Character.perks and enemy.has_method("is_unaware") and enemy.is_unaware():
			damage *= 2.0   # it never saw the rune coming
		if damage > 0.0:
			enemy.take_hit(damage, at, 4.0, 20.0)
		var effect: String = EFFECTS.get(entry["kind"], "")
		if effect != "" and enemy.has_method("add_effect"):
			enemy.add_effect(effect)
		if "runic_snare" in Character.perks and entry["kind"] != "binding" and enemy.has_method("add_effect"):
			enemy.add_effect("bound")
			enemy.effects.active["bound"]["time_left"] = 1.0
		hits += 1
	Sfx.play_at("hit_heavy", at, -2.0)
	Skills.add_xp("runecraft", 2.0 + entry["damage"] * hits / 5.0)
	if entry["rearms"] > 0:
		entry["rearms"] -= 1   # Living Runes: it draws itself again, after a moment
		entry["wait"] = REARM_TIME
	else:
		_remove(entry)
	if "chain_runes" in Character.perks:
		for other in runes.duplicate():
			if other != entry and is_instance_valid(other["node"]) and other["node"].global_position.distance_to(at) <= CHAIN_RADIUS:
				go_off(other)


func _refresh(player: Node, id: String) -> void:
	player.effects.apply(id)
	player.effects.active[id]["time_left"] = 0.3   # lasts while you stand in the circle


func _remove(entry: Dictionary) -> void:
	runes.erase(entry)
	if is_instance_valid(entry["node"]):
		entry["node"].queue_free()


## Living enemies (not yours) within `radius` of `at`.
func _victims(at: Vector3, radius: float) -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(e):
		return e is Node3D and e.is_visible_in_tree() and not Binding.is_bound(e) and not Glamour._dead(e) \
				and e.has_method("take_hit") and e.global_position.distance_to(at) <= radius)


## Clear everything (a new level, or a load).
func reset() -> void:
	for entry in runes.duplicate():
		_remove(entry)
	for ward in wards:
		if is_instance_valid(ward["node"]):
			ward["node"].queue_free()
	wards.clear()


func _make_disc(radius: float, color: Color, ring: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Ward" if ring else "Rune"
	var mesh := MeshInstance3D.new()
	if ring:
		var torus := TorusMesh.new()
		torus.inner_radius = radius - 0.08
		torus.outer_radius = radius
		mesh.mesh = torus
	else:
		var disc := CylinderMesh.new()
		disc.top_radius = radius
		disc.bottom_radius = radius
		disc.height = 0.03
		mesh.mesh = disc
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material_override = mat
	mesh.position.y = 0.03
	root.add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.8
	light.omni_range = radius + 1.5
	light.position.y = 0.4
	root.add_child(light)
	return root


func _ground(caster: Node3D, point: Vector3) -> Vector3:
	var down := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 8.0, 1)
	var hit := caster.get_world_3d().direct_space_state.intersect_ray(down)
	return hit["position"] if not hit.is_empty() else point
