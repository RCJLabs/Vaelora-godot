extends StaticBody3D

# A forge: hearth, anvil and coals. E opens the smithing screen (forge and
# improve, ui/smithing_screen.gd). It's warm, too (Survival's cold). It builds
# its own greybox meshes, so placing one is a single node with this script.

@export var heat_radius: float = 3.0

var prompt := "Use forge"


func _ready() -> void:
	add_to_group("heat_source")
	_box(Vector3(1.2, 0.9, 1.0), Vector3(0, 0.45, 0), Color(0.2, 0.19, 0.18))        # the hearth
	_box(Vector3(0.9, 0.06, 0.7), Vector3(0, 0.93, 0), Color(1.0, 0.35, 0.08), 3.0)   # coals
	_box(Vector3(0.35, 0.55, 0.35), Vector3(1.3, 0.275, 0.1), Color(0.4, 0.27, 0.15)) # the stump
	_box(Vector3(0.7, 0.22, 0.28), Vector3(1.3, 0.66, 0.1), Color(0.18, 0.18, 0.2))   # the anvil
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.0, 1.0, 1.0)
	shape.shape = box
	shape.position = Vector3(0.5, 0.5, 0)
	add_child(shape)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.55, 0.25)
	light.light_energy = 1.4
	light.omni_range = 5.0
	light.position = Vector3(0, 1.3, 0)
	add_child(light)


func _box(size: Vector3, at: Vector3, color: Color, glow: float = 0.0) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	box.material = mat
	mesh.mesh = box
	mesh.position = at
	add_child(mesh)


func interact(_player: Node) -> void:
	SmithingScreen.open(true)
