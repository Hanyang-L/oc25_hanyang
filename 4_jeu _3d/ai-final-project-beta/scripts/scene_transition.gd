extends CanvasLayer

## Gère le fondu noir entre scènes.
## CONFIGURATION : Project Settings > Autoload > ajouter SceneTransition.tscn avec le nom "SceneTransition"

@onready var color_rect: ColorRect = $ColorRect
const FADE_DURATION: float = 0.5


func _ready() -> void:
	color_rect.color = Color(0, 0, 0, 0)
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Fade noir → change de scène → fade de retour.
func fade_to_scene(scene_path: String) -> void:
	var tween = create_tween()
	tween.tween_property(color_rect, "color:a", 1.0, FADE_DURATION)
	await tween.finished
	
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame
	await get_tree().process_frame
	
	var tween_out = create_tween()
	tween_out.tween_property(color_rect, "color:a", 0.0, FADE_DURATION)
