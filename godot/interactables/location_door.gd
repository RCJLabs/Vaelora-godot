extends StaticBody3D

# A door, hatch or cave mouth that takes you to another location (an interior,
# or back outside). Press E to travel. Health, effects, items and everything
# else come with you; the place you leave is remembered (WorldState).
#
# Set Target Scene to the location to load, and Target Marker to the name of a
# Marker3D in that scene where you arrive (facing the marker's -Z direction).

@export_file("*.tscn") var target_scene: String
@export var target_marker: String = ""
## Shown as "[E] Enter <name>" / "[E] Leave for <name>".
@export var destination_name: String = "the next area"
@export var verb: String = "Enter"

var prompt: String:
	get: return "%s %s" % [verb, destination_name]


func interact(_player: Node) -> void:
	SaveSystem.travel(target_scene, target_marker)
