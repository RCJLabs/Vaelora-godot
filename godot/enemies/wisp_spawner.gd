extends Node3D

# Brings wisps out at night: when night falls (WorldClock), `count` wisps
# appear within `radius` of this node; at dawn the survivors fade away. Killed
# ones come back the next night. They fight together (alert()).

@export var count: int = 3
@export var radius: float = 7.0

const WISP_SCENE := preload("res://enemies/wisp.tscn")

var _night_active := false


func _process(_delta: float) -> void:
	var night := WorldClock.is_night()
	if night and not _night_active:
		_night_active = true
		_spawn()
	elif not night and _night_active:
		_night_active = false
		for wisp in get_children():
			if wisp.has_method("fade_out"):
				wisp.fade_out()


func _spawn() -> void:
	for i in count:
		var wisp := WISP_SCENE.instantiate()
		var angle := TAU * i / count + randf_range(-0.4, 0.4)
		wisp.position = Vector3(cos(angle), 0.0, sin(angle)) * randf_range(radius * 0.4, radius) + Vector3.UP * 1.8
		add_child(wisp)


## A wisp started fighting: the others join in.
func alert(_by: Node) -> void:
	for wisp in get_children():
		if wisp.has_method("join_hunt"):
			wisp.join_hunt()
