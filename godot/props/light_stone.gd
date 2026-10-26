extends Node3D

# The light-stone in Ilunhall's eaves: every mesh under this glows gold, softly by
# day and bright at night (daylight() fades between), and the lights under it
# follow. Once dim_flag is set (the Mercy's conduit broken) it all burns at a
# fraction: the city's glow was being fed, and now it isn't. docs/godot-starter/ILUNHALL.md.

@export var dim_flag := ""
@export var day_energy := 0.5
@export var night_energy := 2.6
## What's left once dimmed, as a share.
@export var dimmed := 0.3
## The lights under the stone, against their own energy at full glow: the whole
## city glows gold at night (docs/lore/WORLD.md).
@export var light_mult := 2.0
## The surface colour (gold stone; dark glass for windows) and the glow's.
@export var surface := Color(1.0, 0.8, 0.4)
@export var glow := Color(1.0, 0.72, 0.3)

var material: StandardMaterial3D
var _lights := {}   # light -> its full energy
var _since := 0.0


func _ready() -> void:
	material = StandardMaterial3D.new()
	material.albedo_color = surface
	material.emission_enabled = true
	material.emission = glow
	for m in find_children("*", "MeshInstance3D", true, false):
		m.material_override = material
	for light in find_children("*", "OmniLight3D", true, false):
		_lights[light] = light.light_energy
	GameState.flag_set.connect(func(_flag): _update())
	_update()


func _process(delta: float) -> void:
	_since += delta
	if _since > 1.0:
		_since = 0.0
		_update()


func is_dimmed() -> bool:
	return dim_flag != "" and GameState.has_flag(dim_flag)


## How bright, as a share of its full night glow.
func strength() -> float:
	var s := lerpf(1.0, day_energy / night_energy, WorldClock.daylight())
	return s * (dimmed if is_dimmed() else 1.0)


func _update() -> void:
	var s := strength()
	material.emission_energy_multiplier = night_energy * s
	for light in _lights:
		light.light_energy = _lights[light] * s * light_mult
