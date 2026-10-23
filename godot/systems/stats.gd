class_name Stats
extends Node

# Health / Stamina / Magicka for anything that can be hurt (player, wolves, NPCs).
# Add as a child node named "Stats" and set the maximums in the Inspector,
# or call setup() from code (the player does this from its race).
# If there's a sibling "StatusEffects" node, its modifiers change damage taken
# and regeneration. Armour (armor_rating) reduces hits but not damage over time.

signal changed            # any value changed - HUD bars listen to this
signal damaged(amount: float)
signal died

@export var max_health: float = 100.0
@export var max_stamina: float = 100.0
@export var max_magicka: float = 100.0

@export_group("Regeneration (per second)")
@export var health_regen: float = 0.5
@export var stamina_regen: float = 15.0
@export var magicka_regen: float = 5.0
## Seconds after spending stamina before it starts refilling.
@export var stamina_regen_delay: float = 1.0
## Seconds after casting before magicka starts refilling.
@export var magicka_regen_delay: float = 1.0

## Total armour from equipment. Damage from hits is cut by armor / (armor + 100):
## 25 armour = -20%, 100 armour = -50%.
var armor_rating: float = 0.0

var health: float
var stamina: float
var magicka: float
var is_dead := false

var _stamina_delay_left := 0.0
var _magicka_delay_left := 0.0
var _effects: Node   # sibling StatusEffects, if any
## Anything with modifier(key) -> float that always applies (the player sets
## this to the Character autoload: traits, perks, Hardcore). null for others.
var permanent: Object = null


func _ready() -> void:
	_effects = get_parent().get_node_or_null("StatusEffects")
	refill()


## Multiplier from status effects and permanent modifiers (1.0 when there are none).
func modifier(key: String) -> float:
	var result: float = _effects.modifier(key) if _effects else 1.0
	if permanent:
		result *= permanent.modifier(key)
	return result


func setup(new_max_health: float, new_max_stamina: float, new_max_magicka: float) -> void:
	max_health = new_max_health
	max_stamina = new_max_stamina
	max_magicka = new_max_magicka
	refill()


func refill() -> void:
	health = max_health
	stamina = max_stamina
	magicka = max_magicka
	is_dead = false
	changed.emit()


func _process(delta: float) -> void:
	if is_dead:
		return
	var before := Vector3(health, stamina, magicka)
	health = minf(health + health_regen * modifier("health_regen") * delta, max_health)
	if _magicka_delay_left > 0.0:
		_magicka_delay_left -= delta
	else:
		magicka = minf(magicka + magicka_regen * modifier("magicka_regen") * delta, max_magicka)
	if _stamina_delay_left > 0.0:
		_stamina_delay_left -= delta
	else:
		stamina = minf(stamina + stamina_regen * modifier("stamina_regen") * delta, max_stamina)
	if Vector3(health, stamina, magicka) != before:
		changed.emit()


## `over_time` = bleeding, poison, burning ticks: they skip armour.
func take_damage(amount: float, over_time: bool = false) -> void:
	if is_dead or amount <= 0.0:
		return
	amount *= modifier("damage_taken")
	if not over_time:
		amount *= 1.0 - armor_rating / (armor_rating + 100.0)
	health = maxf(health - amount, 0.0)
	damaged.emit(amount)
	changed.emit()
	if health <= 0.0:
		is_dead = true
		died.emit()


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(health + amount, max_health)
	changed.emit()


## Spends stamina if there's enough. Returns false (and spends nothing) if not.
func try_use_stamina(amount: float) -> bool:
	if stamina < amount:
		return false
	use_stamina(amount)
	return true


## Spends up to `amount` stamina (for continuous drains like sprinting).
func use_stamina(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_stamina_delay_left = stamina_regen_delay
	changed.emit()


func try_use_magicka(amount: float) -> bool:
	if magicka < amount:
		return false
	magicka -= amount
	_magicka_delay_left = magicka_regen_delay
	changed.emit()
	return true
