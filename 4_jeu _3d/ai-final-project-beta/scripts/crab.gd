extends CharacterBody3D

## Crabe — patrouille entre deux points et tue Patrick au contact.

@export var patrol_distance: float = 6.0  ## Distance de patrouille (de chaque côté)
@export var move_speed: float = 2.5
@export var patrol_axis: Vector3 = Vector3(1, 0, 0)  ## Axe de patrouille (X par défaut)
@export var face_patrol_axis: bool = true  ## Si false, garde l'orientation initiale (marche en crabe)

var start_position: Vector3
var target_position: Vector3
var direction: int = 1  ## 1 ou -1


func _ready() -> void:
	start_position = global_position
	target_position = start_position + patrol_axis.normalized() * patrol_distance * direction
	# Petit délai aléatoire pour désynchroniser les crabes
	await get_tree().create_timer(randf() * 0.5).timeout


func _physics_process(delta: float) -> void:
	# Gravité
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
	
	# Mouvement vers la cible
	var to_target = target_position - global_position
	to_target.y = 0
	
	if to_target.length() < 0.5:
		# On a atteint la cible → on repart dans l'autre sens
		direction *= -1
		target_position = start_position + patrol_axis.normalized() * patrol_distance * direction
	else:
		var move_dir = to_target.normalized()
		velocity.x = move_dir.x * move_speed
		velocity.z = move_dir.z * move_speed
		if face_patrol_axis:
			look_at(global_position + move_dir, Vector3.UP)
	
	move_and_slide()


## Appelé quand Patrick entre dans la zone d'attaque du crabe.
func _on_attack_area_body_entered(body: Node3D) -> void:
	if body.has_method("die"):
		body.die()
