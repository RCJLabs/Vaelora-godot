extends "res://tests/test_base.gd"
# Light and Heavy Armour (systems/armor.gd): each piece is light or heavy (shields
# neither); its armour rises 1% per skill level; being hit trains the skills you
# wear, shared by pieces; heavy pieces make sprinting cost more and sneaking
# louder. Perks: some only in armour ("when_wearing" any piece, "when_full" all
# four), checked live as you change; weightless armour; Ghost Armour, Last
# Stand, Counter-Strike; damage over time; effect durations; per-skill XP.
var f := 0
var step := 0
var wait := 0
var p
var S
var C
var I
var A

func _initialize() -> void:
	autoload("SaveSystem").delete_save()
	autoload("Character").create(load("res://races/human.tres"), "T", "soldier", [], {}, {})
	change_scene_to_file("res://levels/test_level.tscn")

func n(path: String) -> Node:
	return current_scene.get_node_or_null(path)

## Damage a hit of `raw` does after armour (and Hardcore etc.) right now.
func after_armor(raw: float) -> float:
	var ar: float = p.stats.armor_rating
	return raw * p.stats.modifier("damage_taken") * (1.0 - ar / (ar + 100.0))

func hit(raw: float) -> float:
	var before: float = p.stats.health
	p.receive_attack(raw, null, 0.0)
	return before - p.stats.health

func _physics_process(_delta: float) -> bool:
	if current_scene == null:
		return false
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	S = autoload("Skills"); C = autoload("Character"); I = autoload("Inventory"); A = autoload("Armor")
	match step:
		0:
			for i in [1, 2, 3]: n("GreyfangPack/Wolf%d" % i).set_physics_process(false)
			p.stats.health_regen = 0.0
			autoload("Inventory").unequip("head")   # a Soldier starts in the iron helmet
			wait = 5
		1:
			ok(S.SKILLS["light_armor"]["attribute"] == "agility" and S.SKILLS["heavy_armor"]["attribute"] == "endurance", "Light Armour (Agility), Heavy Armour (Endurance)")
			ok(A.kind_of(I.get_item("leather_cuirass")) == "light" and A.kind_of(I.get_item("iron_helmet")) == "heavy" and A.kind_of(I.get_item("wooden_shield")) == "", "leather is light, iron heavy, a shield neither")
			ok(I.is_equipped("leather_cuirass") and I.is_equipped("leather_boots") and A.pieces("light") == 2, "in the two light starting pieces", A.pieces("light"))
			near(p.stats.armor_rating, 26.0, 0.01, "20 + 6 armour at Light Armour 15")
			S.levels["light_armor"] = 65
			S.changed.emit()
			near(A.piece_armor(I.get_item("leather_cuirass")), 30.0, 0.01, "Light Armour 65: the cuirass gives 30")
			near(p.stats.armor_rating, 39.0, 0.01, "and the rating follows the skill")
			# Being hit trains it (half: two of four pieces), not Heavy.
			var light_xp: float = S.xp["light_armor"]; var heavy_xp: float = S.xp["heavy_armor"]
			var taken := hit(20.0)
			near(taken, after_armor(20.0), 0.01, "a hit is cut by the armour")
			ok(S.xp["light_armor"] > light_xp and S.xp["heavy_armor"] == heavy_xp, "it trains Light Armour only", [S.xp["light_armor"] - light_xp, S.xp["heavy_armor"] - heavy_xp])
			var one: float = S.xp["light_armor"] - light_xp
			C.perks.append("leather_wisdom")
			light_xp = S.xp["light_armor"]
			hit(20.0)
			near(S.xp["light_armor"] - light_xp, one * 1.25, 0.01, "Leather Wisdom: 25% faster")
			# A when_wearing perk: Quick Step, only in light armour.
			C.perks.append("quick_step")
			near(p.stats.modifier("dodge_stamina"), 0.75, 0.001, "Quick Step in light armour")
			# Second Skin: damage over time.
			C.perks.append("second_skin")
			var before: float = p.stats.health
			p.stats.take_damage(10.0, true)
			near(before - p.stats.health, 7.5, 0.01, "Second Skin: bleeding hurts 25% less (armour doesn't stop it)")
			# The heavy set.
			for id in ["iron_helmet", "iron_cuirass", "iron_gauntlets", "iron_boots"]:
				I.add(id); I.equip(id)
			ok(A.pieces("heavy") == 4 and A.is_full("heavy") and A.pieces("light") == 0, "in all heavy armour")
			near(p.stats.modifier("dodge_stamina"), 1.0, 0.001, "Quick Step stops out of light armour")
			near(A.sprint_mult(), 1.24, 0.001, "four heavy pieces: sprinting +24%")
			near(A.noise_mult(), 1.32, 0.001, "and noticed sneaking 32% further")
			var range_heavy: float = autoload("Stealth").range_mult()
			C.perks.append("steel_lungs"); C.perks.append("padded_plate")
			near(A.sprint_mult(), 1.0, 0.001, "Steel Lungs: no sprint cost")
			near(autoload("Stealth").range_mult(), range_heavy / 1.32, 0.001, "Padded Plate: quiet")
			var weight: float = I.total_weight()
			C.perks.append("conditioning")
			near(weight - I.total_weight(), 31.0, 0.01, "Conditioning: the 31 kg set weighs nothing")
			C.perks.append("well_fitted")
			near(A.piece_armor(I.get_item("iron_cuirass")), 32.0 * 1.25, 0.01, "Well Fitted: +25% in the full set")
			I.unequip("feet")
			near(A.piece_armor(I.get_item("iron_cuirass")), 32.0, 0.01, "boots off: not a full set, no bonus")
			I.equip("iron_boots")
			# Shrug It Off: harmful effects wear off twice as fast in heavy armour.
			p.effects.clear()
			p.effects.apply("bleeding")
			var plain: float = p.effects.active["bleeding"]["time_left"]
			p.effects.clear()
			C.perks.append("shrug_it_off")
			p.effects.apply("bleeding")
			near(p.effects.active["bleeding"]["time_left"], plain * 0.5, 0.01, "Shrug It Off: half as long")
			p.effects.clear()
			# Last Stand: below a quarter Health, half damage.
			C.perks.append("last_stand")
			p.stats.health = p.stats.max_health * 0.2
			near(hit(10.0), after_armor(10.0) * 0.5, 0.01, "Last Stand: half damage when low")
			p.stats.health = p.stats.max_health
			near(hit(10.0), after_armor(10.0), 0.01, "not when healthy")
			# Ghost Armour (all light): one blow in 15 s passes through.
			for id in ["leather_cap", "leather_cuirass", "leather_gloves", "leather_boots"]:
				I.add(id); I.equip(id)
			ok(A.is_full("light"), "back in all light armour")
			C.perks.append("ghost_armor")
			A.ghost_left = 0.0
			ok(p.receive_attack(10.0, null, 0.0) == "dodged" and hit(10.0) > 0.0, "Ghost Armour: the first blow passes, the next lands")
			# Counter-Strike: a dodge in light armour sets up the next hit.
			C.perks.append("counter_strike")
			p.combat._iframes_left = 0.2
			ok(p.receive_attack(10.0, null, 0.0) == "dodged" and p.combat._counter_left > 1.9, "Counter-Strike: armed by a dodge")
			# Drillmaster: per-skill XP.
			S.levels["heavy_armor"] = 15
			ok(C.perk_list["drillmaster"]["modifiers"].has("skill_xp_heavy_armor"), "Drillmaster is per-skill XP")
			# Trees, shop, menu.
			for skill in ["light_armor", "heavy_armor"]:
				var perks: Array = C.perk_list.keys().filter(func(k): return C.perk_list[k]["skill"] == skill)
				ok(perks.size() >= 20, "%s: 20+ perks" % skill, perks.size())
			var stock: Dictionary = autoload("Trade").stock("maren")
			ok(["leather_cap", "leather_gloves", "iron_cuirass", "iron_gauntlets", "iron_boots"].all(func(id): return stock.has(id)), "Maren sells both sets")
			C.perks.clear()
			autoload("SaveSystem").delete_save()
			return done()
	step += 1
	return false
