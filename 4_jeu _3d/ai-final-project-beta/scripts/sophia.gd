extends CharacterBody3D

## Sophia — joueur FPS avec mouvement, saut, interaction (touche E, clic gauche souris) et mode low gravity.

# Paramètres exposés
@export var can_move: bool = true
@export var has_gravity: bool = true
@export var can_jump: bool = true
@export var can_double_jump: bool = true
@export var can_sprint: bool = true


@export_group("Speeds")
@export var look_speed: float = 0.002
@export var base_speed: float = 7.0
@export var jump_velocity: float = 4.5
@export var sprint_speed: float = 10.0

# mode low gravity (mouvement plus lent, gravité réduite)
@export_group("Lowgravity")
@export var lowgravity: bool = false
@export var lowgravity_speed_factor: float = 0.8
@export var lowgravity_gravity_factor: float = 0.7

# actions input utilisées par joueur
@export_group("Input Actions")
@export var input_left: String = "ui_left"
@export var input_right: String = "ui_right"
@export var input_forward: String = "ui_up"
@export var input_back: String = "ui_down"
@export var input_jump: String = "ui_accept"
@export var input_sprint: String = "sprint"
@export var input_interact: String = "interact"

# État interne
var mouse_captured: bool = false
var look_rotation: Vector2
var move_speed: float = 0.0
var _double_jump_available: bool = false
var topdown_mode: bool = false
var _current_anim: String = ""  # mémorisation de l'animation cours

# Signaux
signal interact_pressed   # Émis quand touche E appuiée
signal left_click_pressed   # Émis lors clic gauche souris

# Références
@onready var head: Node3D = $Head
@onready var collider: CollisionShape3D = $Collider
@onready var fps_camera: Camera3D = $Head/Camera3D
@onready var topdown_camera: Camera3D = $TopDownCamera
@onready var _anim: AnimationPlayer = $SophiaMesh/AnimationPlayer


func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	capture_mouse()
	if _anim == null:
		push_warning("sophia.gd: AnimationPlayer introuvable à SophiaMesh/AnimationPlayer")
	# Layer 2 seulement → invisible pour la caméra FPS (cull_mask=1), visible pour TopDown (cull_mask=3)
	for vi in $SophiaMesh.find_children("*", "VisualInstance3D", true, false):
		vi.layers = 2


func _notification(what: int) -> void:
	# Re-capture quand la fenêtre reprend le focus (ex: retour depuis le menu)
	if what == NOTIFICATION_WM_WINDOW_FOCUS_IN and mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# _input capte les événements avant l'UI ; _unhandled_input laisse l'UI les consommer en premier.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		_toggle_camera()
	if mouse_captured and not topdown_mode and event is InputEventMouseMotion:
		rotate_look(event.relative)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not mouse_captured:
				capture_mouse()
				# Ne pas émettre left_click_pressed : ce clic sert uniquement à recapturer la souris.
			else:
				left_click_pressed.emit()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	# Interaction (touche E)
	if InputMap.has_action(input_interact) and Input.is_action_just_pressed(input_interact):
		interact_pressed.emit()


func _physics_process(delta: float) -> void:
	# low gravity
	if has_gravity:
		if not is_on_floor():
			var grav = get_gravity()
			if lowgravity:
				grav *= lowgravity_gravity_factor
			velocity += grav * delta
	
	# jump
	if can_jump:
		if is_on_floor():
			_double_jump_available = can_double_jump
			if Input.is_action_just_pressed(input_jump):
				velocity.y = jump_velocity * 1.2  # boost léger : pop distinct du double-saut
		elif can_double_jump and _double_jump_available and Input.is_action_just_pressed(input_jump):
			velocity.y = jump_velocity
			_double_jump_available = false
	
	# speed
	if can_sprint and Input.is_action_pressed(input_sprint):
		move_speed = sprint_speed
	else:
		move_speed = base_speed
	
	# Sous-marin = plus lent
	if lowgravity:
		move_speed *= lowgravity_speed_factor
	
	# Mouvement
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		if is_on_floor():
			if move_dir:
				velocity.x = move_dir.x * move_speed
				velocity.z = move_dir.z * move_speed
			else:
				velocity.x = move_toward(velocity.x, 0, move_speed)
				velocity.z = move_toward(velocity.z, 0, move_speed)
	else:
		velocity.x = 0
		velocity.z = 0
	
	move_and_slide()
	_update_animation()


func _update_animation() -> void:
	if _anim == null:
		return
	var anim: String
	if not is_on_floor():
		anim = "Jump" if velocity.y > 0.1 else "Fall"
	else:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		if input_dir.length() < 0.1:
			anim = "Idle"
		elif input_dir.x < -0.3:
			anim = "RunTiltL"
		elif input_dir.x > 0.3:
			anim = "RunTiltR"
		else:
			anim = "Run"
	if anim != _current_anim:
		_current_anim = anim
		_anim.play(anim)


func rotate_look(rot_input: Vector2):
	look_rotation.x -= rot_input.y * look_speed
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-80), deg_to_rad(80))
	look_rotation.y -= rot_input.x * look_speed
	# Réinitialiser Basis() à chaque frame évite l'accumulation d'erreurs flottantes sur la rotation Y.
	transform.basis = Basis()
	rotate_y(look_rotation.y)
	head.transform.basis = Basis()
	head.rotate_x(look_rotation.x)

func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


func _toggle_camera() -> void:
	topdown_mode = not topdown_mode
	if topdown_mode:
		fps_camera.current = false
		topdown_camera.current = true
		release_mouse()
	else:
		topdown_camera.current = false
		fps_camera.current = true
		capture_mouse()


func die():
	Global.reload_current_scene()


func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction: " + input_sprint)
		can_sprint = false
