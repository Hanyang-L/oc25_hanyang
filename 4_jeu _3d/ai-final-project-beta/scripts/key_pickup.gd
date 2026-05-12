extends Area3D

## Pickup pour la clé. Quand Patrick s'en approche → message + appui E pour ramasser.

@export var pickup_message: String = "Appuie sur E pour ramasser la clé"

var player_in_range: bool = false
var player_ref: Node = null
var hud: CanvasLayer = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("die"):  # Patrick
		player_in_range = true
		player_ref = body
		hud = get_tree().current_scene.get_node_or_null("HUD")
		if hud:
			hud.set_subtitle(pickup_message)
		# Connecter le signal d'interaction
		if body.has_signal("interact_pressed"):
			if not body.interact_pressed.is_connected(_on_interact):
				body.interact_pressed.connect(_on_interact)


func _on_body_exited(body: Node3D) -> void:
	if body == player_ref:
		player_in_range = false
		if hud:
			hud.set_subtitle("Trouve l'escalier qui descend...")
		if body.has_signal("interact_pressed"):
			if body.interact_pressed.is_connected(_on_interact):
				body.interact_pressed.disconnect(_on_interact)


func _on_interact() -> void:
	if player_in_range:
		Global.has_key = true
		if hud:
			hud.show_message("🔑 Clé ramassée !", 3.0)
			hud.set_subtitle("Trouve l'escalier qui descend...")
		# Petit effet : la clé monte et disparaît
		var tween = create_tween()
		tween.tween_property(self, "position:y", position.y + 1.0, 0.4)
		tween.parallel().tween_property(self, "scale", Vector3.ZERO, 0.4)
		await tween.finished
		queue_free()
