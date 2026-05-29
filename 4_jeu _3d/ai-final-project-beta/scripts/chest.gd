extends Node3D

var _opened: bool = false


func _ready() -> void:
	$InteractArea.body_entered.connect(_on_body_entered)

# ouverture du coffre lorsque Sophia dans la zone et devient imobile
func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("die") or _opened:
		return
	if not Global.has_key:
		var hud = get_tree().current_scene.get_node_or_null("HUD")
		if hud:
			hud.show_message("Il te faut une clé !", 2.0)
		return
	_opened = true
	body.can_move = false
	$ChestMesh/AnimationPlayer.play("open")
	var end_screen = load("res://ui/end_screen.tscn").instantiate()
	get_tree().current_scene.add_child(end_screen)
