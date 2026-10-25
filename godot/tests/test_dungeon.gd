extends "res://tests/test_base.gd"
# The greybox test dungeon: dart plate, disarming, swinging blades, the lever gate,
# the Stone Guardian (wake, attacks, phase 2, death, loot) and that it all stays
# that way after saving and loading.
var f := 0
var step := 0
var wait := 0
var p
var level
var health_before := 0.0
var blade_min := 0.0
var blade_max := 0.0
var watched := 0
var g

func _initialize() -> void:
	seed(7)
	change_scene_to_file("res://levels/test_dungeon.tscn")

func n(path: String) -> Node:
	return current_scene.get_node(path)

func place(pos: Vector3, yaw_degrees: float = 0.0) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_degrees)

func _physics_process(_d: float) -> bool:
	f += 1
	if wait > 0:
		wait -= 1
		return false
	p = get_first_node_in_group("player")
	match step:
		0:
			wait = 30
		1:
			ok(p.is_on_floor(), "player starts on the floor")
			ok(n("Guardian").state == 0, "guardian starts dormant")
			ok(not n("LeverGate").is_open and not n("VaultGate").is_open, "both gates start shut")
			p.stats.max_health = 500.0; p.stats.health = 500.0
			place(Vector3(0, 0.05, -12.0))
			health_before = p.stats.health
			Input.action_press("move_forward")
			wait = 40
		2:
			Input.action_release("move_forward")
			wait = 20
		3:
			ok(n("PlateA")._rearm_left > 0.0, "walking onto plate A set it off")
			ok(p.stats.health < health_before, "darts hit the player", p.stats.health)
			# Disarming: a sure thing with chance 1, then walking over does nothing.
			place(Vector3(0.7, 0.05, -16.5))
			n("PlateB").disarm_chance = 1.0
			n("PlateB").interact(p)
			ok(n("PlateB").disarmed, "plate B disarmed")
			ok(n("PlateB").prompt == "", "a disarmed plate has no prompt")
			health_before = p.stats.health
			Input.action_press("move_forward")
			wait = 40
		4:
			Input.action_release("move_forward")
			ok(p.global_position.z < -18.0, "walked over plate B", p.global_position.z)
			near(p.stats.health, health_before, 2.0, "no darts from the disarmed plate")
			# A failed disarm sets the plate off.
			n("PlateA")._rearm_left = 0.0
			n("PlateA").disarm_chance = 0.0
			place(Vector3(0, 0.05, -12.5))
			# A try never drops below 5% (pressure_plate.gd clamps it), so a lucky success is
			# possible: undo it and try again, as a player would on a plate that's still live.
			for attempt in 10:
				n("PlateA").interact(p)
				if not n("PlateA").disarmed:
					break
				n("PlateA").disarmed = false
			ok(n("PlateA")._rearm_left > 0.0 and not n("PlateA").disarmed, "a failed disarm sets it off")
			# Blades: watch one swing for a full period.
			blade_min = 99.0; blade_max = -99.0; watched = 0
			step += 1
			return false
		5:
			var r: float = rad_to_deg(n("Blade1").rotation.z)
			blade_min = minf(blade_min, r); blade_max = maxf(blade_max, r)
			watched += 1
			if watched < 140:   # a full 2.2 s swing at 60 frames a second
				return false
			between(blade_max, 25.0, 30.5, "blade swings out to one side")
			between(blade_min, -30.5, -25.0, "and to the other")
			place(Vector3(0, 0.05, -25.5))
			health_before = p.stats.health
			wait = 150
		6:
			ok(p.stats.health <= health_before - 25.0 + 0.5, "standing under the blades hurts (>= 25)", health_before - p.stats.health)
			# Dodge invulnerability: the blade doesn't hurt while it's on.
			place(Vector3(0, 0.05, -40))
			# Levers: all three pulled is wrong; the outer two is right.
			for i in [1, 2, 3]:
				n("Lever%d" % i).interact(p)
			wait = 10
		7:
			ok(not n("LeverGate").is_open, "all three levers pulled: gate stays shut")
			n("Lever2").interact(p)
			wait = 120
		8:
			ok(n("LeverGate").is_open, "outer two pulled: gate opens")
			ok(n("LeverGate").position.y > 4.5, "gate slid up", n("LeverGate").position.y)
			# Into the arena.
			place(Vector3(0, 0.05, -51.5), 180.0)
			wait = 20
		9:
			g = n("Guardian")
			ok(g.state != 0, "walking in wakes the guardian")
			ok(not n("LeverGate").is_open, "the gate behind slams shut")
			if ok(p.hud._boss_bar != null and p.hud._boss_bar.visible, "boss health bar shows"):
				ok(p.hud._boss_bar.get_node("BossName").text == "Stone Guardian", "bar is named")
			ok(g.take_hit(10.0, p.global_position, 5.0, 5.0) == "hit", "it can be hurt once awake")
			near(g.stats.health, 390.0, 0.1, "a 10 hit does 10")
			p.effects.clear()   # dart poison would tick health down and look like a hit
			health_before = p.stats.health
			step += 1
			return false
		10:
			# Stand in front of it until it attacks (it walks over).
			if p.stats.health < health_before or f > 2400:
				ok(p.stats.health < health_before, "the guardian's attack lands", health_before - p.stats.health)
				ok(g._attack in ["slam", "sweep"], "attack was a slam or sweep", g._attack)
				step += 1
			return false
		11:
			# Wait for a slam's recovery and punish it: 1.5x damage.
			if g.state == 4 and g._attack == "slam":
				var before: float = g.stats.health
				g.take_hit(20.0, p.global_position, 5.0, 0.0)
				near(before - g.stats.health, 30.0, 0.1, "a hit during slam recovery does 1.5x")
				step += 1
			elif f > 6000:
				ok(false, "saw a slam recovery")
				step += 1
			return false
		12:
			g.take_hit(g.stats.health - g.stats.max_health * 0.5 + 1.0, p.global_position, 0.0, 0.0)
			ok(g.phase == 2, "below half health: phase 2")
			# Phase 2 slams send a shockwave.
			g._attack = "slam"
			g._strike()
			wait = 5
		13:
			ok(current_scene.find_children("*", "Node3D", false, false).any(func(c): return c.get_script() and c.get_script().resource_path.ends_with("shockwave.gd")), "phase 2 slam sends a shockwave")
			g.take_hit(9999.0, p.global_position, 0.0, 0.0)
			wait = 120
		14:
			ok(g.state == 6, "guardian dead")
			ok(n("LeverGate").is_open and n("VaultGate").is_open, "both gates open again")
			ok(not p.hud._boss_bar.visible, "boss bar hidden")
			var heart = current_scene.find_children("*", "StaticBody3D", false, false).filter(func(c): return c.get("item_id") == "guardian_heart")
			ok(heart.size() == 1, "dropped a Guardian Heart")
			ok(autoload("SaveSystem").save_game("quicksave"), "saved")
			wait = 5
		15:
			autoload("SaveSystem").load_game("quicksave")
			wait = 30
		16:
			ok(current_scene.name == "TestDungeon", "reloaded the dungeon")
			ok(not current_scene.has_node("Guardian"), "the guardian stays dead")
			ok(n("LeverGate").is_open and n("VaultGate").is_open, "gates stay open after loading")
			ok(n("PlateB").disarmed, "plate B stays disarmed")
			ok(n("Lever1").on and not n("Lever2").on and n("Lever3").on, "levers keep their positions")
			n("VaultExit").interact(p)
			wait = 20
		17:
			ok(current_scene.name == "TestLevel", "the vault's exit leads outside")
			near(p.global_position.distance_to(current_scene.get_node("DungeonExit").global_position), 0.0, 0.5, "arrived at the barrow")
			return done()
	step += 1
	return false
