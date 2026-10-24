extends "res://tests/test_base.gd"
# The lore's changes to the demo (LORE.md, round four): night wisps notice a corrupted
# player from further away and come out in greater numbers; a Wisp Essence can be
# released at the stone circle's crystal, which gives Wisp's Grace (the wisps let you
# be); the schools are Ruin, Mending and Shaping; Maren mentions the old card player
# (Aeviro); Ostap sings "Hallam and the Hundred Lights"; the cult's papers name the Mercy.

var f := 0
var step := 0
var wait := 0
var p
var C
var GS
var DM
var I
var w

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func texts() -> Array:
	return DM._choices.map(func(c): return c["text"])

func pick(start: String) -> bool:
	var t := texts()
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return true
	return false

func idle_wisp_at(distance: float) -> void:
	# Due north of the player, in the open field where test_wisp duels, with its home there too.
	w.global_position = p.global_position + Vector3(0, 1.8, -distance)
	w.home = w.global_position
	w.velocity = Vector3.ZERO
	w.state = w.State.IDLE

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	C = autoload("Corruption"); GS = autoload("GameState"); DM = autoload("DialogueManager"); I = autoload("Inventory")
	match step:
		0:
			autoload("WorldClock").hour = 12.0   # no spawned wisps by day
			for i in [1, 2, 3]: current_scene.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			for b in current_scene.get_node("BanditCamp").get_children(): b.set_physics_process(false)
			wait = 5
		1:
			# The schools' new names (the ids stay).
			var S = autoload("Skills")
			ok(S.SKILLS["destruction"]["name"] == "Ruin" and S.SKILLS["restoration"]["name"] == "Mending" and S.SKILLS["alteration"]["name"] == "Shaping", "schools renamed: Ruin, Mending, Shaping")
			# Corruption's pull on wisps.
			ok(C.wisp_aggro_scale() == 1.0 and C.extra_wisps() == 0, "clean: wisps as usual")
			C.value = 55.0
			ok(C.wisp_aggro_scale() == 1.5 and C.extra_wisps() == 1, "Stained: noticed from 1.5x as far, one extra wisp", [C.wisp_aggro_scale(), C.extra_wisps()])
			var spawner = current_scene.get_node("StoneWisps")
			spawner._spawn()
			ok(spawner.get_child_count() == spawner.count + 1, "an extra wisp comes out", spawner.get_child_count())
			for child in spawner.get_children(): child.free()
			C.value = 0.0
			# One wisp, 18 m away: past its usual 16 m.
			p.global_position = Vector3(-30, 0.05, 18)
			w = load("res://enemies/wisp.tscn").instantiate()
			current_scene.add_child(w)
			idle_wisp_at(18.0)
			wait = 20
		2:
			ok(w.state == w.State.IDLE, "clean player at 18 m: the wisp doesn't notice", w.State.keys()[w.state])
			C.value = 25.0   # Touched: 16 x 1.25 = 20 m
			idle_wisp_at(18.0)
			wait = 20
		3:
			ok(w.state != w.State.IDLE, "Touched player at 18 m: it comes for you", w.State.keys()[w.state])
			ok(GS.has_flag("hint_wisps_corruption"), "and the hint explains why")
			# Wisp's Grace: even Hollowing, even close, they let you be.
			C.value = 85.0
			p.effects.apply("wisp_grace")
			idle_wisp_at(8.0)
			wait = 30
		4:
			ok(w.state == w.State.IDLE, "with Wisp's Grace, a wisp at 8 m lets you be", w.State.keys()[w.state])
			p.effects.remove("wisp_grace")
			w.queue_free()
			C.value = 0.0
			# Releasing an essence at the crystal.
			var crystal = current_scene.find_children("*", "StaticBody3D", true, false).filter(func(n): return n.has_method("_can_release"))[0]
			autoload("Spellbook").learn("flames")
			ok(crystal.prompt == "Touch the crystal", "no essence: the usual prompt", crystal.prompt)
			GS.set_flag("touched_crystal")
			I.add("wisp_essence", 2)
			ok(crystal.prompt == "Release a Wisp Essence", "carrying essence: release it", crystal.prompt)
			var regen: float = p.stats.modifier("health_regen")
			crystal.interact(p)
			ok(I.count("wisp_essence") == 1, "one essence released")
			ok(p.effects.has("wisp_grace") and GS.has_flag("released_wisp"), "Wisp's Grace, and it's remembered")
			near(p.stats.modifier("health_regen"), regen * 1.5, 0.001, "the grace heals a little faster")
			ok(p.hud.message_label.text.contains("Wisp's Grace"), "and says so", p.hud.message_label.text)
			ok(C.value == 0.0, "releasing doesn't corrupt")
			ok(load("res://items/wisp_essence.tres").description.contains("would let it go"), "the essence's description mentions it")
			# Maren and the old card player.
			GS.set_flag("met_maren")
			DM.start("res://dialogue/maren.json", "maren")
			ok(pick("Who else comes up this road?"), "Maren: who else comes up the road", texts())
			ok(DM.line_label.text.contains("small-folk card player"), "the old card player", DM.line_label.text)
			DM.end()
			DM.start("res://dialogue/maren.json", "maren")
			ok(not texts().has("Who else comes up this road?"), "asked once")
			DM.end()
			# Ostap's song.
			DM.start("res://dialogue/ostap.json", "ostap")
			ok(DM.line_label.text.contains("humming"), "Ostap was humming")
			ok(pick("What was that you were singing?"), "ask about the song", texts())
			ok(DM.line_label.text.contains("Hallam hunted the lights through a hundred nights"), "a verse of Hallam and the Hundred Lights", DM.line_label.text)
			DM.end()
			# The Mercy, by name.
			ok(load("res://items/cult_notes.tres").description.contains("THE MERCY"), "the cult's notes name the Mercy")
			ok(load("res://items/cult_letter.tres").description.contains("the Mercy"), "and so does the letter")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
