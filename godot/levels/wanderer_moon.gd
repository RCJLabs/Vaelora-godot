extends Node3D

# The Wanderer, the small green moon, in the night sky of an outdoor level: a
# disc far off in a fixed direction, following the camera so it never gets
# closer, lit by its phase (WorldClock.wanderer_phase(): 0 dark, 0.5 full) and
# faded out by day. On the dark night (Lanternfast) it's a faint ghost.

const DISTANCE := 400.0
const SIZE := 44.0
## Where it hangs: roughly north-west, a third of the way up the sky.
const DIRECTION := Vector3(-0.45, 0.55, -0.7)

var _disc: MeshInstance3D
var _material: ShaderMaterial


func _ready() -> void:
	_disc = MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	_disc.mesh = quad
	_disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = preload("res://levels/wanderer_moon.gdshader")
	_disc.material_override = _material
	add_child(_disc)
	_update()


func _process(_delta: float) -> void:
	_update()


## How much of it is lit (0 dark, 1 full).
func lit() -> float:
	return (1.0 - cos(WorldClock.wanderer_phase() * TAU)) / 2.0


## 0 by day, 1 at night.
func night() -> float:
	return clampf((0.35 - WorldClock.daylight()) / 0.25, 0.0, 1.0)


func _update() -> void:
	_material.set_shader_parameter("phase", WorldClock.wanderer_phase())
	_material.set_shader_parameter("fade", night())
	_disc.visible = night() > 0.0
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := camera.global_position
	_disc.global_position = from + DIRECTION.normalized() * DISTANCE
	_disc.look_at(from, Vector3.UP)
