extends StaticBody3D

# A pressure plate: stepping on it (player or enemy) sets off the traps listed in
# Targets (anything with an activate() method: DartTrap, SwingingBlade, PuzzleGate).
# It sits a little proud of the floor in paler stone, so a careful player can spot
# it and step around, or press E to disarm it. Agility helps; a failed try sets it off.
#
# Scene: PressurePlate (StaticBody3D, this) ├── Mesh ├── Shape └── Trigger (Area3D,
# mask: player + enemies, a shape a little taller than the plate).

signal triggered

@export var targets: Array[NodePath] = []
## Seconds before it can go off again. 0: only once.
@export var rearm_time: float = 3.0
## Chance to disarm with base Agility; each Agility point above base adds 5%.
@export var disarm_chance: float = 0.55

@onready var trigger: Area3D = $Trigger
@onready var mesh: Node3D = $Mesh

var disarmed := false
var spent := false
var prompt: String:
	get: return "" if disarmed or spent else "Disarm pressure plate"
var _rearm_left := 0.0
var _mesh_y := 0.0


func _ready() -> void:
	add_to_group("persistent")
	_mesh_y = mesh.position.y
	trigger.body_entered.connect(_on_body_entered)
	WorldState.restore(self)


func _process(delta: float) -> void:
	if _rearm_left > 0.0:
		_rearm_left -= delta
		if _rearm_left <= 0.0:
			mesh.position.y = _mesh_y   # pops back up


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player") and Stealth.is_sneaking() and Stealth.has_perk("light_foot"):
		return   # Light Foot (Sneak): a careful step doesn't press it
	if body.is_in_group("player") or body.is_in_group("enemy"):
		fire()


## Sets off the traps (if armed).
func fire() -> void:
	if disarmed or spent or _rearm_left > 0.0:
		return
	if rearm_time > 0.0:
		_rearm_left = rearm_time
	else:
		spent = true
	mesh.position.y = _mesh_y - 0.04   # sinks
	Sfx.play_at("trap_click", global_position)
	for path in targets:
		var target := get_node_or_null(path)
		if target and target.has_method("activate"):
			target.activate()
	triggered.emit()
	Hints.show_once("traps", "Pressure plates sit a little proud of the floor. Step around them, or press %s on one to try disarming it (Agility helps)." % Hints.key("interact"))


func interact(player: Node) -> void:
	if disarmed or spent:
		return
	var chance := clampf(disarm_chance + Attributes.above_base("agility") * 0.05, 0.05, 0.95)
	if randf() < chance:
		disarmed = true
		mesh.position.y = _mesh_y - 0.02
		Sfx.play_at("trap_click", global_position, -8.0)
		player.show_message("You wedge the plate. It won't trigger now.")
	else:
		player.show_message("Click. You slipped.")
		fire()


func get_persist_state() -> Dictionary:
	return {"disarmed": disarmed, "spent": spent}


func apply_persist_state(state: Dictionary) -> void:
	disarmed = state.get("disarmed", false)
	spent = state.get("spent", false)
	if disarmed or spent:
		mesh.position.y = _mesh_y - 0.03
