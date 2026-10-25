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
#   │       ├── AttackCast (ShapeCast3D) sphere r=0.45, reach set from the weapon, Mask: layer 3 "enemies"
#   │       ├── SpellCast (ShapeCast3D)  sphere r=0.5, reach set from the spell, Mask: layer 3
#   │       ├── SpellHand (Node3D)       left-hand glow orb, light, Fire + HealSparks particles
#   │       └── Weapon (WeaponAnimator)  holds the equipped weapon's held_scene and poses it
#   ├── Stats (systems/stats.gd)    Health / Stamina / Magicka / Poise
#   ├── Combat (player_combat.gd)   attacks, combos, block, parry, dodge, stagger
#   ├── Magic (player_magic.gd)     spellcasting: streams, bolts, areas, wards, self, dual-casting
#   ├── Traversal (player_traversal.gd)  mantling onto ledges, vaulting low obstacles
#   ├── Footsteps (player_footsteps.gd)  step sounds by surface
#   ├── View (player_view.gd)       first or third person (V); the third-person camera and body
#   ├── StatusEffects               bleeding, burning... (systems/status_effects.gd)
#   └── HUD (instance of ui/hud.tscn)
#
# Controls: WASD move, Shift sprint, Space jump, mouse look, E interact,
# left-click attack (hold for a heavy attack; bows: hold to draw), hold
# right-click for the left hand (cast the ready spell, block, shield, or aim a
# bow), Q switch spell / Block, Alt dodge, V first / third person, Z race power,
# X background power, F5 quicksave,
# F9 load the latest save, Esc pause menu.

@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var jump_velocity: float = 4.5
## Base mouse speed; the player's own multiplier is in Settings (Esc > Settings).
@export var mouse_sensitivity: float = 0.002
## Gamepad right stick: turn speed at full tilt (radians per second), times the
## same Settings multiplier. The stick is curved, so small tilts aim finely.
@export var stick_look_speed: float = 3.2
@export var ground_accel: float = 40.0   # how fast you reach full speed on the ground
@export var air_accel: float = 8.0       # how much you can steer mid-air
## If the player falls below this height they get put back at the spawn point
## (and a warning is printed, because it means collision isn't working).
@export var kill_y: float = -50.0

@export_group("Melee (unarmed)")
## Fists, used when no weapon is equipped. Weapons bring their own values (items/*.tres);
## swing timing is in player_combat.gd.
@export var unarmed_damage: float = 4.0
@export var unarmed_stamina_cost: float = 5.0
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
@onready var weapon: WeaponAnimator = $Head/Camera3D/Weapon
@onready var off_hand: WeaponAnimator = $Head/Camera3D/OffHand
@onready var combat: PlayerCombat = $Combat
@onready var magic: PlayerMagic = $Magic
@onready var traversal: PlayerTraversal = $Traversal
@onready var footsteps: PlayerFootsteps = $Footsteps
@onready var view: PlayerView = $View
@onready var spell_cast: ShapeCast3D = $Head/Camera3D/SpellCast
@onready var spell_orb: MeshInstance3D = $Head/Camera3D/SpellHand/Orb
@onready var spell_light: OmniLight3D = $Head/Camera3D/SpellHand/Light
@onready var fire_particles: GPUParticles3D = $Head/Camera3D/SpellHand/Fire
@onready var heal_particles: GPUParticles3D = $Head/Camera3D/SpellHand/HealSparks

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var spawn_position: Vector3
var is_dead := false
var sprinting_now := false   # this frame (Arms: attacks begun at a sprint)
var _exhausted := false   # ran out of stamina; no sprinting until it recovers
var _sprint_toggled := false   # Settings.toggle_sprint: sprint is latched on
var last_attacker: Node        # who last hit you (systems/defeat.gd: who beat you)
var _last_hit_at := -100000
var is_casting := false
## Crouched, sneaking (C / D-pad down toggles it): slower, lower, harder to notice
## (systems/stealth.gd). Sprinting, jumping or dodging stands you up.
var is_sneaking := false
const SNEAK_SPEED := 0.55   # of walking speed
const SNEAK_HEAD := 1.05    # camera height crouched (standing: the Head node's own height)
var _head_height := 1.6
var _camera_kick := Vector3.ZERO   # degrees, springs back to zero
var _lunge_velocity := Vector3.ZERO
var _lunge_left := 0.0
var _base: Dictionary = {}   # speeds and regen before race/attribute bonuses
var _orb_material: StandardMaterial3D


func _ready() -> void:
	add_to_group("player")
	spawn_position = global_position
	_head_height = head.position.y
	stats.permanent = Character
	_base = {"walk": walk_speed, "sprint": sprint_speed, "jump": jump_velocity,
			"stamina_regen": stats.stamina_regen, "magicka_regen": stats.magicka_regen}
	_recalculate_stats(true)
	Attributes.changed.connect(_recalculate_stats)
	Character.changed.connect(_recalculate_stats)
	Character.notice.connect(hud.notify)
	hud.track_stats(stats)
	stats.died.connect(_on_died)
	stats.damaged.connect(func(amount): if amount >= 1.0: hud.flash_damage())   # not every bleed tick
	hud.track_effects(effects)
	Skills.skill_increased.connect(_on_skill_increased)
	Skills.leveled_up.connect(_on_leveled_up)
	Skills.level_bonus_spent.connect(func(_stat, _amount): _recalculate_stats())
	Inventory.item_added.connect(_on_item_added)
	Inventory.gold_added.connect(_on_gold_added)
	Inventory.equipment_changed.connect(_apply_equipment)
	Skills.changed.connect(_update_armor)      # Light / Heavy Armour levels
	Character.changed.connect(_update_armor)   # armour perks
	Inventory.equipment_changed.connect(_update_encumbrance)   # weightless armour perks
	Inventory.changed.connect(func(): if combat.is_bow(): _on_spell_changed())   # arrow count
	Inventory.changed.connect(_update_encumbrance)
	Attributes.changed.connect(_update_encumbrance)
	_update_encumbrance.call_deferred()
	_apply_equipment()
	Spellbook.changed.connect(_on_spell_changed)
	InputHints.device_changed.connect(_on_spell_changed)   # button names in the HUD
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
	arrive_at_marker(SaveSystem.take_pending_marker())
	Openings.play(self)   # a new game: the background's first scene
	WispCompanion.ensure(self)   # the wisp freed in the barrow follows you
	var note := SaveSystem.take_pending_message()   # e.g. an old save brought up to date
	if note != "":
		show_message(note)


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
		if not is_casting and not magic.right_hand_free():   # an empty right hand casts instead
			combat.attack_pressed()
	elif event.is_action_released("attack"):
		combat.attack_released()
	elif event.is_action_pressed("crouch"):
		set_sneaking(not is_sneaking)
	elif event.is_action_pressed("dodge"):
		if not Stealth.has_perk("shadow_step"):
			set_sneaking(false)
		combat.dodge_pressed(Input.get_vector("move_left", "move_right", "move_forward", "move_back"))
	elif event.is_action_pressed("switch_spell"):
		Spellbook.cycle()
	elif event.is_action_pressed("power_race"):
		Character.use_power(0)
	elif event.is_action_pressed("power_background"):
		Character.use_power(1)
	elif event.is_action_pressed("command"):
		Command.point_out(self)   # your companion (and called things) go for what you aim at


func _physics_process(delta: float) -> void:
	if Settings.toggle_sprint and Input.is_action_just_pressed("sprint"):
		_sprint_toggled = not _sprint_toggled   # once per frame (sprint_input() is read twice)
	if traversal.busy:   # mantling or vaulting moves the player by itself
		traversal.update(delta)
		_stick_look(delta)
		return
	if not is_on_floor():
		velocity.y -= gravity * delta

	var talking: bool = DialogueManager.is_active or is_dead
	if not talking:
		_stick_look(delta)

	# Jump: climbs a ledge or vaults if there's one in front, otherwise jumps.
	# Holding jump in the air grabs a ledge within reach.
	var can_climb := not talking and combat.state in [PlayerCombat.State.READY, PlayerCombat.State.RECOVERY]
	if Input.is_action_just_pressed("jump") and is_on_floor() and not talking:
		set_sneaking(false)
		var running := sprint_input() and Vector2(velocity.x, velocity.z).length() > walk_speed * 1.1
		if not (can_climb and traversal.try_start(false, running)):
			velocity.y = jump_velocity * stats.modifier("jump_height")
	elif Input.is_action_pressed("jump") and not is_on_floor() and velocity.y < 2.0 and can_climb:
		if traversal.try_start(true, false):
			return

	var input_dir := Vector2.ZERO if talking else Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# Not normalized: a half-tilted stick walks at half speed (keys are always full).
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).limit_length(1.0)

	# Only drains stamina while actually moving (not when pushing against a wall).
	# From a standstill you walk for a split second, then the sprint kicks in.
	var moving := Vector2(velocity.x, velocity.z).length() > 1.0
	if stats.stamina <= 0.0:
		_exhausted = true
	elif stats.stamina >= stamina_to_sprint_again:
		_exhausted = false
	if Settings.toggle_sprint and (direction == Vector3.ZERO or _exhausted):
		_sprint_toggled = false   # stopping (or running out of breath) ends a toggled sprint
	if is_sneaking and sprint_input() and direction != Vector3.ZERO:
		set_sneaking(false)   # breaking into a run stands you up
	var sprinting := sprint_input() and direction != Vector3.ZERO and is_on_floor() and moving \
			and not _exhausted and combat.allows_sprint() and not is_over_encumbered()
	sprinting_now = sprinting
	if sprinting:
		stats.heal(Arms.sum("sprint_heal") * delta)   # Runner's High (Athletics)
		stats.use_stamina(sprint_stamina_per_second * Skills.athletics_stamina_mult()
				* stats.modifier("sprint_stamina") * Armor.sprint_mult() * delta)
		Skills.add_xp("athletics", Vector2(velocity.x, velocity.z).length() * delta / 5.0)   # 1 XP per 5 m
	var target_speed := (sprint_speed * stats.modifier("sprint_speed") if sprinting else walk_speed) * stats.modifier("move_speed") * combat.move_mult()
	if is_sneaking:
		target_speed *= SNEAK_SPEED * stats.modifier("sneak_speed")
	head.position.y = move_toward(head.position.y, SNEAK_HEAD if is_sneaking else _head_height, 3.0 * delta)
	var accel := ground_accel if is_on_floor() else air_accel

	var horizontal := Vector3(velocity.x, 0, velocity.z)
	horizontal = horizontal.move_toward(direction * target_speed, accel * delta)
	var dodge := combat.dodge_velocity()
	if dodge != Vector3.ZERO:
		horizontal = dodge   # the dodge decides where you go
	elif _lunge_left > 0.0:
		_lunge_left -= delta
		horizontal = horizontal.lerp(_lunge_velocity, 0.6)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	weapon.set_movement(horizontal.length() / walk_speed if is_on_floor() else 0.0)

	var was_in_air := not is_on_floor()
	var fall_speed := -velocity.y
	move_and_slide()
	footsteps.update(delta, was_in_air and is_on_floor(), fall_speed)
	if was_in_air and is_on_floor() and fall_speed > safe_fall_speed:
		stats.take_damage((fall_speed - safe_fall_speed) * fall_damage_per_speed * stats.modifier("fall_damage"))

	if talking:
		hud.set_prompt("")
	else:
		_update_interaction()

	if global_position.y < kill_y:
		push_warning("Player fell below kill_y. Collision is not working - turn on Debug > Visible Collision Shapes.")
		global_position = spawn_position
		velocity = Vector3.ZERO


func _on_spell_changed() -> void:
	var spell := Spellbook.current()
	if spell and _orb_material:
		_orb_material.albedo_color = spell.color
		spell_light.light_color = spell.color
		if magic.right_hand:   # the right hand's copy (dual-casting) matches
			magic.right_hand.get_node("Orb").material_override = _orb_material
			magic.right_hand.get_node("Light").light_color = spell.color
	match combat.left_hand():
		PlayerCombat.Hand.SHIELD:
			hud.set_left_hand("Shield   (%s while blocking: bash)" % InputHints.label("attack"))
		PlayerCombat.Hand.TWO_HANDED:
			hud.set_left_hand("Two-handed   (%s blocks)" % InputHints.label("cast"))
		PlayerCombat.Hand.BOW:
			var ammo := Inventory.equipped_item("main_hand").ammo
			hud.set_left_hand("%d %ss   (%s to aim)" % [Inventory.count(ammo), Inventory.get_item(ammo).display_name.to_lower(), InputHints.label("cast")])
		_:
			hud.set_spell(spell, Spellbook.known.size(), magic.right_hand_free())


func _on_spell_learned(spell: SpellData) -> void:
	hud.notify("Spell learned: %s" % spell.display_name)
	if spell.is_charged():
		Hints.show_once("charged_spells", "%s is a charged spell: hold %s until your hand glows bright, then release. With nothing in your right hand, hold both buttons to dual-cast." % [spell.display_name, Hints.key("cast")])


# Weapon stats, model and armour from what's equipped (Inventory).
func _apply_equipment() -> void:
	var weapon_item := Inventory.equipped_item("main_hand")
	for child in weapon.get_children():
		weapon.remove_child(child)
		child.queue_free()
	if weapon_item and weapon_item.held_scene:
		weapon.add_child(weapon_item.held_scene.instantiate())
	combat.set_weapon(weapon_item)
	var shield := Inventory.equipped_item("off_hand")
	for child in off_hand.get_children():
		off_hand.remove_child(child)
		child.queue_free()
	if shield and shield.held_scene:
		off_hand.add_child(shield.held_scene.instantiate())
	combat.set_shield(shield)
	_update_armor()
	_on_spell_changed()   # what the left hand shows depends on the gear


func _update_armor() -> void:
	stats.armor_rating = Inventory.armor_total()


# Gamepad right stick. Mouse look is in _unhandled_input.
func _stick_look(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	if stick == Vector2.ZERO:
		return
	stick *= stick.length()   # curve: fine control near the centre, fast at full tilt
	var speed := stick_look_speed * Settings.mouse_sensitivity * delta
	var vertical := -1.0 if Settings.invert_y else 1.0
	rotate_y(-stick.x * speed)
	head.rotate_x(-stick.y * speed * vertical)
	head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))


## Enemies call this when their attack reaches you. See PlayerCombat.receive_attack.
func receive_attack(damage: float, attacker: Node3D, poise_damage: float = 0.0) -> String:
	note_attacker(attacker)
	return combat.receive_attack(damage, attacker, poise_damage)


## Remembers who hit you last (traps and enemies that hurt you directly call this too).
func note_attacker(attacker: Node) -> void:
	last_attacker = attacker
	_last_hit_at = Time.get_ticks_msec()


## False while talking or dead: no attacking, blocking or dodging.
func can_fight() -> bool:
	return not (DialogueManager.is_active or is_dead)


## Nudges the view (degrees: pitch, yaw, roll); it springs back by itself.
func set_sneaking(on: bool) -> void:
	if on == is_sneaking or (on and is_dead):
		return
	is_sneaking = on
	if on:
		Hints.show_once("sneak", "Sneaking: enemies notice you closer and slower, and need to see you. The word under the compass says how close one is to spotting you. A sneak attack on one that hasn't does triple damage (%s again to stand)." % Hints.key("crouch"))


## Whether the player is asking to sprint: holding the key, or (with Toggle sprint
## on) having pressed it once since they last stopped.
func sprint_input() -> bool:
	if not Settings.toggle_sprint:
		return Input.is_action_pressed("sprint")
	return _sprint_toggled


func camera_kick(degrees: Vector3) -> void:
	_camera_kick += degrees * Settings.camera_shake


## Carrying more than Attributes.carry_capacity(): half speed (the effect), no sprinting.
func is_over_encumbered() -> bool:
	return effects.active.has("over_encumbered")


func _update_encumbrance() -> void:
	var over := Inventory.total_weight() > Attributes.carry_capacity()
	if over and not is_over_encumbered():
		effects.apply("over_encumbered")
		hud.notify("You're carrying too much (%.0f / %.0f): you can't run." % [Inventory.total_weight(), Attributes.carry_capacity()])
	elif not over and is_over_encumbered():
		effects.remove("over_encumbered")


## Steps forward for `seconds` (heavy attacks).
func lunge(speed: float, seconds: float) -> void:
	_lunge_velocity = -global_transform.basis.z * speed
	_lunge_left = seconds


func _process(delta: float) -> void:
	# Bows: hold right-click to aim (zoom in).
	var aiming := combat.is_bow() and Input.is_action_pressed("cast") and can_fight()
	camera.fov = lerpf(camera.fov, Settings.fov * (0.6 if aiming else 1.0), minf(delta * 10.0, 1.0))
	_camera_kick = _camera_kick.lerp(Vector3.ZERO, minf(delta * 12.0, 1.0))
	# (In third person, view.aim_rotation turns the eye to whatever is under the crosshair.)
	camera.rotation = Vector3(deg_to_rad(_camera_kick.x), deg_to_rad(_camera_kick.y), deg_to_rad(_camera_kick.z)) + view.aim_rotation


func _apply_settings() -> void:
	camera.fov = Settings.fov


func _on_skill_increased(skill_id: String, new_level: int) -> void:
	hud.notify("%s increased to %d" % [Skills.SKILLS[skill_id]["name"], new_level])


func _on_leveled_up(new_level: int) -> void:
	hud.notify("Level %d!  Press %s to choose a bonus." % [new_level, InputHints.label("character_menu")])
	Hints.show_once("level_up", "Level up: open %s → Skills to raise Health, Stamina or Magicka, spend an attribute point, and take a perk." % Hints.key("character_menu"))



func _on_item_added(item: ItemData, amount: int) -> void:
	if item.teaches_spell != "":
		Hints.show_once("tomes", "Spell tome: open %s → Inventory and use it to learn the spell." % Hints.key("character_menu"))
	hud.notify("%s added" % item.display_name if amount == 1 else "%s (%d) added" % [item.display_name, amount])


func _on_gold_added(amount: int) -> void:
	hud.notify("%d gold %s" % [absi(amount), "added" if amount > 0 else "removed"])


func _on_died() -> void:
	is_dead = true
	set_sneaking(false)
	Engine.time_scale = 1.0   # in case a hit stop was running
	hud.set_prompt("")
	var killer: Node = last_attacker if Time.get_ticks_msec() - _last_hit_at < Defeat.KILLER_MEMORY_MS else null
	if Defeat.applies():   # Hardcore: wake up wounded instead of reloading
		show_message("You fall...")
		await get_tree().create_timer(1.5).timeout
		Defeat.handle(self, killer)
		return
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


## Stand at the named Marker3D in this level (after a location door, or a new game's opening).
func arrive_at_marker(marker_name: String) -> void:
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


# Speeds, maximums and regen from race (res://races/*.tres), attributes,
# level-up bonuses and perks. Runs at spawn and whenever any of those change.
func _recalculate_stats(first_time: bool = false) -> void:
	var race := GameState.race_data
	walk_speed = _base["walk"] * race.move_speed_mult * Attributes.move_speed_mult()
	sprint_speed = _base["sprint"] * race.move_speed_mult * Attributes.move_speed_mult()
	# Jump height grows with the square of jump speed, so take the square root.
	jump_velocity = _base["jump"] * sqrt(race.jump_height_mult)
	stats.stamina_regen = _base["stamina_regen"] * Attributes.stamina_regen_mult()
	stats.magicka_regen = _base["magicka_regen"] * Attributes.magicka_regen_mult()
	var new_max := {
		"health": race.health + Skills.bonus["health"] + Attributes.health_bonus() + Character.stat_bonus("health"),
		"stamina": race.stamina + Skills.bonus["stamina"] + Attributes.stamina_bonus() + Character.stat_bonus("stamina"),
		"magicka": race.magicka + Skills.bonus["magicka"] + Attributes.magicka_bonus() + Character.stat_bonus("magicka"),
	}
	if first_time:
		stats.setup(new_max["health"], new_max["stamina"], new_max["magicka"])
		return
	for stat in new_max:
		var gained: float = new_max[stat] - stats.get("max_" + stat)
		stats.set("max_" + stat, new_max[stat])
		# new points arrive full; lost ones only cap the current value
		stats.set(stat, clampf(stats.get(stat) + maxf(gained, 0.0), 0.0, new_max[stat]))
	stats.changed.emit()


# Whatever the crosshair points at within reach: if it has an `interact(player)`
# method it's usable. Its optional `prompt` property is shown on screen.
func _update_interaction() -> void:
	var target: Object = interact_ray.get_collider() if interact_ray.is_colliding() else null
	var prompt = target.get("prompt") if target else null
	if target == null or not target.has_method("interact") or prompt == "":
		hud.set_prompt("")   # an empty prompt means "nothing to do here right now"
		return

	hud.set_prompt("[%s] %s" % [InputHints.label("interact"), prompt if prompt else "Use"])
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
		"power_race": KEY_Z, "power_background": KEY_X, "dodge": KEY_ALT,
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
