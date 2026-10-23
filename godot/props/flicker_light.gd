extends OmniLight3D

# Torch / candle flicker: wobbles the light's energy around its starting value.

@export var amount: float = 0.25   # fraction of the base energy
@export var speed: float = 9.0

@onready var _base := light_energy
var _t := randf() * 100.0


func _process(delta: float) -> void:
	_t += delta * speed
	light_energy = _base * (1.0 + amount * (sin(_t) * 0.6 + sin(_t * 2.7) * 0.4))
