extends "res://tests/test_base.gd"
# Main quest 4, "The Barrow": the scrape marks and the secret wall in the vault,
# the hooded cultists (still until the wall opens), the notes, and the last caged
# wisp: free it (a light that follows you, here and after reloading) or take its
# essence (+25 max Magicka, the outlaws hear). Argument: free (default) or take.
const LEVEL := "res://levels/test_dungeon.tscn"
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var GS
var Q
var DM
var magicka_before := 0.0
var rep_before := 0

func _initialize() -> void:
	mode = arg("free")
	autoload("SaveSystem").delete_save()
	change_scene_to_file(LEVEL)

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func pick(start: String) -> void:
	var t: Array = DM._choices.map(func(c): return c["text"])
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return
	ok(false, "choice '%s' offered" % start, t)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); Q = autoload("QuestLog"); DM = autoload("DialogueManager")
	match step:
		0:
			wait = 5
		1:
			GS.set_flag("met_mirela")
			GS.set_flag("barrow_lead")
			ok(Q.status("the_barrow")["state"] == "active", "Mirela's lead starts The Barrow")
			var wall = n("SecretWall")
			ok(wall.prompt == "Examine the scrape marks" and wall.collision_layer != 0, "a wall with scrape marks", wall.prompt)
			for c in n("Cultists").get_children():
				ok(not c.is_physics_processing(), "%s waits behind the wall" % c.name)
				ok(not c.is_in_group("captors"), "cultists take no prisoners")
			for path in ["CagedWisp", "CultNotes", "Jar1", "Worktable", "ChamberFloor"]:
				ok(n(path) != null, "%s in the chamber" % path)
			# Stand in the vault and push the wall.
			p.global_position = Vector3(-1.5, 0.05, -68)
			p.rotation.y = PI / 2   # facing west (-X)
			wall.interact(p)
			ok(GS.has_flag("found_hidden_chamber"), "found the hidden chamber")
			ok(p.hud.message_label.text.begins_with("Something heavy has been dragged"), "message", p.hud.message_label.text)
			ok(Q.current_objective("the_barrow").begins_with("Find out what the hooded folk"), "next objective", Q.current_objective("the_barrow"))
			wait = 120
		2:
			ok(n("SecretWall").collision_layer == 0 and n("SecretWall").position.y < -1.0, "the wall has sunk")
			for c in n("Cultists").get_children():
				ok(c.is_physics_processing(), "%s wakes" % c.name)
			ok(n("Cultists").get_children().any(func(c): return c.state != c.State.IDLE), "the cultists come for you", n("Cultists").get_children().map(func(c): return c.state))
			for c in n("Cultists").get_children():
				c.stats.take_damage(10000.0, true)
			p.stats.refill()
			wait = 10
		3:
			ok(GS.has_flag("cultists_cleared"), "cultists dealt with")
			n("Cultists/Cultist1").interact(p)
			ok(autoload("Inventory").count("marked_coin") == 1, "a cultist carries a marked coin")
			n("CultNotes").interact(p)
			ok(autoload("Inventory").count("cult_notes") == 1, "took the notes")
			ok(autoload("Inventory").get_item("cult_notes").description.contains("Hollow Oak"), "the notes point to the Hollow Oak")
			ok(Q.current_objective("the_barrow") == "Decide what to do with the last caged wisp.", "objective: the wisp", Q.current_objective("the_barrow"))
			var player_stats = p.stats
			magicka_before = player_stats.max_magicka
			rep_before = autoload("Reputation").value("thornwood_free")
			n("CagedWisp").interact(p)
			ok(DM.is_active and DM.line_label.text.begins_with("An iron cage"), "the caged wisp", DM.line_label.text)
			if mode == "free":
				pick("Open the cage.")
				ok(GS.has_flag("freed_wisp"), "freed")
			else:
				pick("Draw its light")
				ok(DM.line_label.text.begins_with("You'd only have to"), "a warning first", DM.line_label.text)
				pick("Do it.")
				ok(GS.has_flag("took_wisp_essence"), "took its essence")
			DM.end()
			ok(Q.status("the_barrow")["state"] == "completed", "The Barrow completed")
			ok(n("CagedWisp").prompt == "", "nothing more to do with the cage")
			wait = 90
		4:
			var companion = current_scene.find_child("WispCompanion", false, false)
			var outcome: String = Q.status("the_barrow")["outcome"]
			if mode == "free":
				ok(companion != null, "the wisp follows you")
				if companion:
					between(companion.global_position.distance_to(p.global_position), 1.0, 3.5, "over your shoulder (m)")
				ok(outcome.begins_with("Behind the barrow's vault") and outcome.contains("I freed the last wisp"), "outcome: freed", outcome)
			else:
				ok(companion == null, "no companion")
				near(p.stats.max_magicka, magicka_before + 25.0, 0.5, "+25 max Magicka")
				ok(autoload("Reputation").value("thornwood_free") == rep_before - 15, "the outlaws heard", autoload("Reputation").value("thornwood_free"))
				ok(outcome.contains("I took the last wisp's light"), "outcome: took", outcome)
			ok(not n("CagedWisp/Orb").visible, "the cage is empty")
			DM.start("res://dialogue/mirela.json", "Mirela")
			var expect := "Is that a wisp on your shoulder?" if mode == "free" else "Word travels in the Thornwood."
			ok(DM.line_label.text.begins_with(expect), "Mirela reacts", DM.line_label.text)
			DM.end()
			# Come back later: the wall stays open, the cage stays empty, the wisp still follows.
			change_scene_to_file(LEVEL)
			wait = 15
		5:
			ok(n("SecretWall").collision_layer == 0, "the wall stays open")
			ok(not n("CagedWisp/Orb").visible and n("CagedWisp").prompt == "", "the cage stays empty")
			ok((current_scene.find_child("WispCompanion", false, false) != null) == (mode == "free"), "the companion comes along to new places")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
