extends RefCounted
class_name StylizedTerrainService
## Serviço central e autoral para o Terreno Estilizado ARPG (Kit 10 / Godot 4).
## Gerencia carregamento de texturas pintadas à mão, compilação de shader e vinculação de máscaras de controle por região.

const SHADER_PATH: String = "res://assets/terrain_v2/terreno_estilizado_blend.gdshader"

const TEXTURES: Dictionary = {
	"grass_tex": "res://assets/terrain_v2/textures/01_grama_base.png",
	"dirt_tex": "res://assets/terrain_v2/textures/02_terra_base.png",
	"stone_tex": "res://assets/terrain_v2/textures/03_pedra_base.png",
	"grass_pebble_tex": "res://assets/terrain_v2/textures/04_grama_com_pedrinhas.png",
	"dirt_pebble_tex": "res://assets/terrain_v2/textures/06_terra_com_pedrinhas.png",
	"rocky_path_tex": "res://assets/terrain_v2/textures/07_trilha_pedregosa.png"
}

static var _cached_shader: Shader = null
static var _cached_textures: Dictionary = {}
static var _cached_materials: Dictionary = {}


static func get_shader() -> Shader:
	if _cached_shader == null:
		_cached_shader = load(SHADER_PATH) as Shader
	return _cached_shader


static func get_texture(uniform_name: String) -> Texture2D:
	if _cached_textures.has(uniform_name):
		return _cached_textures[uniform_name] as Texture2D
	if not TEXTURES.has(uniform_name):
		return null
	var path: String = String(TEXTURES[uniform_name])
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_cached_textures[uniform_name] = tex
	return tex


static func get_zone_masks(zone_id: String) -> Dictionary:
	var base_folder := "res://assets/terrain_v2/masks/%s" % zone_id
	var base_path := "%s/01_controle_base_terra_pedra.png" % base_folder
	var detail_path := "%s/02_controle_detalhes_pedrinhas.png" % base_folder

	if not ResourceLoader.exists(base_path):
		# Fallbacks graciosos
		base_folder = "res://assets/terrain_v2/masks/town"
		base_path = "%s/01_controle_base_terra_pedra.png" % base_folder
		detail_path = "%s/02_controle_detalhes_pedrinhas.png" % base_folder

	if not ResourceLoader.exists(base_path):
		base_folder = "res://assets/terrain_v2/masks/exemplo_trilha_curva"
		base_path = "%s/01_controle_base_terra_pedra.png" % base_folder
		detail_path = "%s/02_controle_detalhes_pedrinhas.png" % base_folder

	var base_tex: Texture2D = load(base_path) as Texture2D
	var detail_tex: Texture2D = load(detail_path) as Texture2D
	return {"base": base_tex, "detail": detail_tex}


static func create_material(base_mask: Texture2D, detail_mask: Texture2D, tiling: Vector2 = Vector2(12.0, 12.0), details_strength: float = 0.75, roughness: float = 0.96) -> ShaderMaterial:
	var shader := get_shader()
	if shader == null:
		return null

	var mat := ShaderMaterial.new()
	mat.shader = shader

	# 1. Texturas repetíveis de materiais
	for uniform_name in TEXTURES.keys():
		var tex := get_texture(uniform_name)
		if tex != null:
			mat.set_shader_parameter(uniform_name, tex)

	# 2. Máscaras de controle que cobrem toda a região (UV 0..1 sem repetição)
	if base_mask != null:
		mat.set_shader_parameter("base_control", base_mask)
	if detail_mask != null:
		mat.set_shader_parameter("detail_control", detail_mask)

	# 3. Parâmetros visuais
	mat.set_shader_parameter("texture_tiling", tiling)
	mat.set_shader_parameter("details_strength", details_strength)
	mat.set_shader_parameter("material_roughness", roughness)

	return mat


static func get_material_for_zone(zone_id: String, tiling: Vector2 = Vector2(12.0, 12.0)) -> ShaderMaterial:
	var key: String = "%s_%.1f_%.1f" % [zone_id, tiling.x, tiling.y]
	if _cached_materials.has(key):
		return _cached_materials[key] as ShaderMaterial

	var masks := get_zone_masks(zone_id)
	var mat := create_material(masks.get("base") as Texture2D, masks.get("detail") as Texture2D, tiling)
	if mat != null:
		_cached_materials[key] = mat
	return mat


## Cria uma malha suave e contínua cobrindo a arena (sem polígonos grosseiros visíveis)
static func create_terrain_mesh_instance(size: Vector2 = Vector2(52.0, 52.0), mat: Material = null) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	# Subdivisões leves para iluminação suave e vértices suficientes sem sobrecarga de GPU
	plane.subdivide_width = 8
	plane.subdivide_depth = 8

	var node := MeshInstance3D.new()
	node.name = "Terrain_Continuous_Grass_Dirt"
	node.mesh = plane
	node.position = Vector3(0.0, 0.001, 0.0) # Levemente acima do chão físico para evitar Z-fighting
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if mat != null:
		node.material_override = mat

	return node
