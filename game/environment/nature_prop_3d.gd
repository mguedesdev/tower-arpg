extends Node3D
class_name NatureProp3D
## Elemento de ambientação 3D estilizado do Stylized Nature MegaKit (Godot 4).
## Gerencia instanciação de malha, materiais estilizados sem bordas pretas,
## sombras nítidas e otimizadas (apenas em árvores e rochas), colisores cilíndricos de tronco
## e sistema de Dithered Fade (screen-door transparency) ultra-leve na fila opaca,
## afetando exclusivamente as copas das árvores que obstruem a câmera (máx 1 a 3 árvores simultâneas).

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
var _canopy_meshes: Array[MeshInstance3D] = []
var _target_fade: float = 1.0
var _current_fade: float = 1.0

# Shader Dithered Fade carregado previamente
const FOLIAGE_SHADER: Shader = preload("res://assets/shaders/nature_foliage_dither.gdshader")

# Cache estático de PackedScenes e Materiais Pré-compilados
static var _scene_cache: Dictionary = {}
static var _material_cache: Dictionary = {}

# Registro estático de árvores ativas para oclusão centralizada (sem process individual em cada árvore)
static var _active_trees: Array[NatureProp3D] = []


static func get_cached_scene(path: String) -> PackedScene:
	if _scene_cache.has(path):
		return _scene_cache[path] as PackedScene
	if not ResourceLoader.exists(path):
		return null
	var sc: PackedScene = load(path) as PackedScene
	if sc != null:
		_scene_cache[path] = sc
	return sc


func _enter_tree() -> void:
	if _is_tree_category() and not _active_trees.has(self):
		_active_trees.append(self)


func _exit_tree() -> void:
	_active_trees.erase(self)


func configure(path: String, prop_cat: PropCategory, custom_scale: Vector3 = Vector3.ONE, custom_yaw: float = 0.0) -> void:
	model_path = path
	category = prop_cat
	base_scale = custom_scale
	rotation.y = custom_yaw

	_setup_visual()
	_setup_collision()
	
	# Desativa _process individual: a oclusão é controlada centralizadamente para máxima performance
	set_process(false)


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
	_canopy_meshes.clear()
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
					var is_foliage: bool = (
						sm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
						or (sm.albedo_texture != null and ("Leaf" in sm.resource_name or "Leaves" in sm.resource_name))
					)

					if is_foliage and _is_tree_category():
						# Copa de árvore: usa o Shader de Dithered Fade na FILA OPACA (sem alpha blend)
						var mat_key: String = "dither_%s_s%d" % [model_path, s]
						var foliage_mat: ShaderMaterial = null

						if _material_cache.has(mat_key):
							foliage_mat = _material_cache[mat_key] as ShaderMaterial
						else:
							foliage_mat = ShaderMaterial.new()
							foliage_mat.shader = FOLIAGE_SHADER
							if sm.albedo_texture != null:
								foliage_mat.set_shader_parameter("albedo_texture", sm.albedo_texture)
							foliage_mat.set_shader_parameter("alpha_scissor_threshold", 0.50)
							foliage_mat.set_shader_parameter("foliage_tint", Color(0.95, 1.0, 0.95))
							foliage_mat.set_shader_parameter("material_roughness", 0.85)
							_material_cache[mat_key] = foliage_mat

						mi.set_surface_override_material(s, foliage_mat)
						mi.set_instance_shader_parameter("fade_amount", 1.0)
						if not _canopy_meshes.has(mi):
							_canopy_meshes.append(mi)

					else:
						# Tronco de árvore, rocha ou vegetação decorativa estática: material opaco PBR
						var mat_key: String = "opaque_%s_s%d" % [model_path, s]
						var opaque_mat: StandardMaterial3D = null

						if _material_cache.has(mat_key):
							opaque_mat = _material_cache[mat_key] as StandardMaterial3D
						else:
							opaque_mat = sm.duplicate() as StandardMaterial3D
							opaque_mat.metallic = 0.0
							if is_foliage:
								# Arbustos/samambaias no chão: recorte alpha com Burley
								opaque_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
								opaque_mat.alpha_scissor_threshold = 0.50
								opaque_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
								opaque_mat.roughness = 0.85
								opaque_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
							else:
								# Tronco e rocha 100% sólidos
								opaque_mat.cull_mode = BaseMaterial3D.CULL_BACK
								opaque_mat.roughness = 0.90
								opaque_mat.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
							_material_cache[mat_key] = opaque_mat

						mi.set_surface_override_material(s, opaque_mat)

	for child in node.get_children():
		_find_and_prepare_meshes(child)


func _should_cast_shadow() -> bool:
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


func set_target_fade(fade: float) -> void:
	_target_fade = fade


func apply_fade_step(delta: float) -> void:
	if not is_equal_approx(_current_fade, _target_fade):
		_current_fade = move_toward(_current_fade, _target_fade, delta * 5.0)
		for mi in _canopy_meshes:
			if is_instance_valid(mi):
				mi.set_instance_shader_parameter("fade_amount", _current_fade)


## Gerenciador Central de Oclusão de Câmera
## Localiza no máximo 1 a 3 árvores obstruindo a linha de visão (+X, +Z) do jogador e esmaece suavemente suas copas via Dithered Fade
static func update_tree_occlusion(player_pos: Vector3, delta: float) -> void:
	if _active_trees.is_empty():
		return

	# Coleta candidatos que estejam no corredor entre a câmera isométrica (+X, +Z) e o jogador
	var candidates: Array[Dictionary] = []

	for tree in _active_trees:
		if not is_instance_valid(tree):
			continue
		var t_pos := tree.global_position
		var dx: float = t_pos.x - player_pos.x
		var dz: float = t_pos.z - player_pos.z

		# A câmera isométrica do jogo observa a partir de (+X, +Z) em direção à origem
		if dx > 0.2 and dx < 5.8 and dz > 0.2 and dz < 5.8:
			var dist_diag: float = (dx + dz) * 0.7071
			var lateral_dist: float = absf(dx - dz) * 0.7071
			if lateral_dist < (2.0 * tree.base_scale.x) and dist_diag < 6.8:
				var score: float = dist_diag + lateral_dist * 1.5
				candidates.append({"tree": tree, "score": score})

	# Ordena por proximidade da linha de visão e seleciona no MÁXIMO 2 a 3 árvores
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["score"] < b["score"]
	)

	var fading_trees: Array[NatureProp3D] = []
	var max_fading: int = mini(2, candidates.size()) # Limite estrito de no máximo 2 árvores simultâneas
	for i in range(max_fading):
		var t: NatureProp3D = candidates[i]["tree"] as NatureProp3D
		fading_trees.append(t)
		t.set_target_fade(0.35)

	# Todas as outras árvores da floresta permanecem 100% sólidas (fade_amount = 1.0)
	for tree in _active_trees:
		if is_instance_valid(tree) and not fading_trees.has(tree):
			tree.set_target_fade(1.0)
		if is_instance_valid(tree):
			tree.apply_fade_step(delta)
