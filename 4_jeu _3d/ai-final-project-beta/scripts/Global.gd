extends Node

## Singleton autoload pour partager l'état entre toutes les scènes.
## CONFIGURATION : Project Settings > Autoload > ajouter ce fichier avec le nom "Global"

# état de Sophia
var has_key: bool = false 
var current_scene_path: String = ""


## Change de scène avec fade noir.
func change_scene(scene_path: String) -> void:
	current_scene_path = scene_path
	var transition = get_tree().root.get_node_or_null("SceneTransition")
	if transition and transition.has_method("fade_to_scene"):
		transition.fade_to_scene(scene_path)
	else:
		get_tree().change_scene_to_file(scene_path)


func reload_current_scene() -> void:
	if current_scene_path != "":
		change_scene(current_scene_path)
	else:
		get_tree().reload_current_scene()


## Réinitialise toute la progression.
func reset_game() -> void:
	has_key = false
	current_scene_path = ""
