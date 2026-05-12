extends Area3D

## Coffre final. Patrick doit avoir la clé pour l'ouvrir → écran de victoire.

@export var locked_message: String = "🔒 Le coffre est verrouillé... il te faut une clé !"
@export var unlock_message: String = "Appuie sur E pour ouvrir le coffre"

var player_in_range: bool = false
var player_ref: Node = null
var hud: CanvasLayer = null
var opened: bool = false

@onready var lid: Node3D = get_node_or_null("../ChestVisual/ChestLid")


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("die") and not opened:
		player_in_range = true
		player_ref = body
		hud = get_tree().current_scene.get_node_or_null("HUD")
		if hud:
			if Global.has_key:
				hud.set_subtitle(unlock_message)
			else:
				hud.set_subtitle(locked_message)
		if body.has_signal("interact_pressed"):
			if not body.interact_pressed.is_connected(_on_interact):
				body.interact_pressed.connect(_on_interact)


func _on_body_exited(body: Node3D) -> void:
	if body == player_ref:
		player_in_range = false
		if hud:
			hud.set_subtitle("")
		if body.has_signal("interact_pressed"):
			if body.interact_pressed.is_connected(_on_interact):
				body.interact_pressed.disconnect(_on_interact)


func _on_interact() -> void:
	if not player_in_range or opened:
		return
	if not Global.has_key:
		if hud:
			hud.show_message("🔒 Verrouillé !", 2.0)
		return
	# Ouvrir le coffre
	opened = true
	if hud:
		hud.set_subtitle("")
		hud.show_message("🎉 Tu as trouvé le trésor !", 5.0)
	# Animation d'ouverture du couvercle
	if lid:
		var tween = create_tween()
		tween.tween_property(lid, "rotation:x", deg_to_rad(-100), 1.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Notifier la scène pour afficher l'écran de victoire
	get_tree().current_scene.victory()
