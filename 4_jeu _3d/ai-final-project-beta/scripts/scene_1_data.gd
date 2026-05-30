extends Node3D

const SCENES_DIR = "res://scenes/"
const SCENE_PREFIX = "scene_"

var _fans: Array[Node3D] = []
var _sophia: CharacterBody3D
var _display_connected: bool = false

func _ready() -> void:
	Engine.time_scale = 1.0  # réinitialise si on revient depuis un menu pausé
	Global.current_scene_path = "res://scenes/scene_1_data.tscn"  # pour le respawn après mort
	_sophia = $Sophia
	_setup_fans()     # crée les ventilateurs PC au runtime (Jolt + CSGCylinder3D requis)
	_setup_display()  # installe la zone de proximité autour de l'écran

	$HUD.set_subtitle("Il se passe quelque chose au data center.")
	if Global.has_key:
		# si la clé est déjà ramassée (retour depuis scene_5), spawn près du coffre
		$Sophia.global_position = Vector3(3.5, 1.0, -11.0)
		$Sophia.rotation.y = 0.0
		$HUD.set_subtitle("Utilise la clé pour ouvrir le coffre !")

func _process(delta: float) -> void:
	for fan in _fans:
		# rotation locale : suit l'orientation du pivot peu importe l'axe du ventilateur
		fan.rotate_object_local(Vector3.UP, deg_to_rad(360.0) * delta)

func _setup_fans() -> void:
	# matériau sombre mat pour les pales (plastique PC)
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.106, 0.157, 0.176, 1.0)

	# matériau métallique brillant pour le moyeu central
	var hub_mat := StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.04, 0.04, 0.05)
	hub_mat.metallic = 0.9
	hub_mat.roughness = 0.2

	# pales des grands ventilateurs Radiator3 (radiateur principal du PC)
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.238, 0.014, 0.042)
	blade_mesh.surface_set_material(0, blade_mat)

	# pales plus petites pour le Radiator2 (radiateur secondaire)
	var rad2_blade_mesh := BoxMesh.new()
	rad2_blade_mesh.size = Vector3(0.140, 0.010, 0.028)
	rad2_blade_mesh.surface_set_material(0, blade_mat)

	# pales GPU : légèrement plus grandes que Radiator2, plus petites que Radiator3
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

	# Radiator3 → ventilateurs sur le dessus du PC ($PC/TopFans)
	for cyl in $PC/Radiator3.get_children():
		_add_fan(cyl, blade_mesh, hub_mesh, $PC/TopFans)
	# Radiator2 → ventilateurs latéraux ($PC/Fans), axe de rotation forcé en -X
	for cyl in $PC/Radiator2.get_children():
		_add_fan(cyl, rad2_blade_mesh, hub_mesh, $PC/Fans, Vector3(-1.0, 0.0, 0.0))
	# GPU corps → ventilateurs dessus GPU (TopFans)
	for cyl in $PC/GPU/GpuBody.get_children():
		_add_fan(cyl, gpu_blade_mesh, hub_mesh, $PC/TopFans)
	# GPU face → ventilateurs face GPU (Fans latéraux)
	for cyl in $PC/GPU/GpuFace.get_children():
		_add_fan(cyl, gpu_blade_mesh, hub_mesh, $PC/Fans)

func _setup_display() -> void:
	var screen: Node3D = $Display/CSGBox3D

	# zone de proximité invisible autour de l'écran pour détecter Sophia
	var area := Area3D.new()
	area.collision_layer = 0  # pas de couche propre — détection seulement
	area.collision_mask = 1   # détecte Sophia (layer 1)
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(5.0, 3.0, 6.0)  # boîte large pour être facile à entrer
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
	# connecte le signal interact_pressed de Sophia → permet d'appuyer E
	_sophia.interact_pressed.connect(_on_display_interact)
	_display_connected = true

func _on_display_exited(body: Node3D) -> void:
	if body != _sophia:
		return
	if _display_connected:
		_sophia.interact_pressed.disconnect(_on_display_interact)
		_display_connected = false
	# rétablit le sous-titre approprié selon l'état de progression
	if not Global.has_key:
		$HUD.set_subtitle("Il se passe quelque chose au data center.")
	else:
		$HUD.set_subtitle("Utilise la clé pour ouvrir le coffre !")

func _on_display_interact() -> void:
	if _display_connected:
		# déconnecte immédiatement pour éviter un double déclenchement
		_sophia.interact_pressed.disconnect(_on_display_interact)
		_display_connected = false

	# gèle Sophia pendant la cinématique d'aspiration
	_sophia.can_move = false
	_sophia.has_gravity = false
	_sophia.velocity = Vector3.ZERO

	$HUD.set_subtitle("")
	$HUD.show_message("Sophia est aspirée dans le GPU...", 2.0)

	var target: Vector3 = $PC/GPU/GpuBody.global_position

	# tween parallèle : position ET scale réduisent en même temps → effet aspiration
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_sophia, "global_position", target, 1.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_property(_sophia, "scale", Vector3.ZERO, 1.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	# changement de scène seulement après la fin des 1.5 secondes
	tween.chain().tween_callback(func():
		Global.change_scene("res://scenes/scene_2_gpu.tscn")
	)

func _add_fan(node: Node, blade_mesh: Mesh, hub_mesh: Mesh, container: Node3D,
		force_axis: Vector3 = Vector3.ZERO) -> void:
	if not node is CSGCylinder3D:
		return  # ignore les enfants non-cylindriques des radiateurs
	var cyl := node as CSGCylinder3D
	# convertit la position globale du cylindre en locale dans $PC pour le pivot
	var local_pos: Vector3 = $PC.to_local(cyl.global_position)
	# si pas de force_axis → utilise l'axe Y naturel du cylindre (face vers le haut)
	var spin_axis: Vector3 = force_axis if force_axis != Vector3.ZERO else cyl.global_basis.y.normalized()
	var pivot := _make_fan_aligned(local_pos, spin_axis, blade_mesh, hub_mesh, 8, (cyl as CSGCylinder3D).radius * 0.50)
	container.add_child(pivot)
	_fans.append(pivot)  # stocké pour la rotation dans _process

func _make_fan_aligned(center: Vector3, spin_axis: Vector3, blade_mesh: Mesh,
		hub_mesh: Mesh, n_blades: int, radius: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = center
	# aligne la base du pivot sur l'axe de spin réel
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
