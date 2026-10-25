extends Node3D

# A moon in the sky of an outdoor level: a disc far off, following the camera so
# it never gets closer, lit by its phase (0 dark, 0.5 full) and faded out by day.
# Two of them, both on this script:
#   wanderer  the small green moon, WorldClock.wanderer_phase()
#   ilun      the old white moon, WorldClock.ilun_phase(), bigger and slower
#
# Each rises in the east, crosses the southern sky and sets in the west, up for
# 12 hours. When depends on its phase, as with a real moon (it's the sun lighting
# it from wherever the sun is): full, it rises at 18:00 and is up all night; dark,
# it rises at 6:00 and is up only by day, out of sight. Half, it's up half the
# night: rising at midnight while waning, setting at midnight while waxing. So the
# Wanderer is never in the night sky on Lanternfast.
#
# Except for one light. On Lanternfast night a single small light hangs in the
# northern sky, where everyone's lanterns face: the Vael who stayed aboard,
# keeping watch (docs/lore/STORY.md). Only the Wanderer's node draws it.

const DISTANCE := 400.0
const HOURS_UP := 12.0
## Lanternfast's one light: due north, a third of the way up the sky.
const WATCH_DIRECTION := Vector3(0.0, 0.5, -0.866)
const WATCH_SIZE := 5.0

@export_enum("wanderer", "ilun") var moon: String = "wanderer"
@export var size: float = 44.0
## How high it climbs (degrees above the southern horizon at its highest).
@export_range(5.0, 89.0) var peak_elevation: float = 35.0
@export var color: Color = Color(0.62, 0.95, 0.7)

## Where it is now: a unit vector from you towards it (below the horizon: negative y).
var direction: Vector3:
	get: return sky_direction(WorldClock.hour)

var _disc: MeshInstance3D
var _material: ShaderMaterial
var _watch: MeshInstance3D   # Lanternfast's one light (the Wanderer only)
var _time := 0.0


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
	if moon == "wanderer":
		_watch = MeshInstance3D.new()
		var dot := SphereMesh.new()
		dot.radius = WATCH_SIZE / 2.0
		dot.height = WATCH_SIZE
		_watch.mesh = dot
		_watch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = Color(0.85, 1.0, 0.9)
		glow.disable_fog = true   # 400 m away: the fog would grey it out, as it would the discs
		_watch.material_override = glow
		add_child(_watch)
	_update()


func _process(delta: float) -> void:
	_time += delta
	_update()


## True while Lanternfast's one light is in the sky (the Wanderer's node, at night).
func watch_shown() -> bool:
	return _watch != null and WorldClock.is_lanternfast() and night() > 0.0


## Where it is in its cycle: 0 dark, 0.5 full.
func phase() -> float:
	return WorldClock.ilun_phase() if moon == "ilun" else WorldClock.wanderer_phase()


## How much of it is lit (0 dark, 1 full).
func lit() -> float:
	return WorldClock.ilun_lit() if moon == "ilun" else WorldClock.wanderer_lit()


## The hour it rises today: 6:00 when dark, 18:00 when full.
func rise_hour() -> float:
	return fposmod(6.0 + phase() * 24.0, 24.0)


## Above the horizon?
func is_up() -> bool:
	return direction.y > 0.0


## Where it is in the sky at `hour`: east at rising, south at its highest, west at
## setting; under the horizon (straight down) the rest of the time.
func sky_direction(hour: float) -> Vector3:
	var t := fposmod(hour - rise_hour(), 24.0) / HOURS_UP   # 0 rising .. 1 setting
	if t > 1.0:
		return Vector3.DOWN
	var across := Vector3(cos(t * PI), 0.0, sin(t * PI))   # east (+x) -> south (+z) -> west
	var elevation := deg_to_rad(peak_elevation) * sin(t * PI)
	return (across * cos(elevation) + Vector3.UP * sin(elevation)).normalized()


## 0 by day, 1 at night.
func night() -> float:
	return clampf((0.35 - WorldClock.daylight()) / 0.25, 0.0, 1.0)


func _update() -> void:
	_material.set_shader_parameter("phase", phase())
	_material.set_shader_parameter("fade", night())
	var where := direction
	_disc.visible = night() > 0.0 and where.y > -0.02   # (it sets behind the hills a little late)
	if _watch:
		_watch.visible = watch_shown()
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var from := camera.global_position
	if _watch and _watch.visible:
		_watch.global_position = from + WATCH_DIRECTION.normalized() * DISTANCE
		_watch.scale = Vector3.ONE * (1.0 + 0.15 * sin(_time * 2.3))   # a slow, steady pulse
	if not _disc.visible:
		return
	_disc.global_position = from + where * DISTANCE
	_disc.look_at(from, Vector3.UP)
