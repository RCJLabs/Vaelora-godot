extends "res://tests/test_base.gd"
# E-to-interact: read the sign, a closed door blocks, E opens it, then walk through.
var f := 0
var p: CharacterBody3D
var level: Node

func _initialize() -> void:
	level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level)
	p = level.get_node("Player")
	p.position = Vector3(-2, 0, -2)

func _physics_process(_d: float) -> bool:
	f += 1
	var hud = p.get_node("HUD")
	match f:
		30:
			ok(hud.prompt_label.text.ends_with("Read sign"), "sign prompt", hud.prompt_label.text)
			Input.action_press("interact")
		31: Input.action_release("interact")
		33:
			ok(hud.message_label.text.begins_with("Riverwatch - 2 leagues north."), "sign text", hud.message_label.text)
			p.global_position = Vector3(0, 0, -8)
		50:
			ok(hud.prompt_label.text.ends_with("Open door"), "door prompt", hud.prompt_label.text)
			Input.action_press("move_forward")
		110:
			between(p.global_position.z, -10.0, -9.0, "closed door stops the player")
			Input.action_release("move_forward"); p.global_position = Vector3(0, 0, -8)
		130: Input.action_press("interact")
		131: Input.action_release("interact")
		170:
			near(rad_to_deg(level.get_node("Door").rotation.y), 100.0, 5.0, "door swung open (degrees)")
			Input.action_press("move_forward")
		250:
			ok(p.global_position.z < -13.0, "walked through the open door", p.global_position.z)
			return done()
	return false
