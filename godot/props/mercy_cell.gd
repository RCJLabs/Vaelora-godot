extends "res://enemies/wolf_pack.gd"

# A small cell of the Mercy (docs/lore/STORY.md): two of the merciful at a marked
# stone, and Sister Halina, who talks before anyone fights. Choose to fight
# (dialogue sets fight_flag) and both come for you at once; attack one first and
# the other joins in, as any pack does. Kill them both and the pack's
# cleared_flag is set. Let them go and the cell's StoryPresence takes them away.

## Set by Halina's dialogue when you choose to fight.
@export var fight_flag: String = "mercy_cell_fight"


func _ready() -> void:
	super()
	GameState.flag_set.connect(func(flag): if flag == fight_flag: alert(null))
