extends Node3D

const SCENES_DIR = "res://scenes/"
const SCENE_PREFIX = "scene_"

var _fans: Array[Node3D] = []
var _sophia: CharacterBody3D
var _display_connected: bool = false

func _ready() -> void:
	Engine.time_scale = 1.0
	Global.current_scene_path = "res://scenes/scene_1_data.tscn"
	_sophia = $Sophia
	_setup_fans()
	_setup_display()

	$HUD.set_subtitle("Trouve la sortie du data center")
	if Global.has_key:
		$Sophia.global_position = Vector3(3.5, 1.0, -11.0)
		$Sophia.rotation.y = 0.0
		$HUD.set_subtitle("Utilise la clé pour ouvrir le coffre !")

func _process(delta: float) -> void:
	for fan in _fans:
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
	blade_mesh.size = Vector3(0.238, 0.014, 0.042)
	blade_mesh.surface_set_material(0, blade_mat)

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
		_add_fan(cyl, blade_mesh, hub_mesh, $PC/Fans)
	for cyl in $PC/GPU/GpuBody.get_children():
		_add_fan(cyl, gpu_blade_mesh, hub_mesh, $PC/TopFans)
	for cyl in $PC/GPU/GpuFace.get_children():
		_add_fan(cyl, gpu_blade_mesh, hub_mesh, $PC/Fans)

func _setup_display() -> void:
	var screen: Node3D = $Display/CSGBox3D

	# Zone de proximité pour déclencher l'interaction
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 3.0, 6.0)
	col.shape = shape
	area.add_child(col)
	area.position = screen.position
	$Display.add_child(area)
	area.body_entered.connect(_on_display_entered)
	area.body_exited.connect(_on_display_exited)

func _on_display_entered(body: Node3D) -> void:
	if body != _sophia:
		return
	$HUD.set_subtitle("E : OK")
	_sophia.interact_pressed.connect(_on_display_interact)
	_display_connected = true

func _on_display_exited(body: Node3D) -> void:
	if body != _sophia:
		return
	if _display_connected:
		_sophia.interact_pressed.disconnect(_on_display_interact)
		_display_connected = false
	if not Global.has_key:
		$HUD.set_subtitle("Trouve la sortie du data center")
	else:
		$HUD.set_subtitle("Utilise la clé pour ouvrir le coffre !")

func _on_display_interact() -> void:
	if _display_connected:
		_sophia.interact_pressed.disconnect(_on_display_interact)
		_display_connected = false

	_sophia.can_move = false
	_sophia.has_gravity = false
	_sophia.velocity = Vector3.ZERO

	$HUD.set_subtitle("")
	$HUD.show_message("Sophia est aspirée dans le GPU...", 2.0)

	var target: Vector3 = $PC/GPU/GpuBody.global_position

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sophia, "global_position", target, 1.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_sophia, "scale", Vector3.ZERO, 1.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func():
		Global.change_scene("res://scenes/scene_2_gpu.tscn")
	)

func _add_fan(node: Node, blade_mesh: Mesh, hub_mesh: Mesh, container: Node3D) -> void:
	if not node is CSGCylinder3D:
		return
	var cyl := node as CSGCylinder3D
	var local_pos: Vector3 = $PC.to_local(cyl.global_position)
	var spin_axis: Vector3 = cyl.global_basis.y.normalized()
	var pivot := _make_fan_aligned(local_pos, spin_axis, blade_mesh, hub_mesh, 8, cyl.radius * 0.50)
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
