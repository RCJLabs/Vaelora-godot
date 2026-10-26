extends Node

# Fast travel between places you've discovered, in any region. Autoloaded as
# "FastTravel". docs/godot-starter/MAP.md, "Fast travel".
#
# The places are each region's MapMarkers, read straight from the region scenes
# (so a level that isn't loaded still lists them; markers must sit directly under
# the level root). Discovered ones (MapMarker.is_discovered: a story flag) show
# in Tab → World. Travelling passes time (the clock and Survival go on) and puts
# you at the marker's arrival point (MapMarker.arrival_point). Not in Hardcore, not
# with enemies about, not over-encumbered, and only from outdoors (an interior
# isn't a region).

const REGIONS := [
	{"scene": "res://levels/test_level.tscn", "name": "The Greywater Vale"},
	{"scene": "res://levels/weirholt.tscn", "name": "Weirholt and the Riverlands"},
	{"scene": "res://levels/grieving_fields.tscn", "name": "The Grieving Fields"},
	{"scene": "res://levels/ilunhall.tscn", "name": "Ilunhall"},
	{"scene": "res://levels/karrowdeep.tscn", "name": "Karrowdeep"},
]
const MIN_HOURS := 0.25
const METRES_PER_HOUR := 400.0   # the levels are a compressed world: a short walk is an hour or so
const REGION_HOURS := 3.0        # the road between two regions

var _places := {}   # scene path -> Array of place dictionaries (cached)


## Every place in a region scene: {id, name, kind, position, arrival, node, scene, region}.
func places_in(scene_path: String) -> Array:
	if _places.has(scene_path):
		return _places[scene_path]
	var found := []
	var packed := load(scene_path) as PackedScene
	if packed:
		var state := packed.get_state()
		for i in state.get_node_count():
			if str(state.get_node_path(i, true)) != ".":   # only direct children of the root
				continue
			var props := {}
			for j in state.get_node_property_count(i):
				props[state.get_node_property_name(i, j)] = state.get_node_property_value(i, j)
			var script = props.get("script")
			if not (script is Script and script.resource_path == "res://props/map_marker.gd"):
				continue
			var node_name := str(state.get_node_name(i))
			var xform: Transform3D = props.get("transform", Transform3D.IDENTITY)
			var offset: Vector3 = props.get("arrival_offset", MapMarker.DEFAULT_ARRIVAL)
			var id: String = props.get("location_id", "")
			found.append({
				"id": id if id != "" else node_name.to_snake_case(),
				"name": props.get("display_name", node_name),
				"kind": int(props.get("kind", 0)),
				"starts_discovered": bool(props.get("starts_discovered", false)),
				"position": xform.origin,
				"arrival": xform.origin + offset,
				"node": node_name,
				"scene": scene_path,
				"region": region_name(scene_path),
			})
	_places[scene_path] = found
	return found


func region_name(scene_path: String) -> String:
	for r in REGIONS:
		if r["scene"] == scene_path:
			return r["name"]
	return ""


func is_discovered(place: Dictionary) -> bool:
	return place["starts_discovered"] or GameState.has_flag("discovered_" + place["id"])


## Discovered places, region by region.
func discovered() -> Array:
	var out := []
	for r in REGIONS:
		for place in places_in(r["scene"]):
			if is_discovered(place):
				out.append(place)
	return out


## Why you can't fast travel right now, or "".
func why_not() -> String:
	var player := get_tree().get_first_node_in_group("player")
	var scene := get_tree().current_scene
	if player == null or player.is_dead:
		return "You can't travel now."
	if Character.modes["hardcore"]:
		return "Hardcore: no fast travel. You walk."   # ROADMAP, Hardcore v1
	if scene == null or region_name(scene.scene_file_path) == "":
		return "Find your way outside first."
	if RestMenu.enemies_nearby(player.global_position):
		return "Not with enemies nearby."
	if player.is_over_encumbered():
		return "You're carrying too much to travel."
	return ""


## Hours a trip to `place` takes from where you stand.
func hours_to(place: Dictionary) -> float:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var scene := get_tree().current_scene
	if player == null or scene == null:
		return MIN_HOURS
	if scene.scene_file_path != place["scene"]:
		return REGION_HOURS
	return maxf(MIN_HOURS, player.global_position.distance_to(place["position"]) / METRES_PER_HOUR)


## Go there: time passes, then you're at its arrival point. True if you went.
func go(place: Dictionary) -> bool:
	var reason := why_not()
	var player := get_tree().get_first_node_in_group("player")
	if reason != "" or not is_discovered(place):
		if player:
			player.hud.notify(reason if reason != "" else "You haven't found that place yet.")
		return false
	var hours := hours_to(place)
	WorldClock.advance(hours)
	Survival.tick(hours, false)
	if get_tree().current_scene.scene_file_path == place["scene"]:
		player.arrive_at_marker(place["node"])
		player.hud.notify("You travel to %s. %s" % [place["name"], WorldClock.text()])
	else:
		SaveSystem.travel(place["scene"], place["node"])
	return true
