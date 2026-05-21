extends Node3D

const SCENES_DIR = "res://scenes/"
const SCENE_PREFIX = "scene_"

var _side_fans: Array[Node3D] = []
var _top_fans: Array[Node3D] = []

func _ready() -> void:
	Engine.time_scale = 1.0
	Global.current_scene_path = "res://scenes/scene_1_data.tscn"
	_setup_fans()
	$NextSceneArea.body_entered.connect(_on_next_scene_area_body_entered)
	$HUD.set_subtitle("Trouve la sortie du data center")
	if Global.has_key:
		$Sophia.global_position = Vector3(3.5, 1.0, -11.0)
		$Sophia.rotation.y = 0.0
		$HUD.set_subtitle("Utilise la clé pour ouvrir le coffre !")

func _process(delta: float) -> void:
	for fan in _side_fans:
		fan.rotate_z(deg_to_rad(480.0) * delta)
	for fan in _top_fans:
		fan.rotate_y(deg_to_rad(360.0) * delta)

func _setup_fans() -> void:
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.72, 1.0, 0.05)
	blade_mat.emission_enabled = true
	blade_mat.emission = Color(0.5, 1.0, 0.05)
	blade_mat.emission_energy_multiplier = 2.0

	var hub_mat := StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.04, 0.04, 0.05)
	hub_mat.metallic = 0.9
	hub_mat.roughness = 0.2

	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.08, 0.42, 0.09)
	blade_mesh.surface_set_material(0, blade_mat)

	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.06
	hub_mesh.bottom_radius = 0.06
	hub_mesh.height = 0.12
	hub_mesh.radial_segments = 10
	hub_mesh.surface_set_material(0, hub_mat)

	# 9 fans panneau vitré 3×3, face Z+ du boîtier
	for row in 3:
		for col in 3:
			var pos := Vector3(-0.62 + col * 0.62, 0.35 + row * 0.62, 0.76)
			var pivot := _make_fan_pivot(pos, blade_mesh, hub_mesh, 8, 0.22)
			$PC/Fans.add_child(pivot)
			_side_fans.append(pivot)

	# 3 fans dessus du boîtier
	var top_blade := BoxMesh.new()
	top_blade.size = Vector3(0.42, 0.09, 0.08)
	top_blade.surface_set_material(0, blade_mat)
	for i in 3:
		var pos := Vector3(-0.62 + i * 0.62, 2.02, 0.0)
		var pivot := _make_fan_pivot_top(pos, top_blade, hub_mesh, 8, 0.22)
		$PC/TopFans.add_child(pivot)
		_top_fans.append(pivot)

func _make_fan_pivot(center: Vector3, blade_mesh: Mesh,
		hub_mesh: Mesh, n_blades: int, radius: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = center
	var hub := MeshInstance3D.new()
	hub.mesh = hub_mesh
	pivot.add_child(hub)
	for i in n_blades:
		var arm := Node3D.new()
		arm.rotation_degrees.z = i * (360.0 / n_blades)
		pivot.add_child(arm)
		var blade := MeshInstance3D.new()
		blade.mesh = blade_mesh
		blade.position = Vector3(0.0, radius, 0.0)
		arm.add_child(blade)
	return pivot

func _make_fan_pivot_top(center: Vector3, blade_mesh: Mesh,
		hub_mesh: Mesh, n_blades: int, radius: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = center
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
		arm.add_child(blade)
	return pivot

func _on_next_scene_area_body_entered(body: Node3D) -> void:
	if not body.has_method("die"):
		return
	var filename := get_tree().current_scene.scene_file_path.get_file()
	var num := filename.split("_")[1].to_int()
	var dir := DirAccess.open(SCENES_DIR)
	if dir:
		for f in dir.get_files():
			if f.begins_with(SCENE_PREFIX + str(num + 1)):
				Global.change_scene(SCENES_DIR + f)
				return
