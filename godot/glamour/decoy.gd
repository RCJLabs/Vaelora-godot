extends Node3D

# Mirror Image: a shimmering copy of you, standing where you aimed. Enemies
# near it go for it instead of you (systems/glamour.gd); each hit it takes
# makes it fainter, and the last one (or the end of its time) breaks it.
# Nothing to collide with: it's light.

var lifetime := 12.0
var hits_left := 3
var color := Color(0.95, 0.45, 0.9)

var _mat: StandardMaterial3D
var _age := 0.0


func _ready() -> void:
	add_to_group("decoy")
	var mesh := MeshInstance3D.new()
	mesh.mesh = CapsuleMesh.new()
	mesh.position.y = 0.9
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_color = Color(color, 0.55)
	_mat.emission_enabled = true
	_mat.emission = color
	_mat.emission_energy_multiplier = 0.6
	mesh.material_override = _mat
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 0.8
	light.omni_range = 3.0
	light.position.y = 1.2
	add_child(light)


func _process(delta: float) -> void:
	_age += delta
	# A shimmer, fading as it's hit.
	_mat.albedo_color.a = (0.25 + 0.15 * hits_left) * (0.85 + 0.15 * sin(_age * 9.0))
	if _age >= lifetime:
		queue_free()


## An enemy's attack landing (the same call the player gets).
func receive_attack(_damage: float, _attacker: Node, _poise: float = 0.0) -> String:
	hits_left -= 1
	if hits_left <= 0:
		Sfx.play_at("spell_impact", global_position, -4.0)
		remove_from_group("decoy")   # at once, so nobody keeps swinging at it
		queue_free()
	return "hit"
