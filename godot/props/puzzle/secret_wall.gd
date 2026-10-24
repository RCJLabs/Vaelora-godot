extends StaticBody3D

# A section of wall that sinks into the floor when examined (E): the way into a
# hidden room. The clue is in the prompt and whatever the level puts next to it
# (scrape marks on the floor). Remembered with a story flag, so it stays open.

@export var opened_flag: String = "found_hidden_chamber"
@export var prompt_text: String = "Examine the scrape marks"
@export_multiline var open_message: String = "Something heavy has been dragged across the floor here, right up to the wall. You push where the marks end, and the wall gives."
## How far it sinks (its own height, so it disappears into the floor).
@export var sink_depth: float = 2.8

var prompt: String = ""


func _ready() -> void:
	if GameState.has_flag(opened_flag):
		_open(false)
	else:
		prompt = prompt_text


func interact(player: Node) -> void:
	if GameState.has_flag(opened_flag):
		return
	GameState.set_flag(opened_flag)
	player.show_message(open_message)
	_open(true)


func is_open() -> bool:
	return GameState.has_flag(opened_flag)


func _open(animate: bool) -> void:
	prompt = ""
	var target := position - Vector3(0, sink_depth, 0)
	if animate:
		Sfx.play_at("gate_rumble", global_position)
		var tween := create_tween()
		tween.tween_property(self, "position", target, 1.6).set_trans(Tween.TRANS_QUAD)
		tween.tween_callback(func(): collision_layer = 0)
	else:
		position = target
		collision_layer = 0
