extends Node3D

const PATH_DENOM: Dictionary = {
	"I1H1":9, "I1H2":6, "I1H3":5, "I1H4":8,
	"I2H1":7, "I2H2":2, "I2H3":4, "I2H4":6,
	"I3H1":10, "I3H2":5, "I3H3":4, "I3H4":7,
	"H1H5":8, "H1H6":5, "H1H7":6, "H1H8":9,
	"H2H5":6, "H2H6":2, "H2H7":7, "H2H8":5,
	"H3H5":4, "H3H6":4, "H3H7":3, "H3H8":6,
	"H4H5":8, "H4H6":3, "H4H7":5, "H4H8":6,
	"H5O":5, "H6O":2, "H7O":3, "H8O":6,
}

# X world positions of each neuron, used to detect geometric crossings
const NEURON_X: Dictionary = {
	"I1":-16.0, "I2":0.0, "I3":16.0,
	"H1":-24.0, "H2":-8.0, "H3":8.0, "H4":24.0,
	"H5":-24.0, "H6":-8.0, "H7":8.0, "H8":24.0,
	"O":0.0,
}

var _path_nodes: Dictionary = {}   # name → CSGBox3D
var _path_active: Dictionary = {}  # name → bool
var _path_bodies: Dictionary = {}  # name → StaticBody3D (walkable collision)
var _path_kills: Dictionary = {}   # name → Area3D (kill zone on red paths)
var _btn_meshes: Dictionary = {}   # name → CSGBox3D (button visual)

var _mat_off: StandardMaterial3D
var _mat_btn_green: StandardMaterial3D
var _mat_btn_red: StandardMaterial3D
var _path_mat_off: StandardMaterial3D
var _path_mat_green: StandardMaterial3D
var _path_mat_red: StandardMaterial3D

var _sophia: CharacterBody3D
var _hud: CanvasLayer
var _current_btn_callable: Callable


func _ready() -> void:
	Engine.time_scale = 1.0
	_sophia = $Sophia
	_hud = $HUD
	_build_materials()
	_init_paths()
	_init_buttons()
	_init_minimap()
	$KillZone.body_entered.connect(_on_kill_zone_body_entered)
	_hud.set_subtitle("Saute sur I1 pour activer les chemins — trouve W=1/2")


func _build_materials() -> void:
	_path_mat_off = StandardMaterial3D.new()
	_path_mat_off.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_mat_off.albedo_color = Color(0.0, 0.0, 0.0, 0.0)

	_path_mat_green = StandardMaterial3D.new()
	_path_mat_green.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_mat_green.albedo_color = Color(0.05, 0.9, 0.2, 0.88)
	_path_mat_green.emission_enabled = true
	_path_mat_green.emission = Color(0.0, 1.0, 0.3)
	_path_mat_green.emission_energy_multiplier = 2.0
	_path_mat_green.metallic = 0.5

	_path_mat_red = StandardMaterial3D.new()
	_path_mat_red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_mat_red.albedo_color = Color(0.9, 0.05, 0.05, 0.88)
	_path_mat_red.emission_enabled = true
	_path_mat_red.emission = Color(1.0, 0.1, 0.05)
	_path_mat_red.emission_energy_multiplier = 2.0
	_path_mat_red.metallic = 0.5

	_mat_btn_green = StandardMaterial3D.new()
	_mat_btn_green.albedo_color = Color(0.05, 0.8, 0.1)
	_mat_btn_green.emission_enabled = true
	_mat_btn_green.emission = Color(0.0, 1.0, 0.2)
	_mat_btn_green.emission_energy_multiplier = 1.5

	_mat_btn_red = StandardMaterial3D.new()
	_mat_btn_red.albedo_color = Color(0.9, 0.05, 0.05)
	_mat_btn_red.emission_enabled = true
	_mat_btn_red.emission = Color(1.0, 0.1, 0.05)
	_mat_btn_red.emission_energy_multiplier = 1.5


func _init_paths() -> void:
	for path_node in $Paths.find_children("*", "CSGBox3D"):
		var n: String = path_node.name
		if not PATH_DENOM.has(n):
			continue
		_path_nodes[n] = path_node
		_path_active[n] = false
		path_node.material = _path_mat_off


func _init_buttons() -> void:
	var first_mesh := $ButtonPanel.get_node("Btn_I1H1/Mesh") as CSGBox3D
	_mat_off = first_mesh.material as StandardMaterial3D
	for path_name in PATH_DENOM:
		var btn := $ButtonPanel.get_node_or_null("Btn_" + path_name) as Node3D
		if not btn:
			continue
		_btn_meshes[path_name] = btn.get_node("Mesh") as CSGBox3D
		var zone := btn.get_node("Zone") as Area3D
		zone.body_entered.connect(_on_btn_body_entered.bind(path_name))
		zone.body_exited.connect(_on_btn_body_exited.bind(path_name))


func _init_minimap() -> void:
	var vp := $MinimapViewport as SubViewport
	if not vp:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = vp.get_texture()
	mat.emission_enabled = true
	mat.emission_texture = vp.get_texture()
	mat.emission_energy_multiplier = 0.9
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	$MapScreen.material = mat


func _on_btn_body_entered(body: Node3D, path_name: String) -> void:
	if body != _sophia:
		return
	if _current_btn_callable.is_valid() and _sophia.interact_pressed.is_connected(_current_btn_callable):
		_sophia.interact_pressed.disconnect(_current_btn_callable)
	_current_btn_callable = _on_btn_interact.bind(path_name)
	_sophia.interact_pressed.connect(_current_btn_callable)
	var action := "désactiver" if _path_active.get(path_name, false) else "activer"
	_hud.set_subtitle("E : " + action + " " + path_name)


func _on_btn_body_exited(body: Node3D, _path_name: String) -> void:
	if body != _sophia:
		return
	if _current_btn_callable.is_valid() and _sophia.interact_pressed.is_connected(_current_btn_callable):
		_sophia.interact_pressed.disconnect(_current_btn_callable)
	_current_btn_callable = Callable()
	_hud.set_subtitle("Saute sur I1 pour activer les chemins — trouve W=1/2")


func _on_btn_interact(path_name: String) -> void:
	_path_active[path_name] = not _path_active.get(path_name, false)
	_update_all_paths()
	var action := "désactiver" if _path_active.get(path_name, false) else "activer"
	_hud.set_subtitle("E : " + action + " " + path_name)


func _update_all_paths() -> void:
	var crossing: Dictionary = {}
	var active_list: Array = []
	for n in PATH_DENOM:
		if _path_active.get(n, false):
			active_list.append(n)
	for i in range(active_list.size()):
		for j in range(i + 1, active_list.size()):
			if _paths_cross(active_list[i], active_list[j]):
				crossing[active_list[i]] = true
				crossing[active_list[j]] = true
	for path_name in PATH_DENOM:
		if not _path_active.get(path_name, false):
			_set_path_state(path_name, "off")
		elif crossing.has(path_name):
			_set_path_state(path_name, "red")
		else:
			_set_path_state(path_name, "green")
	for path_name in _btn_meshes:
		var mesh: CSGBox3D = _btn_meshes[path_name]
		if not _path_active.get(path_name, false):
			mesh.material = _mat_off
		elif crossing.has(path_name):
			mesh.material = _mat_btn_red
		else:
			mesh.material = _mat_btn_green


func _set_path_state(path_name: String, state: String) -> void:
	var path_node: CSGBox3D = _path_nodes.get(path_name)
	if not path_node:
		return
	if state == "off" or state == "green":
		if _path_kills.has(path_name):
			_path_kills[path_name].queue_free()
			_path_kills.erase(path_name)
	if state == "off":
		path_node.material = _path_mat_off
		if _path_bodies.has(path_name):
			_path_bodies[path_name].queue_free()
			_path_bodies.erase(path_name)
		return
	# green or red: ensure walkable StaticBody exists
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
	else:
		path_node.material = _path_mat_red
		if not _path_kills.has(path_name):
			var kill := Area3D.new()
			kill.collision_layer = 0
			kill.collision_mask = 1
			var kc := CollisionShape3D.new()
			var kb := BoxShape3D.new()
			kb.size = path_node.size
			kc.shape = kb
			kill.add_child(kc)
			kill.body_entered.connect(_on_kill_zone_body_entered)
			path_node.add_child(kill)
			_path_kills[path_name] = kill


# Two paths cross if their X endpoints swap order (geometric inversion criterion).
# Only meaningful within the same layer (L1 or L2); L3 paths converge to O.
func _paths_cross(a: String, b: String) -> bool:
	var la := _get_layer(a)
	var lb := _get_layer(b)
	if la != lb or la == 3:
		return false
	var xa := NEURON_X.get(a.substr(0, 2), 0.0) as float
	var ya := NEURON_X.get(a.substr(2), 0.0) as float
	var xb := NEURON_X.get(b.substr(0, 2), 0.0) as float
	var yb := NEURON_X.get(b.substr(2), 0.0) as float
	return (xa - xb) * (ya - yb) < 0.0


func _get_layer(path_name: String) -> int:
	if path_name.begins_with("I"):
		return 1
	if path_name.ends_with("O"):
		return 3
	return 2


func _on_kill_zone_body_entered(body: Node3D) -> void:
	if body.has_method("die"):
		body.die()
