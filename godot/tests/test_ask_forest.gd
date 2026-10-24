extends "res://tests/test_base.gd"
# Main quest 3, "Ask the Forest": the drain-line starts it; find Mirela at the
# outlaw camp; earn trust (clear the bandit camp, bring a garrison supply crate
# from Brannoc, or, as an Outlaw, show your wanted notice); she gives the barrow
# lead. Argument: bandits (hunter), supplies (soldier), outlaw.
const BACKGROUND := {"bandits": "hunter", "supplies": "soldier", "outlaw": "outlaw"}
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var DM
var GS
var Q
var R
var I

func _initialize() -> void:
	mode = arg("bandits")
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", BACKGROUND[mode], [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func texts() -> Array:
	return DM._choices.map(func(c): return c["text"])

func pick(start: String) -> void:
	var t := texts()
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
	DM = autoload("DialogueManager"); GS = autoload("GameState"); Q = autoload("QuestLog")
	R = autoload("Reputation"); I = autoload("Inventory")
	match step:
		0:
			wait = 5
		1:
			for n in ["Mirela", "Dunya", "Ostap", "OutlawFire", "MapOutlawCamp"]:
				ok(current_scene.get_node_or_null(n) != null, "%s in the level" % n)
			ok(Q.status("ask_forest")["state"] == "hidden", "hidden before the drain-line")
			ok(not R.known("thornwood_free") or mode == "outlaw", "faction unknown yet (outlaws know it)")
			GS.set_flag("saw_drain_line")
			ok(Q.status("ask_forest")["state"] == "active", "the drain-line starts it")
			ok(Q.current_objective("ask_forest").begins_with("Follow the drain-line north"), "first objective", Q.current_objective("ask_forest"))
			# The camp is where the line ends.
			var line_end: Vector3 = current_scene.get_node("DrainLine").point(1.0)
			var mirela: Node3D = current_scene.get_node("Mirela")
			between(Vector2(line_end.x - mirela.global_position.x, line_end.z - mirela.global_position.z).length(), 0.0, 10.0, "the drain-line ends at the camp (m)")
			# Nothing in the Thornwood blocks the camp.
			for t in current_scene.get_node("Thornwood").get_children():
				ok(t.global_position.distance_to(mirela.global_position) > 5.0, "%s clear of the camp" % t.name)
			DM.start("res://dialogue/ostap.json", "Ostap")
			ok(DM.line_label.text.contains("Far enough."), "the lookout stops you")
			ok(texts().any(func(t): return t.begins_with("(Outlaw)")) == (mode == "outlaw"), "lookout's outlaw line only for outlaws", texts())
			DM.end()
			DM.start("res://dialogue/mirela.json", "Mirela")
			ok(DM.line_label.text.begins_with("So you're the one"), "Mirela's greeting", DM.line_label.text)
			ok(R.known("thornwood_free"), "faction known once you meet her")
			ok(Q.current_objective("ask_forest") == "Hear what Mirela's scouts have seen.", "objective after meeting", Q.current_objective("ask_forest"))
			if mode == "outlaw":
				ok(texts().filter(func(t): return t.begins_with("(Outlaw)")).size() == 1, "one outlaw line", texts())
				DM.end()
				I.add("wanted_notice")   # the outlaw's opening gives it
				DM.start("res://dialogue/mirela.json", "Mirela")
				var before: int = R.value("thornwood_free")
				pick("(Outlaw)")
				ok(GS.has_flag("outlaws_trust"), "the wanted notice vouches for you")
				ok(R.value("thornwood_free") > before, "outlaw rep up")
				pick("Something's drawing magic")
				pick("Then help me find who's doing it.")
				ok(DM.line_label.text.begins_with("Hooded folk"), "straight to the lead", DM.line_label.text)
				DM.end()
				step = 9
				return false
			ok(not texts().any(func(t): return t.begins_with("(Outlaw)")), "no notice to show")
			pick("Something's drawing magic")
			ok(DM.line_label.text.begins_with("Here, and past here."), "Dunya's story", DM.line_label.text)
			pick("Then help me find who's doing it.")
			ok(DM.line_label.text.begins_with("Help? We've heard that"), "her terms", DM.line_label.text)
			DM.end()
			ok(Q.current_objective("ask_forest").begins_with("Earn the outlaws' trust"), "trust objective", Q.current_objective("ask_forest"))
			if mode == "supplies":
				var rw: int = R.value("riverwatch")
				DM.start("res://dialogue/brannoc.json", "Brannoc")
				pick("I need a crate")
				ok(I.count("supply_crate") == 1, "Brannoc hands over a crate")
				ok(R.value("riverwatch") == rw - 10, "at a garrison reputation cost", R.value("riverwatch"))
				DM.end()
				DM.start("res://dialogue/brannoc.json", "Brannoc")
				ok(not texts().any(func(t): return t.begins_with("I need a crate")), "only one crate")
				DM.end()
				DM.start("res://dialogue/mirela.json", "Mirela")
				ok(DM.line_label.text.begins_with("Well? The thieves, or the crate."), "she's waiting", DM.line_label.text)
				pick("Here. A crate")
				ok(I.count("supply_crate") == 0 and GS.has_flag("outlaws_trust"), "crate delivered, trust earned")
				pick("So. What have your scouts seen?")
				DM.end()
				step = 9
				return false
		2:
			# Clear the bandit camp for real, then search the leader.
			for b in current_scene.get_node("BanditCamp").get_children():
				b.stats.take_damage(10000.0, true)
			wait = 10
		3:
			ok(GS.has_flag("bandits_cleared"), "bandit camp cleared")
			var leader = current_scene.get_node("BanditCamp/Leader")
			leader.interact(p)
			ok(I.count("marked_coin") == 1, "the leader carried a marked coin")
			DM.start("res://dialogue/mirela.json", "Mirela")
			ok(DM.line_label.text.begins_with("The camp by the stones is ash"), "Mirela heard", DM.line_label.text)
			ok(GS.has_flag("outlaws_trust"), "trust earned")
			pick("Their leader carried coins")
			ok(GS.has_flag("knows_marked_coin"), "the coin means something")
			pick("So. What have your scouts seen?")
			DM.end()
			step = 9
			return false
		10:
			ok(GS.has_flag("barrow_lead"), "the barrow lead")
			ok(Q.status("ask_forest")["state"] == "completed", "Ask the Forest completed")
			var outcome: String = Q.status("ask_forest")["outcome"]
			var expect := {"bandits": "I cleared the bandit camp", "supplies": "I brought the outlaws a crate", "outlaw": "The outlaws took me at my word"}
			ok(outcome.begins_with(expect[mode]), "outcome", outcome)
			ok(R.rank("thornwood_free") in ["Friendly", "Honored"], "the outlaws like you", [R.value("thornwood_free"), R.rank("thornwood_free")])
			DM.start("res://dialogue/mirela.json", "Mirela")
			ok(DM.line_label.text.begins_with("Still breathing?"), "Mirela afterwards", DM.line_label.text)
			DM.end()
			DM.start("res://dialogue/dunya.json", "Dunya")
			ok(DM.line_label.text.contains("circle split by three lines"), "Dunya bears the mark")
			DM.end()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
