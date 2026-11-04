extends Control
class_name BossHealthBarHUD

## Barra de Vida Épica de Chefe (Dark Fantasy / Souls-like / Albion)
## Exibida no topo central da tela durante batalhas de chefe com moldura ornamentada,
## rastro de dano (trail), indicador de Fase 2 e anúncio de entrada/vitória.

const BAR_WIDTH: float = 640.0
const BAR_HEIGHT: float = 24.0
const PANEL_HEIGHT: float = 78.0

const COLOR_BG := Color(0.06, 0.05, 0.07, 0.96)
const COLOR_BORDER_P1 := Color(0.72, 0.54, 0.22, 0.95)
const COLOR_BORDER_ENRAGE := Color(0.95, 0.22, 0.18, 0.98)
const COLOR_FILL := Color(0.78, 0.12, 0.12, 1.0)
const COLOR_FILL_ENRAGE := Color(0.92, 0.18, 0.14, 1.0)
const COLOR_TRAIL := Color(0.92, 0.62, 0.20, 0.90)
const COLOR_GOLD := Color(0.95, 0.82, 0.45)
const COLOR_SUBTITLE := Color(0.80, 0.76, 0.70)

var _container: PanelContainer
var _title_label: Label
var _subtitle_label: Label
var _fill_bar: ColorRect
var _trail_bar: ColorRect
var _hp_label: Label
var _active_boss: Node = null

var _target_ratio: float = 1.0
var _trail_ratio: float = 1.0
var _current_hp: int = 100
var _max_hp: int = 100


func _ready() -> void:
	name = "BossHealthBarHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()
	_relayout()
	get_viewport().size_changed.connect(_relayout)


func _relayout() -> void:
	if _container == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	_container.size = Vector2(BAR_WIDTH + 32.0, PANEL_HEIGHT)
	_container.position = Vector2((vp_size.x - _container.size.x) * 0.5, 20.0)


func _build_ui() -> void:
	_container = PanelContainer.new()
	_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_container.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BORDER_P1))
	add_child(_container)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 12)
	_container.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 5)
	margin.add_child(vbox)

	# 1. Cabeçalho: Título e Subtítulo
	var hbox_header := HBoxContainer.new()
	hbox_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hbox_header)

	var skull_icon := Label.new()
	skull_icon.text = "💀 "
	skull_icon.add_theme_font_size_override("font_size", 16)
	skull_icon.add_theme_color_override("font_color", COLOR_GOLD)
	hbox_header.add_child(skull_icon)

	_title_label = Label.new()
	_title_label.text = "MALAKOR, O CEIFADOR DA CRIPTA"
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", COLOR_GOLD)
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox_header.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "O Carrasco dos Condenados"
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	_subtitle_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	hbox_header.add_child(_subtitle_label)

	# 2. Barra de Vida (Slot com fundo escuro, trail e fill)
	var bar_slot := Control.new()
	bar_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_slot.custom_minimum_size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	vbox.add_child(bar_slot)

	var bar_bg := ColorRect.new()
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_bg.color = Color(0.08, 0.08, 0.10, 0.95)
	bar_bg.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_slot.add_child(bar_bg)

	_trail_bar = ColorRect.new()
	_trail_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_trail_bar.color = COLOR_TRAIL
	_trail_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_slot.add_child(_trail_bar)

	_fill_bar = ColorRect.new()
	_fill_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_bar.color = COLOR_FILL
	_fill_bar.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_slot.add_child(_fill_bar)

	# Moldura interna dourada
	var inner_rim := ReferenceRect.new()
	inner_rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner_rim.border_color = Color(0.45, 0.35, 0.18, 0.85)
	inner_rim.border_width = 1.0
	inner_rim.editor_only = false
	inner_rim.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_slot.add_child(inner_rim)

	_hp_label = Label.new()
	_hp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_label.text = "850 / 850 (100%)"
	_hp_label.add_theme_font_size_override("font_size", 12)
	_hp_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.95))
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hp_label.size = Vector2(BAR_WIDTH, BAR_HEIGHT)
	bar_slot.add_child(_hp_label)


func bind_boss(boss_node: Node) -> void:
	if _active_boss != null and is_instance_valid(_active_boss):
		if _active_boss.is_connected("health_changed", _on_boss_health_changed):
			_active_boss.disconnect("health_changed", _on_boss_health_changed)
		if _active_boss.is_connected("died", _on_boss_died):
			_active_boss.disconnect("died", _on_boss_died)
		if _active_boss.is_connected("enrage_entered", _on_boss_enraged):
			_active_boss.disconnect("enrage_entered", _on_boss_enraged)

	_active_boss = boss_node
	if _active_boss == null or not is_instance_valid(_active_boss):
		hide_bar()
		return

	_active_boss.connect("health_changed", _on_boss_health_changed)
	_active_boss.connect("died", _on_boss_died)
	if _active_boss.has_signal("enrage_entered"):
		_active_boss.connect("enrage_entered", _on_boss_enraged)

	_current_hp = int(_active_boss.get("health"))
	_max_hp = int(_active_boss.get("maximum_health"))
	_target_ratio = 1.0
	_trail_ratio = 1.0

	_title_label.text = "MALAKOR, O CEIFADOR DA CRIPTA"
	_subtitle_label.text = "O Carrasco dos Condenados"
	_subtitle_label.add_theme_color_override("font_color", COLOR_SUBTITLE)
	_container.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BORDER_P1))
	_fill_bar.color = COLOR_FILL

	_update_display()
	visible = true
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.5)


func _on_boss_health_changed(current: int, maximum: int) -> void:
	_current_hp = current
	_max_hp = maxi(maximum, 1)
	_target_ratio = clampf(float(_current_hp) / float(_max_hp), 0.0, 1.0)
	_update_display()


func _on_boss_enraged() -> void:
	_subtitle_label.text = "⚡ FÚRIA DAS SOMBRAS (Fase 2) ⚡"
	_subtitle_label.add_theme_color_override("font_color", Color(1.0, 0.35, 0.30))
	_container.add_theme_stylebox_override("panel", _make_panel_style(COLOR_BORDER_ENRAGE))
	_fill_bar.color = COLOR_FILL_ENRAGE

	# Pulso visual de alerta no Enrage
	var tw: Tween = create_tween()
	tw.tween_property(_container, "scale", Vector2(1.03, 1.03), 0.12)
	tw.tween_property(_container, "scale", Vector2.ONE, 0.18)


func _on_boss_died() -> void:
	_title_label.text = "✦ VITÓRIA: MALAKOR FOI DERROTADO! ✦"
	_subtitle_label.text = "A maldição da cripta se desfaz..."
	_target_ratio = 0.0
	_update_display()

	var tw: Tween = create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(self, "modulate:a", 0.0, 0.8)
	tw.tween_callback(hide_bar)


func hide_bar() -> void:
	visible = false
	_active_boss = null


func _process(delta: float) -> void:
	if not visible:
		return
	if _trail_ratio > _target_ratio:
		_trail_ratio = maxf(_target_ratio, _trail_ratio - delta * 0.40)
		_trail_bar.size.x = BAR_WIDTH * _trail_ratio


func _update_display() -> void:
	_fill_bar.size.x = BAR_WIDTH * _target_ratio
	var pct: int = int(roundf(_target_ratio * 100.0))
	_hp_label.text = "%d / %d (%d%%)" % [_current_hp, _max_hp, pct]


func _make_panel_style(border_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_BG
	sb.border_color = border_color
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	sb.shadow_size = 8
	return sb
