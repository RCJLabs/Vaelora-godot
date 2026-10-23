extends StaticBody3D

# A campfire: warms you within heat_radius (Survival's cold), and E opens the
# rest menu to cook raw meat or sleep. Put the logs, flame and light under it.

@export var heat_radius: float = 4.0

var prompt := "Use campfire"


func _ready() -> void:
	add_to_group("heat_source")


func interact(_player: Node) -> void:
	RestMenu.open(self, true)
