extends Node3D
class_name EnemyHealthBar3D
## Componente reutilizável de Barra de Vida 3D (Overhead Health Bar).
## Qualquer inimigo que herde de TowerEnemy (Esqueleto, Lobo, futuros Bosses/Mobs)
## instancia automaticamente este objeto, herdando visual, rastreamento de dano e câmera.

const INNER_WIDTH: float = 0.88
const INNER_HEIGHT: float = 0.095
const OUTER_WIDTH: float = 0.96
const OUTER_HEIGHT: float = 0.145
const RIM_WIDTH: float = 1.02
const RIM_HEIGHT: float = 0.185

static var _shared_ready: bool = false
static var _rim_mesh: QuadMesh
static var _bg_mesh: QuadMesh
static var _fill_mesh: QuadMesh
static var _rim_mat: StandardMaterial3D
static var _bg_mat: StandardMaterial3D
static var _trail_mat: StandardMaterial3D
static var _fill_mat: StandardMaterial3D
static var _burn_fill_mat: StandardMaterial3D

var _fill_node: MeshInstance3D
var _trail_node: MeshInstance3D
var _target_ratio: float = 1.0
var _trail_ratio: float = 1.0
var _is_burning: bool = false


static func _ensure_shared_resources() -> void:
	if _shared_ready:
		return
	_shared_ready = true

	_rim_mesh = QuadMesh.new()
	_rim_mesh.size = Vector2(RIM_WIDTH, RIM_HEIGHT)

	_bg_mesh = QuadMesh.new()
	_bg_mesh.size = Vector2(OUTER_WIDTH, OUTER_HEIGHT)

	_fill_mesh = QuadMesh.new()
	_fill_mesh.size = Vector2(INNER_WIDTH, INNER_HEIGHT)

	_rim_mat = _make_bar_material(Color(0.92, 0.88, 0.76, 0.82), 10)
	_bg_mat = _make_bar_material(Color(0.05, 0.05, 0.07, 0.96), 11)
	_trail_mat = _make_bar_material(Color(1.0, 0.90, 0.45, 0.96), 12)
	_fill_mat = _make_bar_material(Color(0.96, 0.18, 0.22, 1.0), 13)
	_burn_fill_mat = _make_bar_material(Color(1.0, 0.50, 0.10, 1.0), 13)


static func _make_bar_material(color: Color, priority: int) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.render_priority = priority
	return mat


func _ready() -> void:
	_ensure_shared_resources()
	top_level = false

	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	rim.mesh = _rim_mesh
	rim.material_override = _rim_mat
	rim.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rim)

	var bg := MeshInstance3D.new()
	bg.name = "Background"
	bg.mesh = _bg_mesh
	bg.material_override = _bg_mat
	bg.position.z = 0.002
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(bg)

	_trail_node = MeshInstance3D.new()
	_trail_node.name = "DamageTrail"
	_trail_node.mesh = _fill_mesh
	_trail_node.material_override = _trail_mat
	_trail_node.position.z = 0.004
	_trail_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail_node)

	_fill_node = MeshInstance3D.new()
	_fill_node.name = "HealthFill"
	_fill_node.mesh = _fill_mesh
	_fill_node.material_override = _fill_mat
	_fill_node.position.z = 0.006
	_fill_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fill_node)

	_apply_bar_ratios()
	set_process(false)


func configure(bar_height: float, width_scale: float = 1.0) -> void:
	position = Vector3(0.0, bar_height, 0.0)
	scale = Vector3(width_scale, 1.0, 1.0)


func update_health(current_hp: int, max_hp: int, burning: bool = false) -> void:
	var safe_max: float = maxf(float(max_hp), 1.0)
	_target_ratio = clampf(float(current_hp) / safe_max, 0.0, 1.0)
	if _is_burning != burning:
		_is_burning = burning
		if _fill_node != null:
			_fill_node.material_override = _burn_fill_mat if _is_burning else _fill_mat
	_apply_bar_ratios()
	if _trail_ratio > _target_ratio + 0.002:
		set_process(true)


func align_to_camera(viewport: Viewport) -> void:
	if viewport == null:
		return
	var cam: Camera3D = viewport.get_camera_3d()
	if cam != null:
		var current_scale: Vector3 = scale
		global_basis = cam.global_basis.scaled(current_scale)


func _process(delta: float) -> void:
	if _trail_ratio > _target_ratio + 0.001:
		_trail_ratio = move_toward(_trail_ratio, _target_ratio, delta * 1.45)
		_apply_bar_ratios()
	else:
		_trail_ratio = _target_ratio
		_apply_bar_ratios()
		set_process(false)


func _apply_bar_ratios() -> void:
	if _fill_node != null:
		var r: float = maxf(_target_ratio, 0.0001)
		_fill_node.visible = _target_ratio > 0.001
		_fill_node.scale.x = r
		_fill_node.position.x = -INNER_WIDTH * 0.5 * (1.0 - r)
	if _trail_node != null:
		var tr: float = maxf(_trail_ratio, _target_ratio)
		_trail_node.visible = tr > 0.001
		_trail_node.scale.x = maxf(tr, 0.0001)
		_trail_node.position.x = -INNER_WIDTH * 0.5 * (1.0 - tr)
