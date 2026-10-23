class_name WeaponAnimator
extends Node3D

# Placeholder first-person animation: moves the held weapon between named
# poses in front of the camera, plus walking bob, heavy-attack tremble and
# small kicks. Attached to Head/Camera3D/Weapon; the weapon model is its child.
#
# The combat code (player/player_combat.gd) only ever calls go(pose, seconds)
# and the kick/charge helpers, so a version that plays real animation clips
# (from a bought first-person arms pack) can replace this script later
# without touching combat timing. See docs/godot-starter/COMBAT.md.
#
# Poses are camera space: +X right, +Y up, -Z forward. Rotation in degrees
# (X tips the blade up, Y swings it left, Z rolls it). The blade points along -Z.

const POSES := {
	"rest":           {"pos": Vector3(0.30, -0.30, -0.50), "rot": Vector3(35, 8, -12)},
	"high_right":     {"pos": Vector3(0.40, -0.06, -0.48), "rot": Vector3(70, -20, -50)},
	"low_left":       {"pos": Vector3(-0.22, -0.36, -0.58), "rot": Vector3(-25, 60, 55)},
	"high_left":      {"pos": Vector3(-0.15, -0.06, -0.48), "rot": Vector3(68, 25, 50)},
	"low_right":      {"pos": Vector3(0.40, -0.38, -0.55), "rot": Vector3(-25, -55, -55)},
	"overhead":       {"pos": Vector3(0.12, 0.02, -0.42), "rot": Vector3(95, 0, -5)},
	"low_center":     {"pos": Vector3(0.05, -0.38, -0.62), "rot": Vector3(-35, 5, 0)},
	"thrust_back":    {"pos": Vector3(0.28, -0.26, -0.28), "rot": Vector3(2, 4, -85)},
	"thrust_forward": {"pos": Vector3(0.12, -0.18, -0.88), "rot": Vector3(0, 2, -85)},
	"block":          {"pos": Vector3(0.20, -0.26, -0.48), "rot": Vector3(38, 62, 22)},
	"parry":          {"pos": Vector3(0.02, -0.02, -0.55), "rot": Vector3(20, 70, 35)},
	"stagger":        {"pos": Vector3(0.42, -0.45, -0.45), "rot": Vector3(-20, -25, -40)},
	"dodge":          {"pos": Vector3(0.32, -0.40, -0.45), "rot": Vector3(20, 10, -20)},
}

## How much the weapon bobs while walking (metres), and how fast.
@export var bob_amount: float = 0.015
@export var bob_speed: float = 9.0

var _from: Transform3D
var _to: Transform3D
var _duration := 0.0
var _elapsed := 0.0
var _curve := 1.0          # ease() curve: <1 eases out, >1 eases in, negative = in-out
var _pose_name := "rest"
var _arc := Vector3.ZERO   # bulge in the middle of a move (strikes swing out in front)

var _bob_time := 0.0
var _bob_weight := 0.0     # 0 standing still .. 1 moving at walking speed
var _kick := Vector3.ZERO  # position offset that springs back to zero
var _charge := 0.0         # 0..1 while charging a heavy attack: trembles and draws back


func _ready() -> void:
	_to = _pose_transform("rest")
	_from = _to
	transform = _to


## Moves to `pose` over `seconds`. curve < 1 starts fast (windups),
## > 1 starts slow and snaps (strikes), negative eases both ends.
## `arc` pushes the path out by that much halfway through (camera space metres).
func go(pose: String, seconds: float, curve: float = -1.6, arc: Vector3 = Vector3.ZERO) -> void:
	if not POSES.has(pose):
		push_warning("WeaponAnimator: no pose called '%s'." % pose)
		pose = "rest"
	_from = _current_pose()
	_to = _pose_transform(pose)
	_duration = maxf(seconds, 0.001)
	_elapsed = 0.0
	_curve = curve
	_arc = arc
	_pose_name = pose


func pose_name() -> String:
	return _pose_name


## A quick shove (camera space metres) that springs back, e.g. when a hit lands.
func kick(offset: Vector3) -> void:
	_kick += offset


## 0..1 while a heavy attack charges.
func set_charge(amount: float) -> void:
	_charge = amount


## How fast the player is moving compared with walking (for the bob).
func set_movement(speed_fraction: float) -> void:
	_bob_weight = clampf(speed_fraction, 0.0, 1.5)


func _process(delta: float) -> void:
	_elapsed += delta
	var pose := _current_pose()

	_bob_time += delta * bob_speed * maxf(_bob_weight, 0.0)
	var bob := Vector3(cos(_bob_time * 0.5) * bob_amount, -absf(sin(_bob_time * 0.5)) * bob_amount, 0.0) * minf(_bob_weight, 1.0)
	var tremble := Vector3(randf_range(-1, 1), randf_range(-1, 1), 0.0) * 0.004 * _charge
	var draw_back := Vector3(0.03, 0.04, 0.10) * _charge
	_kick = _kick.lerp(Vector3.ZERO, minf(delta * 14.0, 1.0))
	pose.origin += bob + tremble + draw_back + _kick
	transform = pose


func _current_pose() -> Transform3D:
	var t := clampf(_elapsed / _duration, 0.0, 1.0) if _duration > 0.0 else 1.0
	var eased := ease(t, _curve)
	var pose := _from.interpolate_with(_to, eased)
	pose.origin += _arc * sin(PI * eased)
	return pose


func _pose_transform(pose: String) -> Transform3D:
	var data: Dictionary = POSES[pose]
	var rot: Vector3 = data["rot"]
	var basis := Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
	return Transform3D(basis, data["pos"])
