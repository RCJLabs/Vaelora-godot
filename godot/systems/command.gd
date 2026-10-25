extends Node

# Command: leading the people who fight beside you. Autoloaded as "Command".
# docs/godot-starter/COMPANIONS.md, "The Command skill".
#
#   Stronger allies  your companion does +1% damage and has +1% health per level
#                    above 15 (companions/companion.gd asks damage_mult/health_mult).
#   Point it out     press Command (G, or D-pad up) aiming at an enemy: your companion
#                    goes for it, and with Pack Leader so do things you've called
#                    (Binding). Marked Target makes it take more from everyone.
#   XP               from the damage your companion deals, and from orders.

const POINT_RANGE := 40.0
const POINT_ANGLE := 12.0      # degrees off your aim it still counts
const MARK_SECONDS := 10.0
const GUARD_RANGE := 6.0       # Bodyguard

var ordered_target: Node3D = null   # who you pointed out, while it lives


func _level() -> int:
	return Skills.levels.get("command", Skills.START_LEVEL)


func damage_mult() -> float:
	return (1.0 + 0.01 * (_level() - Skills.START_LEVEL)) * Character.modifier("ally_damage")


func health_mult() -> float:
	return (1.0 + 0.01 * (_level() - Skills.START_LEVEL)) * Character.modifier("ally_health")


## What your companion's blows and bolts landed for (Command XP).
func ally_dealt(amount: float) -> void:
	if amount > 0.0:
		Skills.add_xp("command", amount / 10.0)


# --- pointing out a target -----------------------------------------------------------

## The enemy nearest your aim, within POINT_RANGE and POINT_ANGLE, or null.
func aimed_enemy(player: Node3D) -> Node3D:
	var camera: Camera3D = player.camera
	var forward := -camera.global_transform.basis.z
	var best: Node3D = null
	var best_angle := deg_to_rad(POINT_ANGLE)
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not enemy is Node3D or not enemy.has_method("take_hit") or not enemy.is_visible_in_tree() \
				or Glamour._dead(enemy) or Binding.is_bound(enemy):
			continue
		var to: Vector3 = (enemy.global_position + Vector3(0, 0.6, 0)) - camera.global_position
		if to.length() > POINT_RANGE:
			continue
		var angle := forward.angle_to(to)
		if angle < best_angle:
			best = enemy
			best_angle = angle
	return best


## The Command key: point out what you're aiming at. Returns it, or null.
func point_out(player: Node3D) -> Node3D:
	var enemy := aimed_enemy(player)
	var companion := Companions.body()
	var called := get_tree().get_nodes_in_group("bound").size() > 0 and "pack_leader" in Character.perks
	if companion == null and not called:
		player.hud.notify("There's nobody to command.")
		return null
	if enemy == null:
		player.hud.notify("Aim at an enemy to point it out.")
		return null
	ordered_target = enemy
	if companion:
		companion.attack_order(enemy)
	if "marked_target" in Character.perks:
		Sight._apply(enemy, "commanded", MARK_SECONDS)
	Skills.add_xp("command", 1.0)
	player.hud.notify("%s!" % ("Take it down" if companion == null else "%s, that one" % Companions.DEFS[Companions.active()]["name"]))
	return enemy


## The pointed-out enemy, if it's still a fight (Glamour asks, for called things).
func order_for_bound() -> Node3D:
	if "pack_leader" in Character.perks and is_instance_valid(ordered_target) and not Glamour._dead(ordered_target):
		return ordered_target
	return null


## You hit something (PlayerCombat): Coordinated Strike readies your companion's next blow.
func player_hit(target: Node) -> void:
	if target == ordered_target and "coordinated_strike" in Character.perks:
		var companion := Companions.body()
		if companion:
			companion.next_blow_mult = 2.0


# --- auras -------------------------------------------------------------------------

func _process(_delta: float) -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player == null or get_tree().paused:
		return
	if is_instance_valid(ordered_target) and Glamour._dead(ordered_target):
		ordered_target = null
	var companion := Companions.body()
	var up: bool = companion != null and not companion.is_down
	_keep(player, "guarded", "bodyguard" in Character.perks and up
			and companion.global_position.distance_to(player.global_position) <= GUARD_RANGE)
	_keep(player, "avenging", "battle_brothers" in Character.perks and companion != null and companion.is_down)


# An always-on effect while `on` holds (it has no duration of its own).
func _keep(player: Node, id: String, on: bool) -> void:
	if on and not player.effects.has(id):
		player.effects.apply(id)
	elif not on and player.effects.has(id):
		player.effects.remove(id)


func reset() -> void:
	ordered_target = null
