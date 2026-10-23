extends Node

# Every status effect in the game, by id. Autoloaded as "EffectLibrary".

## Add new effect files here.
const EFFECT_FILES := [
	"res://effects/bleeding.tres",
	"res://effects/burning.tres",
	"res://effects/poisoned.tres",
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
