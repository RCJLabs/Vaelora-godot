extends AnimatableBody3D

# A portcullis that slides up when it's opened, by:
#   - levers: when every lever in Levers matches Combination (on/off), or
#   - activate() from a PressurePlate, or open() / close() from a BossArena.
# Once open it stays open (and remembers it) unless Close When Unsolved is on, in
# which case moving a lever back shuts it again.
# E on the gate shows Locked Message (a place for a clue).

signal opened

@export var levers: Array[NodePath] = []
## The position each lever must be in (true = pulled). Empty: all pulled.
@export var combination: Array[bool] = []
@export var close_when_unsolved := false
@export var open_height: float = 3.2
@export var open_time: float = 1.6
@export_multiline var locked_message: String = "The gate won't budge. Something must raise it."

var is_open := false
var prompt: String:
	get: return "" if is_open else "Examine gate"
var _closed_y := 0.0
var _tween: Tween


func _ready() -> void:
	add_to_group("persistent")
	_closed_y = position.y
	for path in levers:
		var lever := get_node_or_null(path)
		if lever:
			lever.toggled.connect(func(_on): _check_levers())
	WorldState.restore(self)


func interact(player: Node) -> void:
	if not is_open:
		player.show_message(locked_message)


func solved() -> bool:
	if levers.is_empty():
		return false
	for i in levers.size():
		var lever := get_node_or_null(levers[i])
		var want: bool = combination[i] if i < combination.size() else true
		if lever == null or lever.on != want:
			return false
	return true


func _check_levers() -> void:
	if solved():
		open()
	elif close_when_unsolved:
		close()


func activate() -> void:
	open()


func open() -> void:
	if is_open:
		return
	is_open = true
	_slide(_closed_y + open_height)
	Sfx.play_at("gate_rumble", global_position)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_slide(_closed_y)
	Sfx.play_at("gate_rumble", global_position)


func _slide(y: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "position:y", y, open_time).set_trans(Tween.TRANS_SINE)


func get_persist_state() -> Dictionary:
	return {"open": is_open}


func apply_persist_state(state: Dictionary) -> void:
	is_open = state.get("open", false)
	position.y = _closed_y + (open_height if is_open else 0.0)
