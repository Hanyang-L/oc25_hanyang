extends Area2D

@onready var timer: Timer = $Timer
var player_body: Node2D

	
func _on_body_entered(body: Node2D) -> void:
	print("NOP")
	player_body = body
	timer.start()
	
func _on_timer_timeout() -> void:
	print("Restart")
	var spawn = get_tree().current_scene.get_node("spawn point_1")
	var player = get_tree().current_scene.get_node("Player")
	player.global_position = spawn.global_position
	
