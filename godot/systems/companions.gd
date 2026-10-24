extends Node

# Who's travelling with you. Autoloaded as "Companions". One companion at a time.
#
# Following is a story flag, "companion_<id>", so it saves and loads with
# everything else: a dialogue choice sets it to recruit someone, and this node
# makes them appear behind you (and hides the person at their post, whose
# StoryPresence has hide_flag "companion_<id>"). In the level, they're a
# companion.gd body.
#
# Their own dialogue (dialogue/companion_<id>.json) gives orders by setting a
# command flag, which is acted on and cleared at once:
#   companion_cmd_wait     wait here
#   companion_cmd_follow   follow again
#   companion_cmd_dismiss  go home (back to their post)

const DEFS := {
	"brannoc": {"name": "Brannoc", "dialogue": "res://dialogue/companion_brannoc.json", "damage": 12.0, "reach": 1.9},
	"zora": {"name": "Zora", "dialogue": "res://dialogue/companion_zora.json", "damage": 9.0, "reach": 6.0, "attack_interval": 1.6},
}
const COMMANDS := ["companion_cmd_wait", "companion_cmd_follow", "companion_cmd_dismiss"]
const COMPANION_SCRIPT := preload("res://companions/companion.gd")


func _ready() -> void:
	GameState.flag_set.connect(_on_flag_set)


## The id of whoever's following you, or "".
func active() -> String:
	for id in DEFS:
		if GameState.has_flag("companion_" + id):
			return id
	return ""


## Their body in the current level, if they're in it.
func body() -> Node3D:
	var id := active()
	if id == "" or get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("Companion_" + id) as Node3D


func _process(_delta: float) -> void:
	# Arriving in a level (or loading a save) with someone following: bring them along.
	var id := active()
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if id != "" and player and body() == null:
		var companion := COMPANION_SCRIPT.new()
		companion.setup(id, DEFS[id])
		get_tree().current_scene.add_child(companion)
		companion.arrive_behind(player)


func _on_flag_set(flag: String) -> void:
	if not flag in COMMANDS:
		return
	GameState.clear_flag(flag)   # an order, not a memory
	var companion := body()
	match flag:
		"companion_cmd_wait":
			if companion:
				companion.state = companion.State.WAIT
		"companion_cmd_follow":
			if companion:
				companion.state = companion.State.FOLLOW
		"companion_cmd_dismiss":
			if companion:
				companion.queue_free()
			GameState.clear_flag("companion_" + active())
