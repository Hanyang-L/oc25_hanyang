extends Area2D

@onready var timer: Timer = $Timer

func _on_body_entered(body: Node2D) -> void:
	timer.start()

func _on_timer_timeout() -> void:
	var spawn = get_tree().current_scene.get_node("spawn point_2")
	var player = get_tree().current_scene.get_node("Player")
	player.global_position = spawn.global_position
