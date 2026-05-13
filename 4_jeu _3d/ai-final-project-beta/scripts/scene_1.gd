extends Node3D

const SCENES_DIR = "res://scenes/"
const SCENE_PREFIX = "scene_"

@onready var patrick: CharacterBody3D = $Patrick
@onready var hud = $HUD
@onready var water_exit_area: Area3D = $WaterExitArea
@onready var next_scene_area: Area3D = $NextSceneArea
@onready var bubbles: GPUParticles3D = $Bubbles
@onready var splash: GPUParticles3D = $ExitSplash
@onready var env: WorldEnvironment = $WorldEnvironment
@onready var sun: DirectionalLight3D = $DirectionalLight3D

var exited_water: bool = false

func _ready() -> void:
	Engine.time_scale = 1.0
	Global.current_scene_path = "res://scenes/scene_1_underwater.tscn"
	patrick.underwater = true
	water_exit_area.body_entered.connect(_on_water_exit)
	next_scene_area.body_entered.connect(_on_next_scene)
	hud.set_subtitle("Remonte vers la surface !")

func _on_water_exit(body: Node3D) -> void:
	if exited_water or not body.has_method("die"):
		return
	exited_water = true
	patrick.underwater = false
	bubbles.emitting = false
	splash.emitting = true
	_transition_to_beach_env()
	hud.set_subtitle("")

func _transition_to_beach_env() -> void:
	var tween = create_tween()
	tween.tween_method(_set_fog_density, 0.04, 0.005, 1.5)
	tween.parallel().tween_method(_set_fog_color,
		Color(0.02, 0.15, 0.35), Color(0.7, 0.85, 1.0), 1.5)
	sun.light_color = Color(1.0, 0.95, 0.8)
	sun.light_energy = 1.2

func _set_fog_density(v: float) -> void:
	env.environment.fog_density = v

func _set_fog_color(c: Color) -> void:
	env.environment.fog_light_color = c

func _on_next_scene(body: Node3D) -> void:
	if not body.has_method("die"):
		return
	Engine.time_scale = 0.5
	var filename = get_tree().current_scene.scene_file_path.get_file()
	var num = filename.split("_")[1].to_int()
	var dir = DirAccess.open(SCENES_DIR)
	if dir:
		for f in dir.get_files():
			if f.begins_with(SCENE_PREFIX + str(num + 1)):
				Global.change_scene(SCENES_DIR + f)
				return
