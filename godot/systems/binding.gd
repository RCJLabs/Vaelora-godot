extends Node

# Binding: calling things and holding them. Autoloaded as "Binding". Its spells
# (SpellData.binding) are cast by player_magic.gd through cast().
# docs/godot-starter/BINDING.md; the lore is docs/lore/MAGIC.md ("Binding").
#   call_wolf  a wolf-spirit, pale and glowing, where you aim
#   guardian   a stone echo of a Vael guardian: slow, heavy, hard to kill
#   raise      the nearest corpse (wolf or bandit-kind) where you aim stands back up
#   bind       roots the enemy nearest where you aim (it can't move; it can still bite)
#
# Called things fight for you through Glamour's charm (they go for the nearest
# enemy) and enemies fight back (Targeting counts them like companions). With no
# fight, they follow you. When their time runs out, or they fall, they're gone:
# no pelt, no purse, nothing saved. You can hold one at a time (perks: more);
# calling another sends the oldest back. Your own swings pass through them.
#
# 🔒 What you call are echoes of Vael-creatures that remember their masters. At
# high corruption, now and then, one looks at you as if it knows what you are.

const WOLF := preload("res://enemies/wolf.tscn")
const BANDIT := preload("res://enemies/bandit.tscn")
const SPIRIT := Color(0.55, 0.8, 1.0)
const STONE := Color(0.5, 0.5, 0.47)
const RAISED := Color(0.42, 0.5, 0.4)
const FOLLOW_GAP := 2.5        # metres behind you a summon idles
const BIND_EFFECT := "bound"
const BIND_RADIUS := 3.0       # Binding Circle

var summons := []              # [{"node", "left", "cost", "corpse"}], oldest first


func max_summons() -> int:
	return 3 if "host_of_echoes" in Character.perks else (2 if "twin_souls" in Character.perks else 1)


## A Binding spell going off at `center`. `power` scales how long it lasts. Returns
## how many things it called or held.
func cast(spell: SpellData, center: Vector3, power: float, caster: Node3D, cost: float) -> int:
	var seconds := spell.duration * power
	match spell.binding:
		"bind":
			var held := 0
			var targets := _enemies_near(caster, center, spell.radius)
			if "binding_circle" in Character.perks and not targets.is_empty():
				targets = _enemies_near(caster, targets[0].global_position, BIND_RADIUS)
			elif not targets.is_empty():
				targets = [targets[0]]
			for enemy in targets:
				if enemy.has_method("add_effect") and enemy.get("effects"):
					enemy.effects.apply(BIND_EFFECT)
					enemy.effects.active[BIND_EFFECT]["time_left"] = seconds * Character.modifier("bind_duration")
					held += 1
			return held
		"call_wolf":
			var count := 2 if "spirit_pack" in Character.perks else 1
			for i in count:
				_call(WOLF.instantiate(), _ground(caster, center + Vector3(i * 1.2, 0, 0)), SPIRIT, "Wolf-Spirit",
						seconds * Character.modifier("summon_duration"), cost / count, caster)
			return count
		"guardian":
			var echo: Node3D = BANDIT.instantiate()
			echo.max_health = 160.0
			echo.run_speed = 3.6
			echo.attack_damage = 16.0
			echo.scale = Vector3.ONE * 1.25
			_call(echo, _ground(caster, center), STONE, "Stone Echo", seconds * Character.modifier("summon_duration"), cost, caster)
			return 1
		"raise":
			var corpse := _nearest_corpse(caster, center, spell.radius + 2.0)
			if corpse == null:
				caster.hud.notify("Nothing here to raise.")
				return 0
			var risen: Node3D = load(corpse.scene_file_path).instantiate()
			corpse.visible = false
			corpse.process_mode = Node.PROCESS_MODE_DISABLED
			_call(risen, corpse.global_position, RAISED, "Risen", seconds * Character.modifier("summon_duration") * Character.modifier("raise_duration"),
					cost, caster, corpse)
			if risen.get("stats"):
				risen.stats.max_health *= Character.modifier("raise_health")
				risen.stats.health = risen.stats.max_health
			return 1
	return 0


func _call(node: Node3D, at: Vector3, tint: Color, label: String, seconds: float, cost: float, caster: Node3D, corpse: Node3D = null) -> void:
	while summons.size() >= max_summons():
		_dismiss(summons[0])
	caster.get_parent().add_child(node)
	node.global_position = at
	node.remove_from_group("persistent")   # not saved: it's gone when the spell is
	node.remove_from_group("captors")      # a stone echo doesn't take prisoners
	node.add_to_group("bound")
	node.set_meta("bound", true)
	node.set_meta("display_name", label)
	_tint(node, tint)
	var stats = node.get("stats")
	if stats:
		stats.max_health *= Character.modifier("summon_health")
		stats.health = stats.max_health
		stats.died.connect(_on_summon_died.bind(node))
	for prop in ["bite_damage", "attack_damage"]:
		if node.get(prop) != null:
			node.set(prop, node.get(prop) * Character.modifier("summon_damage"))
	Glamour.charm(node, seconds + 60.0)   # on our side for as long as it's here
	summons.append({"node": node, "left": seconds, "cost": cost, "corpse": corpse})
	if Corruption.tier() >= 2 and randf() < 0.35:
		caster.hud.notify("The %s looks at you a moment too long, as if it knows what you are." % label.to_lower())


func _tint(node: Node, tint: Color) -> void:
	if node.get("_fur") is StandardMaterial3D:   # a wolf
		node._fur.albedo_color = tint
		node.set("fur_color", tint)
		if tint == SPIRIT:
			node._fur.emission_enabled = true
			node._fur.emission = tint
			node._fur.emission_energy_multiplier = 0.6
	elif node.get("_cloth") is StandardMaterial3D:   # a bandit
		node._cloth.albedo_color = tint
		node.set("_cloth_color", tint)


func _physics_process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	for entry in summons.duplicate():
		var node = entry["node"]
		if not is_instance_valid(node):
			summons.erase(entry)
			continue
		entry["left"] -= delta
		if entry["left"] <= 0.0:
			_dismiss(entry)
			continue
		if player and node.get("home") != null:
			# "Home" is at your heels: with nobody to fight, it comes back to you.
			var behind: Vector3 = player.global_position + player.global_transform.basis.z * FOLLOW_GAP
			node.home = behind
			var states = node.get("State")
			if states != null and node.state == states["IDLE"] and node.global_position.distance_to(behind) > 6.0:
				node.state = states["RETURN"]   # fallen behind: catch up


## Is this one of yours? (Your swings pass through them.)
func is_bound(node: Object) -> bool:
	return is_instance_valid(node) and node is Node and node.has_meta("bound")


func _on_summon_died(node: Node) -> void:
	for entry in summons:
		if entry["node"] == node:
			if "soul_tether" in Character.perks:
				var player := get_tree().get_first_node_in_group("player")
				if player:
					player.stats.magicka = minf(player.stats.magicka + entry["cost"] * 0.25, player.stats.max_magicka)
			# Gone in a moment: an echo leaves no body to search.
			get_tree().create_timer(0.8).timeout.connect(func(): _dismiss(entry))
			return


func _dismiss(entry: Dictionary) -> void:
	summons.erase(entry)
	var node = entry["node"]
	if is_instance_valid(node):
		Glamour._end(node)
		node.queue_free()
	var corpse = entry["corpse"]
	if is_instance_valid(corpse):
		corpse.visible = true   # the body lies where it fell again
		corpse.process_mode = Node.PROCESS_MODE_INHERIT


## Send everything back (a new level, or a load).
func reset() -> void:
	for entry in summons.duplicate():
		_dismiss(entry)


func _ground(caster: Node3D, point: Vector3) -> Vector3:
	var down := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 8.0, 1)
	var hit := caster.get_world_3d().direct_space_state.intersect_ray(down)
	return (hit["position"] + Vector3.UP * 0.1) if not hit.is_empty() else point


## Living enemies (not yours) within `radius` of `center`, nearest first.
func _enemies_near(caster: Node3D, center: Vector3, radius: float) -> Array:
	var found := get_tree().get_nodes_in_group("enemy").filter(func(e):
		return e is Node3D and not is_bound(e) and not Glamour._dead(e) and e.is_visible_in_tree() \
				and e.global_position.distance_to(center) <= radius)
	found.sort_custom(func(a, b): return a.global_position.distance_to(center) < b.global_position.distance_to(center))
	return found


func _nearest_corpse(caster: Node3D, center: Vector3, radius: float) -> Node3D:
	var best: Node3D = null
	var best_dist := radius
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is Node3D and Glamour._dead(e) and e.is_visible_in_tree() and not is_bound(e) and e.scene_file_path in [WOLF.resource_path, BANDIT.resource_path]:
			var d: float = e.global_position.distance_to(center)
			if d < best_dist:
				best = e
				best_dist = d
	return best
