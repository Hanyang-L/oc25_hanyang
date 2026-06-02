extends Node3D

signal all_placed
signal cap_placed(placed_count: int, total_count: int)

# force d'impulsion pour pusser cap de damp=14
const PUSH_FORCE = 100.0

# liste des RigidBody3D (caps) et de leurs rayons visuels correspondants
var _cap_bodies: Array[RigidBody3D] = []
var _cap_radii:  Array[float]       = []
var _placed_count: int = 0  # caps correctement posés sur une trace
var _sophia: Node3D  # référence à Sophia (détection de proximité)

func _ready() -> void:
	_sophia = get_node("../Sophia")
	for child in get_children():
		if child is RigidBody3D:
			# glisse horizontalement
			child.axis_lock_linear_y  = true  # bouge pas verticalemet
			child.axis_lock_angular_x = true  # ne peu pas tomber sur l'axe x
			child.axis_lock_angular_z = true  # ne peu pas tomber sur l'axe z
			# frottement élevé
			child.linear_damp  = 14.0
			child.angular_damp = 14.0
			var phys_mat = PhysicsMaterial.new()
			phys_mat.friction = 1.0
			phys_mat.rough = true  # évite le glissement comme sur la glace sur le sol lisse
			child.physics_material_override = phys_mat
			# rayon = rayon de la taille visuelle du Mesh
			var mesh_inst = child.get_node("Mesh") as MeshInstance3D
			_cap_radii.append((mesh_inst.mesh as CylinderMesh).top_radius)
			_cap_bodies.append(child)

func _physics_process(_delta: float) -> void:
	for i in _cap_bodies.size():
		var rb = _cap_bodies[i]
		if rb.freeze:  # cap déjà placé sur une trace --> impoussable
			continue
		_apply_push(rb, _cap_radii[i])

func _apply_push(rb: RigidBody3D, visual_rad: float) -> void:
	# légère marge au rayon visuel pour pousser plus tôt (visuellement plus propre)
	var push_range = visual_rad + 0.5
	var diff = rb.global_position - _sophia.global_position
	diff.y = 0.0  # pousse seulement sur axe x et z
	var dist = diff.length()
	if dist < push_range and dist > 0.01:  # dist > 0.01 évite division par 0
		rb.apply_central_impulse(diff.normalized() * PUSH_FORCE)

# appelé depuis scene_2_gpu.gd quand un cap entre dans la kill zone d'une trace
func on_cap_entered_trace(rb: RigidBody3D, _trace_pos: Vector3) -> void:
	if rb.freeze:  # évite un double déclenchement si déja immobile
		return
	rb.freeze = true  # immobilise le cap à position actuelle
	var idx = _cap_bodies.find(rb)
	# remplace la collision shape par une version au rayon exact dde la forme visuelle
	var col_shape = rb.get_node("Shape") as CollisionShape3D
	var old_cyl   = col_shape.shape as CylinderShape3D
	var new_cyl   = CylinderShape3D.new()
	new_cyl.radius = _cap_radii[idx]
	new_cyl.height = old_cyl.height
	col_shape.shape = new_cyl
	_placed_count += 1
	cap_placed.emit(_placed_count, _cap_bodies.size())
	if _placed_count >= _cap_bodies.size():
		all_placed.emit()  # activation de NextSceneArea dans scene_2_gpu
