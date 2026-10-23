extends StaticBody3D

# A campfire: warms you within heat_radius (Survival's cold), and E opens the
# rest menu to cook raw meat or sleep. Put the logs, flame and light under it.

@export var heat_radius: float = 4.0

var prompt := "Use campfire"


func _ready() -> void:
	add_to_group("heat_source")
	var stream := Sfx.loop("campfire_crackle")
	if stream == null:
		return
	var crackle := AudioStreamPlayer3D.new()
	crackle.stream = stream
	crackle.position.y = 0.4
	crackle.volume_db = -6.0
	crackle.unit_size = 2.5
	crackle.max_distance = 22.0
	add_child(crackle)
	crackle.play(randf() * crackle.stream.get_length())


func interact(_player: Node) -> void:
	RestMenu.open(self, true)
