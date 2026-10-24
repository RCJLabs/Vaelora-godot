class_name WispCompanion
extends Node3D

# The wisp you freed in the barrow (main quest 4): a small light that follows
# you over your shoulder, everywhere, from then on. The player adds one when it
# spawns if the "freed_wisp" flag is set (WispCompanion.ensure).

const FLAG := "freed_wisp"
const OFFSET := Vector3(0.7, 2.1, 0.6)   # right, up, slightly behind (player space)
const COLOR := Color(0.65, 0.55, 1.0)

var _player: Node3D
var _time := 0.0


## Adds a companion beside `player` if the wisp was freed and there isn't one yet.
static func ensure(player: Node3D) -> WispCompanion:
	if not GameState.has_flag(FLAG) or player.get_parent() == null:
		return null
	for child in player.get_parent().get_children():
		if child is WispCompanion:
			return child
	var wisp := WispCompanion.new()
	wisp._player = player
	player.get_parent().add_child.call_deferred(wisp)
	return wisp


func _ready() -> void:
	name = "WispCompanion"
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.albedo_color = COLOR.lightened(0.4)
	var orb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.09
	sphere.height = 0.18
	sphere.material = glow
	orb.mesh = sphere
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(orb)
	var light := OmniLight3D.new()
	light.light_color = COLOR
	light.light_energy = 1.4
	light.omni_range = 7.0
	add_child(light)
	if _player:
		global_position = _target()


func _target() -> Vector3:
	return _player.global_transform * OFFSET + Vector3.UP * sin(_time * 1.8) * 0.12


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	_time += delta
	global_position = global_position.lerp(_target(), minf(delta * 3.0, 1.0))
