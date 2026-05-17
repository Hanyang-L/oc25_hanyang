extends Node3D

signal all_placed

const SNAP_THRESHOLD = 2.5
const PUSH_RANGE     = 1.5
const PUSH_FORCE     = 15.0

var _cap_bodies: Array[RigidBody3D] = []
var _placed_count: int = 0
var _trace_positions: Array[Vector3] = []
var _patrick: Node3D

func _ready() -> void:
	_patrick = get_node("../Patrick")
	_gather_trace_positions()
	for child in get_children():
		if child is RigidBody3D:
			_cap_bodies.append(child)

func _gather_trace_positions() -> void:
	for trace in get_node("../GPU/CircuitTraces").get_children():
		if trace is CSGBox3D:
			_trace_positions.append(trace.global_position)

func _process(_delta: float) -> void:
	for rb in _cap_bodies:
		if rb.freeze:
			continue
		_apply_push(rb)
		_check_snap(rb)

func _apply_push(rb: RigidBody3D) -> void:
	var diff = rb.global_position - _patrick.global_position
	diff.y = 0.0
	var dist = diff.length()
	if dist < PUSH_RANGE and dist > 0.01:
		rb.apply_central_impulse(diff.normalized() * PUSH_FORCE)

func _check_snap(rb: RigidBody3D) -> void:
	if rb.linear_velocity.length() > 2.0:
		return
	var best_dist = INF
	var best_pos  = Vector3.ZERO
	for tpos in _trace_positions:
		var d = Vector2(rb.global_position.x - tpos.x,
						rb.global_position.z - tpos.z).length()
		if d < best_dist:
			best_dist = d
			best_pos  = tpos
	if best_dist < SNAP_THRESHOLD:
		rb.freeze = true
		rb.global_position = Vector3(best_pos.x, rb.global_position.y, best_pos.z)
		_placed_count += 1
		if _placed_count >= _cap_bodies.size():
			all_placed.emit()
