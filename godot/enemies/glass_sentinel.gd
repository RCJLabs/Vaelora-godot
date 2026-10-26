extends "res://enemies/stone_guardian.gd"

# The Glass Sentinel: what the Glass College's founders left to keep the vault
# under the Scar (docs/godot-starter/GLASS_COAST.md). It fights exactly like the
# Stone Guardian (use it on stone_guardian.tscn with this script swapped in: slam,
# sweep, shockwaves at half health), but it's glass, fused in the Mage War, with
# light caught inside it; and beating it sets `defeated_flag` for the quest.

@export var defeated_flag: String = "glass_sentinel_down"

const GLASS := Color(0.6, 0.85, 0.9)


func _ready() -> void:
	super()
	body_color = GLASS
	_stone_material.albedo_color = GLASS
	_stone_material.metallic = 0.3
	_stone_material.roughness = 0.08
	_stone_material.emission_enabled = true
	_stone_material.emission = Color(0.35, 0.75, 0.85)
	_stone_material.emission_energy_multiplier = 0.4


func _on_died() -> void:
	super()
	GameState.set_flag(defeated_flag)
