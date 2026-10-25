extends StaticBody3D

# A plant you can pick (the Survival skill, systems/bushcraft.gd): E gives its
# ingredient, then it's bare until it grows back a few days later. Builds its
# own greybox bush and flowers in `color`. Saved (WorldState).

@export var item_id: String = "mountain_flower"
@export var amount: int = 1
@export var regrow_days: int = 3
@export var color: Color = Color(0.95, 0.95, 0.9)

var picked_at := -1.0           # WorldClock time (days * 24 + hour) it was picked, -1 if it's ready
var _flowers: Node3D

var prompt: String:
	get: return "Pick %s" % Inventory.get_item(item_id).display_name if is_ready() else ""


func _ready() -> void:
	add_to_group("persistent")
	add_to_group("forage_plant")
	var bush := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.35
	sphere.height = 0.45
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.25, 0.42, 0.2)
	sphere.material = leaf
	bush.mesh = sphere
	bush.position = Vector3(0, 0.2, 0)
	add_child(bush)
	_flowers = Node3D.new()
	add_child(_flowers)
	for spot in [Vector3(0.15, 0.42, 0.05), Vector3(-0.12, 0.4, 0.12), Vector3(0.02, 0.45, -0.15)]:
		var bloom := MeshInstance3D.new()
		var ball := SphereMesh.new()
		ball.radius = 0.07
		ball.height = 0.14
		var petal := StandardMaterial3D.new()
		petal.albedo_color = color
		ball.material = petal
		bloom.mesh = ball
		bloom.position = spot
		_flowers.add_child(bloom)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.7, 0.5, 0.7)
	shape.shape = box
	shape.position = Vector3(0, 0.25, 0)
	add_child(shape)
	collision_layer = 8   # "loot": walk through it, the interaction ray still finds it
	collision_mask = 0
	WorldState.restore(self)
	_show()


func is_ready() -> bool:
	return picked_at < 0.0 or _now() - picked_at >= Bushcraft.regrow_days(regrow_days) * 24.0


func _now() -> float:
	return WorldClock.day * 24.0 + WorldClock.hour


func interact(player: Node) -> void:
	if not is_ready():
		return
	var got: Dictionary = Bushcraft.forage(item_id, amount)
	picked_at = _now()
	player.hud.notify("Picked " + ", ".join(got.keys().map(func(id): return "%s ×%d" % [Inventory.get_item(id).display_name, got[id]])))
	_show()


func _process(_delta: float) -> void:
	if _flowers.visible != is_ready():
		_show()


func _show() -> void:
	if picked_at >= 0.0 and is_ready():
		picked_at = -1.0
	_flowers.visible = is_ready()


func get_persist_state() -> Dictionary:
	return {"picked_at": picked_at}


func apply_persist_state(state: Dictionary) -> void:
	picked_at = float(state.get("picked_at", -1.0))
