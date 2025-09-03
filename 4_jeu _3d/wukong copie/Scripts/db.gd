extends Area2D

@onready var timer: Timer = $Timer
var lives :  int = 3

func _on_body_entered(body: Node2D) -> void:
	print("aie")
	lives -= 1
	print("Il reste ", lives, " vies.") 
	if lives <= 0:
		body.set_collision_mask_value(1, false)  
		body.set_collision_mask_value(16, true)
		Engine. time_scale = 0.8
		lives=3
