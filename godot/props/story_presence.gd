extends Node3D

# Shows or hides everything under it by story flags: a person who is somewhere
# only at a certain point in the story (a prisoner in a cage until freed, then
# at the waystation; a hedge-mage until she's arrested). Hidden means invisible,
# not processing, and no collision (nothing to bump into or talk to).
#   show_flag: present only once this is set ("" = from the start)
#   hide_flag: gone once this is set ("" = never)

@export var show_flag: String = ""
@export var hide_flag: String = ""

var _layers := {}   # body -> its collision layer while present


func _ready() -> void:
	for body in _bodies():
		_layers[body] = body.collision_layer
	GameState.flag_set.connect(func(_flag): _update())
	_update()


func is_present() -> bool:
	return (show_flag == "" or GameState.has_flag(show_flag)) \
			and (hide_flag == "" or not GameState.has_flag(hide_flag))


func _update() -> void:
	var present := is_present()
	visible = present
	process_mode = Node.PROCESS_MODE_INHERIT if present else Node.PROCESS_MODE_DISABLED
	for body in _layers:
		if is_instance_valid(body):
			body.collision_layer = _layers[body] if present else 0


func _bodies() -> Array:
	return find_children("*", "CollisionObject3D", true, false)
