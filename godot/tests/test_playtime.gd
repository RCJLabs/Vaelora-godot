extends "res://tests/test_base.gd"
# Play time counts while playing and stops while the pause menu is open.
var f := 0
var t0 := 0.0

func _initialize() -> void:
	var level = load("res://levels/test_level.tscn").instantiate()
	root.add_child(level); current_scene = level

func _physics_process(_d: float) -> bool:
	f += 1
	var GS = autoload("GameState")
	if f == 10: t0 = GS.play_time
	if f == 130:
		between(GS.play_time - t0, 1.5, 2.6, "play time grew over 2 s of play")
		autoload("PauseMenu").open_page("main"); t0 = GS.play_time
	if f == 250:
		near(GS.play_time - t0, 0.0, 0.001, "play time while paused")
		return done()
	return false
