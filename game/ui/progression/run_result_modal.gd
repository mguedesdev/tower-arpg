extends Control
class_name RunResultModal
## Tela de resultado da partida: exibe progresso alcançado, inimigos derrotados, nível, build e Essência conquistada.
## Reabrir esta tela nunca recalcula ou duplica a moeda (exibe RunSummaryState consolidado).

signal open_talent_tree_requested
signal restart_run_requested

const BG_OVERLAY := Color(0.012, 0.018, 0.025, 0.86)
const BG_PANEL := Color(0.042, 0.056, 0.070, 0.98)
const BORDER := Color(0.30, 0.36, 0.39, 0.90)
const TEXT := Color(0.96, 0.94, 0.88, 1.0)
const MUTED := Color(0.64, 0.70, 0.69, 1.0)
const MINT := Color(0.55, 0.84, 0.71, 1.0)
const GOLD := Color(0.94, 0.74, 0.40, 1.0)
const RED := Color(0.88, 0.36, 0.33, 1.0)

var _backdrop: ColorRect
var _main_panel: Panel
var _title_label: Label
var _subtitle_label: Label
var _stats_label: Label
var _build_label: Label
var _essence_panel: Panel
var _essence_label: Label
var _talent_button: Button
var _restart_button: Button


func _ready() -> void:
	name = "RunResultModal"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()
	get_viewport().size_changed.connect(_relayout)


func show_summary(summary: RunSummaryState, current_essence_balance: int) -> void:
	if summary == null:
		return
	visible = true
	if summary.victory:
		_title_label.text = "PROVAÇÃO CONCLUÍDA — VITÓRIA!"
		_title_label.add_theme_color_override("font_color", MINT)
	else:
		_title_label.text = "TENTATIVA ENCERRADA — VOCÊ CAIU"
		_title_label.add_theme_color_override("font_color", RED)

	_subtitle_label.text = "Classe: Guerreiro  •  Forma Final: %s" % summary.active_ability_name
	_stats_label.text = (
		"Onda Alcançada: %d  (Concluídas: %d)\n" % [summary.wave_reached, summary.waves_completed]
		+ "Inimigos Derrotados: %d\n" % summary.enemies_defeated
		+ "Nível da Partida: %d  (%d XP Total)" % [summary.run_level_reached, summary.total_xp_earned]
	)

	if summary.acquired_upgrade_titles.is_empty():
		_build_label.text = "Evoluções da Partida:\nNenhuma evolução adquirida nesta tentativa."
	else:
		_build_label.text = "Build da Tentativa (%d evoluções):\n• %s" % [
			summary.acquired_upgrade_titles.size(),
			"\n• ".join(summary.acquired_upgrade_titles)
		]

	_essence_label.text = "+%d ESSÊNCIA CONQUISTADA   (Saldo no Altar: %d Essência)" % [
		summary.essence_rewarded,
		current_essence_balance
	]
	_relayout()


func hide_modal() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.physical_keycode == KEY_T or key_event.keycode == KEY_T:
				open_talent_tree_requested.emit()
				get_viewport().set_input_as_handled()
			elif key_event.physical_keycode == KEY_R or key_event.keycode == KEY_R:
				restart_run_requested.emit()
				get_viewport().set_input_as_handled()


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = BG_OVERLAY
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_main_panel = Panel.new()
	_main_panel.add_theme_stylebox_override("panel", _make_style(BG_PANEL, GOLD, 2, 16))
	add_child(_main_panel)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 22)
	_title_label.add_theme_color_override("font_color", RED)
	_main_panel.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.add_theme_color_override("font_color", MINT)
	_main_panel.add_child(_subtitle_label)

	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 15)
	_stats_label.add_theme_color_override("font_color", TEXT)
	_main_panel.add_child(_stats_label)

	_build_label = Label.new()
	_build_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_build_label.add_theme_font_size_override("font_size", 13)
	_build_label.add_theme_color_override("font_color", MUTED)
	_main_panel.add_child(_build_label)

	_essence_panel = Panel.new()
	_essence_panel.add_theme_stylebox_override("panel", _make_style(Color(0.08, 0.07, 0.04, 0.96), GOLD, 1, 10))
	_main_panel.add_child(_essence_panel)

	_essence_label = Label.new()
	_essence_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_essence_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_essence_label.add_theme_font_size_override("font_size", 15)
	_essence_label.add_theme_color_override("font_color", GOLD)
	_essence_panel.add_child(_essence_label)

	_talent_button = Button.new()
	_talent_button.text = "ÁRVORE DE TALENTOS / LOBBY [T]"
	_talent_button.add_theme_font_size_override("font_size", 14)
	_talent_button.add_theme_color_override("font_color", TEXT)
	_talent_button.add_theme_stylebox_override("normal", _make_style(MINT.darkened(0.58), MINT, 1, 10))
	_talent_button.add_theme_stylebox_override("hover", _make_style(MINT.darkened(0.38), MINT.lightened(0.2), 2, 10))
	_talent_button.pressed.connect(func() -> void: open_talent_tree_requested.emit())
	_main_panel.add_child(_talent_button)

	_restart_button = Button.new()
	_restart_button.text = "NOVA PARTIDA [R]"
	_restart_button.add_theme_font_size_override("font_size", 14)
	_restart_button.add_theme_color_override("font_color", TEXT)
	_restart_button.add_theme_stylebox_override("normal", _make_style(GOLD.darkened(0.58), GOLD, 1, 10))
	_restart_button.add_theme_stylebox_override("hover", _make_style(GOLD.darkened(0.38), GOLD.lightened(0.2), 2, 10))
	_restart_button.pressed.connect(func() -> void: restart_run_requested.emit())
	_main_panel.add_child(_restart_button)


func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10.0 or vp.y < 10.0:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var pw: float = minf(600.0, vp.x - 32.0)
	var ph: float = minf(430.0, vp.y - 32.0)
	_main_panel.size = Vector2(pw, ph)
	_main_panel.position = (vp - _main_panel.size) * 0.5

	_title_label.position = Vector2(20.0, 18.0)
	_title_label.size = Vector2(pw - 40.0, 32.0)
	_subtitle_label.position = Vector2(20.0, 52.0)
	_subtitle_label.size = Vector2(pw - 40.0, 24.0)

	_stats_label.position = Vector2(28.0, 88.0)
	_stats_label.size = Vector2(pw - 56.0, 78.0)

	_build_label.position = Vector2(28.0, 174.0)
	_build_label.size = Vector2(pw - 56.0, maxf(90.0, ph - 306.0))

	_essence_panel.position = Vector2(24.0, ph - 118.0)
	_essence_panel.size = Vector2(pw - 48.0, 44.0)
	_essence_label.position = Vector2(8.0, 4.0)
	_essence_label.size = Vector2(_essence_panel.size.x - 16.0, 36.0)

	var btn_w: float = (pw - 60.0) * 0.5
	_talent_button.position = Vector2(24.0, ph - 58.0)
	_talent_button.size = Vector2(btn_w, 42.0)
	_restart_button.position = Vector2(36.0 + btn_w, ph - 58.0)
	_restart_button.size = Vector2(btn_w, 42.0)


func _make_style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s
