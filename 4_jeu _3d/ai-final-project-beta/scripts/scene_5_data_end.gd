extends Node3D

var _fans: Array[Node3D] = []
var _skeleton: Node3D
@onready var _fade_player: AnimationPlayer = $FadeOverlay/FadePlayer

func _ready() -> void:
	Engine.time_scale = 1.0
	Global.current_scene_path = "res://scenes/scene_5_data_end.tscn"
	Global.has_key = true # Sophia arrive dans scene 5 avec la clé par défaut
	_setup_fans()  # crée les ventilos
	_setup_skeleton() # lance animation Idle + instalation zone  dialogue

	$HUD.set_key_visible(true)  # affiche la clé dans HUD
	$HUD.set_subtitle("Utilise la clé pour ouvrir le coffre !")

func _process(delta: float) -> void:
	for fan in _fans:
		fan.rotate_object_local(Vector3.UP, deg_to_rad(360.0) * delta) # rotation locale --> suit l'orientation du pivot

func _setup_skeleton() -> void:
	_skeleton = $BarSkeleton
	var anim := _skeleton.find_child("AnimationPlayer", true, false) as AnimationPlayer

	if anim and anim.has_animation("Idle"):
		anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("Idle")

func _on_chest_opening(_body: Node3D) -> void:
	$FadeOverlay.visible = true
	$HUD.set_subtitle("")
	_fade_player.play("fade_out")

func _on_chest_opened(body: Node3D) -> void:
	if _fade_player.is_playing():
		await _fade_player.animation_finished

	var plate_pos: Vector3 = $BeachBar/PlateMR.global_position
	body.global_position = plate_pos + Vector3(0, -0.95, 3.0)
	body.rotation.y = 0.0
	body.can_look = false
	body.has_gravity = false
	body.aim_at(_skeleton.global_position + Vector3(0,-1.4, 0))
	_fade_player.play("fade_in")
	await _fade_player.animation_finished
	var anim := _skeleton.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim and anim.has_animation("1H_Ranged_Aiming"):
		anim.get_animation("1H_Ranged_Aiming").loop_mode = Animation.LOOP_NONE
		anim.play("1H_Ranged_Aiming")
		await get_tree().create_timer(0.4).timeout
		$BeachBar/PlateMR.visible = true
		await anim.animation_finished
		if anim.has_animation("Idle"):
			anim.get_animation("Idle").loop_mode = Animation.LOOP_LINEAR
			anim.play("Idle")


	$HUD.show_message("Merci beaucoup pour votre aide.\nVoici votre plat. Bon appétit !", 4.0)
	await get_tree().create_timer(3.0).timeout
	$HUD.set_subtitle("Merci!")
	await get_tree().create_timer(2.0).timeout

	var end_screen = load("res://ui/end_screen.tscn").instantiate()
	get_tree().current_scene.add_child(end_screen)

func _setup_fans() -> void:
	# couleurs des pales
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = Color(0.106, 0.157, 0.176, 1.0)

	# couleurs du centre
	var hub_mat := StandardMaterial3D.new()
	hub_mat.albedo_color = Color(0.237, 0.262, 0.433, 1.0)
	hub_mat.metallic = 0.9
	hub_mat.roughness = 0.2

	# pales des ventilo Radiator3
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.238, 0.014, 0.042)
	blade_mesh.surface_set_material(0, blade_mat)

	# pales plus petites des ventilo le Radiator2
	var rad2_blade_mesh := BoxMesh.new()
	rad2_blade_mesh.size = Vector3(0.140, 0.010, 0.028)
	rad2_blade_mesh.surface_set_material(0, blade_mat)

	# pales GPU
	var gpu_blade_mesh := BoxMesh.new()
	gpu_blade_mesh.size = Vector3(0.170, 0.010, 0.030)
	gpu_blade_mesh.surface_set_material(0, blade_mat)

	# moyeau cylindrique de tout les ventilos
	var hub_mesh := CylinderMesh.new()
	hub_mesh.top_radius = 0.04
	hub_mesh.bottom_radius = 0.04
	hub_mesh.height = 0.05
	hub_mesh.radial_segments = 10
	hub_mesh.surface_set_material(0, hub_mat)

	# créer ventilos
	for cyl in $PC/Radiator3.get_children():
		_add_fan(cyl, blade_mesh, hub_mesh, $PC/TopFans)
	# ventilo Radiator2 axe de rotation forcé en -X
	for cyl in $PC/Radiator2.get_children():
		_add_fan(cyl, rad2_blade_mesh, hub_mesh, $PC/Fans, Vector3(-1.0, 0.0, 0.0))
	# ventilos dessus GPU
	for cyl in $PC/GPU/GpuBody.get_children():
		_add_fan(cyl, gpu_blade_mesh, hub_mesh, $PC/TopFans)
	# ventilos face GPU
	for cyl in $PC/GPU/GpuFace.get_children():
		_add_fan(cyl, gpu_blade_mesh, hub_mesh, $PC/Fans)

func _add_fan(node: Node, blade_mesh: Mesh, hub_mesh: Mesh, container: Node3D,
		force_axis: Vector3 = Vector3.ZERO) -> void:  # impose l'axe le vecteur nul
	if not node is CSGCylinder3D:
		return  # si pas cylindriques alors ignorés
	var cyl := node as CSGCylinder3D
	# convertissement position en position locale de $PC pour le pivot
	var local_pos: Vector3 = $PC.to_local(cyl.global_position)
	# si pas de force_axis --> utilise axe Y naturel
	var spin_axis: Vector3 = force_axis if force_axis != Vector3.ZERO else cyl.global_basis.y.normalized()
	var pivot := _make_fan_aligned(local_pos, spin_axis, blade_mesh, hub_mesh, 8, (cyl as CSGCylinder3D).radius * 0.50)
	container.add_child(pivot)
	_fans.append(pivot)  # stocké pour la rotation dans _process

func _make_fan_aligned(center: Vector3, spin_axis: Vector3, blade_mesh: Mesh,
		hub_mesh: Mesh, n_blades: int, radius: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = center
	# aligne la base du pivot sur l'axe spin réel
	pivot.transform.basis = Basis(Quaternion(Vector3.UP, spin_axis))
	var hub := MeshInstance3D.new()
	hub.mesh = hub_mesh
	pivot.add_child(hub)
	# 8 bras espacés de 45deg autour du moyeau
	for i in n_blades:
		var arm := Node3D.new()
		arm.rotation_degrees.y = i * (360.0 / n_blades)
		pivot.add_child(arm)
		var blade := MeshInstance3D.new()
		blade.mesh = blade_mesh
		blade.position = Vector3(radius, 0.0, 0.0)
		blade.rotation_degrees.x = 30.0  # inclinaison de pale (pour (effet visuel)
		arm.add_child(blade)
	return pivot
