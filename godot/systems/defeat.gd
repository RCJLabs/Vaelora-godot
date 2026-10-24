extends Node

# What happens when you fall in Hardcore: instead of loading a save, you wake up
# wounded somewhere, hours later (LORE.md, "Death"). Normal mode keeps
# reload-your-last-save. Autoloaded as "Defeat".
#
#   Captured       beaten by people who take prisoners (group "captors", e.g. bandits)
#                  in a level with a cell: you wake locked in their cage, without
#                  your gear, which is in a stash nearby. Work the lock to get out.
#                  The level needs a Marker3D "CaptiveCell", a CageDoor and a
#                  loot container "CaptorStash".
#   Found          someone finds you and brings you to the level's Refuge marker;
#                  helping you costs some of your gold.
#   Left for dead  you wake where you fell, hours later.
#
# Every outcome: the Wounded effect (until you sleep 8 hours), low health, time
# passes, enemies go back to where they were, and the game autosaves (as resting
# does), so a defeat can't be undone by loading.

signal defeated(outcome: String)

const HOURS := {"captured": 6.0, "found": 8.0, "left": 5.0}
const HEALTH := {"captured": 0.3, "found": 0.4, "left": 0.25}
## Chance that someone finds you, when the level has a refuge (else left for dead).
const FOUND_CHANCE := 0.6
## Share of your gold it costs when you're found.
const FOUND_FEE := 0.2
## A hit this recent decides who beat you; older than this, it was the wild.
const KILLER_MEMORY_MS := 10000

const MESSAGES := {
	"captured": "Bandits beat you senseless and threw you in their cage. Your gear is in a stash outside it, if you can get out.",
	"left": "You come to where you fell, hours later. Whatever beat you lost interest.",
}

var last_outcome := ""


## True when defeat replaces reloading (Hardcore).
func applies() -> bool:
	return Character.modes.get("hardcore", false)


## Which outcome a defeat by `killer` (or null: the wild, a fall, hunger) gets here.
func choose(killer: Node) -> String:
	var level := get_tree().current_scene
	if killer and is_instance_valid(killer) and killer.is_in_group("captors") and level \
			and level.find_child("CaptiveCell", true, false) and level.find_child("CaptorStash", true, false):
		return "captured"
	if get_tree().get_first_node_in_group("refuge") and randf() < FOUND_CHANCE:
		return "found"
	return "left"


## The full sequence the player's death runs: fade out, wake up, fade in.
func handle(player: Node3D, killer: Node) -> String:
	var outcome := choose(killer)
	var fade := _fade_layer()
	var tween := fade.create_tween()
	tween.tween_property(fade.get_child(0), "color:a", 1.0, 0.8)
	await tween.finished
	wake(player, outcome)
	tween = fade.create_tween()
	tween.tween_interval(0.6)
	tween.tween_property(fade.get_child(0), "color:a", 0.0, 1.4)
	tween.tween_callback(fade.queue_free)
	return outcome


## Applies an outcome at once (the fade is handle()'s job).
func wake(player: Node3D, outcome: String) -> void:
	var hours: float = HOURS[outcome]
	WorldClock.advance(hours)
	Survival.tick(hours, false)
	_reset_enemies()
	# Short effects (bleeding, burning...) have run their course; the defeat leaves its mark.
	for id in player.effects.active.keys():
		var data: StatusEffectData = player.effects.active[id]["data"]
		if data.is_harmful and data.duration > 0.0:
			player.effects.remove(id)
	var stats: Stats = player.stats
	stats.refill()   # back on your feet first: effects don't take on the dead
	player.effects.apply("wounded")
	stats.health = stats.max_health * HEALTH[outcome]
	stats.stamina = stats.max_stamina * 0.5
	stats.magicka = stats.max_magicka * 0.5
	stats.changed.emit()
	player.velocity = Vector3.ZERO
	Engine.time_scale = 1.0
	var message: String = MESSAGES.get(outcome, "")
	match outcome:
		"captured":
			_imprison(player)
		"found":
			var refuge: Node3D = get_tree().get_first_node_in_group("refuge")
			var fee := int(Inventory.gold * FOUND_FEE)
			if fee > 0:
				Inventory.add_gold(-fee)
			_place(player, refuge)
			message = refuge.found_text + ("" if fee <= 0 else " It cost you %d gold." % fee)
	player.is_dead = false
	last_outcome = outcome
	defeated.emit(outcome)
	SaveSystem.save_game(SaveSystem.AUTOSAVE, true)   # before the message: saving shows its own
	player.show_message(message + "\nYou are Wounded until you sleep.")
	Hints.show_once("defeat", "Hardcore: defeat isn't the end. You wake up Wounded (slower, weaker) until you sleep 8 hours at a bed or campfire.")


# Gear and gold go into the captors' stash; you go into the cage.
func _imprison(player: Node3D) -> void:
	var level := get_tree().current_scene
	var stash := level.find_child("CaptorStash", true, false)
	for slot in Inventory.equipped.keys():
		Inventory.unequip(slot)
	var taken: Dictionary = stash.contents.duplicate()
	for id in Inventory.items.keys():
		var amount: int = Inventory.count(id)
		taken[id] = taken.get(id, 0) + amount
		Inventory.remove(id, amount)
	stash.contents = taken
	if Inventory.gold > 0:
		stash.gold += Inventory.gold
		Inventory.add_gold(-Inventory.gold)
	for door in get_tree().get_nodes_in_group("cage_door"):
		door.lock()
	_place(player, level.find_child("CaptiveCell", true, false))


func _place(player: Node3D, marker: Node3D) -> void:
	player.global_position = marker.global_position
	player.rotation.y = marker.global_rotation.y


# Everyone still standing goes back to where they started, healed, and calms down.
func _reset_enemies() -> void:
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
		if enemy.has_method("reset_after_defeat"):
			enemy.reset_after_defeat()
			continue
		var states: Dictionary = enemy.get_script().get_script_constant_map().get("State", {}) if enemy.get_script() else {}
		if states.has("DEAD") and enemy.state == states["DEAD"]:
			continue
		if "home" in enemy:
			enemy.global_position = enemy.home
		if "velocity" in enemy:
			enemy.velocity = Vector3.ZERO
		if states.has("IDLE"):
			enemy.state = states["IDLE"]
		if enemy.get("stats"):
			enemy.stats.refill()


func _fade_layer() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.layer = 90
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(rect)
	add_child(layer)
	return layer
