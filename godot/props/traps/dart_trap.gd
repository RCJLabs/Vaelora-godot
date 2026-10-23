extends Node3D

# Darts from a hole in the wall, fired along the node's -Z when activate() is
# called (usually by a PressurePlate). The player can block or dodge them like
# any attack; a hit may poison. They also hit enemies.

@export var darts: int = 3
@export var interval: float = 0.12
@export var damage: float = 10.0
@export var speed: float = 22.0
@export var spread_degrees: float = 4.0
@export var poison_chance: float = 0.35

const DART := preload("res://combat/dart.gd")


func activate() -> void:
	Sfx.play_at("dart_fire", global_position)
	for i in darts:
		if i > 0:
			await get_tree().create_timer(interval, false).timeout
		if not is_inside_tree():
			return
		var dart := Node3D.new()
		dart.set_script(DART)
		dart.damage = damage
		dart.poison_chance = poison_chance
		var level := get_tree().current_scene
		(level if level else get_parent()).add_child(dart)
		var direction := -global_transform.basis.z
		direction = direction.rotated(Vector3.UP, deg_to_rad(randf_range(-spread_degrees, spread_degrees)))
		direction = direction.rotated(global_transform.basis.x, deg_to_rad(randf_range(-spread_degrees, spread_degrees) * 0.5))
		dart.launch(global_position, direction, speed)
