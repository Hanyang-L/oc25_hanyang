extends Node3D

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

const CORRECT_PATHS: Array[String] = [
	"I1H1", "I1H2", "I3H4",
	"I2H3", "I2H4", "I3H2",
	"H1H5",
	"H1H8", "H2H6", "H2H8", "H3H5", "H3H6", "H4H6", "H4H7",
	"H5O", "H6O", "H7O", "H8O",
]

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
var _path_mat_green: StandardMaterial3D
var _path_mat_red: StandardMaterial3D
var _mat_indicator: StandardMaterial3D
var _path_indicators: Dictionary = {}

var _sophia: CharacterBody3D
var _hud: CanvasLayer
var _current_btn_callable: Callable
var _constraints_label: RichTextLabel


func _ready() -> void:
	Engine.time_scale = 1.0
	_sophia = $Sophia
	_hud = $HUD
	_build_materials()
	_init_paths()
	_init_buttons()
	_init_minimap()
	_sophia.left_click_pressed.connect(_on_raycast_interact)
	$KillZone.body_entered.connect(_on_kill_zone_body_entered)
	$KeyPickup.visible = false
	$KeyPickup.monitoring = false
	_hud.set_subtitle("")
	_constraints_label = $ConstraintsHUD/Panel/VBox/ConstraintsLabel
	_update_constraints_display([])


func _build_materials() -> void:
	_path_mat_green = StandardMaterial3D.new()
	_path_mat_green.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_mat_green.albedo_color = Color(0.0, 0.05, 0.45, 0.50)
	_path_mat_green.emission_enabled = true
	_path_mat_green.emission = Color(0.05, 0.25, 0.9)
	_path_mat_green.emission_energy_multiplier = 1.5
	_path_mat_green.metallic = 0.2

	_path_mat_red = StandardMaterial3D.new()
	_path_mat_red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_path_mat_red.albedo_color = Color(0.9, 0.05, 0.05, 0.50)
	_path_mat_red.emission_enabled = true
	_path_mat_red.emission = Color(1.0, 0.1, 0.05)
	_path_mat_red.emission_energy_multiplier = 2.0
	_path_mat_red.metallic = 0.5

	_mat_indicator = StandardMaterial3D.new()
	_mat_indicator.albedo_color = Color(0.0, 0.85, 1.0, 1.0)
	_mat_indicator.emission_enabled = true
	_mat_indicator.emission = Color(0.0, 0.9, 1.0)
	_mat_indicator.emission_energy_multiplier = 4.5

	_mat_off = StandardMaterial3D.new()
	_mat_off.albedo_color = Color(0.18, 0.18, 0.22)
	_mat_off.emission_enabled = true
	_mat_off.emission = Color(0.15, 0.15, 0.25)
	_mat_off.emission_energy_multiplier = 0.4

	_mat_btn_green = StandardMaterial3D.new()
	_mat_btn_green.albedo_color = Color(0.05, 0.8, 0.1)
	_mat_btn_green.emission_enabled = true
	_mat_btn_green.emission = Color(0.0, 1.0, 0.2)
	_mat_btn_green.emission_energy_multiplier = 0.5

	_mat_btn_red = StandardMaterial3D.new()
	_mat_btn_red.albedo_color = Color(0.9, 0.05, 0.05)
	_mat_btn_red.emission_enabled = true
	_mat_btn_red.emission = Color(1.0, 0.1, 0.05)
	_mat_btn_red.emission_energy_multiplier = 0.5


func _init_paths() -> void:
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
		(_btn_meshes[path_name] as CSGBox3D).size.y = 0.6
		(_btn_meshes[path_name] as CSGBox3D).position.y = 0.7
		zone.position.y = 0.7
		zone.collision_layer = 4
		var cs := zone.get_node("Shape") as CollisionShape3D
		var box := BoxShape3D.new()
		box.size = Vector3(1.1, 1.1, 0.4)
		cs.shape = box
		(_btn_meshes[path_name] as CSGBox3D).material = _mat_off
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
	_hud.set_subtitle("")


func _on_btn_body_exited(body: Node3D, _path_name: String) -> void:
	if body != _sophia:
		return
	if _current_btn_callable.is_valid() and _sophia.interact_pressed.is_connected(_current_btn_callable):
		_sophia.interact_pressed.disconnect(_current_btn_callable)
	_current_btn_callable = Callable()
	_hud.set_subtitle("")


func _on_btn_interact(path_name: String) -> void:
	_path_active[path_name] = not _path_active.get(path_name, false)
	_update_all_paths()
	_hud.set_subtitle("")


func _update_all_paths() -> void:
	var crossing: Dictionary = {}
	var active_list: Array = []
	for n in PATH_NAMES:
		if _path_active.get(n, false):
			active_list.append(n)
	for i in range(active_list.size()):
		for j in range(i + 1, active_list.size()):
			if _paths_cross(active_list[i], active_list[j]):
				crossing[active_list[i]] = true
				crossing[active_list[j]] = true
	for path_name in PATH_NAMES:
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
	var count := active_list.size()
	var count_color := "red" if count > 18 else "white"
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


func _set_path_state(path_name: String, state: String) -> void:
	var path_node: CSGBox3D = _path_nodes.get(path_name)
	if not path_node:
		return
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
	# green or red: visible + ensure walkable StaticBody exists
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
		_create_indicators(path_name, path_node)
	else:
		_remove_indicators(path_name)
		path_node.material = _path_mat_red
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
		return
	var sz: Vector3 = path_node.size
	var indicators: Array = []
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


func _on_raycast_interact() -> void:
	var camera := _sophia.get_node("Head/Camera3D") as Camera3D
	var from := camera.global_position
	var to := from + camera.global_basis * Vector3(0, 0, -1) * 15.0
	var params := PhysicsRayQueryParameters3D.create(from, to)
	params.collide_with_areas = true
	params.collision_mask = 4
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
		body.die()
