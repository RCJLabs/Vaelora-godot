extends CharacterBody3D

# A wisp: a drifting knot of light that fights from range. Needs no animation.
#
#   - It hovers and keeps its distance, circling, and throws slow arcane bolts.
#     The telegraph: it stops, swells and brightens for charge_time, with a
#     rising hum. Block, ward or dodge the bolt; parry it and it flies back.
#   - Get close and it blinks away (with a flash) when the blink is ready.
#   - Magic hurts it half as much (spells: no knockback or poise damage).
#     Weapons and arrows hurt it fully, and a heavy hit (or broken poise)
#     knocks it out of the air for a moment: then it's easy to hit.
#   - Dead wisps leave Wisp Essence (restores Magicka).
# They're spawned at night by a WispSpawner and fade at dawn.

signal died

enum State { IDLE, ENGAGE, CHARGE, STAGGER, RETURN, DEAD }

@export var aggro_range: float = 16.0
@export var leash_range: float = 35.0
@export var preferred_range: float = 8.0
@export var min_range: float = 3.5      # closer than this: blink away
@export var hover_height: float = 1.8
@export var speed: float = 3.5
@export var bolt_damage: float = 12.0
@export var bolt_speed: float = 14.0
@export var bolt_poise: float = 8.0
@export var charge_time: float = 0.9
@export var cast_cooldown: float = 2.2
@export var blink_cooldown: float = 4.0
@export var stagger_time: float = 1.6
## Damage taken from spells, compared with weapons (0.5 = half).
@export var magic_resist: float = 0.5
@export var color: Color = Color(0.65, 0.55, 1.0)

@onready var stats: Stats = $Stats
@onready var effects: StatusEffects = $StatusEffects
@onready var model: Node3D = $Model
@onready var core: MeshInstance3D = $Model/Core
@onready var halo: MeshInstance3D = $Model/Halo
@onready var light: OmniLight3D = $Model/Light

var state := State.IDLE
var home: Vector3
var prompt := ""          # wisps leave no body to search
var _time := randf() * 10.0
var _cast_left := 1.0
var _blink_left := 0.0
var _charge_left := 0.0
var _stagger_left := 0.0
var _strafe := 1.0
var _wander_target: Vector3
var _knockback := Vector3.ZERO
var _lift_left := 0.0   # the Lifting Tide holds it up this much longer
var _lift_to := 0.0
var _core_material: StandardMaterial3D
var _halo_material: StandardMaterial3D
var _fading := false

const BOLT_SCENE := preload("res://combat/spell_bolt.tscn")


func _ready() -> void:
	add_to_group("enemy")
	home = global_position
	_wander_target = home
	stats.died.connect(_on_died)
	stats.damaged.connect(_on_damaged)
	stats.poise_broken.connect(func(): stagger(stagger_time))
	_core_material = StandardMaterial3D.new()
	_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_core_material.albedo_color = color.lightened(0.4)
	core.material_override = _core_material
	_halo_material = StandardMaterial3D.new()
	_halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_halo_material.albedo_color = Color(color.r, color.g, color.b, 0.35)
	halo.material_override = _halo_material
	light.light_color = color
	for mote in model.get_children():
		if mote is MeshInstance3D and mote.name.begins_with("Mote"):
			mote.material_override = _core_material


func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	_time += delta
	_cast_left -= delta
	_blink_left -= delta
	_animate(delta)
	var player := get_tree().get_first_node_in_group("player")
	var target_velocity := Vector3.ZERO
	if player == null or player.is_dead or DialogueManager.is_active:
		pass
	else:
		target_velocity = _think(player, delta)
	# Hover: hold a height above whatever is below (lower while knocked down).
	var ground := _ground_height()
	var want_y := ground + (0.35 if state == State.STAGGER else hover_height + sin(_time * 1.7) * 0.15)
	if _lift_left > 0.0:
		_lift_left -= delta
		want_y = _lift_to   # held up by the tide
	target_velocity *= Vector3(stats.modifier("move_speed"), 1.0, stats.modifier("move_speed"))   # chilled, pinned
	target_velocity.y = clampf((want_y - global_position.y) * 4.0, -6.0, 4.0)
	velocity = velocity.lerp(target_velocity, minf(delta * 4.0, 1.0)) + _knockback
	move_and_slide()
	velocity -= _knockback
	_knockback = _knockback.move_toward(Vector3.ZERO, 12.0 * delta)


func _think(player: Node3D, delta: float) -> Vector3:
	var to_player: Vector3 = player.global_position + Vector3.UP * 1.2 - global_position
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	var dist := flat.length()
	var from_home := Vector2(global_position.x - home.x, global_position.z - home.z).length()
	match state:
		State.IDLE:
			if not _graced(player) and Stealth.notices(self, player, aggro_range * Corruption.wisp_aggro_scale(), dist, delta) and _sees(player):
				_start_fight()
				if Corruption.tier() > 0:
					Hints.show_once("wisps_corruption", "Wisps go for anyone carrying stolen light. The more corrupted you are, the further away they notice you, and the more of them come out at night.")
			return _wander()
		State.RETURN:
			if from_home < 1.5:
				state = State.IDLE
				stats.refill()
			elif Stealth.notices(self, player, aggro_range * 0.5, dist, delta):
				state = State.ENGAGE
			var back := home - global_position
			back.y = 0.0
			return back.normalized() * speed
		State.ENGAGE:
			if from_home > leash_range or Stealth.lost_track(self, delta):
				state = State.RETURN
				return Vector3.ZERO
			if dist < min_range and _blink_left <= 0.0:
				_blink(player)
				return Vector3.ZERO
			if _cast_left <= 0.0 and dist < aggro_range * 1.3 and _sees(player):
				state = State.CHARGE
				_charge_left = charge_time
				Sfx.play_at("wisp_charge", global_position, -2.0)
				return Vector3.ZERO
			# Keep about preferred_range away, circling.
			var side := flat.normalized().cross(Vector3.UP) * _strafe
			var move := side * 0.8
			if dist > preferred_range + 1.5:
				move += flat.normalized()
			elif dist < preferred_range - 1.5:
				move -= flat.normalized()
			if randf() < delta * 0.3:
				_strafe = -_strafe
			return move.normalized() * speed
		State.CHARGE:
			_charge_left -= delta
			if _charge_left <= 0.0:
				_fire(player)
				state = State.ENGAGE
				_cast_left = cast_cooldown * randf_range(0.8, 1.2)
			return Vector3.ZERO
		State.STAGGER:
			_stagger_left -= delta
			if _stagger_left <= 0.0:
				state = State.ENGAGE
			return Vector3.ZERO
	return Vector3.ZERO


func _start_fight() -> void:
	state = State.ENGAGE
	_cast_left = randf_range(0.6, 1.4)
	Hints.show_once("wisps", "Wisps throw bolts after they glow brighter: block, ward or dodge them, or parry to throw the bolt back. Magic only half-hurts them; blades and arrows don't.")
	if get_parent().has_method("alert"):
		get_parent().alert(self)


## Called by the spawner when another wisp starts fighting.
func join_hunt() -> void:
	if state == State.IDLE or state == State.RETURN:
		state = State.ENGAGE
		_cast_left = randf_range(1.0, 2.0)


func _fire(player: Node3D) -> void:
	var bolt: SpellBolt = BOLT_SCENE.instantiate()
	bolt.shooter = self
	bolt.hits_player = true
	bolt.damage = bolt_damage
	bolt.poise_damage = bolt_poise
	bolt.color = color
	_world().add_child(bolt)
	var from := global_position + Vector3.UP * 0.1
	var aim: Vector3 = player.global_position + Vector3.UP * 1.3 - from
	bolt.launch(from + aim.normalized() * 0.5, aim, bolt_speed, 1.1)
	Sfx.play_at("spell_cast", global_position, -2.0)


# Flash, then reappear a few metres away, further from the player.
func _blink(player: Node3D) -> void:
	_blink_left = blink_cooldown
	SpellBurst.spawn(_world(), global_position, 0.8, color)
	Sfx.play_at("wisp_blink", global_position)
	var away := global_position - player.global_position
	away.y = 0.0
	var angle := randf_range(-0.9, 0.9)
	var direction := away.normalized().rotated(Vector3.UP, angle)
	var target := global_position + direction * randf_range(5.0, 7.0)
	# Don't blink into walls: stop short of anything solid on the way.
	var query := PhysicsRayQueryParameters3D.create(global_position, target, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		target = hit["position"] - direction * 0.6
	global_position = target
	SpellBurst.spawn(_world(), global_position, 0.6, color)
	_cast_left = minf(_cast_left, 0.8)


func _wander() -> Vector3:
	var to := _wander_target - global_position
	to.y = 0.0
	if to.length() < 1.0:
		_wander_target = home + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5))
	return to.normalized() * speed * 0.35


# Bolts, flashes and drops go in the level, not under the spawner.
func _world() -> Node:
	var level := get_tree().current_scene
	return level if level else get_parent()


# Released an essence tonight (effects/wisp_grace.tres), or it's Lanternfast: the
# wisps let you be.
func _graced(player: Node3D) -> bool:
	if GameState.has_flag("lanternfast_now"):
		return true
	return player.get("effects") != null and player.effects.has("wisp_grace")


func _sees(player: Node3D) -> bool:
	var query := PhysicsRayQueryParameters3D.create(global_position, player.global_position + Vector3.UP * 1.3, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _ground_height() -> float:
	var query := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 20.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"].y if not hit.is_empty() else global_position.y - hover_height


# Glow, swell while charging, motes circling.
func _animate(delta: float) -> void:
	var charge := 0.0
	if state == State.CHARGE:
		charge = 1.0 - _charge_left / charge_time
	var glow := 1.0 + charge * 4.0
	if state == State.STAGGER:
		glow = 0.4
	light.light_energy = lerpf(light.light_energy, 1.2 * glow, minf(delta * 10.0, 1.0))
	halo.scale = Vector3.ONE * (1.0 + charge * 0.8 + sin(_time * 6.0) * 0.05)
	core.scale = Vector3.ONE * (1.0 + charge * 0.4)
	var i := 0
	for mote in model.get_children():
		if mote is MeshInstance3D and mote.name.begins_with("Mote"):
			var a := _time * (2.0 + charge * 6.0) + i * TAU / 3.0
			mote.position = Vector3(cos(a), sin(a * 1.3) * 0.4, sin(a)) * (0.45 - charge * 0.2)
			i += 1


## Called by weapons, arrows (knockback, poise) and spells (no knockback or poise: resisted).
func take_hit(damage: float, from_position: Vector3, knockback: float = 5.0, poise_damage: float = 0.0, heavy: bool = false) -> String:
	if state == State.DEAD:
		return "hit"
	if state == State.IDLE or state == State.RETURN:
		_start_fight()
	var is_spell := knockback <= 0.0 and poise_damage <= 0.0
	stats.take_damage(damage * (magic_resist if is_spell else 1.0))
	if state == State.DEAD:
		return "hit"
	if knockback > 0.0:
		var push := global_position - from_position
		push.y = 0.0
		_knockback = push.normalized() * knockback * 0.8
	if heavy:
		stagger(stagger_time)
	else:
		stats.take_poise_damage(poise_damage)
	return "hit"


func add_effect(id: String) -> void:
	effects.apply(id)


## Tidecraft moves it (systems/tidecraft.gd): `push` (metres a second, flat)
## replaces whatever knockback it has this frame.
func shove(push: Vector3) -> void:
	if state != State.DEAD:
		push.y = 0.0
		_knockback = push

## The Lifting Tide (systems/tidecraft.gd): rise `height` metres and hang there,
## helpless, for `seconds`; then gravity has it again.
func lift(height: float, seconds: float) -> void:
	if state == State.DEAD:
		return
	_lift_to = global_position.y + height
	_lift_left = seconds
	stagger(seconds + 0.6)


## Reeling from a broken guard or a heavy blow (Knockout, Unarmed).
func is_staggered() -> bool:
	return state == State.STAGGER


## Hasn't noticed you: a sneak attack lands (systems/stealth.gd).
func is_unaware() -> bool:
	return state == State.IDLE


## After you, for the HUD's eye.
func is_hunting() -> bool:
	return state in [State.ENGAGE, State.CHARGE, State.STAGGER]


func is_lifted() -> bool:
	return _lift_left > 0.0


## Knocked out of the air: drops low and dims, can't cast.
func stagger(seconds: float) -> void:
	if state == State.DEAD:
		return
	state = State.STAGGER
	_stagger_left = seconds
	_charge_left = 0.0


func _on_damaged(_amount: float) -> void:
	var tween := create_tween()
	tween.tween_property(_core_material, "albedo_color", Color(1, 1, 1), 0.04)
	tween.tween_property(_core_material, "albedo_color", color.lightened(0.4), 0.2)


func _on_died() -> void:
	state = State.DEAD
	collision_layer = 0
	collision_mask = 0
	SpellBurst.spawn(_world(), global_position, 1.4, color)
	Sfx.play_at("wisp_blink", global_position, 2.0)
	_drop_essence()
	died.emit()
	queue_free()


func _drop_essence() -> void:
	var drop := StaticBody3D.new()
	drop.set_script(load("res://interactables/pickup.gd"))
	drop.set("item_id", "wisp_essence")
	drop.set("remember", false)
	drop.collision_layer = 8
	drop.collision_mask = 0
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	drop.add_child(shape)
	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.09
	ball.height = 0.18
	mesh.mesh = ball
	mesh.material_override = _core_material
	drop.add_child(mesh)
	var glow := OmniLight3D.new()
	glow.light_color = color
	glow.light_energy = 0.8
	glow.omni_range = 2.0
	drop.add_child(glow)
	_world().add_child(drop)
	drop.global_position = Vector3(global_position.x, _ground_height() + 0.6, global_position.z)


## Something is drawing the life out of the stones' wisps (main quest, "The Draining").
## The spawner calls this on a calm wisp: it drifts into the crystal at `center`,
## dims, and leaves as a thin streak heading north (-Z). Only while it isn't fighting.
func drain_away(center: Vector3) -> bool:
	if _fading or state != State.IDLE:
		return false
	_fading = true
	state = State.DEAD
	collision_layer = 0
	Sfx.play_at("wisp_drain", global_position)
	var tween := create_tween()
	tween.set_parallel()
	tween.tween_property(self, "global_position", center, 2.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(light, "light_energy", light.light_energy * 0.3, 2.5)
	tween.tween_property(_halo_material, "albedo_color:a", 0.05, 2.5)
	tween.chain().tween_property(self, "global_position", center + Vector3(0, 0.6, -6.0), 0.8)
	tween.tween_property(model, "scale", Vector3(0.15, 0.15, 2.5), 0.8)
	tween.tween_property(light, "light_energy", 0.0, 0.8)
	tween.chain().tween_callback(queue_free)
	return true


## Dawn: the spawner calls this; the wisp fades away.
func fade_out() -> void:
	if _fading or state == State.DEAD:
		return
	_fading = true
	state = State.DEAD
	collision_layer = 0
	var tween := create_tween().set_parallel()
	tween.tween_property(model, "scale", Vector3.ONE * 0.05, 1.5)
	tween.tween_property(light, "light_energy", 0.0, 1.5)
	tween.chain().tween_callback(queue_free)
