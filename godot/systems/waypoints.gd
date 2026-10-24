class_name Waypoints
extends RefCounted

# What the compass and the map point at: the places you know (MapMarker nodes) and
# where your active quests want you to go next.
#
# Quest markers come from quests.json: an objective can name the node(s) it's about,
#   "marker": "Maren"     or     "marker": ["RuneShard1", "RuneShard2", "RuneShard3"]
# Each name is looked up in the current level; any that aren't there (another level,
# already picked up) are skipped. So a quest only shows markers in the level it's in.


## [{"title": quest title, "text": objective, "position": Vector3}] for every target of
## every active quest's next objective, in the current level.
static func quest_targets(tree: SceneTree) -> Array:
	var targets := []
	var level := tree.current_scene
	if level == null:
		return targets
	for id in QuestLog.quests:
		var status: Dictionary = QuestLog.status(id)
		if status["state"] != "active":
			continue
		for objective in status["objectives"]:
			if objective["done"]:
				continue
			var names = objective.get("marker", [])
			if names is String:
				names = [names]
			for marker_name in names:
				var node := level.find_child(marker_name, true, false) as Node3D
				if node and not node.is_queued_for_deletion():
					targets.append({"title": QuestLog.quests[id]["title"], "text": objective["text"],
							"position": node.global_position})
			break   # only the next objective of each quest
	return targets


## Every MapMarker in the current level.
static func locations(tree: SceneTree) -> Array:
	return tree.get_nodes_in_group("map_marker")


## Compass bearing in degrees from `from` to `to`: 0 = north (-Z), 90 = east (+X).
static func bearing(from: Vector3, to: Vector3) -> float:
	return rad_to_deg(atan2(to.x - from.x, -(to.z - from.z)))


## The way a node is facing, as a bearing (its -Z axis).
static func heading(node: Node3D) -> float:
	var forward := -node.global_transform.basis.z
	return rad_to_deg(atan2(forward.x, -forward.z))
