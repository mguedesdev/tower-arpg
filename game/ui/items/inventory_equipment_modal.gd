extends Control
class_name InventoryEquipmentModal
## Modal Unificado de Inventário Espacial em Grid (10x6) + Paperdoll em Cruz + Status Básico.
## • Layout fiel à referência visual Dark-Fantasy Dourada.
## • Centralizado quando aberto sozinho; lado a lado (direita) quando aberto junto com NPC/Baú.
## • Tooltip com comparação linha a linha (▲ verde / ▼ vermelho) e área dedicada de Ganhos e Perdas.
## • Atalho: [I] ou [B].

signal opened()
signal closed()
signal item_context_action_requested(item: ItemInstance)
signal potion_consumed(heal_amount: int)

const BG_COLOR := Color(0.055, 0.048, 0.058, 0.98)
const PANEL_INNER_BG := Color(0.075, 0.065, 0.08, 0.96)
const BORDER_COLOR := Color(0.68, 0.52, 0.26, 0.96)
const BORDER_SUBTLE := Color(0.42, 0.33, 0.19, 0.85)
const GOLD_COLOR := Color(0.94, 0.79, 0.44)
const TEXT_COLOR := Color(0.93, 0.89, 0.82)
const MUTED_LABEL := Color(0.68, 0.60, 0.50)
const RED_ALERT := Color(0.95, 0.28, 0.28)
const CELL_SIZE := 39

var inventory: SpatialInventoryGrid
var equipment: CharacterEquipment
var stats: CharacterStats
var current_gold: int = 150
var active_partner_station: String = ""

# Janela móvel
var _window_panel: PanelContainer
var _header_bar: HBoxContainer
var _gold_header_label: Label
var _mochila_title_label: Label
var _hint_label: Label
var _is_dragging_window: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_win_pos: Vector2 = Vector2.ZERO
var _has_custom_window_pos: bool = false

# Estado de arrasto e foco de itens
var _held_item: ItemInstance = null
var _held_origin_pos: Vector2i = Vector2i(-1, -1)
var _held_origin_rotated: bool = false
var _held_origin_slot: ItemDefinition.EquipmentSlot = ItemDefinition.EquipmentSlot.NONE
var _held_preview: TextureRect
var _hovered_grid_item: ItemInstance = null
var _warning_timer: float = 0.0

# Componentes da UI
var _grid_container: Control
var _paperdoll_slots: Dictionary = {}    ## EquipmentSlot -> Panel
var _silhouette_cache: Dictionary = {}   ## EquipmentSlot -> Texture2D

# Labels de Status Básico (Tabela 2 colunas fiel à referência)
var _stat_val_hp: Label
var _stat_val_dmg: Label
var _stat_val_crit: Label
var _stat_val_mana: Label
var _stat_val_armor: Label
var _stat_val_speed: Label
var _stat_attributes_footer: Label

# Tooltip flutuante
var _tooltip_panel: PanelContainer
var _tooltip_text: RichTextLabel


func _ready() -> void:
	name = "InventoryEquipmentModal"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group("blocking_modal")
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func bind_context(inv: SpatialInventoryGrid, eq: CharacterEquipment, p_stats: CharacterStats) -> void:
	if inventory != null and inventory.grid_changed.is_connected(_refresh_grid_view):
		inventory.grid_changed.disconnect(_refresh_grid_view)
	if equipment != null and equipment.equipment_changed.is_connected(_on_equipment_changed):
		equipment.equipment_changed.disconnect(_on_equipment_changed)

	inventory = inv
	equipment = eq
	stats = p_stats

	if inventory != null:
		inventory.grid_changed.connect(_refresh_grid_view)
	if equipment != null:
		equipment.equipment_changed.connect(_on_equipment_changed)

	_refresh_all()


func set_gold(gold_val: int) -> void:
	current_gold = maxi(0, gold_val)
	if _gold_header_label != null:
		_gold_header_label.text = "🪙 %d" % current_gold
	if visible:
		_refresh_stats_view()


func set_partner_station(station_id: String) -> void:
	active_partner_station = station_id
	_has_custom_window_pos = false
	_update_hint_label()


func get_window_size() -> Vector2:
	if _window_panel == null:
		return Vector2(690, 540)
	_window_panel.reset_size()
	var sz: Vector2 = _window_panel.size
	if sz.x < 100.0:
		sz = _window_panel.get_combined_minimum_size()
	return sz


func set_window_position(pos: Vector2) -> void:
	if _window_panel == null:
		return
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = get_window_size()
	if vp.x > 100.0 and vp.y > 100.0:
		pos.x = clampf(pos.x, 6.0, maxf(6.0, vp.x - sz.x - 6.0))
		pos.y = clampf(pos.y, 6.0, maxf(6.0, vp.y - sz.y - 6.0))
	_window_panel.position = pos


func open_inventory() -> void:
	visible = true
	_update_hint_label()
	_refresh_all()
	if not _has_custom_window_pos:
		call_deferred("_center_window_on_screen")
	opened.emit()


func close_inventory() -> void:
	if _held_item != null:
		var restored: bool = false
		if inventory != null:
			if _held_origin_pos.x >= 0 and _held_origin_pos.y >= 0:
				_held_item.is_rotated = _held_origin_rotated
				if inventory.can_place_at(_held_item, _held_origin_pos):
					restored = inventory.place_item(_held_item, _held_origin_pos)
			if not restored:
				restored = inventory.auto_add_item(_held_item)
		if not restored and equipment != null and _held_origin_slot != ItemDefinition.EquipmentSlot.NONE:
			if equipment.get_equipped_item(_held_origin_slot) == null:
				equipment.equip_item(_held_item, _held_origin_slot, stats)
				restored = true
		_set_held_item(null)
	visible = false
	_is_dragging_window = false
	_hide_tooltip()
	closed.emit()


func toggle_inventory() -> void:
	if visible:
		close_inventory()
	else:
		open_inventory()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_I or event.keycode == KEY_B:
			toggle_inventory()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and visible and active_partner_station.is_empty():
			close_inventory()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			if _try_rotate_current_item():
				get_viewport().set_input_as_handled()
				return
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging_window = false
		elif mb.pressed and _held_item != null and (mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN or mb.button_index == MOUSE_BUTTON_MIDDLE):
			if _try_rotate_current_item():
				get_viewport().set_input_as_handled()
				return
	elif event is InputEventMouseMotion:
		if _is_dragging_window:
			var current_mouse: Vector2 = get_viewport().get_mouse_position()
			var new_pos: Vector2 = _drag_start_win_pos + (current_mouse - _drag_start_mouse)
			var vp: Vector2 = get_viewport_rect().size
			new_pos.x = clampf(new_pos.x, 6.0, maxf(6.0, vp.x - _window_panel.size.x - 6.0))
			new_pos.y = clampf(new_pos.y, 6.0, maxf(6.0, vp.y - _window_panel.size.y - 6.0))
			_window_panel.position = new_pos
			_has_custom_window_pos = true
		if _tooltip_panel != null and _tooltip_panel.visible:
			_reposition_tooltip()


func _try_rotate_current_item() -> bool:
	if _held_item != null:
		if _held_item.toggle_rotation():
			_set_held_item(_held_item)
			var mpos: Vector2 = get_viewport().get_mouse_position()
			_held_preview.position = mpos - _held_preview.size * 0.5
			return true
		return false

	if _hovered_grid_item != null and inventory != null and inventory.items.has(_hovered_grid_item):
		var target: ItemInstance = _hovered_grid_item
		if not target.can_rotate():
			return false
		if inventory.rotate_item_in_place(target):
			_show_item_tooltip(target, false)
			return true
		else:
			# Se outros itens adjacentes bloquearem o giro no mesmo lugar, pega na mão já girado!
			inventory.remove_item(target)
			target.toggle_rotation()
			_set_held_item(target)
			return true
	return false


func _on_viewport_size_changed() -> void:
	if not _has_custom_window_pos and active_partner_station.is_empty():
		_center_window_on_screen()


func _center_window_on_screen() -> void:
	if _window_panel == null or not active_partner_station.is_empty():
		return
	var sz: Vector2 = get_window_size()
	var vp: Vector2 = get_viewport_rect().size
	if vp.x > 100.0 and vp.y > 100.0:
		_window_panel.position = Vector2(
			maxf(10.0, (vp.x - sz.x) * 0.5),
			maxf(10.0, (vp.y - sz.y) * 0.45)
		)


func _build_ui() -> void:
	# Moldura Principal Dourada Gótica
	_window_panel = PanelContainer.new()
	_window_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = BG_COLOR
	root_style.border_color = BORDER_COLOR
	root_style.set_border_width_all(3)
	root_style.set_corner_radius_all(8)
	root_style.shadow_color = Color(0, 0, 0, 0.82)
	root_style.shadow_size = 16
	root_style.content_margin_left = 18
	root_style.content_margin_right = 18
	root_style.content_margin_top = 12
	root_style.content_margin_bottom = 14
	_window_panel.add_theme_stylebox_override("panel", root_style)
	add_child(_window_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_window_panel.add_child(main_vbox)

	# 1. CABEÇALHO SUPERIOR CENTRALIZADO: "────── ❖ INVENTÁRIO ❖ ──────" + [X]
	_header_bar = HBoxContainer.new()
	_header_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_header_bar.gui_input.connect(_on_header_gui_input)

	_gold_header_label = Label.new()
	_gold_header_label.text = "🪙 %d" % current_gold
	_gold_header_label.custom_minimum_size = Vector2(72, 0)
	_gold_header_label.add_theme_font_size_override("font_size", 14)
	_gold_header_label.add_theme_color_override("font_color", Color(0.98, 0.84, 0.36))
	_gold_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_bar.add_child(_gold_header_label)

	var title := Label.new()
	title.text = "──────────  ❖   INVENTÁRIO   ❖  ──────────"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 17)
	title.add_theme_color_override("font_color", GOLD_COLOR)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_bar.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.custom_minimum_size = Vector2(30, 28)
	close_btn.add_theme_font_size_override("font_size", 14)
	close_btn.add_theme_color_override("font_color", GOLD_COLOR)
	close_btn.focus_mode = Control.FOCUS_NONE
	var x_style := _slot_style(Color(0.12, 0.10, 0.13, 0.95), BORDER_COLOR, 1)
	x_style.set_corner_radius_all(4)
	var x_hov := x_style.duplicate() as StyleBoxFlat
	x_hov.bg_color = Color(0.35, 0.12, 0.12, 0.95)
	close_btn.add_theme_stylebox_override("normal", x_style)
	close_btn.add_theme_stylebox_override("hover", x_hov)
	close_btn.add_theme_stylebox_override("pressed", x_hov)
	close_btn.pressed.connect(close_inventory)
	_header_bar.add_child(close_btn)
	main_vbox.add_child(_header_bar)

	var h_sep := HSeparator.new()
	h_sep.add_theme_color_override("separator", BORDER_SUBTLE)
	main_vbox.add_child(h_sep)

	# 2. CORPO DIVIDIDO: ESQUERDA (EQUIPAMENTO + STATUS BÁSICO) | DIREITA (MOCHILA 10 x 6)
	var body_hbox := HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 16)
	main_vbox.add_child(body_hbox)

	# ================= COLUNA ESQUERDA =================
	var left_vbox := VBoxContainer.new()
	left_vbox.custom_minimum_size = Vector2(252, 0)
	left_vbox.add_theme_constant_override("separation", 6)
	body_hbox.add_child(left_vbox)

	var doll_title := Label.new()
	doll_title.text = "────  ❖  EQUIPAMENTO  ❖  ────"
	doll_title.add_theme_font_size_override("font_size", 13)
	doll_title.add_theme_color_override("font_color", GOLD_COLOR)
	doll_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(doll_title)

	var doll_root := Control.new()
	doll_root.custom_minimum_size = Vector2(252, 298)
	left_vbox.add_child(doll_root)
	_build_paperdoll(doll_root)

	# Card de STATUS BÁSICO (Fiel à imagem de referência: placa superior + 2 colunas com divisórias)
	_build_basic_status_card(left_vbox)

	# Divisor Vertical Dourado
	var v_sep := VSeparator.new()
	body_hbox.add_child(v_sep)

	# ================= COLUNA DIREITA: MOCHILA (10 x 6) =================
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	body_hbox.add_child(right_vbox)

	_mochila_title_label = Label.new()
	_mochila_title_label.text = "🎒  MOCHILA (10 x 6)"
	_mochila_title_label.add_theme_font_size_override("font_size", 14)
	_mochila_title_label.add_theme_color_override("font_color", GOLD_COLOR)
	right_vbox.add_child(_mochila_title_label)

	var grid_frame := PanelContainer.new()
	var gf_style := _slot_style(Color(0.04, 0.035, 0.045, 0.98), BORDER_COLOR, 2)
	gf_style.set_corner_radius_all(4)
	gf_style.content_margin_left = 4
	gf_style.content_margin_right = 4
	gf_style.content_margin_top = 4
	gf_style.content_margin_bottom = 4
	grid_frame.add_theme_stylebox_override("panel", gf_style)
	right_vbox.add_child(grid_frame)

	_grid_container = Control.new()
	_grid_container.custom_minimum_size = Vector2(10 * CELL_SIZE, 6 * CELL_SIZE)
	_grid_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid_container.gui_input.connect(_on_grid_gui_input)
	grid_frame.add_child(_grid_container)

	_hint_label = Label.new()
	_hint_label.add_theme_font_size_override("font_size", 11)
	_hint_label.add_theme_color_override("font_color", Color(0.75, 0.70, 0.62))
	right_vbox.add_child(_hint_label)
	_update_hint_label()

	# Preview flutuante do item seguro na mão (top_level = true)
	_held_preview = TextureRect.new()
	_held_preview.top_level = true
	_held_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_preview.visible = false
	_held_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_held_preview.modulate = Color(1, 1, 1, 0.90)
	add_child(_held_preview)

	# Tooltip flutuante com comparação (top_level = true)
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.top_level = true
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 120
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.05, 0.045, 0.06, 0.98)
	t_style.border_color = GOLD_COLOR
	t_style.set_border_width_all(2)
	t_style.set_corner_radius_all(4)
	t_style.shadow_color = Color(0, 0, 0, 0.8)
	t_style.shadow_size = 10
	t_style.content_margin_left = 12
	t_style.content_margin_right = 12
	t_style.content_margin_top = 10
	t_style.content_margin_bottom = 10
	_tooltip_panel.add_theme_stylebox_override("panel", t_style)
	_tooltip_text = RichTextLabel.new()
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.fit_content = true
	_tooltip_text.custom_minimum_size = Vector2(280, 40)
	_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.add_child(_tooltip_text)
	add_child(_tooltip_panel)


func _build_basic_status_card(parent_vbox: VBoxContainer) -> void:
	# Placa de título "STATUS BÁSICO" emoldurada
	var header_badge := PanelContainer.new()
	var hb_style := StyleBoxFlat.new()
	hb_style.bg_color = Color(0.09, 0.075, 0.09, 0.98)
	hb_style.border_color = BORDER_COLOR
	hb_style.set_border_width_all(1)
	hb_style.set_corner_radius_all(4)
	hb_style.content_margin_left = 12
	hb_style.content_margin_right = 12
	hb_style.content_margin_top = 3
	hb_style.content_margin_bottom = 3
	header_badge.add_theme_stylebox_override("panel", hb_style)

	var badge_lbl := Label.new()
	badge_lbl.text = "❖   STATUS BÁSICO   ❖"
	badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge_lbl.add_theme_font_size_override("font_size", 12)
	badge_lbl.add_theme_color_override("font_color", GOLD_COLOR)
	header_badge.add_child(badge_lbl)
	parent_vbox.add_child(header_badge)

	# Quadro de Status em 2 Colunas (Vida/Dano/Crítico | Mana/Armadura/Velocidade)
	var stats_card := PanelContainer.new()
	var sc_style := StyleBoxFlat.new()
	sc_style.bg_color = PANEL_INNER_BG
	sc_style.border_color = BORDER_COLOR
	sc_style.set_border_width_all(1)
	sc_style.set_corner_radius_all(5)
	sc_style.content_margin_left = 10
	sc_style.content_margin_right = 10
	sc_style.content_margin_top = 8
	sc_style.content_margin_bottom = 8
	stats_card.add_theme_stylebox_override("panel", sc_style)
	parent_vbox.add_child(stats_card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 6)
	stats_card.add_child(card_vbox)

	var cols_hbox := HBoxContainer.new()
	cols_hbox.add_theme_constant_override("separation", 8)
	card_vbox.add_child(cols_hbox)

	# Coluna Esquerda: Vida, Dano, Crítico
	var col_left := VBoxContainer.new()
	col_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_left.add_theme_constant_override("separation", 4)
	cols_hbox.add_child(col_left)

	_stat_val_hp = _add_stat_row(col_left, "❤️", "Vida", "100")
	col_left.add_child(_make_thin_sep())
	_stat_val_dmg = _add_stat_row(col_left, "⚔️", "Dano", "14")
	col_left.add_child(_make_thin_sep())
	_stat_val_crit = _add_stat_row(col_left, "💥", "Crítico", "5%")

	# Divisor central vertical
	var mid_sep := VSeparator.new()
	cols_hbox.add_child(mid_sep)

	# Coluna Direita: Mana, Armadura, Velocidade
	var col_right := VBoxContainer.new()
	col_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col_right.add_theme_constant_override("separation", 4)
	cols_hbox.add_child(col_right)

	_stat_val_mana = _add_stat_row(col_right, "💧", "Mana", "50")
	col_right.add_child(_make_thin_sep())
	_stat_val_armor = _add_stat_row(col_right, "🛡️", "Armadura", "12")
	col_right.add_child(_make_thin_sep())
	_stat_val_speed = _add_stat_row(col_right, "👟", "Velocidade", "6.2 m/s")

	card_vbox.add_child(_make_thin_sep())

	# Linha compacta de Atributos (Força / Agilidade / Inteligência)
	_stat_attributes_footer = Label.new()
	_stat_attributes_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stat_attributes_footer.add_theme_font_size_override("font_size", 11)
	_stat_attributes_footer.add_theme_color_override("font_color", Color(0.84, 0.76, 0.62))
	card_vbox.add_child(_stat_attributes_footer)


func _add_stat_row(parent_col: VBoxContainer, icon_str: String, label_str: String, default_val: String) -> Label:
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 4)

	var ic := Label.new()
	ic.text = icon_str
	ic.add_theme_font_size_override("font_size", 11)
	hb.add_child(ic)

	var nm := Label.new()
	nm.text = label_str
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.add_theme_font_size_override("font_size", 11)
	nm.add_theme_color_override("font_color", Color(0.80, 0.76, 0.68))
	hb.add_child(nm)

	var val := Label.new()
	val.text = default_val
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.add_theme_font_size_override("font_size", 12)
	val.add_theme_color_override("font_color", Color(0.98, 0.96, 0.92))
	hb.add_child(val)

	parent_col.add_child(hb)
	return val


func _make_thin_sep() -> HSeparator:
	var s := HSeparator.new()
	s.add_theme_constant_override("separation", 2)
	return s


func _update_hint_label() -> void:
	if _hint_label == null:
		return
	match active_partner_station:
		"stash":
			_hint_label.text = "• [Clique Direito na Mochila]: Guardar no Baú  |  [Tecla R]: Girar Item (Deitado ↔ Em Pé)\n• Passe o mouse para comparar atributos com o item equipado (▲ verde / ▼ vermelho)"
			_hint_label.add_theme_color_override("font_color", Color(0.68, 0.92, 0.72))
		"vendor_physical", "vendor_magic":
			_hint_label.text = "• [Clique Direito na Mochila]: Vender por 🪙 Ouro (vai para Recomprar)  |  [Tecla R]: Girar Item\n• Passe o mouse sobre um item para comparar com seu equipamento atual"
			_hint_label.add_theme_color_override("font_color", Color(0.95, 0.85, 0.48))
		_:
			_hint_label.text = "• [Clique Esquerdo]: Mover/Equipar  |  [Clique Direito]: Equipar / Beber  |  [Tecla R]: Girar Item\n• Passe o mouse para comparar atributos (▲ ganha em verde / ▼ perde em vermelho)"
			_hint_label.add_theme_color_override("font_color", Color(0.72, 0.68, 0.60))


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging_window = true
			_drag_start_mouse = get_viewport().get_mouse_position()
			_drag_start_win_pos = _window_panel.position
		else:
			_is_dragging_window = false


# ===============================================================
# PAPERDOLL EM CRUZ FIEL À IMAGEM DE REFERÊNCIA + SILHUETAS
# ===============================================================
func _build_paperdoll(root: Control) -> void:
	# Coluna Central: Elmo -> Peitoral -> Cinto -> Botas
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.HELMET, "Elmo", Vector2(88, 2), Vector2(76, 68))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.CHEST, "Peitoral", Vector2(88, 76), Vector2(76, 94))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.BELT, "Cinto", Vector2(88, 176), Vector2(76, 48))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.BOOTS, "Botas", Vector2(88, 230), Vector2(76, 66))

	# Ala Esquerda: Luvas -> Mão Principal -> Anel 1
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.GLOVES, "Luvas", Vector2(16, 12), Vector2(64, 58))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.MAIN_HAND, "Mão\nPrincipal", Vector2(6, 76), Vector2(74, 94))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.RING_1, "Anel 1", Vector2(20, 176), Vector2(60, 48))

	# Ala Direita: Colar -> Mão Secundária -> Anel 2
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.AMULET, "Colar", Vector2(172, 12), Vector2(64, 58))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.OFF_HAND, "Mão\nSecundária", Vector2(172, 76), Vector2(74, 94))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.RING_2, "Anel 2", Vector2(172, 176), Vector2(60, 48))


func _create_doll_slot(parent: Control, slot: ItemDefinition.EquipmentSlot, label_txt: String, pos: Vector2, sz_px: Vector2) -> void:
	var slot_panel := Panel.new()
	slot_panel.position = pos
	slot_panel.size = sz_px
	var st := _slot_style(Color(0.095, 0.082, 0.10, 0.96), BORDER_COLOR, 1)
	st.set_corner_radius_all(5)
	slot_panel.add_theme_stylebox_override("panel", st)
	slot_panel.gui_input.connect(func(ev: InputEvent) -> void: _on_doll_slot_input(slot, ev))
	slot_panel.mouse_entered.connect(func() -> void: _on_doll_slot_hover(slot, true))
	slot_panel.mouse_exited.connect(func() -> void: _on_doll_slot_hover(slot, false))
	parent.add_child(slot_panel)

	# Silhueta procedural do slot quando vazio
	var sil := TextureRect.new()
	sil.name = "Silhouette"
	sil.texture = _get_or_build_silhouette(slot)
	sil.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sil.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sil.position = Vector2(6, 4)
	sil.size = Vector2(sz_px.x - 12.0, maxf(18.0, sz_px.y - 22.0))
	sil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_child(sil)

	# Texto da base do slot ("Elmo", "Colar", "Mão Principal", etc.)
	var lbl := Label.new()
	lbl.name = "Placeholder"
	lbl.text = label_txt
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", MUTED_LABEL)
	lbl.position = Vector2(2, sz_px.y - (26.0 if label_txt.contains("\n") else 17.0))
	lbl.size = Vector2(sz_px.x - 4.0, 26.0 if label_txt.contains("\n") else 16.0)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.add_theme_constant_override("line_spacing", -3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_child(lbl)

	# Ícone do item equipado
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.position = Vector2(4, 4)
	icon.size = Vector2(sz_px.x - 8.0, sz_px.y - 8.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.visible = false
	slot_panel.add_child(icon)

	_paperdoll_slots[slot] = slot_panel


func _get_or_build_silhouette(slot: ItemDefinition.EquipmentSlot) -> Texture2D:
	if _silhouette_cache.has(slot):
		return _silhouette_cache[slot] as Texture2D

	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(0.42, 0.35, 0.29, 0.82)
	var dark := Color(0.08, 0.07, 0.08, 0.95)

	match slot:
		ItemDefinition.EquipmentSlot.HELMET:
			# Elmo medieval com abertura em T
			for y in range(8, 38):
				for x in range(12, 36):
					var dx: float = float(x - 24)
					var dy: float = float(y - 20)
					if y < 22 and (dx * dx + dy * dy) > 144.0:
						continue
					img.set_pixel(x, y, col)
			for x in range(16, 32):
				for y in range(20, 24):
					img.set_pixel(x, y, dark)
			for y in range(20, 35):
				for x in range(22, 26):
					img.set_pixel(x, y, dark)

		ItemDefinition.EquipmentSlot.AMULET:
			# Corrente em V + medalhão redondo
			for i in range(16):
				img.set_pixel(11 + i, 8 + i, col)
				img.set_pixel(12 + i, 8 + i, col)
				img.set_pixel(36 - i, 8 + i, col)
				img.set_pixel(35 - i, 8 + i, col)
			for y in range(22, 38):
				for x in range(16, 32):
					var d: float = Vector2(x - 24, y - 30).length()
					if d <= 6.5:
						img.set_pixel(x, y, col)

		ItemDefinition.EquipmentSlot.MAIN_HAND:
			# Espada inclinada na diagonal
			for i in range(28):
				var bx: int = 12 + i
				var by: int = 36 - i
				for ox in range(-2, 3):
					for oy in range(-2, 3):
						if abs(ox + oy) <= 2:
							img.set_pixel(clampi(bx + ox, 0, 47), clampi(by + oy, 0, 47), col)
			# Guarda (crossguard)
			for g in range(-7, 8):
				img.set_pixel(clampi(17 + g, 0, 47), clampi(31 + g, 0, 47), col)
				img.set_pixel(clampi(18 + g, 0, 47), clampi(31 + g, 0, 47), col)

		ItemDefinition.EquipmentSlot.CHEST:
			# Couraça / Peitoral com ombreiras
			for y in range(8, 40):
				var half_w: int = 16 if y < 18 else (12 if y < 30 else 10)
				for x in range(24 - half_w, 24 + half_w):
					if y < 14 and abs(x - 24) < 5:
						continue
					img.set_pixel(x, y, col)

		ItemDefinition.EquipmentSlot.OFF_HAND:
			# Escudo Heater clássico
			for y in range(8, 40):
				var t_prog: float = float(y - 8) / 32.0
				var half_w: int = int(roundi(13.0 * (1.0 - t_prog * t_prog * 0.85)))
				for x in range(24 - half_w, 24 + half_w):
					img.set_pixel(x, y, col)

		ItemDefinition.EquipmentSlot.RING_1, ItemDefinition.EquipmentSlot.RING_2:
			# Anel circular com pedra no topo
			for y in range(10, 40):
				for x in range(10, 38):
					var d: float = Vector2(x - 24, y - 26).length()
					if d >= 7.5 and d <= 11.5:
						img.set_pixel(x, y, col)
			for y in range(10, 17):
				for x in range(20, 28):
					img.set_pixel(x, y, col.lightened(0.15))

		ItemDefinition.EquipmentSlot.BELT:
			# Cinto horizontal com fivela central
			for y in range(19, 29):
				for x in range(6, 42):
					img.set_pixel(x, y, col)
			for y in range(16, 32):
				for x in range(18, 30):
					if x < 21 or x > 27 or y < 19 or y > 29:
						img.set_pixel(x, y, col.lightened(0.18))
					else:
						img.set_pixel(x, y, dark)

		ItemDefinition.EquipmentSlot.BOOTS:
			# Par de botas lado a lado
			for y in range(8, 38):
				for x in range(10, 21):
					if y > 28 or x >= 13:
						img.set_pixel(x, y, col)
				for x in range(27, 38):
					if y > 28 or x <= 34:
						img.set_pixel(x, y, col)

		ItemDefinition.EquipmentSlot.GLOVES:
			# Par de manoplas
			for y in range(12, 36):
				for x in range(10, 22):
					img.set_pixel(x, y, col)
				for x in range(26, 38):
					img.set_pixel(x, y, col)

	var tex := ImageTexture.create_from_image(img)
	_silhouette_cache[slot] = tex
	return tex


func _process(delta: float) -> void:
	if _warning_timer > 0.0:
		_warning_timer -= delta
		if _warning_timer <= 0.0:
			_update_hint_label()
	if not visible:
		return
	if _held_item != null and _held_preview != null and _held_preview.visible:
		var mpos: Vector2 = get_viewport().get_mouse_position()
		_held_preview.position = mpos - _held_preview.size * 0.5


func show_inventory_warning(msg: String) -> void:
	if _hint_label != null:
		_hint_label.text = msg
		_hint_label.add_theme_color_override("font_color", Color(1.0, 0.42, 0.42))
		_warning_timer = 4.0


var _grid_dirty: bool = true


func _refresh_all() -> void:
	_grid_dirty = false
	_refresh_grid_view(true)
	_refresh_paperdoll_view()
	_refresh_stats_view()


func _get_item_slot_bg_color(item: ItemInstance) -> Color:
	match item.rarity:
		ItemInstance.ItemRarity.MAGIC:
			return Color(0.13, 0.14, 0.25, 0.96)
		ItemInstance.ItemRarity.RARE:
			return Color(0.24, 0.18, 0.10, 0.96)
		ItemInstance.ItemRarity.UNIQUE:
			return Color(0.26, 0.11, 0.11, 0.96)
		_:
			return Color(0.17, 0.12, 0.22, 0.95)


func _refresh_grid_view(force: bool = false) -> void:
	if _grid_container == null or inventory == null:
		return
	if _mochila_title_label != null:
		_mochila_title_label.text = "🎒  MOCHILA (%d x %d)" % [inventory.columns, inventory.rows]
	_grid_container.custom_minimum_size = Vector2(inventory.columns * CELL_SIZE, inventory.rows * CELL_SIZE)
	if not visible and not force:
		_grid_dirty = true
		return
	_grid_dirty = false
	for child in _grid_container.get_children():
		child.queue_free()

	# 1. Desenha as células de fundo (10 colunas x 6 linhas)
	for y in range(inventory.rows):
		for x in range(inventory.columns):
			var cell := Panel.new()
			cell.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.add_theme_stylebox_override("panel", _slot_style(Color(0.06, 0.052, 0.068, 0.92), Color(0.28, 0.22, 0.15, 0.72), 1))
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_grid_container.add_child(cell)

	# 2. Desenha os itens ocupando suas dimensões (W x H) com fundo colorido rico igual à referência
	for item in inventory.items:
		if item == null or item.definition == null:
			continue
		var eff_size: Vector2i = item.get_grid_size()
		var pos_px: Vector2 = Vector2(item.grid_position.x * CELL_SIZE, item.grid_position.y * CELL_SIZE)
		var size_px: Vector2 = Vector2(eff_size.x * CELL_SIZE, eff_size.y * CELL_SIZE)

		var item_panel := Panel.new()
		item_panel.position = pos_px + Vector2(1, 1)
		item_panel.size = size_px - Vector2(2, 2)
		var border_col: Color = item.get_rarity_color()
		var bg_col: Color = _get_item_slot_bg_color(item)
		if stats != null and not item.meets_requirements(stats):
			border_col = RED_ALERT
			bg_col = Color(0.25, 0.08, 0.09, 0.96)
		var item_st := _slot_style(bg_col, border_col, 2)
		item_st.set_corner_radius_all(4)
		item_panel.add_theme_stylebox_override("panel", item_st)
		item_panel.gui_input.connect(func(ev: InputEvent) -> void: _on_item_panel_input(item, ev))
		item_panel.mouse_entered.connect(func() -> void:
			_hovered_grid_item = item
			_show_item_tooltip(item, false)
		)
		item_panel.mouse_exited.connect(func() -> void:
			if _hovered_grid_item == item:
				_hovered_grid_item = null
			_hide_tooltip()
		)
		_grid_container.add_child(item_panel)

		var icon := TextureRect.new()
		icon.texture = ItemIconFactory.get_icon_for_item(item, false)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(3, 3)
		icon.size = item_panel.size - Vector2(6, 6)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_panel.add_child(icon)


func _refresh_paperdoll_view() -> void:
	if equipment == null:
		return
	for slot_key in _paperdoll_slots.keys():
		var slot_panel: Panel = _paperdoll_slots[slot_key]
		var item: ItemInstance = equipment.get_equipped_item(slot_key)
		var icon: TextureRect = slot_panel.get_node("Icon") as TextureRect
		var lbl: Label = slot_panel.get_node("Placeholder") as Label
		var sil: TextureRect = slot_panel.get_node("Silhouette") as TextureRect
		if item != null and item.definition != null:
			icon.texture = ItemIconFactory.get_icon_for_item(item, true)
			icon.visible = true
			lbl.visible = false
			sil.visible = false
			var border_col: Color = item.get_rarity_color()
			var bg_col: Color = _get_item_slot_bg_color(item)
			if stats != null and not item.meets_requirements(stats):
				border_col = RED_ALERT
			var eq_st := _slot_style(bg_col, border_col, 2)
			eq_st.set_corner_radius_all(5)
			slot_panel.add_theme_stylebox_override("panel", eq_st)
		else:
			icon.texture = null
			icon.visible = false
			lbl.visible = true
			sil.visible = true
			var empty_st := _slot_style(Color(0.095, 0.082, 0.10, 0.96), BORDER_COLOR, 1)
			empty_st.set_corner_radius_all(5)
			slot_panel.add_theme_stylebox_override("panel", empty_st)


func _refresh_stats_view() -> void:
	if _gold_header_label != null:
		_gold_header_label.text = "🪙 %d" % current_gold
	if stats == null:
		return
	var hp: int = stats.get_max_health()
	var dmg: int = stats.get_damage()
	var armor: int = int(roundi(stats.get_stat(&"armor")))
	var mov_spd: float = stats.get_stat(&"move_speed")
	var crit_c: int = int(roundi(stats.get_stat(&"crit_chance") * 100.0))
	var str_val: int = int(roundi(stats.get_stat(&"strength")))
	var agi_val: int = int(roundi(stats.get_stat(&"agility")))
	var int_val: int = int(roundi(stats.get_stat(&"intelligence")))
	var mana_val: int = 30 + int_val * 2

	if _stat_val_hp != null:
		_stat_val_hp.text = "%d" % hp
	if _stat_val_dmg != null:
		_stat_val_dmg.text = "%d" % dmg
	if _stat_val_crit != null:
		_stat_val_crit.text = "%d%%" % crit_c
	if _stat_val_mana != null:
		_stat_val_mana.text = "%d" % mana_val
	if _stat_val_armor != null:
		_stat_val_armor.text = "%d" % armor
	if _stat_val_speed != null:
		_stat_val_speed.text = "%.1f m/s" % mov_spd
	if _stat_attributes_footer != null:
		_stat_attributes_footer.text = "Força: %d   •   Agil.: %d   •   Int.: %d" % [str_val, agi_val, int_val]


# --- INTERAÇÃO COM O MOUSE ---
func _format_no_space_warning(displaced: Array[ItemInstance]) -> String:
	if displaced.is_empty():
		return "⚠ Sem espaço suficiente na mochila para realizar esta troca!"
	if displaced.size() == 1:
		var d0: ItemInstance = displaced[0]
		var sz: Vector2i = d0.get_grid_size()
		return "⚠ Sem espaço livre na mochila (%dx%d) para guardar o item equipado: %s!" % [sz.x, sz.y, d0.get_display_name()]
	var names: PackedStringArray = PackedStringArray()
	for d in displaced:
		if d != null:
			var sz: Vector2i = d.get_grid_size()
			names.append("%s (%dx%d)" % [d.get_display_name(), sz.x, sz.y])
	return "⚠ Sem espaço livre na mochila para guardar os itens equipados: %s!" % ", ".join(names)


func _on_grid_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var cell := Vector2i(int(mb.position.x / CELL_SIZE), int(mb.position.y / CELL_SIZE))
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _held_item != null:
				if inventory.can_place_at(_held_item, cell):
					inventory.place_item(_held_item, cell)
					_set_held_item(null)
					_refresh_all()
			else:
				var clicked: ItemInstance = inventory.get_item_at(cell)
				if clicked != null:
					_held_origin_pos = clicked.grid_position
					_held_origin_rotated = clicked.is_rotated
					_held_origin_slot = ItemDefinition.EquipmentSlot.NONE
					inventory.remove_item(clicked)
					_set_held_item(clicked)


func _on_item_panel_input(item: ItemInstance, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _held_item == null:
				_held_origin_pos = item.grid_position
				_held_origin_rotated = item.is_rotated
				_held_origin_slot = ItemDefinition.EquipmentSlot.NONE
				inventory.remove_item(item)
				_set_held_item(item)
			else:
				var prev_held: ItemInstance = _held_item
				var item_orig_pos: Vector2i = item.grid_position
				var item_orig_rot: bool = item.is_rotated
				inventory.remove_item(item)
				if inventory.can_place_at(prev_held, item_orig_pos):
					inventory.place_item(prev_held, item_orig_pos)
					_held_origin_pos = item_orig_pos
					_held_origin_rotated = item_orig_rot
					_held_origin_slot = ItemDefinition.EquipmentSlot.NONE
					_set_held_item(item)
					_refresh_all()
				else:
					item.is_rotated = item_orig_rot
					inventory.place_item(item, item_orig_pos)
					show_inventory_warning("⚠ %s (%dx%d) não cabe no espaço de %s!" % [prev_held.get_display_name(), prev_held.get_grid_size().x, prev_held.get_grid_size().y, item.get_display_name()])
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if _held_item != null:
				return
			_hide_tooltip()
			if active_partner_station == "stash" or active_partner_station == "vendor_physical" or active_partner_station == "vendor_magic":
				item_context_action_requested.emit(item)
				return

			if item.definition.category == ItemDefinition.ItemCategory.CONSUMABLE:
				var heal_val: int = maxi(25, item.definition.base_health)
				inventory.remove_item(item)
				potion_consumed.emit(heal_val)
				_refresh_all()
				return

			if item.definition.is_equippable():
				var target_slot: ItemDefinition.EquipmentSlot = item.definition.equip_slot
				if target_slot == ItemDefinition.EquipmentSlot.RING_1 and equipment.get_equipped_item(ItemDefinition.EquipmentSlot.RING_1) != null and equipment.get_equipped_item(ItemDefinition.EquipmentSlot.RING_2) == null:
					target_slot = ItemDefinition.EquipmentSlot.RING_2
				var res: Dictionary = equipment.try_equip_from_inventory(item, target_slot, inventory, stats)
				if not bool(res.get("ok", false)):
					var reason: String = String(res.get("reason", ""))
					if reason == "no_space":
						var disp_arr: Array[ItemInstance] = []
						for d in res.get("displaced", []):
							if d is ItemInstance:
								disp_arr.append(d)
						show_inventory_warning(_format_no_space_warning(disp_arr))
					elif reason == "requirements":
						show_inventory_warning("⚠ Você não cumpre os requisitos de atributos para equipar %s!" % item.get_display_name())
				_refresh_all()


func _on_doll_slot_input(slot: ItemDefinition.EquipmentSlot, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var equipped_item: ItemInstance = equipment.get_equipped_item(slot)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _held_item != null:
				var res: Dictionary = equipment.try_equip_from_inventory(_held_item, slot, inventory, stats, _held_origin_pos)
				if bool(res.get("ok", false)):
					_set_held_item(null)
					_refresh_all()
				else:
					var reason: String = String(res.get("reason", ""))
					if reason == "no_space":
						var disp_arr: Array[ItemInstance] = []
						for d in res.get("displaced", []):
							if d is ItemInstance:
								disp_arr.append(d)
						show_inventory_warning(_format_no_space_warning(disp_arr))
					elif reason == "requirements":
						show_inventory_warning("⚠ Você não cumpre os requisitos de atributos para equipar %s!" % _held_item.get_display_name())
					else:
						show_inventory_warning("⚠ %s não pode ser equipado neste slot!" % _held_item.get_display_name())
			elif equipped_item != null:
				if inventory != null and not inventory.can_fit_item(equipped_item):
					var sz: Vector2i = equipped_item.get_grid_size()
					show_inventory_warning("⚠ Sem espaço livre na mochila (%dx%d) para desequipar %s!" % [sz.x, sz.y, equipped_item.get_display_name()])
					return
				_held_origin_slot = slot
				_held_origin_pos = Vector2i(-1, -1)
				_held_origin_rotated = equipped_item.is_rotated
				equipment.unequip_item(slot, stats)
				_set_held_item(equipped_item)
				_refresh_all()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if _held_item != null:
				return
			if equipped_item != null:
				_hide_tooltip()
				if inventory == null or not inventory.can_fit_item(equipped_item):
					var sz: Vector2i = equipped_item.get_grid_size()
					show_inventory_warning("⚠ Sem espaço livre na mochila (%dx%d) para desequipar %s!" % [sz.x, sz.y, equipped_item.get_display_name()])
					return
				equipment.unequip_item(slot, stats)
				inventory.auto_add_item(equipped_item)
				_refresh_all()


func _on_doll_slot_hover(slot: ItemDefinition.EquipmentSlot, entered: bool) -> void:
	if entered:
		var item: ItemInstance = equipment.get_equipped_item(slot)
		if item != null:
			_show_item_tooltip(item, true)
	else:
		_hide_tooltip()


func _set_held_item(item: ItemInstance) -> void:
	_held_item = item
	if _held_item != null and _held_item.definition != null:
		var eff_sz: Vector2i = _held_item.get_grid_size()
		_held_preview.texture = ItemIconFactory.get_icon_for_item(_held_item, false)
		var exact_w: float = float(eff_sz.x) * float(CELL_SIZE)
		var exact_h: float = float(eff_sz.y) * float(CELL_SIZE)
		_held_preview.custom_minimum_size = Vector2(exact_w, exact_h)
		_held_preview.size = Vector2(exact_w, exact_h)
		_held_preview.visible = true
	else:
		_held_preview.texture = null
		_held_preview.visible = false
	_hide_tooltip()


func _on_equipment_changed(_slot: ItemDefinition.EquipmentSlot, _item: ItemInstance) -> void:
	_refresh_paperdoll_view()
	_refresh_stats_view()


func _show_item_tooltip(item: ItemInstance, is_on_paperdoll: bool = false) -> void:
	if item == null or item.definition == null or _held_item != null:
		_hide_tooltip()
		return

	var action_hint: String = ""
	if is_on_paperdoll:
		action_hint = "[Clique Direito: Desequipar para a Mochila]"
	else:
		match active_partner_station:
			"stash":
				action_hint = "[Clique Direito: Guardar no Baú Pessoal]"
			"vendor_physical", "vendor_magic":
				action_hint = "[Clique Direito: Vender por %d Ouro]" % item.get_sell_value()
			_:
				if item.definition.category == ItemDefinition.ItemCategory.CONSUMABLE:
					action_hint = "[Clique Direito: Beber Poção (+%d Vida)]" % maxi(25, item.definition.base_health)
				elif item.definition.is_equippable():
					action_hint = "[Clique Direito: Equipar Item]"
		if item.can_rotate():
			var cur_sz: Vector2i = item.get_grid_size()
			action_hint += "\n[color=#e8c56b][Tecla R: Girar Item (%dx%d ↔ %dx%d)][/color]" % [cur_sz.x, cur_sz.y, cur_sz.y, cur_sz.x]

	_tooltip_text.text = item.format_tooltip_bbcode(stats, equipment, action_hint)
	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()
	_reposition_tooltip()


func _reposition_tooltip() -> void:
	if _tooltip_panel == null or not _tooltip_panel.visible:
		return
	var mp: Vector2 = get_viewport().get_mouse_position()
	var vp: Vector2 = get_viewport_rect().size
	var sz: Vector2 = _tooltip_panel.size
	var tx: float = mp.x + 18.0
	if tx + sz.x + 8.0 > vp.x:
		tx = maxf(8.0, mp.x - sz.x - 14.0)
	var ty: float = clampf(mp.y + 14.0, 8.0, maxf(8.0, vp.y - sz.y - 8.0))
	_tooltip_panel.position = Vector2(tx, ty)


func _hide_tooltip() -> void:
	if _tooltip_panel != null:
		_tooltip_panel.visible = false


func _slot_style(bg: Color, border: Color, bw: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(2)
	return s
