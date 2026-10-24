extends "res://enemies/bandit.gd"

# A Lantern Order inquisitor (docs/lore/FACTIONS.md): the Order hunts "corrupt"
# mages. On the road he's a man you talk to (dialogue/inquisitor.json); if he
# sees Stained veins, he draws, and this is what you fight. Fights like a bandit
# (bandit.tscn with this script swapped in), in white and gold, with a lantern,
# and takes no prisoners: the Order doesn't keep the corrupt in cages.

const COAT := Color(0.86, 0.84, 0.78)
const TRIM := Color(0.72, 0.58, 0.25)


func _ready() -> void:
	super()
	remove_from_group("captors")
	_cloth.albedo_color = COAT
	_cloth_color = COAT
	for part in ["Hood", "LegL", "LegR"]:
		var mesh := get_node_or_null("Model/" + part) as MeshInstance3D
		if mesh:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = TRIM
			mesh.material_override = mat
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.85, 0.55)
	lantern.light_energy = 1.2
	lantern.omni_range = 5.0
	lantern.position = Vector3(0.35, 1.0, 0.0)
	add_child(lantern)
