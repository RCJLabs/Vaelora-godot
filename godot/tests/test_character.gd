extends "res://tests/test_base.gd"
# Character creation results: each background's attributes, skills, gear, gold,
# reputation and spells; an orc soldier with traits, Hardcore, both powers, perks,
# level-ups and attribute points; all of it through a save and load.
var f := 0
var started := false
var C; var A; var I; var S; var R; var SB
func player(): return get_first_node_in_group("player")
func key(k: Key) -> void:
	var e := InputEventKey.new(); e.keycode = k; e.physical_keycode = k; e.pressed = true
	Input.parse_input_event(e)
	var r := InputEventKey.new(); r.keycode = k; r.physical_keycode = k; r.pressed = false
	Input.parse_input_event(r)
func attrs() -> String:
	return " ".join(A.ATTRIBUTES.keys().map(func(id): return "%s%d" % [A.ATTRIBUTES[id]["short"], A.value(id)]))

# background -> [attributes, [1H, ATH, DES, RES], gear, gold, riverwatch, spells]
const BACKGROUNDS := {
	"soldier": ["STR11 END11 AGI10 INT10 WIL11 PRE12", [20, 20, 15, 15], ["iron_sword", "leather_cuirass", "leather_boots", "iron_helmet"], 20, 10, ["healing"]],
	"scholar": ["STR10 END10 AGI10 INT12 WIL11 PRE12", [15, 15, 20, 20], ["hunting_dagger", "leather_boots"], 40, 0, ["healing", "flames", "firebolt", "candlelight"]],
	"outlaw": ["STR10 END10 AGI11 INT10 WIL11 PRE13", [20, 20, 15, 15], ["hunting_dagger", "leather_cuirass", "leather_boots"], 60, -15, ["healing"]],
	"hunter": ["STR10 END11 AGI11 INT10 WIL11 PRE12", [15, 25, 15, 15], ["hunting_bow", "leather_cuirass", "leather_boots"], 25, 0, ["healing"]],
	"acolyte": ["STR10 END10 AGI10 INT10 WIL12 PRE13", [15, 15, 15, 25], ["iron_sword", "leather_boots"], 15, 0, ["healing", "healing_ward", "mending"]],
	"merchant": ["STR10 END10 AGI10 INT10 WIL11 PRE14", [15, 15, 15, 15], ["iron_sword", "leather_cuirass", "leather_boots"], 150, 5, ["healing"]],
}

func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		C = autoload("Character"); A = autoload("Attributes"); I = autoload("Inventory"); S = autoload("Skills"); R = autoload("Reputation"); SB = autoload("Spellbook")
		autoload("SaveSystem").delete_save()
		ok(C.backgrounds.keys() == BACKGROUNDS.keys(), "the six backgrounds", C.backgrounds.keys())
		for bg in C.backgrounds:
			if not BACKGROUNDS.has(bg): continue
			var want: Array = BACKGROUNDS[bg]
			C.create(load("res://races/human.tres"), "Test", bg, [], {}, {})
			ok(attrs() == want[0], "%s attributes" % bg, attrs())
			var skills := [S.levels["one_handed"], S.levels["athletics"], S.levels["destruction"], S.levels["restoration"]]
			ok(skills == want[1], "%s skills (1H ATH DES RES)" % bg, skills)
			ok(I.equipped.values() == want[2], "%s gear" % bg, I.equipped.values())
			ok(I.gold == want[3], "%s gold" % bg, I.gold)
			ok(R.value("riverwatch") == want[4], "%s Riverwatch reputation" % bg, R.value("riverwatch"))
			ok(SB.known == want[5], "%s spells" % bg, SB.known)
		C.create(load("res://races/orc.tres"), "Grukka", "soldier", ["quick_learner", "thick_skinned", "strong_arm", "glass_jaw"], {"endurance": 2, "agility": 2}, {"hardcore": true})
		ok(attrs() == "STR16 END15 AGI12 INT8 WIL10 PRE9", "orc soldier with traits and 4 points", attrs())
		ok(C.traits == ["quick_learner", "thick_skinned", "strong_arm", "glass_jaw"] and C.modes["hardcore"], "traits and Hardcore kept")
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		return false
	f += 1
	var p = player()
	match f:
		2:
			near(p.stats.modifier("skill_xp"), 1.10, 0.001, "Quick Learner skill XP")
			near(p.stats.modifier("damage_taken"), 1.518, 0.001, "damage taken (0.92 x 1.1 x 1.5 Hardcore)")
			near(p.stats.modifier("damage_dealt"), 1.20, 0.001, "damage dealt")
			near(p.stats.modifier("health_regen"), 0.25, 0.001, "Hardcore health regen")
			ok([p.stats.max_health, p.stats.max_stamina, p.stats.max_magicka] == [155.0, 130.0, 60.0], "max pools", [p.stats.max_health, p.stats.max_stamina, p.stats.max_magicka])
			ok(C.powers() == ["battle_fury", "second_wind", "", ""], "orc and soldier powers (no class, nothing earned)", C.powers())
			var h = p.stats.health; p.stats.take_damage(10.0, true)
			near(h - p.stats.health, 15.18, 0.01, "10 damage over time")
		40: key(KEY_Z)
		60:
			ok(p.effects.has("battle_fury"), "Z: Battle Fury active")
			near(p.stats.modifier("damage_dealt"), 1.5, 0.001, "damage dealt in Battle Fury")
			near(p.stats.modifier("damage_taken"), 1.214, 0.001, "damage taken in Battle Fury")
			ok(p.hud.powers_label.text.begins_with("Z Battle Fury 120s"), "HUD shows the cooldown", p.hud.powers_label.text)
			key(KEY_Z)
		80:
			var last = p.hud.notices.get_children().map(func(l): return l.text).slice(-1)
			ok(last.size() == 1 and last[0].contains("isn't ready"), "Z again: not ready", last)
			p.stats.stamina = 10.0; p.stats.health = 50.0; key(KEY_X)
		100:
			near(p.stats.stamina, 60, 6, "Second Wind stamina (10 + 50, plus regen)")
			near(p.stats.health, 70, 1, "Second Wind health (50 + 20)")
		120:
			ok(C.perk_points == 1, "one perk point", C.perk_points)
			ok(C.perk_blocker("armsman_1") == "", "Armsman available")
			ok(C.perk_blocker("marathon") == "needs Athletics 30", "Marathon needs Athletics 30", C.perk_blocker("marathon"))
			C.take_perk("armsman_1")
			near(p.stats.modifier("weapon_damage_one_handed"), 1.20, 0.001, "Armsman one-handed damage")
			ok(C.perk_points == 0 and C.perk_blocker("armsman_1") == "taken", "perk point spent, Armsman taken")
			for i in 5: S.add_xp("athletics", 1000)
		140:
			ok(S.character_level == 17, "character level after 5 big skill-ups", S.character_level)
			ok(C.perk_points == 16 and C.attribute_points == 16, "perk and attribute points", [C.perk_points, C.attribute_points])
			var mh = p.stats.max_health; var hh = p.stats.health
			C.spend_attribute_point("endurance")
			near(p.stats.max_health - mh, 5, 0.01, "1 Endurance: max health")
			near(p.stats.health - hh, 5, 0.5, "1 Endurance: health")
			var ms = p.stats.max_stamina
			S.levels["athletics"] = 30; C.perk_points += 2; C.take_perk("wind_runner"); C.take_perk("marathon")
			near(p.stats.modifier("sprint_stamina"), 0.75, 0.001, "Wind Runner sprint stamina")
			near(p.stats.max_stamina - ms, 20, 0.01, "Marathon max stamina")
		160: autoload("SaveSystem").save_game("quicksave", true)   # hardcore: saving as if resting
		180: C.reset(); A.reset(load("res://races/orc.tres")); autoload("SaveSystem").load_game("quicksave")
		230:
			ok(C.player_name == "Grukka" and C.background == "soldier", "name and background after load")
			ok(C.traits == ["quick_learner", "thick_skinned", "strong_arm", "glass_jaw"], "traits after load", C.traits)
			ok(C.perks == ["armsman_1", "wind_runner", "marathon"], "perks after load", C.perks)
			ok(C.perk_points == 16 and C.attribute_points == 15, "points after load", [C.perk_points, C.attribute_points])
			ok(C.modes["hardcore"], "Hardcore after load")
			ok(C.cooldowns.has("battle_fury") and C.cooldowns.has("second_wind"), "power cooldowns after load", C.cooldowns.keys())
			ok(attrs() == "STR16 END16 AGI12 INT8 WIL10 PRE9", "attributes after load", attrs())
			var pools := [player().stats.max_health, player().stats.max_stamina, player().stats.max_magicka]
			ok(pools == [160.0, 153.0, 60.0], "max pools after load", pools)
			var describe: String = autoload("SaveSystem").describe(autoload("SaveSystem").list_saves()[0]["meta"])
			ok(describe.begins_with("Grukka (Orc Soldier), level 17  -  Test Level"), "save description", describe)
			autoload("SaveSystem").delete_save()
			return done()
	return false
