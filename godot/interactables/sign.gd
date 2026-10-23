extends StaticBody3D

# A readable sign. Any physics body with a `prompt` property and an
# `interact(player)` method can be used with E - that's the whole contract.

@export var prompt: String = "Read sign"
@export_multiline var text: String = "Welcome, traveller."


func interact(player: Node) -> void:
	player.show_message(text)
