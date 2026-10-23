@tool
extends Node3D

# Loads your terrain scene into this level, if you've made one.
#
# Keep your Terrain3D node in its own scene (default: the file below) so that
# updating test_level.tscn never overwrites your sculpting. When that file
# exists, it's added here at startup, and the old box ground is removed so the
# two don't overlap. In the editor (this is a @tool script) you see the terrain
# too, but the box ground is left alone: changing it there would get saved into
# this level. The terrain itself is never saved into this level - it stays in
# its own file.
#
# Step-by-step setup: docs/godot-starter/TERRAIN3D.md

@export_file("*.tscn") var terrain_scene: String = "res://levels/test_level_terrain.tscn"
## Removed when the game runs with a terrain.
@export var replaces: NodePath = ^"../Ground"


func _ready() -> void:
	if terrain_scene == "" or not ResourceLoader.exists(terrain_scene):
		return
	var terrain: Node = (load(terrain_scene) as PackedScene).instantiate()
	add_child(terrain)   # no owner, so it's never written into this scene file
	var old := get_node_or_null(replaces)
	if old == null or Engine.is_editor_hint():
		return
	# The level is still being set up, so the node can't be removed yet. Taking
	# it off every physics layer right now keeps it out of the navigation bake
	# (which runs next) and out of the player's way; it's freed after this frame.
	old.visible = false
	if old is CollisionObject3D:
		old.collision_layer = 0
		old.collision_mask = 0
	old.queue_free()
