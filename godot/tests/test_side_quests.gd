extends "res://tests/test_base.gd"
# The side quests, one route per run. Argument:
#   shrine          Silent Shrine: silent prayer, the inscription, wisp essence, the answer at night, the daily blessing
#   wagon_merchant  The Lost Wagon as the Merchant: the wreck, Jory caged, the lock, the strongbox, pay him double
#   wagon_keep      The Lost Wagon as anyone else: keep the strongbox
#   licence_arrest  Licence to Burn: bring Zora in (she leaves; Brannoc pays)
#   licence_teach   Licence to Burn: learn from her (she stays; no pay)
#   readings        Readings Under the Wanderer: three nights, not twice in one night, the report
#   greyfang        The Greyfang Pack's reason
const LEVEL := "res://levels/test_level.tscn"
const BACKGROUND := {"wagon_merchant": "merchant", "readings": "scholar", "shrine": "acolyte"}
var f := 0
var step := 0
var wait := 0
var mode := ""
var p
var GS
var Q
var DM
var I
var clock
var gold_before := 0

func _initialize() -> void:
	mode = arg("shrine")
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", BACKGROUND.get(mode, "soldier"), [], {}, {})
	change_scene_to_file(LEVEL)

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func texts() -> Array:
	return DM._choices.map(func(c): return c["text"])

func pick(start: String) -> void:
	var t := texts()
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return
	ok(false, "choice '%s' offered" % start, t)

func talk(file: String) -> void:
	if DM.is_active:
		DM.end()
	DM.start("res://dialogue/%s.json" % file, file)

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); Q = autoload("QuestLog"); DM = autoload("DialogueManager"); I = autoload("Inventory")
	clock = autoload("WorldClock")
	if step == 0:
		step = 1
		wait = 5
		return false
	var finished := false
	match mode:
		"shrine": finished = shrine()
		"wagon_merchant", "wagon_keep": finished = wagon()
		"licence_arrest", "licence_teach": finished = licence()
		"readings": finished = readings()
		"greyfang": finished = greyfang()
	if finished:
		DM.end()
		autoload("SaveSystem").delete_save()
		return done()
	step += 1
	return false


func shrine() -> bool:
	match step:
		1:
			var shrine = n("RoadsideShrine")
			ok(shrine.prompt == "Pray at the shrine", "shrine prompt")
			clock.advance(clock.hours_until(12.0))
			shrine.interact(p)
			ok(DM.is_active and DM.line_label.text.begins_with("A weathered stone shrine"), "the shrine's dialogue", DM.line_label.text)
			ok(Q.status("silent_shrine")["state"] == "active", "Silent Shrine starts at the shrine")
			pick("Pray.")
			ok(DM.line_label.text.begins_with("You say the old words. Nothing answers"), "silence", DM.line_label.text)
			ok(texts().any(func(t): return t.begins_with("(Acolyte)")), "the Acolyte knows a rite")
			pick("Read the inscription")
			ok(not texts().any(func(t): return t.begins_with("Offer")), "nothing to offer yet")
			DM.end()
			ok(Q.current_objective("silent_shrine").begins_with("Find light given freely"), "objective: essence", Q.current_objective("silent_shrine"))
			I.add("wisp_essence")
			shrine.interact(p)
			pick("Offer the Wisp Essence.")
			ok(GS.has_flag("shrine_rekindled") and I.count("wisp_essence") == 0, "rekindled")
			DM.end()
			wait = 100
		2:
			var shrine = n("RoadsideShrine")
			ok(shrine.candle_light.light_energy > 1.5, "the candle burns bright", shrine.candle_light.light_energy)
			# By day: a blessing, once.
			p.stats.health = 20.0
			shrine.interact(p)
			ok(not DM.is_active, "no dialogue once rekindled")
			near(p.stats.health, p.stats.max_health, 0.5, "healed")
			ok(p.effects.active.has("blessing"), "blessed")
			p.stats.health = 20.0
			shrine.interact(p)
			near(p.stats.health, 20.0, 0.5, "only once a day")
			ok(not GS.has_flag("shrine_answered"), "no answer by day")
			clock.advance(clock.hours_until(23.0))
			shrine.interact(p)
			ok(GS.has_flag("shrine_answered"), "something answers at night")
			ok(p.hud.message_label.text.contains("from somewhere above and to the north"), "the answer", p.hud.message_label.text)
			ok(Q.status("silent_shrine")["state"] == "completed", "Silent Shrine completed")
			return true
	return false


func wagon() -> bool:
	match step:
		1:
			var merchant := mode == "wagon_merchant"
			if merchant:
				GS.set_flag("wrong_things_started")   # the opening sets it
				talk("maren")
				pick("My wagon never reached Riverwatch.")
				ok(GS.has_flag("lost_wagon_started"), "Maren starts it for the Merchant")
				DM.end()
			n("LostWagon").interact(p)
			ok(DM.line_label.text.begins_with("It's yours." if merchant else "A merchant's wagon on its side"), "the wreck", DM.line_label.text)
			pick("Look for tracks.")
			DM.end()
			ok(Q.status("lost_wagon")["state"] == "active", "The Lost Wagon active")
			ok(Q.current_objective("lost_wagon").begins_with("Follow the tracks"), "objective: tracks", Q.current_objective("lost_wagon"))
			ok(n("JoryInCage/JoryCaged").collision_layer != 0 and not n("JoryAtWaystation").visible, "Jory is in the cage, not at the waystation")
			talk("jory_caged")
			ok(DM.line_label.text.begins_with("You! You're not one of them."), "Jory, caged")
			ok(texts().any(func(t): return t.begins_with("(Merchant)")) == merchant, "he knows the Merchant", texts())
			DM.end()
			var door = n("BanditCage/CageDoor")
			for i in door.tries_needed:
				door.interact(p)
			ok(GS.has_flag("bandit_cage_opened"), "the lock springs")
			talk("jory_caged")
			ok(DM.line_label.text.begins_with("The door's open."), "freed", DM.line_label.text)
			DM.end()
			wait = 3
		2:
			ok(not n("JoryInCage").visible and n("JoryInCage/JoryCaged").collision_layer == 0, "Jory leaves the cage")
			ok(n("JoryAtWaystation").visible and n("JoryAtWaystation/JoryWaystation").collision_layer != 0, "and waits at the waystation")
			ok(n("BanditChest").contents.has("strongbox"), "the strongbox is in the bandits' chest")
			n("BanditChest").interact(p)
			ok(I.count("strongbox") == 1, "took the strongbox")
			gold_before = I.gold
			talk("jory")
			if mode == "wagon_merchant":
				ok(DM.line_label.text.begins_with("You got it back!"), "Jory, to the Merchant", DM.line_label.text)
				pick("Your forty, and forty more.")
				ok(I.gold == gold_before + 70 and I.count("strongbox") == 0, "150 in the box, 80 to Jory", I.gold - gold_before)
				ok(Q.status("lost_wagon")["outcome"].contains("paid him double"), "outcome", Q.status("lost_wagon")["outcome"])
			else:
				ok(DM.line_label.text.begins_with("The strongbox! My master's"), "Jory, to a stranger", DM.line_label.text)
				var rw: int = autoload("Reputation").value("riverwatch")
				pick("Finders keepers.")
				ok(I.gold == gold_before + 150, "kept 150", I.gold - gold_before)
				ok(autoload("Reputation").value("riverwatch") == rw - 5, "word gets round Riverwatch")
				ok(Q.status("lost_wagon")["outcome"].contains("better manners"), "outcome", Q.status("lost_wagon")["outcome"])
			ok(Q.status("lost_wagon")["state"] == "completed", "The Lost Wagon completed")
			return true
	return false


func licence() -> bool:
	match step:
		1:
			GS.set_flag("met_brannoc")
			GS.set_flag("wrong_things_started")
			talk("brannoc")
			pick("Any other work for the garrison?")
			ok(GS.has_flag("licence_started"), "Brannoc's job")
			DM.end()
			ok(Q.status("licence_to_burn")["state"] == "active", "Licence to Burn active")
			ok(n("ZoraHere").visible, "Zora at her hut")
			talk("zora")
			ok(DM.line_label.text.begins_with("Another one."), "Zora", DM.line_label.text)
			pick("What do you know about what's draining")
			ok(DM.line_label.text.contains("Somebody learned at a college"), "she knows the drain's shape", DM.line_label.text)
			pick("The garrison wants you arrested.")
			var gold: int = I.gold
			if mode == "licence_arrest":
				pick("Come with me.")
				ok(GS.has_flag("zora_arrested"), "arrested")
				DM.end()
				wait = 3
			else:
				pick("Teach me something")
				ok(I.count("tome_frost_burst") == 1, "a frost tome")
				DM.end()
				wait = 3
			gold_before = gold
		2:
			ok(n("ZoraHere").visible == (mode == "licence_teach"), "Zora leaves only if arrested")
			talk("brannoc")
			ok(DM.line_label.text.begins_with("Well? The hedge-mage?"), "Brannoc asks", DM.line_label.text)
			if mode == "licence_arrest":
				pick("She came quietly.")
				ok(I.gold == gold_before + 50, "fifty for bringing her in", I.gold - gold_before)
			else:
				pick("I never found her.")
				ok(I.gold == gold_before, "no pay")
			DM.end()
			ok(Q.status("licence_to_burn")["state"] == "completed", "Licence to Burn completed")
			var outcome: String = Q.status("licence_to_burn")["outcome"]
			ok(outcome.contains("came quietly") if mode == "licence_arrest" else outcome.contains("taught me a frost spell"), "outcome", outcome)
			return true
	return false


func readings() -> bool:
	match step:
		1:
			var stone = n("ReadingStone")
			talk("aurel")
			ok(DM.line_label.text.begins_with("You'll be the one they sent"), "Aurel knows the Scholar", DM.line_label.text)
			pick("Give me the glass.")
			ok(I.count("rune_glass") == 1 and Q.status("readings")["state"] == "active", "the rune-glass, and the quest")
			DM.end()
			clock.advance(clock.hours_until(12.0))
			ok(stone.prompt == "", "no reading by day")
			for night in 3:
				clock.advance(clock.hours_until(22.0))
				ok(stone.prompt == "Take a reading", "night %d: take a reading" % (night + 1))
				stone.interact(p)
				ok(GS.has_flag("readings_%d" % (night + 1)), "reading %d" % (night + 1))
				clock.advance(3.0)   # 01:00, the same night
				ok(stone.prompt == "", "night %d: once only" % (night + 1))
			ok(p.hud.message_label.text.contains("Reading 3 of 3"), "the third reading", p.hud.message_label.text)
			ok(Q.current_objective("readings").begins_with("Bring the readings"), "objective: Aurel", Q.current_objective("readings"))
			var gold: int = I.gold
			talk("aurel")
			pick("North.")
			ok(I.gold == gold + 80 and I.count("rune_glass") == 0, "paid 80, glass returned")
			ok(texts().any(func(t): return t.begins_with("(Scholar)")), "the Scholar's line")
			DM.end()
			ok(Q.status("readings")["state"] == "completed", "Readings completed")
			return true
	return false


func greyfang() -> bool:
	match step:
		1:
			talk("maren")
			pick("Why don't people come this way?")
			ok(not texts().any(func(t): return t.begins_with("Why are they raiding")), "no reason before the main quest")
			DM.end()
			GS.set_flag("wrong_things_started")
			talk("maren")
			if texts().any(func(t): return t.begins_with("Tell me about the wolves again.")):
				pick("Tell me about the wolves again.")
			else:
				pick("Why don't people come this way?")
			pick("Why are they raiding the road at all?")
			ok(DM.line_label.text.begins_with("Hunger."), "the drain thins their prey", DM.line_label.text)
			ok(texts().any(func(t): return t.begins_with("I'll deal with them.")), "and the quest is still offered", texts())
			return true
	return false
