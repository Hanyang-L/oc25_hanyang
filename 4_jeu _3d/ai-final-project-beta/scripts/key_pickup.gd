extends Area3D

## Pickup automatique lorsque Sophia entre dans la zone

@export var next_scene_override: String = ""

var hud: CanvasLayer = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)

# ramassage automatique dès que le joueur touche la zone
func _on_body_entered(body: Node3D) -> void:
	if body.has_method("die"): # seul le joueur peut déclencher
		hud = get_tree().current_scene.get_node_or_null("HUD")
		_on_interact()


func _on_interact() -> void:
	Global.has_key = true
	if hud:
		hud.show_message("🔑 Clé ramassée !", 3.0)
		hud.set_subtitle("Enfin!")

# animation: la clé monte et disparaît
	var tween = create_tween()
	tween.tween_property(self, "position:y", position.y + 1.0, 0.4)
	tween.parallel().tween_property(self, "scale", Vector3.ZERO, 0.4)
	await tween.finished
	if next_scene_override != "":
		Global.change_scene(next_scene_override)
	queue_free()
