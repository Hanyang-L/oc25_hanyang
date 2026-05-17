extends Node3D

const SCENES_DIR = "res://scenes/"
const SCENE_PREFIX = "scene_"

@onready var next_scene_area: Area3D = $NextSceneArea

func _ready() -> void:
	Engine.time_scale = 1.0
	Global.current_scene_path = "res://scenes/scene_3_gpu.tscn"

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
