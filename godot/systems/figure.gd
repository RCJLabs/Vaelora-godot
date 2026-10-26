class_name Figure
extends RefCounted

# Greybox people, until there's art: a body built from simple meshes, shaped by
# race (height, build, skin, a feature or two) and dressed by role (a helmet and
# spear, a pack, a robe and hood...), so you can tell who's who at a glance. Used
# by NPCs (interactables/npc.gd: set Race and Role) and the third-person player
# body (player/player_view.gd). docs/godot-starter/LOOK.md.
#
# Faces point down -Z, Godot's forward. Everything sits on the origin's floor.

## Race id (RaceData file name: "small_folk") -> shape.
## h: height and w: breadth (1 = human), skin, head: head size, eyes, hair (none: bald), feature.
const RACES := {
	"human": {"h": 1.0, "w": 1.0, "skin": Color(0.72, 0.55, 0.42), "head": 1.0, "eyes": Color(0.12, 0.1, 0.08), "hair": Color(0.25, 0.17, 0.1)},
	"elf": {"h": 1.06, "w": 0.86, "skin": Color(0.86, 0.76, 0.66), "head": 0.95, "eyes": Color(0.2, 0.35, 0.3), "feature": "ears", "hair": Color(0.8, 0.72, 0.5)},
	"orc": {"h": 1.05, "w": 1.25, "skin": Color(0.4, 0.48, 0.32), "head": 1.08, "eyes": Color(0.25, 0.08, 0.05), "feature": "tusks", "hair": Color(0.08, 0.07, 0.06)},
	"small_folk": {"h": 0.68, "w": 0.95, "skin": Color(0.78, 0.6, 0.46), "head": 1.2, "eyes": Color(0.15, 0.1, 0.05), "feature": "curls"},
	"deepfolk": {"h": 0.8, "w": 1.32, "skin": Color(0.68, 0.45, 0.36), "head": 1.1, "eyes": Color(0.1, 0.08, 0.06), "feature": "beard", "hair": Color(0.4, 0.22, 0.12)},
	"ashen": {"h": 1.04, "w": 0.84, "skin": Color(0.56, 0.57, 0.6), "head": 0.95, "eyes": Color(0.85, 0.9, 1.0), "glow": true},
	"passenger": {"h": 1.12, "w": 0.78, "skin": Color(0.82, 0.8, 0.76), "head": 0.92, "eyes": Color(0.75, 0.85, 0.95), "glow": true, "hair": Color(0.9, 0.9, 0.88)},
}

## Role -> clothes and kit. Unknown roles dress as commoners.
const ROLES := ["commoner", "child", "guard", "merchant", "innkeeper", "priest", "scholar",
		"worker", "hunter", "official", "physician", "inquisitor", "mercy", "bandit"]

const METAL := Color(0.55, 0.56, 0.6)
const LEATHER := Color(0.3, 0.2, 0.12)
const LINEN := Color(0.78, 0.74, 0.64)
const HAIR := Color(0.25, 0.17, 0.1)

static var _mats := {}


## RaceData display name ("Small Folk") or file name -> a key in RACES ("small_folk").
static func race_key(race: String) -> String:
	var key := race.strip_edges().to_lower().replace(" ", "_")
	return key if RACES.has(key) else "human"


## How tall a race stands, against a human's 1.0.
static func height_of(race: String) -> float:
	var h: float = RACES[race_key(race)]["h"]
	return h


## A person: race (key or display name), role (one of ROLES), cloth (their clothes'
## colour). sitting folds the legs under them (on a bench or the ground). Meshes go
## on render `layers`. Without `arms`, the arms are left off for the caller to hang
## on its own shoulder pivots (arm()); `own_cloth` gives the clothes a material of
## their own (meta "cloth_material"), so tinting it, as a hit flash does, tints only
## this one.
static func build(race: String, role: String, cloth: Color, sitting := false, layers := 1, arms := true, own_cloth := false) -> Node3D:
	var r: Dictionary = RACES[race_key(race)]
	var h: float = r["h"]
	var w: float = r["w"]
	var head_size: float = r["head"]
	if role == "child":
		h *= 0.62
		head_size *= 1.2
	var root := Node3D.new()
	root.name = "Figure"
	var cloth_mat := _new_mat(cloth) if own_cloth else _mat(cloth, false)
	root.set_meta("cloth_material", cloth_mat)
	var trousers := cloth.darkened(0.45)
	var robed := role in ["priest", "scholar", "physician", "inquisitor", "mercy"]
	var drop := 0.42 * h if sitting else 0.0   # sitting: the seat is at knee height

	# Legs and body.
	if robed and not sitting:
		_part(root, _cyl(0.2 * w, 0.36 * w, 1.3 * h), Vector3(0, 0.65 * h, 0), cloth).material_override = cloth_mat
	else:
		for side in [-1.0, 1.0]:
			if sitting:
				_part(root, _capsule(0.085 * w, 0.48 * h), Vector3(side * 0.1 * w, 0.46 * h - drop + 0.05, -0.2 * h), trousers, Vector3(PI / 2.0, 0, 0))
				_part(root, _capsule(0.08 * w, 0.46 * h), Vector3(side * 0.1 * w, 0.23 * h, -0.42 * h), trousers)
			else:
				_part(root, _capsule(0.09 * w, 0.86 * h), Vector3(side * 0.1 * w, 0.43 * h, 0), trousers)
		if robed:
			_part(root, _cyl(0.24 * w, 0.3 * w, 0.4 * h), Vector3(0, 0.9 * h - drop, 0), cloth).material_override = cloth_mat
	_part(root, _capsule(0.22 * w, 0.78 * h), Vector3(0, 1.13 * h - drop, 0), cloth).material_override = cloth_mat
	if arms:
		for side in [-1.0, 1.0]:
			_part(root, _capsule(0.065 * w, 0.68 * h), Vector3(side * 0.28 * w, 1.1 * h - drop, 0), cloth, Vector3(0, 0, side * 0.08)).material_override = cloth_mat
			_part(root, _sphere(0.055 * w), Vector3(side * 0.3 * w, 0.75 * h - drop, 0), r["skin"])

	# Head and face.
	var head_y := 1.42 * h + 0.16 * head_size - drop
	var head_r := 0.14 * head_size
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, head_y, 0)
	root.add_child(head)
	_part(head, _sphere(head_r), Vector3.ZERO, r["skin"])
	for side in [-1.0, 1.0]:
		_part(head, _box(Vector3(0.035, 0.03, 0.02) * head_size), Vector3(side * 0.05 * head_size, 0.02 * head_size, -head_r * 0.93), r["eyes"], Vector3.ZERO, r.get("glow", false))
	_part(head, _box(Vector3(0.03, 0.05, 0.04) * head_size), Vector3(0, -0.02 * head_size, -head_r), r["skin"].darkened(0.1))
	if r.has("hair"):
		_part(head, _sphere(head_r * 1.02), Vector3(0, head_r * 0.3, head_r * 0.25), r["hair"])   # top and back: the face shows
	match r.get("feature", ""):
		"ears":
			for side in [-1.0, 1.0]:
				_part(head, _box(Vector3(0.02, 0.1, 0.05)), Vector3(side * head_r * 0.98, 0.04, 0.0), r["skin"], Vector3(0, 0, -side * 0.6))
		"tusks":
			for side in [-1.0, 1.0]:
				_part(head, _box(Vector3(0.025, 0.05, 0.025)), Vector3(side * 0.04, -head_r * 0.55, -head_r * 0.85), LINEN)
		"beard":
			_part(head, _box(Vector3(0.2, 0.2, 0.08) * head_size), Vector3(0, -head_r * 0.85, -head_r * 0.62), r["hair"])
		"curls":
			_part(head, _sphere(head_r * 1.04), Vector3(0, head_r * 0.25, head_r * 0.15), HAIR)

	# What their work puts on them.
	match role:
		"guard":
			_part(head, _cyl(head_r * 1.08, head_r * 1.16, head_r * 0.8), Vector3(0, head_r * 0.55, 0), METAL)
			_part(root, _box(Vector3(0.48, 0.5, 0.3) * Vector3(w, h, w)), Vector3(0, 1.15 * h - drop, 0), METAL.darkened(0.2))   # breastplate
			if not sitting:
				_part(root, _cyl(0.022, 0.022, 2.1 * maxf(h, 0.8)), Vector3(0.38 * w, 1.05 * maxf(h, 0.8), -0.08), LEATHER)
				_part(root, _cyl(0.0, 0.05, 0.22), Vector3(0.38 * w, 2.2 * maxf(h, 0.8), -0.08), METAL)
		"merchant":
			_part(root, _box(Vector3(0.42, 0.5, 0.26) * Vector3(w, h, 1)), Vector3(0, 1.15 * h - drop, 0.27 * w), LEATHER)   # pack
			_part(root, _box(Vector3(0.12, 0.12, 0.3)), Vector3(0, 1.48 * h - drop, 0.27 * w), LINEN, Vector3(0, PI / 2.0, 0))   # bedroll
		"innkeeper":
			_part(root, _box(Vector3(0.36 * w, 0.62 * h, 0.03)), Vector3(0, 0.95 * h - drop, -0.22 * w), LINEN)
		"worker":
			_part(head, _cyl(head_r * 2.2, head_r * 2.2, 0.025), Vector3(0, head_r * 0.6, 0), Color(0.6, 0.5, 0.3))   # straw hat
			_part(head, _cyl(head_r * 0.8, head_r, head_r * 0.6), Vector3(0, head_r * 0.85, 0), Color(0.6, 0.5, 0.3))
		"hunter":
			_hood(head, head_r, cloth.darkened(0.25))
			_part(root, _box(Vector3(0.03, 1.1 * h, 0.06)), Vector3(0.05, 1.15 * h - drop, 0.25 * w), LEATHER, Vector3(0, 0, 0.5))   # bow on the back
		"priest":
			_hood(head, head_r, cloth.darkened(0.2))
			_part(root, _box(Vector3(0.12, 0.7 * h, 0.02)), Vector3(0, 1.0 * h - drop, -0.23 * w), LINEN)   # stole
		"scholar":
			_part(head, _cyl(head_r * 0.95, head_r, head_r * 0.35), Vector3(0, head_r * 0.8, 0), cloth.darkened(0.4))   # cap
			_part(root, _box(Vector3(0.18, 0.24, 0.05)), Vector3(-0.3 * w, 1.0 * h - drop, -0.12), LEATHER)   # book
		"official":
			_part(head, _cyl(head_r * 0.85, head_r * 0.9, head_r * 1.6), Vector3(0, head_r * 1.2, 0), Color(0.08, 0.08, 0.1))   # tall hat
			_part(root, _box(Vector3(0.5 * w, 0.08, 0.32 * w)), Vector3(0, 1.4 * h - drop, 0), LINEN)   # collar
		"physician":
			_part(head, _cyl(head_r * 2.0, head_r * 2.0, 0.02), Vector3(0, head_r * 0.7, 0), Color(0.08, 0.08, 0.1))
			_part(head, _cyl(head_r * 0.85, head_r * 0.95, head_r * 0.8), Vector3(0, head_r * 1.05, 0), Color(0.08, 0.08, 0.1))
			_part(head, _cyl(0.0, 0.035, 0.14), Vector3(0, -0.02, -head_r - 0.06), LINEN, Vector3(-PI / 2.0, 0, 0))   # beak
		"inquisitor":
			_part(head, _cyl(head_r * 2.1, head_r * 2.1, 0.025), Vector3(0, head_r * 0.6, 0), Color(0.1, 0.09, 0.08))
			_part(head, _cyl(head_r * 0.9, head_r, head_r * 0.7), Vector3(0, head_r * 0.9, 0), Color(0.1, 0.09, 0.08))
			_part(root, _box(Vector3(0.1, 0.1, 0.1)), Vector3(0, 1.28 * h - drop, -0.24 * w), Color(1.0, 0.8, 0.4), Vector3(0, PI / 4.0, 0), true)   # lantern badge
		"bandit":
			_hood(head, head_r, cloth.darkened(0.35).lerp(Color(0.2, 0.26, 0.18), 0.5))
			_part(head, _box(Vector3(0.24, 0.1, 0.06) * head_size), Vector3(0, -head_r * 0.45, -head_r * 0.8), Color(0.55, 0.1, 0.08))   # face scarf
			_part(root, _box(Vector3(0.06, 0.06, 0.5) * Vector3(1, 1, w)), Vector3(0, 1.0 * h - drop, 0), LEATHER, Vector3(0, 0, 0.6))   # belt-strap
		"mercy":
			_hood(head, head_r, cloth.darkened(0.3))
			_part(head, _box(Vector3(0.2, 0.22, 0.03) * head_size), Vector3(0, -0.01, -head_r * 0.98), Color(0.9, 0.88, 0.82))   # mask

	_set_layers(root, layers)
	return root


## Where a figure's shoulder is (side: 1 right, -1 left), for arm pivots.
static func shoulder(race: String, side: float) -> Vector3:
	var r: Dictionary = RACES[race_key(race)]
	return Vector3(side * 0.28 * r["w"], 1.44 * r["h"], 0)


## How far below the shoulder the hand is.
static func hand_drop(race: String) -> float:
	return 0.66 * height_of(race)


## An arm hanging from a shoulder pivot (the figure built without arms): a sleeve
## in `cloth_material` and a hand at hand_drop(). The pivot swings it.
static func arm(pivot: Node3D, race: String, cloth_material: Material, layers := 1) -> void:
	var r: Dictionary = RACES[race_key(race)]
	var h: float = r["h"]
	var w: float = r["w"]
	_part(pivot, _capsule(0.065 * w, 0.68 * h), Vector3(0, -0.33 * h, 0), Color.WHITE).material_override = cloth_material
	_part(pivot, _sphere(0.055 * w), Vector3(0, -hand_drop(race), 0), r["skin"])
	_set_layers(pivot, layers)


static func _hood(head: Node3D, head_r: float, color: Color) -> void:
	_part(head, _sphere(head_r * 1.18), Vector3(0, head_r * 0.1, head_r * 0.22), color)
	_part(head, _cyl(head_r * 0.4, head_r * 1.1, head_r * 0.9), Vector3(0, -head_r * 0.6, head_r * 0.35), color, Vector3(0.3, 0, 0))


static func _set_layers(node: Node, layers: int) -> void:
	if node is VisualInstance3D:
		node.layers = layers
	for c in node.get_children():
		_set_layers(c, layers)


static func _part(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color, rot := Vector3.ZERO, glow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = pos
	m.rotation = rot
	m.material_override = _mat(color, glow)
	parent.add_child(m)
	return m


static func _new_mat(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m


static func _mat(color: Color, glow: bool) -> StandardMaterial3D:
	var key := "%s%s" % [color, glow]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.85
		if glow:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = 1.5
		_mats[key] = m
	return _mats[key]


static func _capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = maxf(height, radius * 2.0)
	m.radial_segments = 12
	m.rings = 4
	return m


static func _cyl(top: float, bottom: float, height: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 12
	m.rings = 1
	return m


static func _sphere(radius: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m
