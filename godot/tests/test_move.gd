extends "res://tests/test_base.gd"
# Basic movement: walk speed and jump height.
var f := 0
var p: CharacterBody3D
var max_y := 0.0
var start: Vector3

func _initialize() -> void:
	var level: Node = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level)
	p = level.get_node("Player")

func _physics_process(_d: float) -> bool:
	f += 1
	if f == 90:
		ok(p.is_on_floor(), "landed after spawning")
		start = p.global_position
		Input.action_press("move_forward")
	if f == 150:
		near(Vector2(p.velocity.x, p.velocity.z).length(), p.walk_speed, 0.1, "walk speed after 1 s")
		between(start.distance_to(p.global_position), 4.0, 5.0, "distance walked in 1 s")
		Input.action_release("move_forward"); Input.action_press("jump")
	if f == 152: Input.action_release("jump")
	if f > 150: max_y = max(max_y, p.global_position.y)
	if f == 260:
		between(max_y, 0.95, 1.2, "jump peak")
		ok(p.is_on_floor(), "back on the floor after the jump")
		return done()
	return false
