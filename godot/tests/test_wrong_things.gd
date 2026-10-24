extends "res://tests/test_base.gd"
# Main quest 1, "Wrong Things": Maren -> the hollow wolf (copy its mark, then put
# it down or leave it) -> Brannoc. The hollow wolf never attacks or moves.
# Argument: mercy (hunter, put down in the dialogue), spare (scholar, left
# standing, then killed later), weapon (soldier, killed before examining it).
const LEVEL := "res://levels/test_level.tscn"
const BACKGROUND := {"mercy": "hunter", "spare": "scholar", "weapon": "soldier"}
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var wolf
var DM
var GS
var Q
var health_before := 0.0
var wolf_spot := Vector3.ZERO

func _initialize() -> void:
	mode = arg("mercy")
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", BACKGROUND[mode], [], {}, {})
	autoload("Openings").pending = true
	change_scene_to_file(LEVEL)

func choose_starting(start: String) -> void:
	var texts: Array = DM._choices.map(func(c): return c["text"])
	for i in texts.size():
		if texts[i].begins_with(start):
			DM.choose(i)
			return
	ok(false, "choice '%s' offered" % start, texts)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	DM = autoload("DialogueManager"); GS = autoload("GameState"); Q = autoload("QuestLog")
	wolf = current_scene.get_node_or_null("HollowWolf")
	match step:
		0:
			wait = 10
		1:
			ok(Q.status("wrong_things")["state"] == "active", "quest started by the opening")
			DM.start("res://dialogue/maren.json", "Maren")
			DM.choose(0)   # the background's opener
			DM.choose(0)
			ok(GS.has_flag("maren_wrong_things"), "Maren told you about the wrong things")
			choose_starting("Where did he see it?")
			ok(DM.line_label.text.begins_with("East of Greyfang Hollow"), "Maren says where", DM.line_label.text)
			DM.end()
			ok(Q.current_objective("wrong_things") == "Find the hollow wolf east of Greyfang Hollow.", "objective: the hollow wolf", Q.current_objective("wrong_things"))
			# Stand next to it, with nothing else around.
			wolf_spot = wolf.global_position
			p.global_position = wolf_spot + Vector3(0, 0, 1.6)
			health_before = p.stats.health
			wait = 90
		2:
			near(p.stats.health, health_before, 0.01, "the hollow wolf never bites")
			near(Vector2(wolf.global_position.x - wolf_spot.x, wolf.global_position.z - wolf_spot.z).length(), 0.0, 0.1, "it doesn't move")
			ok(wolf.state == wolf.State.IDLE, "it doesn't hunt", wolf.state)
			ok(wolf.collision_layer & 8, "the E ray can find it alive")
			ok(wolf.prompt == "Examine the hollow wolf", "prompt", wolf.prompt)
			if mode == "weapon":
				var result: String = wolf.take_hit(30.0, p.global_position, 5.0, 10.0)
				ok(result == "hit" and wolf.state == wolf.State.IDLE, "a blow doesn't make it fight back", wolf.state)
				wolf.take_hit(500.0, p.global_position)
				ok(wolf.state == wolf.State.DEAD, "killed with a weapon")
				ok(GS.has_flag("hollow_wolf_killed"), "killed flag")
				ok(not GS.has_flag("saw_hollow_wolf"), "mark not seen yet")
				ok(wolf.prompt == "Examine the hollow wolf" and wolf.collision_layer == 8, "corpse can be examined", [wolf.prompt, wolf.collision_layer])
				wolf.interact(p)
				ok(GS.has_flag("saw_hollow_wolf"), "examining the body finds the mark")
				ok(autoload("Inventory").count("charcoal_rubbing") == 1, "charcoal rubbing")
				ok(wolf.prompt == "" and wolf.collision_layer == 0, "nothing more to do with it")
				ok(p.hud.message_label.text.begins_with("Burnt into its flank"), "message", p.hud.message_label.text)
			else:
				wolf.interact(p)
				ok(DM.is_active and DM.line_label.text.begins_with("It doesn't run."), "the hollow wolf's dialogue", DM.line_label.text)
				ok(GS.has_flag("saw_hollow_wolf"), "mark seen")
				ok(autoload("Inventory").count("charcoal_rubbing") == 1, "charcoal rubbing")
				ok(Q.current_objective("wrong_things").begins_with("Show the mark to Brannoc"), "objective: Brannoc", Q.current_objective("wrong_things"))
				if mode == "mercy":
					choose_starting("(Hunter) Read its tracks first.")
					ok(DM.line_label.text.begins_with("The same prints"), "hunter reads the tracks", DM.line_label.text)
					choose_starting("Put it out of its misery.")
					ok(wolf.state == wolf.State.DEAD, "put down from the dialogue")
					ok(wolf.prompt == "" and wolf.collision_layer == 0, "no skinning a hollow wolf")
				else:
					choose_starting("(Scholar) Look closer at the mark.")
					ok(DM.line_label.text.begins_with("Not a brand."), "scholar reads the mark", DM.line_label.text)
					choose_starting("Leave it be.")
					ok(GS.has_flag("hollow_wolf_spared") and wolf.state != wolf.State.DEAD, "left standing")
				DM.end()
				wolf.interact(p)
				if mode == "spare":
					ok(DM.is_active and DM.line_label.text.begins_with("It hasn't moved."), "talking to it again", DM.line_label.text)
					DM.end()
				else:
					ok(not DM.is_active, "nothing more to say to a dead wolf")
				ok(autoload("Inventory").count("charcoal_rubbing") == 1, "only one rubbing")
			wait = 30
		3:
			# Brannoc.
			DM.start("res://dialogue/brannoc.json", "Brannoc")
			ok(DM.line_label.text.begins_with("Brannoc turns the scrap over twice."), "Brannoc looks at the mark", DM.line_label.text)
			ok(Q.status("wrong_things")["state"] == "completed", "Wrong Things completed")
			ok(Q.status("waking_stones")["state"] == "hidden", "Waking Stones not started yet")
			var texts: Array = DM._choices.map(func(c): return c["text"])
			ok(texts.any(func(t): return t.begins_with("(Scholar)")) == (mode == "spare"), "scholar's line only for the scholar", texts)
			ok(texts.any(func(t): return t.begins_with("(Hunter)")) == (mode == "mercy"), "hunter's line only for the hunter", texts)
			if mode == "mercy":
				choose_starting("(Hunter)")
				ok(GS.has_flag("heard_of_thornwood"), "hunter points Brannoc at the Thornwood")
			choose_starting("Then I'll look at the stones.")
			ok(Q.status("waking_stones")["state"] == "active", "leads into The Waking Stones")
			DM.end()
			var outcome: String = Q.status("wrong_things")["outcome"]
			if mode == "spare":
				ok(outcome.begins_with("I left the hollow wolf standing"), "outcome: spared", outcome)
				# Changing your mind later still works, and the outcome follows.
				wolf.take_hit(500.0, p.global_position)
				ok(wolf.state == wolf.State.DEAD and GS.has_flag("hollow_wolf_killed"), "killed later")
				ok(wolf.prompt == "" and wolf.collision_layer == 0, "already examined: nothing to do with the body")
				outcome = Q.status("wrong_things")["outcome"]
			ok(outcome.begins_with("I put the hollow wolf out of its misery"), "outcome: put down", outcome)
			# The body stays examined after a save and load.
			var state: Dictionary = wolf.get_persist_state()
			ok(state["dead"] and state["examined"], "persist state", state)
			DM.start("res://dialogue/brannoc.json", "Brannoc")
			ok(not DM.line_label.text.begins_with("Brannoc turns"), "Brannoc doesn't repeat himself", DM.line_label.text)
			DM.end()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
