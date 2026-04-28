@tool
extends CSGBox3D

var speed = 3
var t = 3.3

func _process(delta: float) -> void:
	t += delta
	position.x = cos(t * speed*4)
	position.y = tan(t * speed*0.4)
	position.z = sin(t * speed*5)
