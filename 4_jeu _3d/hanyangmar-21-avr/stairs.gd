@tool
extends Node3D
## This class creates a staircase.
class_name Stairs

## Number of steps.
@export var repeat = 18:
	set(x):
		repeat = x
		if is_node_ready():
			create()
		
## Size of a step.
@export var size = Vector3(2, 0.5, 4):
	set(x):
		size = x
		if is_node_ready():
				create()
		
## Transposition vector (offset).
@export var transpose = Vector3(0, 1, 0):
	set(x):
		transpose = x 
		create()
		
# Euler angles of rotation
@export var rotate_3d = Vector3(10, 40, 10):
	set(x):
		rotate_3d = x
		create()

# Show nodes in scene tree		
@export var show_node = false:
	set(x):
		show_node = x
		create()

# Staircase material		
@export var material: BaseMaterial3D		

func _ready():
	create()
	
	
func create():
	for child in get_children():
		child.free()
	
	var box	
	box = CSGBox3D.new()
	box.name = "Step"
	box.size = size
	box.position = 0.5 * size
	box.material = material
	box.use_collision = true
	add_child(box)
	if show_node:
		box.owner = get_tree().edited_scene_root
	
	for i in (repeat):
		box = box.duplicate()
		box.name = "Step" + str(i+1)
		box.translate(transpose)
		box.rotate_x(deg_to_rad(rotate_3d.x))
		box.rotate_y(deg_to_rad(rotate_3d.y))
		box.rotate_z(deg_to_rad(rotate_3d.z))
		add_child(box)
		if show_node:
			box.owner = get_tree().edited_scene_root
