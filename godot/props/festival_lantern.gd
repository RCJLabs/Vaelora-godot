extends Node3D

# A Lanternfast lantern on a post (greybox): a warm glowing box and a light.
# Put them under a StoryPresence with show_flag "lanternfast_now".
# `on_post` false: just the lantern (on a sill, a table, a wagon).

@export var on_post: bool = true
@export var color: Color = Color(1.0, 0.78, 0.45)

const POST_HEIGHT := 1.6


func _ready() -> void:
	var height := POST_HEIGHT if on_post else 0.0
	if on_post:
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.08, POST_HEIGHT, 0.08)
		post.mesh = post_mesh
		post.position.y = POST_HEIGHT / 2.0
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.3, 0.22, 0.14)
		post.material_override = wood
		add_child(post)
	var lantern := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.22, 0.3, 0.22)
	lantern.mesh = box
	lantern.position.y = height + 0.15
	var glow := StandardMaterial3D.new()
	glow.albedo_color = color
	glow.emission_enabled = true
	glow.emission = color
	glow.emission_energy_multiplier = 2.5
	lantern.material_override = glow
	add_child(lantern)
	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.4
	light.omni_range = 6.0
	light.position.y = height + 0.2
	add_child(light)
