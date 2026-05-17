extends Node3D

const SCENES_DIR = "res://scenes/"
const SCENE_PREFIX = "scene_"

@onready var next_scene_area: Area3D = $NextSceneArea
@onready var _moving_cap: Node3D = $MovingCap

var _spark_mesh: SphereMesh
var _fans: Array[Node3D] = []

func _ready() -> void:
	Engine.time_scale = 1.0
	Global.current_scene_path = "res://scenes/scene_3_gpu.tscn"
	next_scene_area.monitoring = false
	$NextSceneArea/CollisionShape3D.disabled = true
	_moving_cap.all_placed.connect(_on_all_caps_placed)
	_setup_trace_hazards()
	_setup_fans()

func _on_all_caps_placed() -> void:
	next_scene_area.monitoring = true
	$NextSceneArea/CollisionShape3D.disabled = false

func _process(delta: float) -> void:
	for fan in _fans:
		fan.rotate_y(deg_to_rad(300.0) * delta)

func _setup_fans() -> void:
	var fan_mat = StandardMaterial3D.new()
	fan_mat.albedo_color = Color(0.18, 0.18, 0.22)
	fan_mat.metallic = 0.8
	fan_mat.roughness = 0.3

	var blade_mesh = BoxMesh.new()
	blade_mesh.size = Vector3(25.0, 0.6, 5.0)
	blade_mesh.surface_set_material(0, fan_mat)

	var hub_mesh = CylinderMesh.new()
	hub_mesh.top_radius = 2.5
	hub_mesh.bottom_radius = 2.5
	hub_mesh.height = 1.2
	hub_mesh.radial_segments = 12
	hub_mesh.surface_set_material(0, fan_mat)

	var fan_centers = [
		Vector3(0.8,    25.0, 0.0),
		Vector3(-51.33, 25.0, 0.0),
		Vector3(54.18,  25.0, 0.0),
	]
	for center in fan_centers:
		var pivot = _create_fan(center, blade_mesh, hub_mesh)
		$GPU/Fans.add_child(pivot)
		_fans.append(pivot)

func _create_fan(center: Vector3, blade_mesh: BoxMesh, hub_mesh: CylinderMesh) -> Node3D:
	var pivot = Node3D.new()
	pivot.position = center

	var hub = MeshInstance3D.new()
	hub.mesh = hub_mesh
	pivot.add_child(hub)

	for i in 8:
		var arm = Node3D.new()
		arm.rotation_degrees.y = i * 45.0
		pivot.add_child(arm)

		var blade = MeshInstance3D.new()
		blade.mesh = blade_mesh
		blade.position = Vector3(9.0, 0.0, 0.0)
		blade.rotation_degrees.x = 30.0
		arm.add_child(blade)

	return pivot

func _setup_trace_hazards() -> void:
	_spark_mesh = SphereMesh.new()
	_spark_mesh.radius = 0.04
	_spark_mesh.height = 0.08
	var spark_mat = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(0.3, 0.8, 1.0)
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(0.5, 1.0, 1.5)
	spark_mat.emission_energy_multiplier = 3.0
	_spark_mesh.surface_set_material(0, spark_mat)

	for trace in $GPU/CircuitTraces.get_children():
		if not trace is CSGBox3D:
			continue
		_add_trace_kill_zone(trace)
		_add_trace_sparks(trace)

func _add_trace_kill_zone(trace: CSGBox3D) -> void:
	var area = Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 1
	area.position = trace.position
	$GPU/CircuitTraces.add_child(area)

	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	box.size = Vector3(trace.size.x, 0.5, trace.size.z)
	shape.shape = box
	area.add_child(shape)
	area.body_entered.connect(_on_trace_body_entered)

func _add_trace_sparks(trace: CSGBox3D) -> void:
	var particles = GPUParticles3D.new()
	particles.amount = 8
	particles.lifetime = 0.4
	particles.position = trace.position + Vector3(0, 0.15, 0)

	var pmat = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(trace.size.x * 0.5, 0.05, trace.size.z * 0.5)
	pmat.direction = Vector3(0, 1, 0)
	pmat.spread = 60.0
	pmat.initial_velocity_min = 0.3
	pmat.initial_velocity_max = 2.0
	pmat.gravity = Vector3(0, -4, 0)
	pmat.color = Color(0.3, 0.8, 1.0)
	pmat.scale_min = 0.5
	pmat.scale_max = 1.5
	particles.process_material = pmat
	particles.draw_pass_1 = _spark_mesh
	$GPU/CircuitTraces.add_child(particles)

func _on_trace_body_entered(body: Node3D) -> void:
	if body.has_method("die"):
		body.die()

func _on_next_scene_area_body_entered(body: Node3D) -> void:
	if not body.has_method("die"):
		return
	var filename = get_tree().current_scene.scene_file_path.get_file()
	var num = filename.split("_")[1].to_int()
	var dir = DirAccess.open(SCENES_DIR)
	if dir:
		for f in dir.get_files():
			if f.begins_with(SCENE_PREFIX + str(num + 1)):
				Global.change_scene(SCENES_DIR + f)
				return
