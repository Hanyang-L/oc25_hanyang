extends Node3D

# 32 chemins : 12 (I→H1) + 16 (H1→H2) + 4 (H2→O)
const PATH_NAMES: Array[String] = [
	"I1H1", "I1H2", "I1H3", "I1H4",
	"I2H1", "I2H2", "I2H3", "I2H4",
	"I3H1", "I3H2", "I3H3", "I3H4",
	"H1H5", "H1H6", "H1H7", "H1H8",
	"H2H5", "H2H6", "H2H7", "H2H8",
	"H3H5", "H3H6", "H3H7", "H3H8",
	"H4H5", "H4H6", "H4H7", "H4H8",
	"H5O", "H6O", "H7O", "H8O",
]

# combinaison exacte pour gagner : 18 chemins, 0 croisement
const CORRECT_PATHS: Array[String] = [
	"I1H1", "I1H2", "I3H4",
	"I2H3", "I2H4", "I3H2",
	"H1H5",
	"H1H8", "H2H6", "H2H8", "H3H5", "H3H6", "H4H6", "H4H7",
	"H5O", "H6O", "H7O", "H8O",
]

# position X de chaque neurone --> utilisé pour détecter les croisements géométriques
const NEURON_X: Dictionary = {
	"I1":-16.0, "I2":0.0, "I3":16.0,
	"H1":-24.0, "H2":-8.0, "H3":8.0, "H4":24.0,
	"H5":-24.0, "H6":-8.0, "H7":8.0, "H8":24.0,
	"O":0.0,
}

var _path_nodes: Dictionary = {}   # name -> CSGBox3D dans $Paths
var _path_active: Dictionary = {}  # name -> bool (activé par le joueur)
var _path_bodies: Dictionary = {}  # name -> StaticBody3D marchable
var _path_kills: Dictionary = {}   # name -> Area3D (zone de mort chemin rouge)
var _btn_meshes: Dictionary = {}   # name -> CSGBox3D du bouton pour coloration

# materiaux
var _mat_off: StandardMaterial3D
var _mat_btn_green: StandardMaterial3D
var _mat_btn_red: StandardMaterial3D
var _path_mat_green: StandardMaterial3D
var _path_mat_red: StandardMaterial3D
var _mat_indicator: StandardMaterial3D
var _path_indicators: Dictionary = {}  # name -> Array[MeshInstance3D] bandes cyan de bord

var _sophia: CharacterBody3D
var _hud: CanvasLayer
var _constraints_label: RichTextLabel


func _ready() -> void:
	_sophia = $Sophia
	_hud = $HUD
	_hud.set_key_visible(true)
	_build_materials()
	_init_paths()    # collecte les CSGBox3D de $Paths, tous invisibles au debut
	_init_buttons()  # configure boutons du panneau (taille, layer 4, signaux)
	_init_minimap()  # branche texture SubViewport sur l'écran minimap
	_sophia.left_click_pressed.connect(_on_raycast_interact)  # clic gauche --> inverse l'état d'un bouton à distance
	$KillZone.body_entered.connect(_on_kill_zone_body_entered)
	# clé cachée jusqu'a ce que la solution exacte soit activée
	$KeyPickup.visible = false
	$KeyPickup.monitoring = false
	_hud.set_subtitle("")
	_constraints_label = $ConstraintsRulesHUD/VBox/ConstraintsLabel
	_update_constraints_display([])


func _build_materials() -> void:
	# chemin vert : marchable, semi-transparent
	_path_mat_green = StandardMaterial3D.new()
	_path_mat_green.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_mat_green.albedo_color = Color(0.0, 0.05, 0.45, 0.50)
	_path_mat_green.emission_enabled = true
	_path_mat_green.emission = Color(0.05, 0.25, 0.9)
	_path_mat_green.emission_energy_multiplier = 1.5
	_path_mat_green.metallic = 0.2

	# chemin rouge : croisé / invalide, mortel
	_path_mat_red = StandardMaterial3D.new()
	_path_mat_red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_mat_red.albedo_color = Color(0.9, 0.05, 0.05, 0.50)
	_path_mat_red.emission_enabled = true
	_path_mat_red.emission = Color(1.0, 0.1, 0.05)
	_path_mat_red.emission_energy_multiplier = 2.0
	_path_mat_red.metallic = 0.5

	# bandes cyan sur les bords des chemins verts (indique que marchable)
	_mat_indicator = StandardMaterial3D.new()
	_mat_indicator.albedo_color = Color(0.0, 0.85, 1.0, 1.0)
	_mat_indicator.emission_enabled = true
	_mat_indicator.emission = Color(0.0, 0.9, 1.0)
	_mat_indicator.emission_energy_multiplier = 4.5

	# bouton inactif : gris sombre
	_mat_off = StandardMaterial3D.new()
	_mat_off.albedo_color = Color(0.18, 0.18, 0.22)
	_mat_off.emission_enabled = true
	_mat_off.emission = Color(0.15, 0.15, 0.25)
	_mat_off.emission_energy_multiplier = 0.4

	# bouton activé valide : vert
	_mat_btn_green = StandardMaterial3D.new()
	_mat_btn_green.albedo_color = Color(0.05, 0.8, 0.1)
	_mat_btn_green.emission_enabled = true
	_mat_btn_green.emission = Color(0.0, 1.0, 0.2)
	_mat_btn_green.emission_energy_multiplier = 0.5

	# bouton activé croisé : rouge
	_mat_btn_red = StandardMaterial3D.new()
	_mat_btn_red.albedo_color = Color(0.9, 0.05, 0.05)
	_mat_btn_red.emission_enabled = true
	_mat_btn_red.emission = Color(1.0, 0.1, 0.05)
	_mat_btn_red.emission_energy_multiplier = 0.5


func _init_paths() -> void:
	# tous invisibles au debut --> activés un par un par le joueur
	for path_node in $Paths.find_children("*", "CSGBox3D"):
		var n: String = path_node.name
		if not n in PATH_NAMES:
			continue
		_path_nodes[n] = path_node
		_path_active[n] = false
		path_node.visible = false


func _init_buttons() -> void:
	for path_name in PATH_NAMES:
		var btn := $ButtonPanel.get_node_or_null("Btn_" + path_name) as Node3D
		if not btn:
			continue
		_btn_meshes[path_name] = btn.get_node("Mesh") as CSGBox3D
		var zone := btn.get_node("Zone") as Area3D
		# redimensionne pour que le bouton soit plus visible sur le panneau
		(_btn_meshes[path_name] as CSGBox3D).size.y = 0.6
		(_btn_meshes[path_name] as CSGBox3D).position.y = 0.7
		zone.position.y = 0.7
		zone.collision_layer = 4  # layer 4 : zones de boutons uniquement
		var cs := zone.get_node("Shape") as CollisionShape3D
		var box := BoxShape3D.new()
		box.size = Vector3(1.1, 1.1, 0.4)
		cs.shape = box
		(_btn_meshes[path_name] as CSGBox3D).material = _mat_off

func _init_minimap() -> void:
	# texture live du SubViewport sur l'écran MapScreen
	var vp := $MinimapViewport as SubViewport
	if not vp:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = vp.get_texture()
	mat.emission_enabled = true
	mat.emission_texture = vp.get_texture()  # même texture en émissif --> écran qui brille
	mat.emission_energy_multiplier = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED  # visible des deux côtés
	$MapScreen.material = mat

func _on_btn_interact(path_name: String) -> void:
	# inverse l'état actif du chemin puis recalcule tout le réseau
	_path_active[path_name] = not _path_active.get(path_name, false)
	_update_all_paths()

func _update_all_paths() -> void:
	# recalcule les croisements à chaque changement (calcul global, pas incrémental)
	var crossing: Dictionary = {}
	var active_list: Array = []
	for n in PATH_NAMES:
		if _path_active.get(n, false):
			active_list.append(n)
	# détecte tous les couples croisés dans la liste active
	for i in range(active_list.size()):
		for j in range(i + 1, active_list.size()):
			if _paths_cross(active_list[i], active_list[j]):
				crossing[active_list[i]] = true
				crossing[active_list[j]] = true
	# applique état (off / vert / rouge) à chaque chemin
	for path_name in PATH_NAMES:
		if not _path_active.get(path_name, false):
			_set_path_state(path_name, "off")
		elif crossing.has(path_name):
			_set_path_state(path_name, "red")
		else:
			_set_path_state(path_name, "green")
	# miroir la couleur des boutons sur l'état du chemin
	for path_name in _btn_meshes:
		var mesh: CSGBox3D = _btn_meshes[path_name]
		if not _path_active.get(path_name, false):
			mesh.material = _mat_off
		elif crossing.has(path_name):
			mesh.material = _mat_btn_red
		else:
			mesh.material = _mat_btn_green
	# vérifie si la solution exacte est atteinte --> révèle la clé
	var solved := active_list.size() == CORRECT_PATHS.size()
	if solved:
		for n in CORRECT_PATHS:
			if not n in active_list:
				solved = false
				break
	$KeyPickup.visible = solved
	$KeyPickup.monitoring = solved
	_update_constraints_display(active_list)


func _update_constraints_display(active_list: Array) -> void:
	# affiche en rouge si le nombre de chemins dépasse 18
	var count := active_list.size()
	var count_color := "red" if count > 18 else "white"
	# vérifie que chaque plateforme source a bien 2 chemins sortants
	var platform_ok := true
	for src in ["I1", "I2", "I3", "H1", "H2", "H3", "H4"]:
		var c := 0
		for p in active_list:
			if p.begins_with(src):
				c += 1
		if c != 2:
			platform_ok = false
			break
	var platform_color := "white" if platform_ok else "red"
	_constraints_label.parse_bbcode(
		"[color=%s]Chemins activés : %d/18[/color]\n[color=%s]Chaque plateforme : 2 chemins partants[/color]" \
		% [count_color, count, platform_color]
	)


## applique l'état à un chemin : invisible / vert marchable / rouge mortel
func _set_path_state(path_name: String, state: String) -> void:
	var path_node: CSGBox3D = _path_nodes.get(path_name)
	if not path_node:
		return
	# off ou green --> supprime la kill zone rouge si elle existe
	if state == "off" or state == "green":
		if _path_kills.has(path_name):
			_path_kills[path_name].queue_free()
			_path_kills.erase(path_name)
	if state == "off":
		path_node.visible = false
		_remove_indicators(path_name)
		if _path_bodies.has(path_name):
			_path_bodies[path_name].queue_free()
			_path_bodies.erase(path_name)
		return
	# vert ou rouge : visible + crée un StaticBody3D marchable si absent
	path_node.visible = true
	if not _path_bodies.has(path_name):
		var body := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = path_node.size
		col.shape = box
		body.add_child(col)
		path_node.add_child(body)
		_path_bodies[path_name] = body
	if state == "green":
		path_node.material = _path_mat_green
		_create_indicators(path_name, path_node)  # bandes cyan sur les bords
	else:
		_remove_indicators(path_name)
		path_node.material = _path_mat_red
		# crée la kill zone rouge si absente
		if not _path_kills.has(path_name):
			var kill := Area3D.new()
			kill.collision_layer = 0
			kill.collision_mask = 1
			var kc := CollisionShape3D.new()
			var kb := BoxShape3D.new()
			kb.size = Vector3(path_node.size.x, 0.5, path_node.size.z)
			kc.shape = kb
			kill.add_child(kc)
			kill.body_entered.connect(_on_kill_zone_body_entered)
			path_node.add_child(kill)
			_path_kills[path_name] = kill


func _create_indicators(path_name: String, path_node: CSGBox3D) -> void:
	if _path_indicators.has(path_name):
		return  # déja crées pour ce chemin
	var sz: Vector3 = path_node.size
	var indicators: Array = []
	# 2 bandes cyan, une de chaque coté du chemin
	for side in [-1, 1]:
		var ind := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(sz.x, 0.06, 0.2)
		ind.mesh = mesh
		ind.material_override = _mat_indicator
		ind.position = Vector3(0.0, sz.y * 0.5 + 0.04, side * (sz.z * 0.5 - 0.7))
		path_node.add_child(ind)
		indicators.append(ind)
	_path_indicators[path_name] = indicators


func _remove_indicators(path_name: String) -> void:
	if not _path_indicators.has(path_name):
		return
	for ind in _path_indicators[path_name]:
		ind.queue_free()
	_path_indicators.erase(path_name)


## deux chemins se croisent si leurs X source et destination s'inversent
## valable seulment dans le même layer ; L3 (H→O) converge toujours --> jamais croisé
func _paths_cross(a: String, b: String) -> bool:
	var la := _get_layer(a)
	var lb := _get_layer(b)
	if la != lb or la == 3:  # L3 : tous vont vers O donc jamais croisés
		return false
	var xa := NEURON_X.get(a.substr(0, 2), 0.0) as float
	var ya := NEURON_X.get(a.substr(2), 0.0) as float
	var xb := NEURON_X.get(b.substr(0, 2), 0.0) as float
	var yb := NEURON_X.get(b.substr(2), 0.0) as float
	return (xa - xb) * (ya - yb) < 0.0  # signe négatif --> les X s'inversent --> croisement


func _get_layer(path_name: String) -> int:
	if path_name.begins_with("I"):
		return 1  # Input --> Hidden1
	if path_name.ends_with("O"):
		return 3  # Hidden2 --> Output
	return 2      # Hidden1 --> Hidden2


func _on_raycast_interact() -> void:
	# clic gauche --> raycast 15u sur layer 4 pour appuyer un bouton à distance
	var camera := _sophia.get_node("Head/Camera3D") as Camera3D
	var from := camera.global_position
	var to := from + camera.global_basis * Vector3(0, 0, -1) * 15.0
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true
	params.collision_mask = 4  # layer 4 uniquement
	var result := get_world_3d().direct_space_state.intersect_ray(params)
	if result.is_empty():
		return
	var hit := result["collider"] as Area3D
	if not hit:
		return
	var btn := hit.get_parent() as Node3D
	if not btn:
		return
	var path_name := btn.name.trim_prefix("Btn_")
	if not path_name in PATH_NAMES:
		return
	_on_btn_interact(path_name)


func _on_kill_zone_body_entered(body: Node3D) -> void:
	if body.has_method("die"):
		body.die()  # Sophia tombe dans le vide ou marche sur un chemin rouge
