extends "res://tests/test_base.gd"
# Mantling and vaulting: ledges of 1.0 / 1.8 m, too-high walls, fence vaults, ledge grabs, stamina cost.
var f := 0
var steps := []
var wait := 0
var p; var level; var maxy := 0.0
var finished := false
func add(k: int, cb: Callable) -> void: steps.append([k, cb])
func box(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new(); var c := CollisionShape3D.new(); var sh := BoxShape3D.new(); sh.size = size; c.shape = sh; b.add_child(c)
	level.add_child(b); b.global_position = pos
func place(x: float, z: float) -> void:
	p.global_position = Vector3(x, 0, z); p.rotation.y = 0; p.velocity = Vector3.ZERO; p.stats.stamina = p.stats.max_stamina
func _initialize() -> void:
	level = load("res://levels/test_level.tscn").instantiate(); root.add_child(level); current_scene = level
func _physics_process(_d: float) -> bool:
	f += 1
	if p: maxy = maxf(maxy, p.global_position.y)
	if f == 3:
		p = level.get_node("Player")
		for i in [1, 2, 3]: level.get_node("GreyfangPack/Wolf%d" % i).set_physics_process(false)
		# test course far from everything: ledges of 1.0, 1.8, 2.5 m, a thin 0.95 m fence, and a 2.4 m ledge to grab mid-jump
		box(Vector3(30, 0.5, 30), Vector3(3, 1.0, 3))
		box(Vector3(36, 0.9, 30), Vector3(3, 1.8, 3))
		box(Vector3(42, 1.25, 30), Vector3(3, 2.5, 3))
		box(Vector3(48, 0.475, 30), Vector3(3, 0.95, 0.12))
		box(Vector3(54, 1.2, 30), Vector3(3, 2.4, 3))
		var ledge = p.traversal
		add(5, func(): place(30, 32.2); near(ledge.find_ledge().get("height", -1.0), 1.0, 0.02, "1.0 m block: ledge found"); Input.action_press("jump"))
		add(2, func(): Input.action_release("jump"))
		add(40, func(): near(p.global_position.y, 1.0, 0.05, "mantled onto the 1.0 m block"); ok(p.is_on_floor(), "standing on the 1.0 m block"))
		add(5, func(): place(36, 32.2); near(ledge.find_ledge().get("height", -1.0), 1.8, 0.02, "1.8 m block: ledge found"); Input.action_press("jump"))
		add(2, func(): Input.action_release("jump"))
		add(40, func(): near(p.global_position.y, 1.8, 0.05, "mantled onto the 1.8 m block"); ok(p.is_on_floor(), "standing on the 1.8 m block"); between(p.stats.max_stamina - p.stats.stamina, 8.0, 12.0, "stamina spent on a mantle"))
		add(5, func(): place(42, 32.2); maxy = 0.0; ok(ledge.find_ledge().is_empty(), "2.5 m wall: no ledge", ledge.find_ledge()); Input.action_press("jump"))
		add(2, func(): Input.action_release("jump"))
		add(60, func(): between(maxy, 0.9, 1.3, "normal jump at a 2.5 m wall: peak"); near(p.global_position.y, 0.0, 0.05, "back on the ground"))
		add(5, func(): place(48, 30.75); var l = ledge.find_ledge(); near(l.get("height", -1.0), 0.95, 0.02, "fence height"); ok(l.get("deep", true) == false, "fence is thin (vault, not mantle)"); ok(l.has("landing"), "fence has a landing on the far side"); Input.action_press("jump"))
		add(2, func(): Input.action_release("jump"))
		add(40, func(): ok(p.global_position.z < 29.5, "vaulted over the fence", p.global_position.z); near(p.global_position.y, 0.0, 0.05, "landed after the vault"))
		add(5, func(): place(54, 31.2); maxy = 0.0; Input.action_press("jump"))
		add(50, func(): Input.action_release("jump"); between(p.global_position.y, 2.2, 2.6, "2.4 m ledge grabbed mid-jump and climbed"))
		add(40, func(): place(36, 32.2); p.stats.stamina = 3.0; Input.action_press("jump"))
		add(2, func(): Input.action_release("jump"))
		add(40, func(): ok(p.global_position.y < 1.5, "can't climb with 3 stamina", p.global_position.y))
		# sprint-vault the fence
		add(40, func(): place(48, 34.5); Input.action_press("move_forward"); Input.action_press("sprint"))
		add(32, func(): near(Vector2(p.velocity.x, p.velocity.z).length(), 8.0, 0.3, "sprinting at the fence"); Input.action_press("jump"))
		add(3, func(): Input.action_release("jump"); ok(p.traversal.busy, "sprint jump starts a vault"))
		add(30, func(): Input.action_release("move_forward"); Input.action_release("sprint"); ok(p.global_position.z < 29.5, "sprint vault cleared the fence", p.global_position.z); near(p.global_position.y, 0.0, 0.05, "landed after the sprint vault"))
		add(5, func(): finished = true)
	if finished: return done()
	if f < 3 or steps.is_empty(): return false
	wait += 1
	if wait >= steps[0][0]:
		wait = 0
		steps.pop_front()[1].call()
	return false
