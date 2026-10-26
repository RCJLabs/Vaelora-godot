class_name LevelMood
extends Resource

# A region's weather and colour, laid over the day/night cycle (levels/day_night.gd
# applies it every time it sets the hour): the Riverlands damp and green, the
# Grieving Fields overcast and grey, Ilunhall hazy gold. The clock still runs; this
# only tints and thickens what it does. levels/moods/*.tres; set one as a level's
# DayNight > Mood. docs/godot-starter/LOOK.md, "Moods".

@export_group("Sky")
## Colour the sky leans towards (top and horizon), and how far.
@export var sky_tint := Color(1, 1, 1)
@export_range(0.0, 1.0) var sky_tint_amount := 0.0
## Cloud cover, 0 to 1: greys the sky, dims the sun and softens its shadows.
@export_range(0.0, 1.0) var overcast := 0.0
## How much of the sky the drifting clouds cover (levels/sky_dome.gd), 0 to 1.
@export_range(0.0, 1.0) var clouds := 0.4

@export_group("Sun")
@export var sun_tint := Color(1, 1, 1)
@export_range(0.0, 1.0) var sun_tint_amount := 0.0
@export var sun_energy_mult := 1.0

@export_group("Fog")
@export var fog_tint := Color(1, 1, 1)
@export_range(0.0, 1.0) var fog_tint_amount := 0.0
## Depth fog density; negative keeps the level's own.
@export var fog_density := -1.0
## How much the fog glows towards the sun (negative: keep).
@export var fog_sun_scatter := -1.0

@export_group("Grade")
@export var ambient_mult := 1.0
@export var saturation := 1.0
@export var contrast := 1.0
@export var brightness := 1.0
## Glow (bloom) strength; negative keeps the level's own. Makes lights and gold shine.
@export var glow_intensity := -1.0
@export var glow_bloom := -1.0

const GREY := Color(0.62, 0.63, 0.66)


## The parts that don't change with the hour: fog density, glow, the colour grade.
func apply_static(env: Environment) -> void:
	if fog_density >= 0.0:
		env.fog_density = fog_density
	if fog_sun_scatter >= 0.0:
		env.fog_sun_scatter = fog_sun_scatter
	if glow_intensity >= 0.0:
		env.glow_intensity = glow_intensity
	if glow_bloom >= 0.0:
		env.glow_bloom = glow_bloom
	env.adjustment_enabled = true
	env.adjustment_saturation *= saturation
	env.adjustment_contrast *= contrast
	env.adjustment_brightness *= brightness


func sky(color: Color) -> Color:
	return color.lerp(sky_tint * color.get_luminance() * 1.6, sky_tint_amount).lerp(GREY * maxf(color.get_luminance(), 0.05) * 1.4, overcast * 0.8)


func sun_color(color: Color) -> Color:
	return color.lerp(sun_tint, sun_tint_amount).lerp(GREY.lightened(0.3), overcast * 0.5)


func sun_energy(energy: float) -> float:
	return energy * sun_energy_mult * (1.0 - overcast * 0.55)


func fog(color: Color) -> Color:
	return color.lerp(fog_tint * maxf(color.get_luminance(), 0.05) * 1.5, fog_tint_amount)


func ambient(energy: float) -> float:
	return energy * ambient_mult * (1.0 + overcast * 0.25)   # cloud scatters light into the shade


## Shadows soften under cloud.
func shadow_opacity() -> float:
	return 1.0 - overcast * 0.6
