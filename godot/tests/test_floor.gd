extends "res://tests/test_base.gd"
# A level's floor holds the player up: after 3 s they stand on it, not fallen through.
# Argument: the scene to load (default the test level).
var frames := 0
var player: CharacterBody3D

func _initialize() -> void:
	var level: Node = load(arg("res://levels/test_level.tscn")).instantiate()
	root.add_child(level)
	player = level.get_node("Player")

func _physics_process(_delta: float) -> bool:
	frames += 1
	if frames == 180:
		ok(player.is_on_floor(), "player is on the floor")
		between(player.global_position.y, -0.3, 1.0, "player height")
		return done()
	return false
