extends Node3D

var _fans: Array[Node3D] = []

func _ready() -> void:
	Engine.time_scale = 1.0
	Global.current_scene_path = "res://scenes/scene_5_data_end.tscn"
	Global.has_key = true # Sophia arrive dans scene 5 avec la clé par défaut
	_setup_fans()  # construction des ventito du pc
	$HUD.set_key_visible(true)  # affiche la clé dans HUD
	$HUD.set_subtitle("Utilise la clé pour ouvrir le coffre !")

func _process(delta: float) -> void:
	for fan in _fans:
		fan.rotate_object_local(Vector3.UP, deg_to_rad(360.0) * delta) # rotation locale

func _setup_fans() -> void:
	# matériaux identiques à scene_1 (même PC, même assets)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.106, 0.157, 0.176, 1.0)

	# matériau métallique brillant pour le moyeu central
	var hub_mat := StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.237, 0.262, 0.433, 1.0)
	hub_mat.metallic = 0.9
	hub_mat.roughness = 0.2

	# pales des grands ventilateurs Radiator3
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.238, 0.014, 0.042)
	blade_mesh.surface_set_material(0, blade_mat)

	# pales Radiator2 (plus petites)
	var rad2_blade_mesh := BoxMesh.new()
	rad2_blade_mesh.size = Vector3(0.140, 0.010, 0.028)
	rad2_blade_mesh.surface_set_material(0, blade_mat)

	# pales GPU corps et face
	var gpu_blade_mesh := BoxMesh.new()
	gpu_blade_mesh.size = Vector3(0.170, 0.010, 0.030)
	gpu_blade_mesh.surface_set_material(0, blade_mat)

	# moyeu cylindrique partagé entre tous les fans
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.04
	hub_mesh.bottom_radius = 0.04
	hub_mesh.height = 0.05
	hub_mesh.radial_segments = 10
	hub_mesh.surface_set_material(0, hub_mat)

	# même disposition que scene_1 : Radiator3 → TopFans, Radiator2 → Fans latéraux
	for cyl in $PC/Radiator3.get_children():
		_add_fan(cyl, blade_mesh, hub_mesh, $PC/TopFans)
	for cyl in $PC/Radiator2.get_children():
		_add_fan(cyl, rad2_blade_mesh, hub_mesh, $PC/Fans, Vector3(-1.0, 0.0, 0.0))
	# GPU corps → ventilateurs dessus GPU
	for cyl in $PC/GPU/GpuBody.get_children():
		_add_fan(cyl, gpu_blade_mesh, hub_mesh, $PC/TopFans)
	# GPU face → ventilateurs latéraux
	for cyl in $PC/GPU/GpuFace.get_children():
		_add_fan(cyl, gpu_blade_mesh, hub_mesh, $PC/Fans)

func _add_fan(node: Node, blade_mesh: Mesh, hub_mesh: Mesh, container: Node3D,
		force_axis: Vector3 = Vector3.ZERO) -> void:
	if not node is CSGCylinder3D:
		return  # ignore les enfants non-cylindriques des radiateurs
	var cyl := node as CSGCylinder3D
	# convertit la position globale du cylindre en locale dans $PC pour le pivot
	var local_pos: Vector3 = $PC.to_local(cyl.global_position)
	# si pas de force_axis → déduit l'axe depuis l'orientation Y du cylindre source
	var spin_axis: Vector3 = force_axis if force_axis != Vector3.ZERO else cyl.global_basis.y.normalized()
	var pivot := _make_fan_aligned(local_pos, spin_axis, blade_mesh, hub_mesh, 8, (cyl as CSGCylinder3D).radius * 0.50)
	container.add_child(pivot)
	_fans.append(pivot)  # stocké pour la rotation dans _process

func _make_fan_aligned(center: Vector3, spin_axis: Vector3, blade_mesh: Mesh,
		hub_mesh: Mesh, n_blades: int, radius: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = center
	# aligne le pivot sur l'axe de rotation réel du ventilateur
	pivot.transform.basis = Basis(Quaternion(Vector3.UP, spin_axis))
	var hub := MeshInstance3D.new()
	hub.mesh = hub_mesh
	pivot.add_child(hub)
	# 8 bras espacés de 45° autour du moyeu
	for i in n_blades:
		var arm := Node3D.new()
		arm.rotation_degrees.y = i * (360.0 / n_blades)
		pivot.add_child(arm)
		var blade := MeshInstance3D.new()
		blade.mesh = blade_mesh
		blade.position = Vector3(radius, 0.0, 0.0)
		blade.rotation_degrees.x = 30.0  # inclinaison de pale pour l'effet visuel
		arm.add_child(blade)
	return pivot
