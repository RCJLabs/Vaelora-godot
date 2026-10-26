class_name MapMarker
extends Node3D

# A named place for the compass and the map. Walk within Discover Radius and it's
# discovered ("Discovered: Stone Circle"); from then on it shows on the compass
# and the map. Discovery is a story flag ("discovered_<id>"), so it's saved.
# Undiscovered places show on the compass as a dim icon when you're near.

enum Kind { LANDMARK, SETTLEMENT, CAMP, DUNGEON }

@export var location_id: String = ""
@export var display_name: String = "Somewhere"
@export var kind: Kind = Kind.LANDMARK
@export var discover_radius: float = 18.0
## Known from the start (where the game begins).
@export var starts_discovered := false
## Where fast travel puts you, from the marker (it often sits in the middle of the place).
@export var arrival_offset := DEFAULT_ARRIVAL

const DEFAULT_ARRIVAL := Vector3(0, 0.3, 5)

var _check_left := 0.0


func _ready() -> void:
	add_to_group("map_marker")
	if location_id == "":
		location_id = name.to_snake_case()


## Where you appear when you fast travel here (FastTravel).
func arrival_point() -> Vector3:
	return global_position + arrival_offset


func is_discovered() -> bool:
	return starts_discovered or GameState.has_flag("discovered_" + location_id)


func _physics_process(delta: float) -> void:
	_check_left -= delta
	if _check_left > 0.0 or is_discovered():
		return
	_check_left = 0.5
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player and player.global_position.distance_to(global_position) <= discover_radius:
		GameState.set_flag("discovered_" + location_id)
		player.hud.notify("Discovered: %s" % display_name)
		Hints.show_once("map", "New places appear on your compass and on the map: press %s (or the map tab in %s)." % [Hints.key("map"), Hints.key("character_menu")])
