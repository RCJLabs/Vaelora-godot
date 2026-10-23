class_name ItemData
extends Resource

# One kind of item. Each item is a .tres file in res://items/ - double-click it to
# edit in the Inspector. Register new files in ITEM_FILES in systems/inventory.gd.

enum Type { MISC, CONSUMABLE, WEAPON, ARMOR }
## Where armour is worn. Weapons always go in MAIN_HAND.
enum Slot { NONE, MAIN_HAND, OFF_HAND, HEAD, BODY, HANDS, FEET, RING, AMULET }

## Unique name used in code, dialogue JSON and save files. Don't change it once
## saves exist.
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var type: Type = Type.MISC
## Price in gold when sold.
@export var value: int = 0
## Kilograms. Used once carry weight exists.
@export var weight: float = 0.0

@export_group("When used (consumables)")
@export var restore_health: float = 0.0
@export var restore_stamina: float = 0.0
@export var restore_magicka: float = 0.0

@export_group("Weapon")
@export var damage: float = 0.0
## Only used when Light Attacks is empty: roughly the seconds between swings.
@export var attack_cooldown: float = 0.55
## Metres in front of the camera the swing reaches.
@export var reach: float = 1.8
@export var stamina_cost: float = 10.0
## Skill that improves with hits and boosts damage.
@export var weapon_skill: String = "one_handed"
## First-person model shown in the right hand (a scene with meshes).
@export var held_scene: PackedScene
## The light combo, in order (click, click, click). Empty = one simple swing.
@export var light_attacks: Array[AttackData] = []
## Hold attack to charge, release to strike.
@export var heavy_attack: AttackData
## Share of a hit's damage stopped while blocking with this weapon (0-1).
@export var block_reduction: float = 0.6

@export_group("Armor")
@export var slot: Slot = Slot.NONE
@export var armor: float = 0.0


func is_equipment() -> bool:
	return type == Type.WEAPON or type == Type.ARMOR


## The slot this item goes in, as a name used by Inventory ("main_hand", "body"...).
func slot_name() -> String:
	if type == Type.WEAPON:
		return "main_hand"
	return Slot.keys()[slot].to_lower()
