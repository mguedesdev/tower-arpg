extends Control
class_name HealthGlobeHUD

## ============================================================================
## COMPONENTE VISUAL INDEPENDENTE DE VIDA — ARPG DARK FANTASY (GODOT 4)
## ============================================================================
## Canto inferior esquerdo da tela:
## • Orbe de vidro com líquido rubi dinâmico (preenchimento vertical bottom-to-top).
## • Barra horizontal conectada com líquido rubi (preenchimento horizontal left-to-right).
## • Moldura gótica ornamentada com bordas douradas, losangos e estandarte sobre o vidro.
## • Rótulo numérico dinâmico no visor superior ("❤️ 1.280 / 1.280").
## • Transições suaves sem atrasar os valores reais de combate.

const BASE_SIZE := Vector2(627, 360)

const TEX_FRAME := preload("res://assets/ui/hud/health_frame.png")
const TEX_FILL_ORB := preload("res://assets/ui/hud/health_fill_orb.png")
const TEX_UNDER_ORB := preload("res://assets/ui/hud/health_under_orb.png")
const TEX_FILL_BAR := preload("res://assets/ui/hud/health_fill_bar.png")
const TEX_UNDER_BAR := preload("res://assets/ui/hud/health_under_bar.png")

@export_range(0.2, 1.0, 0.02) var ui_scale: float = 0.46
@export var smooth_speed: float = 4.0

var current_health: int = 100
var maximum_health: int = 100

var _target_ratio: float = 1.0
var _visual_ratio: float = 1.0

var _scaler: Control
var _orb_under: TextureRect
var _orb_bar: TextureProgressBar
var _bar_under: TextureRect
var _bar_bar: TextureProgressBar
var _frame_overlay: TextureRect
var _value_label: Label


func _init() -> void:
	name = "HealthGlobeHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _ready() -> void:
	_relayout()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_relayout)


func _build_ui() -> void:
	# O scaler agrupa as texturas em alta resolução (627x360) e reduz com interpolação suave
	_scaler = Control.new()
	_scaler.name = "Scaler"
	_scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.scale = Vector2(ui_scale, ui_scale)
	add_child(_scaler)

	# 1. Cavidade escura do orbe (fundo sob o líquido quando a vida está baixa)
	_orb_under = TextureRect.new()
	_orb_under.name = "OrbUnder"
	_orb_under.texture = TEX_UNDER_ORB
	_orb_under.position = Vector2(71, 73)
	_orb_under.size = Vector2(200, 200)
	_orb_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_orb_under)

	# 2. Barra de progresso vertical do orbe (líquido rubi de baixo para cima)
	_orb_bar = TextureProgressBar.new()
	_orb_bar.name = "OrbProgress"
	_orb_bar.position = Vector2(71, 73)
	_orb_bar.size = Vector2(200, 200)
	_orb_bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	_orb_bar.texture_progress = TEX_FILL_ORB
	_orb_bar.min_value = 0.0
	_orb_bar.max_value = 100.0
	_orb_bar.value = 100.0
	_orb_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_orb_bar)

	# 3. Cavidade escura da barra horizontal
	_bar_under = TextureRect.new()
	_bar_under.name = "BarUnder"
	_bar_under.texture = TEX_UNDER_BAR
	_bar_under.position = Vector2(280, 180)
	_bar_under.size = Vector2(304, 46)
	_bar_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_bar_under)

	# 4. Barra de progresso horizontal (líquido rubi da esquerda para a direita)
	_bar_bar = TextureProgressBar.new()
	_bar_bar.name = "BarProgress"
	_bar_bar.position = Vector2(280, 180)
	_bar_bar.size = Vector2(304, 46)
	_bar_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_bar_bar.texture_progress = TEX_FILL_BAR
	_bar_bar.min_value = 0.0
	_bar_bar.max_value = 100.0
	_bar_bar.value = 100.0
	_bar_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_bar_bar)

	# 5. Moldura de topo (ouro ornamentado, losangos, estandarte e reflexos do vidro)
	_frame_overlay = TextureRect.new()
	_frame_overlay.name = "FrameOverlay"
	_frame_overlay.texture = TEX_FRAME
	_frame_overlay.position = Vector2.ZERO
	_frame_overlay.size = BASE_SIZE
	_frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_frame_overlay)

	# 6. Rótulo numérico de vida
	_value_label = Label.new()
	_value_label.name = "HealthValue"
	_value_label.position = Vector2(276, 116)
	_value_label.size = Vector2(308, 48)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", 25)
	_value_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.88))
	_value_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02, 0.98))
	_value_label.add_theme_constant_override("outline_size", 6)
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_value_label)


func update_health(cur: int, max_hp: int) -> void:
	current_health = maxi(0, cur)
	maximum_health = maxi(1, max_hp)
	_target_ratio = clampf(float(current_health) / float(maximum_health), 0.0, 1.0)
	_update_label_text()


func set_values(cur: int, max_hp: int) -> void:
	update_health(cur, max_hp)


func set_values_immediate(cur: int, max_hp: int) -> void:
	update_health(cur, max_hp)
	_visual_ratio = _target_ratio
	var pct: float = _visual_ratio * 100.0
	if _orb_bar != null:
		_orb_bar.value = pct
	if _bar_bar != null:
		_bar_bar.value = pct


func _update_label_text() -> void:
	if _value_label != null:
		_value_label.text = "❤️ %s / %s" % [_format_thousands(current_health), _format_thousands(maximum_health)]


func _process(delta: float) -> void:
	if not visible:
		return
	if not is_equal_approx(_visual_ratio, _target_ratio):
		_visual_ratio = move_toward(_visual_ratio, _target_ratio, delta * smooth_speed)
		var pct: float = _visual_ratio * 100.0
		if _orb_bar != null:
			_orb_bar.value = pct
		if _bar_bar != null:
			_bar_bar.value = pct


func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10.0:
		return

	# Escala responsiva suave para manter tamanho compacto em 1280x720 e telas menores
	var responsive_scale: float = clampf(vp.x / 1920.0 * 0.52, 0.38, 0.50)
	ui_scale = responsive_scale
	if _scaler != null:
		_scaler.scale = Vector2(ui_scale, ui_scale)

	custom_minimum_size = BASE_SIZE * ui_scale
	size = custom_minimum_size

	# Fixado de forma independente no canto inferior esquerdo com margem de respiro
	var margin_x: float = 14.0
	var margin_y: float = 12.0
	position = Vector2(margin_x, vp.y - size.y - margin_y)


static func _format_thousands(num: int) -> String:
	var s: String = str(num)
	if s.length() <= 3:
		return s
	var res: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "." + res
	return res
