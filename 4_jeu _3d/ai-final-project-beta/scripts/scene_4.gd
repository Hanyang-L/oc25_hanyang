extends Node3D

const SCENES_DIR = "res://scenes/"
const SCENE_PREFIX = "scene_"
const EDGE_OFFSET = 1.45

func _ready() -> void:
	Engine.time_scale = 1.0
	_setup_path_collision()
	_setup_edge_strips()

func _setup_path_collision() -> void:
	for path in $Paths.get_children():
		if not path is CSGBox3D:
			continue
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = path.size
		col.shape = box
		body.add_child(col)
		path.add_child(body)

func _setup_edge_strips() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.0, 0.4, 1.0, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.0, 0.5, 1.0, 1.0)
	mat.emission_energy_multiplier = 4.0
	for path in $Paths.get_children():
		if not path is CSGBox3D:
			continue
		for s in [-1, 1]:
			var strip := CSGBox3D.new()
			strip.size = Vector3(path.size.x, 0.06, 0.12)
			var z_off = path.transform.basis.z * EDGE_OFFSET * s
			strip.transform = Transform3D(path.transform.basis, path.transform.origin + z_off)
			strip.use_collision = false
			strip.material = mat
			$Paths.add_child(strip)

func _on_kill_zone_body_entered(body: Node3D) -> void:
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
