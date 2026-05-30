extends Node3D

const SCENES_DIR = "res://scenes/"
const SCENE_PREFIX = "scene_"

@onready var next_scene_area: Area3D = $NextSceneArea
@onready var _moving_cap: Node3D = $MovingCap
@onready var _hud = $HUD

var _spark_mesh: SphereMesh
var _fans: Array[Node3D] = []

func _ready() -> void:
	Engine.time_scale = 1.0
	Global.current_scene_path = "res://scenes/scene_2_gpu.tscn"
	# sortie verrouillée — s'ouvre seulement quand tous les caps sont placés
	next_scene_area.monitoring = false
	$NextSceneArea/CollisionShape3D.disabled = true  # double verrou pour éviter les faux positifs
	# écoute les signaux de MovingCap pour le HUD et pour débloquer la sortie
	_moving_cap.all_placed.connect(_on_all_caps_placed)
	_moving_cap.cap_placed.connect(_on_cap_placed)
	_hud.set_subtitle("But: Déplacer les condensateurs cylindriques pour réparer le GPU.")
	_hud.set_cap_counter(0, 7)  # affiche 0/7 dès le départ dans le HUD
	_setup_trace_hazards()  # ajoute kill zones + étincelles sur chaque trace du circuit
	_setup_fans()           # crée les 3 grandes hélices GPU

func _on_cap_placed(placed: int, total: int) -> void:
	_hud.set_cap_counter(placed, total)  # met à jour le compteur affiché dans le HUD

func _on_all_caps_placed() -> void:
	# tous les caps sont en place → déverrouille la sortie
	next_scene_area.monitoring = true
	$NextSceneArea/CollisionShape3D.disabled = false
	_hud.show_message("Tous les composants placés ! Rejoins la sortie !", 6.0)
	_hud.set_subtitle("Rejoins la sortie au bord avant du GPU !")

func _process(delta: float) -> void:
	for fan in _fans:
		fan.rotate_y(deg_to_rad(300.0) * delta)  # 300°/s = GPU sous charge maximale

func _setup_fans() -> void:
	# matériau métallique sombre pour les pales du GPU géant
	var fan_mat = StandardMaterial3D.new()
	fan_mat.albedo_color = Color(0.18, 0.18, 0.22)
	fan_mat.metallic = 0.8
	fan_mat.roughness = 0.3

	# pale de 25 unités — proportionnel au PCB 160×100
	var blade_mesh = BoxMesh.new()
	blade_mesh.size = Vector3(25.0, 0.6, 5.0)
	blade_mesh.surface_set_material(0, fan_mat)

	# moyeu large (r=2.5) à l'échelle du GPU géant
	var hub_mesh = CylinderMesh.new()
	hub_mesh.top_radius = 2.5
	hub_mesh.bottom_radius = 2.5
	hub_mesh.height = 1.2
	hub_mesh.radial_segments = 12
	hub_mesh.surface_set_material(0, fan_mat)

	# 3 centres de ventilateurs alignés sur le dessus du GPU (Y=25)
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

	# 8 bras à 45° — même pattern que les fans PC de scene_1
	for i in 8:
		var arm = Node3D.new()
		arm.rotation_degrees.y = i * 45.0
		pivot.add_child(arm)

		var blade = MeshInstance3D.new()
		blade.mesh = blade_mesh
		blade.position = Vector3(9.0, 0.0, 0.0)  # bras de 9 unités depuis le centre
		blade.rotation_degrees.x = 30.0           # inclinaison de pale
		arm.add_child(blade)

	return pivot

func _setup_trace_hazards() -> void:
	# mesh sphérique partagé entre toutes les étincelles (évite de le recréer par trace)
	_spark_mesh = SphereMesh.new()
	_spark_mesh.radius = 0.04
	_spark_mesh.height = 0.08
	var spark_mat = StandardMaterial3D.new()
	spark_mat.albedo_color = Color(0.3, 0.8, 1.0)  # cyan électrique
	spark_mat.emission_enabled = true
	spark_mat.emission = Color(0.5, 1.0, 1.5)
	spark_mat.emission_energy_multiplier = 3.0
	_spark_mesh.surface_set_material(0, spark_mat)

	for trace in $GPU/CircuitTraces.get_children():
		if not trace is CSGBox3D:
			continue
		_add_trace_kill_zone(trace)  # zone de mort si Sophia marche dessus
		_add_trace_sparks(trace)     # particules visuelles cyan sur chaque trace

func _add_trace_kill_zone(trace: CSGBox3D) -> void:
	var area = Area3D.new()
	area.collision_layer = 0  # pas de layer propre
	area.collision_mask = 1   # détecte Sophia (layer 1) et les caps (layer 1)
	area.position = trace.position
	$GPU/CircuitTraces.add_child(area)

	var shape = CollisionShape3D.new()
	var box = BoxShape3D.new()
	# hauteur 0.3 : zone rase la surface de la trace, pas toute la hauteur du CSG
	box.size = Vector3(trace.size.x, 0.3, trace.size.z)
	shape.shape = box
	area.add_child(shape)
	# capture la position globale de la trace pour la transmettre à on_cap_entered_trace
	area.body_entered.connect(func(body): _on_trace_body_entered(body, area.global_position))

func _add_trace_sparks(trace: CSGBox3D) -> void:
	var particles = GPUParticles3D.new()
	particles.amount = 8
	particles.lifetime = 0.4
	particles.position = trace.position + Vector3(0, 0.15, 0)  # légèrement au-dessus de la trace

	var pmat = ParticleProcessMaterial.new()
	# émission répartie sur toute la surface de la trace
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

func _on_trace_body_entered(body: Node3D, trace_pos: Vector3) -> void:
	if body.has_method("die"):
		body.die()  # Sophia → mort instantanée
	elif body is RigidBody3D:
		# cap → snap sur la trace (freeze + ajustement collision + compteur)
		_moving_cap.call("on_cap_entered_trace", body, trace_pos)

func _on_next_scene_area_body_entered(body: Node3D) -> void:
	if not body.has_method("die"):
		return
	# trouve dynamiquement scene_N+1 par numéro sans hardcoder le chemin
	var filename = get_tree().current_scene.scene_file_path.get_file()
	var num = filename.split("_")[1].to_int()
	var dir = DirAccess.open(SCENES_DIR)
	if dir:
		for f in dir.get_files():
			if f.begins_with(SCENE_PREFIX + str(num + 1)):
				Global.change_scene(SCENES_DIR + f)
				return
