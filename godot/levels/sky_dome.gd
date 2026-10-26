class_name SkyDome
extends MeshInstance3D

# The clouds and stars (levels/sky_dome.gdshader) on a dome that follows the camera.
# DayNight makes one for its level and sets its colours by the hour; a level's mood
# sets how cloudy (LevelMood.clouds). docs/godot-starter/LOOK.md, "Water and sky".

const RADIUS := 900.0

var material: ShaderMaterial


func _init() -> void:
	name = "SkyDome"
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	mesh = sphere
	material = ShaderMaterial.new()
	material.shader = preload("res://levels/sky_dome.gdshader")
	material.set_shader_parameter("noise", preload("res://levels/materials/noise_clouds.tres"))
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = RADIUS


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera:
		global_position = camera.global_position


## How the sky looks now: clouds lit by `light` (the sun's colour and energy), night
## 0..1, cover 0..1.
func set_look(light: Color, night: float, cover: float) -> void:
	var lit := light.lerp(Color(1, 1, 1), 0.5)
	var day_cloud := Color(lit.r, lit.g, lit.b, 0.92)
	var night_cloud := Color(0.16, 0.18, 0.24, 0.85)
	material.set_shader_parameter("cloud_color", day_cloud.lerp(night_cloud, night))
	material.set_shader_parameter("night", night)
	material.set_shader_parameter("cover", cover)
