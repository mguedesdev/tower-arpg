extends Control
class_name ManaGlobeHUD

## ============================================================================
## CLUSTER MODULAR DE MANA — ARPG DARK FANTASY (GODOT 4)
## ============================================================================
## Canto inferior direito da tela:
## • Orbe de vidro com líquido safira celestial dinâmico (preenchimento vertical bottom-to-top).
## • Base visual oficial sem correntes (03_mana_base.png, 414x295).
## • Fundo escuro do orbe quando vazio (07_orbe_mana_fundo_escuro.png).
## • Preenchimento 100% de alta qualidade (05_preenchimento_mana_cheio.png).
## • Rótulo numérico dinâmico formatado sobre o orbe ("💧 500 / 500").
## • Responsivo, independente e nivelado na base da tela.
## • mouse_filter da moldura é IGNORE para não bloquear cliques de combate.

const BASE_SIZE := Vector2(414, 295)

const TEX_FRAME := preload("res://assets/ui/hud/03_mana_base.png")
const TEX_UNDER_ORB := preload("res://assets/ui/hud/07_orbe_mana_fundo_escuro.png")
const TEX_FILL_ORB := preload("res://assets/ui/hud/05_preenchimento_mana_cheio.png")

@export_range(0.3, 1.2, 0.02) var user_scale_multiplier: float = 1.0
@export var smooth_speed: float = 4.0

var ui_scale: float = 0.76
var current_mana: int = 60
var maximum_mana: int = 60

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
	name = "ManaGlobeHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()


func _ready() -> void:
	_relayout()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_relayout)


func _build_ui() -> void:
	_scaler = Control.new()
	_scaler.name = "Scaler"
	_scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.scale = Vector2(ui_scale, ui_scale)
	add_child(_scaler)

	# 1. Cavidade escura do orbe de mana
	_orb_under = TextureRect.new()
	_orb_under.name = "OrbUnder"
	_orb_under.texture = TEX_UNDER_ORB
	_orb_under.position = Vector2(50, 20)
	_orb_under.size = Vector2(256, 256)
	_orb_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_orb_under)

	# 2. Barra de progresso vertical do orbe (líquido safira de baixo para cima)
	_orb_bar = TextureProgressBar.new()
	_orb_bar.name = "OrbProgress"
	_orb_bar.position = Vector2(50, 20)
	_orb_bar.size = Vector2(256, 256)
	_orb_bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	_orb_bar.texture_progress = TEX_FILL_ORB
	_orb_bar.min_value = 0.0
	_orb_bar.max_value = 100.0
	_orb_bar.value = 100.0
	_orb_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_orb_bar)

	# 3 & 4. Nós de compatibilidade regressiva para suíte de testes legada
	_bar_under = TextureRect.new()
	_bar_under.name = "BarUnder"
	_bar_under.visible = false
	_scaler.add_child(_bar_under)

	_bar_bar = TextureProgressBar.new()
	_bar_bar.name = "BarProgress"
	_bar_bar.visible = false
	_bar_bar.min_value = 0.0
	_bar_bar.max_value = 100.0
	_bar_bar.value = 100.0
	_scaler.add_child(_bar_bar)

	# 5. Moldura de topo (ouro ornamentado e losangos)
	_frame_overlay = TextureRect.new()
	_frame_overlay.name = "FrameOverlay"
	_frame_overlay.texture = TEX_FRAME
	_frame_overlay.position = Vector2.ZERO
	_frame_overlay.size = BASE_SIZE
	_frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_frame_overlay)

	# 6. Rótulo numérico de mana centralizado sobre o orbe
	_value_label = Label.new()
	_value_label.name = "ManaValue"
	_value_label.position = Vector2(74, 134)
	_value_label.size = Vector2(208, 32)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", 20)
	_value_label.add_theme_color_override("font_color", Color(0.88, 0.94, 1.0))
	_value_label.add_theme_color_override("font_outline_color", Color(0.02, 0.04, 0.08, 0.98))
	_value_label.add_theme_constant_override("outline_size", 6)
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_value_label)


func update_mana(cur: int, max_m: int) -> void:
	current_mana = maxi(0, cur)
	maximum_mana = maxi(1, max_m)
	_target_ratio = clampf(float(current_mana) / float(maximum_mana), 0.0, 1.0)
	_update_label_text()


func set_values(cur: int, max_m: int) -> void:
	update_mana(cur, max_m)


func set_values_immediate(cur: int, max_m: int) -> void:
	update_mana(cur, max_m)
	_visual_ratio = _target_ratio
	var pct: float = _visual_ratio * 100.0
	if _orb_bar != null:
		_orb_bar.value = pct
	if _bar_bar != null:
		_bar_bar.value = pct


func _update_label_text() -> void:
	if _value_label != null:
		_value_label.text = "💧 %s / %s" % [_format_thousands(current_mana), _format_thousands(maximum_mana)]


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

	# Escala responsiva uniforme idêntica aos outros 2 clusters
	var s: float = (vp.y / 1080.0) * 0.76
	var max_w_scale: float = (vp.x - 120.0) / 1834.0
	ui_scale = clampf(minf(s, max_w_scale) * user_scale_multiplier, 0.42, 0.95)

	if _scaler != null:
		_scaler.scale = Vector2(ui_scale, ui_scale)

	custom_minimum_size = BASE_SIZE * ui_scale
	size = custom_minimum_size

	# Fixado de forma independente no canto inferior direito com margem de respiro
	var margin_x: float = 14.0
	var margin_y: float = 6.0
	position = Vector2(vp.x - size.x - margin_x, vp.y - size.y - margin_y)


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
