extends CanvasLayer
class_name LoadingScreen
## Tela visual de carregamento universal (Dark Fantasy ARPG).
## Opera em camada superior (layer 120) com interceptação de inputs,
## barra fina com porcentagem real mensurável, suporte a ícone regional
## e transição suave de fade in / fade out via Tweens.

signal fade_in_completed()
signal fade_out_completed()

const COLOR_BG := Color(0.04, 0.042, 0.05, 1.0)
const COLOR_GOLD_BRIGHT := Color(1.0, 0.88, 0.45, 1.0)
const COLOR_GOLD_TITLE := Color(0.96, 0.88, 0.68, 1.0)
const COLOR_BRONZE_BORDER := Color(0.65, 0.50, 0.22, 0.90)
const COLOR_BAR_BG := Color(0.07, 0.075, 0.09, 1.0)
const COLOR_BAR_FILL := Color(0.95, 0.74, 0.25, 1.0)
const COLOR_TEXT_MUTED := Color(0.72, 0.68, 0.60, 1.0)

var _root_control: Control
var _icon_rect: TextureRect
var _badge_label: Label
var _title_label: Label
var _subtitle_label: Label
var _progress_bar_bg: Panel
var _progress_bar_fill: Panel
var _status_label: Label
var _percent_label: Label

var _target_progress: float = 0.0
var _current_progress: float = 0.0
var _is_fading: bool = false
var _bar_width: float = 520.0
var _bar_height: float = 8.0


func _init() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()


func _build_ui() -> void:
	_root_control = Control.new()
	_root_control.name = "RootControl"
	_root_control.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_control.modulate.a = 0.0
	_root_control.visible = false
	add_child(_root_control)

	# Fundo Sólido Dark Fantasy
	var bg := ColorRect.new()
	bg.name = "Backdrop"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = COLOR_BG
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_root_control.add_child(bg)

	# Borda / Vinheta decorativa
	var frame := Panel.new()
	frame.name = "DecorativeFrame"
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var frame_style := StyleBoxFlat.new()
	frame_style.draw_center = false
	frame_style.border_width_left = 2
	frame_style.border_width_top = 2
	frame_style.border_width_right = 2
	frame_style.border_width_bottom = 2
	frame_style.border_color = Color(0.35, 0.26, 0.14, 0.40)
	frame.add_theme_stylebox_override("panel", frame_style)
	_root_control.add_child(frame)

	# Centro Vertical / Horizontal
	var center := CenterContainer.new()
	center.name = "CenterLayout"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root_control.add_child(center)

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "ContentVBox"
	main_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	main_vbox.add_theme_constant_override("separation", 14)
	main_vbox.custom_minimum_size = Vector2(_bar_width, 0.0)
	center.add_child(main_vbox)

	# Ícone Regional Ilustrado (Arte do Mapa)
	_icon_rect = TextureRect.new()
	_icon_rect.name = "ZoneIcon"
	_icon_rect.custom_minimum_size = Vector2(104, 104)
	_icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon_rect.visible = false
	main_vbox.add_child(_icon_rect)

	# Badge de Região
	_badge_label = Label.new()
	_badge_label.name = "BadgeLabel"
	_badge_label.text = "✦ REINO DE VELEN • ATO I ✦"
	_badge_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_label.add_theme_font_size_override("font_size", 12)
	_badge_label.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	main_vbox.add_child(_badge_label)

	# Título Principal da Zona de Destino
	_title_label = Label.new()
	_title_label.name = "ZoneTitle"
	_title_label.text = "CARREGANDO..."
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 26)
	_title_label.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	main_vbox.add_child(_title_label)

	# Subtítulo / Descrição da Região
	_subtitle_label = Label.new()
	_subtitle_label.name = "ZoneSubtitle"
	_subtitle_label.text = "Preparando o mundo de jogo..."
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.custom_minimum_size = Vector2(_bar_width, 0.0)
	_subtitle_label.add_theme_font_size_override("font_size", 13)
	_subtitle_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	main_vbox.add_child(_subtitle_label)

	# Espaçador
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0.0, 18.0)
	main_vbox.add_child(spacer)

	# Container da Barra Fina de Carregamento
	var bar_container := VBoxContainer.new()
	bar_container.name = "BarContainer"
	bar_container.custom_minimum_size = Vector2(_bar_width, 0.0)
	bar_container.add_theme_constant_override("separation", 6)
	main_vbox.add_child(bar_container)

	# Fundo da Barra
	_progress_bar_bg = Panel.new()
	_progress_bar_bg.name = "ProgressBarBg"
	_progress_bar_bg.custom_minimum_size = Vector2(_bar_width, _bar_height)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = COLOR_BAR_BG
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = COLOR_BRONZE_BORDER
	bg_style.corner_radius_top_left = 4
	bg_style.corner_radius_top_right = 4
	bg_style.corner_radius_bottom_left = 4
	bg_style.corner_radius_bottom_right = 4
	_progress_bar_bg.add_theme_stylebox_override("panel", bg_style)
	bar_container.add_child(_progress_bar_bg)

	# Preenchimento da Barra
	_progress_bar_fill = Panel.new()
	_progress_bar_fill.name = "ProgressBarFill"
	_progress_bar_fill.custom_minimum_size = Vector2(0.0, _bar_height)
	_progress_bar_fill.size = Vector2(0.0, _bar_height)
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = COLOR_BAR_FILL
	fill_style.corner_radius_top_left = 3
	fill_style.corner_radius_top_right = 3
	fill_style.corner_radius_bottom_left = 3
	fill_style.corner_radius_bottom_right = 3
	_progress_bar_fill.add_theme_stylebox_override("panel", fill_style)
	_progress_bar_bg.add_child(_progress_bar_fill)

	# Linha de Status e Porcentagem Real
	var info_row := HBoxContainer.new()
	info_row.name = "InfoRow"
	info_row.custom_minimum_size = Vector2(_bar_width, 0.0)
	bar_container.add_child(info_row)

	_status_label = Label.new()
	_status_label.name = "StatusLabel"
	_status_label.text = "Iniciando..."
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", COLOR_TEXT_MUTED)
	info_row.add_child(_status_label)

	_percent_label = Label.new()
	_percent_label.name = "PercentLabel"
	_percent_label.text = "0%"
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_percent_label.add_theme_font_size_override("font_size", 12)
	_percent_label.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	info_row.add_child(_percent_label)


func _process(delta: float) -> void:
	if not _root_control.visible:
		return

	# Interpolação suave do preenchimento da barra para evitar saltos secos
	if not is_equal_approx(_current_progress, _target_progress):
		_current_progress = move_toward(_current_progress, _target_progress, delta * 2.5)
		var fill_w: float = clampf(_current_progress, 0.0, 1.0) * _bar_width
		_progress_bar_fill.size = Vector2(fill_w, _bar_height)
		_percent_label.text = "%d%%" % int(_current_progress * 100.0)


## Configura as informações visuais da região de destino antes de exibir
func setup_destination(title: String, subtitle: String = "", icon_path: String = "") -> void:
	_title_label.text = title.to_upper()
	_subtitle_label.text = subtitle
	_target_progress = 0.0
	_current_progress = 0.0
	_progress_bar_fill.size = Vector2(0.0, _bar_height)
	_percent_label.text = "0%"

	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		var tex: Texture2D = load(icon_path) as Texture2D
		if tex != null:
			_icon_rect.texture = tex
			_icon_rect.visible = true
		else:
			_icon_rect.visible = false
	else:
		_icon_rect.visible = false


## Atualiza o status textual e a porcentagem real da etapa ativa
func set_step(message: String, progress: float, is_indeterminate: bool = false) -> void:
	_status_label.text = message
	_target_progress = clampf(progress, 0.0, 1.0)
	if is_indeterminate:
		_percent_label.text = "..."
	else:
		_percent_label.text = "%d%%" % int(_target_progress * 100.0)


## Esmaecimento de entrada suave (Fade In)
func fade_in(duration: float = 0.20) -> void:
	_root_control.visible = true
	var tween := create_tween()
	tween.tween_property(_root_control, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	fade_in_completed.emit()


## Esmaecimento de saída suave (Fade Out)
func fade_out(duration: float = 0.25) -> void:
	var tween := create_tween()
	tween.tween_property(_root_control, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await tween.finished
	_root_control.visible = false
	fade_out_completed.emit()


func is_active() -> bool:
	return _root_control.visible and _root_control.modulate.a > 0.01
