extends Control
class_name TalentTreeModal
## Árvore Permanente de Talentos (Lobby entre partidas).
## Exibe nós conectados, estados (Desbloqueado, Disponível, Bloqueado), custos, pré-requisitos, prévia, Compra e Respec.

signal start_new_run_requested
signal return_to_lobby_requested

const BG_OVERLAY := Color(0.012, 0.018, 0.025, 0.90)
const BG_PANEL := Color(0.038, 0.052, 0.066, 0.99)
const BG_NODE := Color(0.065, 0.085, 0.105, 0.98)
const BORDER := Color(0.28, 0.34, 0.38, 0.90)
const TEXT := Color(0.96, 0.94, 0.88, 1.0)
const MUTED := Color(0.60, 0.66, 0.65, 1.0)
const MINT := Color(0.55, 0.84, 0.71, 1.0)
const GOLD := Color(0.94, 0.74, 0.40, 1.0)
const RED := Color(0.88, 0.36, 0.33, 1.0)

var _service: PermanentProgressionService
var _selected_talent_id: String = "talent_vitality_root"

var _backdrop: ColorRect
var _main_panel: Panel
var _title_label: Label
var _currency_label: Label
var _tree_canvas: Control
var _detail_panel: Panel
var _detail_title: Label
var _detail_type: Label
var _detail_desc: Label
var _detail_prereq: Label
var _detail_preview: Label
var _buy_button: Button
var _respec_button: Button
var _back_lobby_button: Button
var _start_run_button: Button
var _node_buttons: Dictionary = {}


func _ready() -> void:
	name = "TalentTreeModal"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	_build_ui()
	get_viewport().size_changed.connect(_relayout)


func bind_service(service: PermanentProgressionService) -> void:
	if _service != null:
		if _service.currency_changed.is_connected(_on_service_updated):
			_service.currency_changed.disconnect(_on_service_updated)
		if _service.talents_changed.is_connected(_refresh_all):
			_service.talents_changed.disconnect(_refresh_all)
	_service = service
	if _service != null:
		_service.currency_changed.connect(_on_service_updated)
		_service.talents_changed.connect(_refresh_all)
	_rebuild_tree_nodes()
	_refresh_all()


func open_lobby() -> void:
	visible = true
	_refresh_all()
	_relayout()


func hide_lobby() -> void:
	visible = false


func _on_service_updated(_new_balance: int) -> void:
	_refresh_all()


func _build_ui() -> void:
	_backdrop = ColorRect.new()
	_backdrop.color = BG_OVERLAY
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	_main_panel = Panel.new()
	_main_panel.add_theme_stylebox_override("panel", _make_style(BG_PANEL, GOLD, 2, 16))
	add_child(_main_panel)

	_title_label = Label.new()
	_title_label.text = "ALTAR ANCESTRAL — ÁRVORE PERMANENTE DE TALENTOS"
	_title_label.add_theme_font_size_override("font_size", 19)
	_title_label.add_theme_color_override("font_color", GOLD)
	_main_panel.add_child(_title_label)

	_currency_label = Label.new()
	_currency_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_currency_label.add_theme_font_size_override("font_size", 16)
	_currency_label.add_theme_color_override("font_color", MINT)
	_main_panel.add_child(_currency_label)

	_tree_canvas = Control.new()
	_tree_canvas.name = "TreeCanvas"
	_main_panel.add_child(_tree_canvas)

	_detail_panel = Panel.new()
	_detail_panel.add_theme_stylebox_override("panel", _make_style(Color(0.028, 0.038, 0.048, 0.98), BORDER, 1, 12))
	_main_panel.add_child(_detail_panel)

	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 18)
	_detail_title.add_theme_color_override("font_color", TEXT)
	_detail_panel.add_child(_detail_title)

	_detail_type = Label.new()
	_detail_type.add_theme_font_size_override("font_size", 12)
	_detail_type.add_theme_color_override("font_color", GOLD)
	_detail_panel.add_child(_detail_type)

	_detail_desc = Label.new()
	_detail_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_desc.add_theme_font_size_override("font_size", 13)
	_detail_desc.add_theme_color_override("font_color", TEXT)
	_detail_panel.add_child(_detail_desc)

	_detail_prereq = Label.new()
	_detail_prereq.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_prereq.add_theme_font_size_override("font_size", 12)
	_detail_prereq.add_theme_color_override("font_color", MUTED)
	_detail_panel.add_child(_detail_prereq)

	_detail_preview = Label.new()
	_detail_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_preview.add_theme_font_size_override("font_size", 13)
	_detail_preview.add_theme_color_override("font_color", MINT)
	_detail_panel.add_child(_detail_preview)

	_buy_button = Button.new()
	_buy_button.text = "DESBLOQUEAR TALENTO"
	_buy_button.add_theme_font_size_override("font_size", 14)
	_buy_button.add_theme_color_override("font_color", TEXT)
	_buy_button.pressed.connect(_on_buy_pressed)
	_detail_panel.add_child(_buy_button)

	_respec_button = Button.new()
	_respec_button.text = "RESETAR TALENTOS (RESPEC GRATUITO)"
	_respec_button.add_theme_font_size_override("font_size", 13)
	_respec_button.add_theme_color_override("font_color", TEXT)
	_respec_button.add_theme_stylebox_override("normal", _make_style(RED.darkened(0.62), RED, 1, 8))
	_respec_button.add_theme_stylebox_override("hover", _make_style(RED.darkened(0.45), RED.lightened(0.2), 2, 8))
	_respec_button.pressed.connect(_on_respec_pressed)
	_main_panel.add_child(_respec_button)

	_back_lobby_button = Button.new()
	_back_lobby_button.text = "◄ VOLTAR AO SANTUÁRIO"
	_back_lobby_button.add_theme_font_size_override("font_size", 13)
	_back_lobby_button.add_theme_color_override("font_color", TEXT)
	_back_lobby_button.add_theme_stylebox_override("normal", _make_style(BG_NODE, GOLD, 1, 8))
	_back_lobby_button.add_theme_stylebox_override("hover", _make_style(BG_NODE.lightened(0.1), GOLD.lightened(0.2), 2, 8))
	_back_lobby_button.pressed.connect(func() -> void:
		hide_lobby()
		return_to_lobby_requested.emit()
	)
	_main_panel.add_child(_back_lobby_button)

	_start_run_button = Button.new()
	_start_run_button.text = "⚔ INICIAR PARTIDA NA TORRE"
	_start_run_button.add_theme_font_size_override("font_size", 15)
	_start_run_button.add_theme_color_override("font_color", TEXT)
	_start_run_button.add_theme_stylebox_override("normal", _make_style(MINT.darkened(0.55), MINT, 2, 10))
	_start_run_button.add_theme_stylebox_override("hover", _make_style(MINT.darkened(0.35), MINT.lightened(0.2), 2, 10))
	_start_run_button.pressed.connect(func() -> void: start_new_run_requested.emit())
	_main_panel.add_child(_start_run_button)


func _rebuild_tree_nodes() -> void:
	if _tree_canvas == null:
		return
	for child in _tree_canvas.get_children():
		child.queue_free()
	_node_buttons.clear()
	if _service == null:
		return

	# Conectores visuais (ColorRects posicionados no _relayout)
	for def in _service.talent_tree:
		var btn := Button.new()
		btn.name = "Node_" + def.id
		btn.clip_text = true
		btn.add_theme_font_size_override("font_size", 12)
		var tid: String = def.id
		btn.pressed.connect(func() -> void:
			_selected_talent_id = tid
			_refresh_all()
		)
		_tree_canvas.add_child(btn)
		_node_buttons[def.id] = btn


func _refresh_all() -> void:
	if _service == null:
		return
	_currency_label.text = "%s Disponível: %d" % [_service.state.currency_name, _service.state.essence]

	for def in _service.talent_tree:
		var btn: Button = _node_buttons.get(def.id, null) as Button
		if btn == null:
			continue
		var rank: int = _service.get_talent_rank(def.id)
		var prereq_ok: bool = _service.are_prerequisites_met(def.id)
		var can_buy: bool = _service.can_purchase_talent(def.id)
		var cost: int = _service.get_talent_cost(def.id)
		var selected: bool = (def.id == _selected_talent_id)

		var status_tag: String = ""
		var border_col: Color = BORDER
		var bg_col: Color = BG_NODE
		if rank >= def.max_rank:
			status_tag = "MÁX (%d/%d)" % [rank, def.max_rank]
			border_col = GOLD
			bg_col = Color(0.14, 0.11, 0.05, 0.98)
		elif rank > 0:
			status_tag = "NV %d/%d • %d Ess." % [rank, def.max_rank, cost]
			border_col = MINT if can_buy else GOLD
			bg_col = Color(0.08, 0.13, 0.11, 0.98)
		elif can_buy:
			status_tag = "DISPONÍVEL • %d Ess." % cost
			border_col = MINT
			bg_col = Color(0.07, 0.14, 0.12, 0.98)
		elif prereq_ok:
			status_tag = "CUSTO: %d Ess." % cost
			border_col = Color(0.55, 0.50, 0.35, 0.9)
		else:
			status_tag = "BLOQUEADO (%d Ess.)" % cost
			border_col = Color(0.22, 0.25, 0.28, 0.8)
			bg_col = Color(0.035, 0.042, 0.050, 0.92)

		var bw: int = 3 if selected else 1
		btn.text = "%s\n[%s]" % [def.title, status_tag]
		btn.add_theme_color_override("font_color", TEXT if (prereq_ok or rank > 0) else MUTED)
		btn.add_theme_stylebox_override("normal", _make_style(bg_col, border_col.lightened(0.25) if selected else border_col, bw, 10))
		btn.add_theme_stylebox_override("hover", _make_style(bg_col.lightened(0.08), border_col.lightened(0.3), bw, 10))
		btn.add_theme_stylebox_override("pressed", _make_style(bg_col.darkened(0.1), GOLD, 3, 10))

	_refresh_detail_panel()


func _refresh_detail_panel() -> void:
	if _service == null:
		return
	var def: TalentNodeDefinition = _service.get_talent_definition(_selected_talent_id)
	if def == null and not _service.talent_tree.is_empty():
		def = _service.talent_tree[0]
		_selected_talent_id = def.id
	if def == null:
		return

	var rank: int = _service.get_talent_rank(def.id)
	var cost: int = _service.get_talent_cost(def.id)
	var prereq_ok: bool = _service.are_prerequisites_met(def.id)
	var can_buy: bool = _service.can_purchase_talent(def.id)

	_detail_title.text = "%s  (Nível %d / %d)" % [def.title, rank, def.max_rank]
	_detail_type.text = "Categoria: %s" % def.type_label()
	_detail_desc.text = def.description

	var req_names: Array[String] = []
	for req_id in def.prerequisite_ids:
		var rdef: TalentNodeDefinition = _service.get_talent_definition(String(req_id))
		req_names.append(rdef.title if rdef != null else String(req_id))
	if not def.any_prerequisite_ids.is_empty():
		var opt_names: Array[String] = []
		for opt_id in def.any_prerequisite_ids:
			var odef: TalentNodeDefinition = _service.get_talent_definition(String(opt_id))
			opt_names.append(odef.title if odef != null else String(opt_id))
		req_names.append("Qualquer um: " + " OU ".join(opt_names))

	if req_names.is_empty():
		_detail_prereq.text = "Pré-requisitos: Nenhum (Nó Inicial)"
	else:
		_detail_prereq.text = "Pré-requisitos: %s" % ", ".join(req_names)

	_detail_preview.text = "Consequência na Partida:\n%s" % def.preview_text

	if rank >= def.max_rank:
		_buy_button.text = "TALENTO MAXIMIZADO"
		_buy_button.disabled = true
		_buy_button.add_theme_stylebox_override("disabled", _make_style(Color(0.10, 0.10, 0.10, 0.9), GOLD, 1, 8))
	elif can_buy:
		_buy_button.text = "COMPRAR POR %d ESSÊNCIA" % cost
		_buy_button.disabled = false
		_buy_button.add_theme_stylebox_override("normal", _make_style(MINT.darkened(0.55), MINT, 2, 8))
		_buy_button.add_theme_stylebox_override("hover", _make_style(MINT.darkened(0.35), MINT.lightened(0.2), 2, 8))
	elif not prereq_ok:
		_buy_button.text = "PRÉ-REQUISITO BLOQUEADO (%d ESSÊNCIA)" % cost
		_buy_button.disabled = true
		_buy_button.add_theme_stylebox_override("disabled", _make_style(Color(0.08, 0.08, 0.10, 0.9), BORDER, 1, 8))
	else:
		_buy_button.text = "ESSÊNCIA INSUFICIENTE (%d / %d)" % [_service.state.essence, cost]
		_buy_button.disabled = true
		_buy_button.add_theme_stylebox_override("disabled", _make_style(Color(0.12, 0.08, 0.06, 0.9), RED, 1, 8))


func _on_buy_pressed() -> void:
	if _service == null or _selected_talent_id.is_empty():
		return
	_service.purchase_talent(_selected_talent_id)


func _on_respec_pressed() -> void:
	if _service == null:
		return
	_service.respec_all_talents()


func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10.0 or vp.y < 10.0:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var pw: float = minf(960.0, vp.x - 28.0)
	var ph: float = minf(560.0, vp.y - 28.0)
	_main_panel.size = Vector2(pw, ph)
	_main_panel.position = (vp - _main_panel.size) * 0.5

	_title_label.position = Vector2(24.0, 16.0)
	_title_label.size = Vector2(pw * 0.62, 30.0)
	_currency_label.position = Vector2(pw * 0.62, 16.0)
	_currency_label.size = Vector2(pw * 0.38 - 24.0, 30.0)

	var content_top: float = 56.0
	var content_h: float = ph - 122.0
	var tree_w: float = pw * 0.58 - 28.0
	var detail_w: float = pw - tree_w - 60.0

	_tree_canvas.position = Vector2(24.0, content_top)
	_tree_canvas.size = Vector2(tree_w, content_h)

	_detail_panel.position = Vector2(36.0 + tree_w, content_top)
	_detail_panel.size = Vector2(detail_w, content_h)

	_detail_title.position = Vector2(18.0, 16.0)
	_detail_title.size = Vector2(detail_w - 36.0, 28.0)
	_detail_type.position = Vector2(18.0, 46.0)
	_detail_type.size = Vector2(detail_w - 36.0, 20.0)
	_detail_desc.position = Vector2(18.0, 76.0)
	_detail_desc.size = Vector2(detail_w - 36.0, 86.0)
	_detail_prereq.position = Vector2(18.0, 168.0)
	_detail_prereq.size = Vector2(detail_w - 36.0, 48.0)
	_detail_preview.position = Vector2(18.0, 224.0)
	_detail_preview.size = Vector2(detail_w - 36.0, 80.0)
	_buy_button.position = Vector2(18.0, content_h - 56.0)
	_buy_button.size = Vector2(detail_w - 36.0, 42.0)

	_respec_button.position = Vector2(24.0, ph - 52.0)
	_respec_button.size = Vector2(265.0, 38.0)
	_back_lobby_button.position = Vector2(302.0, ph - 52.0)
	_back_lobby_button.size = Vector2(220.0, 38.0)
	_start_run_button.position = Vector2(pw - 314.0, ph - 52.0)
	_start_run_button.size = Vector2(290.0, 38.0)

	if _service == null:
		return
	var node_w: float = minf(210.0, (tree_w - 28.0) * 0.46)
	var node_h: float = 64.0
	var center_x: float = (tree_w - node_w) * 0.5
	var row_gap: float = (content_h - node_h * 4.0) / 3.0
	row_gap = maxf(14.0, row_gap)

	for def in _service.talent_tree:
		var btn: Button = _node_buttons.get(def.id, null) as Button
		if btn == null:
			continue
		var gx: float = def.ui_grid_pos.x
		var gy: float = def.ui_grid_pos.y
		var x_pos: float = center_x + gx * (node_w * 0.56 + 12.0)
		var y_pos: float = gy * (node_h + row_gap)
		btn.position = Vector2(x_pos, y_pos)
		btn.size = Vector2(node_w, node_h)


func _make_style(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	return s
