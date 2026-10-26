extends "res://tests/test_base.gd"
# Region moods (levels/level_mood.gd, levels/moods/*.tres) over the day/night cycle
# (levels/day_night.gd): every outdoor region has one; the Grieving Fields are
# overcast (a dimmer sun, softer shadows, a greyer grade), Ilunhall hazy gold;
# nights keep a moonlit fill to see by; clouds by day and stars by night on the sky
# dome; water that moves. docs/godot-starter/LOOK.md, "Moods", "Water and sky".
const REGIONS := {
	"res://levels/test_level.tscn": "vale",
	"res://levels/weirholt.tscn": "riverlands",
	"res://levels/grieving_fields.tscn": "fields",
	"res://levels/ilunhall.tscn": "capital",
}
var f := 0
var step := 0
var wait := 0
var i := 0
var sun_energy := {}   # region -> sun energy at noon

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file(REGIONS.keys()[0])

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	match step:
		0:
			wait = 5
		1:
			var path: String = REGIONS.keys()[i]
			var dn = n("DayNight")
			var env: Environment = n("WorldEnvironment").environment
			ok(dn.mood != null and dn.mood.resource_path.ends_with("/%s.tres" % REGIONS[path]), "%s: the %s mood" % [current_scene.name, REGIONS[path]],
					dn.mood.resource_path if dn.mood else "none")
			dn.apply(12.0)
			sun_energy[REGIONS[path]] = n("Sun").light_energy
			if REGIONS[path] == "fields":
				ok(n("Sun").shadow_opacity < 0.7, "the Fields are overcast: soft shadows", n("Sun").shadow_opacity)
				ok(env.adjustment_saturation < 0.8, "and a grey grade", env.adjustment_saturation)
			if REGIONS[path] == "capital":
				near(env.fog_density, 0.0035, 0.0001, "Ilunhall's haze")
				ok(n("Sun").light_color.b < n("Sun").light_color.r * 0.85, "and a golden sun", n("Sun").light_color)
			var dome = n("SkyDome")
			ok(dome != null and is_equal_approx(dome.material.get_shader_parameter("cover"), dn.mood.clouds), "%s: clouds in the sky (cover %s)" % [current_scene.name, dn.mood.clouds])
			ok(dome.material.get_shader_parameter("night") == 0.0, "no stars by day")
			ok(n("GroundSkirt") != null, "%s: ground out to the horizon" % current_scene.name)
			dn.apply(0.5)
			ok(dome.material.get_shader_parameter("night") > 0.9, "stars at night")
			var fill: Color = env.ambient_light_color
			ok(fill.b >= dn.NIGHT_FILL.b - 0.001 and env.ambient_light_energy >= 2.0, "%s at night: a moonlit fill to see by" % current_scene.name, [fill, env.ambient_light_energy])
			i += 1
			if i < REGIONS.size():
				change_scene_to_file(REGIONS.keys()[i])
				step = 0
				wait = 20
				return false
			var fjord: MeshInstance3D = n("Fjord")
			ok(fjord.mesh.material is ShaderMaterial and fjord.mesh.material.get_shader_parameter("flow") != Vector2.ZERO, "Ilunhall's fjord is moving water")
			ok(sun_energy["fields"] < sun_energy["vale"] * 0.75, "the Fields' sun is dimmer than the Vale's at noon", sun_energy)
			# The shared atmosphere isn't changed by any of it (each level has its own copy).
			var shared: Environment = load("res://levels/atmosphere.tres")
			near(shared.fog_density, 0.008, 0.0001, "the shared atmosphere is untouched")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
