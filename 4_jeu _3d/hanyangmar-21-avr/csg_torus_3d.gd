@tool
extends CSGTorus3D

var speed = 4
var t = 3.6

func _process(delta: float) -> void:
	t += delta
	position.x = tan(t * speed*0.5)
	position.y = cos(t * speed*4)
	position.z = sin(t * speed*5)
