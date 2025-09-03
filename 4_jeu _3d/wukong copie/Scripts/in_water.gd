extends Area2D


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("in water")
		Engine.time_scale=0.5


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("Player"):
		print("out water")
		Engine.time_scale=1
