extends "res://enemies/wolf.gd"

# The hollow wolf from main quest 1, "Wrong Things": a Greyfang wolf with the
# life drained out of it. Grey all through, eyes dark, and it doesn't fight,
# run or wander. Use it with E: res://dialogue/hollow_wolf.json, where you copy
# the rune-mark on its flank and then put it down or leave it. Killing it with
# a weapon or spell works too (it doesn't fight back), and then you examine the
# body instead.
#
# Story flags: saw_hollow_wolf (the mark is copied), hollow_wolf_killed,
# hollow_wolf_spared. Use it on wolf.tscn with this script swapped in.

const DIALOGUE := "res://dialogue/hollow_wolf.json"
const FUR := Color(0.52, 0.52, 0.5)

var _examined_corpse := false
var glamour_proof := true   # nothing left in it to fool (systems/glamour.gd)


func _ready() -> void:
	super()
	_fur.albedo_color = FUR
	_eyes.emission_energy_multiplier = 0.0
	_eyes.albedo_color = Color(0.15, 0.15, 0.15)
	_eye_glow = 0.0
	model.rotation.x = deg_to_rad(8)   # head low
	if state != State.DEAD:
		collision_layer = 4 | 8   # an enemy body, and layer 4 "loot" so the E ray finds it alive
		prompt = "Examine the hollow wolf"
	GameState.flag_set.connect(_on_flag_set)
	if GameState.has_flag("hollow_wolf_killed") and state != State.DEAD:
		_become_corpse(false)


# It doesn't hunt, wander or answer a blow: it just stands there.
func _think(_player: Node3D, delta: float) -> void:
	_move_toward(global_position, 0.0, delta)


func _start_hunt() -> void:
	pass


func interact(player: Node) -> void:
	if state != State.DEAD:
		DialogueManager.start(DIALOGUE, "Hollow wolf")
		return
	if _examined_corpse:
		return
	_examined_corpse = true
	prompt = ""
	collision_layer = 0
	if not GameState.has_flag("saw_hollow_wolf"):
		Inventory.add("charcoal_rubbing")
		GameState.set_flag("saw_hollow_wolf")
		player.show_message("Burnt into its flank: a circle split by three lines. You copy it with charcoal from your pack.")


# The dialogue's "put it out of its misery" sets the flag; this does the rest.
func _on_flag_set(flag: String) -> void:
	if flag == "hollow_wolf_killed" and state != State.DEAD:
		stats.take_damage(stats.health * 10.0, true)   # past armour and resistances


func _on_died() -> void:
	GameState.set_flag("hollow_wolf_killed")
	super()


func _become_corpse(animate: bool) -> void:
	super(animate)
	# A thin thread of pale light leaves it. (Nothing to skin: the pelt is ash.)
	if GameState.has_flag("saw_hollow_wolf"):
		_examined_corpse = true
		prompt = ""
		collision_layer = 0
	else:
		prompt = "Examine the hollow wolf"


func _on_damaged(_amount: float) -> void:
	if _flash_tween:
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_fur, "albedo_color", Color(0.8, 0.8, 0.85), 0.05)
	_flash_tween.tween_property(_fur, "albedo_color", FUR, 0.3)


func get_persist_state() -> Dictionary:
	var data := super()
	data["examined"] = _examined_corpse
	return data


func apply_persist_state(saved: Dictionary) -> void:
	super(saved)
	if saved.get("examined", false):
		_examined_corpse = true
		prompt = ""
		collision_layer = 0
