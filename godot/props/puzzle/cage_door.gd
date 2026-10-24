extends StaticBody3D

# The door of a captors' cage (systems/defeat.gd puts you behind it). Press E a few
# times to work the lock; then it swings open. A new capture locks it again.

@export var tries_needed: int = 4
## Set when the lock springs (the Lost Wagon's driver waits for it). Optional.
@export var opened_flag: String = ""

var tries_left := 0
var prompt: String:
	get: return "" if tries_left <= 0 else ("Work at the lock" if tries_left == tries_needed else "Keep working at the lock")
var _closed_rotation := 0.0


func _ready() -> void:
	add_to_group("cage_door")
	_closed_rotation = rotation.y
	lock()


func lock() -> void:
	tries_left = tries_needed
	rotation.y = _closed_rotation
	$Shape.disabled = false


func interact(player: Node) -> void:
	if tries_left <= 0:
		return
	tries_left -= 1
	Sfx.play_at("lever", global_position, -6.0)
	if tries_left > 0:
		player.show_message("The lock gives a little.")
		return
	player.show_message("The lock springs open.")
	if opened_flag != "":
		GameState.set_flag(opened_flag)
	$Shape.disabled = true
	create_tween().tween_property(self, "rotation:y", _closed_rotation + deg_to_rad(100), 0.6)
