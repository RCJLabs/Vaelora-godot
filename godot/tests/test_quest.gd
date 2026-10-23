extends "res://tests/test_base.gd"
# The Waking Stones quest end to end: talk, journal, crystal, three shards, an ending, save/load.
# Argument: the ending, "riverwatch" (give the shards to Brannoc) or "stones" (return them to the crystal).
var f := 0
var started := false
var ending := "riverwatch"
var DM; var QL; var I
var notices_seen := []

func player(): return get_first_node_in_group("player")

func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)

func look_at_point(target: Vector3, dist: float) -> void:
	var p = player()
	p.global_position = Vector3(target.x, 0, target.z + dist); p.velocity = Vector3.ZERO
	p.rotation.y = 0
	p.get_node("Head").rotation.x = atan2(target.y - 1.6, dist)

func choices() -> Array: return DM.choices_box.get_children().map(func(b): return b.text)

func pick(text_start: String) -> void:
	var c = choices()
	for i in c.size():
		if c[i].substr(3).begins_with(text_start):
			DM.choose(i); return
	ok(false, "choice '%s' offered" % text_start, c)

func state(id: String) -> String: return QL.status(id)["state"]
func objectives_done(id: String) -> Array: return QL.status(id)["objectives"].map(func(o): return o["done"])

func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		DM = autoload("DialogueManager"); QL = autoload("QuestLog"); I = autoload("Inventory")
		ending = arg("riverwatch")
		autoload("SaveSystem").delete_save()
		QL.notice.connect(func(t): notices_seen.append(t))
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		return false
	f += 1
	var p = player()
	match f:
		5:
			ok(state("waking_stones") == "hidden", "quest hidden before talking", state("waking_stones"))
			ok(objectives_done("waking_stones") == [false, false, false], "three objectives, none done")
		10: look_at_point(Vector3(-6, 1.2, -3), 2.0)
		14: ok(p.hud.prompt_label.text == "[E] Talk to Brannoc", "talk prompt", p.hud.prompt_label.text); key(KEY_E)
		18:
			ok(DM.line_label.text.begins_with("Easy - you're no bandit."), "Brannoc's greeting", DM.line_label.text.substr(0, 50))
			pick("I'll look into it")
		22:
			pick("I'll be back")
			ok("Quest started: The Waking Stones" in notices_seen, "quest started notice", notices_seen); notices_seen = []
		26: key(KEY_J)
		30:
			var m = autoload("CharacterMenu")
			ok(m.is_open and m.tabs.current_tab == 3, "J opens the journal tab", [m.is_open, m.tabs.current_tab])
			ok(m.quest_list.item_count == 1 and m.quest_list.get_item_text(0) == "The Waking Stones", "journal lists the quest")
			ok(m.get_node("%QuestObjectives").text.count("[  ]") == 3, "journal shows three open objectives", m.get_node("%QuestObjectives").text)
			key(KEY_J)
		34: ok(not autoload("CharacterMenu").is_open, "J again closes the journal"); look_at_point(Vector3(-11, 1.55, -9), 2.0)
		38: key(KEY_E)
		42: ok(objectives_done("waking_stones")[0], "crystal objective done", notices_seen); notices_seen = []
		44: look_at_point(Vector3(-17.5, 0.13, -5.0), 1.5)
		48: ok(p.hud.prompt_label.text == "[E] Take Rune Shard", "shard prompt", p.hud.prompt_label.text); key(KEY_E)
		52: look_at_point(Vector3(-5.5, 0.13, -14.5), 1.5)
		56: key(KEY_E)
		60: look_at_point(Vector3(-14.0, 0.13, -16.5), 1.5)
		64: key(KEY_E)
		68:
			ok(I.count("rune_shard") == 3, "picked up three shards", I.count("rune_shard"))
			ok(objectives_done("waking_stones") == [true, true, false], "shard objective done", objectives_done("waking_stones"))
			notices_seen = []; look_at_point(Vector3(-6, 1.2, -3), 2.0)
		72: key(KEY_E)
		76: pick("I found three")
		80:
			ok(choices().size() == 4, "four ways to decide", choices())
			pick("Take them" if ending == "riverwatch" else "They should go back")
		84:
			if ending == "riverwatch":
				ok(DM.line_label.text.begins_with("Sixty gold"), "Riverwatch ending line", DM.line_label.text.substr(0, 45))
				ok(I.gold == 60 and I.count("rune_shard") == 0, "paid 60 gold, shards handed over", [I.gold, I.count("rune_shard")])
			else:
				ok(DM.line_label.text.begins_with("Then put them back yourself"), "stones ending line", DM.line_label.text.substr(0, 45))
				ok(I.gold == 0 and I.count("rune_shard") == 3, "no gold, shards kept", [I.gold, I.count("rune_shard")])
			DM.choose(0)
		88:
			if ending == "riverwatch":
				ok(state("waking_stones") == "completed", "quest completed", state("waking_stones"))
				ok(QL.status("waking_stones")["outcome"].begins_with("I gave the shards to Brannoc"), "Riverwatch outcome in the journal")
			else:
				ok(state("waking_stones") == "active", "quest still active", state("waking_stones"))
				ok(objectives_done("waking_stones") == [true, true, true, false], "new objective: return the shards", objectives_done("waking_stones"))
			notices_seen = []
		90:
			if ending == "stones":
				look_at_point(Vector3(-11, 1.55, -9), 2.0)
		94:
			if ending == "stones":
				near(p.stats.max_magicka, 100.0, 0.5, "max magicka before the crystal"); key(KEY_E)
		98:
			if ending == "stones":
				near(p.stats.max_magicka, 110.0, 0.5, "crystal gives +10 max magicka")
				ok(I.count("rune_shard") == 0, "shards returned")
				near(current_scene.get_node("StoneCircle/Crystal").base_light_energy, 3.0, 0.05, "crystal glows brighter")
				ok(state("waking_stones") == "completed", "quest completed", state("waking_stones"))
				ok(QL.status("waking_stones")["outcome"].begins_with("I returned the shards to the stones"), "stones outcome in the journal")
			notices_seen = []
		102: key(KEY_F5)
		106: key(KEY_F9)
		120:
			ok(notices_seen.is_empty(), "no repeated notices after reload", notices_seen)
			ok(state("waking_stones") == "completed", "still completed after reload")
			if ending == "stones":
				near(player().stats.max_magicka, 110.0, 0.5, "max magicka bonus kept after reload")
				near(current_scene.get_node("StoneCircle/Crystal").base_light_energy, 3.0, 0.05, "crystal still bright after reload")
		122: look_at_point(Vector3(-6, 1.2, -3), 2.0)
		126: key(KEY_E)
		130:
			var expected := "The scholars are beside themselves." if ending == "riverwatch" else "The circle's light is steadier now."
			ok(DM.line_label.text.begins_with(expected), "Brannoc reacts to the ending", DM.line_label.text)
			autoload("SaveSystem").delete_save()
			return done()
	return false
