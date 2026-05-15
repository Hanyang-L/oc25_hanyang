extends Node3D

## Peuple le fond marin de manière procédurale avec une seed fixe.
## Modifie rock_count / coral_count / plant_count depuis l'inspecteur.

@export var rng_seed: int = 500
@export var rock_count: int = 700
@export var coral_count: int = 1000
@export var plant_count: int = 8000

const FLOOR_Y := -3.0
const X_MIN   := -255.0
const X_MAX   :=  275.0
const Z_MIN   := -410.0
const Z_MAX   :=   -4.0

const CORAL_COLORS: Array[Color] = [
	Color(1.0, 0.28, 0.18, 1.0),
	Color(0.65, 0.05, 0.82, 1.0),
	Color(0.0,  0.75, 0.65, 1.0),
	Color(0.95, 0.72, 0.08, 1.0),
	Color(0.9,  0.35, 0.6,  1.0),
]

var _rng   := RandomNumberGenerator.new()
var _algue : PackedScene

# matériaux pré-créés pour éviter des centaines d'allocations
var _rock_mats  : Array[StandardMaterial3D] = []
var _coral_mats : Array[StandardMaterial3D] = []


func _ready() -> void:
	_rng.seed = rng_seed
	_algue = load("res://scenes/algue.tscn")
	_build_materials()
	_spawn_rocks()
	_spawn_corals()
	_spawn_plants()


func _build_materials() -> void:
	for i in 7:
		var m := StandardMaterial3D.new()
		var g := 0.28 + i * 0.06
		m.albedo_color = Color(g, g * 0.93, g * 0.87, 1.0)
		m.roughness    = 0.78 + i * 0.03
		_rock_mats.append(m)

	for c in CORAL_COLORS:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		_coral_mats.append(m)


func _rpos() -> Vector3:
	return Vector3(
		_rng.randf_range(X_MIN, X_MAX),
		FLOOR_Y,
		_rng.randf_range(Z_MIN, Z_MAX)
	)


# ── ROCHERS ─────────────────────────────────────────────────────────────────

func _spawn_rocks() -> void:
	for _i in rock_count:
		var body := StaticBody3D.new()
		var mi   := MeshInstance3D.new()
		var col  := CollisionShape3D.new()

		var r  := _rng.randf_range(0.28, 1.7)
		var sy := _rng.randf_range(0.30, 1.0)   # écrasement vertical
		var sz := _rng.randf_range(0.65, 1.45)  # élongation Z

		var sm := SphereMesh.new()
		sm.radius = r
		sm.height = r * 2.0
		mi.mesh  = sm
		mi.scale = Vector3(1.0, sy, sz)
		mi.material_override = _rock_mats[_rng.randi() % _rock_mats.size()]

		var shape := SphereShape3D.new()
		shape.radius = r * 0.86
		col.shape = shape
		col.scale = Vector3(1.0, sy, sz)

		body.position = _rpos() + Vector3(0.0, r * sy, 0.0)
		body.rotation_degrees.y = _rng.randf() * 360.0
		body.add_child(mi)
		body.add_child(col)
		add_child(body)


# ── CORAUX ──────────────────────────────────────────────────────────────────

func _spawn_corals() -> void:
	for _i in coral_count:
		var mat := _coral_mats[_rng.randi() % _coral_mats.size()]
		var pos := _rpos()
		match _rng.randi() % 4:
			0: _coral_ball(pos, mat)
			1: _coral_tube(pos, mat)
			2: _coral_dome(pos, mat)
			3: _coral_branch(pos, mat)


func _coral_ball(pos: Vector3, mat: StandardMaterial3D) -> void:
	var r  := _rng.randf_range(0.18, 0.58)
	var body := StaticBody3D.new()

	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r; sm.height = r * 2.0
	mi.mesh = sm; mi.material_override = mat
	mi.position = Vector3(0, r, 0)

	var col   := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = r
	col.shape = shape; col.position = Vector3(0, r, 0)

	body.position = pos
	body.add_child(mi); body.add_child(col)
	add_child(body)


func _coral_tube(pos: Vector3, mat: StandardMaterial3D) -> void:
	var h := _rng.randf_range(0.45, 1.6)
	var r := _rng.randf_range(0.1, 0.32)
	var body := StaticBody3D.new()

	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.55; cm.bottom_radius = r; cm.height = h
	mi.mesh = cm; mi.material_override = mat
	mi.position = Vector3(0, h * 0.5, 0)

	var col   := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = r; shape.height = h
	col.shape = shape; col.position = Vector3(0, h * 0.5, 0)

	body.position = pos
	body.rotation_degrees.y = _rng.randf() * 360.0
	body.add_child(mi); body.add_child(col)
	add_child(body)


func _coral_dome(pos: Vector3, mat: StandardMaterial3D) -> void:
	var r := _rng.randf_range(0.22, 0.68)
	var body := StaticBody3D.new()

	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r; sm.height = r * 2.0
	mi.mesh = sm; mi.scale = Vector3(1.0, 0.52, 1.0)
	mi.material_override = mat; mi.position = Vector3(0, r * 0.26, 0)

	var col   := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = r * 0.65
	col.shape = shape; col.position = Vector3(0, r * 0.26, 0)

	body.position = pos
	body.rotation_degrees.y = _rng.randf() * 360.0
	body.add_child(mi); body.add_child(col)
	add_child(body)


func _coral_branch(pos: Vector3, mat: StandardMaterial3D) -> void:
	var h    := _rng.randf_range(0.5, 1.3)
	var body := StaticBody3D.new()
	body.position = pos

	# tronc
	var mi0 := MeshInstance3D.new()
	var cm0 := CylinderMesh.new()
	cm0.top_radius = 0.045; cm0.bottom_radius = 0.075; cm0.height = h
	mi0.mesh = cm0; mi0.material_override = mat
	mi0.position = Vector3(0, h * 0.5, 0)
	body.add_child(mi0)

	# 2 branches latérales
	for b in 2:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.025; cm.bottom_radius = 0.04; cm.height = h * 0.55
		mi.mesh = cm; mi.material_override = mat
		var side := (b * 2 - 1) * 0.14
		mi.position = Vector3(side, h * 0.72, 0)
		mi.rotation_degrees.z = (b * 2 - 1) * -30.0
		body.add_child(mi)

	var col   := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.1; shape.height = h
	col.shape = shape; col.position = Vector3(0, h * 0.5, 0)
	body.add_child(col)
	add_child(body)


# ── PLANTES ANIMÉES ─────────────────────────────────────────────────────────

func _spawn_plants() -> void:
	for _i in plant_count:
		var plant: Node3D = _algue.instantiate()
		plant.position = _rpos()
		add_child(plant)
