extends "res://tests/test_base.gd"
# Act-one content from the lore (docs/lore/STORY.md):
# - Inquisitor Hale of the Lantern Order, on the south road: talks to a clean player
#   (and can be told where Zora lives, which Zora doesn't forgive), warns a Touched
#   one, and draws on a Stained one (his fighting self takes his place).
# - The Mercy's cell in the south-east hollow: Sister Halina talks first. "fight"
#   (default): she slips away and both merciful come for you; kill them and the
#   journal says so. "peace": they go, and the journal says so.
# - Brannoc and Zora each say they'd travel with you (future companions).
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var C
var GS
var DM
var Q

func _initialize() -> void:
	mode = arg("fight")
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func texts() -> Array:
	return DM._choices.map(func(c): return c["text"])

func talk(file: String) -> String:
	if DM.is_active:
		DM.end()
	DM.start("res://dialogue/%s.json" % file, file)
	return DM.line_label.text

func pick(start: String) -> bool:
	var t := texts()
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return true
	ok(false, "choice '%s' offered" % start, t)
	return false

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	C = autoload("Corruption"); GS = autoload("GameState"); DM = autoload("DialogueManager"); Q = autoload("QuestLog")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			wait = 5
		1:
			# Brannoc, after Wrong Things.
			for flag in ["met_brannoc", "wrong_things_done"]: GS.set_flag(flag)
			talk("brannoc")
			pick("What will you do, after all this?")
			ok(DM.line_label.text.contains("Ask me then") and GS.has_flag("brannoc_would_travel"), "Brannoc would travel with you", DM.line_label.text)
			# Brannoc's lead to the Mercy.
			talk("brannoc")
			pick("Anything else I should know about out here?")
			ok(DM.line_label.text.contains("hooded lot") and GS.has_flag("heard_about_mercy"), "Brannoc mentions the hooded camp")
			ok(Q.status("the_merciful")["state"] == "active", "The Merciful starts")
			DM.end()
			# The inquisitor, to a clean player.
			GS.set_flag("met_zora")
			ok(talk("inquisitor").contains("Lantern Order. Inquisitor Hale"), "the inquisitor introduces himself", DM.line_label.text)
			if mode == "fight":
				pick("Her hut is west of the outlaw camp.")
				ok(GS.has_flag("inquisitor_told_zora"), "you told him where Zora lives")
				ok(talk("zora").contains("In your words"), "Zora knows", DM.line_label.text)
				ok(not talk("zora").is_empty() and not texts().has("Would you ever leave this place?"), "and won't travel with you")
			else:
				pick("No.")
				talk("zora")
				pick("Would you ever leave this place?")
				ok(GS.has_flag("zora_would_travel"), "Zora would travel with you", DM.line_label.text)
			DM.end()
			# Touched: a warning.
			C.value = 25.0
			ok(talk("inquisitor").contains("coldness about the eyes") and GS.has_flag("inquisitor_warned"), "Touched: he warns you", DM.line_label.text)
			DM.end()
			# Stained: he draws.
			C.value = 55.0
			p.global_position = n("InquisitorOnRoad/Inquisitor").global_position + Vector3(0, 0.05, -3)
			ok(talk("inquisitor").contains("The Order is merciful, and it's quick"), "Stained: he draws", DM.line_label.text)
			pick("(Fight.)")
			wait = 20
		2:
			ok(not n("InquisitorOnRoad").is_present() and n("InquisitorDrawn").is_present(), "the man on the road becomes the foe")
			var foe = n("InquisitorDrawn/InquisitorFoe")
			ok(foe.state != foe.State.IDLE, "and he comes for you", foe.State.keys()[foe.state])
			ok(not foe.is_in_group("captors"), "the Order takes no prisoners")
			foe.stats.take_damage(1000.0, true)
			C.value = 55.0
			# The Mercy's cell.
			p.global_position = n("MercyCell").global_position + Vector3(0, 0.05, 5)
			ok(talk("halina").contains("We're not here for you. We're here for them."), "Sister Halina", DM.line_label.text)
			ok(texts().has("You've got grey fingers. So do I."), "Stained: she sees your hands", texts())
			if mode == "fight":
				pick("I'm stopping you.")
				DM.end()
				wait = 20
			else:
				pick("What are you doing to the wisps?")
				ok(DM.line_label.text.contains("Staying hurts them forever"), "why they do it")
				pick("Go in peace.")
				DM.end()
				wait = 5
		3:
			if mode == "fight":
				ok(not n("MercyCell/HalinaHere").is_present(), "Halina slips away")
				var merciful: Array = n("MercyCell/Merciful").get_children()
				ok(merciful.all(func(m): return m.state != m.State.IDLE), "both merciful come for you", merciful.map(func(m): return m.State.keys()[m.state]))
				for m in merciful: m.stats.take_damage(1000.0, true)
				wait = 5
			else:
				ok(not n("MercyCell").is_present(), "they go")
				ok(GS.has_flag("mercy_let_go") and GS.has_flag("mercy_cell_done"), "let go, and done")
		4:
			var q: Dictionary = Q.status("the_merciful")
			ok(q["state"] == "completed", "The Merciful completed", q)
			var expect := "I fought the Mercy" if mode == "fight" else "I let them go in peace"
			ok(q["outcome"].contains(expect), "journal: " + expect, q["outcome"])
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
