extends StaticBody3D

# A character you can talk to. Set Display Name and Dialogue File in the Inspector.

@export var display_name: String = "Stranger"
@export_file("*.json") var dialogue_file: String

var prompt: String:
	get: return "Talk to %s" % display_name


func interact(_player: Node) -> void:
	DialogueManager.start(dialogue_file, display_name)
