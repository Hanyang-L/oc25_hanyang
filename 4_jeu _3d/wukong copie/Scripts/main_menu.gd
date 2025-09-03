extends Control 

@onready var timer: Timer = $Timer
@onready var timer_2: Timer = $Timer2


func _on_jouer_pressed() -> void:
	timer.start()
	
func _on_timer_timeout():
	get_tree(). change_scene_to_file("res://Scenes/level/Level_1.tscn")


func _on_quitter_pressed() -> void:
	timer_2.start()
	
func _on_timer_2_timeout() -> void:
	get_tree(). quit()
