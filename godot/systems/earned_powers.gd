extends Node

# Earned powers: active powers won through play (shrines, quests, the stones).
# Autoloaded as "EarnedPowers". docs/godot-starter/POWERS.md.
#
# They're abilities.json entries with an "earned" source:
#   {"quest": "silent_shrine"}   that quest is completed
#   {"essences": 3}              that many Wisp Essences released at the stone circle
#   {"flag": "name"}             a story flag
# Like quests, whether you have one is worked out from flags and quests, so it's
# saved with them. You hold one in the fourth power slot (T, touch IV), chosen in
# Tab → Powers (Character.earned_power); the first you earn goes there by itself.
# Powers marked "scripted" need code (activate()); the rest are an effect.
# They're meant to sit beside the starting powers, not above them.

signal earned(id: String)

const ESSENCE_FLAG := "released_wisp_%d"
const PEACE_RADIUS := 10.0
const PEACE_TIME := 10.0
const STEP_DISTANCE := 6.0
const GLARE_RANGE := 10.0
const GLARE_ANGLE := 30.0       # degrees either side of your aim
const GLARE_WISP_DAMAGE := 40.0
const KINDLE_RANGE := 20.0
const KINDLE_RADIUS := 3.0


func _ready() -> void:
	QuestLog.changed.connect(_check)   # after every flag or item change, and after a load


## Every earned power, in the order abilities.json lists them.
func all() -> Array:
	return Character.ability_list.keys().filter(func(id): return Character.ability_list[id].has("earned"))


func has(id: String) -> bool:
	var source: Dictionary = Character.ability_list.get(id, {}).get("earned", {})
	if source.has("quest"):
		return QuestLog.quests.has(source["quest"]) and QuestLog.status(source["quest"])["state"] == "completed"
	if source.has("essences"):
		return essences_released() >= int(source["essences"])
	if source.has("flag"):
		return GameState.has_flag(source["flag"])
	return false


func owned() -> Array:
	return all().filter(has)


## "Complete The Silent Shrine", "Release 3 Wisp Essences at the stones"
func how_to_earn(id: String) -> String:
	var source: Dictionary = Character.ability_list[id]["earned"]
	if source.has("quest"):
		return "Complete %s" % QuestLog.quests.get(source["quest"], {}).get("title", source["quest"])
	if source.has("essences"):
		return "Release %d Wisp Essences at the stone circle (%d so far)" % [int(source["essences"]), essences_released()]
	return "Found somewhere in the world"


## How many Wisp Essences you've released (props/floating_crystal.gd counts them).
func essences_released() -> int:
	var n := 0
	while GameState.has_flag(ESSENCE_FLAG % (n + 1)):
		n += 1
	return n


func essence_released() -> void:
	GameState.set_flag(ESSENCE_FLAG % (essences_released() + 1))


## Puts an earned power in the slot.
func choose(id: String) -> bool:
	if not has(id):
		return false
	Character.earned_power = id
	Character.changed.emit()
	return true


## Newly earned ones: say so, and fill an empty slot.
func _check() -> void:
	for id in owned():
		if id in Character.earned_seen:
			continue
		Character.earned_seen.append(id)
		if Character.earned_power == "":
			Character.earned_power = id
		earned.emit(id)
		var player := get_tree().get_first_node_in_group("player")
		if player and not QuestLog.silent:
			player.hud.notify("Power earned: %s (%s; Tab → Powers to change it)" % [Character.ability_list[id]["name"], InputHints.label("power_earned")])
		Character.changed.emit()


## A power that needs code ("scripted": true; earned ones, and the Ashen's Kinship).
## False if it can't go off now.
func activate(id: String, player: Node3D) -> bool:
	match id:
		"kinship":
			player.effects.apply("wisp_grace")
			player.effects.active["wisp_grace"]["time_left"] = 60.0
			player.effects.apply("kinship")
			return true
		"shrines_peace":
			for enemy in _enemies_near(player.global_position, PEACE_RADIUS):
				if not is_wisp(enemy):
					Glamour.calm(enemy, PEACE_TIME)
			return true
		"wisp_step":
			var camera: Camera3D = player.camera
			var forward := -camera.global_transform.basis.z
			forward.y = 0.0
			forward = forward.normalized()
			var from: Vector3 = player.global_position + Vector3(0, 0.9, 0)
			var query := PhysicsRayQueryParameters3D.create(from, from + forward * STEP_DISTANCE, 1)
			query.exclude = [player.get_rid()]
			var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
			var distance := STEP_DISTANCE if hit.is_empty() else maxf(from.distance_to(hit["position"]) - 0.6, 0.0)
			if distance < 0.5:
				player.hud.notify("No room to step.")
				return false
			player.global_position += forward * distance
			return true
		"lanterns_glare":
			var camera: Camera3D = player.camera
			var forward := -camera.global_transform.basis.z
			for enemy in _enemies_near(player.global_position, GLARE_RANGE):
				var to: Vector3 = enemy.global_position - player.global_position
				to.y = 0.0
				var flat := Vector3(forward.x, 0.0, forward.z)
				if to.length() > 0.01 and rad_to_deg(flat.angle_to(to)) > GLARE_ANGLE:
					continue
				if enemy.has_method("stagger"):
					enemy.stagger(2.0)
				if is_wisp(enemy):
					enemy.take_hit(GLARE_WISP_DAMAGE, player.global_position, 2.0, 0.0)
			return true
		"kindle":
			var camera: Camera3D = player.camera
			var from := camera.global_position
			var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_transform.basis.z * KINDLE_RANGE, 1 | 4)
			query.exclude = [player.get_rid()]
			var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
			var at: Vector3 = hit["position"] if not hit.is_empty() else from - camera.global_transform.basis.z * KINDLE_RANGE
			for enemy in _enemies_near(at, KINDLE_RADIUS):
				if enemy.has_method("add_effect"):
					enemy.add_effect("burning")
			SpellBurst.spawn(player.get_parent(), at, KINDLE_RADIUS, Color(1, 0.45, 0.1))
			return true
	return true


func is_wisp(node: Node) -> bool:
	return node.get_script() != null and node.get_script().resource_path.ends_with("wisp.gd")


func _enemies_near(at: Vector3, radius: float) -> Array:
	return get_tree().get_nodes_in_group("enemy").filter(func(e):
		return e is Node3D and e.is_visible_in_tree() and e.has_method("take_hit") and not Glamour._dead(e) \
				and not Binding.is_bound(e) and e.global_position.distance_to(at) <= radius)
