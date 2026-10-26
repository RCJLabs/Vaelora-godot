extends "res://enemies/bandit.gd"

# A Lantern Order inquisitor (docs/lore/FACTIONS.md): the Order hunts "corrupt"
# mages. On the road he's a man you talk to (dialogue/inquisitor.json); if he
# sees Stained veins, he draws, and this is what you fight. Fights like a bandit
# (bandit.tscn with this script swapped in), in white and gold, with a lantern,
# and takes no prisoners: the Order doesn't keep the corrupt in cages.

const COAT := Color(0.86, 0.84, 0.78)


func _ready() -> void:
	look_role = "inquisitor"
	look_cloth = COAT
	look_vary = false   # Inquisitor Hale: one man
	super()
	remove_from_group("captors")
	var lantern := OmniLight3D.new()
	lantern.light_color = Color(1.0, 0.85, 0.55)
	lantern.light_energy = 1.2
	lantern.omni_range = 5.0
	lantern.position = Vector3(0.35, 1.0, 0.0)
	add_child(lantern)
