@warning_ignore("integer_division")
extends Control
class_name TownNpcModal
## Modal Gótico Dark-Fantasy Padronizado para os NPCs e Baú da Vila:
## • Lojas (Ferreiro & Arcanista) com layout fiel à referência visual em 3 colunas:
##   1. Esquerda: Retrato ilustrado do NPC + 4 abas verticais (🛒 Comprar, 🔄 Recomprar, 🪙 Vender, 🔨 Reparar).
##   2. Centro: Filtros de Categoria (Todas, Armas, Armaduras, Acessórios, Consumíveis), Busca em tempo real,
##      filtros de Tier e Raridade, lista de itens destacável e paginação (< 1 / 3 >).
##   3. Direita: Painel de Inspeção do item selecionado com vitrine grande, badge de Tier (T1/T2/T3),
##      atributos + comparação (▲/▼), descrição temática em itálico e botão dourado "Comprar por X Ouro".

signal opened(station_id: String)
signal closed()
signal waypoint_travel_requested(zone_id: String)
signal respec_build_requested()
signal identify_items_requested()
signal heal_player_requested()
signal gold_changed(new_gold: int)

const COLOR_BG := Color(0.055, 0.048, 0.058, 0.98)
const COLOR_PANEL_DARK := Color(0.075, 0.068, 0.085, 0.96)
const COLOR_BRONZE_BORDER := Color(0.65, 0.50, 0.25, 0.96)
const COLOR_BORDER_SUBTLE := Color(0.36, 0.29, 0.18, 0.82)
const COLOR_GOLD_TITLE := Color(0.95, 0.80, 0.42)
const COLOR_GOLD_BRIGHT := Color(1.0, 0.88, 0.48)
const COLOR_PARCHMENT := Color(0.90, 0.86, 0.78)
const COLOR_MUTED := Color(0.64, 0.59, 0.52)
const RED_ALERT := Color(1.0, 0.35, 0.35)
const CELL_SIZE := 36
const ITEMS_PER_PAGE := 6

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

# Estado padronizado das Lojas (Ferreiro / Arcanista)
var _active_vendor_tab: int = 0              ## 0 = Comprar, 1 = Recomprar, 2 = Vender, 3 = Reparar
var _active_category_filter: int = 0         ## 0 = Todas, 1 = Armas, 2 = Armaduras, 3 = Acessórios, 4 = Consumíveis
var _active_tier_filter: int = 0             ## 0 = Todos, 1 = T1, 2 = T2, 3 = T3+
var _active_rarity_filter: int = 0           ## 0 = Todas, 1 = Normal, 2 = Mágico, 3 = Raro, 4 = Lendário
var _search_query: String = ""
var _current_page: int = 0
var _selected_vendor_item: ItemInstance = null
var _selected_buyback_entry: Dictionary = {}

# Cache de retratos dos mercadores
static var _portrait_cache: Dictionary = {}

# Janela móvel / acoplável
var _window_panel: PanelContainer
var _header_bar: HBoxContainer
var _gold_header_label: Label
var _title_label: Label
var _subtitle_label: Label
var _content_box: VBoxContainer
var _feedback_label: Label
var _bottom_close_btn: Button
var _stash_grid_container: Control

# Sub-containers dinâmicos da Loja (para atualizar lista e preview sem perder foco da busca)
var _vendor_list_vbox: VBoxContainer
var _vendor_page_label: Label
var _vendor_prev_page_btn: Button
var _vendor_next_page_btn: Button
var _vendor_inspector_box: VBoxContainer

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
		_gold_header_label.text = "🪙  %d Ouro" % current_gold
	if visible and _is_vendor_station():
		_refresh_vendor_catalog_and_inspector()


func _is_vendor_station() -> bool:
	return current_station_id == "vendor_physical" or current_station_id == "vendor_magic"


func show_feedback(msg: String, is_error: bool = false) -> void:
	if _feedback_label == null:
		return
	_feedback_label.text = msg
	_feedback_label.visible = not msg.is_empty()
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45) if is_error else Color(0.52, 0.94, 0.62))


func get_window_size() -> Vector2:
	if _window_panel == null:
		return Vector2(880, 545) if _is_vendor_station() else Vector2(540, 520)
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
			maxf(10.0, (vp.y - sz.y) * 0.46)
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
	_window_panel.custom_minimum_size = Vector2(880, 540)
	_window_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_BG
	style.border_color = COLOR_BRONZE_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.84)
	style.shadow_size = 18
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 12
	style.content_margin_bottom = 14
	_window_panel.add_theme_stylebox_override("panel", style)
	add_child(_window_panel)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 8)
	_window_panel.add_child(root_vbox)

	# 1. CABEÇALHO SUPERIOR FIEL À REFERÊNCIA (Ícone + Título + Ornamento ───❖─── + 🪙 Ouro + Botão Vermelho [✕])
	_header_bar = HBoxContainer.new()
	_header_bar.add_theme_constant_override("separation", 10)
	_header_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_header_bar.gui_input.connect(_on_header_gui_input)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_bar.add_child(_title_label)

	var orn_line := Label.new()
	orn_line.text = "──────  ❖  ────────────────────────"
	orn_line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orn_line.add_theme_font_size_override("font_size", 13)
	orn_line.add_theme_color_override("font_color", Color(0.62, 0.48, 0.24, 0.85))
	orn_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_bar.add_child(orn_line)

	var gold_badge := PanelContainer.new()
	gold_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gb_st := _slot_style(Color(0.09, 0.08, 0.06, 0.95), Color(0.55, 0.43, 0.20, 0.85), 1)
	gb_st.content_margin_left = 10
	gb_st.content_margin_right = 10
	gb_st.content_margin_top = 4
	gb_st.content_margin_bottom = 4
	gold_badge.add_theme_stylebox_override("panel", gb_st)

	_gold_header_label = Label.new()
	_gold_header_label.text = "🪙  %d Ouro" % current_gold
	_gold_header_label.add_theme_font_size_override("font_size", 14)
	_gold_header_label.add_theme_color_override("font_color", Color(0.98, 0.86, 0.42))
	_gold_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gold_badge.add_child(_gold_header_label)
	_header_bar.add_child(gold_badge)

	var close_top_btn := Button.new()
	close_top_btn.text = "✕"
	close_top_btn.custom_minimum_size = Vector2(32, 30)
	close_top_btn.add_theme_font_size_override("font_size", 15)
	close_top_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.90))
	close_top_btn.focus_mode = Control.FOCUS_NONE
	var x_norm := StyleBoxFlat.new()
	x_norm.bg_color = Color(0.46, 0.12, 0.12, 0.96)
	x_norm.border_color = COLOR_BRONZE_BORDER
	x_norm.set_border_width_all(1)
	x_norm.set_corner_radius_all(4)
	var x_hov := x_norm.duplicate() as StyleBoxFlat
	x_hov.bg_color = Color(0.64, 0.16, 0.16, 0.98)
	x_hov.border_color = COLOR_GOLD_BRIGHT
	close_top_btn.add_theme_stylebox_override("normal", x_norm)
	close_top_btn.add_theme_stylebox_override("hover", x_hov)
	close_top_btn.add_theme_stylebox_override("pressed", x_hov)
	close_top_btn.pressed.connect(close_modal)
	_header_bar.add_child(close_top_btn)
	root_vbox.add_child(_header_bar)

	var sep_top := HSeparator.new()
	sep_top.add_theme_color_override("separator", COLOR_BORDER_SUBTLE)
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
	_feedback_label.visible = false
	_feedback_label.add_theme_font_size_override("font_size", 12)
	_feedback_label.add_theme_color_override("font_color", Color(0.56, 0.90, 0.62))
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_feedback_label)

	_bottom_close_btn = _make_gothic_button("FECHAR JANELA (ESC / E)", false)
	_bottom_close_btn.custom_minimum_size = Vector2(0, 34)
	_bottom_close_btn.pressed.connect(close_modal)
	root_vbox.add_child(_bottom_close_btn)

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
	_active_category_filter = 0
	_active_tier_filter = 0
	_active_rarity_filter = 0
	_search_query = ""
	_current_page = 0
	_selected_vendor_item = null
	_selected_buyback_entry = {}
	_has_custom_window_pos = false
	_ensure_vendor_stocks()
	show_feedback("")
	if _gold_header_label != null:
		_gold_header_label.text = "🪙  %d Ouro" % current_gold

	if _is_vendor_station():
		_window_panel.custom_minimum_size = Vector2(890, 548)
		_subtitle_label.visible = false
		_bottom_close_btn.visible = false
	elif station_id == "identifier_respec":
		_window_panel.custom_minimum_size = Vector2(860, 540)
		_subtitle_label.visible = false
		_bottom_close_btn.visible = true
	else:
		_window_panel.custom_minimum_size = Vector2(540, 510)
		_subtitle_label.visible = true
		_bottom_close_btn.visible = true

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
	if _buyback_items.size() > 30:
		_buyback_items.resize(30)
	if visible and _is_vendor_station():
		_refresh_vendor_catalog_and_inspector()


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
	elif _is_vendor_station():
		_refresh_vendor_catalog_and_inspector()


func _on_equipment_changed(_slot: ItemDefinition.EquipmentSlot, _item: ItemInstance) -> void:
	if not visible:
		return
	if current_station_id == "stash" and _stash_grid_container != null:
		_rebuild_stash_cells()
	elif _is_vendor_station():
		_refresh_vendor_catalog_and_inspector()


func _refresh_current_station_content() -> void:
	_hide_tooltip()
	_stash_grid_container = null
	_vendor_list_vbox = null
	_vendor_inspector_box = null
	for child in _content_box.get_children():
		_content_box.remove_child(child)
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
	_title_label.text = "📦  BAÚ PESSOAL (STASH 10x6)"
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
	hint.text = "• Clique em um item no Baú: move para a Mochila  |  • Clique Direito na Mochila: guarda no Baú"
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
			if not backpack.can_fit_item(item):
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
# 2. LOJAS PADRONIZADAS (FERREIRO & ARCANISTA) — FIEL À IMAGEM
# ===============================================================
func _populate_vendor_physical() -> void:
	_title_label.text = "⚒   FERREIRO  —  ARMAS & ARMADURAS"
	_build_vendor_shop_ui(true)


func _populate_vendor_magic() -> void:
	_title_label.text = "🔮   ARCANISTA  —  RELÍQUIAS & ITENS MÁGICOS"
	_build_vendor_shop_ui(false)


func _get_vendor_portrait(is_blacksmith: bool) -> Texture2D:
	var key: String = "blacksmith" if is_blacksmith else "arcanist"
	if _portrait_cache.has(key):
		return _portrait_cache[key] as Texture2D

	var res_path: String = "res://assets/ui/blacksmith_portrait.png" if is_blacksmith else "res://assets/ui/arcanist_portrait.png"
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_portrait_cache[key] = tex
			return tex
	if ResourceLoader.exists(res_path):
		var rtex: Texture2D = load(res_path) as Texture2D
		if rtex != null:
			_portrait_cache[key] = rtex
			return rtex
	return null


func _build_vendor_shop_ui(is_blacksmith: bool) -> void:
	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 12)
	_content_box.add_child(body_hbox)

	# ---------------------------------------------------------------
	# COLUNA 1 (ESQUERDA): RETRATO DO NPC + 4 BOTÕES DE MODO EMPILHADOS
	# ---------------------------------------------------------------
	var left_col := VBoxContainer.new()
	left_col.custom_minimum_size = Vector2(174, 0)
	left_col.add_theme_constant_override("separation", 6)
	body_hbox.add_child(left_col)

	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(174, 244)
	portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pf_style := _slot_style(Color(0.06, 0.05, 0.07, 0.98), COLOR_BRONZE_BORDER, 2)
	pf_style.set_corner_radius_all(5)
	pf_style.content_margin_left = 3
	pf_style.content_margin_right = 3
	pf_style.content_margin_top = 3
	pf_style.content_margin_bottom = 3
	portrait_frame.add_theme_stylebox_override("panel", pf_style)
	left_col.add_child(portrait_frame)

	var portrait_tex := TextureRect.new()
	portrait_tex.texture = _get_vendor_portrait(is_blacksmith)
	portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_frame.add_child(portrait_tex)

	var mode_defs: Array[Dictionary] = [
		{"id": 0, "icon": "🛒", "label": "Comprar"},
		{"id": 1, "icon": "🔄", "label": "Recomprar" + (" (%d)" % _buyback_items.size() if not _buyback_items.is_empty() else "")},
		{"id": 2, "icon": "🪙", "label": "Vender"},
		{"id": 3, "icon": "🔨", "label": "Reparar"},
	]
	for md in mode_defs:
		var tab_id: int = int(md["id"])
		var m_btn := _make_sidebar_mode_button(String(md["icon"]), String(md["label"]), _active_vendor_tab == tab_id)
		m_btn.pressed.connect(func() -> void:
			_active_vendor_tab = tab_id
			_current_page = 0
			_selected_vendor_item = null
			_selected_buyback_entry = {}
			_refresh_current_station_content()
		)
		left_col.add_child(m_btn)

	# ---------------------------------------------------------------
	# COLUNA 2 (CENTRO): CATEGORIAS + BUSCA/TIER/RARIDADE + LISTA + PAGINAÇÃO
	# ---------------------------------------------------------------
	var center_frame := PanelContainer.new()
	center_frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_frame.custom_minimum_size = Vector2(456, 0)
	var cf_style := _slot_style(Color(0.05, 0.045, 0.06, 0.96), COLOR_BORDER_SUBTLE, 1)
	cf_style.set_corner_radius_all(6)
	cf_style.content_margin_left = 10
	cf_style.content_margin_right = 10
	cf_style.content_margin_top = 8
	cf_style.content_margin_bottom = 8
	center_frame.add_theme_stylebox_override("panel", cf_style)
	body_hbox.add_child(center_frame)

	var center_vbox := VBoxContainer.new()
	center_vbox.add_theme_constant_override("separation", 7)
	center_frame.add_child(center_vbox)

	# Linha 1: Pílulas de Categoria (⊞ Todas | ⚔ Armas | 🛡 Armaduras | 💍 Acessórios | 🧪 Consumíveis)
	var cat_bar := HBoxContainer.new()
	cat_bar.add_theme_constant_override("separation", 5)
	center_vbox.add_child(cat_bar)

	var cat_defs := [
		[0, "⊞  Todas"],
		[1, "⚔  Armas"],
		[2, "🛡  Armaduras"],
		[3, "💍  Acessórios"],
		[4, "🧪  Consumíveis"],
	]
	for cd in cat_defs:
		var cid: int = int(cd[0])
		var c_btn := _make_category_pill_button(String(cd[1]), _active_category_filter == cid)
		c_btn.pressed.connect(func() -> void:
			_active_category_filter = cid
			_current_page = 0
			_refresh_current_station_content()
		)
		cat_bar.add_child(c_btn)

	# Linha 2: Barra de Busca ("🔍 Buscar item...") + Tier Dropdown + Raridade Dropdown
	var filter_bar := HBoxContainer.new()
	filter_bar.add_theme_constant_override("separation", 6)
	center_vbox.add_child(filter_bar)

	var search_edit := LineEdit.new()
	search_edit.placeholder_text = "🔍  Buscar item..."
	search_edit.text = _search_query
	search_edit.clear_button_enabled = true
	search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_edit.custom_minimum_size = Vector2(170, 30)
	search_edit.add_theme_font_size_override("font_size", 12)
	search_edit.add_theme_color_override("font_color", COLOR_PARCHMENT)
	var se_style := _slot_style(Color(0.04, 0.038, 0.05, 0.98), COLOR_BORDER_SUBTLE, 1)
	se_style.set_corner_radius_all(4)
	se_style.content_margin_left = 8
	se_style.content_margin_right = 8
	se_style.content_margin_top = 4
	se_style.content_margin_bottom = 4
	search_edit.add_theme_stylebox_override("normal", se_style)
	search_edit.add_theme_stylebox_override("focus", _slot_style(Color(0.06, 0.055, 0.08, 0.98), COLOR_GOLD_TITLE, 1))
	search_edit.text_changed.connect(func(new_txt: String) -> void:
		_search_query = new_txt
		_current_page = 0
		_refresh_vendor_catalog_and_inspector()
	)
	filter_bar.add_child(search_edit)

	var tier_opt := OptionButton.new()
	tier_opt.custom_minimum_size = Vector2(114, 30)
	tier_opt.add_theme_font_size_override("font_size", 12)
	tier_opt.add_theme_color_override("font_color", COLOR_PARCHMENT)
	tier_opt.add_theme_stylebox_override("normal", se_style)
	tier_opt.add_theme_stylebox_override("hover", se_style)
	tier_opt.add_theme_stylebox_override("pressed", se_style)
	tier_opt.add_item("Tier: Todos", 0)
	tier_opt.add_item("Tier: T1", 1)
	tier_opt.add_item("Tier: T2", 2)
	tier_opt.add_item("Tier: T3+", 3)
	tier_opt.selected = _active_tier_filter
	tier_opt.item_selected.connect(func(idx: int) -> void:
		_active_tier_filter = idx
		_current_page = 0
		_refresh_vendor_catalog_and_inspector()
	)
	filter_bar.add_child(tier_opt)

	var rar_opt := OptionButton.new()
	rar_opt.custom_minimum_size = Vector2(132, 30)
	rar_opt.add_theme_font_size_override("font_size", 12)
	rar_opt.add_theme_color_override("font_color", COLOR_PARCHMENT)
	rar_opt.add_theme_stylebox_override("normal", se_style)
	rar_opt.add_theme_stylebox_override("hover", se_style)
	rar_opt.add_theme_stylebox_override("pressed", se_style)
	rar_opt.add_item("Raridade: Todas", 0)
	rar_opt.add_item("Normal (Branco)", 1)
	rar_opt.add_item("Incomum (Verde)", 2)
	rar_opt.add_item("Mágico (Azul)", 3)
	rar_opt.add_item("Raro (Amarelo)", 4)
	rar_opt.add_item("Único (Vermelho)", 5)
	rar_opt.selected = _active_rarity_filter
	rar_opt.item_selected.connect(func(idx: int) -> void:
		_active_rarity_filter = idx
		_current_page = 0
		_refresh_vendor_catalog_and_inspector()
	)
	filter_bar.add_child(rar_opt)

	# Linha 3: Container da Lista de Itens (6 linhas por página igual à referência)
	var list_scroll := ScrollContainer.new()
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_scroll.custom_minimum_size = Vector2(0, 336)
	center_vbox.add_child(list_scroll)

	_vendor_list_vbox = VBoxContainer.new()
	_vendor_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vendor_list_vbox.add_theme_constant_override("separation", 5)
	list_scroll.add_child(_vendor_list_vbox)

	# Linha 4: Barra de Paginação (<   1 / 3   >)
	var page_bar := HBoxContainer.new()
	page_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	page_bar.add_theme_constant_override("separation", 12)
	center_vbox.add_child(page_bar)

	_vendor_prev_page_btn = _make_page_arrow_button("<")
	_vendor_prev_page_btn.pressed.connect(func() -> void:
		if _current_page > 0:
			_current_page -= 1
			_refresh_vendor_catalog_and_inspector()
	)
	page_bar.add_child(_vendor_prev_page_btn)

	_vendor_page_label = Label.new()
	_vendor_page_label.text = "1 / 3"
	_vendor_page_label.custom_minimum_size = Vector2(54, 0)
	_vendor_page_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vendor_page_label.add_theme_font_size_override("font_size", 13)
	_vendor_page_label.add_theme_color_override("font_color", COLOR_PARCHMENT)
	page_bar.add_child(_vendor_page_label)

	_vendor_next_page_btn = _make_page_arrow_button(">")
	_vendor_next_page_btn.pressed.connect(func() -> void:
		_current_page += 1
		_refresh_vendor_catalog_and_inspector()
	)
	page_bar.add_child(_vendor_next_page_btn)

	# ---------------------------------------------------------------
	# COLUNA 3 (DIREITA): PAINEL DE INSPEÇÃO / VITRINE DO ITEM SELECIONADO
	# ---------------------------------------------------------------
	var right_frame := PanelContainer.new()
	right_frame.custom_minimum_size = Vector2(226, 0)
	right_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var rf_style := _slot_style(Color(0.06, 0.052, 0.072, 0.98), COLOR_BRONZE_BORDER, 1)
	rf_style.set_corner_radius_all(6)
	rf_style.content_margin_left = 12
	rf_style.content_margin_right = 12
	rf_style.content_margin_top = 10
	rf_style.content_margin_bottom = 10
	right_frame.add_theme_stylebox_override("panel", rf_style)
	body_hbox.add_child(right_frame)

	_vendor_inspector_box = VBoxContainer.new()
	_vendor_inspector_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_vendor_inspector_box.add_theme_constant_override("separation", 8)
	right_frame.add_child(_vendor_inspector_box)

	_refresh_vendor_catalog_and_inspector()


func _matches_vendor_filters(item: ItemInstance) -> bool:
	if item == null or item.definition == null:
		return false
	var def: ItemDefinition = item.definition

	# 1. Filtro de Categoria
	match _active_category_filter:
		1: # Armas
			if def.category != ItemDefinition.ItemCategory.WEAPON_1H and def.category != ItemDefinition.ItemCategory.WEAPON_2H:
				return false
		2: # Armaduras
			if def.category != ItemDefinition.ItemCategory.CHEST and def.category != ItemDefinition.ItemCategory.HELMET and def.category != ItemDefinition.ItemCategory.GLOVES and def.category != ItemDefinition.ItemCategory.BOOTS and def.category != ItemDefinition.ItemCategory.BELT and def.category != ItemDefinition.ItemCategory.SHIELD:
				return false
		3: # Acessórios
			if def.category != ItemDefinition.ItemCategory.RING and def.category != ItemDefinition.ItemCategory.AMULET:
				return false
		4: # Consumíveis
			if def.category != ItemDefinition.ItemCategory.CONSUMABLE:
				return false

	# 2. Filtro de Tier
	var tier_num: int = clampi(item.item_level, 1, 3)
	if _active_tier_filter > 0 and tier_num != _active_tier_filter:
		return false

	# 3. Filtro de Raridade
	if _active_rarity_filter > 0:
		var expected_order: int = _active_rarity_filter - 1
		if ItemInstance.get_rarity_visual_order(item.rarity) != expected_order:
			return false

	# 4. Busca textual
	if not _search_query.strip_edges().is_empty():
		var q: String = _search_query.strip_edges().to_lower()
		var hay: String = (item.get_display_name() + " " + _build_short_item_summary(item) + " " + item.get_slot_display_name()).to_lower()
		if not hay.contains(q):
			return false

	return true


func _refresh_vendor_catalog_and_inspector() -> void:
	if _vendor_list_vbox == null or _vendor_inspector_box == null:
		return
	for child in _vendor_list_vbox.get_children():
		_vendor_list_vbox.remove_child(child)
		child.queue_free()

	var is_blacksmith: bool = (current_station_id == "vendor_physical")
	var stock: Array[ItemInstance] = _blacksmith_stock if is_blacksmith else _arcanist_stock

	# ABA 3: REPARAR & MANUTENÇÃO DA FORJA
	if _active_vendor_tab == 3:
		_populate_repair_tab(is_blacksmith)
		_vendor_page_label.text = "1 / 1"
		_vendor_prev_page_btn.disabled = true
		_vendor_next_page_btn.disabled = true
		_rebuild_vendor_inspector()
		return

	# Coleta itens filtrados conforme a aba ativa (0 = Comprar, 1 = Recomprar, 2 = Vender)
	var filtered_entries: Array[Dictionary] = []
	if _active_vendor_tab == 0:
		for it in stock:
			if _matches_vendor_filters(it):
				filtered_entries.append({"item": it, "price": it.get_buy_price(), "mode": "buy", "stock": stock})
	elif _active_vendor_tab == 1:
		for b_entry in _buyback_items:
			var bit: ItemInstance = b_entry.get("item", null) as ItemInstance
			if _matches_vendor_filters(bit):
				filtered_entries.append({"item": bit, "price": int(b_entry.get("price", 5)), "mode": "buyback", "raw": b_entry})
	elif _active_vendor_tab == 2:
		if backpack != null:
			for bp_it in backpack.items:
				if _matches_vendor_filters(bp_it):
					filtered_entries.append({"item": bp_it, "price": bp_it.get_sell_value(), "mode": "sell"})

	var total_pages: int = maxi(1, int(ceil(float(filtered_entries.size()) / float(ITEMS_PER_PAGE))))
	_current_page = clampi(_current_page, 0, total_pages - 1)
	_vendor_page_label.text = "%d / %d" % [_current_page + 1, total_pages]
	_vendor_prev_page_btn.disabled = (_current_page <= 0)
	_vendor_next_page_btn.disabled = (_current_page >= total_pages - 1)

	# Garante que há um item selecionado válido para o Painel de Inspeção à direita
	var found_selected: bool = false
	for fe in filtered_entries:
		if fe["item"] == _selected_vendor_item:
			found_selected = true
			if fe["mode"] == "buyback":
				_selected_buyback_entry = fe["raw"]
			break
	if not found_selected:
		if not filtered_entries.is_empty():
			_selected_vendor_item = filtered_entries[0]["item"]
			if filtered_entries[0]["mode"] == "buyback":
				_selected_buyback_entry = filtered_entries[0]["raw"]
		else:
			_selected_vendor_item = null
			_selected_buyback_entry = {}

	if filtered_entries.is_empty():
		var empty_lbl := Label.new()
		if _active_vendor_tab == 1:
			empty_lbl.text = "\nNenhum item na aba Recomprar.\nQuando você vender um item, poderá recuperá-lo aqui pelo mesmo valor!"
		elif _active_vendor_tab == 2:
			empty_lbl.text = "\nNenhum item correspondente na sua Mochila para vender."
		else:
			empty_lbl.text = "\nNenhum item encontrado com os filtros selecionados."
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", COLOR_MUTED)
		_vendor_list_vbox.add_child(empty_lbl)
	else:
		var start_idx: int = _current_page * ITEMS_PER_PAGE
		var end_idx: int = mini(filtered_entries.size(), start_idx + ITEMS_PER_PAGE)
		for i in range(start_idx, end_idx):
			var entry: Dictionary = filtered_entries[i]
			_vendor_list_vbox.add_child(_make_standardized_item_row(entry))

	_rebuild_vendor_inspector()


func _make_standardized_item_row(entry: Dictionary) -> PanelContainer:
	var item: ItemInstance = entry["item"] as ItemInstance
	var price: int = int(entry["price"])
	var mode: String = String(entry["mode"])
	var is_selected: bool = (item == _selected_vendor_item)

	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	var st := StyleBoxFlat.new()
	if is_selected:
		st.bg_color = Color(0.18, 0.14, 0.08, 0.98)
		st.border_color = COLOR_GOLD_BRIGHT
		st.set_border_width_all(2)
		st.shadow_color = Color(0.95, 0.75, 0.25, 0.22)
		st.shadow_size = 6
	else:
		st.bg_color = Color(0.085, 0.078, 0.098, 0.95)
		st.border_color = Color(0.32, 0.26, 0.18, 0.85)
		st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 4
	st.content_margin_bottom = 4
	row.add_theme_stylebox_override("panel", st)

	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_selected_vendor_item = item
			if mode == "buyback":
				_selected_buyback_entry = entry.get("raw", {})
			_refresh_vendor_catalog_and_inspector()
	)
	var price_label_str: String = "🪙 Preço: [color=#f5d168]%d Ouro[/color]" % price
	row.mouse_entered.connect(func() -> void:
		_show_item_tooltip(item, "[Clique para inspecionar ou comprar]", price_label_str)
	)
	row.mouse_exited.connect(_hide_tooltip)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hb)

	# 1. Ícone emoldurado (42x42) com fundo roxo/índigo escuro igual à referência
	var icon_box := PanelContainer.new()
	icon_box.custom_minimum_size = Vector2(42, 42)
	icon_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ib_bg := Color(0.14, 0.10, 0.20, 0.96) if item.rarity != ItemInstance.ItemRarity.NORMAL else Color(0.09, 0.08, 0.12, 0.96)
	var ib_st := _slot_style(ib_bg, item.get_rarity_color(), 1)
	ib_st.set_corner_radius_all(3)
	ib_st.content_margin_left = 3
	ib_st.content_margin_right = 3
	ib_st.content_margin_top = 3
	ib_st.content_margin_bottom = 3
	icon_box.add_theme_stylebox_override("panel", ib_st)

	var icon_rect := TextureRect.new()
	icon_rect.texture = ItemIconFactory.get_icon_for_item(item, true)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(36, 36)
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_box.add_child(icon_rect)
	hb.add_child(icon_box)

	# 2. Nome do Item + Linha de Atributos com ícones
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vb)

	var nl := Label.new()
	nl.text = item.get_display_name()
	nl.add_theme_font_size_override("font_size", 13)
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

	# 3. Botão Duplo Direita ("🪙 65 Ouro / Comprar")
	var action_word: String = "Comprar"
	var can_act: bool = current_gold >= price
	if mode == "buyback":
		action_word = "Recomprar"
	elif mode == "sell":
		action_word = "Vender"
		can_act = true

	var act_btn := Button.new()
	act_btn.text = "🪙 %d Ouro\n%s" % [price, action_word]
	act_btn.custom_minimum_size = Vector2(96, 40)
	act_btn.focus_mode = Control.FOCUS_NONE
	act_btn.disabled = not can_act
	act_btn.add_theme_font_size_override("font_size", 11)
	act_btn.add_theme_color_override("font_color", Color(0.98, 0.90, 0.65) if can_act else Color(0.65, 0.45, 0.45))

	var ab_st := StyleBoxFlat.new()
	ab_st.bg_color = Color(0.14, 0.11, 0.07, 0.96) if can_act else Color(0.14, 0.08, 0.08, 0.90)
	ab_st.border_color = COLOR_BRONZE_BORDER if can_act else Color(0.45, 0.22, 0.22, 0.8)
	ab_st.set_border_width_all(1)
	ab_st.set_corner_radius_all(3)
	var ab_hov := ab_st.duplicate() as StyleBoxFlat
	ab_hov.bg_color = ab_st.bg_color.lightened(0.14)
	ab_hov.border_color = COLOR_GOLD_BRIGHT
	act_btn.add_theme_stylebox_override("normal", ab_st)
	act_btn.add_theme_stylebox_override("hover", ab_hov)
	act_btn.add_theme_stylebox_override("pressed", ab_hov)

	act_btn.pressed.connect(func() -> void:
		_selected_vendor_item = item
		_execute_vendor_entry_action(entry)
	)
	hb.add_child(act_btn)

	return row


func _execute_vendor_entry_action(entry: Dictionary) -> void:
	var item: ItemInstance = entry.get("item", null) as ItemInstance
	var mode: String = String(entry.get("mode", "buy"))
	if item == null:
		return
	if mode == "buy":
		var stock_arr: Array[ItemInstance] = entry.get("stock", _blacksmith_stock)
		_attempt_buy_item(item, stock_arr)
	elif mode == "buyback":
		var raw_entry: Dictionary = entry.get("raw", {})
		_attempt_buyback_item(raw_entry)
	elif mode == "sell":
		_attempt_sell_backpack_item(item)


func _attempt_sell_backpack_item(item: ItemInstance) -> void:
	if item == null or backpack == null or not backpack.items.has(item):
		return
	var sell_val: int = item.get_sell_value()
	var nm: String = item.get_display_name()
	_hide_tooltip()
	backpack.remove_item(item)
	register_sold_item(item, sell_val)
	current_gold += sell_val
	gold_changed.emit(current_gold)
	_refresh_vendor_catalog_and_inspector()
	show_feedback("✦ Vendido: %s por +%d Ouro! (Disponível em 🔄 Recomprar)" % [nm, sell_val], false)


func _rebuild_vendor_inspector() -> void:
	if _vendor_inspector_box == null:
		return
	for child in _vendor_inspector_box.get_children():
		_vendor_inspector_box.remove_child(child)
		child.queue_free()

	if _selected_vendor_item == null or _selected_vendor_item.definition == null:
		var empty_info := Label.new()
		empty_info.text = "\n\nSelecione um item na lista ao lado para inspecionar seus detalhes, tier e comparação."
		empty_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_info.add_theme_font_size_override("font_size", 12)
		empty_info.add_theme_color_override("font_color", COLOR_MUTED)
		_vendor_inspector_box.add_child(empty_info)
		return

	var item: ItemInstance = _selected_vendor_item
	var def: ItemDefinition = item.definition

	# 1. Vitrine Grande Superior (200x132) com fundo nebulosa roxo-escuro e moldura dourada
	var showcase := PanelContainer.new()
	showcase.custom_minimum_size = Vector2(200, 134)
	var sc_st := _slot_style(Color(0.085, 0.055, 0.125, 0.98), COLOR_BRONZE_BORDER, 1)
	sc_st.set_corner_radius_all(4)
	sc_st.content_margin_left = 10
	sc_st.content_margin_right = 10
	sc_st.content_margin_top = 8
	sc_st.content_margin_bottom = 8
	showcase.add_theme_stylebox_override("panel", sc_st)
	_vendor_inspector_box.add_child(showcase)

	var big_icon := TextureRect.new()
	big_icon.texture = ItemIconFactory.get_icon_for_item(item, false)
	big_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big_icon.custom_minimum_size = Vector2(180, 114)
	showcase.add_child(big_icon)

	# 2. Nome do Item em Destaque
	var title_lbl := Label.new()
	title_lbl.text = item.get_display_name()
	title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_lbl.add_theme_font_size_override("font_size", 15)
	title_lbl.add_theme_color_override("font_color", item.get_rarity_color())
	_vendor_inspector_box.add_child(title_lbl)

	# 3. Subtítulo da Categoria + Badge de Tier [T1 / T2 / T3]
	var sub_row := HBoxContainer.new()
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_vendor_inspector_box.add_child(sub_row)

	var cat_lbl := Label.new()
	cat_lbl.text = item.get_slot_display_name()
	cat_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cat_lbl.add_theme_font_size_override("font_size", 12)
	cat_lbl.add_theme_color_override("font_color", COLOR_MUTED)
	sub_row.add_child(cat_lbl)

	var tier_badge := PanelContainer.new()
	var tb_st := _slot_style(Color(0.12, 0.10, 0.14, 0.96), COLOR_BRONZE_BORDER, 1)
	tb_st.set_corner_radius_all(3)
	tb_st.content_margin_left = 6
	tb_st.content_margin_right = 6
	tb_st.content_margin_top = 1
	tb_st.content_margin_bottom = 1
	tier_badge.add_theme_stylebox_override("panel", tb_st)
	var tier_lbl := Label.new()
	tier_lbl.text = "T%d" % clampi(item.item_level, 1, 3)
	tier_lbl.add_theme_font_size_override("font_size", 11)
	tier_lbl.add_theme_color_override("font_color", COLOR_PARCHMENT)
	tier_badge.add_child(tier_lbl)
	sub_row.add_child(tier_badge)

	var sep1 := HSeparator.new()
	sep1.add_theme_color_override("separator", COLOR_BORDER_SUBTLE)
	_vendor_inspector_box.add_child(sep1)

	# 4. Atributo Principal Alinhado (Esquerda: Ícone + Nome | Direita: Valor)
	if def.category == ItemDefinition.ItemCategory.WEAPON_1H or def.category == ItemDefinition.ItemCategory.WEAPON_2H:
		var dmg: Vector2i = item.get_damage_range()
		_add_inspector_stat_row("⚔  Dano", "%d – %d" % [dmg.x, dmg.y])
	elif item.get_total_armor() > 0:
		_add_inspector_stat_row("🛡  Armadura", "%d" % item.get_total_armor())
	elif def.base_health > 0:
		_add_inspector_stat_row("♥  Vida", "+%d" % def.base_health)

	for imp in def.implicit_affixes:
		if imp != null:
			var imp_lbl := Label.new()
			imp_lbl.text = "◆ " + imp.display_text
			imp_lbl.add_theme_font_size_override("font_size", 11)
			imp_lbl.add_theme_color_override("font_color", Color(0.90, 0.84, 0.66))
			_vendor_inspector_box.add_child(imp_lbl)

	for af in item.explicit_affixes:
		if af != null:
			var af_lbl := Label.new()
			af_lbl.text = "• " + af.display_text
			af_lbl.add_theme_font_size_override("font_size", 11)
			af_lbl.add_theme_color_override("font_color", item.get_rarity_color())
			_vendor_inspector_box.add_child(af_lbl)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("separator", COLOR_BORDER_SUBTLE)
	_vendor_inspector_box.add_child(sep2)

	# 5. Descrição Temática (Lore)
	var lore_lbl := Label.new()
	lore_lbl.text = item.get_lore_description()
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lore_lbl.add_theme_font_size_override("font_size", 11)
	lore_lbl.add_theme_color_override("font_color", Color(0.68, 0.63, 0.56))
	_vendor_inspector_box.add_child(lore_lbl)

	_vendor_inspector_box.add_spacer(false)

	# 6. Botão Principal Dourado no Rodapé ("🪙 Comprar por 65 Ouro")
	var price: int = item.get_buy_price()
	var btn_caption: String = "🪙  Comprar por %d Ouro" % price
	var can_afford: bool = current_gold >= price

	if _active_vendor_tab == 1:
		price = int(_selected_buyback_entry.get("price", item.get_sell_value()))
		btn_caption = "🪙  Recomprar por %d Ouro" % price
		can_afford = current_gold >= price
	elif _active_vendor_tab == 2:
		price = item.get_sell_value()
		btn_caption = "🪙  Vender por %d Ouro" % price
		can_afford = true

	var main_buy_btn := Button.new()
	main_buy_btn.text = btn_caption
	main_buy_btn.custom_minimum_size = Vector2(0, 40)
	main_buy_btn.focus_mode = Control.FOCUS_NONE
	main_buy_btn.disabled = not can_afford
	main_buy_btn.add_theme_font_size_override("font_size", 13)
	main_buy_btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.76) if can_afford else Color(0.65, 0.45, 0.45))

	var mb_st := StyleBoxFlat.new()
	mb_st.bg_color = Color(0.28, 0.19, 0.08, 0.98) if can_afford else Color(0.16, 0.09, 0.09, 0.92)
	mb_st.border_color = COLOR_GOLD_BRIGHT if can_afford else Color(0.45, 0.22, 0.22, 0.8)
	mb_st.set_border_width_all(2)
	mb_st.set_corner_radius_all(4)
	var mb_hov := mb_st.duplicate() as StyleBoxFlat
	mb_hov.bg_color = mb_st.bg_color.lightened(0.14)
	main_buy_btn.add_theme_stylebox_override("normal", mb_st)
	main_buy_btn.add_theme_stylebox_override("hover", mb_hov)
	main_buy_btn.add_theme_stylebox_override("pressed", mb_hov)

	main_buy_btn.pressed.connect(func() -> void:
		if _active_vendor_tab == 0:
			var stock_arr: Array[ItemInstance] = _blacksmith_stock if current_station_id == "vendor_physical" else _arcanist_stock
			_attempt_buy_item(item, stock_arr)
		elif _active_vendor_tab == 1:
			_attempt_buyback_item(_selected_buyback_entry)
		elif _active_vendor_tab == 2:
			_attempt_sell_backpack_item(item)
	)
	_vendor_inspector_box.add_child(main_buy_btn)


func _add_inspector_stat_row(left_txt: String, right_txt: String) -> void:
	var hb := HBoxContainer.new()
	var l := Label.new()
	l.text = left_txt
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", COLOR_PARCHMENT)
	hb.add_child(l)

	var r := Label.new()
	r.text = right_txt
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	r.add_theme_font_size_override("font_size", 13)
	r.add_theme_color_override("font_color", Color(1.0, 0.98, 0.92))
	hb.add_child(r)
	_vendor_inspector_box.add_child(hb)


func _populate_repair_tab(is_blacksmith: bool) -> void:
	var info_card := PanelContainer.new()
	info_card.add_theme_stylebox_override("panel", _slot_style(Color(0.08, 0.07, 0.09, 0.95), COLOR_BRONZE_BORDER, 1))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	info_card.add_child(vb)

	var title := Label.new()
	title.text = "🔨  MANUTENÇÃO DE EQUIPAMENTO & BANCADA"
	title.add_theme_font_size_override("font_size", 14)
	title.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	vb.add_child(title)

	var desc := Label.new()
	desc.text = "Mantenha suas armas afiadas e armaduras polidas em estado impecável (100% de integridade), ou encomende uma nova remessa de mercadorias."
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 12)
	desc.add_theme_color_override("font_color", COLOR_PARCHMENT)
	vb.add_child(desc)

	var repair_btn := _make_gothic_button("🔨  REPARAR TODO O EQUIPAMENTO EQUIPADO (100% INTEGRIDADE — GRÁTIS)", false)
	repair_btn.pressed.connect(func() -> void:
		show_feedback("✦ Todas as suas armas e armaduras equipadas foram reparadas e polidas na forja!", false)
	)
	vb.add_child(repair_btn)

	var restock_cost: int = 15
	var restock_btn := _make_gothic_button("🔄  ENCOMENDAR NOVA REMESSA DA LOJA (%d 🪙 Ouro)" % restock_cost, false)
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
		_active_vendor_tab = 0
		_current_page = 0
		_refresh_current_station_content()
		show_feedback("✦ Nova remessa de itens chegou à bancada!", false)
	)
	vb.add_child(restock_btn)

	_vendor_list_vbox.add_child(info_card)


func _make_sidebar_mode_button(icon_str: String, label_str: String, is_active: bool) -> Button:
	var btn := Button.new()
	btn.text = "  %s    %s" % [icon_str, label_str]
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.custom_minimum_size = Vector2(0, 38)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 13)
	btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78) if is_active else COLOR_PARCHMENT)

	var st := StyleBoxFlat.new()
	if is_active:
		st.bg_color = Color(0.24, 0.16, 0.07, 0.98)
		st.border_color = COLOR_GOLD_BRIGHT
		st.set_border_width_all(2)
	else:
		st.bg_color = Color(0.08, 0.072, 0.09, 0.95)
		st.border_color = COLOR_BORDER_SUBTLE
		st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	st.content_margin_left = 10
	st.content_margin_right = 10
	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = st.bg_color.lightened(0.12)
	hov.border_color = COLOR_GOLD_TITLE
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", st)
	return btn


func _make_category_pill_button(text_val: String, is_active: bool) -> Button:
	var btn := Button.new()
	btn.text = text_val
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(74, 30)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_color_override("font_color", Color(1.0, 0.94, 0.74) if is_active else COLOR_PARCHMENT)

	var st := StyleBoxFlat.new()
	if is_active:
		st.bg_color = Color(0.28, 0.18, 0.07, 0.98)
		st.border_color = COLOR_GOLD_BRIGHT
		st.set_border_width_all(2)
	else:
		st.bg_color = Color(0.085, 0.078, 0.098, 0.94)
		st.border_color = COLOR_BORDER_SUBTLE
		st.set_border_width_all(1)
	st.set_corner_radius_all(4)
	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = st.bg_color.lightened(0.12)
	hov.border_color = COLOR_GOLD_TITLE
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", st)
	return btn


func _make_page_arrow_button(txt: String) -> Button:
	var btn := Button.new()
	btn.text = txt
	btn.custom_minimum_size = Vector2(28, 26)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	var st := _slot_style(Color(0.09, 0.08, 0.10, 0.95), COLOR_BRONZE_BORDER, 1)
	st.set_corner_radius_all(3)
	st.content_margin_left = 4
	st.content_margin_right = 4
	st.content_margin_top = 2
	st.content_margin_bottom = 2
	var hov := st.duplicate() as StyleBoxFlat
	hov.bg_color = st.bg_color.lightened(0.15)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hov)
	btn.add_theme_stylebox_override("pressed", hov)
	return btn


func _attempt_buyback_item(entry: Dictionary) -> void:
	var item: ItemInstance = entry.get("item", null) as ItemInstance
	var sold_price: int = int(entry.get("price", 5))
	if item == null or backpack == null:
		return
	if current_gold < sold_price:
		show_feedback("⚠ Ouro insuficiente para recomprar! Você precisa de %d Ouro." % sold_price, true)
		return
	if not backpack.can_fit_item(item):
		var gsz: Vector2i = item.get_grid_size()
		show_feedback("⚠ Sua Mochila não tem espaço livre (%dx%d) para recomprar este item!" % [gsz.x, gsz.y], true)
		return

	_hide_tooltip()
	current_gold -= sold_price
	_buyback_items.erase(entry)
	backpack.auto_add_item(item)
	gold_changed.emit(current_gold)
	_refresh_vendor_catalog_and_inspector()
	show_feedback("✦ Recomprado: %s pelo mesmo valor da venda (%d Ouro)!" % [item.get_display_name(), sold_price], false)


func _build_short_item_summary(item: ItemInstance) -> String:
	var def: ItemDefinition = item.definition
	var parts: Array[String] = []
	if def.category == ItemDefinition.ItemCategory.WEAPON_1H or def.category == ItemDefinition.ItemCategory.WEAPON_2H:
		var dmg: Vector2i = item.get_damage_range()
		parts.append("⚔ Dano %d – %d" % [dmg.x, dmg.y])
	if item.get_total_armor() > 0:
		parts.append("🛡 Armadura %d" % item.get_total_armor())
	if def.base_health > 0:
		parts.append("💙 +%d Vida" % def.base_health)
	for imp in def.implicit_affixes:
		if imp != null:
			parts.append(imp.display_text)
	for af in item.explicit_affixes:
		if af != null:
			parts.append(af.display_text)
	return "   |   ".join(parts)


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

	if not backpack.can_fit_item(item_to_give):
		var gsz: Vector2i = item_to_give.get_grid_size()
		show_feedback("⚠ Sua Mochila não tem espaço livre (%dx%d) para este item!" % [gsz.x, gsz.y], true)
		return

	current_gold -= price
	backpack.auto_add_item(item_to_give)
	if not is_consumable:
		stock_array.erase(item)
	gold_changed.emit(current_gold)
	_refresh_vendor_catalog_and_inspector()
	show_feedback("✦ Comprado: %s (-%d Ouro)!" % [item_to_give.get_display_name(), price], false)


# ===============================================================
# 3. SÁBIO IDENTIFICADOR, CURANDEIRO & RESET DE BUILD (FIEL À IMAGEM)
# ===============================================================
func _load_ui_texture(res_path: String) -> Texture2D:
	if _portrait_cache.has(res_path):
		return _portrait_cache[res_path] as Texture2D
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path):
		var img := Image.load_from_file(abs_path)
		if img != null and not img.is_empty():
			var tex := ImageTexture.create_from_image(img)
			_portrait_cache[res_path] = tex
			return tex
	if ResourceLoader.exists(res_path):
		var rtex: Texture2D = load(res_path) as Texture2D
		if rtex != null:
			_portrait_cache[res_path] = rtex
			return rtex
	return null


func _populate_identifier_respec() -> void:
	_title_label.text = "📜   SÁBIO ANCESTRAL  —  IDENTIFICAR, CURAR & RESETAR"

	var unid_count: int = 0
	if backpack != null:
		for it in backpack.items:
			if it != null and not it.is_identified:
				unid_count += 1
	if stash != null:
		for it in stash.items:
			if it != null and not it.is_identified:
				unid_count += 1

	var body_hbox := HBoxContainer.new()
	body_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_hbox.add_theme_constant_override("separation", 16)
	_content_box.add_child(body_hbox)

	# ---------------------------------------------------------------
	# COLUNA ESQUERDA: RETRATO ILUSTRADO DO SÁBIO NO ALTAR ARCANO
	# ---------------------------------------------------------------
	var portrait_frame := PanelContainer.new()
	portrait_frame.custom_minimum_size = Vector2(236, 392)
	portrait_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var pf_style := _slot_style(Color(0.06, 0.05, 0.075, 0.98), COLOR_BRONZE_BORDER, 2)
	pf_style.set_corner_radius_all(6)
	pf_style.content_margin_left = 3
	pf_style.content_margin_right = 3
	pf_style.content_margin_top = 3
	pf_style.content_margin_bottom = 3
	portrait_frame.add_theme_stylebox_override("panel", pf_style)
	body_hbox.add_child(portrait_frame)

	var portrait_tex := TextureRect.new()
	portrait_tex.texture = _load_ui_texture("res://assets/ui/sage_portrait.png")
	portrait_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait_frame.add_child(portrait_tex)

	# ---------------------------------------------------------------
	# COLUNA DIREITA: CITAÇÃO + 3 CARDS DE SERVIÇO + DICAS DO SÁBIO
	# ---------------------------------------------------------------
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 12)
	body_hbox.add_child(right_vbox)

	# 1. Citação Superior Centralizada
	var quote_lbl := Label.new()
	quote_lbl.text = "\"Fique um instante e escute... Posso revelar o poder oculto das suas relíquias,\ncurar suas feridas ou purificar seus atributos.\""
	quote_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quote_lbl.add_theme_font_size_override("font_size", 13)
	quote_lbl.add_theme_color_override("font_color", COLOR_PARCHMENT)
	right_vbox.add_child(quote_lbl)

	var sep_quote := HSeparator.new()
	sep_quote.add_theme_color_override("separator", COLOR_BORDER_SUBTLE)
	right_vbox.add_child(sep_quote)

	# 2. Linha dos 3 Cards Verticais Lado a Lado
	var cards_hbox := HBoxContainer.new()
	cards_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cards_hbox.add_theme_constant_override("separation", 12)
	right_vbox.add_child(cards_hbox)

	# Card 1: IDENTIFICAR ITENS
	var id_desc: String = "Revela o poder oculto dos\nitens não identificados."
	if unid_count > 0:
		id_desc += "\n(%d pendente(s))" % unid_count
	var id_btn_txt: String = "GRÁTIS" if unid_count == 0 else "GRÁTIS (%d)" % unid_count
	cards_hbox.add_child(_make_sage_service_card(
		"res://assets/ui/sage_icon_identify.png",
		"IDENTIFICAR ITENS",
		id_desc,
		id_btn_txt,
		Color(0.085, 0.055, 0.135, 0.97),
		Color(0.24, 0.14, 0.36, 0.98),
		Color(0.68, 0.48, 0.90, 0.95),
		func() -> void:
			identify_items_requested.emit()
			_refresh_current_station_content()
			show_feedback("✦ Todos os itens na Mochila e no Baú foram identificados pelo Sábio!", false)
	))

	# Card 2: BÊNÇÃO DE CURA
	cards_hbox.add_child(_make_sage_service_card(
		"res://assets/ui/sage_icon_heal.png",
		"BÊNÇÃO DE CURA",
		"Restaura 100% da\nsua Vida.",
		"GRÁTIS",
		Color(0.055, 0.095, 0.08, 0.97),
		Color(0.20, 0.14, 0.32, 0.98),
		Color(0.62, 0.45, 0.85, 0.95),
		func() -> void:
			heal_player_requested.emit()
			show_feedback("✦ A luz ancestral restaurou toda a sua Vida!", false)
	))

	# Card 3: PURIFICAR & RESETAR
	cards_hbox.add_child(_make_sage_service_card(
		"res://assets/ui/sage_icon_respec.png",
		"PURIFICAR & RESETAR",
		"Redefine os\natributos base do seu\npersonagem.",
		"RESETAR",
		Color(0.14, 0.045, 0.055, 0.97),
		Color(0.42, 0.10, 0.11, 0.98),
		Color(0.88, 0.32, 0.30, 0.95),
		func() -> void:
			respec_build_requested.emit()
			show_feedback("✦ Seus atributos base foram restaurados ao estado original!", false)
	))

	# 3. Quadro Inferior: "📖 DICAS DO SÁBIO DE VELEN"
	var tips_panel := PanelContainer.new()
	var tp_style := _slot_style(Color(0.06, 0.058, 0.078, 0.96), COLOR_BRONZE_BORDER, 1)
	tp_style.set_corner_radius_all(5)
	tp_style.content_margin_left = 14
	tp_style.content_margin_right = 14
	tp_style.content_margin_top = 10
	tp_style.content_margin_bottom = 10
	tips_panel.add_theme_stylebox_override("panel", tp_style)
	right_vbox.add_child(tips_panel)

	var tips_vbox := VBoxContainer.new()
	tips_vbox.add_theme_constant_override("separation", 6)
	tips_panel.add_child(tips_vbox)

	var tips_title := Label.new()
	tips_title.text = "📖   DICAS DO SÁBIO DE VELEN"
	tips_title.add_theme_font_size_override("font_size", 13)
	tips_title.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	tips_vbox.add_child(tips_title)

	var sep_tips := HSeparator.new()
	sep_tips.add_theme_color_override("separator", COLOR_BORDER_SUBTLE)
	tips_vbox.add_child(sep_tips)

	var tips_rt := RichTextLabel.new()
	tips_rt.bbcode_enabled = true
	tips_rt.fit_content = true
	tips_rt.scroll_active = false
	tips_rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tips_rt.text = (
		"[color=#f2cb6f]✦[/color]  [color=#e6dfd3]Passe o mouse sobre qualquer item na Mochila, Baú ou Mercador para ver as setas de\n"
		+ "    comparação ([color=#4dff6b]▲ verde = melhora[/color] / [color=#ff4d4d]▼ vermelha = piora[/color]).[/color]\n"
		+ "[color=#f2cb6f]✦[/color]  [color=#e6dfd3]Requisitos de Força, Agilidade e Inteligência são cumpridos equipando Anéis, Amuletos e\n"
		+ "    subindo de Nível em combate.[/color]"
	)
	tips_vbox.add_child(tips_rt)


func _make_sage_service_card(
	icon_res: String,
	card_title: String,
	card_desc: String,
	btn_caption: String,
	card_bg: Color,
	btn_bg: Color,
	btn_border: Color,
	on_click: Callable
) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.custom_minimum_size = Vector2(180, 212)

	var c_style := StyleBoxFlat.new()
	c_style.bg_color = card_bg
	c_style.border_color = COLOR_BRONZE_BORDER
	c_style.set_border_width_all(2)
	c_style.set_corner_radius_all(6)
	c_style.content_margin_left = 12
	c_style.content_margin_right = 12
	c_style.content_margin_top = 12
	c_style.content_margin_bottom = 12
	card.add_theme_stylebox_override("panel", c_style)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)

	var icon_rect := TextureRect.new()
	icon_rect.texture = _load_ui_texture(icon_res)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(96, 74)
	vb.add_child(icon_rect)

	var t_lbl := Label.new()
	t_lbl.text = card_title
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.add_theme_font_size_override("font_size", 14)
	t_lbl.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	vb.add_child(t_lbl)

	var d_lbl := Label.new()
	d_lbl.text = card_desc
	d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	d_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	d_lbl.add_theme_font_size_override("font_size", 11)
	d_lbl.add_theme_color_override("font_color", COLOR_PARCHMENT)
	vb.add_child(d_lbl)

	var act_btn := Button.new()
	act_btn.text = btn_caption
	act_btn.custom_minimum_size = Vector2(0, 34)
	act_btn.focus_mode = Control.FOCUS_NONE
	act_btn.add_theme_font_size_override("font_size", 13)
	act_btn.add_theme_color_override("font_color", Color(0.98, 0.96, 0.94))

	var b_st := StyleBoxFlat.new()
	b_st.bg_color = btn_bg
	b_st.border_color = btn_border
	b_st.set_border_width_all(2)
	b_st.set_corner_radius_all(4)
	var b_hov := b_st.duplicate() as StyleBoxFlat
	b_hov.bg_color = b_st.bg_color.lightened(0.16)
	b_hov.border_color = COLOR_GOLD_BRIGHT
	act_btn.add_theme_stylebox_override("normal", b_st)
	act_btn.add_theme_stylebox_override("hover", b_hov)
	act_btn.add_theme_stylebox_override("pressed", b_hov)
	act_btn.pressed.connect(on_click)
	vb.add_child(act_btn)

	return card


# ===============================================================
# 4. WAYPOINT ANCESTRAL — TELEPORTE DE ZONAS
# ===============================================================
func _populate_waypoint() -> void:
	_title_label.text = "✦  WAYPOINT ANCESTRAL — TELEPORTE"
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
