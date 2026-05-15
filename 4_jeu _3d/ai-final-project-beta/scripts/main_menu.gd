extends Control

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _on_start_button_pressed() -> void:
	Global.change_scene("res://scenes/scene_1_underwater.tscn")
