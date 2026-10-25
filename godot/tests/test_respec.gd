extends "res://tests/test_base.gd"
# Respec (Character.respec(), Aurel's rite): for 150 gold every perk comes back
# as a point, attributes go back to race + background + traits with every point
# you chose (creation and levels) to spend again, and the level-up bonuses come
# back too; quest-reward bonuses, skills, race and traits stay.
var f := 0
var step := 0
var wait := 0
var p
var C
var S
var A
var I
var DM

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/orc.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

func _process(_d: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	C = autoload("Character"); S = autoload("Skills"); A = autoload("Attributes"); I = autoload("Inventory"); DM = autoload("DialogueManager")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			# An Orc soldier with Strong Arm (+2 STR) who put 4 creation points into Endurance
			# (created here: the trait list isn't loaded yet in _initialize).
			C.create(load("res://races/orc.tres"), "T", "soldier", ["strong_arm"], {"endurance": 4}, {})
			wait = 5
		1:
			var base: Dictionary = A.values.duplicate()
			set_meta("endurance_before", base["endurance"])
			# Two levels: spend everything.
			for i in 2 * S.SKILL_UPS_PER_LEVEL:
				S.raise("one_handed")
			ok(S.character_level == 3, "level 3", S.character_level)
			S.spend_level_up("health"); S.spend_level_up("magicka")
			C.spend_attribute_point("strength"); C.spend_attribute_point("strength")
			S.levels["one_handed"] = 40
			C.perk_points = 3
			var perk_id: String = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == "one_handed" and not C.perk_list[k].has("requires"))[0]
			ok(C.take_perk(perk_id), "take a perk")
			S.grant_bonus("stamina", 20)   # a quest reward
			set_meta("perks", C.perks.size()); set_meta("perk_points", C.perk_points)
			set_meta("skill", S.levels["one_handed"])
			# Aurel's rite.
			I.add_gold(200)
			var gold: int = I.gold
			DM.start("res://dialogue/aurel.json", "Aurel")
			_pick("The Tide College. Do you teach?")
			_pick("Can the College undo what I've learned?")
			ok(_offered("Do it. (150 gold)"), "Aurel offers the rite for 150")
			_pick("Do it. (150 gold)")
			DM.end()
			ok(I.gold == gold - 150, "150 gold", gold - I.gold)
			ok(C.perks.is_empty() and C.perk_points == get_meta("perk_points") + get_meta("perks"), "perks come back as points", [C.perks, C.perk_points])
			var orc = load("res://races/orc.tres")
			var soldier: int = int(C.backgrounds["soldier"].get("attributes", {}).get("strength", 0))
			near(float(A.value("strength")), float(10 + int(orc.attribute_bonuses.get("strength", 0)) + soldier + 2), 0.01, "Strength: race, background and Strong Arm only")
			near(float(A.value("endurance")), float(get_meta("endurance_before") - 4), 0.01, "the 4 creation points are taken back out")
			ok(C.attribute_points == C.CREATION_ATTRIBUTE_POINTS + 2, "4 creation + 2 level points to spend", C.attribute_points)
			ok(S.unspent_level_ups == 2 and S.bonus["health"] == 0 and S.bonus["magicka"] == 0, "the level bonuses come back", [S.unspent_level_ups, S.bonus])
			ok(S.bonus["stamina"] == 20, "a quest reward stays", S.bonus["stamina"])
			ok(S.levels["one_handed"] == get_meta("skill") and C.traits == ["strong_arm"], "skills and traits stay")
			# Saved.
			S.spend_level_up("stamina")
			var data: Dictionary = S.to_dict()
			S.from_dict(data)
			ok(S.level_spent["stamina"] == 1, "level-up spends are saved (for the next respec)")
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false

func _pick(start: String) -> void:
	var t: Array = DM._choices.map(func(c): return c["text"])
	for i in t.size():
		if t[i].begins_with(start):
			DM.choose(i)
			return
	ok(false, "choice '%s' offered" % start, t)

func _offered(start: String) -> bool:
	return DM._choices.any(func(c): return c["text"].begins_with(start))
