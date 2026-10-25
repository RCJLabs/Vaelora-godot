extends "res://tests/test_base.gd"
# Lanternfast as an event: the Wanderer in the sky (levels/wanderer_moon.gd),
# lit by its phase, gone by day, a ghost on the dark night; the crowd at the
# waystation (Pim, Hettie Kettlewick, Orrin of the Mill Lane, Moss), only that
# night; Hettie's lantern cake, once; and "Hallam and the Hundred Lights" round
# the fire (props/lanternfast_song.gd), with the Passenger's last line.
var f := 0
var step := 0
var wait := 0
var p
var GS
var DM
var W
var moon
var song
var lines := []

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func texts() -> Array:
	return DM._choices.map(func(c): return c["text"])

func pick(start: String) -> bool:
	var t := texts()
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return true
	ok(false, "choice '%s' offered" % start, t)
	return false

func talk(file: String) -> String:
	if DM.is_active:
		DM.end()
	DM.start("res://dialogue/%s.json" % file, file)
	return DM.line_label.text

func _physics_process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	GS = autoload("GameState"); DM = autoload("DialogueManager"); W = autoload("WorldClock")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			moon = n("WandererMoon")
			wait = 5
		1:
			ok(moon != null, "the Wanderer is in the sky")
			# Day 1, 08:00: daytime, so it's not shown.
			ok(not moon._disc.visible, "not by day")
			# Day 4, midnight: full, and up.
			W.day = 4; W.hour = 0.0
			wait = 2
		2:
			near(W.wanderer_phase(), 0.5, 0.06, "day 4: halfway through its cycle")
			ok(moon.lit() > 0.95 and moon._disc.visible, "full, and in the sky at night", moon.lit())
			near(float(moon._disc.material_override.get_shader_parameter("phase")), W.wanderer_phase(), 0.001, "the disc is drawn at that phase")
			# Day 1, 22:00: a crescent (the dark was the evening before day 1).
			W.day = 1; W.hour = 22.0
			wait = 2
		3:
			between(moon.lit(), 0.1, 0.4, "day 1: a crescent")
			ok(not n("Lanternfast").is_present(), "no crowd on an ordinary night")
			# Lanternfast.
			W.day = 7; W.hour = 20.5
			wait = 3
		4:
			ok(GS.has_flag("lanternfast_now"), "Lanternfast")
			ok(moon.lit() < 0.02, "the Wanderer is dark: a ghost of a disc", moon.lit())
			for who in ["Pim", "Hettie", "Orrin", "Moss"]:
				ok(n("Lanternfast/" + who) != null and n("Lanternfast/" + who).is_visible_in_tree(), who + " is out tonight")
			ok(n("Lanternfast/Hettie").prompt == "Talk to Hettie Kettlewick", "prompt", n("Lanternfast/Hettie").prompt)
			# The crowd's lanterns, each people's own reason.
			ok(talk("lf_pim").contains("the lights get in"), "Pim: so the lights can't get in")
			pick("What happens if a light gets in?")
			ok(DM.line_label.text.contains("drinks your breath"), "and what they do")
			var I = autoload("Inventory")
			ok(talk("lf_hettie").contains("because it's a party"), "Hettie: because it's a party")
			ok(I.count("lantern_cake") == 1, "and a lantern cake")
			ok(talk("lf_hettie").contains("Only one each"), "only one")
			ok(I.count("lantern_cake") == 1, "really only one")
			talk("lf_orrin"); pick("Why do you?")
			ok(DM.line_label.text.contains("so the lost ones can find their way home"), "Orrin: so the lost ones can find their way home")
			talk("lf_moss"); pick("No lantern?")
			ok(DM.line_label.text.contains("We remember instead"), "Moss: no lantern, only remembering")
			DM.end()
			# The song: stand by the fire.
			song = n("Lanternfast/Song")
			p.global_position = song.global_position + Vector3(2, 0.05, 0)
			p.velocity = Vector3.ZERO
			song._left = 0.01
			wait = 3
		5:
			lines.append(p.hud.message_label.text)
			if song.verse <= 4 and lines.size() < 6:
				song._left = 0.01
				wait = 3
				return false
			ok(lines[0].begins_with("(Round the fire, they sing) When the lights came down"), "the first verse", lines[0])
			ok(lines.any(func(l): return l.contains("You should have stayed in the sky")), "Hallam's last words")
			ok(lines.back().contains("The lanterns are for finding"), "and the Passenger's last line", lines.back())
			ok(GS.has_flag("heard_hallam_sung"), "heard_hallam_sung")
			# Gone at 2:00.
			W.advance(W.hours_until(2.05))
			wait = 3
		6:
			ok(not GS.has_flag("lanternfast_now") and not n("Lanternfast").is_present(), "over: the crowd goes home")
			ok(n("Lanternfast/Song").can_process() == false, "and the singing stops")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
