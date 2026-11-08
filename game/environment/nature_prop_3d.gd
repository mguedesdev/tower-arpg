extends Node3D
class_name NatureProp3D
## Elemento de ambientação 3D estilizado do Stylized Nature MegaKit (Godot 4).
## Gerencia instanciação de malha, materiais estilizados sem bordas pretas,
## sombras nítidas e otimizadas (apenas em árvores e rochas), colisores cilíndricos de tronco
## e transparência suave quando obstrui a visão da câmera isométrica.

enum PropCategory {
	TREE_NORMAL,
	TREE_PINE,
	TREE_DEAD,
	TREE_TWISTED,
	ROCK_MEDIUM,
	BUSH,
	FERN,
	GRASS_LOW,
	GRASS_TALL,
	FLOWER,
	MUSHROOM,
	PEBBLE
}

@export var model_path: String = ""
@export var category: PropCategory = PropCategory.TREE_NORMAL
@export var is_blocking: bool = false
@export var base_scale: Vector3 = Vector3.ONE

var _static_body: StaticBody3D = null
var _collision_shape: CollisionShape3D = null
var _meshes: Array[MeshInstance3D] = []
var _fade_materials: Array[StandardMaterial3D] = []
var _is_faded: bool = false
var _target_alpha: float = 1.0
var _current_alpha: float = 1.0

# Cache estático de PackedScenes e Materiais Otimizados para altíssima performance
static var _scene_cache: Dictionary = {}
static var _material_cache: Dictionary = {}


static func get_cached_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path] as PackedScene
	if not ResourceLoader.exists(path):
		return null
	var sc: PackedScene = load(path) as PackedScene
	if sc != null:
		_scene_cache[path] = sc
	return sc


func configure(path: String, prop_cat: PropCategory, custom_scale: Vector3 = Vector3.ONE, custom_yaw: float = 0.0) -> void:
	model_path = path
	category = prop_cat
	base_scale = custom_scale
	rotation.y = custom_yaw

	_setup_visual()
	_setup_collision()


func _setup_visual() -> void:
	for child in get_children():
		if child is StaticBody3D:
			continue
		child.queue_free()

	if model_path.is_empty():
		return

	var scene: PackedScene = get_cached_scene(model_path)
	if scene == null:
		return

	var model_root: Node = scene.instantiate()
	if model_root == null:
		return

	add_child(model_root)
	model_root.scale = base_scale

	_meshes.clear()
	_fade_materials.clear()
	_find_and_prepare_meshes(model_root)


func _find_and_prepare_meshes(node: Node) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		_meshes.append(mi)

		var should_cast_shadow: bool = _should_cast_shadow()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if should_cast_shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

		var m: Mesh = mi.mesh
		if m != null:
			for s in range(m.get_surface_count()):
				var original_mat: Material = m.surface_get_material(s)
				if original_mat is StandardMaterial3D:
					var sm := original_mat as StandardMaterial3D
					var mat_key: String = "%s_s%d" % [model_path, s]
					var optimized_mat: StandardMaterial3D = null

					if _material_cache.has(mat_key):
						optimized_mat = _material_cache[mat_key] as StandardMaterial3D
					else:
						optimized_mat = sm.duplicate() as StandardMaterial3D
						optimized_mat.metallic = 0.0
						
						# Se for superfície de folha/vegetação com canal alpha
						if sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or sm.albedo_texture != null and "Leaf" in sm.resource_name or "Leaves" in sm.resource_name:
							optimized_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
							optimized_mat.alpha_scissor_threshold = 0.50
							optimized_mat.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
							optimized_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
							optimized_mat.roughness = 0.85
							optimized_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
						else:
							# Tronco ou rocha
							optimized_mat.cull_mode = BaseMaterial3D.CULL_BACK
							optimized_mat.roughness = 0.90

						_material_cache[mat_key] = optimized_mat

					mi.set_surface_override_material(s, optimized_mat)

					if _is_tree_category():
						# Para árvores, guardamos referência caso precise de fade por oclusão isométrica
						_fade_materials.append(optimized_mat)

	for child in node.get_children():
		_find_and_prepare_meshes(child)


func _should_cast_shadow() -> bool:
	# Apenas árvores e rochas médias projetam sombras nítidas no terreno.
	# Vegetação rasteira, flores, cogumelos e pedregulhos não projetam sombra (performance 60 FPS).
	match category:
		PropCategory.TREE_NORMAL, PropCategory.TREE_PINE, PropCategory.TREE_DEAD, PropCategory.TREE_TWISTED, PropCategory.ROCK_MEDIUM:
			return true
		_:
			return false


func _setup_collision() -> void:
	if _static_body != null:
		_static_body.queue_free()
		_static_body = null
		_collision_shape = null

	var trunk_radius: float = 0.0
	var trunk_height: float = 0.0
	var col_offset_y: float = 0.0

	match category:
		PropCategory.TREE_NORMAL:
			is_blocking = true
			trunk_radius = 0.38 * base_scale.x
			trunk_height = 2.20 * base_scale.y
			col_offset_y = trunk_height * 0.5
		PropCategory.TREE_PINE:
			is_blocking = true
			trunk_radius = 0.34 * base_scale.x
			trunk_height = 2.00 * base_scale.y
			col_offset_y = trunk_height * 0.5
		PropCategory.TREE_DEAD:
			is_blocking = true
			trunk_radius = 0.36 * base_scale.x
			trunk_height = 2.20 * base_scale.y
			col_offset_y = trunk_height * 0.5
		PropCategory.TREE_TWISTED:
			is_blocking = true
			trunk_radius = 0.55 * base_scale.x
			trunk_height = 2.40 * base_scale.y
			col_offset_y = trunk_height * 0.5
		PropCategory.ROCK_MEDIUM:
			is_blocking = true
			trunk_radius = 1.10 * base_scale.x
			trunk_height = 1.30 * base_scale.y
			col_offset_y = trunk_height * 0.5
		_:
			# Vegetação rasteira, arbustos, flores e pedrinhas NUNCA bloqueiam movimentação
			is_blocking = false

	if is_blocking and trunk_radius > 0.0 and trunk_height > 0.0:
		_static_body = StaticBody3D.new()
		_static_body.name = "ColliderBody"
		add_child(_static_body)

		_collision_shape = CollisionShape3D.new()
		_collision_shape.name = "TrunkShape"
		var cyl := CylinderShape3D.new()
		cyl.radius = trunk_radius
		cyl.height = trunk_height
		_collision_shape.shape = cyl
		_collision_shape.position = Vector3(0.0, col_offset_y, 0.0)
		_static_body.add_child(_collision_shape)


func _is_tree_category() -> bool:
	return category in [
		PropCategory.TREE_NORMAL,
		PropCategory.TREE_PINE,
		PropCategory.TREE_DEAD,
		PropCategory.TREE_TWISTED
	]


func _process(delta: float) -> void:
	if not _is_tree_category() or _fade_materials.is_empty():
		set_process(false)
		return

	var vp := get_viewport()
	if vp == null:
		return
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null:
		return

	var player_nodes := get_tree().get_nodes_in_group("player")
	if player_nodes.is_empty():
		return
	var player_node := player_nodes[0] as Node3D
	if player_node == null:
		return

	var p_pos := player_node.global_position
	var t_pos := global_position

	# Checa se esta árvore está no cone entre o jogador e a câmera isométrica (+X, +Z)
	var dx: float = t_pos.x - p_pos.x
	var dz: float = t_pos.z - p_pos.z
	var should_fade: bool = false

	if dx > 0.2 and dx < 6.0 and dz > 0.2 and dz < 6.0:
		var dist_along_diagonal: float = (dx + dz) * 0.7071
		var lateral_dist: float = absf(dx - dz) * 0.7071
		if lateral_dist < (2.2 * base_scale.x) and dist_along_diagonal < 7.5:
			should_fade = true

	_target_alpha = 0.35 if should_fade else 1.0

	if not is_equal_approx(_current_alpha, _target_alpha):
		_current_alpha = move_toward(_current_alpha, _target_alpha, delta * 4.5)
		for mat in _fade_materials:
			if _current_alpha < 0.98:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				mat.albedo_color.a = _current_alpha
			else:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				mat.alpha_scissor_threshold = 0.50
				mat.albedo_color.a = 1.0
