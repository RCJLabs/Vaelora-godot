extends NavigationRegion3D

# The walkable area AI (wolves) uses to find paths around obstacles.
#
# It reads every StaticBody3D on physics layer 1 "world" under nodes in the
# group "navmesh_source" (the level root is in that group, so: the whole
# level), plus the painted "navigable" areas of any Terrain3D in the level.
#
# If you haven't baked it in the editor, it bakes itself when the level loads,
# so it always matches the level. (Use Terrain3D Tools > Bake NavMesh to bake
# in the editor when there's a Terrain3D - the normal NavigationRegion3D bake
# button ignores terrain. A baked mesh is used as-is, so re-bake after edits.)
#
# See it while playing: Debug > Visible Navigation.


func _ready() -> void:
	if navigation_mesh.get_polygon_count() == 0:
		bake_now()


## Same steps as Terrain3D's own editor baker: scene geometry, then terrain faces.
func bake_now() -> void:
	var source := NavigationMeshSourceGeometryData3D.new()
	NavigationServer3D.parse_source_geometry_data(navigation_mesh, source, self)
	for terrain in _find_terrains():
		var aabb := navigation_mesh.filter_baking_aabb   # empty = the whole terrain
		aabb.position += navigation_mesh.filter_baking_aabb_offset
		if aabb.has_volume():
			aabb = global_transform * aabb
		var faces: PackedVector3Array = terrain.generate_nav_mesh_source_geometry(aabb)
		if not faces.is_empty():
			source.add_faces(faces, Transform3D.IDENTITY)
	NavigationServer3D.bake_from_source_geometry_data(navigation_mesh, source)
	navigation_mesh = navigation_mesh   # re-assign so the region picks up the new polygons


# Terrain3D nodes under the navigation source group. Found by the method they
# provide rather than by class, so this script works without the addon.
func _find_terrains() -> Array:
	var found := []
	for root in get_tree().get_nodes_in_group(navigation_mesh.geometry_source_group_name):
		for node in [root] + root.find_children("*", "", true, false):
			if node.has_method("generate_nav_mesh_source_geometry") and not node in found:
				found.append(node)
	return found
