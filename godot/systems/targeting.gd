extends Node

# Who an enemy goes after. Autoloaded as "Targeting". Wolves and bandit-kind ask
# foe_for() every frame:
#   1. Glamour first: a decoy, a charmed or frenzied packmate, or (when charmed
#      or frenzied) another enemy (systems/glamour.gd).
#   2. Otherwise the nearer of the player (unless invisible) and a companion
#      who's on their feet. An enemy sticks with whoever it's after unless the
#      other is STICK metres closer, so it doesn't flip between two people
#      standing side by side, and a companion who hits an enemy draws it
#      (provoke()).
# null means nobody to fight (you're invisible and alone, or it's charmed with no
# one to turn on): the enemy gives up and heads home.
# Wisps, the stone guardian and The First still only go for the player, and see
# through Invisibility.

const STICK := 2.5


func foe_for(enemy: Node3D, player: Node3D) -> Node3D:
	var glamoured := Glamour.target_for(enemy, player)
	if glamoured != player:
		return glamoured
	var people: Array = get_tree().get_nodes_in_group("companion").filter(_can_be_fought)
	if not (player.get("effects") and player.effects.has("invisible")):
		people.push_front(player)
	if people.size() <= 1:
		return people[0] if people.size() == 1 else null
	var current = enemy.get_meta("foe") if enemy.has_meta("foe") else people[0]
	if not (is_instance_valid(current) and current in people):
		current = people[0]
	var best: Node3D = current
	var best_dist := enemy.global_position.distance_to(current.global_position) - STICK
	for other in people:
		var d := enemy.global_position.distance_to(other.global_position)
		if d < best_dist:
			best = other
			best_dist = d
	enemy.set_meta("foe", best)
	return best


## `by` (a companion) has hit `enemy`: it turns on them.
func provoke(enemy: Node, by: Node3D) -> void:
	if is_instance_valid(enemy):
		enemy.set_meta("foe", by)


func _can_be_fought(companion: Node) -> bool:
	return companion.is_visible_in_tree() and not companion.get("is_down")
