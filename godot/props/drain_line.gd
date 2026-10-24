extends Node3D

# The drain-line from main quest 2, "The Waking Stones": a thread of pale light
# running from the stone circle's crystal towards the Thornwood, with motes
# flowing away along it. Hidden until `show_flag` is set (the crystal sets it
# once the shards are dealt with). Place it at the crystal; it runs along its
# own -Z for `length` metres, sloping down by `drop`.

@export var show_flag: String = "saw_drain_line"
@export var length: float = 48.0
@export var drop: float = 0.8
@export var color: Color = Color(0.75, 1.0, 0.85)
@export var mote_count: int = 10
@export var mote_speed: float = 4.0

var _thread: MeshInstance3D
var _motes: Array[MeshInstance3D] = []
var _t := 0.0


func _ready() -> void:
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow.albedo_color = Color(color.r, color.g, color.b, 0.55)
	var box := BoxMesh.new()
	box.size = Vector3(0.07, 0.07, length)
	box.material = glow
	_thread = MeshInstance3D.new()
	_thread.mesh = box
	_thread.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_thread.position = Vector3(0, -drop / 2.0, -length / 2.0)
	_thread.rotation.x = -atan2(drop, length)   # tilt the far end down
	add_child(_thread)
	var mote_mat := glow.duplicate()
	mote_mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	var sphere := SphereMesh.new()
	sphere.radius = 0.11
	sphere.height = 0.22
	sphere.material = mote_mat
	for i in mote_count:
		var mote := MeshInstance3D.new()
		mote.mesh = sphere
		mote.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mote)
		_motes.append(mote)
	visible = GameState.has_flag(show_flag)
	GameState.flag_set.connect(func(flag): if flag == show_flag: visible = true)


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	for i in _motes.size():
		var along := fmod(_t * mote_speed + i * length / _motes.size(), length)
		_motes[i].position = Vector3(0, -drop * along / length, -along)
		_motes[i].scale = Vector3.ONE * (1.0 - along / length * 0.6)


## A point on the line, `fraction` (0-1) of the way from the crystal.
func point(fraction: float) -> Vector3:
	return to_global(Vector3(0, -drop * fraction, -length * fraction))
