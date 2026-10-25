extends Node

# Who's travelling with you. Autoloaded as "Companions". One companion at a time.
#
# Following is a story flag, "companion_<id>", so it saves and loads with
# everything else: a dialogue choice sets it to recruit someone, and this node
# makes them appear behind you (and hides the person at their post, whose
# StoryPresence has hide_flag "companion_<id>"). In the level, they're a
# companion.gd body.
#
# Their own dialogue (dialogue/companion_<id>.json) gives orders by setting a
# command flag, which is acted on and cleared at once:
#   companion_cmd_wait     wait here
#   companion_cmd_follow   follow again
#   companion_cmd_dismiss  go home (back to their post)
#   companion_cmd_talk     their usual conversation (the one at their post), since
#                          the person at the post is away while they're with you
#
# Approval (-100..100, saved): how they feel about you. While they're following,
# story flags they care about move it and get a remark (companions/<id>.json
# "reactions"); now and then, out of a fight, they say something (its "banter",
# each line once, gated by the usual conditions). At LEAVE_AT or below they walk
# out ("left_you_<id>") and won't come back. Dialogue reads it with
# "requires_approval" / "requires_approval_below" and changes it with
# "add_approval" (systems/conditions.gd, ui/dialogue_manager.gd).

const DEFS := {
	"brannoc": {"name": "Brannoc", "dialogue": "res://dialogue/companion_brannoc.json", "npc_dialogue": "res://dialogue/brannoc.json", "health": 150.0, "damage": 12.0, "reach": 1.9},
	"zora": {"name": "Zora", "dialogue": "res://dialogue/companion_zora.json", "npc_dialogue": "res://dialogue/zora.json", "health": 90.0, "damage": 9.0, "reach": 6.0, "attack_interval": 1.6, "ranged": true},
}
const COMMANDS := ["companion_cmd_wait", "companion_cmd_follow", "companion_cmd_dismiss", "companion_cmd_talk"]
const COMPANION_SCRIPT := preload("res://companions/companion.gd")
const LEAVE_AT := -40
## Seconds of following (out of a fight) between remarks.
const BANTER_EVERY := 150.0

signal said(id: String, line: String)

var approval := {}   # id -> -100..100
var health := {}     # id -> their health, kept across levels and saves (missing: full)
var _said := {}      # id -> [banter ids already said]
var _talk := {}      # id -> {"reactions": {...}, "banter": [...], "leave_line": "..."}
var _banter_left := BANTER_EVERY


func _ready() -> void:
	for id in DEFS:
		var file := "res://companions/%s.json" % id
		_talk[id] = JSON.parse_string(FileAccess.get_file_as_string(file)) if FileAccess.file_exists(file) else {}
	reset()
	GameState.flag_set.connect(_on_flag_set)


func reset() -> void:
	for id in DEFS:
		approval[id] = 0
		_said[id] = []
	health = {}
	_banter_left = BANTER_EVERY


func to_dict() -> Dictionary:
	return {"approval": approval.duplicate(), "said": _said.duplicate(true), "health": health.duplicate()}


func from_dict(data: Dictionary) -> void:
	reset()
	for id in data.get("approval", {}):
		approval[id] = int(data["approval"][id])
	for id in data.get("said", {}):
		_said[id] = Array(data["said"][id])
	for id in data.get("health", {}):
		health[id] = float(data["health"][id])


## Changes how `id` feels about you. Below LEAVE_AT while following, they leave.
func add_approval(id: String, amount: int) -> void:
	if not approval.has(id) or amount == 0:
		return
	if amount > 0:
		amount = roundi(amount * Character.modifier("approval_gain"))   # Trusted (Speech)
	approval[id] = clampi(approval[id] + amount, -100, 100)
	if active() == id and approval[id] <= (-80 if "beloved" in Character.perks else LEAVE_AT):   # Beloved (Command)
		say(id, _talk[id].get("leave_line", "I'm done. Find someone else."))
		var companion := body()
		if companion:
			companion.queue_free()
		GameState.clear_flag("companion_" + id)
		GameState.set_flag("left_you_" + id)


## A remark from `id`, shown to the player.
func say(id: String, line: String) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("hud"):
		player.hud.show_message("%s: \"%s\"" % [DEFS[id]["name"], line], 6.0)
	said.emit(id, line)


## The id of whoever's following you, or "".
func active() -> String:
	for id in DEFS:
		if GameState.has_flag("companion_" + id):
			return id
	return ""


## Their body in the current level, if they're in it.
func body() -> Node3D:
	var id := active()
	if id == "" or get_tree().current_scene == null:
		return null
	return get_tree().current_scene.get_node_or_null("Companion_" + id) as Node3D


func _process(delta: float) -> void:
	var id := active()
	_tick_banter(id, delta)
	var here := body()
	if here:
		health[id] = here.health
	# No longer following (the flag was cleared some other way than "Go home"): gone.
	for companion in get_tree().get_nodes_in_group("companion"):
		if companion.companion_id != id and not companion.is_queued_for_deletion():
			companion.queue_free()
	# Arriving in a level (or loading a save) with someone following: bring them along.
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if id != "" and player and body() == null:
		var companion := COMPANION_SCRIPT.new()
		companion.setup(id, DEFS[id])
		if health.has(id):
			# As you left them; down when you left means getting up as they arrive.
			companion.health = health[id] if health[id] > 0.0 else companion.max_health * companion.GOT_UP
		get_tree().current_scene.add_child(companion)
		companion.arrive_behind(player)
		Hints.show_once("command", "%s is with you. Aim at an enemy and press %s to send them at it (the Command skill)." % [DEFS[id]["name"], Hints.key("command")])


# Every BANTER_EVERY seconds of following, out of a fight: the next line they haven't said.
func _tick_banter(id: String, delta: float) -> void:
	var companion := body()
	if companion == null or get_tree().paused or DialogueManager.is_active or companion.target or companion.is_down:
		return
	_banter_left -= delta
	if _banter_left > 0.0:
		return
	_banter_left = BANTER_EVERY
	for line in _talk[id].get("banter", []):
		if not line["id"] in _said[id] and Conditions.met(line):
			_said[id].append(line["id"])
			say(id, line["line"])
			return


func _on_flag_set(flag: String) -> void:
	var id := active()
	if id != "" and _talk[id].get("reactions", {}).has(flag):
		var reaction: Dictionary = _talk[id]["reactions"][flag]
		say(id, reaction["line"])
		add_approval(id, int(reaction.get("approval", 0)))
	if not flag in COMMANDS:
		return
	GameState.clear_flag(flag)   # an order, not a memory
	var companion := body()
	match flag:
		"companion_cmd_wait":
			if companion:
				companion.order(companion.State.WAIT)
		"companion_cmd_follow":
			if companion:
				companion.order(companion.State.FOLLOW)
		"companion_cmd_dismiss":
			if companion:
				companion.queue_free()
			health.erase(active())   # rested by the time you see them again
			GameState.clear_flag("companion_" + active())
		"companion_cmd_talk":
			# After this conversation has closed (the choice that sets this ends it).
			var npc: Dictionary = DEFS.get(active(), {})
			if npc.has("npc_dialogue"):
				DialogueManager.start.call_deferred(npc["npc_dialogue"], npc["name"])
