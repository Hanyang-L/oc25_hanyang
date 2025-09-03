extends Area2D

const FILE_BEGIN = "res://Scenes/level/level_"
@onready var timer: Timer = $Timer

var next_level_path: String = ""

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("get key!")
		timer.start()
		Engine. time_scale = 0.5
		var current_scene_file = get_tree().current_scene.scene_file_path
		print(current_scene_file)
		var next_level_number = current_scene_file.to_int() + 1
		next_level_path = FILE_BEGIN + str(next_level_number) + ".tscn"

func _on_timer_timeout() -> void:
	Engine. time_scale = 1.0
	get_tree().change_scene_to_file(next_level_path)
