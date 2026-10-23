class_name ItemData
extends Resource

# One kind of item. Each item is a .tres file in res://items/ - double-click it to
# edit in the Inspector. Register new files in ITEM_FILES in systems/inventory.gd.

enum Type { MISC, CONSUMABLE }

## Unique name used in code, dialogue JSON and save files. Don't change it once
## saves exist.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var type: Type = Type.MISC
## Price in gold when sold.
@export var value: int = 0

@export_group("When used (consumables)")
@export var restore_health: float = 0.0
@export var restore_stamina: float = 0.0
@export var restore_magicka: float = 0.0
