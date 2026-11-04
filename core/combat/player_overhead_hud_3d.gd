extends Node3D
class_name PlayerOverheadHUD3D
## Placa de Identificação e Barra de Vida Overhead (sobre a cabeça do Player).
## Inspirado fielmente no Albion Online: Nome em ouro + Tag da classe + Barra de vida compacta.

const BAR_WIDTH: float = 0.92
const BAR_HEIGHT: float = 0.085
const RIM_WIDTH: float = 0.98
const RIM_HEIGHT: float = 0.13

var _label_tag: Label3D
var _label_name: Label3D
var _fill_node: MeshInstance3D
var _trail_node: MeshInstance3D
var _target_ratio: float = 1.0
var _trail_ratio: float = 1.0

static var _rim_mat: StandardMaterial3D
static var _bg_mat: StandardMaterial3D
static var _fill_mat: StandardMaterial3D
static var _trail_mat: StandardMaterial3D
static var _shared_ready: bool = false


func _ready() -> void:
	_ensure_materials()
	_build_visuals()


static func _ensure_materials() -> void:
	if _shared_ready:
		return
	_shared_ready = true

	_rim_mat = _make_mat(Color(0.18, 0.16, 0.14, 0.95), 20)
	_bg_mat = _make_mat(Color(0.04, 0.04, 0.05, 0.98), 21)
	_trail_mat = _make_mat(Color(0.95, 0.75, 0.30, 0.95), 22)
	_fill_mat = _make_mat(Color(0.20, 0.82, 0.35, 1.0), 23) # Verde clássico de vida do herói estilo Albion


static func _make_mat(col: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = true
	m.render_priority = priority
	return m


func _build_visuals() -> void:
	# 1. Tag de Título / Guild / Classe (Ex: "[GUERREIRO]")
	_label_tag = Label3D.new()
	_label_tag.text = "[GUERREIRO EXILADO]"
	_label_tag.font_size = 20
	_label_tag.outline_size = 6
	_label_tag.modulate = Color(0.95, 0.78, 0.32, 0.90)
	_label_tag.outline_modulate = Color(0.01, 0.01, 0.02, 1.0)
	_label_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_tag.no_depth_test = true
	_label_tag.pixel_size = 0.0055
	_label_tag.position = Vector3(0.0, 0.32, 0.0)
	_label_tag.render_priority = 25
	_label_tag.outline_render_priority = 24
	add_child(_label_tag)

	# 2. Nome do Personagem (em ouro bold estilo Albion: "Cavaleiro")
	_label_name = Label3D.new()
	_label_name.text = "⚔ Cavaleiro ⚔"
	_label_name.font_size = 26
	_label_name.outline_size = 8
	_label_name.modulate = Color(1.0, 0.92, 0.58, 1.0)
	_label_name.outline_modulate = Color(0.01, 0.01, 0.02, 1.0)
	_label_name.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_name.no_depth_test = true
	_label_name.pixel_size = 0.0068
	_label_name.position = Vector3(0.0, 0.16, 0.0)
	_label_name.render_priority = 25
	_label_name.outline_render_priority = 24
	add_child(_label_name)

	# 3. Moldura da Barra de Vida
	var rim_mesh := QuadMesh.new()
	rim_mesh.size = Vector2(RIM_WIDTH, RIM_HEIGHT)
	var rim_node := MeshInstance3D.new()
	rim_node.mesh = rim_mesh
	rim_node.material_override = _rim_mat
	rim_node.position = Vector3(0.0, 0.0, -0.002)
	add_child(rim_node)

	# 4. Fundo escuro da Barra de Vida
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	var bg_node := MeshInstance3D.new()
	bg_node.mesh = bg_mesh
	bg_node.material_override = _bg_mat
	bg_node.position = Vector3(0.0, 0.0, -0.001)
	add_child(bg_node)

	# 5. Rastro de Dano Dourado/Laranja
	var trail_mesh := QuadMesh.new()
	trail_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_trail_node = MeshInstance3D.new()
	_trail_node.mesh = trail_mesh
	_trail_node.material_override = _trail_mat
	add_child(_trail_node)

	# 6. Preenchimento de Vida Verde
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	_fill_node = MeshInstance3D.new()
	_fill_node.mesh = fill_mesh
	_fill_node.material_override = _fill_mat
	_fill_node.position = Vector3(0.0, 0.0, 0.001)
	add_child(_fill_node)


func update_health(current: int, maximum: int) -> void:
	var max_val: float = maxf(float(maximum), 1.0)
	_target_ratio = clampf(float(current) / max_val, 0.0, 1.0)
	_update_fill_transform(_target_ratio)


func _update_fill_transform(ratio: float) -> void:
	if _fill_node == null:
		return
	var w: float = BAR_WIDTH * ratio
	_fill_node.scale = Vector3(maxf(ratio, 0.0001), 1.0, 1.0)
	_fill_node.position.x = -BAR_WIDTH * 0.5 + w * 0.5


func _process(delta: float) -> void:
	if _trail_ratio > _target_ratio:
		_trail_ratio = maxf(_target_ratio, _trail_ratio - delta * 0.85)
		if _trail_node != null:
			var w: float = BAR_WIDTH * _trail_ratio
			_trail_node.scale = Vector3(maxf(_trail_ratio, 0.0001), 1.0, 1.0)
			_trail_node.position.x = -BAR_WIDTH * 0.5 + w * 0.5
	else:
		_trail_ratio = _target_ratio

	# Alinha com a câmera para manter legibilidade isométrica
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		global_basis = cam.global_basis
