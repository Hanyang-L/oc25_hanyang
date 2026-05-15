@tool
extends Node3D

const _B := "res://assets/dungeon_assets/building/"
const _P := "res://assets/dungeon_assets/props/"

const W  := 10.0  # largeur (X)
const D  := 8.0   # profondeur (Z)
const H  := 3.2   # hauteur (Y)
const WT := 0.3   # épaisseur des murs

var _dungeon_mat: StandardMaterial3D
var _rng          := RandomNumberGenerator.new()
var _candle_lights: Array[OmniLight3D] = []
var _torch_lights:  Array[OmniLight3D] = []
var _time := 0.0


func _ready() -> void:
	_rng.seed = 42
	_make_material()

	var structure := Node3D.new()
	structure.name = "Structure"
	add_child(structure)

	var props := Node3D.new()
	props.name = "Props"
	add_child(props)

	var fx := Node3D.new()
	fx.name = "Particles"
	add_child(fx)

	var lights := Node3D.new()
	lights.name = "Lights"
	add_child(lights)

	_build_floor_with_hole(structure)
	_build_walls(structure)
	_place_wall_deco(structure)
	_place_props(props, fx, lights)
	_setup_ambient_light(lights)


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_time += delta
	for i in _candle_lights.size():
		_candle_lights[i].light_energy = 0.45 + sin(_time * 8.0 + float(i) * 1.7) * 0.08
	for i in _torch_lights.size():
		_torch_lights[i].light_energy = 1.6 + sin(_time * 5.0 + float(i) * 2.3) * 0.18


# ── Matériau ─────────────────────────────────────────────────────────────────

func _make_material() -> void:
	_dungeon_mat = StandardMaterial3D.new()
	_dungeon_mat.albedo_texture = load("res://assets/dungeon_assets/dungeon_albedo.png")
	_dungeon_mat.roughness = 0.85


func _apply_dungeon_mat(node: Node) -> void:
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi := child as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for i in mi.get_surface_override_material_count():
			mi.set_surface_override_material(i, _dungeon_mat)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _place_glb(path: String, parent: Node3D, pos: Vector3,
		rot := Vector3.ZERO, sc := Vector3.ONE) -> Node3D:
	var node: Node3D = (load(path) as PackedScene).instantiate()
	parent.add_child(node)
	node.position = pos
	node.rotation = rot
	node.scale    = sc
	_apply_dungeon_mat(node)
	return node


func _csg_box(parent: Node3D, sz: Vector3, pos: Vector3,
		use_col := true) -> CSGBox3D:
	var b := CSGBox3D.new()
	b.size          = sz
	b.position      = pos
	b.material      = _dungeon_mat
	b.use_collision = use_col
	parent.add_child(b)
	return b


# ── Structure ─────────────────────────────────────────────────────────────────

func _build_floor_with_hole(structure: Node3D) -> void:
	var comb := CSGCombiner3D.new()
	comb.name          = "Floor"
	comb.use_collision = true
	structure.add_child(comb)

	# Dalle en bois
	var floor_b := CSGBox3D.new()
	floor_b.size     = Vector3(W, 0.3, D)
	floor_b.position = Vector3(0.0, -0.15, 0.0)
	floor_b.material = _dungeon_mat
	comb.add_child(floor_b)

	# Trou circulaire coin avant-gauche (futur escalier)
	var hole := CSGCylinder3D.new()
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.radius    = 1.3
	hole.height    = 0.6
	hole.position  = Vector3(-3.5, -0.15, 2.5)
	hole.material  = _dungeon_mat
	comb.add_child(hole)


func _build_walls(structure: Node3D) -> void:
	# Mur arrière
	_csg_box(structure, Vector3(W, H, WT),
			Vector3(0.0, H * 0.5, -(D * 0.5)))
	# Mur gauche
	_csg_box(structure, Vector3(WT, H, D),
			Vector3(-(W * 0.5), H * 0.5, 0.0))
	# Mur droit
	_csg_box(structure, Vector3(WT, H, D),
			Vector3(W * 0.5, H * 0.5, 0.0))
	# Plafond (sans collision)
	_csg_box(structure, Vector3(W, WT, D),
			Vector3(0.0, H, 0.0), false)
	# Comptoir
	_csg_box(structure, Vector3(W - 2.0, 1.0, 0.6),
			Vector3(0.0, 0.5, -(D * 0.5) + 2.0))


func _place_wall_deco(structure: Node3D) -> void:
	var deco := Node3D.new()
	deco.name = "WallDeco"
	structure.add_child(deco)

	# Piliers aux 4 coins + 2 sur la façade
	for p in [
		Vector3(-(W * 0.5) + 0.1, 0.0, -(D * 0.5) + 0.1),
		Vector3( (W * 0.5) - 0.1, 0.0, -(D * 0.5) + 0.1),
		Vector3(-(W * 0.5) + 0.1, 0.0,  (D * 0.5) - 0.1),
		Vector3( (W * 0.5) - 0.1, 0.0,  (D * 0.5) - 0.1),
		Vector3(-2.5, 0.0,  D * 0.5 - 0.1),
		Vector3( 2.5, 0.0,  D * 0.5 - 0.1),
	]:
		_place_glb(_B + "pillar.glb", deco, p)

	# Arches ouvertes côté plage
	_place_glb(_B + "wall_arched.glb", deco,
			Vector3(-1.2, 0.0, D * 0.5), Vector3(0.0, PI, 0.0))
	_place_glb(_B + "wall_arched.glb", deco,
			Vector3( 1.2, 0.0, D * 0.5), Vector3(0.0, PI, 0.0))

	# Étagère sur le mur arrière
	_place_glb(_B + "wall_shelved.glb", deco,
			Vector3(-3.5, 0.0, -(D * 0.5) + 0.4))

	# Panneaux décoratifs sur les murs latéraux
	_place_glb(_B + "wall.glb", deco,
			Vector3(-(W * 0.5) + 0.4, 0.0, -1.5), Vector3(0.0, PI * 0.5, 0.0))
	_place_glb(_B + "wall.glb", deco,
			Vector3( W * 0.5 - 0.4, 0.0, -1.5), Vector3(0.0, -PI * 0.5, 0.0))


# ── Props ─────────────────────────────────────────────────────────────────────

func _place_props(props: Node3D, fx: Node3D, lights: Node3D) -> void:
	# Tables medium avec bougies et assiettes
	for tp in [Vector3(-2.5, 0.0, -0.5), Vector3(2.5, 0.0, -0.5)]:
		_place_glb(_P + "table_medium.glb", props, tp)
		_place_glb(_P + "candles.glb",    props, tp + Vector3(0.0, 0.82, 0.0))
		_place_glb(_P + "plate_food.glb", props, tp + Vector3(0.2, 0.82, 0.2))
		_maybe_light_candle(tp + Vector3(0.0, 0.95, 0.0), lights, fx)

	# Tables small avec bougies
	for tp in [Vector3(-1.5, 0.0, 2.0), Vector3(2.5, 0.0, 2.5)]:
		_place_glb(_P + "table_small.glb", props, tp)
		_place_glb(_P + "candles.glb",     props, tp + Vector3(0.0, 0.65, 0.0))
		_maybe_light_candle(tp + Vector3(0.0, 0.78, 0.0), lights, fx)

	# Chaises — table medium gauche (-2.5, 0, -0.5)
	_place_glb(_P + "chair.glb", props, Vector3(-2.5, 0.0,  0.6), Vector3(0.0, PI, 0.0))
	_place_glb(_P + "chair.glb", props, Vector3(-2.5, 0.0, -1.5))
	# Chaises — table medium droite (2.5, 0, -0.5)
	_place_glb(_P + "chair.glb", props, Vector3( 2.5, 0.0,  0.6), Vector3(0.0, PI, 0.0))
	_place_glb(_P + "chair.glb", props, Vector3( 2.5, 0.0, -1.5))
	# Chaises — tables small
	_place_glb(_P + "chair.glb", props, Vector3(-1.5, 0.0, 3.0), Vector3(0.0, PI, 0.0))
	_place_glb(_P + "chair.glb", props, Vector3( 2.5, 0.0, 3.5), Vector3(0.0, PI, 0.0))
	# Chaises au comptoir
	_place_glb(_P + "chair.glb", props, Vector3(-1.0, 0.0, -0.8), Vector3(0.0, PI, 0.0))
	_place_glb(_P + "chair.glb", props, Vector3( 1.0, 0.0, -0.8), Vector3(0.0, PI, 0.0))

	# Déco bar
	_place_glb(_P + "keg_decorated.glb",  props, Vector3(-1.5, 0.0, -3.3))
	_place_glb(_P + "keg_decorated.glb",  props, Vector3( 0.5, 0.0, -3.3))
	_place_glb(_P + "crates_stacked.glb", props, Vector3( 4.0, 0.0, -3.5))
	_place_glb(_P + "banner_mounted.glb", props, Vector3( 2.5, 2.0, -(D * 0.5) + 0.35))
	_place_glb(_P + "coin_stack.glb",     props, Vector3( 1.5, 1.05, -(D * 0.5) + 2.1))

	# Torches — mur arrière centre, mur gauche, mur droit
	_place_torch(
		Vector3(0.0, 2.2, -(D * 0.5) + 0.4),
		Vector3(0.0, 0.0, 0.0),
		Vector3(0.0, 0.15, 0.25),
		props, fx, lights)
	_place_torch(
		Vector3(-(W * 0.5) + 0.4, 2.2, -1.0),
		Vector3(0.0, PI * 0.5, 0.0),
		Vector3(0.25, 0.15, 0.0),
		props, fx, lights)
	_place_torch(
		Vector3(W * 0.5 - 0.4, 2.2, -1.0),
		Vector3(0.0, -PI * 0.5, 0.0),
		Vector3(-0.25, 0.15, 0.0),
		props, fx, lights)


func _place_torch(pos: Vector3, rot: Vector3, flame_off: Vector3,
		props: Node3D, fx: Node3D, lights: Node3D) -> void:
	_place_glb(_P + "torch_mounted.glb", props, pos, rot)
	var fp := pos + flame_off
	_make_flame_particles(fx, fp, 1.4)
	var tl := OmniLight3D.new()
	tl.position       = fp + Vector3(0.0, 0.1, 0.0)
	tl.light_color    = Color(1.0, 0.38, 0.05)
	tl.light_energy   = 1.6
	tl.omni_range     = 4.5
	tl.shadow_enabled = true
	lights.add_child(tl)
	_torch_lights.append(tl)


func _maybe_light_candle(light_pos: Vector3, lights: Node3D, fx: Node3D) -> void:
	if _rng.randi() % 3 == 0:
		return  # bougie éteinte (~33%)
	_make_flame_particles(fx, light_pos, 0.6)
	var cl := OmniLight3D.new()
	cl.position     = light_pos
	cl.light_color  = Color(1.0, 0.55, 0.15)
	cl.light_energy = 0.45
	cl.omni_range   = 2.5
	lights.add_child(cl)
	_candle_lights.append(cl)


# ── Flammes GPU Particles ─────────────────────────────────────────────────────

func _make_flame_particles(parent: Node3D, pos: Vector3, scale: float) -> GPUParticles3D:
	var gp := GPUParticles3D.new()
	gp.position      = pos
	gp.amount        = 12
	gp.lifetime      = 0.5
	gp.explosiveness = 0.0
	gp.local_coords  = true
	gp.visibility_aabb = AABB(Vector3(-0.4, -0.1, -0.4), Vector3(0.8, 0.9, 0.8))

	var mat := ParticleProcessMaterial.new()
	mat.direction              = Vector3(0.0, 1.0, 0.0)
	mat.spread                 = 18.0
	mat.initial_velocity_min   = 0.3 * scale
	mat.initial_velocity_max   = 0.7 * scale
	mat.gravity                = Vector3(0.0, 0.5, 0.0)
	mat.turbulence_enabled     = true
	mat.turbulence_noise_strength = 0.6
	mat.scale_min              = 0.06 * scale
	mat.scale_max              = 0.14 * scale

	# Gradient orange → rouge → transparent
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.7, 0.0, 1.0))
	grad.set_color(1, Color(0.4, 0.0, 0.0, 0.0))
	grad.add_point(0.5, Color(1.0, 0.25, 0.0, 0.8))
	var gt := GradientTexture1D.new()
	gt.gradient = grad
	mat.color_ramp = gt
	gp.process_material = mat

	# Mesh quad billboard pour chaque particule
	var quad := QuadMesh.new()
	quad.size = Vector2(0.1, 0.15) * scale
	var qmat := StandardMaterial3D.new()
	qmat.transparency               = BaseMaterial3D.TRANSPARENCY_ALPHA
	qmat.shading_mode               = BaseMaterial3D.SHADING_MODE_UNSHADED
	qmat.billboard_mode             = BaseMaterial3D.BILLBOARD_ENABLED
	qmat.albedo_color               = Color(1.0, 0.5, 0.0, 1.0)
	qmat.emission_enabled           = true
	qmat.emission                   = Color(1.0, 0.3, 0.0, 1.0)
	qmat.emission_energy_multiplier = 3.0
	quad.material   = qmat
	gp.draw_pass_1  = quad

	parent.add_child(gp)
	return gp


# ── Éclairage ambiant ─────────────────────────────────────────────────────────

func _setup_ambient_light(lights: Node3D) -> void:
	var al := OmniLight3D.new()
	al.name         = "AmbientFill"
	al.position     = Vector3(0.0, H - 0.5, 0.0)
	al.light_color  = Color(0.85, 0.78, 0.62)
	al.light_energy = 0.28
	al.omni_range   = 13.0
	lights.add_child(al)
