extends "res://tests/test_base.gd"
# Guards who fight (enemies/guard.gd, systems/crime.gd): run from one and every
# guard near you takes up arms, dressed as themselves; beat one down and they
# yield (a bounty for assault, and the region's people think less of you);
# surrender (E) and they talk again; beaten by them, you're arrested (the cells,
# not death); outrun them and they go back to their posts. A fence in Ilunhall
# buys stolen goods from anywhere; the Fields have a warden. docs/godot-starter/CRIME.md.
var f := 0
var step := 0
var wait := 0
var p
var C
var DM
var budget := 0
var rep_before := 0
var day_before := 0

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/weirholt.tscn")

func n(path: String) -> Node:
	return current_scene.find_child(path, true, false)

func fighters() -> Array:
	return get_nodes_in_group("guards_fighting").filter(func(g): return not g.is_queued_for_deletion())

func choice_with(key: String, value: String) -> int:
	for i in DM._choices.size():
		if str(DM._choices[i].get(key, "")) == value:
			return i
	return -1

func in_front_of(who: Node3D, metres: float) -> void:
	p.global_position = who.global_position + (-who.global_basis.z) * metres
	p.velocity = Vector3.ZERO

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	C = autoload("Crime")
	DM = autoload("DialogueManager")
	var I = autoload("Inventory")
	var W = autoload("WorldClock")
	var R = autoload("Reputation")
	match step:
		0:
			W.hour = 13.0
			autoload("GameState").set_flag("met_tarle")   # the River Compact knows you
			wait = 10
		1:
			C._add_bounty("riverlands", 20, "Test.")
			rep_before = R.value("river_compact")
			in_front_of(n("Varga"), 3.0)
			n("Varga").interact(p)
			ok(DM.is_active, "Varga stops you")
			DM.choose(choice_with("crime", "resist"))
			ok(not DM.is_active and C.bounty_here() == 30, "you run: the bounty grows", C.bounty)
			wait = 3
		2:
			var armed: Array = fighters()
			ok(armed.size() == 2, "Varga and Dace both take up arms", armed.map(func(g): return g.name))
			ok(not n("Varga").visible and n("Varga").collision_layer == 0, "the NPC steps out")
			var varga = n("VargaArmed")
			ok(varga != null and varga.display_name == "Captain Varga" and varga.look_role == "guard" and varga.model.get_node_or_null("Figure") != null,
					"a fighter in Varga's clothes steps in")
			ok(varga.attacks.size() > 0 and varga.weapon_holder.get_child_count() > 0, "with the bandit's swings and a sword (the scene's settings kept)")
			ok(varga.state == varga.State.CHASE, "and comes for you")
			ok(not varga.is_in_group("captors"), "guards arrest; they don't cage")
			# Beat Varga down: he yields.
			varga.stats.take_damage(varga.stats.max_health)
			wait = 2
		3:
			ok(n("VargaArmed") == null and n("Varga").visible, "beaten, Varga yields: he's himself again")
			ok(C.bounty_here() == 30 + C.ASSAULT, "with a bounty for assault", C.bounty)
			ok(R.value("river_compact") == rep_before - C.REPUTATION_LOSS["resist"] - C.REPUTATION_LOSS["assault"],
					"and the River Compact thinks less of you", [rep_before, R.value("river_compact")])
			# Dace is still after you: surrender to him.
			var dace = n("DaceArmed")
			ok(dace != null and dace.prompt.begins_with("Surrender"), "E at Dace: Surrender", dace.prompt if dace else "")
			I.add_gold(1000)
			dace.interact(p)
			ok(fighters().is_empty() and n("Dace").visible, "you surrender: weapons down")
			ok(DM.is_active and DM.speaker_label.text == "Sergeant Dace", "and Dace talks again", DM.speaker_label.text)
			DM.choose(choice_with("crime", "pay"))
			ok(C.bounty_here() == 0, "paid")
			DM.end()
			# Arrested: run again and let them beat you.
			C._add_bounty("riverlands", 20, "Test.")
			C.resist()
			wait = 3
		4:
			var dace = n("DaceArmed")
			ok(dace != null, "they come again")
			day_before = W.day
			p.note_attacker(dace)
			p.stats.take_damage(p.stats.max_health * 10.0)
			budget = 300
			step = 5
			return false
		5:
			budget -= 1
			if p.is_dead and budget > 0:
				return false
			ok(not p.is_dead and p.stats.health > 0.0, "beaten by a guard: not dead", p.stats.health)
			ok(W.day > day_before and p.global_position.distance_to(n("JailRelease").global_position) < 0.5, "arrested: the cells, then out at the barracks", W.day - day_before)
			ok(fighters().is_empty() and C.bounty_here() == 0, "the guards stand down; the bounty's served")
			ok(current_scene.scene_file_path.ends_with("weirholt.tscn"), "and no reload")
			# Outrun them.
			C._add_bounty("riverlands", 20, "Test.")
			in_front_of(n("Dace"), 3.0)
			C.resist()
			wait = 3
		6:
			ok(fighters().size() >= 1, "after you again")
			p.global_position = Vector3(-40, 1, -60)   # far up the road
			Engine.time_scale = 6.0
			budget = 3000
			step = 7
			return false
		7:
			budget -= 1
			if not fighters().is_empty() and budget > 0:
				if f % 30 == 0:
					p.global_position = Vector3(-40, 1, -60)
				return false
			Engine.time_scale = 1.0
			ok(fighters().is_empty() and n("Varga").visible and n("Dace").visible, "lost you: back at their posts")
			ok(not C.guards_may_stop(), "and they leave you be a while")
			C.bounty.erase("riverlands")
			change_scene_to_file("res://levels/ilunhall.tscn")
			wait = 20
		8:
			var T = autoload("Trade")
			I.add("lockpick", 2)
			C._mark_stolen("capital", "lockpick", I.count("lockpick"))
			ok("stolen" in T.why_not_sell("bruna", "lockpick"), "Bruna won't buy Ilunhall's stolen picks")
			ok(T.why_not_sell("quill", "lockpick") == "", "Quill, the Low Lane fence, will", T.why_not_sell("quill", "lockpick"))
			ok(n("Quill") != null, "Quill's in the Low Lane")
			change_scene_to_file("res://levels/grieving_fields.tscn")
			wait = 20
		9:
			ok(C.region() == "fields" and n("FieldsWarden").role == "guard" and n("JailRelease") != null, "the Fields have a warden, and a lock-up")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
