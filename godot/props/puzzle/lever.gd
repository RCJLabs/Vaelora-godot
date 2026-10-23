extends StaticBody3D

# A wall lever: E flips it. Gates listen for it (PuzzleGate's Levers list).
# Remembers its position (WorldState).
# Scene: Lever (StaticBody3D, this) ├── Base mesh ├── Shape └── Handle (Node3D
# pivot; rotates on X between up and down) with the handle mesh under it.

signal toggled(on: bool)

@export var on := false
## Once pulled, it stays (for one-way mechanisms).
@export var one_way := false

@onready var handle: Node3D = $Handle

var prompt: String:
	get:
		if one_way and on:
			return ""
		return "Pull lever"


func _ready() -> void:
	add_to_group("persistent")
	WorldState.restore(self)
	handle.rotation.x = _angle()


func interact(_player: Node) -> void:
	if one_way and on:
		return
	on = not on
	create_tween().tween_property(handle, "rotation:x", _angle(), 0.25).set_trans(Tween.TRANS_BACK)
	Sfx.play_at("lever", global_position)
	toggled.emit(on)


func _angle() -> float:
	return deg_to_rad(-40.0 if on else 40.0)


func get_persist_state() -> Dictionary:
	return {"on": on}


func apply_persist_state(state: Dictionary) -> void:
	on = state.get("on", on)
	if is_node_ready():
		handle.rotation.x = _angle()
