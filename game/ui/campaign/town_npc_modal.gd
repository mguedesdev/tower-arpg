extends Control
class_name TownNpcModal
## Modal Gótico Dark-Fantasy (estilo Diablo 2 / Path of Exile) para os NPCs e Baú da Vila:
## • Funciona centralizado quando aberto sozinho, ou lado a lado (esquerda) com o Inventário (direita)!
## • Baú Pessoal (Stash) com Grid Espacial real 10x6.
## • Ferreiro & Arcanista com estoque real de itens, compra/venda por Ouro e Tooltip comparativo (▲ verde / ▼ vermelho).
## • Sábio com Identificação real, Cura Completa e Reset de Atributos.

signal opened(station_id: String)
signal closed()
signal waypoint_travel_requested(zone_id: String)
signal respec_build_requested()
signal identify_items_requested()
signal heal_player_requested()
signal gold_changed(new_gold: int)

const COLOR_BG := Color(0.045, 0.04, 0.05, 0.97)
const COLOR_BRONZE_BORDER := Color(0.55, 0.43, 0.24, 0.96)
const COLOR_GOLD_TITLE := Color(0.94, 0.78, 0.38)
const COLOR_PARCHMENT := Color(0.88, 0.84, 0.76)
const COLOR_MUTED := Color(0.64, 0.60, 0.54)
const RED_ALERT := Color(1.0, 0.35, 0.35)
const CELL_SIZE := 36

var backpack: SpatialInventoryGrid
var stash: SpatialInventoryGrid
var equipment: CharacterEquipment
var stats: CharacterStats
var current_gold: int = 150
var area_level: int = 1

var current_station_id: String = ""
var _unlocked_zones: Array[String] = ["town", "zone_1_road"]
var _current_zone_id: String = "town"

var _blacksmith_stock: Array[ItemInstance] = []
var _arcanist_stock: Array[ItemInstance] = []
var _buyback_items: Array[Dictionary] = []   ## Array de {"item": ItemInstance, "price": int}
var _active_vendor_tab: int = 0              ## 0 = Comprar, 1 = Recomprar

# Janela móvel / acoplável
var _window_panel: PanelContainer
var _header_bar: HBoxContainer
var _gold_header_label: Label
var _title_label: Label
var _subtitle_label: Label
var _content_box: VBoxContainer
var _feedback_label: Label
var _stash_grid_container: Control

var _is_dragging_window: bool = false
var _drag_start_mouse: Vector2 = Vector2.ZERO
var _drag_start_win_pos: Vector2 = Vector2.ZERO
var _has_custom_window_pos: bool = false

# Tooltip flutuante com comparação
var _tooltip_panel: PanelContainer
var _tooltip_text: RichTextLabel


func _ready() -> void:
	name = "TownNpcModal"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_size_changed)


func bind_context(p_backpack: SpatialInventoryGrid, p_stash: SpatialInventoryGrid, p_equip: CharacterEquipment, p_stats: CharacterStats) -> void:
	if backpack != null and backpack.grid_changed.is_connected(_on_inventories_changed):
		backpack.grid_changed.disconnect(_on_inventories_changed)
	if stash != null and stash.grid_changed.is_connected(_on_inventories_changed):
		stash.grid_changed.disconnect(_on_inventories_changed)
	if equipment != null and equipment.equipment_changed.is_connected(_on_equipment_changed):
		equipment.equipment_changed.disconnect(_on_equipment_changed)

	backpack = p_backpack
	stash = p_stash
	equipment = p_equip
	stats = p_stats

	if backpack != null:
		backpack.grid_changed.connect(_on_inventories_changed)
	if stash != null:
		stash.grid_changed.connect(_on_inventories_changed)
	if equipment != null:
		equipment.equipment_changed.connect(_on_equipment_changed)


func set_gold(gold_val: int) -> void:
	current_gold = maxi(0, gold_val)
	if _gold_header_label != null:
		_gold_header_label.text = "🪙 %d Ouro" % current_gold
	if visible and (current_station_id == "vendor_physical" or current_station_id == "vendor_magic"):
		_refresh_current_station_content()


func show_feedback(msg: String, is_error: bool = false) -> void:
	if _feedback_label == null:
		return
	_feedback_label.text = msg
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45) if is_error else Color(0.52, 0.94, 0.62))


func get_window_size() -> Vector2:
	if _window_panel == null:
		return Vector2(540, 520)
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


func center_on_screen() -> void:
	if _window_panel == null:
		return
	var sz: Vector2 = get_window_size()
	var vp: Vector2 = get_viewport_rect().size
	if vp.x > 100.0 and vp.y > 100.0:
		_window_panel.position = Vector2(
			maxf(10.0, (vp.x - sz.x) * 0.5),
			maxf(10.0, (vp.y - sz.y) * 0.45)
		)


func _on_viewport_size_changed() -> void:
	if visible and not _has_custom_window_pos:
		center_on_screen()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close_modal()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging_window = false
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


func _build_ui() -> void:
	_window_panel = PanelContainer.new()
	_window_panel.custom_minimum_size = Vector2(540, 510)
	_window_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = COLOR_BRONZE_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.78)
	style.shadow_size = 14
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	_window_panel.add_theme_stylebox_override("panel", style)
	add_child(_window_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	_window_panel.add_child(root_vbox)

	# Barra superior arrastável
	_header_bar = HBoxContainer.new()
	_header_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_header_bar.gui_input.connect(_on_header_gui_input)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 15)
	_title_label.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_bar.add_child(_title_label)
	_header_bar.add_spacer(false)

	_gold_header_label = Label.new()
	_gold_header_label.text = "🪙 %d Ouro" % current_gold
	_gold_header_label.add_theme_font_size_override("font_size", 14)
	_gold_header_label.add_theme_color_override("font_color", Color(0.98, 0.85, 0.38))
	_gold_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_bar.add_child(_gold_header_label)

	var sp := Control.new()
	sp.custom_minimum_size = Vector2(8, 0)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_bar.add_child(sp)

	var close_top_btn := Button.new()
	close_top_btn.text = " [X] "
	close_top_btn.add_theme_font_size_override("font_size", 13)
	close_top_btn.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	close_top_btn.focus_mode = Control.FOCUS_NONE
	close_top_btn.pressed.connect(close_modal)
	_header_bar.add_child(close_top_btn)
	root_vbox.add_child(_header_bar)

	var sep_top := HSeparator.new()
	root_vbox.add_child(sep_top)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", 12)
	_subtitle_label.add_theme_color_override("font_color", COLOR_MUTED)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_subtitle_label)

	_content_box = VBoxContainer.new()
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 8)
	root_vbox.add_child(_content_box)

	_feedback_label = Label.new()
	_feedback_label.add_theme_font_size_override("font_size", 13)
	_feedback_label.add_theme_color_override("font_color", Color(0.56, 0.90, 0.62))
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_feedback_label)

	var close_btn := _make_gothic_button("FECHAR JANELA (ESC / E)", false)
	close_btn.custom_minimum_size = Vector2(0, 34)
	close_btn.pressed.connect(close_modal)
	root_vbox.add_child(close_btn)

	# Tooltip flutuante com comparação (top_level = true)
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.top_level = true
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	_tooltip_panel.z_index = 125
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.05, 0.045, 0.06, 0.98)
	t_style.border_color = COLOR_GOLD_TITLE
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


func _on_header_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_is_dragging_window = true
			_drag_start_mouse = get_viewport().get_mouse_position()
			_drag_start_win_pos = _window_panel.position
		else:
			_is_dragging_window = false


func _ensure_vendor_stocks() -> void:
	if _blacksmith_stock.is_empty():
		_blacksmith_stock = ItemDatabase.generate_blacksmith_stock(maxi(1, area_level))
	if _arcanist_stock.is_empty():
		_arcanist_stock = ItemDatabase.generate_arcanist_stock(maxi(1, area_level))


func open_station(station_id: String, unlocked_zones: Array[String], current_zone: String, p_area_level: int = 1) -> void:
	current_station_id = station_id
	_unlocked_zones = unlocked_zones
	_current_zone_id = current_zone
	area_level = maxi(1, p_area_level)
	_active_vendor_tab = 0
	_has_custom_window_pos = false
	_ensure_vendor_stocks()
	_feedback_label.text = ""
	if _gold_header_label != null:
		_gold_header_label.text = "🪙 %d Ouro" % current_gold

	_refresh_current_station_content()
	visible = true
	opened.emit(station_id)


func register_sold_item(item: ItemInstance, sold_price: int) -> void:
	if item == null:
		return
	_buyback_items.push_front({
		"item": item,
		"price": maxi(1, sold_price)
	})
	if _buyback_items.size() > 24:
		_buyback_items.resize(24)
	if visible and (current_station_id == "vendor_physical" or current_station_id == "vendor_magic"):
		_refresh_current_station_content()


func close_modal() -> void:
	if not visible:
		return
	visible = false
	_is_dragging_window = false
	_hide_tooltip()
	closed.emit()


func _on_inventories_changed() -> void:
	if not visible:
		return
	if current_station_id == "stash" and _stash_grid_container != null:
		_rebuild_stash_cells()
	elif current_station_id == "identifier_respec":
		_refresh_current_station_content()


func _on_equipment_changed(_slot: ItemDefinition.EquipmentSlot, _item: ItemInstance) -> void:
	if visible and current_station_id == "stash" and _stash_grid_container != null:
		_rebuild_stash_cells()


func _refresh_current_station_content() -> void:
	_hide_tooltip()
	_stash_grid_container = null
	for child in _content_box.get_children():
		child.queue_free()

	match current_station_id:
		"stash":
			_populate_stash()
		"vendor_physical":
			_populate_vendor_physical()
		"vendor_magic":
			_populate_vendor_magic()
		"identifier_respec":
			_populate_identifier_respec()
		"waypoint":
			_populate_waypoint()


# ===============================================================
# 1. BAÚ PESSOAL (STASH) — GRID ESPACIAL REAL 10x6
# ===============================================================
func _populate_stash() -> void:
	_title_label.text = "📦 BAÚ PESSOAL (STASH 10x6)"
	_subtitle_label.text = "Guarde armas, armaduras e relíquias. Clique em um item do Baú para retirar para a Mochila, ou clique com o Botão Direito na Mochila (ao lado) para guardar aqui!"

	var center_grid := CenterContainer.new()
	_content_box.add_child(center_grid)

	_stash_grid_container = Control.new()
	var cols: int = stash.columns if stash != null else 10
	var rows: int = stash.rows if stash != null else 6
	_stash_grid_container.custom_minimum_size = Vector2(cols * CELL_SIZE, rows * CELL_SIZE)
	center_grid.add_child(_stash_grid_container)

	_rebuild_stash_cells()

	var transfer_all_btn := _make_gothic_button("📥 GUARDAR TODOS OS ITENS DA MOCHILA NO BAÚ", false)
	transfer_all_btn.custom_minimum_size = Vector2(0, 34)
	transfer_all_btn.pressed.connect(_deposit_all_from_backpack)
	_content_box.add_child(transfer_all_btn)

	var hint := Label.new()
	hint.text = "• Clique em um item no Baú: move para a Mochila\n• Clique Direito em um item na Mochila (janela à direita): guarda no Baú\n• Passe o mouse para comparar atributos com o que está equipado (▲ verde / ▼ vermelho)"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", COLOR_PARCHMENT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_box.add_child(hint)


func _rebuild_stash_cells() -> void:
	if _stash_grid_container == null or stash == null:
		return
	for child in _stash_grid_container.get_children():
		child.queue_free()

	for y in range(stash.rows):
		for x in range(stash.columns):
			var cell := Panel.new()
			cell.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.add_theme_stylebox_override("panel", _slot_style(Color(0.06, 0.05, 0.07, 0.85), Color(0.26, 0.22, 0.18, 0.65)))
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_stash_grid_container.add_child(cell)

	for item in stash.items:
		if item == null or item.definition == null:
			continue
		var eff_size: Vector2i = item.get_grid_size()
		var pos_px := Vector2(item.grid_position.x * CELL_SIZE, item.grid_position.y * CELL_SIZE)
		var size_px := Vector2(eff_size.x * CELL_SIZE, eff_size.y * CELL_SIZE)

		var item_panel := Panel.new()
		item_panel.position = pos_px
		item_panel.size = size_px
		var border_col: Color = item.get_rarity_color()
		if stats != null and not item.meets_requirements(stats):
			border_col = RED_ALERT
		item_panel.add_theme_stylebox_override("panel", _slot_style(Color(0.12, 0.10, 0.14, 0.96), border_col, 2))
		item_panel.gui_input.connect(func(ev: InputEvent) -> void: _on_stash_item_input(item, ev))
		item_panel.mouse_entered.connect(func() -> void:
			_show_item_tooltip(item, "[Clique Esquerdo/Direito: Retirar para a Mochila]")
		)
		item_panel.mouse_exited.connect(_hide_tooltip)
		_stash_grid_container.add_child(item_panel)

		var icon := TextureRect.new()
		icon.texture = ItemIconFactory.get_icon_for_item(item, false)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item_panel.add_child(icon)


func _on_stash_item_input(item: ItemInstance, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT or mb.button_index == MOUSE_BUTTON_RIGHT:
			if backpack == null or stash == null:
				return
			if backpack.find_free_spot_for(item).x < 0:
				show_feedback("⚠ Espaço insuficiente na Mochila para retirar %s!" % item.get_display_name(), true)
				return
			_hide_tooltip()
			stash.remove_item(item)
			backpack.auto_add_item(item)
			show_feedback("✦ Retirado do Baú para a Mochila: %s" % item.get_display_name(), false)


func _deposit_all_from_backpack() -> void:
	if backpack == null or stash == null:
		return
	var copy_items: Array[ItemInstance] = backpack.items.duplicate()
	var moved: int = 0
	for it in copy_items:
		if stash.find_free_spot_for(it).x >= 0:
			backpack.remove_item(it)
			stash.auto_add_item(it)
			moved += 1
	if moved > 0:
		show_feedback("✦ %d item(ns) guardados no Baú Pessoal!" % moved, false)
	else:
		show_feedback("⚠ Nenhum item pôde ser movido (Mochila vazia ou Baú cheio).", true)


# ===============================================================
# 2. FERREIRO & ARCANISTA — COMPRA E VENDA REAL + COMPARAÇÃO
# ===============================================================
func _populate_vendor_physical() -> void:
	_title_label.text = "⚒ FERREIRO — ARMAS & ARMADURAS"
	_subtitle_label.text = "\"Aço temperado para quem enfrenta a Cripta. Passe o mouse sobre os itens para comparar (▲/▼) com seu equipamento, ou clique com o Botão Direito na sua Mochila ao lado para vender!\""
	_build_vendor_shop_ui(_blacksmith_stock, true)


func _populate_vendor_magic() -> void:
	_title_label.text = "🔮 ARCANISTA — RELÍQUIAS & ITENS MÁGICOS"
	_subtitle_label.text = "\"Anéis, amuletos e lâminas encantadas. Passe o mouse para ver o que você ganha (▲ verde) ou perde (▼ vermelho), ou clique com o Botão Direito na Mochila para vender!\""
	_build_vendor_shop_ui(_arcanist_stock, false)


func _build_vendor_shop_ui(stock: Array[ItemInstance], is_blacksmith: bool) -> void:
	# Barra de Abas: [🛒 Comprar] | [↩ Recomprar (N)] + [🔄 Novos Itens]
	var tabs_bar := HBoxContainer.new()
	tabs_bar.add_theme_constant_override("separation", 8)

	var buy_tab_btn := _make_tab_button("🛒 COMPRAR ITENS (%d)" % stock.size(), _active_vendor_tab == 0, false)
	buy_tab_btn.pressed.connect(func() -> void:
		_active_vendor_tab = 0
		_refresh_current_station_content()
	)
	tabs_bar.add_child(buy_tab_btn)

	var buyback_tab_btn := _make_tab_button("↩ RECOMPRAR (%d)" % _buyback_items.size(), _active_vendor_tab == 1, _buyback_items.size() > 0)
	buyback_tab_btn.pressed.connect(func() -> void:
		_active_vendor_tab = 1
		_refresh_current_station_content()
	)
	tabs_bar.add_child(buyback_tab_btn)

	tabs_bar.add_spacer(false)

	if _active_vendor_tab == 0:
		var restock_cost: int = 15
		var restock_btn := _make_gothic_button("🔄 Novos (%d 🪙)" % restock_cost, false)
		restock_btn.custom_minimum_size = Vector2(126, 30)
		restock_btn.add_theme_font_size_override("font_size", 12)
		restock_btn.disabled = current_gold < restock_cost
		restock_btn.pressed.connect(func() -> void:
			if current_gold < restock_cost:
				show_feedback("⚠ Ouro insuficiente para renovar o estoque!", true)
				return
			current_gold -= restock_cost
			gold_changed.emit(current_gold)
			if is_blacksmith:
				_blacksmith_stock = ItemDatabase.generate_blacksmith_stock(maxi(1, area_level))
			else:
				_arcanist_stock = ItemDatabase.generate_arcanist_stock(maxi(1, area_level))
			_refresh_current_station_content()
			show_feedback("✦ O mercador trouxe novas mercadorias para a bancada!", false)
		)
		tabs_bar.add_child(restock_btn)

	_content_box.add_child(tabs_bar)

	var sell_hint := Label.new()
	if _active_vendor_tab == 0:
		sell_hint.text = "💡 Clique Direito em qualquer item da sua Mochila (à direita) para VENDER (ele irá para a aba Recomprar)!"
		sell_hint.add_theme_color_override("font_color", Color(0.96, 0.85, 0.45))
	else:
		sell_hint.text = "↩ Aba Recomprar: recupere qualquer item vendido pelo EXATO mesmo valor em Ouro que você recebeu!"
		sell_hint.add_theme_color_override("font_color", Color(0.56, 0.92, 0.66))
	sell_hint.add_theme_font_size_override("font_size", 11)
	_content_box.add_child(sell_hint)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 290)
	_content_box.add_child(scroll)

	var list_vbox := VBoxContainer.new()
	list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_vbox.add_theme_constant_override("separation", 6)
	scroll.add_child(list_vbox)

	if _active_vendor_tab == 0:
		for item in stock:
			if item == null or item.definition == null:
				continue
			list_vbox.add_child(_make_vendor_item_row(item, stock))
	else:
		if _buyback_items.is_empty():
			var empty_lbl := Label.new()
			empty_lbl.text = "\nNenhum item vendido ainda nesta sessão.\n\nQuando você vender um item clicando com o Botão Direito na sua Mochila,\nele ficará guardado aqui caso queira recomprá-lo pelo mesmo valor!"
			empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			empty_lbl.add_theme_font_size_override("font_size", 13)
			empty_lbl.add_theme_color_override("font_color", COLOR_MUTED)
			list_vbox.add_child(empty_lbl)
		else:
			for entry in _buyback_items:
				list_vbox.add_child(_make_buyback_item_row(entry))


func _make_tab_button(text_val: String, is_active: bool, has_items_highlight: bool) -> Button:
	var btn := Button.new()
	btn.text = text_val
	btn.custom_minimum_size = Vector2(172, 32)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 12)
	if is_active:
		btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.72))
	elif has_items_highlight:
		btn.add_theme_color_override("font_color", Color(0.62, 0.95, 0.70))
	else:
		btn.add_theme_color_override("font_color", COLOR_MUTED)

	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.18, 0.14, 0.08, 0.98) if is_active else Color(0.08, 0.075, 0.095, 0.92)
	st.border_color = COLOR_GOLD_TITLE if is_active else (Color(0.38, 0.68, 0.44, 0.85) if has_items_highlight else Color(0.32, 0.28, 0.22, 0.75))
	st.set_border_width_all(2 if is_active else 1)
	st.set_corner_radius_all(4)
	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = st.bg_color.lightened(0.12)
	hov.border_color = COLOR_GOLD_TITLE
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", st)
	return btn


func _make_buyback_item_row(entry: Dictionary) -> PanelContainer:
	var item: ItemInstance = entry.get("item", null) as ItemInstance
	var sold_price: int = int(entry.get("price", 5))

	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.07, 0.095, 0.08, 0.95)
	st.border_color = item.get_rarity_color().darkened(0.15)
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", st)

	var price_line: String = "↩ Valor de Recompra: [color=#4dff6b]%d Ouro (Mesmo valor da venda)[/color]" % sold_price
	row.mouse_entered.connect(func() -> void:
		_show_item_tooltip(item, "[Clique em Recomprar pelo valor exato de venda]", price_line)
	)
	row.mouse_exited.connect(_hide_tooltip)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)

	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(44, 44)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_theme_stylebox_override("panel", _slot_style(Color(0.05, 0.04, 0.06, 0.95), item.get_rarity_color(), 1))
	var icon_rect := TextureRect.new()
	icon_rect.texture = ItemIconFactory.get_icon(item.definition)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(38, 38)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon_rect)
	hb.add_child(icon_box)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)

	var nl := Label.new()
	nl.text = item.get_display_name()
	nl.add_theme_font_size_override("font_size", 14)
	nl.add_theme_color_override("font_color", item.get_rarity_color())
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nl)

	var dl := Label.new()
	dl.text = _build_short_item_summary(item)
	dl.add_theme_font_size_override("font_size", 11)
	dl.add_theme_color_override("font_color", COLOR_PARCHMENT)
	dl.clip_text = true
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(dl)

	var can_afford: bool = current_gold >= sold_price
	var buyback_btn := _make_gothic_button("🪙 %d Ouro\n[Recomprar]" % sold_price, not can_afford)
	buyback_btn.custom_minimum_size = Vector2(110, 42)
	buyback_btn.add_theme_font_size_override("font_size", 12)
	buyback_btn.disabled = not can_afford
	buyback_btn.mouse_entered.connect(func() -> void:
		_show_item_tooltip(item, "[Clique para Recomprar por %d Ouro]" % sold_price, price_line)
	)
	buyback_btn.mouse_exited.connect(_hide_tooltip)
	buyback_btn.pressed.connect(func() -> void:
		_attempt_buyback_item(entry)
	)
	hb.add_child(buyback_btn)

	return row


func _attempt_buyback_item(entry: Dictionary) -> void:
	var item: ItemInstance = entry.get("item", null) as ItemInstance
	var sold_price: int = int(entry.get("price", 5))
	if item == null or backpack == null:
		return
	if current_gold < sold_price:
		show_feedback("⚠ Ouro insuficiente para recomprar! Você precisa de %d Ouro." % sold_price, true)
		return
	if backpack.find_free_spot_for(item).x < 0:
		show_feedback("⚠ Sua Mochila não tem espaço livre (%dx%d) para recomprar este item!" % [item.definition.grid_size.x, item.definition.grid_size.y], true)
		return

	_hide_tooltip()
	current_gold -= sold_price
	_buyback_items.erase(entry)
	backpack.auto_add_item(item)
	gold_changed.emit(current_gold)
	_refresh_current_station_content()
	show_feedback("✦ Recomprado: %s pelo mesmo valor da venda (%d Ouro)!" % [item.get_display_name(), sold_price], false)


func _make_vendor_item_row(item: ItemInstance, stock_array: Array[ItemInstance]) -> PanelContainer:
	var row := PanelContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.075, 0.095, 0.95)
	st.border_color = item.get_rarity_color().darkened(0.25)
	st.set_border_width_all(1)
	st.set_corner_radius_all(3)
	st.content_margin_left = 10
	st.content_margin_right = 10
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	row.add_theme_stylebox_override("panel", st)

	var price: int = item.get_buy_price()
	var price_line: String = "🪙 Preço de Compra: [color=#f5d168]%d Ouro[/color]" % price
	row.mouse_entered.connect(func() -> void:
		_show_item_tooltip(item, "[Clique em Comprar para adquirir este item]", price_line)
	)
	row.mouse_exited.connect(_hide_tooltip)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)

	# Moldura do Ícone
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(44, 44)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_theme_stylebox_override("panel", _slot_style(Color(0.05, 0.04, 0.06, 0.95), item.get_rarity_color(), 1))
	var icon_rect := TextureRect.new()
	icon_rect.texture = ItemIconFactory.get_icon(item.definition)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(38, 38)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon_rect)
	hb.add_child(icon_box)

	# Nome + Resumo de Atributos
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)

	var nl := Label.new()
	nl.text = item.get_display_name()
	nl.add_theme_font_size_override("font_size", 14)
	nl.add_theme_color_override("font_color", item.get_rarity_color())
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(nl)

	var dl := Label.new()
	dl.text = _build_short_item_summary(item)
	dl.add_theme_font_size_override("font_size", 11)
	dl.add_theme_color_override("font_color", COLOR_PARCHMENT)
	dl.clip_text = true
	dl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(dl)

	# Botão de Compra
	var can_afford: bool = current_gold >= price
	var buy_btn := _make_gothic_button("🪙 %d Ouro\n[Comprar]" % price, not can_afford)
	buy_btn.custom_minimum_size = Vector2(106, 42)
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.disabled = not can_afford
	buy_btn.mouse_entered.connect(func() -> void:
		_show_item_tooltip(item, "[Clique para Comprar por %d Ouro]" % price, price_line)
	)
	buy_btn.mouse_exited.connect(_hide_tooltip)
	buy_btn.pressed.connect(func() -> void:
		_attempt_buy_item(item, stock_array)
	)
	hb.add_child(buy_btn)

	return row


func _build_short_item_summary(item: ItemInstance) -> String:
	var def: ItemDefinition = item.definition
	var parts: Array[String] = []
	if def.category == ItemDefinition.ItemCategory.WEAPON_1H or def.category == ItemDefinition.ItemCategory.WEAPON_2H:
		var dmg: Vector2i = item.get_damage_range()
		parts.append("⚔ Dano %d-%d" % [dmg.x, dmg.y])
	if item.get_total_armor() > 0:
		parts.append("🛡️ Armadura %d" % item.get_total_armor())
	if def.base_health > 0:
		parts.append("♥ +%d Vida" % def.base_health)
	for af in item.explicit_affixes:
		if af != null:
			parts.append(af.display_text)
	return "  |  ".join(parts)


func _attempt_buy_item(item: ItemInstance, stock_array: Array[ItemInstance]) -> void:
	if item == null or backpack == null:
		return
	var price: int = item.get_buy_price()
	if current_gold < price:
		show_feedback("⚠ Ouro insuficiente! Você precisa de %d Ouro." % price, true)
		return

	# Se for poção consumível, cria uma cópia para que a loja nunca fique sem poções!
	var item_to_give: ItemInstance = item
	var is_consumable: bool = item.definition.category == ItemDefinition.ItemCategory.CONSUMABLE
	if is_consumable:
		item_to_give = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, item.definition.base_id)
		item_to_give.identify()

	if backpack.find_free_spot_for(item_to_give).x < 0:
		show_feedback("⚠ Sua Mochila não tem espaço livre (%dx%d) para este item!" % [item_to_give.definition.grid_size.x, item_to_give.definition.grid_size.y], true)
		return

	current_gold -= price
	backpack.auto_add_item(item_to_give)
	if not is_consumable:
		stock_array.erase(item)
	gold_changed.emit(current_gold)
	_refresh_current_station_content()
	show_feedback("✦ Comprado: %s (-%d Ouro)!" % [item_to_give.get_display_name(), price], false)


# ===============================================================
# 3. SÁBIO IDENTIFICADOR, CURANDEIRO & RESET DE BUILD
# ===============================================================
func _populate_identifier_respec() -> void:
	_title_label.text = "📜 SÁBIO ANCESTRAL — IDENTIFICAR, CURAR & RESETAR"
	_subtitle_label.text = "\"Fique um instante e escute... Posso revelar o poder oculto das suas relíquias, curar suas feridas ou purificar seus atributos.\""

	var unid_count: int = 0
	if backpack != null:
		for it in backpack.items:
			if it != null and not it.is_identified:
				unid_count += 1
	if stash != null:
		for it in stash.items:
			if it != null and not it.is_identified:
				unid_count += 1

	var id_txt: String = "🔍 IDENTIFICAR TODOS OS ITENS (%d Pendentes) — GRÁTIS" % unid_count if unid_count > 0 else "🔍 TODOS OS SEUS ITENS JÁ ESTÃO IDENTIFICADOS"
	var id_btn := _make_gothic_button(id_txt, false)
	id_btn.pressed.connect(func() -> void:
		identify_items_requested.emit()
		_refresh_current_station_content()
		show_feedback("✦ Todos os itens na Mochila e no Baú foram identificados pelo Sábio!", false)
	)
	_content_box.add_child(id_btn)

	var heal_btn := _make_gothic_button("♥ BÊNÇÃO DE CURA COMPLETA (RESTAURAR 100% DA VIDA) — GRÁTIS", false)
	heal_btn.pressed.connect(func() -> void:
		heal_player_requested.emit()
		show_feedback("✦ A luz ancestral restaurou toda a sua Vida!", false)
	)
	_content_box.add_child(heal_btn)

	var respec_btn := _make_gothic_button("↺ PURIFICAR & RESETAR ATRIBUTOS BASE", true)
	respec_btn.pressed.connect(func() -> void:
		respec_build_requested.emit()
		show_feedback("✦ Seus atributos base foram restaurados ao estado original!", false)
	)
	_content_box.add_child(respec_btn)

	var lore_panel := PanelContainer.new()
	lore_panel.add_theme_stylebox_override("panel", _slot_style(Color(0.07, 0.065, 0.085, 0.92), COLOR_BRONZE_BORDER, 1))
	var lore := Label.new()
	lore.text = "✦ Dicas do Sábio de Velen:\n• Passe o mouse sobre qualquer item na Mochila, Baú ou Mercador para ver as setas de comparação (▲ verde = melhora / ▼ vermelho = piora).\n• Requisitos de Força, Agilidade e Inteligência são cumpridos equipando Anéis, Amuletos e subindo de Nível em combate."
	lore.add_theme_font_size_override("font_size", 12)
	lore.add_theme_color_override("font_color", COLOR_PARCHMENT)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_panel.add_child(lore)
	_content_box.add_child(lore_panel)


# ===============================================================
# 4. WAYPOINT ANCESTRAL — TELEPORTE DE ZONAS
# ===============================================================
func _populate_waypoint() -> void:
	_title_label.text = "✦ WAYPOINT ANCESTRAL — TELEPORTE"
	_subtitle_label.text = "Selecione uma Zona descoberta do Ato 1 para viajar instantaneamente:"

	var all_zones := [
		["town", "🏰 Vila de Velen (Refúgio Seguro)"],
		["zone_1_road", "⚔ Zona 1 — Caminho dos Lamentos (Nível 1)"],
		["zone_2_woods", "🌲 Zona 2 — Mata das Sombras (Nível 2)"],
		["zone_3_crypt", "☠ Zona 3 — Cripta do Carrasco (Nível 3 - Boss Malakor)"],
	]
	for z in all_zones:
		var zid: String = z[0]
		var zlabel: String = z[1]
		var is_unlocked: bool = _unlocked_zones.has(zid)
		var is_current: bool = (zid == _current_zone_id)
		var btn_text: String = zlabel
		if is_current:
			btn_text += "  [VOCÊ ESTÁ AQUI]"
		elif not is_unlocked:
			btn_text += "  [BLOQUEADO — Descubra a pé]"
		var btn := _make_gothic_button(btn_text, zid == "zone_3_crypt" and is_unlocked)
		btn.disabled = (not is_unlocked) or is_current
		btn.pressed.connect(func() -> void:
			close_modal()
			waypoint_travel_requested.emit(zid)
		)
		_content_box.add_child(btn)


# ===============================================================
# TOOLTIP & ESTILOS
# ===============================================================
func _show_item_tooltip(item: ItemInstance, action_hint: String = "", price_line: String = "") -> void:
	if item == null or item.definition == null:
		_hide_tooltip()
		return
	_tooltip_text.text = item.format_tooltip_bbcode(stats, equipment, action_hint, price_line)
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
	s.set_corner_radius_all(3)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _make_gothic_button(text_val: String, is_crimson: bool) -> Button:
	var btn := Button.new()
	btn.text = text_val
	btn.custom_minimum_size = Vector2(0, 40)
	btn.add_theme_font_size_override("font_size", 14)
	btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.38, 0.10, 0.10, 0.96) if is_crimson else Color(0.11, 0.10, 0.14, 0.96)
	normal.border_color = COLOR_BRONZE_BORDER
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(3)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.14)
	hover.border_color = COLOR_GOLD_TITLE
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn
