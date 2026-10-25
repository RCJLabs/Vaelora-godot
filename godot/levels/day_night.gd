extends Node

# Day and night for an outdoor level: moves the sun (a moon at night), and
# blends the sky, sun and ambient colours through night -> dawn -> day -> dusk
# by the WorldClock. At night the light comes from Ilun (the level's IlunMoon,
# if it has one: levels/wanderer_moon.gd), brighter the fuller it is, and the
# sky draws no disc for it, since IlunMoon draws the moon itself. Add one to an outdoor level and point it at the Sun and
# the WorldEnvironment. Interiors don't need one.
#
# Dawn and dusk use the colours the test level was first tuned with. The other
# keyframes are first drafts: tweak KEYS below, or untick Enabled to freeze the
# level at Fixed Hour while you work on its look.

@export var sun_path: NodePath = ^"../Sun"
@export var environment_path: NodePath = ^"../WorldEnvironment"
@export var enabled: bool = true
## The hour shown when Enabled is off (and in the editor).
@export_range(0.0, 24.0) var fixed_hour: float = 18.5
## Compass direction the sun rises from and travels along (degrees).
@export var sun_azimuth: float = 25.0
## Where the night light comes from (its direction and phase). Empty or missing: a
## plain moonlight at 35 degrees opposite the sun.
@export var night_moon_path: NodePath = ^"../IlunMoon"

# hour: sun colour, sun energy, sky top, sky horizon, ground horizon, ambient energy, fog light
const KEYS := [
	[0.0,  Color(0.55, 0.65, 0.95), 0.4, Color(0.02, 0.035, 0.08), Color(0.08, 0.1, 0.17), Color(0.06, 0.06, 0.08), 0.5, Color(0.18, 0.21, 0.32)],
	[5.0,  Color(0.55, 0.65, 0.95), 0.4, Color(0.02, 0.035, 0.08), Color(0.08, 0.1, 0.17), Color(0.06, 0.06, 0.08), 0.5, Color(0.18, 0.21, 0.32)],
	[6.5,  Color(1, 0.84, 0.66), 1.6, Color(0.13, 0.22, 0.42), Color(0.8, 0.62, 0.5), Color(0.55, 0.46, 0.42), 1.0, Color(0.6, 0.62, 0.72)],
	[9.0,  Color(1, 0.96, 0.9), 2.0, Color(0.2, 0.38, 0.72), Color(0.68, 0.75, 0.85), Color(0.45, 0.47, 0.42), 1.0, Color(0.72, 0.78, 0.88)],
	[16.0, Color(1, 0.96, 0.9), 2.0, Color(0.2, 0.38, 0.72), Color(0.68, 0.75, 0.85), Color(0.45, 0.47, 0.42), 1.0, Color(0.72, 0.78, 0.88)],
	[18.5, Color(1, 0.84, 0.66), 1.6, Color(0.13, 0.22, 0.42), Color(0.8, 0.62, 0.5), Color(0.55, 0.46, 0.42), 1.0, Color(0.6, 0.62, 0.72)],
	[20.5, Color(0.55, 0.65, 0.95), 0.4, Color(0.02, 0.035, 0.08), Color(0.08, 0.1, 0.17), Color(0.06, 0.06, 0.08), 0.5, Color(0.18, 0.21, 0.32)],
	[24.0, Color(0.55, 0.65, 0.95), 0.4, Color(0.02, 0.035, 0.08), Color(0.08, 0.1, 0.17), Color(0.06, 0.06, 0.08), 0.5, Color(0.18, 0.21, 0.32)],
]

@onready var sun: DirectionalLight3D = get_node_or_null(sun_path)
@onready var world_environment: WorldEnvironment = get_node_or_null(environment_path)
@onready var night_moon: Node3D = get_node_or_null(night_moon_path) if not night_moon_path.is_empty() else null
var _sky: ProceduralSkyMaterial
var _last_hour := -1.0


func _ready() -> void:
	if world_environment and world_environment.environment:
		# Own copy, so changing it doesn't change the .tres other levels may share.
		world_environment.environment = world_environment.environment.duplicate(true)
		var sky := world_environment.environment.sky
		if sky and sky.sky_material is ProceduralSkyMaterial:
			_sky = sky.sky_material
	apply(_hour())


func _process(_delta: float) -> void:
	var hour := _hour()
	if absf(hour - _last_hour) > 0.01:   # about every 30 game seconds
		apply(hour)


func _hour() -> float:
	return WorldClock.hour if enabled and not Engine.is_editor_hint() else fixed_hour


## Sets the sun and sky for `hour`.
func apply(hour: float) -> void:
	_last_hour = hour
	var a: Array = KEYS[0]
	var b: Array = KEYS[1]
	for i in KEYS.size() - 1:
		if hour >= KEYS[i][0] and hour <= KEYS[i + 1][0]:
			a = KEYS[i]
			b = KEYS[i + 1]
			break
	var t: float = 0.0 if b[0] == a[0] else (hour - a[0]) / (b[0] - a[0])
	t = smoothstep(0.0, 1.0, t)
	if sun:
		sun.light_color = a[1].lerp(b[1], t)
		sun.light_energy = lerpf(a[2], b[2], t)
		# By day the light is the sun, arcing up to 60 degrees; by night, a moon at 35.
		var day_part := clampf(sin((hour - 6.0) / 12.0 * PI), -1.0, 1.0)
		var elevation := maxf(day_part * 60.0, 12.0) if day_part > 0.0 else 35.0
		var azimuth := sun_azimuth + (hour - 12.0) * 8.0 if day_part > 0.0 else sun_azimuth + 180.0
		sun.rotation_degrees = Vector3(-elevation, azimuth, 0.0)
		sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
		if day_part <= 0.0 and night_moon:
			# Shining from Ilun, a little dimmer when it's a sliver.
			sun.basis = Basis.looking_at(-night_moon.direction, Vector3.UP)
			sun.light_energy *= lerpf(0.6, 1.0, night_moon.lit())
			sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	if _sky:
		_sky.sky_top_color = a[3].lerp(b[3], t)
		_sky.sky_horizon_color = a[4].lerp(b[4], t)
		_sky.ground_horizon_color = a[5].lerp(b[5], t)
	if world_environment:
		var env := world_environment.environment
		env.ambient_light_energy = lerpf(a[6], b[6], t)
		env.fog_light_color = a[7].lerp(b[7], t)
