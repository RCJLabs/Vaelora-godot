extends StaticBody3D

# The crystal at the heart of the stone circle: hovers, turns slowly, and
# flares when touched (E). The first touch teaches the Flames spell.
# In "The Waking Stones", if you chose to return the rune shards, touching it
# with three shards restores the stones (+10 max Magicka, brighter crystal).
# Once the shards are dealt with, either way, touching it shows the drain-line:
# something is pulling magic through it, north into the Thornwood (the
# "saw_drain_line" flag, which a DrainLine node in the level shows).

@export var bob_height: float = 0.12
@export var spin_speed: float = 0.4   # radians per second

var prompt: String = "Touch the crystal"

@onready var gem: Node3D = $Gem
@onready var light: OmniLight3D = $Light
@onready var base_light_energy: float = light.light_energy

var _time := 0.0


func _ready() -> void:
	if GameState.has_flag("stones_restored"):
		_brighten()


func _brighten() -> void:
	base_light_energy *= 2.0
	light.light_energy = base_light_energy


func _process(delta: float) -> void:
	_time += delta
	gem.rotation.y += spin_speed * delta
	gem.position.y = sin(_time * 1.3) * bob_height


func interact(player: Node) -> void:
	if GameState.has_flag("shards_chose_stones") and not GameState.has_flag("stones_restored") \
			and Inventory.count("rune_shard") >= 3:
		Inventory.remove("rune_shard", 3)
		Skills.grant_bonus("magicka", 10)
		_brighten()
		GameState.set_flag("stones_restored")
		GameState.set_flag("saw_drain_line")
		GameState.set_flag("stones_quest_done")
		player.show_message("The shards rise from your hands and sink into the crystal. Light floods the circle - and some of it stays with you. (+10 Magicka) In the glare, a thread of light runs out of the crystal, north towards the forest.")
	elif GameState.has_flag("shards_decided") and not GameState.has_flag("shards_chose_stones") \
			and not GameState.has_flag("saw_drain_line"):
		GameState.set_flag("saw_drain_line")
		player.show_message("Without the shards the crystal flickers, and in the flicker you see it: a thread of light running out of it, north towards the forest. Something is drawing on it.")
	elif not Spellbook.knows("flames"):
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
