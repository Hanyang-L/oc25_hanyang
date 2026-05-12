extends CanvasLayer

## HUD du joueur — affiche les messages contextuels et l'état de la clé.

@onready var message_label: Label = $MessageLabel
@onready var key_label: Label = $KeyLabel
@onready var subtitle_label: Label = $SubtitleLabel

var message_timer: float = 0.0


func _ready() -> void:
	message_label.text = ""
	subtitle_label.text = ""
	_update_key_display()


func _process(delta: float) -> void:
	_update_key_display()
	if message_timer > 0:
		message_timer -= delta
		if message_timer <= 0:
			message_label.text = ""


func _update_key_display() -> void:
	if Global.has_key:
		key_label.text = "🔑 Clé : ✅"
		key_label.modulate = Color(1, 0.9, 0.3)
	else:
		key_label.text = "🔑 Clé : ❌"
		key_label.modulate = Color(0.7, 0.7, 0.7)


## Affiche un message temporaire en haut (ex: "Clé ramassée !").
func show_message(text: String, duration: float = 2.0) -> void:
	message_label.text = text
	message_timer = duration


## Affiche un sous-titre permanent en bas (ex: "Appuie sur E pour interagir").
func set_subtitle(text: String) -> void:
	subtitle_label.text = text
