extends CanvasLayer

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var blind_timer: Timer = $BlindTimer
@onready var end_panel: Control = $EndPanel

func _ready() -> void:
	end_panel.visible = false
	anim_player.play("blind") # lance animation
	blind_timer.start()


func _on_blind_timer_timeout() -> void:
	end_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _on_restart_button_pressed() -> void:
	Global.reset_game()
	Global.change_scene("res://scenes/scene_1_data.tscn")


func _on_menu_button_pressed() -> void:
	Global.reset_game()
	Global.change_scene("res://scenes/main_menu.tscn")
