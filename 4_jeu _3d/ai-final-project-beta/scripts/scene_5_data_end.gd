extends Node3D

var _fans: Array[Node3D] = []

func _ready() -> void:
	Engine.time_scale = 1.0
	Global.current_scene_path = "res://scenes/scene_5_data_end.tscn"
	Global.has_key = true
	_setup_fans()

	$HUD.set_subtitle("Utilise la clé pour ouvrir le coffre !")

func _process(delta: float) -> void:
	for fan in _fans:
		fan.rotate_object_local(Vector3.UP, deg_to_rad(360.0) * delta)

func _setup_fans() -> void:
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.106, 0.157, 0.176, 1.0)

	var hub_mat := StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.04, 0.04, 0.05)
	hub_mat.metallic = 0.9
	hub_mat.roughness = 0.2

	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.238, 0.014, 0.042)
	blade_mesh.surface_set_material(0, blade_mat)

	var rad2_blade_mesh := BoxMesh.new()
	rad2_blade_mesh.size = Vector3(0.140, 0.010, 0.028)
	rad2_blade_mesh.surface_set_material(0, blade_mat)

	var gpu_blade_mesh := BoxMesh.new()
	gpu_blade_mesh.size = Vector3(0.170, 0.010, 0.030)
	gpu_blade_mesh.surface_set_material(0, blade_mat)

	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.04
	hub_mesh.bottom_radius = 0.04
	hub_mesh.height = 0.05
	hub_mesh.radial_segments = 10
	hub_mesh.surface_set_material(0, hub_mat)

	for cyl in $PC/Radiator3.get_children():
		_add_fan(cyl, blade_mesh, hub_mesh, $PC/TopFans)
	for cyl in $PC/Radiator2.get_children():
		_add_fan(cyl, rad2_blade_mesh, hub_mesh, $PC/Fans, Vector3(-1.0, 0.0, 0.0))
	for cyl in $PC/GPU/GpuBody.get_children():
		_add_fan(cyl, gpu_blade_mesh, hub_mesh, $PC/TopFans)
	for cyl in $PC/GPU/GpuFace.get_children():
		_add_fan(cyl, gpu_blade_mesh, hub_mesh, $PC/Fans)

func _add_fan(node: Node, blade_mesh: Mesh, hub_mesh: Mesh, container: Node3D,
		force_axis: Vector3 = Vector3.ZERO) -> void:
	if not node is CSGCylinder3D:
		return
	var cyl := node as CSGCylinder3D
	var local_pos: Vector3 = $PC.to_local(cyl.global_position)
	var spin_axis: Vector3 = force_axis if force_axis != Vector3.ZERO else cyl.global_basis.y.normalized()
	var pivot := _make_fan_aligned(local_pos, spin_axis, blade_mesh, hub_mesh, 8, (cyl as CSGCylinder3D).radius * 0.50)
	container.add_child(pivot)
	_fans.append(pivot)

func _make_fan_aligned(center: Vector3, spin_axis: Vector3, blade_mesh: Mesh,
		hub_mesh: Mesh, n_blades: int, radius: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = center
	pivot.transform.basis = Basis(Quaternion(Vector3.UP, spin_axis))
	var hub := MeshInstance3D.new()
	hub.mesh = hub_mesh
	pivot.add_child(hub)
	for i in n_blades:
		var arm := Node3D.new()
		arm.rotation_degrees.y = i * (360.0 / n_blades)
		pivot.add_child(arm)
		var blade := MeshInstance3D.new()
		blade.mesh = blade_mesh
		blade.position = Vector3(radius, 0.0, 0.0)
		blade.rotation_degrees.x = 30.0
		arm.add_child(blade)
	return pivot
