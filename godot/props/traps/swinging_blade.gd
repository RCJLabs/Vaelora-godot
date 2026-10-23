extends Node3D

# A pendulum blade hung from the ceiling: swings side to side across a corridor
# (around the node's Z axis). Too heavy to block: time your run, or dodge through
# it (the dodge's invulnerability works). Hits the player and enemies.
#
# Scene: SwingingBlade (Node3D at the pivot, this) ├── Arm + Blade meshes hanging
# down └── Hitbox (Area3D around the blade, mask: player + enemies). All children
# swing with the node.
# Active from the start, or set Start Active off and give it to a PressurePlate.

@export var start_active := true
@export var swing_degrees: float = 65.0
@export var period: float = 2.4          # seconds for a full left-right-left swing
@export var phase: float = 0.0           # 0..1: offsets blades in a row
@export var damage: float = 25.0
@export var knockback: float = 7.0

@onready var hitbox: Area3D = $Hitbox

var active := false
var _time := 0.0
var _hit_cooldown := {}   # body -> seconds before it can be hit again


func _ready() -> void:
	active = start_active
	_time = phase * period


func activate() -> void:
	active = true


func deactivate() -> void:
	active = false


func _physics_process(delta: float) -> void:
	if not active:
		rotation.z = move_toward(rotation.z, 0.0, delta)
		return
	_time += delta
	rotation.z = sin(_time / period * TAU) * deg_to_rad(swing_degrees)
	if absf(cos(_time / period * TAU)) > 0.85 and fmod(_time, period * 0.5) < delta:
		Sfx.play_at("swing_heavy", hitbox.global_position, -4.0)
	for body in _hit_cooldown.keys():
		_hit_cooldown[body] -= delta
		if _hit_cooldown[body] <= 0.0:
			_hit_cooldown.erase(body)
	# Only dangerous while moving fast (not at the ends of the swing).
	if absf(cos(_time / period * TAU)) < 0.25:
		return
	for body in hitbox.get_overlapping_bodies():
		if _hit_cooldown.has(body):
			continue
		_hit_cooldown[body] = 0.8
		_hit(body)


func _hit(body: Node3D) -> void:
	# Push along the way the blade is moving.
	var swing_direction := global_transform.basis.x * signf(cos(_time / period * TAU))
	swing_direction.y = 0.0
	if body.is_in_group("player"):
		if body.combat.is_invulnerable() or body.is_dead:
			return
		body.stats.take_damage(damage)
		body.combat.stagger(0.5)
		body.velocity += swing_direction.normalized() * knockback + Vector3.UP * 2.0
		body.camera_kick(Vector3(-4.0, 0.0, 8.0 * signf(swing_direction.x + 0.001)))
		Sfx.play("hit_heavy")
	elif body.has_method("take_hit"):
		body.take_hit(damage, body.global_position - swing_direction, knockback, 40.0, true)
