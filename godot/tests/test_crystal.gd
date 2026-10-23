extends "res://tests/test_base.gd"
# The stone-circle crystal: prompt, first touch teaches Flames and sets the flag,
# second touch gives the "remembers you" line, and its altar blocks walking through.
var f := 0
var p

func _initialize() -> void:
	var level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level)
	p = level.get_node("Player")
	# circle centre is (-11, 0, -9); stand 2 m south of it, facing north (-Z), look slightly down
	p.position = Vector3(-11, 0, -7)
	p.get_node("Head").rotation.x = deg_to_rad(-2)

func _physics_process(_d: float) -> bool:
	f += 1
	var hud = p.get_node("HUD")
	match f:
		60:
			near(p.global_position.y, 0.0, 0.1, "landed")
			ok(hud.prompt_label.text.ends_with("Touch the crystal"), "prompt", hud.prompt_label.text)
			Input.action_press("interact")
		61: Input.action_release("interact")
		64:
			ok(hud.message_label.text.begins_with("Cold light runs up your arm"), "first touch message", hud.message_label.text)
			ok(autoload("GameState").has_flag("touched_crystal"), "touched_crystal flag set")
			Input.action_press("interact")
		65: Input.action_release("interact")
		68:
			ok(hud.message_label.text == "The crystal hums softly. It remembers you.", "second touch message", hud.message_label.text)
			p.position = Vector3(-11, 0, -2); Input.action_press("move_forward")
		200:
			between(p.global_position.z, -8.3, -7.0, "stopped by the altar walking north")
			Input.action_release("move_forward")
			return done()
	return false
