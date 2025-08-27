extends Area2D

@onready var timer: Timer = $Timer
var lives :  int = 3
var player_body: Node2D

func _on_body_entered(body: Node2D) -> void:
	print("DED")
	player_body = body
	Engine. time_scale = 0.4
	timer.start()

func _on_timer_timeout() -> void:
	print("Restart")
	var spawn = get_tree().current_scene.get_node("spawn point")
	var player = get_tree().current_scene.get_node("Player")
	player.global_position = spawn.global_position
	if lives == 3 and player_body:
		player_body.set_collision_mask_value(16, false)  
		player_body.set_collision_mask_value(1, true)
	Engine. time_scale = 1.0
