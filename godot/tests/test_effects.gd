extends "res://tests/test_base.gd"
# Status effects: stacking bleed, armour vs damage over time, poison modifiers, effects saved, Flames burning, bleed chance.
var f := 0
var started := false
var p; var w
var h_flames := 0.0

func visible_effects() -> Array:
	return p.hud.effects_row.get_children().filter(func(l): return l.visible).map(func(l): return l.text)

func _physics_process(_d: float) -> bool:
	if not started:
		started = true
		autoload("SaveSystem").delete_save()
		var level = load("res://levels/test_level.tscn").instantiate()
		root.add_child(level); current_scene = level
		return false
	f += 1
	if f == 2:
		p = get_first_node_in_group("player"); w = current_scene.get_node("GreyfangPack/Wolf1")
		for x in current_scene.get_node("GreyfangPack").get_children(): x.aggro_range = 0.0
	match f:
		10:
			p.effects.apply("bleeding"); p.effects.apply("bleeding")
			ok(p.effects.stacks("bleeding") == 2, "bleeding stacks to 2")
			ok(visible_effects().size() == 1 and visible_effects()[0].begins_with("Bleeding x2"), "HUD shows Bleeding x2", visible_effects())
		70: between(p.stats.health, 95.0, 99.5, "health after 1 s of bleeding x2")
		80:
			p.stats.armor_rating = 25.0; var h = p.stats.health
			p.stats.take_damage(10.0); near(h - p.stats.health, 8.0, 0.05, "hit of 10 through 25 armour")
			h = p.stats.health; p.stats.take_damage(10.0, true); near(h - p.stats.health, 10.0, 0.05, "10 over-time damage ignores armour")
			p.stats.armor_rating = 0.0
		90:
			p.effects.apply("poisoned")
			near(p.stats.modifier("health_regen"), 0.5, 0.01, "poison halves health regen")
			near(p.stats.modifier("stamina_regen"), 0.5, 0.01, "poison halves stamina regen")
			ok(visible_effects().size() == 2 and visible_effects()[1].begins_with("Poisoned"), "HUD shows both effects", visible_effects())
		100: autoload("SaveSystem").save_game("quicksave")
		110: p.effects.clear(); autoload("SaveSystem").load_game("quicksave")
		125:
			p = get_first_node_in_group("player")
			ok(p.effects.has("bleeding") and p.effects.has("poisoned"), "effects survive save/load", p.effects.active.keys())
			p.effects.clear()
		130:
			w = current_scene.get_node("GreyfangPack/Wolf1")
			for x in current_scene.get_node("GreyfangPack").get_children(): x.aggro_range = 0.0
			autoload("Spellbook").learn("flames"); autoload("Spellbook").select("flames")
			p.global_position = w.global_position + Vector3(0, 0, 3.5); p.rotation.y = 0; p.get_node("Head").rotation.x = deg_to_rad(-12)
		135: Input.action_press("cast")
		160:
			Input.action_release("cast")
			ok(w.effects.has("burning"), "Flames sets the wolf burning")
			h_flames = w.stats.health
		220:
			ok(w.effects.has("burning"), "still burning 1 s after Flames stopped")
			ok(w.stats.health < h_flames - 1.0, "the burn keeps hurting", [h_flames, w.stats.health])
		400: ok(not w.effects.has("burning"), "burning has worn off 4 s later")
		410:
			var bites := 0; var bleeds := 0
			for i in 400:
				p.effects.clear(); p.stats.health = p.stats.max_health; w._bite(p); bites += 1
				if p.effects.has("bleeding"): bleeds += 1
			between(100.0 * bleeds / bites, 15.0, 35.0, "bleed chance per wolf bite (%)")
			autoload("SaveSystem").delete_save()
			return done()
	return false
