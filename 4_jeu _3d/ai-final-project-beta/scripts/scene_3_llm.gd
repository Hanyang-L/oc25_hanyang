extends Node3D

const SCENES_DIR = "res://scenes/"
const SCENE_PREFIX = "scene_"

# états possibles d'un bloc-mot au cours de la partie
const STATE_FREE   = 0  # posé sur l'étagère, ramassable
const STATE_HELD   = 1  # tenu par Sophia devant la caméra
const STATE_PLACED = 2  # placé dans un slot du panneau (freeze kinematic)

# 3 phrases à reconstituer — les mots sont dans le bon ordre dans chaque tableau
const PHRASES = [
	{"words": ["ami", "bricoleur", "jaune", "fruit", "mauvais"]},
	{"words": ["Bug", "problème", "ecran", "ami",  "une"]},
	{"words": ["IAs", "deep learning", "générations", "Large Language Model", "des"]}
]

# positions Z des étagères et panneaux — correspondent EXACTEMENT à la géométrie du .tscn
const ZONE_SHELF_Z = [38.0,  12.0, -14.0]
const ZONE_RACK_Z  = [22.0,  -4.0, -30.0]
const SLOT_Y       = [5.5, 4.2, 2.9, 1.6, 0.3]  # hauteurs des 5 emplacements sur chaque panneau
const BLOCK_X      = [-10.0, -5.0, 0.0, 5.0, 10.0]
const ZONE_COLORS  = [
	Color(0.15, 0.25, 0.78),
	Color(0.45, 0.15, 0.78),
	Color(0.1,  0.45, 0.62)
]
const INTERACT_RANGE = 4.0

var _blocks: Array = []
var _slots:  Array = []
var _held_block           = null
var _place_pending: Dictionary = {}  # buffer de téléports différés : RigidBody3D → Vector3
const RACK_RANGE = 6.0
var _correct_count: int   = 0
var _solved_phrases: int  = 0
var _rng := RandomNumberGenerator.new()

@onready var _sophia: CharacterBody3D = $Sophia
@onready var _sophia_head: Node3D     = $Sophia/Head
@onready var _hud: Node               = $HUD
@onready var _next_area: Area3D       = $NextSceneArea


func _ready() -> void:
	_rng.randomize()  # seed différent chaque partie → ordre de blocs différent
	Engine.time_scale = 1.0
	Global.current_scene_path = "res://scenes/scene_3_llm.tscn"
	# sortie bloquée tant que les 3 phrases ne sont pas résolues
	_next_area.monitoring = false
	$NextSceneArea/CollisionShape3D.disabled = true

	# initialise les données de slots (world_pos correspond aux positions du .tscn)
	for pi in 3:
		var row: Array = []
		for si in 5:
			row.append({
				"filled":     false,
				"block_data": null,
				"world_pos":  Vector3(0.0, SLOT_Y[si], ZONE_RACK_Z[pi] - 0.12)
			})
		_slots.append(row)

	# crée les blocs au runtime (RigidBody3D obligatoire — pas déclarable en .tscn avec Jolt)
	for pi in 3:
		var positions := [-10.0, -5.0, 0.0, 5.0, 10.0]
		_shuffle(positions)  # mélange les positions X pour que l'ordre soit aléatoire
		for wi in 5:
			_create_word_block(
				PHRASES[pi]["words"][wi], pi,
				Vector3(positions[wi], 1.4, ZONE_SHELF_Z[pi])
			)

	_sophia.interact_pressed.connect(_on_interact)
	_sophia.left_click_pressed.connect(_on_interact)  # E ou clic gauche → même action
	$NextSceneArea.body_entered.connect(_on_next_scene_body_entered)
	_hud.set_subtitle("E/clic gauche: prendre un bloc  |  approche le panneau  |  touches 1-5: placer dans la case correspondante")
	_hud.set_rules("Règles : Placer les mots dans la phrase correspondante, du plus probable au moins probable.")


func _create_word_block(word: String, phrase_idx: int, pos: Vector3) -> void:
	var rb := RigidBody3D.new()
	rb.mass            = 2.0
	rb.linear_damp     = 5.0
	rb.angular_damp    = 8.0
	# empêche les blocs de rouler ou de se coucher sur le côté
	rb.axis_lock_angular_x = true
	rb.axis_lock_angular_z = true
	rb.collision_layer = 1
	rb.collision_mask  = 1
	# kinematic freeze : la position peut être forcée par script même quand freeze=true
	rb.freeze_mode     = RigidBody3D.FREEZE_MODE_KINEMATIC
	rb.position        = pos

	# couleur par phrase : bleu / violet / cyan-vert
	var col: Color = ZONE_COLORS[phrase_idx]
	var m   := StandardMaterial3D.new()
	m.albedo_color             = col * 0.32  # couleur sombre en diffus
	m.emission_enabled         = true
	m.emission                 = col          # couleur vive en émissif
	m.emission_energy_multiplier = 0.55

	var visual := CSGBox3D.new()
	visual.name          = "Visual"  # nommé pour être retrouvé via get_node("Visual")
	visual.size          = Vector3(0.5, 0.5, 0.5)
	visual.use_collision = false  # collision gérée par le CollisionShape3D séparé
	visual.material      = m
	rb.add_child(visual)

	var cs  := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.5, 0.5, 0.5)
	cs.shape = box
	rb.add_child(cs)

	# label 3D billboard : toujours face caméra, pas de depth test
	var lbl := Label3D.new()
	lbl.text          = word
	lbl.font_size     = 52
	lbl.modulate      = Color(1, 1, 1)
	lbl.billboard     = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.position      = Vector3(0.0, 0.0, 0.3)  # en avant du bloc pour la lisibilité
	rb.add_child(lbl)

	add_child(rb)
	_blocks.append({"node": rb, "word": word, "phrase_idx": phrase_idx, "state": STATE_FREE})


func _shuffle(arr: Array) -> void:
	# Fisher-Yates in-place — évite les doublons de position
	for i in range(arr.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# ─── Interaction ─────────────────────────────────────────────────

func _on_interact() -> void:
	if _held_block != null:
		_drop_block()  # si on tient déjà un bloc → le lâcher
		return
	# sinon → prendre le bloc libre le plus proche dans INTERACT_RANGE
	var nearest = null
	var best    := INTERACT_RANGE
	for bd in _blocks:
		if bd["state"] != STATE_FREE:
			continue
		var d: float = bd["node"].global_position.distance_to(_sophia.global_position)
		if d < best:
			best    = d
			nearest = bd
	if nearest != null:
		_pick_up(nearest)


func _pick_up(bd: Dictionary) -> void:
	bd["node"].freeze = true  # freeze kinematic : position contrôlée par le script
	bd["state"]       = STATE_HELD
	_held_block       = bd
	_hud.set_subtitle(
		"Tenu : \"" + bd["word"] + "\"   —   Approche le panneau + 1-5   |  touches 1-5: placer dans la case correspondante"
	)


func _drop_block() -> void:
	if _held_block == null:
		return
	_held_block["node"].freeze          = false  # libère la physique
	_held_block["node"].linear_velocity = Vector3.ZERO
	_held_block["state"]                = STATE_FREE
	_held_block                         = null
	_hud.set_subtitle("E : prendre un bloc  |  approche le panneau  |   touches 1-5: placer dans la case correspondante")


func _physics_process(_delta: float) -> void:
	# Carry : met à jour la position du bloc tenu (doit être dans _physics_process avec Jolt)
	if _held_block != null:
		_held_block["node"].global_position = (
			_sophia_head.global_position
			+ _sophia_head.global_basis * Vector3(0.0, -0.2, -1.65)  # légèrement sous la caméra
		)
	# Placement différé : applique les téléports en attente au tick physique (compatibilité Jolt)
	if not _place_pending.is_empty():
		for rb in _place_pending:
			rb.global_position = _place_pending[rb]
		_place_pending.clear()


func _unhandled_input(event: InputEvent) -> void:
	if _held_block == null:
		return  # touches 1-5 ignorées si on ne tient rien
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1: _try_place(0)
		KEY_2: _try_place(1)
		KEY_3: _try_place(2)
		KEY_4: _try_place(3)
		KEY_5: _try_place(4)


func _find_near_rack() -> int:
	# retourne l'index de la phrase (0-2) si Sophia est assez proche d'un panneau
	for pi in 3:
		var rack_pos := Vector3(0.0, 3.5, ZONE_RACK_Z[pi])
		if _sophia.global_position.distance_to(rack_pos) < RACK_RANGE:
			return pi
	return -1  # aucun panneau à portée


func _try_place(slot_idx: int) -> void:
	var near_zone := _find_near_rack()
	if near_zone == -1:
		_hud.show_message("Approche le panneau de classement !", 2.0)
		return
	var pi: int = _held_block["phrase_idx"]
	if near_zone != pi:
		# le joueur a essayé de placer un bloc dans le mauvais panneau
		_hud.show_message("Ce bloc appartient à la zone " + str(pi + 1) + " !", 2.0)
		return
	var sd: Dictionary = _slots[pi][slot_idx]
	if sd["filled"]:
		_hud.show_message("L'emplacement " + str(slot_idx + 1) + " est déjà occupé !", 1.5)
		return
	var bd: Dictionary = _held_block
	bd["node"].freeze = true   # reste kinematic pour ne pas tomber
	# téléport différé dans _physics_process (compatibilité Jolt)
	_place_pending[bd["node"]] = sd["world_pos"] + Vector3(0.0, 0.3, 0.5)
	bd["state"]       = STATE_PLACED
	sd["filled"]               = true
	sd["block_data"]           = bd
	_held_block                = null
	_hud.set_subtitle("E : prendre un bloc  |  approche le panneau  |   touches 1-5: placer dans la case correspondante")
	_try_validate_phrase(pi)


# ─── Validation ──────────────────────────────────────────────────

func _try_validate_phrase(pi: int) -> void:
	# ne valide que si les 5 slots sont tous remplis
	for si in 5:
		if not _slots[pi][si]["filled"]:
			return
	var correct     := 0
	var wrong_items := []
	for si in 5:
		var sd: Dictionary = _slots[pi][si]
		var bd: Dictionary = sd["block_data"]
		if bd["word"] == PHRASES[pi]["words"][si]:
			correct += 1
		else:
			wrong_items.append([bd, sd])
	if correct == 5:
		for si in 5:
			_set_block_correct(_slots[pi][si]["block_data"])  # passe les blocs au vert
		_correct_count  += 5
		_solved_phrases += 1
		_hud.show_message(
			"Phrase " + str(pi + 1) + " réussie !  (" + str(_solved_phrases) + "/3)", 3.5
		)
		_check_all_complete()
	else:
		# éjecte les mauvais blocs vers Sophia pour un feedback visuel immédiat
		for item in wrong_items:
			var bd: Dictionary = item[0]
			var sd: Dictionary = item[1]
			sd["filled"]      = false
			sd["block_data"]  = null
			bd["state"]       = STATE_FREE
			bd["node"].freeze = false
			bd["node"].global_position += Vector3(0.0, 0.4, 1.8)
			bd["node"].linear_velocity  = Vector3(0.0, 2.5, 3.5)  # projecté vers Sophia
		_hud.show_message(str(correct) + " / 5 correct(s) — Réessaie !", 3.0)


func _set_block_correct(bd: Dictionary) -> void:
	var visual := bd["node"].get_node("Visual") as CSGBox3D
	var m      := StandardMaterial3D.new()
	m.albedo_color             = Color(0.08, 0.45, 0.15)
	m.emission_enabled         = true
	m.emission                 = Color(0.12, 0.78, 0.25)
	m.emission_energy_multiplier = 1.7
	visual.material = m


func _check_all_complete() -> void:
	if _correct_count < 15:  # 3 phrases × 5 mots = 15 blocs corrects requis
		return
	# déverrouille la sortie
	_next_area.monitoring = true
	$NextSceneArea/CollisionShape3D.disabled = false
	_hud.set_subtitle("Bravo ! Toutes les phrases résolues — dirige-toi vers la sortie.")


func _on_next_scene_body_entered(body: Node3D) -> void:
	if not body.has_method("die"):
		return
	# trouve dynamiquement scene_N+1 par numéro sans hardcoder le chemin
	var filename := get_tree().current_scene.scene_file_path.get_file()
	var num      := filename.split("_")[1].to_int()
	var dir      := DirAccess.open(SCENES_DIR)
	if dir:
		for f in dir.get_files():
			if f.begins_with(SCENE_PREFIX + str(num + 1)):
				Global.change_scene(SCENES_DIR + f)
				return
	Global.change_scene("res://scenes/main_menu.tscn")  # fallback si aucune scène suivante trouvée
