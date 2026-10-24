class_name LevelMap
extends Node

# Tells the map screen what this level's map covers. One per level that has a map.
# The map is a live top-down picture of the level (an orthographic camera looking
# straight down), with markers drawn on top.
#   Area: the part of the world to show, as x / z (north is -z) and width / depth.
#   Camera Height: where the camera sits. Outdoors: above everything. Indoors: just
#   under the ceiling, so you see the rooms, not the roof.

@export var map_name: String = "Map"
@export var area := Rect2(-60, -60, 120, 120)
@export var camera_height: float = 80.0


func _ready() -> void:
	add_to_group("level_map")
