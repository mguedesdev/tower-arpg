extends Node3D
class_name PlayerOverheadHUD3D
## ============================================================================
## BARRA DE VIDA OVERHEAD DO PLAYER (ARPG DARK FANTASY GODOT 4)
## Estilo autoral refinado: moldura de ferro forjado chanfrada com filete em bronze/ouro,
## cristal de vida rubi luminoso em degradê com reflexo vítreo, notches de 25%,
## rastro suave de dano (ghost trail), texto numérico nítido (HP / MaxHP),
## nome do herói em ouro antigo e pulso de alerta para vida crítica (< 25%).
## Totalmente sincronizada com o status real do personagem e orbe da HUD.
## ============================================================================

const SHADER_PATH: String = "res://assets/ui/hud/player_health_bar_3d.gdshader"
const BAR_WIDTH: float = 0.88
const BAR_HEIGHT: float = 0.11

var _bar_mesh_node: MeshInstance3D
var _name_label: Label3D
var _hp_label: Label3D

var _shader_mat: ShaderMaterial
var _target_ratio: float = 1.0
var _trail_ratio: float = 1.0
var _current_health: int = 100
var _maximum_health: int = 100
var _pulse_timer: float = 0.0

# Aliases de compatibilidade para sistemas e testes existentes
var _fill_node: MeshInstance3D:
	get:
		return _bar_mesh_node
var _trail_node: MeshInstance3D:
	get:
		return _bar_mesh_node


func _init() -> void:
	_build_components()
	update_health(_current_health, _maximum_health)


func _ready() -> void:
	update_health(_current_health, _maximum_health)


func _build_components() -> void:
	# 1. ShaderMaterial PBR / Unshaded Dark Fantasy
	var shader: Shader = load(SHADER_PATH) as Shader
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	_shader_mat.render_priority = 20

	# 2. Malha da Barra de Vida Estilizada (QuadMesh único de alta fidelidade)
	var qm := QuadMesh.new()
	qm.size = Vector2(BAR_WIDTH, BAR_HEIGHT)

	_bar_mesh_node = MeshInstance3D.new()
	_bar_mesh_node.name = "HealthBarMesh"
	_bar_mesh_node.mesh = qm
	_bar_mesh_node.material_override = _shader_mat
	_bar_mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bar_mesh_node)

	# 3. Nome do Herói / Classe (Ouro Antigo com Sombra Profunda)
	_name_label = Label3D.new()
	_name_label.name = "HeroName"
	_name_label.text = "Cavaleiro"
	_name_label.font_size = 17
	_name_label.outline_size = 5
	_name_label.modulate = Color(0.95, 0.88, 0.65, 1.0)
	_name_label.outline_modulate = Color(0.02, 0.02, 0.03, 1.0)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.pixel_size = 0.0055
	_name_label.position = Vector3(0.0, 0.15, 0.0)
	_name_label.render_priority = 25
	_name_label.outline_render_priority = 24
	add_child(_name_label)

	# 4. Texto Numérico de Vida (ex: 140 / 140)
	_hp_label = Label3D.new()
	_hp_label.name = "HealthNumbers"
	_hp_label.text = "100 / 100"
	_hp_label.font_size = 11
	_hp_label.outline_size = 3
	_hp_label.modulate = Color(1.0, 0.98, 0.94, 0.96)
	_hp_label.outline_modulate = Color(0.0, 0.0, 0.0, 0.95)
	_hp_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_label.no_depth_test = true
	_hp_label.pixel_size = 0.0050
	_hp_label.position = Vector3(0.0, 0.0, 0.006)
	_hp_label.render_priority = 26
	_hp_label.outline_render_priority = 25
	add_child(_hp_label)


## Atualiza os valores absolutos de vida e sincroniza a proporção visual instantaneamente
func update_health(current: int, maximum: int) -> void:
	_maximum_health = maxi(1, maximum)
	_current_health = clampi(current, 0, _maximum_health)

	var prev_target: float = _target_ratio
	_target_ratio = clampf(float(_current_health) / float(_maximum_health), 0.0, 1.0)

	# Se recebeu cura ou inicializou, rastro acompanha de imediato
	if _target_ratio >= prev_target:
		_trail_ratio = _target_ratio

	_apply_shader_params()

	if _hp_label != null:
		_hp_label.text = "%d / %d" % [_current_health, _maximum_health]


func set_hero_name(p_name: String) -> void:
	if _name_label != null:
		_name_label.text = p_name


func _apply_shader_params() -> void:
	if _shader_mat == null:
		return
	_shader_mat.set_shader_parameter("health_ratio", _target_ratio)
	_shader_mat.set_shader_parameter("trail_ratio", _trail_ratio)


func _process(delta: float) -> void:
	var needs_shader_update: bool = false

	# Rastro de dano esvazia suavemente após o golpe
	if _trail_ratio > _target_ratio:
		_trail_ratio = move_toward(_trail_ratio, _target_ratio, delta * 1.35)
		needs_shader_update = true
	else:
		_trail_ratio = _target_ratio

	# Pulso de aviso quando a vida estiver em estado crítico (< 25%)
	if _target_ratio < 0.25 and _target_ratio > 0.0:
		_pulse_timer += delta * 7.5
		var p: float = 0.5 + 0.5 * sin(_pulse_timer)
		if _shader_mat != null:
			_shader_mat.set_shader_parameter("pulse_intensity", p)
	else:
		_pulse_timer = 0.0
		if _shader_mat != null:
			_shader_mat.set_shader_parameter("pulse_intensity", 0.0)

	if needs_shader_update:
		_apply_shader_params()
