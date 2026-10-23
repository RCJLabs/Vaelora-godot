extends AnimatableBody3D

# A door that swings open/closed around its own origin (the hinge).
# Scene structure:
#   Door (AnimatableBody3D)   <- this script, placed AT the hinge; it rotates
#   ├── MeshInstance3D        <- offset sideways by half the door width
#   └── CollisionShape3D      <- same offset as the mesh
#
# The body itself must rotate. Rotating a parent Node3D instead moves the mesh
# but leaves the collision behind (tested in Godot 4.3).

@export var open_angle_degrees: float = 100.0
@export var swing_time: float = 0.4

var prompt: String = "Open door"
var is_open := false
var _tween: Tween


func interact(_player: Node) -> void:
	is_open = not is_open
	prompt = "Close door" if is_open else "Open door"
	var target := deg_to_rad(open_angle_degrees) if is_open else 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "rotation:y", target, swing_time)
