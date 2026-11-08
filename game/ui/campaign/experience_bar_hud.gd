extends Control
class_name ExperienceBarHUD

## ============================================================================
## BARRA DE EXPERIÊNCIA (XP) — ARPG DARK FANTASY (GODOT 4)
## ============================================================================
## Posicionada imediatamente acima da hotbar central de habilidades (SkillBarHUD):
## • Preenchimento horizontal dinâmico da esquerda para a direita (0 a 100%).
## • Moldura vazia com trilho escuro (xp_bar_empty.png, 2080x175).
## • Líquido mágico em degradê violeta -> azul -> ciano (xp_bar_fill_aligned.png, 2080x175).
## • Alinhamento milimétrico automático compartilhando escala e centro da hotbar.
## • Animação suave via Tween ao receber XP em combate.
## • Feedback discreto de Level-up (pulso violeta sutil e som opcional).
## • Tooltip dinâmico completo ao passar o mouse (Nível, XP Atual/Próximo, %, Faltam X).
## • mouse_filter PASS para capturar hover sem interceptar cliques de combate.

signal level_up_celebrated(new_level: int)

const BASE_WIDTH: float = 780.0
const NATIVE_ASPECT_RATIO: float = 2080.0 / 175.0 # ~11.8857
const BASE_HEIGHT: float = BASE_WIDTH / NATIVE_ASPECT_RATIO # ~65.6 px
const BASE_SIZE := Vector2(BASE_WIDTH, BASE_HEIGHT)

const TEX_EMPTY := preload("res://assets/ui/hud/xp_bar_empty.png")
const TEX_FILL := preload("res://assets/ui/hud/xp_bar_fill_aligned.png")
const ExperienceServiceScript = preload("res://core/progression/experience_service.gd")

const COLOR_GLOW := Color(0.78, 0.45, 1.0, 0.0)
const COLOR_TOOLTIP_BG := Color(0.06, 0.045, 0.08, 0.98)
const COLOR_GOLD := Color(0.92, 0.78, 0.42)
const COLOR_CYAN_XP := Color(0.45, 0.88, 1.0)

var ui_scale: float = 0.76

var _service: RefCounted = null
var _hotbar_ref: SkillBarHUD = null

var _scaler: Control
var _progress_bar: TextureProgressBar
var _glow_overlay: ColorRect
var _hover_detector: Control

var _current_display_ratio: float = 0.0
var _anim_tween: Tween = null
var _is_leveling_up: bool = false

# Dados cacheados para tooltip
var cached_level: int = 1
var cached_xp_in_level: int = 0
var cached_xp_required: int = 90
var cached_total_xp: int = 0


func _init() -> void:
	name = "ExperienceBarHUD"
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()


func _ready() -> void:
	_relayout()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_relayout)
	_update_tooltip_text()


func bind_service(service: RefCounted) -> void:
	if _service != null:
		if _service.progress_changed.is_connected(_on_progress_changed):
			_service.progress_changed.disconnect(_on_progress_changed)
		if _service.level_gained.is_connected(_on_level_gained):
			_service.level_gained.disconnect(_on_level_gained)

	_service = service

	if _service != null:
		_service.progress_changed.connect(_on_progress_changed)
		_service.level_gained.connect(_on_level_gained)
		cached_level = _service.current_level
		cached_xp_in_level = _service.current_xp_in_level
		cached_xp_required = _service.get_xp_required_for_next_level(_service.current_level)
		cached_total_xp = _service.total_xp
		_set_visual_ratio(_service.get_progress_ratio(), false)
	_update_tooltip_text()


func bind_hotbar(hotbar: SkillBarHUD) -> void:
	if _hotbar_ref != null and is_instance_valid(_hotbar_ref):
		if _hotbar_ref.has_signal("layout_updated") and _hotbar_ref.layout_updated.is_connected(_relayout):
			_hotbar_ref.layout_updated.disconnect(_relayout)

	_hotbar_ref = hotbar

	if _hotbar_ref != null and is_instance_valid(_hotbar_ref):
		if _hotbar_ref.has_signal("layout_updated"):
			_hotbar_ref.layout_updated.connect(_relayout)
		_hotbar_ref.visibility_changed.connect(func() -> void:
			if is_instance_valid(_hotbar_ref):
				visible = _hotbar_ref.visible
		)
		visible = _hotbar_ref.visible
	_relayout()


func _build_ui() -> void:
	_scaler = Control.new()
	_scaler.name = "Scaler"
	_scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.scale = Vector2(ui_scale, ui_scale)
	add_child(_scaler)

	# Barra de progresso com arte nativa
	_progress_bar = TextureProgressBar.new()
	_progress_bar.name = "ProgressBar"
	_progress_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bar.fill_mode = TextureProgressBar.FILL_LEFT_TO_RIGHT
	_progress_bar.min_value = 0.0
	_progress_bar.max_value = 100.0
	_progress_bar.step = 0.01
	_progress_bar.value = 0.0
	_progress_bar.texture_under = TEX_EMPTY
	_progress_bar.texture_progress = TEX_FILL
	_progress_bar.nine_patch_stretch = false
	# Dimensões da textura nativa: 2080x175; escalamos para BASE_SIZE
	var native_scale: float = BASE_WIDTH / 2080.0
	_progress_bar.scale = Vector2(native_scale, native_scale)
	_scaler.add_child(_progress_bar)

	# Camada de brilho/glow para efeito sutil de level-up
	_glow_overlay = ColorRect.new()
	_glow_overlay.name = "GlowOverlay"
	_glow_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow_overlay.position = Vector2(0, 0)
	_glow_overlay.size = BASE_SIZE
	_glow_overlay.color = COLOR_GLOW
	_scaler.add_child(_glow_overlay)

	# Área interativa de tooltip sobre toda a barra
	_hover_detector = Control.new()
	_hover_detector.name = "HoverDetector"
	_hover_detector.mouse_filter = Control.MOUSE_FILTER_PASS
	_hover_detector.size = BASE_SIZE
	_scaler.add_child(_hover_detector)


## ----------------------------------------------------------------------------
## ATUALIZAÇÃO VISUAL E TWEEN SUAVE
## ----------------------------------------------------------------------------
func _on_progress_changed(level: int, xp_in_lvl: int, xp_req: int, p_total_xp: int) -> void:
	cached_level = level
	cached_xp_in_level = xp_in_lvl
	cached_xp_required = xp_req
	cached_total_xp = p_total_xp
	_update_tooltip_text()

	var target_ratio: float = 0.0
	if xp_req > 0:
		target_ratio = clampf(float(xp_in_lvl) / float(xp_req), 0.0, 1.0)

	if not _is_leveling_up:
		_animate_to_ratio(target_ratio)


func _on_level_gained(new_level: int, _old_level: int) -> void:
	_is_leveling_up = true
	cached_level = new_level
	_update_tooltip_text()

	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()

	# 1. Completa a barra até 100%
	_anim_tween = create_tween()
	_anim_tween.tween_property(_progress_bar, "value", 100.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_anim_tween.parallel().tween_property(_glow_overlay, "color", Color(0.85, 0.55, 1.0, 0.60), 0.18)

	# 2. Pulso de comemoração
	_anim_tween.tween_callback(func() -> void:
		_progress_bar.value = 0.0
		_current_display_ratio = 0.0
		level_up_celebrated.emit(new_level)
	)

	# 3. Fade out do brilho e transição para o novo progresso com overflow
	_anim_tween.tween_property(_glow_overlay, "color", COLOR_GLOW, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_anim_tween.tween_callback(func() -> void:
		_is_leveling_up = false
		var final_ratio: float = 0.0
		if cached_xp_required > 0:
			final_ratio = clampf(float(cached_xp_in_level) / float(cached_xp_required), 0.0, 1.0)
		_animate_to_ratio(final_ratio)
	)


func _animate_to_ratio(target_ratio: float) -> void:
	if _anim_tween != null and _anim_tween.is_valid():
		_anim_tween.kill()

	var target_pct: float = target_ratio * 100.0
	_anim_tween = create_tween()
	_anim_tween.tween_property(_progress_bar, "value", target_pct, 0.38).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_current_display_ratio = target_ratio


func _set_visual_ratio(ratio: float, animate: bool = true) -> void:
	_current_display_ratio = clampf(ratio, 0.0, 1.0)
	if animate:
		_animate_to_ratio(_current_display_ratio)
	else:
		if _progress_bar != null:
			_progress_bar.value = _current_display_ratio * 100.0


## ----------------------------------------------------------------------------
## TOOLTIP RICO DE EXPERIÊNCIA
## ----------------------------------------------------------------------------
func _update_tooltip_text() -> void:
	var pct: int = 0
	if cached_xp_required > 0:
		pct = roundi(clampf(float(cached_xp_in_level) / float(cached_xp_required), 0.0, 1.0) * 100.0)
	var remaining: int = maxi(0, cached_xp_required - cached_xp_in_level)

	var tt: String = "Nível %d\nExperiência: %s / %s\nProgresso: %d%%\nFaltam: %s XP" % [
		cached_level,
		_format_int(cached_xp_in_level),
		_format_int(cached_xp_required),
		pct,
		_format_int(remaining)
	]
	tooltip_text = tt
	if _hover_detector != null:
		_hover_detector.tooltip_text = tt


func _make_custom_tooltip(for_text: String) -> Object:
	var panel := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = COLOR_TOOLTIP_BG
	st.border_color = COLOR_GOLD
	st.set_border_width_all(1)
	st.set_corner_radius_all(5)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", st)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	panel.add_child(vbox)

	var lines: PackedStringArray = for_text.split("\n")
	for idx in range(lines.size()):
		var line: String = lines[idx]
		var lbl := Label.new()
		lbl.text = line
		lbl.add_theme_font_size_override("font_size", 12)
		if idx == 0:
			lbl.add_theme_color_override("font_color", COLOR_GOLD)
			lbl.add_theme_font_size_override("font_size", 13)
		elif idx == 1 or idx == 2:
			lbl.add_theme_color_override("font_color", COLOR_CYAN_XP)
		else:
			lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		vbox.add_child(lbl)

	return panel


static func _format_int(val: int) -> String:
	var s: String = str(val)
	var res: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			res = "." + res
		res = s[i] + res
		count += 1
	return res


## ----------------------------------------------------------------------------
## SINCRONIZAÇÃO E RESPONSIVIDADE COM A HOTBAR
## ----------------------------------------------------------------------------
func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10.0:
		return

	if _hotbar_ref != null and is_instance_valid(_hotbar_ref):
		# Herda a mesma escala e cálculo da hotbar
		ui_scale = _hotbar_ref.ui_scale
		visible = _hotbar_ref.visible
	else:
		var s: float = (vp.y / 1080.0) * 0.76
		var max_w_scale: float = (vp.x - 120.0) / 1834.0
		ui_scale = clampf(minf(s, max_w_scale), 0.42, 0.95)

	if _scaler != null:
		_scaler.scale = Vector2(ui_scale, ui_scale)

	var bar_w: float = BASE_WIDTH * ui_scale
	var bar_h: float = BASE_HEIGHT * ui_scale
	custom_minimum_size = Vector2(bar_w, bar_h)
	size = custom_minimum_size

	if _hotbar_ref != null and is_instance_valid(_hotbar_ref):
		# Alinhada milimetricamente no topo da hotbar central (8px de folga escalada)
		var target_x: float = _hotbar_ref.position.x + (_hotbar_ref.size.x - bar_w) * 0.5
		# As setas da hotbar começam em y=85 (top em 73 base). Colocamos a barra de XP logo acima
		var hotbar_visual_top: float = _hotbar_ref.position.y + (50.0 * ui_scale)
		var target_y: float = hotbar_visual_top - bar_h - (6.0 * ui_scale)
		position = Vector2(target_x, target_y)
	else:
		# Fallback se a hotbar ainda não estiver associada
		position = Vector2((vp.x - bar_w) * 0.5, vp.y - bar_h - 220.0 * ui_scale)
