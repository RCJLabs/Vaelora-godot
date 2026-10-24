extends Node3D

# Put wolves, bandits (or any enemy with a `died` signal) under this node.
# When all of them are dead, sets `cleared_flag` - quests and dialogue check it.
# When one starts hunting the player, the others join in (alert()).
# On load, if the flag is already set, the pack doesn't respawn (bodies that
# WorldState restored stay, so unsearched loot isn't lost). Individual dead
# members are remembered by WorldState, so a half-killed pack stays that way.
#
# Morale (can_break, for animals): every point of damage to the pack adds to its
# fear, twice as much while the hurt member is burning, and a member's death adds
# death_fear. At break_fear the pack breaks and the living run. Once every member
# is dead or has run off for good, the pack is cleared; if any ran, it's also
# driven off (driven_off_flag). Run them all down instead and it's a plain kill.
# With the defaults and three wolves: kill one and land one more hit, or burn them.
# Saving while they're still running and loading brings them back home, unbroken.

@export var cleared_flag: String = "wolves_cleared"
@export_multiline var cleared_message: String = "The last of the Greyfang pack falls."
@export var can_break: bool = false
@export var break_fear: float = 100.0
@export var death_fear: float = 60.0
@export var driven_off_flag: String = "wolves_driven_off"
@export_multiline var driven_off_message: String = "The Greyfang pack breaks and scatters into the hills."

var fear := 0.0
var broken := false
var _alive := 0
var _gone := 0
var _health := {}   # member -> Health when last hurt, so overkill doesn't count


func _ready() -> void:
	var members := get_children().filter(func(c): return c.has_signal("died"))
	if GameState.has_flag(cleared_flag):
		for member in members:
			if member.get("state") == null or member.state != member.State.DEAD:
				member.queue_free()
		return
	# Members restore themselves first (WorldState); only count the living.
	for member in members:
		if member.get("state") != null and member.state == member.State.DEAD:
			continue
		_alive += 1
		member.died.connect(_on_member_died)
		if member.get("stats"):
			_health[member] = member.stats.health
			member.stats.damaged.connect(_on_member_damaged.bind(member))


## A member started hunting: the rest of the pack joins in.
func alert(_by: Node) -> void:
	for member in get_children():
		if member.has_method("join_hunt"):
			member.join_hunt()


func _on_member_damaged(_amount: float, member: Node) -> void:
	var lost: float = maxf(_health[member] - member.stats.health, 0.0)
	_health[member] = member.stats.health
	if broken or not can_break:
		return
	var burning: bool = member.get("effects") != null and member.effects.has("burning")
	_add_fear(lost * (2.0 if burning else 1.0))


func _add_fear(amount: float) -> void:
	fear += amount
	if fear >= break_fear and _alive > 0 and not broken:
		_break()


# The living run (wolf.gd flee()); each one that gets away calls member_gone().
func _break() -> void:
	broken = true
	for member in get_children():
		if member.has_method("flee") and member.get("state") != member.State.DEAD:
			member.flee()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.show_message(driven_off_message)


## A fleeing member got away: it's gone for good.
func member_gone(_member: Node) -> void:
	_alive -= 1
	_gone += 1
	_check_cleared()


## Fear fades once the whole pack has given up and gone home to rest.
func _physics_process(_delta: float) -> void:
	if fear > 0.0 and not broken and get_children().all(func(m): return m.get("state") == null or m.state == m.State.IDLE or m.state == m.State.DEAD):
		fear = 0.0
		for member in _health:
			if is_instance_valid(member):
				_health[member] = member.stats.health   # refilled at the den


func _on_member_died() -> void:
	_alive -= 1
	if can_break and _alive > 0:
		_add_fear(death_fear)
	_check_cleared()


func _check_cleared() -> void:
	if _alive > 0:
		return
	GameState.set_flag(cleared_flag)
	if _gone > 0:
		GameState.set_flag(driven_off_flag)
		return   # the break already said so
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.show_message(cleared_message)
