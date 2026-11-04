extends Control
class_name LevelUpModal
## Tela de evolução durante a partida (3 cartas válidas).
## Funciona com SceneTree pausado (PROCESS_MODE_ALWAYS), mouse, teclado (1/2/3) e toque.

signal upgrade_chosen(upgrade: ProgressionUpgradeDefinition)

const BG_OVERLAY := Color(0.015, 0.022, 0.030, 0.82)
const BG_CARD := Color(0.048, 0.064, 0.080, 0.98)
const BG_CARD_HOVER := Color(0.075, 0.105, 0.125, 0.99)
const BORDER_DEFAULT := Color(0.28, 0.34, 0.37, 0.90)
const TEXT := Color(0.96, 0.94, 0.88, 1.0)
const MUTED := Color(0.65, 0.71, 0.70, 1.0)
const MINT := Color(0.55, 0.84, 0.71, 1.0)
const GOLD := Color(0.94, 0.74, 0.40, 1.0)
const CORAL := Color(0.92, 0.45, 0.36, 1.0)
const CYAN := Color(0.48, 0.78, 0.95, 1.0)

const ICON_STAB: Texture2D = preload("res://game/ui/icons/stab.png")
const ICON_ARC: Texture2D = preload("res://game/ui/icons/arc.png")
const ICON_SPIN: Texture2D = preload("res://game/ui/icons/spin.png")

var _offers: Array[ProgressionUpgradeDefinition] = []
var _run_state: RunProgressionState
var _stats: CharacterStats

var _backdrop: ColorRect
var _header_panel: Panel
var _title_label: Label
var _subtitle_label: Label
var _cards_container: Control
var _card_panels: Array[Panel] = []
var _card_buttons: Array[Button] = []


func _ready() -> void:
	name = "LevelUpModal"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_base_ui()
	get_viewport().size_changed.connect(_relayout)


func present_offers(
	offers: Array[ProgressionUpgradeDefinition],
	run_state: RunProgressionState,
	stats: CharacterStats = null
) -> void:
	_offers = offers.duplicate()
	_run_state = run_state
	_stats = stats
	if _offers.is_empty():
		hide_modal()
		return
	visible = true
	_rebuild_cards()
	_relayout()


func hide_modal() -> void:
	visible = false
	_offers.clear()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _offers.is_empty():
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.physical_keycode == KEY_1 or key_event.keycode == KEY_1:
				_select_index(0)
				get_viewport().set_input_as_handled()
			elif key_event.physical_keycode == KEY_2 or key_event.keycode == KEY_2:
				_select_index(1)
				get_viewport().set_input_as_handled()
			elif key_event.physical_keycode == KEY_3 or key_event.keycode == KEY_3:
				_select_index(2)
				get_viewport().set_input_as_handled()


func _select_index(index: int) -> void:
	if index < 0 or index >= _offers.size():
		return
	var chosen: ProgressionUpgradeDefinition = _offers[index]
	upgrade_chosen.emit(chosen)


func _build_base_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = BG_OVERLAY
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_header_panel = Panel.new()
	_header_panel.name = "HeaderPanel"
	_header_panel.add_theme_stylebox_override("panel", _make_style(BG_CARD, GOLD, 2, 12))
	add_child(_header_panel)

	_title_label = Label.new()
	_title_label.text = "NÍVEL ALCANÇADO — ESCOLHA UMA EVOLUÇÃO"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 20)
	_title_label.add_theme_color_override("font_color", GOLD)
	_header_panel.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.text = "Clique em uma carta ou pressione [1], [2] ou [3]"
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_subtitle_label.add_theme_font_size_override("font_size", 13)
	_subtitle_label.add_theme_color_override("font_color", MUTED)
	_header_panel.add_child(_subtitle_label)

	_cards_container = Control.new()
	_cards_container.name = "CardsContainer"
	add_child(_cards_container)


func _rebuild_cards() -> void:
	for child in _cards_container.get_children():
		child.queue_free()
	_card_panels.clear()
	_card_buttons.clear()

	var pending_count: int = _run_state.pending_upgrade_choices if _run_state != null else 1
	var lvl: int = _run_state.level if _run_state != null else 2
	_title_label.text = "NÍVEL %02d — ESCOLHA SUA EVOLUÇÃO" % lvl
	if pending_count > 1:
		_subtitle_label.text = "Escolhas na fila: %d  •  Clique em uma carta ou pressione [1], [2], [3]" % pending_count
	else:
		_subtitle_label.text = "Combate pausado  •  Clique em uma carta ou pressione [1], [2], [3]"

	for i in range(_offers.size()):
		var upg: ProgressionUpgradeDefinition = _offers[i]
		var accent: Color = _category_color(upg.category)
		var card := Panel.new()
		card.name = "OfferCard_%d" % (i + 1)
		card.add_theme_stylebox_override("panel", _make_style(BG_CARD, accent, 2, 14))
		_cards_container.add_child(card)
		_card_panels.append(card)

		var badge := Label.new()
		badge.name = "CategoryBadge"
		badge.text = upg.category_label()
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 11)
		badge.add_theme_color_override("font_color", accent)
		card.add_child(badge)

		var icon_rect := TextureRect.new()
		icon_rect.name = "Icon"
		icon_rect.texture = _icon_for_key(upg.icon_key)
		icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_rect.modulate = accent.lightened(0.25)
		card.add_child(icon_rect)

		var title := Label.new()
		title.name = "Title"
		title.text = upg.title
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		title.add_theme_font_size_override("font_size", 17)
		title.add_theme_color_override("font_color", TEXT)
		card.add_child(title)

		var rank_label := Label.new()
		rank_label.name = "RankInfo"
		var cur_rank: int = _run_state.get_upgrade_rank(upg.id) if _run_state != null else 0
		if upg.max_rank > 1:
			rank_label.text = "Nível da Melhoria: %d -> %d (Máx %d)" % [cur_rank, cur_rank + 1, upg.max_rank]
		else:
			rank_label.text = "Evolução Única de Comportamento"
		rank_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rank_label.add_theme_font_size_override("font_size", 11)
		rank_label.add_theme_color_override("font_color", MUTED)
		card.add_child(rank_label)

		var desc := Label.new()
		desc.name = "Description"
		desc.text = upg.description
		desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", TEXT)
		card.add_child(desc)

		var compare_box := Panel.new()
		compare_box.name = "CompareBox"
		compare_box.add_theme_stylebox_override("panel", _make_style(Color(0.03, 0.04, 0.05, 0.95), BORDER_DEFAULT, 1, 8))
		card.add_child(compare_box)

		var compare_label := Label.new()
		compare_label.name = "CompareLabel"
		compare_label.text = _build_comparison_text(upg)
		compare_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		compare_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		compare_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		compare_label.add_theme_font_size_override("font_size", 12)
		compare_label.add_theme_color_override("font_color", MINT)
		compare_box.add_child(compare_label)

		var btn := Button.new()
		btn.name = "SelectButton"
		btn.text = "ESCOLHER [%d]" % (i + 1)
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_color_override("font_color", TEXT)
		btn.add_theme_stylebox_override("normal", _make_style(accent.darkened(0.55), accent, 1, 8))
		btn.add_theme_stylebox_override("hover", _make_style(accent.darkened(0.35), accent.lightened(0.2), 2, 8))
		btn.add_theme_stylebox_override("pressed", _make_style(accent.darkened(0.68), accent, 2, 8))
		var pick_idx: int = i
		btn.pressed.connect(func() -> void: _select_index(pick_idx))
		card.add_child(btn)
		_card_buttons.append(btn)


func _build_comparison_text(upg: ProgressionUpgradeDefinition) -> String:
	var base_preview: String = upg.preview_comparison
	if _stats == null:
		return base_preview
	if upg.id == "stat_dano":
		var cur_dmg: int = _stats.get_damage()
		var next_dmg: int = maxi(cur_dmg + 1, roundi(float(cur_dmg) * 1.22))
		return "%s\nDano: %d -> ~%d" % [base_preview, cur_dmg, next_dmg]
	elif upg.id == "stat_vida_maxima":
		var cur_hp: int = _stats.get_max_health()
		return "%s\nVida Máx: %d -> %d" % [base_preview, cur_hp, cur_hp + 25]
	elif upg.id == "stat_velocidade_ataque":
		var cur_spd: int = roundi(_stats.get_attack_speed() * 100.0)
		return "%s\nVel. Ataque: %d%% -> %d%%" % [base_preview, cur_spd, cur_spd + 18]
	return base_preview


func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10.0 or vp.y < 10.0:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var header_w: float = minf(660.0, vp.x - 32.0)
	_header_panel.size = Vector2(header_w, 76.0)
	_header_panel.position = Vector2((vp.x - header_w) * 0.5, maxf(18.0, vp.y * 0.06))
	_title_label.position = Vector2(16.0, 10.0)
	_title_label.size = Vector2(header_w - 32.0, 30.0)
	_subtitle_label.position = Vector2(16.0, 42.0)
	_subtitle_label.size = Vector2(header_w - 32.0, 24.0)

	var count: int = _card_panels.size()
	if count == 0:
		return
	var gap: float = 18.0
	var max_total_w: float = minf(980.0, vp.x - 36.0)
	var card_w: float = minf(300.0, (max_total_w - gap * float(maxi(0, count - 1))) / float(count))
	var card_h: float = minf(395.0, vp.y - _header_panel.position.y - _header_panel.size.y - 38.0)
	var total_w: float = card_w * float(count) + gap * float(maxi(0, count - 1))
	var start_x: float = (vp.x - total_w) * 0.5
	var start_y: float = _header_panel.position.y + _header_panel.size.y + 18.0

	_cards_container.position = Vector2.ZERO
	_cards_container.size = vp

	for i in range(count):
		var card: Panel = _card_panels[i]
		card.position = Vector2(start_x + float(i) * (card_w + gap), start_y)
		card.size = Vector2(card_w, card_h)

		var badge: Label = card.get_node("CategoryBadge") as Label
		var icon_rect: TextureRect = card.get_node("Icon") as TextureRect
		var title: Label = card.get_node("Title") as Label
		var rank_info: Label = card.get_node("RankInfo") as Label
		var desc: Label = card.get_node("Description") as Label
		var compare_box: Panel = card.get_node("CompareBox") as Panel
		var compare_label: Label = compare_box.get_node("CompareLabel") as Label
		var btn: Button = card.get_node("SelectButton") as Button

		badge.position = Vector2(12.0, 12.0)
		badge.size = Vector2(card_w - 24.0, 20.0)
		icon_rect.position = Vector2((card_w - 46.0) * 0.5, 36.0)
		icon_rect.size = Vector2(46.0, 46.0)
		title.position = Vector2(14.0, 88.0)
		title.size = Vector2(card_w - 28.0, 44.0)
		rank_info.position = Vector2(14.0, 132.0)
		rank_info.size = Vector2(card_w - 28.0, 20.0)
		desc.position = Vector2(16.0, 156.0)
		desc.size = Vector2(card_w - 32.0, maxf(68.0, card_h - 280.0))

		var comp_y: float = card_h - 116.0
		compare_box.position = Vector2(14.0, comp_y)
		compare_box.size = Vector2(card_w - 28.0, 52.0)
		compare_label.position = Vector2(8.0, 4.0)
		compare_label.size = Vector2(compare_box.size.x - 16.0, 44.0)

		btn.position = Vector2(14.0, card_h - 52.0)
		btn.size = Vector2(card_w - 28.0, 38.0)


func _category_color(category: int) -> Color:
	match category:
		ProgressionUpgradeDefinition.Category.ABILITY_TRANSFORMATION:
			return MINT
		ProgressionUpgradeDefinition.Category.SPECIAL_MODIFIER:
			return CORAL
		ProgressionUpgradeDefinition.Category.ABILITY_UPGRADE:
			return CYAN
		_:
			return GOLD


func _icon_for_key(icon_key: String) -> Texture2D:
	match icon_key:
		"arc":
			return ICON_ARC
		"spin":
			return ICON_SPIN
		_:
			return ICON_STAB


func _make_style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s
