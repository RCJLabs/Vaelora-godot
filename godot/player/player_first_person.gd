extends CharacterBody3D

# First-person controller for Godot 4.
# Attach to the root CharacterBody3D of player.tscn.
#
# Scene structure (origin of Player = the player's FEET):
#   Player (CharacterBody3D)        <- this script
#   ├── CollisionShape3D            CapsuleShape3D r=0.4 h=1.8, position y=0.9
#   ├── Head (Node3D)               position y=1.6, rotates up/down
#   │   └── Camera3D                Current = ON
#   │       ├── InteractRay (RayCast3D)  Target Position (0, 0, -2.5), Mask: layers 1 "world" + 4 "loot"
#   │       ├── AttackCast (ShapeCast3D) sphere r=0.45, Target (0, 0, -1.8), Mask: layer 3 "enemies"
#   │       ├── SpellCast (ShapeCast3D)  sphere r=0.5, reach set from the spell, Mask: layer 3
#   │       ├── SpellHand (Node3D)       left-hand glow orb, light, Fire + HealSparks particles
#   │       └── Weapon (Node3D)          holds the equipped weapon's held_scene; swung by _swing_weapon()
#   ├── Stats (systems/stats.gd)    Health / Stamina / Magicka
#   ├── StatusEffects               bleeding, burning... (systems/status_effects.gd)
#   └── HUD (instance of ui/hud.tscn)
#
# Controls: WASD move, Shift sprint, Space jump, mouse look, E interact,
# left-click attack, hold right-click cast spell, Q switch spell, F5 quicksave,
# F9 load the latest save, Esc pause menu.

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
## Base mouse speed; the player's own multiplier is in Settings (Esc > Settings).
@export var mouse_sensitivity: float = 0.002
@export var ground_accel: float = 40.0   # how fast you reach full speed on the ground
@export var air_accel: float = 8.0       # how much you can steer mid-air
## If the player falls below this height they get put back at the spawn point
## (and a warning is printed, because it means collision isn't working).
@export var kill_y: float = -50.0

@export_group("Melee (unarmed)")
## Fists, used when no weapon is equipped. Weapons bring their own values (items/*.tres).
@export var unarmed_damage: float = 4.0
@export var unarmed_stamina_cost: float = 5.0
@export var unarmed_cooldown: float = 0.45
@export var unarmed_reach: float = 1.3

@export_group("Stamina & falling")
@export var sprint_stamina_per_second: float = 12.0
## After running out, you can't sprint again until stamina is back to this.
@export var stamina_to_sprint_again: float = 20.0
## Landing faster than this (m/s) hurts. 9 m/s is roughly a 4 m drop.
@export var safe_fall_speed: float = 9.0
@export var fall_damage_per_speed: float = 10.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var hud: CanvasLayer = $HUD
@onready var stats: Stats = $Stats
@onready var effects: StatusEffects = $StatusEffects
@onready var attack_cast: ShapeCast3D = $Head/Camera3D/AttackCast
@onready var weapon: Node3D = $Head/Camera3D/Weapon
@onready var weapon_rest_rotation: Vector3 = weapon.rotation
@onready var spell_cast: ShapeCast3D = $Head/Camera3D/SpellCast
@onready var spell_orb: MeshInstance3D = $Head/Camera3D/SpellHand/Orb
@onready var spell_light: OmniLight3D = $Head/Camera3D/SpellHand/Light
@onready var fire_particles: GPUParticles3D = $Head/Camera3D/SpellHand/Fire
@onready var heal_particles: GPUParticles3D = $Head/Camera3D/SpellHand/HealSparks

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3
var is_dead := false
var _exhausted := false   # ran out of stamina; no sprinting until it recovers
var _attack_cooldown_left := 0.0
# Current weapon numbers (from the equipped weapon, or unarmed).
var attack_damage := 4.0
var attack_stamina_cost := 5.0
var attack_cooldown := 0.45
var attack_skill := "one_handed"
var is_casting := false
var _orb_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	_apply_race(GameState.race_data)
	hud.track_stats(stats)
	stats.died.connect(_on_died)
	stats.damaged.connect(func(amount): if amount >= 1.0: hud.flash_damage())   # not every bleed tick
	hud.track_effects(effects)
	Skills.skill_increased.connect(_on_skill_increased)
	Skills.leveled_up.connect(_on_leveled_up)
	Skills.level_bonus_spent.connect(_on_level_bonus_spent)
	Inventory.item_added.connect(_on_item_added)
	Inventory.gold_added.connect(_on_gold_added)
	Inventory.equipment_changed.connect(_apply_equipment)
	_apply_equipment()
	Spellbook.changed.connect(_on_spell_changed)
	Spellbook.learned.connect(_on_spell_learned)
	QuestLog.notice.connect(hud.notify)
	Reputation.notice.connect(hud.notify)
	_orb_material = spell_orb.mesh.surface_get_material(0).duplicate()
	spell_orb.material_override = _orb_material
	_on_spell_changed()
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	_ensure_input_actions()
	_check_collision_setup()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	var saved := SaveSystem.take_pending_player_state()
	if not saved.is_empty():
		apply_save_data(saved)
	_arrive_at_marker(SaveSystem.take_pending_marker())


func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active or is_dead:
		return   # the dialogue box owns the mouse and keys while talking

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var sensitivity := mouse_sensitivity * Settings.mouse_sensitivity
		var vertical := -1.0 if Settings.invert_y else 1.0
		rotate_y(-event.relative.x * sensitivity)                # body turns left/right
		head.rotate_x(-event.relative.y * sensitivity * vertical)  # head tilts up/down
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))

	if event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED   # this click only grabs the mouse
	elif event.is_action_pressed("attack"):
		_try_attack()
	elif event.is_action_pressed("switch_spell"):
		Spellbook.cycle()


func _physics_process(delta: float) -> void:
	_attack_cooldown_left -= delta
	if not is_on_floor():
		velocity.y -= gravity * delta

	var talking: bool = DialogueManager.is_active or is_dead

	if Input.is_action_just_pressed("jump") and is_on_floor() and not talking:
		velocity.y = jump_velocity

	var input_dir := Vector2.ZERO if talking else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	# Only drains stamina while actually moving (not when pushing against a wall).
	# From a standstill you walk for a split second, then the sprint kicks in.
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	if stats.stamina <= 0.0:
		_exhausted = true
	elif stats.stamina >= stamina_to_sprint_again:
		_exhausted = false
	var sprinting := Input.is_action_pressed("sprint") and direction != Vector3.ZERO \
			and is_on_floor() and moving and not _exhausted
	if sprinting:
		stats.use_stamina(sprint_stamina_per_second * Skills.athletics_stamina_mult() * delta)
		Skills.add_xp("athletics", Vector2(velocity.x, velocity.z).length() * delta / 5.0)   # 1 XP per 5 m
	var target_speed := (sprint_speed if sprinting else walk_speed) * stats.modifier("move_speed")
	var accel := ground_accel if is_on_floor() else air_accel

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.move_toward(direction * target_speed, accel * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	_update_casting(delta, talking)

	var was_in_air := not is_on_floor()
	var fall_speed := -velocity.y
	move_and_slide()
	if was_in_air and is_on_floor() and fall_speed > safe_fall_speed:
		stats.take_damage((fall_speed - safe_fall_speed) * fall_damage_per_speed)

	if talking:
		hud.set_prompt("")
	else:
		_update_interaction()

	if global_position.y < kill_y:
		push_warning("Player fell below kill_y. Collision is not working - turn on Debug > Visible Collision Shapes.")
		global_position = spawn_position
		velocity = Vector3.ZERO


func _try_attack() -> void:
	if _attack_cooldown_left > 0.0 or not stats.try_use_stamina(attack_stamina_cost):
		return
	_attack_cooldown_left = attack_cooldown
	_swing_weapon()
	attack_cast.force_shapecast_update()
	for i in attack_cast.get_collision_count():
		var target := attack_cast.get_collider(i)
		if target and target.has_method("take_hit"):
			target.take_hit(attack_damage * GameState.race_data.melee_damage_mult * Attributes.melee_mult()
					* Skills.one_handed_damage_mult() * stats.modifier("damage_dealt"), global_position)
			hud.flash_hit()
			Skills.add_xp(attack_skill, 3.0)
			var target_stats = target.get("stats")
			if target_stats is Stats:
				hud.show_enemy_health(target_stats)
			return   # one target per swing


# Spells are hold-to-cast: while right-click is held and there's Magicka,
# the ready spell runs every physics frame.
func _update_casting(delta: float, blocked: bool) -> void:
	var spell := Spellbook.current()
	var wants := Input.is_action_pressed("cast") and not blocked and spell != null
	is_casting = wants and stats.try_use_magicka(spell.magicka_per_second * delta)
	if is_casting:
		var power := spell.power_per_second * delta * Skills.spell_power_mult(spell.skill) \
				* Attributes.spell_mult() * stats.modifier("damage_dealt")
		match spell.effect:
			SpellData.Effect.DAMAGE_STREAM:
				_cast_damage_stream(spell, power)
			SpellData.Effect.HEAL_SELF:
				var healed := minf(power, stats.max_health - stats.health)
				stats.heal(healed)
				Skills.add_xp(spell.skill, healed / 5.0)   # 1 XP per 5 health actually restored

	fire_particles.emitting = is_casting and spell.effect == SpellData.Effect.DAMAGE_STREAM
	heal_particles.emitting = is_casting and spell.effect == SpellData.Effect.HEAL_SELF
	var glow := 2.5 + randf() * 0.8 if is_casting else 0.4   # flicker while casting
	spell_light.light_energy = lerpf(spell_light.light_energy, glow, minf(delta * 15.0, 1.0))
	spell_orb.scale = Vector3.ONE * (1.4 if is_casting else 1.0)


func _cast_damage_stream(spell: SpellData, damage: float) -> void:
	spell_cast.target_position = Vector3(0, 0, -spell.range)
	spell_cast.force_shapecast_update()
	for i in spell_cast.get_collision_count():
		var target := spell_cast.get_collider(i)
		if target and target.has_method("take_hit"):
			target.take_hit(damage, global_position, 0.0)
			if spell.applies_effect != "" and target.has_method("add_effect"):
				target.add_effect(spell.applies_effect)
			Skills.add_xp(spell.skill, damage / 5.0)   # 1 XP per 5 damage dealt
			var target_stats = target.get("stats")
			if target_stats is Stats:
				hud.show_enemy_health(target_stats)


func _on_spell_changed() -> void:
	var spell := Spellbook.current()
	spell_orb.visible = spell != null
	spell_light.visible = spell != null
	if spell:
		_orb_material.albedo_color = spell.color
		spell_light.light_color = spell.color
	hud.set_spell(spell, Spellbook.known.size())


func _on_spell_learned(spell: SpellData) -> void:
	hud.notify("Spell learned: %s" % spell.display_name)


# Weapon stats, model and armour from what's equipped (Inventory).
func _apply_equipment() -> void:
	var weapon_item := Inventory.equipped_item("main_hand")
	for child in weapon.get_children():
		weapon.remove_child(child)
		child.queue_free()
	if weapon_item:
		attack_damage = weapon_item.damage
		attack_stamina_cost = weapon_item.stamina_cost
		attack_cooldown = weapon_item.attack_cooldown
		attack_skill = weapon_item.weapon_skill
		attack_cast.target_position = Vector3(0, 0, -weapon_item.reach)
		if weapon_item.held_scene:
			weapon.add_child(weapon_item.held_scene.instantiate())
	else:
		attack_damage = unarmed_damage
		attack_stamina_cost = unarmed_stamina_cost
		attack_cooldown = unarmed_cooldown
		attack_skill = "one_handed"   # until there's a Hand-to-Hand skill
		attack_cast.target_position = Vector3(0, 0, -unarmed_reach)
	stats.armor_rating = Inventory.armor_total()


func _swing_weapon() -> void:
	# Chop: from raised (rest pose) down and across, then back.
	var tween := create_tween()
	tween.tween_property(weapon, "rotation", weapon_rest_rotation + Vector3(deg_to_rad(-80), deg_to_rad(30), 0), 0.08)
	tween.tween_property(weapon, "rotation", weapon_rest_rotation, 0.25)


func _apply_settings() -> void:
	camera.fov = Settings.fov


func _on_skill_increased(skill_id: String, new_level: int) -> void:
	hud.notify("%s increased to %d" % [Skills.SKILLS[skill_id]["name"], new_level])


func _on_leveled_up(new_level: int) -> void:
	hud.notify("Level %d!  Press Tab to choose a bonus." % new_level)


func _on_level_bonus_spent(stat: String, amount: int) -> void:
	stats.set("max_" + stat, stats.get("max_" + stat) + amount)
	stats.set(stat, stats.get(stat) + amount)   # the new points arrive full
	stats.changed.emit()


func _on_item_added(item: ItemData, amount: int) -> void:
	hud.notify("%s added" % item.display_name if amount == 1 else "%s (%d) added" % [item.display_name, amount])


func _on_gold_added(amount: int) -> void:
	hud.notify("%d gold %s" % [absi(amount), "added" if amount > 0 else "removed"])


func _on_died() -> void:
	is_dead = true
	hud.set_prompt("")
	show_message("You have died.")
	await get_tree().create_timer(2.5).timeout
	if SaveSystem.has_save():
		SaveSystem.load_game()   # like Skyrim: back to your last save
	else:
		global_position = spawn_position
		velocity = Vector3.ZERO
		effects.clear()
		stats.refill()
		is_dead = false


func get_save_data() -> Dictionary:
	return {
		"position": [global_position.x, global_position.y, global_position.z],
		"yaw": rotation.y,
		"pitch": head.rotation.x,
		"health": stats.health,
		"stamina": stats.stamina,
		"magicka": stats.magicka,
		"effects": effects.to_array(),
	}


func apply_save_data(data: Dictionary) -> void:
	if data.has("position"):   # travelling between locations leaves it out
		var p: Array = data["position"]
		global_position = Vector3(p[0], p[1], p[2])
		rotation.y = data["yaw"]
		head.rotation.x = data["pitch"]
	stats.health = data["health"]
	stats.stamina = data["stamina"]
	stats.magicka = data["magicka"]
	effects.from_array(data.get("effects", []))
	stats.changed.emit()


# After going through a location door: stand at the named Marker3D in this level.
func _arrive_at_marker(marker_name: String) -> void:
	if marker_name == "" or owner == null:
		return
	var marker := owner.find_child(marker_name, true, false) as Node3D
	if marker == null:
		push_warning("No Marker3D called '%s' in this level - staying at the default spawn." % marker_name)
		return
	global_position = marker.global_position
	rotation.y = marker.global_rotation.y
	head.rotation.x = 0.0
	spawn_position = global_position


# Race modifiers from res://races/*.tres (chosen on the character creation screen).
func _apply_race(race: RaceData) -> void:
	walk_speed *= race.move_speed_mult * Attributes.move_speed_mult()
	sprint_speed *= race.move_speed_mult * Attributes.move_speed_mult()
	# Jump height grows with the square of jump speed, so take the square root.
	jump_velocity *= sqrt(race.jump_height_mult)
	stats.setup(race.health + Skills.bonus["health"] + Attributes.health_bonus(),
			race.stamina + Skills.bonus["stamina"] + Attributes.stamina_bonus(),
			race.magicka + Skills.bonus["magicka"] + Attributes.magicka_bonus())
	stats.stamina_regen *= Attributes.stamina_regen_mult()
	stats.magicka_regen *= Attributes.magicka_regen_mult()


# Whatever the crosshair points at within reach: if it has an `interact(player)`
# method it's usable. Its optional `prompt` property is shown on screen.
func _update_interaction() -> void:
	var target: Object = interact_ray.get_collider() if interact_ray.is_colliding() else null
	if target == null or not target.has_method("interact"):
		hud.set_prompt("")
		return

	var prompt = target.get("prompt")
	hud.set_prompt("[E] %s" % (prompt if prompt else "Use"))
	if Input.is_action_just_pressed("interact"):
		target.interact(self)


func show_message(text: String) -> void:
	hud.show_message(text)


# Prints a clear error for the most common "falls through the floor" mistakes.
func _check_collision_setup() -> void:
	var found_shape := false
	for child in get_children():
		if child is CollisionShape3D:
			if child.shape == null:
				push_error("Player: CollisionShape3D '%s' has no Shape. Inspector > Shape > New CapsuleShape3D." % child.name)
			elif child.disabled:
				push_error("Player: CollisionShape3D '%s' is Disabled. Untick Disabled in the Inspector." % child.name)
			else:
				found_shape = true
	if not found_shape:
		push_error("Player: no working CollisionShape3D as a DIRECT child of the CharacterBody3D.")
	if collision_mask == 0:
		push_error("Player: Collision > Mask is empty, so it can't collide with anything. Tick layer 1.")


# Adds default key bindings if they are missing from Project Settings > Input Map,
# so the script works even when copied into a fresh project.
func _ensure_input_actions() -> void:
	var defaults := {
		"move_forward": KEY_W, "move_back": KEY_S,
		"move_left": KEY_A, "move_right": KEY_D,
		"jump": KEY_SPACE, "sprint": KEY_SHIFT, "interact": KEY_E,
		"quicksave": KEY_F5, "quickload": KEY_F9,
	}
	for action in defaults:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var key_event := InputEventKey.new()
			key_event.physical_keycode = defaults[action]
			InputMap.action_add_event(action, key_event)
	if not InputMap.has_action("attack"):
		InputMap.add_action("attack")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack", click)
