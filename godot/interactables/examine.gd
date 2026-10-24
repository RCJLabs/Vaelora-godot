extends StaticBody3D

# Something to look at closely (E) that opens a conversation-style description
# with choices: a wrecked wagon, a strange stone. Like an NPC, but the prompt is
# whatever you set ("Search the wagon") and there's no one to talk to.

@export var prompt: String = "Examine"
@export var speaker: String = ""
@export_file("*.json") var dialogue_file: String


func interact(_player: Node) -> void:
	DialogueManager.start(dialogue_file, speaker)
