extends NavigationRegion3D

# The walkable area AI (wolves) uses to find paths around obstacles.
#
# It reads every StaticBody3D on physics layer 1 "world" under nodes in the
# group "navmesh_source" (the level root is in that group, so: the whole level).
#
# If you haven't baked it in the editor (select this node > Bake NavigationMesh
# in the toolbar), it bakes itself when the level loads, so it always matches
# the level. That takes a few milliseconds here; for big levels, bake in the
# editor instead and this script will leave the baked mesh alone.
#
# See it while playing: Debug > Visible Navigation.


func _ready() -> void:
	if navigation_mesh.get_polygon_count() == 0:
		bake_navigation_mesh(false)   # false = right now, not on a background thread
