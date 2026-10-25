class_name ShieldAnimator
extends WeaponAnimator

# The left hand's version of WeaponAnimator: poses the equipped shield.
# Attached to Head/Camera3D/OffHand. Same calls (go, kick...), its own poses.
# The shield model faces -Z (away from the camera).

const SHIELD_POSES := {
	"rest":    {"pos": Vector3(-0.42, -0.38, -0.55), "rot": Vector3(-10, -25, 10)},
	"block":   {"pos": Vector3(-0.17, -0.26, -0.50), "rot": Vector3(5, -12, 0)},
	"bash":    {"pos": Vector3(-0.02, -0.12, -0.78), "rot": Vector3(8, 0, 0)},
	"stagger": {"pos": Vector3(-0.50, -0.55, -0.45), "rot": Vector3(-25, -35, 20)},
	"dodge":   {"pos": Vector3(-0.45, -0.45, -0.5), "rot": Vector3(-15, -30, 10)},
}


## A one-handed weapon in the left hand (dual-wielding): the right hand's poses, mirrored.
var holds_weapon := false
var _mirrored := {}


func _poses() -> Dictionary:
	if not holds_weapon:
		return SHIELD_POSES
	if _mirrored.is_empty():
		for name in POSES:
			var pose: Dictionary = POSES[name]
			_mirrored[name] = {"pos": Vector3(-pose["pos"].x, pose["pos"].y, pose["pos"].z),
					"rot": Vector3(pose["rot"].x, -pose["rot"].y, -pose["rot"].z)}
	return _mirrored
