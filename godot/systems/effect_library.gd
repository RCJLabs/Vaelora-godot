extends Node

# Every status effect in the game, by id. Autoloaded as "EffectLibrary".

## Add new effect files here.
const EFFECT_FILES := [
	"res://effects/bleeding.tres",
	"res://effects/bound.tres",
	"res://effects/venom.tres",
	"res://effects/arrow_pinned.tres",
	"res://effects/commanded.tres",
	"res://effects/guarded.tres",
	"res://effects/avenging.tres",
	"res://effects/well_fed_skewer.tres",
	"res://effects/well_fed_stew.tres",
	"res://effects/well_fed_bread.tres",
	"res://effects/well_fed_tea.tres",
	"res://effects/potion_regeneration.tres",
	"res://effects/potion_swiftness.tres",
	"res://effects/potion_might.tres",
	"res://effects/potion_resist.tres",
	"res://effects/hollowed.tres",
	"res://effects/weak_point.tres",
	"res://effects/weak_point_deep.tres",
	"res://effects/ill_fortune.tres",
	"res://effects/bad_omen.tres",
	"res://effects/foresight.tres",
	"res://effects/true_sight.tres",
	"res://effects/moment_of_clarity.tres",
	"res://effects/rune_ward.tres",
	"res://effects/rune_ward_steady.tres",
	"res://effects/rune_ward_renewal.tres",
	"res://effects/rune_blade.tres",
	"res://effects/burning.tres",
	"res://effects/poisoned.tres",
	# powers (res://character/abilities.json)
	"res://effects/adaptable.tres",
	"res://effects/innate_focus.tres",
	"res://effects/battle_fury.tres",
	"res://effects/shadowstep.tres",
	"res://effects/invisible.tres",
	"res://effects/hunters_focus.tres",
	"res://effects/blessing.tres",
	"res://effects/steady_nerves.tres",
	# the stone circle: releasing a Wisp Essence (props/floating_crystal.gd)
	"res://effects/wisp_grace.tres",
	# spells
	"res://effects/chilled.tres",
	"res://effects/mending.tres",
	"res://effects/stoneflesh.tres",
	"res://effects/candlelight.tres",
	"res://effects/pinned.tres",
	# carrying too much (player_first_person.gd)
	"res://effects/over_encumbered.tres",
	# survival (systems/survival.gd) and resting
	"res://effects/survival_peckish.tres",
	"res://effects/survival_hungry.tres",
	"res://effects/survival_starving.tres",
	"res://effects/survival_thirsty.tres",
	"res://effects/survival_parched.tres",
	"res://effects/survival_dehydrated.tres",
	"res://effects/survival_tired.tres",
	"res://effects/survival_weary.tres",
	"res://effects/survival_exhausted.tres",
	"res://effects/survival_chilly.tres",
	"res://effects/survival_cold.tres",
	"res://effects/survival_freezing.tres",
	"res://effects/well_rested.tres",
	"res://effects/wounded.tres",
]

var _catalog: Dictionary = {}


func _ready() -> void:
	for path in EFFECT_FILES:
		var effect: StatusEffectData = load(path)
		_catalog[effect.id] = effect


func get_effect(id: String) -> StatusEffectData:
	if not _catalog.has(id):
		push_error("EffectLibrary: unknown effect '%s'. Is it listed in EFFECT_FILES?" % id)
	return _catalog.get(id)
