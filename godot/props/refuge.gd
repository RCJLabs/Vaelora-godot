class_name Refuge
extends Marker3D

# Where you wake up when someone finds you after a defeat in Hardcore (systems/defeat.gd).
# One per level that has people who'd help. Faces the way you'll face.

@export_multiline var found_text: String = "Someone found you and brought you somewhere safe."


func _ready() -> void:
	add_to_group("refuge")
