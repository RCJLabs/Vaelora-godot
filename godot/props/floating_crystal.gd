extends StaticBody3D

# The crystal at the heart of the stone circle: hovers, turns slowly, and
# flares when touched (E). The first touch teaches the Flames spell.

@export var bob_height: float = 0.12
@export var spin_speed: float = 0.4   # radians per second

var prompt: String = "Touch the crystal"

@onready var gem: Node3D = $Gem
@onready var light: OmniLight3D = $Light
@onready var base_light_energy: float = light.light_energy

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	gem.rotation.y += spin_speed * delta
	gem.position.y = sin(_time * 1.3) * bob_height


func interact(player: Node) -> void:
	if not Spellbook.knows("flames"):
		GameState.set_flag("touched_crystal")
		Spellbook.learn("flames")
		Spellbook.select("flames")
		player.show_message("Cold light runs up your arm, and fire answers. (Right-click to cast, Q to switch spells.)")
	elif not GameState.has_flag("touched_crystal"):
		GameState.set_flag("touched_crystal")
		player.show_message("The crystal hums, and the fire you already carry stirs in answer.")
	else:
		player.show_message("The crystal hums softly. It remembers you.")
	var tween := create_tween()
	tween.tween_property(light, "light_energy", base_light_energy * 4.0, 0.15)
	tween.tween_property(light, "light_energy", base_light_energy, 1.2)
