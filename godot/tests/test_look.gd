extends "res://tests/test_base.gd"
# The look pass (systems/figure.gd, levels/builders/builder_base.gd): people are
# greybox figures shaped by race and dressed by role, NPC collision fits their
# height, companions and the third-person body are figures too (the body follows
# your race), and the generated levels have textured materials and ground out to
# the horizon. docs/godot-starter/LOOK.md.
var f := 0
var step := 0
var wait := 0
var p

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	change_scene_to_file("res://levels/weirholt.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

## Height of the top of everything under `node`, over the node's own floor.
func top(node: Node3D) -> float:
	var best := 0.0
	for m in node.find_children("*", "MeshInstance3D", true, false):
		if m.visible and m.is_visible_in_tree():
			var box: AABB = m.global_transform * m.get_aabb()
			best = maxf(best, box.end.y - node.global_position.y)
	return best

func meshes(node: Node) -> int:
	return node.find_children("*", "MeshInstance3D", true, false).size()

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	match step:
		0:
			autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
			wait = 5
		1:
			# Figures: every race and role builds, races differ in height.
			var broken := []
			for race in Figure.RACES:
				for role in Figure.ROLES:
					var fig := Figure.build(race, role, Color(0.4, 0.3, 0.2))
					if fig.get_child_count() <= 5:
						broken.append("%s %s" % [race, role])
					fig.free()
			ok(broken.is_empty(), "every race in every role builds", broken)
			ok(Figure.race_key("Small Folk") == "small_folk" and Figure.race_key("nobody") == "human", "race names map to figure shapes")
			ok(Figure.height_of("small_folk") < Figure.height_of("deepfolk") and Figure.height_of("deepfolk") < Figure.height_of("human")
					and Figure.height_of("human") < Figure.height_of("passenger"), "small folk < deepfolk < humans < Passengers")
			# NPCs in a generated town.
			var wenna = n("Wenna")
			var varga = n("Varga")
			ok(wenna.race == "small_folk" and wenna.role == "merchant", "Wenna is small folk, a merchant", [wenna.race, wenna.role])
			ok(wenna.get_node_or_null("Figure") != null and not wenna.get_node("MeshInstance3D").visible, "the capsule's swapped for a figure")
			ok(top(wenna) < 1.45 and top(varga) > 1.9, "Wenna stands lower than Captain Varga (and his spear)", [top(wenna), top(varga)])
			var shape: CapsuleShape3D = wenna.get_node("CollisionShape3D").shape
			near(shape.height, 1.8 * Figure.height_of("small_folk"), 0.01, "and her collision fits her height")
			near(varga.get_node("CollisionShape3D").shape.height, 1.8, 0.001, "a human's stays as it was")
			# Materials and the horizon.
			var ground: StandardMaterial3D = n("GroundWest/Mesh").mesh.material
			ok(ground.albedo_texture != null and ground.uv1_world_triplanar, "the ground is textured (world triplanar)")
			var stone: StandardMaterial3D = n("Ford/Mesh").mesh.material
			ok(stone.normal_enabled and stone.albedo_texture != ground.albedo_texture, "stone has its own texture and a normal map")
			# Houses: a gabled roof, a door facing the streets, windows lit at night; pines
			# in layers (systems/tree_dresser.gd).
			var dressing = n("CountingHouseDressing")
			ok(dressing != null and dressing.get_node_or_null("RoofA") != null and dressing.get_node_or_null("Door") != null
					and dressing.get_node_or_null("Chimney") != null, "houses have roofs, doors and chimneys")
			var windows = dressing.get_node("Windows")
			autoload("WorldClock").hour = 23.0
			windows._update()
			var lit: float = windows.material.emission_energy_multiplier
			autoload("WorldClock").hour = 13.0
			windows._update()
			ok(lit > 1.0 and windows.material.emission_energy_multiplier < 0.2, "windows glow at night, not by day", [lit, windows.material.emission_energy_multiplier])
			var door: Node3D = dressing.get_node("Door")
			ok(door.global_position.length() < dressing.global_position.length(), "the door is on the side facing the middle of town")
			var tree = n("Tree1")
			ok(tree.get_node_or_null("CrownLayer2") != null and not tree.get_node("Crown").visible, "pines are layered", tree.get_children().map(func(c): return c.name))
			var skirt = n("GroundSkirt")
			ok(skirt != null and skirt.mesh.size.x >= 1000.0 and skirt.global_position.y < n("River").global_position.y,
					"ground on to the horizon, under the river")
			# The third-person body: your race.
			var V = p.get_node("View")
			ok(V.body.get_node_or_null("Figure") != null, "the third-person body is a figure")
			var human_meshes := meshes(V.body.get_node("Figure"))
			autoload("Character").create(load("res://races/deepfolk.tres"), "T", "soldier", [], {}, {})
			autoload("Settings").set_option("third_person", true)
			wait = 5
		2:
			var V = p.get_node("View")
			ok(V._body_race == "Deepfolk", "the body follows a new race", V._body_race)
			ok(V._rig.position.y < V.SHOULDERS.y, "and holds things at a deepfolk's shoulders", V._rig.position.y)
			autoload("Settings").set_option("third_person", false)
			# The Vale's people (hand-placed, given a race and role in the scene).
			change_scene_to_file("res://levels/test_level.tscn")
			wait = 30
		3:
			var moss = n("Lanternfast/Moss")
			var pim = n("Lanternfast/Pim")
			ok(moss.race == "ashen" and moss.get_node_or_null("Figure") != null, "Moss is Ashen")
			ok(pim.role == "child" and top(pim) < 1.3, "Pim's a child", top(pim))
			var dunya = n("Dunya")
			ok(dunya.sitting and top(dunya) < 1.4, "Dunya sits", top(dunya))
			ok(n("Aurel").get_node("Figure") != null, "Magister Aurel has a figure")
			var pine = n("Thornwood/Tree1")
			ok(pine.get_node_or_null("CrownLayer0") != null and not pine.get_node("Canopy").visible, "the Vale's hand-placed pines are layered too")
			# Enemies: figures too, each in its own clothes, with arms on the shoulder pivots.
			var camp: Array = n("BanditCamp").get_children()
			ok(camp.all(func(b): return b.model.get_node_or_null("Figure") != null and b.model.get_node_or_null("Body") == null),
					"bandits are figures (the placeholder body's gone)")
			ok(camp.all(func(b): return b.right_arm.get_child_count() >= 3), "with their arms on the swinging shoulders (and the sword in hand)")
			var looks := {}
			for b in camp:
				looks["%s %s" % [b.look_race, b.look_cloth]] = true
			ok(looks.size() >= 2, "and not all the same person", looks.keys())
			var mats := {}
			for b in camp:
				mats[b._cloth] = true
			ok(mats.size() == camp.size(), "each with clothes of its own")
			var before: Color = camp[1]._cloth.albedo_color
			camp[0]._on_damaged(5.0)
			ok(camp[1]._cloth.albedo_color == before, "so a hit flash tints only the one that was hit")
			camp[0]._pose("overhead", 0.01)
			# Companions.
			autoload("GameState").set_flag("companion_brannoc")
			wait = 5
		4:
			var raised = n("BanditCamp").get_children()[0]
			ok(raised.right_arm.rotation_degrees.x > 100.0 and raised.weapon_holder.global_position.y > raised.global_position.y + 1.6,
					"poses still swing the figure's arm, sword and all", raised.right_arm.rotation_degrees)
			var comp = get_nodes_in_group("companion")
			ok(comp.size() == 1 and comp[0]._body.name == "Figure", "a companion is a figure too")
			if comp.size() == 1:
				ok(comp[0]._body.get_child_count() > 5, "Brannoc dressed as a hunter")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
