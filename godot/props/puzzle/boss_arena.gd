extends Area3D

# Starts a boss fight when the player walks in: shuts the Gates behind them, wakes
# the Boss and shows its health bar. When the boss dies, the gates open again.
# If the boss was already killed (on an earlier visit), the gates stay open.
# The Area3D's shape should cover the arena floor (mask: player).

@export var boss: NodePath
@export var gates: Array[NodePath] = []

var _started := false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var boss_node := get_node_or_null(boss)
	if boss_node == null or boss_node.is_queued_for_deletion():
		_open_gates.call_deferred()   # beaten before (it removed itself on load)
	else:
		boss_node.died.connect(_on_boss_died)


func _on_body_entered(body: Node) -> void:
	if _started or not body.is_in_group("player"):
		return
	var boss_node := get_node_or_null(boss)
	if boss_node == null or boss_node.is_queued_for_deletion() or boss_node.is_defeated():
		return
	_started = true
	for path in gates:
		var gate := get_node_or_null(path)
		if gate:
			gate.close()
	boss_node.wake(body)
	body.hud.show_boss(boss_node.display_name, boss_node.stats)


func _on_boss_died() -> void:
	_open_gates()
	var player := get_tree().get_first_node_in_group("player")
	if player:
		player.hud.hide_boss()


func _open_gates() -> void:
	for path in gates:
		var gate := get_node_or_null(path)
		if gate:
			gate.open()
