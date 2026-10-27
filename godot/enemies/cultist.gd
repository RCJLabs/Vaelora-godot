extends "res://enemies/bandit.gd"

# A hooded cultist: one of the people doing the draining (main quest 4, "The
# Barrow"). Fights exactly like a bandit (bandit.tscn with this script swapped
# in), but in grey-violet robes, and doesn't take prisoners: beaten by one in
# Hardcore you're found or left for dead, never caged.
#
# A caster (caster = true; a "Mercy Drawer") fights with Drawing, the school the Mercy
# practise (docs/godot-starter/DRAWING.md), from a distance like an archer:
#   - Hollow bolt: a violet bolt (combat/spell_bolt.gd). Block, parry (it goes back at
#     the caster) or dodge it, like a swing.
#   - Draw: within DRAW_RANGE and in plain sight, a grey beam that takes your Health in
#     pulses and gives half of it to the caster. It stops if you get out of reach or
#     behind something; a raised guard or a ward takes it as it would a hit.
#   - Mend: a friend nearby badly hurt, it raises a hand over them and gives them back
#     MEND_AMOUNT.
# Every cast has a wind-up (the hands glow: violet for a bolt, pale for a Draw, gold
# for a Mend), and any hit breaks it: the caster reels for a moment. Close in and it
# backs off; cornered, it fights hand to hand with whatever it holds.

## Stays still, unseeing, until this story flag is set (e.g. their hidden room is
## opened), so they don't press against a wall at a player on the other side.
@export var wait_for_flag: String = ""
@export_group("Caster")
## Fights with spells from a distance instead of hand to hand.
@export var caster := false
@export var bolt_damage: float = 14.0
@export var draw_damage: float = 4.0   # each pulse (two a second)
@export var cast_range: float = 8.0    # it keeps this far off

const ROBE := Color(0.2, 0.18, 0.24)
const BOLT_SCENE := preload("res://combat/spell_bolt.tscn")
const BOLT_WINDUP := 0.8
const BOLT_SPEED := 16.0
const DRAW_WINDUP := 0.6
const DRAW_RANGE := 7.0
const DRAW_LASTS := 2.5       # the longest a Draw lasts
const DRAW_PULSE := 0.5
const MEND_WINDUP := 1.2
const MEND_AMOUNT := 25.0
const MEND_RANGE := 10.0
const MEND_BELOW := 0.5      # a friend under this share of its Health
const MEND_COOLDOWN := 12.0
const INTERRUPTED := 0.6     # seconds it reels when a hit breaks a cast
const COLORS := {"bolt": Color(0.65, 0.5, 1.0), "draw": Color(0.85, 0.88, 0.92), "mend": Color(1.0, 0.8, 0.4)}

var _spell := ""             # what it's casting: "bolt", "draw" or "mend"
var _cast_target: Node3D     # who it's casting at (a friend, for a Mend)
var _cast_cooldown := 0.0
var _mend_cooldown := 0.0
var _pulse_left := 0.0
var _hand_glow: StandardMaterial3D
var _hand_light: OmniLight3D
var _beam: MeshInstance3D


func _ready() -> void:
	if look_role == "bandit":   # the scene's default: dress as the Mercy, unless the level chose
		look_role = "mercy"
		look_cloth = ROBE
	if caster:
		keep_range = cast_range
	super()
	remove_from_group("captors")
	if caster:
		_make_hands()
	if wait_for_flag != "" and not GameState.has_flag(wait_for_flag) and state != State.DEAD:
		set_physics_process(false)
		GameState.flag_set.connect(func(flag): if flag == wait_for_flag: set_physics_process(true))


## The Mercy are hollowing mages: humans, elves and Passengers.
func vary_races() -> Array:
	return ["human", "human", "elf", "passenger"]


## The Mercy dress alike.
func vary_cloths() -> Array:
	return []


func ranged() -> bool:
	return archer or caster


func _physics_process(delta: float) -> void:
	super(delta)
	if not caster:
		return
	if state == State.DEAD:
		_beam.visible = false
		_hand_glow.emission_energy_multiplier = 0.0
		_hand_light.light_energy = 0.0
		return
	_mend_cooldown -= delta
	var glow := 0.0
	if state == State.CAST:
		var windup := _windup()
		glow = 2.0 + 4.0 * minf(_phase_time / windup, 1.0) if _phase == Phase.WINDUP else 5.0
	_hand_glow.emission_energy_multiplier = lerpf(_hand_glow.emission_energy_multiplier, glow, minf(delta * 12.0, 1.0))
	_hand_light.light_energy = _hand_glow.emission_energy_multiplier * 0.4
	_beam.visible = state == State.CAST and _spell == "draw" and _phase == Phase.ACTIVE and is_instance_valid(_cast_target)
	if _beam.visible:
		_aim_beam()


func _think(player: Node3D, delta: float) -> void:
	if state != State.CAST:
		super(player, delta)
		return
	var dist := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if _spell != "mend" and _phase == Phase.WINDUP and dist < keep_range * BACK_OFF:
		_end_cast(0.6)   # you've closed in: let it go and back off
		return
	if _gone(_cast_target):
		_end_cast(0.4)
		return
	_face(_cast_target.global_position, delta)
	_move(Vector3.ZERO, 0.0, delta)
	_phase_time += delta
	match _phase:
		Phase.WINDUP:
			if _phase_time >= _windup():
				_phase_time = 0.0
				match _spell:
					"bolt":
						_hollow_bolt(_cast_target)
						_phase = Phase.RECOVERY
						_pose("rest", 0.4)
					"draw":
						_phase = Phase.ACTIVE
						_pulse_left = 0.0
						Sfx.play_at("wisp_drain", global_position, -2.0)
					"mend":
						_mend(_cast_target)
						_phase = Phase.RECOVERY
						_pose("rest", 0.4)
		Phase.ACTIVE:   # the Draw
			var reach := _cast_target.global_position.distance_to(global_position)
			if reach > DRAW_RANGE + 1.0 or not Stealth.clear_line(self, _cast_target) or _phase_time > DRAW_LASTS:
				_phase = Phase.RECOVERY
				_phase_time = 0.0
				_pose("rest", 0.4)
				return
			_pulse_left -= delta
			if _pulse_left <= 0.0:
				_pulse_left = DRAW_PULSE
				_draw_pulse(_cast_target)
		Phase.RECOVERY:
			if _phase_time >= 0.5:
				_end_cast(randf_range(2.5, 3.5))


# --- casting -----------------------------------------------------------------------------

## At range: keep its distance, back off if you close in, mend a friend or cast at you.
func _ranged_engage(player: Node3D, to_player: Vector3, dist: float, delta: float) -> void:
	if not caster:
		super(player, to_player, dist, delta)
		return
	if dist > keep_range + 4.0 or _unseen > 1.0:
		state = State.CHASE
		return
	_face(player.global_position, delta)
	_cast_cooldown -= delta
	var step := to_player.normalized().cross(Vector3.UP) * _strafe * 0.3
	if dist < keep_range * RETREAT:
		step -= to_player.normalized()
	_move(global_position + step, run_speed * 0.55, delta, false)
	if _cast_cooldown > 0.0:
		return
	var friend := _friend_to_mend()
	if friend:
		_begin_cast("mend", friend)
		return
	if not Stealth.clear_line(self, player):
		_unseen += delta
		return
	_unseen = 0.0
	_begin_cast("draw" if dist <= DRAW_RANGE and randf() < 0.5 else "bolt", player)


func _begin_cast(spell: String, target: Node3D) -> void:
	state = State.CAST
	_spell = spell
	_cast_target = target
	_phase = Phase.WINDUP
	_phase_time = 0.0
	_hand_glow.emission = COLORS[spell]
	_hand_light.light_color = COLORS[spell]
	_pose("mend" if spell == "mend" else "cast", 0.3)
	Stealth.noise(global_position, 8.0, self)   # muttering, and the hum of it
	Hints.show_once("casters", "Mercy Drawers cast. Watch their hands: hit them to break the spell, and get out of a Draw's reach or behind something.")


func _end_cast(cooldown: float) -> void:
	state = State.ENGAGE
	_spell = ""
	_cast_cooldown = cooldown
	_pose("rest", 0.2)
	if randf() < 0.4:
		_strafe = -_strafe


## Dead, or no longer there: nothing to cast at.
func _gone(target: Node3D) -> bool:
	if not is_instance_valid(target):
		return true
	if _spell == "mend":
		return target.state == State.DEAD
	return target.get("is_dead") == true or (target.get("stats") != null and target.stats.is_dead)


func _windup() -> float:
	return {"bolt": BOLT_WINDUP, "draw": DRAW_WINDUP, "mend": MEND_WINDUP}.get(_spell, 1.0)


func _hollow_bolt(target: Node3D) -> void:
	var bolt: SpellBolt = BOLT_SCENE.instantiate()
	bolt.shooter = self
	bolt.hits_player = true
	bolt.damage = bolt_damage
	bolt.poise_damage = 8.0
	bolt.color = COLORS["bolt"]
	get_tree().current_scene.add_child(bolt)
	var from := global_position + Vector3.UP * 1.4 - global_basis.z * 0.6
	var aim := target.global_position + Vector3.UP * 1.2 - from
	bolt.launch(from, aim, BOLT_SPEED, 0.9)
	Sfx.play_at("spell_cast", global_position, -2.0)


## One pulse of the Draw: taken like a hit (a guard or a ward stops some), and half of
## the Health it actually took comes back to the caster.
func _draw_pulse(target: Node3D) -> void:
	var target_stats = target.get("stats")
	var before: float = target_stats.health if target_stats else 0.0
	if target.has_method("receive_attack"):
		target.receive_attack(draw_damage, self, 0.0)
	var taken: float = maxf(before - target_stats.health, 0.0) if target_stats else 0.0
	if taken > 0.0:
		stats.heal(taken * 0.5)


## A friend (in its band) close by and badly hurt.
func _friend_to_mend() -> Node3D:
	if _mend_cooldown > 0.0:
		return null
	var worst: Node3D = null
	var worst_share := MEND_BELOW
	for other in get_parent().get_children():
		if other == self or other.get("stats") == null or other.get("state") == null or other.state == State.DEAD:
			continue
		if other.global_position.distance_to(global_position) > MEND_RANGE:
			continue
		var share: float = other.stats.health / maxf(other.stats.max_health, 1.0)
		if share < worst_share:
			worst = other
			worst_share = share
	return worst


func _mend(friend: Node3D) -> void:
	_mend_cooldown = MEND_COOLDOWN
	friend.stats.heal(MEND_AMOUNT)
	SpellBurst.spawn(get_tree().current_scene, friend.global_position + Vector3.UP, 0.9, COLORS["mend"])
	Sfx.play_at("spell_cast", friend.global_position, -4.0)


## Any hit breaks a cast: it reels for a moment.
func take_hit(damage: float, from_position: Vector3, knockback: float = 5.0, poise_damage: float = 0.0, heavy: bool = false) -> String:
	var casting := state == State.CAST
	var answer := super(damage, from_position, knockback, poise_damage, heavy)
	if casting and state == State.CAST:
		_spell = ""
		_cast_cooldown = 1.0
		stagger(INTERRUPTED)
	return answer


# --- the look -------------------------------------------------------------------------------

## A glow in the left hand (the right holds its weapon) that shows what it's casting.
func _make_hands() -> void:
	var hand := MeshInstance3D.new()
	hand.name = "CastGlow"
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.14
	_hand_glow = StandardMaterial3D.new()
	_hand_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_hand_glow.albedo_color = Color(0.2, 0.2, 0.25)
	_hand_glow.emission_enabled = true
	_hand_glow.emission = COLORS["bolt"]
	_hand_glow.emission_energy_multiplier = 0.0
	sphere.material = _hand_glow
	hand.mesh = sphere
	hand.position = Vector3(0, -0.58, 0)
	left_arm.add_child(hand)
	_hand_light = OmniLight3D.new()
	_hand_light.omni_range = 3.0
	_hand_light.light_energy = 0.0
	hand.add_child(_hand_light)
	_beam = MeshInstance3D.new()
	_beam.name = "DrawBeam"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.035
	cylinder.bottom_radius = 0.06
	cylinder.height = 1.0
	var grey := StandardMaterial3D.new()
	grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	grey.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	grey.albedo_color = Color(0.8, 0.82, 0.86, 0.6)
	cylinder.material = grey
	_beam.mesh = cylinder
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)


## Stretches the beam from its hand to the chest of whoever it's drawing from.
func _aim_beam() -> void:
	var from: Vector3 = left_arm.get_node("CastGlow").global_position
	var to: Vector3 = _cast_target.global_position + Vector3.UP * 1.1
	var length := from.distance_to(to)
	if length < 0.1:
		return
	var up := (to - from) / length
	var side := up.cross(Vector3.FORWARD if absf(up.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var b := Basis(side, up, side.cross(up)).scaled(Vector3(1, length, 1))
	_beam.global_transform = Transform3D(b, (from + to) * 0.5)
