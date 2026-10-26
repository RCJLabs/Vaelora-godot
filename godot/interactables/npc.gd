extends StaticBody3D

# A character you can talk to. Set Display Name and Dialogue File in the Inspector.
# Set Race and Role and the game swaps the plain capsule for a greybox person
# (systems/figure.gd) in the capsule's colour, or Cloth's if you set one.

@export var display_name: String = "Stranger"
@export_file("*.json") var dialogue_file: String
## A race's file name in races/ (human, elf, orc, small_folk, deepfolk, ashen, passenger). Empty: keep the capsule.
@export var race := ""
## What they do, which decides what they wear: one of Figure.ROLES (guard, merchant, priest...).
@export var role := "commoner"
## Their clothes' colour. Left clear, the capsule's colour.
@export var cloth := Color(0, 0, 0, 0)
@export var sitting := false

var prompt: String:
	get: return "Talk to %s" % display_name


func _ready() -> void:
	if race != "":
		_dress()


func interact(_player: Node) -> void:
	DialogueManager.start(dialogue_file, display_name)


func _dress() -> void:
	var capsule := get_node_or_null("MeshInstance3D") as MeshInstance3D
	var colour := cloth
	if colour.a == 0.0:
		colour = Color(0.4, 0.38, 0.35)
		if capsule and capsule.mesh and capsule.mesh.surface_get_material(0) is StandardMaterial3D:
			colour = capsule.mesh.surface_get_material(0).albedo_color
	if capsule:
		capsule.visible = false
	add_child(Figure.build(race, role, colour, sitting))
	# Fit the collision capsule to their height (the interact ray aims at it).
	var shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
	var height := Figure.height_of(race) * (0.62 if role == "child" else 1.0)
	if shape and shape.shape is CapsuleShape3D and not sitting and not is_equal_approx(height, 1.0):
		var fitted := shape.shape.duplicate() as CapsuleShape3D
		fitted.height = maxf(fitted.height * height, fitted.radius * 2.0)
		shape.shape = fitted
		shape.position.y = fitted.height / 2.0
