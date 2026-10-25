extends Node3D

# A moon in the night sky of an outdoor level: a disc far off in a fixed
# direction, following the camera so it never gets closer, lit by its phase
# (0 dark, 0.5 full) and faded out by day. Two of them, both on this script:
#   wanderer  the small green moon, WorldClock.wanderer_phase(); dark on
#             Lanternfast, when it's a faint ghost
#   ilun      the old white moon, WorldClock.ilun_phase(), bigger and slower

const DISTANCE := 400.0

@export_enum("wanderer", "ilun") var moon: String = "wanderer"
@export var size: float = 44.0
## Where it hangs. The Wanderer: roughly north-west, a third of the way up the sky.
@export var direction: Vector3 = Vector3(-0.45, 0.55, -0.7)
@export var color: Color = Color(0.62, 0.95, 0.7)

var _disc: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_disc = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	_disc.mesh = quad
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = preload("res://levels/wanderer_moon.gdshader")
	_material.set_shader_parameter("color", color)
	_disc.material_override = _material
	add_child(_disc)
	_update()


func _process(_delta: float) -> void:
	_update()


## Where it is in its cycle: 0 dark, 0.5 full.
func phase() -> float:
	return WorldClock.ilun_phase() if moon == "ilun" else WorldClock.wanderer_phase()


## How much of it is lit (0 dark, 1 full).
func lit() -> float:
	return WorldClock.ilun_lit() if moon == "ilun" else WorldClock.wanderer_lit()


## 0 by day, 1 at night.
func night() -> float:
	return clampf((0.35 - WorldClock.daylight()) / 0.25, 0.0, 1.0)


func _update() -> void:
	_material.set_shader_parameter("phase", phase())
	_material.set_shader_parameter("fade", night())
	_disc.visible = night() > 0.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := camera.global_position
	_disc.global_position = from + direction.normalized() * DISTANCE
	_disc.look_at(from, Vector3.UP)
