extends Node3D

signal all_placed
signal cap_placed(placed_count: int, total_count: int)

const PUSH_FORCE = 100.0

var _cap_bodies: Array[RigidBody3D] = []
var _cap_radii:  Array[float]       = []
var _placed_count: int = 0
var _sophia: Node3D

func _ready() -> void:
	_sophia = get_node("../Sophia")
	for child in get_children():
		if child is RigidBody3D:
			child.axis_lock_linear_y  = true
			child.axis_lock_angular_x = true
			child.axis_lock_angular_z = true
			child.linear_damp  = 14.0
			child.angular_damp = 14.0
			var phys_mat = PhysicsMaterial.new()
			phys_mat.friction = 1.0
			phys_mat.rough = true
			child.physics_material_override = phys_mat
			var mesh_inst = child.get_node("Mesh") as MeshInstance3D
			_cap_radii.append((mesh_inst.mesh as CylinderMesh).top_radius)
			_cap_bodies.append(child)

func _physics_process(_delta: float) -> void:
	for i in _cap_bodies.size():
		var rb = _cap_bodies[i]
		if rb.freeze:
			continue
		_apply_push(rb, _cap_radii[i])

func _apply_push(rb: RigidBody3D, visual_rad: float) -> void:
	var push_range = visual_rad + 0.5
	var diff = rb.global_position - _sophia.global_position
	diff.y = 0.0
	var dist = diff.length()
	if dist < push_range and dist > 0.01:
		rb.apply_central_impulse(diff.normalized() * PUSH_FORCE)

func on_cap_entered_trace(rb: RigidBody3D, trace_pos: Vector3) -> void:
	if rb.freeze:
		return
	rb.freeze = true
	var idx = _cap_bodies.find(rb)
	var col_shape = rb.get_node("Shape") as CollisionShape3D
	var old_cyl   = col_shape.shape as CylinderShape3D
	var new_cyl   = CylinderShape3D.new()
	new_cyl.radius = _cap_radii[idx]
	new_cyl.height = old_cyl.height
	col_shape.shape = new_cyl
	_placed_count += 1
	cap_placed.emit(_placed_count, _cap_bodies.size())
	if _placed_count >= _cap_bodies.size():
		all_placed.emit()
