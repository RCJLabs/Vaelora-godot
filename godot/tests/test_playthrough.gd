extends "res://tests/test_base.gd"
# The whole demo in one run, the way a player would string it together: the
# Hunter's opening, all five main quests (with the trip into the barrow and
# back), every side quest, and the ending, with saves and loads in between
# (including one inside the dungeon). It drives the game through the same calls
# a key press would make (interact, dialogue choices, doors), and fights by
# dealing damage directly: the fights themselves are tested elsewhere.
# Brannoc travels with you from quest 3 to the Greyfang Pack (into the barrow,
# where you read the Riverwatch Roll), and Zora from Licence to Burn on; their
# quests are done the way their approval allows.
# At the end every quest in quests.json must be completed, and stay so after a
# last save and load.
# Argument: normal (default) or hardcore. Hardcore saves only by resting, and
# before quest 3 the bandits capture you: you wake in their cage, next to Jory.
const LEVEL := "res://levels/test_level.tscn"
const DUNGEON := "res://levels/test_dungeon.tscn"

var steps: Array = []   # [frames to wait first, what to do]
var index := 0
var wait := 0
var p
var GS
var Q
var DM
var I
var S
var clock
var notices: Array = []
var hardcore := false


func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	hardcore = arg("normal") == "hardcore"
	autoload("Character").create(load("res://races/human.tres"), "Tester", "hunter", [], {}, {"hardcore": hardcore})
	autoload("Openings").pending = true
	change_scene_to_file(LEVEL)
	_plan()


func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)


func say(file: String) -> void:
	if DM.is_active:
		DM.end()
	DM.start("res://dialogue/%s.json" % file, file)


func pick(start: String) -> void:
	var texts: Array = DM._choices.map(func(c): return c["text"])
	for i in texts.size():
		if texts[i].begins_with(start):
			DM.choose(i)
			return
	ok(false, "choice '%s' offered (line: %s)" % [start, DM.line_label.text.substr(0, 40)], texts)


func kill(node: Node) -> void:
	node.stats.take_damage(100000.0, true)


func state(id: String) -> String:
	return Q.status(id)["state"]


func at(position: Vector3) -> void:
	p.global_position = position
	p.velocity = Vector3.ZERO


func save_and_load(label: String) -> void:
	DM.end()
	p.stats.refill()
	ok(S.save_game(S.QUICKSAVE, hardcore), "%s: saved" % label)   # Hardcore: as if resting
	ok(S.load_game(S.QUICKSAVE), "%s: loading" % label)


func step(frames: int, what: Callable) -> void:
	steps.append([frames, what])


func _plan() -> void:
	# --- the opening and quest 1 ---------------------------------------------
	step(10, func():
		ok(state("wrong_things") == "active", "the Hunter's opening starts Wrong Things")
		say("maren"); pick("I'm tracking a Greyfang"); pick("Old Tam?"); pick("Where did he see it?")
		n("HollowWolf").interact(p)
		pick("(Hunter) Read its tracks first."); pick("Put it out of its misery.")
		say("brannoc"); pick("(Hunter) Its tracks came out of the forest"); pick("Then I'll look at the stones.")
		ok(state("wrong_things") == "completed", "1. Wrong Things done"))
	step(1, func(): save_and_load("after quest 1"))
	# --- quest 2 ---------------------------------------------------------------
	step(15, func():
		ok(state("waking_stones") == "active", "The Waking Stones survives the load")
		var crystal = n("StoneCircle/Crystal")
		crystal.interact(p)
		for shard in ["RuneShard1", "RuneShard2", "RuneShard3"]:
			n(shard).interact(p)
		say("brannoc"); pick("I found three rune shards."); pick("Take them to Riverwatch.")
		DM.end()
		crystal.interact(p)
		ok(state("waking_stones") == "completed", "2. The Waking Stones done")
		ok(state("ask_forest") == "active", "the drain-line starts Ask the Forest")
		say("brannoc")
		if DM.line_label.text.begins_with("The captain sent word"):
			pick("Thank you, Brannoc.")   # the captain's gift comes first at this reputation
			say("brannoc")
		pick("The crystal showed me"); pick("(Hunter) Same way"))
	# --- Hardcore: beaten by the bandits, you wake in their cage, next to Jory --
	if hardcore:
		step(1, func():
			DM.end()
			autoload("Defeat").wake(p, "captured"))
		step(10, func():
			ok(p.global_position.distance_to(n("BanditCage/CaptiveCell").global_position) < 0.5, "captured: in the cage")
			ok(n("JoryInCage").visible and p.global_position.distance_to(n("JoryInCage/JoryCaged").global_position) < 1.5, "Jory's in there with you")
			say("jory_caged")
			ok(DM.line_label.text.begins_with("You! You're not one of them."), "Jory, through the bars")
			ok(state("lost_wagon") == "active", "The Lost Wagon starts in the cage")
			DM.end()
			var door = n("BanditCage/CageDoor")
			for i in door.tries_needed:
				door.interact(p)
			say("jory_caged")
			ok(GS.has_flag("jory_freed"), "out together")
			DM.end()
			var stash = n("BanditCage/CaptorStash")
			var taken: Dictionary = stash.contents.duplicate()
			stash.interact(p)
			ok(taken.size() > 3 and taken.keys().all(func(id): return I.count(id) >= int(taken[id])), "gear back from the bandits' stash", [taken, I.items]))
	# --- quest 3, and Thieves by the Fire --------------------------------------
	step(1, func():
		say("brannoc"); pick("Anything else I should know about out here?")
		# Brannoc comes along from here.
		say("brannoc"); pick("What will you do, after all this?")
		say("brannoc"); pick("Come with me.")
		ok(autoload("Companions").active() == "brannoc", "Brannoc joins you")
		say("mirela"); pick("Something's drawing magic"); pick("A wolf by Greyfang Hollow"); pick("Then help me find who's doing it.")
		DM.end()
		for bandit in n("BanditCamp").get_children():
			kill(bandit))
	step(10, func():
		n("BanditCamp/Leader").interact(p)
		ok(I.count("marked_coin") == 1, "the bandit leader's marked coin")
		say("brannoc"); pick("The bandit camp south-west of here is cleared.")
		ok(state("bandit_camp") == "completed", "Thieves by the Fire done")
		say("mirela"); pick("Their leader carried coins"); pick("So. What have your scouts seen?")
		ok(state("ask_forest") == "completed", "3. Ask the Forest done")
		ok(state("the_barrow") == "active", "The Barrow starts"))
	step(1, func(): save_and_load("after quest 3"))
	# --- quest 4: into the barrow ----------------------------------------------
	step(15, func():
		at(Vector3(-20, 0.05, 28.0))
		n("DungeonEntrance").interact(p))
	step(20, func():
		ok(current_scene.scene_file_path == DUNGEON, "into the barrow")
		ok(state("the_barrow") == "active", "still on The Barrow")
		ok(autoload("Companions").body() != null, "Brannoc comes into the barrow")
		n("RiverwatchRoll").interact(p)
		autoload("BookReader").close()
		at(Vector3(0, 0.05, -53)))   # into the arena: the Guardian wakes
	step(10, func():
		var guardian = n("Guardian")
		ok(guardian.state != guardian.State.DORMANT, "the Guardian wakes")
		guardian.take_hit(100000.0, p.global_position))
	step(90, func():
		ok(n("VaultGate").is_open, "the vault gate opens")
		at(Vector3(-1.5, 0.05, -68))
		n("SecretWall").interact(p)
		ok(state("the_barrow") == "active" and Q.current_objective("the_barrow").begins_with("Find out"), "the hidden chamber"))
	step(10, func():
		for c in n("Cultists").get_children():
			kill(c))
	step(10, func():
		n("CultNotes").interact(p)
		save_and_load("inside the barrow"))
	step(15, func():
		ok(current_scene.scene_file_path == DUNGEON, "loads back into the barrow")
		ok(n("Guardian") == null, "the Guardian stays dead")
		ok(n("SecretWall").collision_layer == 0, "the wall stays open")
		ok(n("Cultists").get_children().all(func(c): return c.state == c.State.DEAD), "the cultists stay dead")
		ok(n("CultNotes") == null, "the notes stay taken")
		n("CagedWisp").interact(p)
		pick("Open the cage.")
		DM.end()
		ok(state("the_barrow") == "completed", "4. The Barrow done")
		ok(state("what_they_made") == "active", "What They Made starts"))
	step(60, func():
		ok(current_scene.find_child("WispCompanion", false, false) != null, "the wisp follows you")
		n("VaultExit").interact(p))
	step(20, func():
		ok(current_scene.scene_file_path == LEVEL, "back outside")
		ok(current_scene.find_child("WispCompanion", false, false) != null, "the wisp comes too"))
	# --- side quests by day ----------------------------------------------------
	step(1, func():
		# The Greyfang Pack.
		say("maren"); pick("Tell me about the wolves again."); pick("I'll deal with them.")
		DM.end()
		for wolf in n("GreyfangPack").get_children():
			kill(wolf))
	step(10, func():
		say("maren"); pick("The Greyfang pack is dead.")
		ok(state("greyfang") == "completed", "The Greyfang Pack done")
		# What Riverwatch Was Founded On, now that he trusts you enough.
		ok(autoload("Companions").approval["brannoc"] >= 10, "Brannoc's approval by now", autoload("Companions").approval)
		say("companion_brannoc"); pick("Your father's story"); pick("Then let's go and read it.")
		say("companion_brannoc"); pick("I read the roll in the barrow."); pick("The truth")
		ok(state("brannoc_founded") == "completed", "What Riverwatch Was Founded On done")
		say("companion_brannoc"); pick("Go home.")
		DM.end()
		# The Lost Wagon.
		n("LostWagon").interact(p); pick("Look for tracks.")
		say("jory_caged")
		var door = n("BanditCage/CageDoor")
		for i in door.tries_needed:
			door.interact(p)
		say("jory_caged")
		DM.end()
		n("BanditChest").interact(p)
		say("jory"); pick("Take it. Get it home.")
		ok(state("lost_wagon") == "completed", "The Lost Wagon done")
		# Licence to Burn.
		say("brannoc"); pick("Any other work for the garrison?"); pick("I'll find her.")
		say("zora"); pick("What do you know"); pick("The garrison wants you arrested."); pick("Teach me something")
		say("brannoc"); pick("I never found her.")
		ok(state("licence_to_burn") == "completed", "Licence to Burn done")
		# Zora comes along from here.
		say("zora"); pick("Would you ever leave this place?")
		say("zora"); pick("Come with me.")
		ok(autoload("Companions").active() == "zora", "Zora joins you")
		# The Merciful (Brannoc's lead, with the bandits): let them go.
		say("halina"); pick("What are you doing to the wisps?"); pick("Go in peace.")
		DM.end()
		ok(state("the_merciful") == "completed", "The Merciful done")
		# Readings: get the glass; Silent Shrine: start it.
		say("aurel"); pick("I'll do it.")
		DM.end()
		n("RoadsideShrine").interact(p); pick("Read the inscription"))
	step(1, func(): save_and_load("after the day's side quests"))
	# --- nights: readings, wisps, the shrine, and quest 5 ----------------------
	step(15, func():
		ok(current_scene.find_child("WispCompanion", false, false) != null, "the wisp is still with you after loading")
		clock.advance(clock.hours_until(22.0))
		n("ReadingStone").interact(p))
	step(30, func():
		# A wisp at the stones, for the shrine.
		var wisps: Array = n("StoneWisps").get_children()
		ok(wisps.size() > 0, "wisps at the stones at night")
		if wisps.size() > 0:
			kill(wisps[0]))
	step(10, func():
		var drops: Array = current_scene.get_children().filter(func(c): return c.get("item_id") == "wisp_essence")
		ok(drops.size() == 1, "a wisp essence dropped")
		for drop in drops:
			drop.interact(p)
		n("RoadsideShrine").interact(p); pick("Offer the Wisp Essence.")
		DM.end()
		n("RoadsideShrine").interact(p)
		ok(state("silent_shrine") == "completed", "Silent Shrine done")
		for night in 2:
			clock.advance(clock.hours_until(12.0))   # through the day to the next night
			clock.advance(clock.hours_until(22.0))
			n("ReadingStone").interact(p)
		say("aurel"); pick("North.")
		ok(state("readings") == "completed", "Readings Under the Wanderer done")
		# Her Teacher's Notebook: bought back from Inquisitor Hale.
		ok(autoload("Companions").approval["zora"] >= 10, "Zora's approval by now", autoload("Companions").approval)
		say("companion_zora"); pick("You said the Order burned your teacher."); pick("I'll get it.")
		ok(I.gold >= 100, "gold for the lamp fund", I.gold)
		say("inquisitor"); pick("You carry a hedge-witch's notebook."); pick("(Donate 100 gold.)")
		say("companion_zora"); pick("I have Ilse's notebook.")
		ok(state("zora_notebook") == "completed", "Her Teacher's Notebook done")
		DM.end()
		# The Hollow Oak.
		at(Vector3(22, 0.05, -38)))
	step(10, func():
		ok(GS.has_flag("ritual_started"), "the ritual at night")
		at(Vector3(22, 0.05, -45.5)))
	step(10, func():
		var first = n("TheFirst")
		ok(first.state != first.State.DORMANT, "The First wakes")
		for c in n("RitualCultists").get_children():
			kill(c)
		first.take_hit(100000.0, p.global_position))
	step(30, func():
		ok(GS.has_flag("first_slain"), "The First is dead")
		n("RitualAltar").interact(p)
		say("maren"); pick("(Show her the letter"); pick("It followed me out of the barrow."); pick("What do I do now?")
		DM.end()
		ok(state("what_they_made") == "completed", "5. What They Made done: the end")
		ok(autoload("Openings").card_visible(), "the closing card"))
	# --- everything, and it all survives one last load ---------------------------
	step(1, func():
		for id in Q.quests.keys().filter(func(q): return Q.quests[q].get("region", "") == ""):   # the Vale's (other regions have their own tests)
			ok(state(id) == "completed", "all quests: %s completed" % id)
		notices = []
		save_and_load("the end"))
	step(15, func():
		for id in Q.quests.keys().filter(func(q): return Q.quests[q].get("region", "") == ""):   # the Vale's (other regions have their own tests)
			ok(state(id) == "completed", "after loading: %s completed" % id)
		ok(notices.is_empty(), "no quest notices from loading", notices)
		ok(n("TheFirst") == null and n("FirstStream").visible, "the oak, as you left it"))


func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); Q = autoload("QuestLog"); DM = autoload("DialogueManager")
	I = autoload("Inventory"); S = autoload("SaveSystem"); clock = autoload("WorldClock")
	if notices.is_empty() and not Q.notice.is_connected(_on_notice):
		Q.notice.connect(_on_notice)
	if index >= steps.size():
		DM.end()
		S.delete_save()
		return done()
	if p == null:
		return false
	wait = steps[index][0]
	if wait > 0 and not steps[index].size() > 2:
		steps[index].append(true)   # waited; run it next time round
		return false
	steps[index][1].call()
	index += 1
	return false


func _on_notice(text: String) -> void:
	notices.append(text)
