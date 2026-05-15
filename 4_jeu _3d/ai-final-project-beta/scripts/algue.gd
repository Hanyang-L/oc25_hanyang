extends Node3D

const STEM_COLORS: Array[Color] = [
	Color(0.08, 0.70, 0.18, 1.0),  # vert vif
	Color(0.04, 0.42, 0.12, 1.0),  # vert foncé
	Color(0.04, 0.52, 0.35, 1.0),  # vert sarcelle
	Color(0.38, 0.68, 0.08, 1.0),  # vert-jaune
	Color(0.28, 0.48, 0.10, 1.0),  # olive
	Color(0.02, 0.30, 0.22, 1.0),  # vert profond
	Color(0.12, 0.60, 0.45, 1.0),  # cyan-vert
]

func _ready() -> void:
	var anim: AnimationPlayer = $AnimPlayer
	var dur: float = anim.get_animation("sway").length
	anim.seek(randf() * dur, true)
	var s := randf_range(0.7, 1.6)
	scale = Vector3(s, s, s)
	rotation_degrees.y = randf() * 360.0

	var base_color: Color = STEM_COLORS[randi() % STEM_COLORS.size()]
	var top_color: Color  = base_color.lightened(randf_range(0.05, 0.25))

	var mat_stem := StandardMaterial3D.new()
	mat_stem.albedo_color = base_color
	mat_stem.roughness = 0.8
	$Stalk.material = mat_stem

	var mat_top := StandardMaterial3D.new()
	mat_top.albedo_color = top_color
	$Top.material = mat_top
