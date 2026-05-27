extends Node3D

var _player_in_range: bool = false
var _player: Node = null
var _opened: bool = false


func _ready() -> void:
	$InteractArea.body_entered.connect(_on_body_entered)
	$InteractArea.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("die") or _opened:
		return
	_player_in_range = true
	_player = body
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		if Global.has_key:
			hud.set_subtitle("E : ouvrir le coffre")
		else:
			hud.set_subtitle("Il te faut la clé pour ouvrir ce coffre")
	if body.has_signal("interact_pressed"):
		if not body.interact_pressed.is_connected(_on_interact):
			body.interact_pressed.connect(_on_interact)


func _on_body_exited(body: Node3D) -> void:
	if body != _player:
		return
	_player_in_range = false
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if hud:
		hud.set_subtitle("")
	if body.has_signal("interact_pressed"):
		if body.interact_pressed.is_connected(_on_interact):
			body.interact_pressed.disconnect(_on_interact)


func _on_interact() -> void:
	if not _player_in_range or _opened:
		return
	var hud = get_tree().current_scene.get_node_or_null("HUD")
	if not Global.has_key:
		if hud:
			hud.show_message("Il te faut la clé !", 2.0)
		return
	_opened = true
	if hud:
		hud.set_subtitle("")
	if _player and _player.has_signal("interact_pressed"):
		if _player.interact_pressed.is_connected(_on_interact):
			_player.interact_pressed.disconnect(_on_interact)
	$ChestMesh/AnimationPlayer.play("open")
	var end_screen = load("res://ui/end_screen.tscn").instantiate()
	get_tree().current_scene.add_child(end_screen)
