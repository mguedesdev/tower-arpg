extends PanelContainer
class_name InventoryEquipmentModal
## Modal de Inventário Espacial em Grid (Diablo 2 / PoE) + Paperdoll de Equipamento.
## Tecla de atalho: [I] ou [TAB].

signal closed()

const BG_COLOR := Color(0.045, 0.04, 0.045, 0.96)
const BORDER_COLOR := Color(0.48, 0.38, 0.22, 0.95)
const GOLD_COLOR := Color(0.92, 0.74, 0.35)
const TEXT_COLOR := Color(0.92, 0.89, 0.82)
const RED_ALERT := Color(1.0, 0.35, 0.35)
const CELL_SIZE := 36

var inventory: SpatialInventoryGrid
var equipment: CharacterEquipment
var stats: CharacterStats

# Estado de arrasto
var _held_item: ItemInstance = null
var _held_preview: TextureRect

# Componentes da UI
var _grid_container: Control
var _paperdoll_slots: Dictionary = {}    ## EquipmentSlot -> Panel
var _stats_label: RichTextLabel
var _tooltip_panel: PanelContainer
var _tooltip_text: RichTextLabel


func _ready() -> void:
	name = "InventoryEquipmentModal"
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("blocking_modal")
	_build_ui()


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


func open_inventory() -> void:
	visible = true
	_refresh_all()


func close_inventory() -> void:
	if _held_item != null:
		# Devolve item seguro à mochila se estava na mão
		inventory.auto_add_item(_held_item)
		_set_held_item(null)
	visible = false
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
		elif event.keycode == KEY_ESCAPE and visible:
			close_inventory()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var root_style := StyleBoxFlat.new()
	root_style.bg_color = BG_COLOR
	root_style.border_color = BORDER_COLOR
	root_style.set_border_width_all(3)
	root_style.set_corner_radius_all(6)
	root_style.shadow_color = Color(0, 0, 0, 0.7)
	root_style.shadow_size = 10
	root_style.content_margin_left = 18
	root_style.content_margin_right = 18
	root_style.content_margin_top = 14
	root_style.content_margin_bottom = 16
	add_theme_stylebox_override("panel", root_style)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 10)
	add_child(main_vbox)

	# Cabeçalho com Título e Fechar [X]
	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "⚔ EQUIPAMENTO DO CAVALEIRO & MOCHILA (GRID)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", GOLD_COLOR)
	header.add_child(title)
	header.add_spacer(false)

	var close_btn := Button.new()
	close_btn.text = " [X] "
	close_btn.add_theme_font_size_override("font_size", 13)
	close_btn.add_theme_color_override("font_color", GOLD_COLOR)
	close_btn.pressed.connect(close_inventory)
	header.add_child(close_btn)
	main_vbox.add_child(header)

	# Corpo dividido: Esquerda = Paperdoll + Atributos | Direita = Grid da Mochila
	var body_hbox := HBoxContainer.new()
	body_hbox.add_theme_constant_override("separation", 24)
	main_vbox.add_child(body_hbox)

	# --- PAINEL ESQUERDO: PAPERDOLL ---
	var left_vbox := VBoxContainer.new()
	left_vbox.add_theme_constant_override("separation", 8)
	body_hbox.add_child(left_vbox)

	var doll_title := Label.new()
	doll_title.text = "SLOTS DE EQUIPAMENTO"
	doll_title.add_theme_font_size_override("font_size", 12)
	doll_title.add_theme_color_override("font_color", GOLD_COLOR)
	doll_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_vbox.add_child(doll_title)

	var doll_root := Control.new()
	doll_root.custom_minimum_size = Vector2(250, 360)
	left_vbox.add_child(doll_root)
	_build_paperdoll(doll_root)

	# Atributos do personagem abaixo do Paperdoll
	_stats_label = RichTextLabel.new()
	_stats_label.bbcode_enabled = true
	_stats_label.fit_content = true
	_stats_label.custom_minimum_size = Vector2(250, 95)
	left_vbox.add_child(_stats_label)

	# Separador vertical
	var v_sep := VSeparator.new()
	body_hbox.add_child(v_sep)

	# --- PAINEL DIREITO: MOCHILA (GRID 10x5) ---
	var right_vbox := VBoxContainer.new()
	right_vbox.add_theme_constant_override("separation", 8)
	body_hbox.add_child(right_vbox)

	var grid_title := Label.new()
	grid_title.text = "MOCHILA (10 x 5 ESPAÇOS)"
	grid_title.add_theme_font_size_override("font_size", 12)
	grid_title.add_theme_color_override("font_color", GOLD_COLOR)
	right_vbox.add_child(grid_title)

	_grid_container = Control.new()
	_grid_container.custom_minimum_size = Vector2(10 * CELL_SIZE, 5 * CELL_SIZE)
	_grid_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_grid_container.gui_input.connect(_on_grid_gui_input)
	right_vbox.add_child(_grid_container)

	var hint := Label.new()
	hint.text = "• Clique Esquerdo: pegar/soltar  |  Clique Direito: equipar direto"
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
	right_vbox.add_child(hint)

	# Preview flutuante do item seguro na mão
	_held_preview = TextureRect.new()
	_held_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_held_preview.visible = false
	_held_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_held_preview.modulate = Color(1, 1, 1, 0.85)
	add_child(_held_preview)

	# Tooltip flutuante
	_tooltip_panel = PanelContainer.new()
	_tooltip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tooltip_panel.visible = false
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.06, 0.05, 0.07, 0.98)
	t_style.border_color = GOLD_COLOR
	t_style.set_border_width_all(2)
	t_style.set_corner_radius_all(4)
	t_style.content_margin_left = 10
	t_style.content_margin_right = 10
	t_style.content_margin_top = 8
	t_style.content_margin_bottom = 8
	_tooltip_panel.add_theme_stylebox_override("panel", t_style)
	_tooltip_text = RichTextLabel.new()
	_tooltip_text.bbcode_enabled = true
	_tooltip_text.fit_content = true
	_tooltip_text.custom_minimum_size = Vector2(230, 40)
	_tooltip_panel.add_child(_tooltip_text)
	add_child(_tooltip_panel)


func _build_paperdoll(root: Control) -> void:
	# Posições clássicas do boneco (com Peitoral 4x2 e Cinto ajustado)
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.HELMET, "Elmo", Vector2(96, 6), Vector2(2, 2))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.AMULET, "Amul.", Vector2(174, 20), Vector2(1, 1))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.CHEST, "Peitoral", Vector2(96, 84), Vector2(2, 4))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.MAIN_HAND, "Arma 1H/2H", Vector2(16, 84), Vector2(2, 4))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.OFF_HAND, "Escudo", Vector2(174, 84), Vector2(2, 4))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.GLOVES, "Luvas", Vector2(16, 234), Vector2(2, 2))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.BELT, "Cinto", Vector2(96, 234), Vector2(2, 1))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.BOOTS, "Botas", Vector2(96, 276), Vector2(2, 2))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.RING_1, "Anel 1", Vector2(174, 234), Vector2(1, 1))
	_create_doll_slot(root, ItemDefinition.EquipmentSlot.RING_2, "Anel 2", Vector2(212, 234), Vector2(1, 1))


func _create_doll_slot(parent: Control, slot: ItemDefinition.EquipmentSlot, label_txt: String, pos: Vector2, size_cells: Vector2) -> void:
	var slot_panel := Panel.new()
	slot_panel.position = pos
	slot_panel.size = size_cells * float(CELL_SIZE)
	slot_panel.add_theme_stylebox_override("panel", _slot_style(Color(0.08, 0.07, 0.09, 0.9), BORDER_COLOR))
	slot_panel.gui_input.connect(func(ev: InputEvent) -> void: _on_doll_slot_input(slot, ev))
	slot_panel.mouse_entered.connect(func() -> void: _on_doll_slot_hover(slot, true))
	slot_panel.mouse_exited.connect(func() -> void: _on_doll_slot_hover(slot, false))
	parent.add_child(slot_panel)

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_child(icon)

	var lbl := Label.new()
	lbl.name = "Placeholder"
	lbl.text = label_txt
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.45, 0.40))
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot_panel.add_child(lbl)

	_paperdoll_slots[slot] = slot_panel


func _process(_delta: float) -> void:
	if not visible:
		return
	if _held_item != null and _held_preview.visible:
		_held_preview.position = get_local_mouse_position() - _held_preview.size * 0.5


func _refresh_all() -> void:
	_refresh_grid_view()
	_refresh_paperdoll_view()
	_refresh_stats_view()


func _refresh_grid_view() -> void:
	if _grid_container == null or inventory == null:
		return
	for child in _grid_container.get_children():
		child.queue_free()

	# 1. Desenha as células de fundo (10 colunas x 4 linhas)
	for y in range(inventory.rows):
		for x in range(inventory.columns):
			var cell := Panel.new()
			cell.position = Vector2(x * CELL_SIZE, y * CELL_SIZE)
			cell.size = Vector2(CELL_SIZE, CELL_SIZE)
			cell.add_theme_stylebox_override("panel", _slot_style(Color(0.06, 0.05, 0.07, 0.8), Color(0.25, 0.22, 0.18, 0.6)))
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_grid_container.add_child(cell)

	# 2. Desenha os itens ocupando suas dimensões (W x H)
	for item in inventory.items:
		if item == null or item.definition == null:
			continue
		var pos_px: Vector2 = Vector2(item.grid_position.x * CELL_SIZE, item.grid_position.y * CELL_SIZE)
		var size_px: Vector2 = Vector2(item.definition.grid_size.x * CELL_SIZE, item.definition.grid_size.y * CELL_SIZE)

		var item_panel := Panel.new()
		item_panel.position = pos_px
		item_panel.size = size_px
		var border_col: Color = item.get_rarity_color()
		if stats != null and not item.meets_requirements(stats):
			border_col = RED_ALERT
		item_panel.add_theme_stylebox_override("panel", _slot_style(Color(0.12, 0.10, 0.14, 0.95), border_col, 2))
		item_panel.gui_input.connect(func(ev: InputEvent) -> void: _on_item_panel_input(item, ev))
		item_panel.mouse_entered.connect(func() -> void: _show_item_tooltip(item))
		item_panel.mouse_exited.connect(_hide_tooltip)
		_grid_container.add_child(item_panel)

		var icon := TextureRect.new()
		icon.texture = ItemIconFactory.get_icon(item.definition)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
		if item != null and item.definition != null:
			icon.texture = ItemIconFactory.get_icon(item.definition)
			icon.visible = true
			lbl.visible = false
			var border_col: Color = item.get_rarity_color()
			if stats != null and not item.meets_requirements(stats):
				border_col = RED_ALERT
			slot_panel.add_theme_stylebox_override("panel", _slot_style(Color(0.12, 0.10, 0.14, 0.95), border_col, 2))
		else:
			icon.texture = null
			icon.visible = false
			lbl.visible = true
			slot_panel.add_theme_stylebox_override("panel", _slot_style(Color(0.08, 0.07, 0.09, 0.9), BORDER_COLOR))


func _refresh_stats_view() -> void:
	if stats == null:
		return
	var hp: int = stats.get_max_health()
	var dmg: int = stats.get_damage()
	var armor: int = int(roundi(stats.get_stat(&"armor")))
	var str_val: int = int(roundi(stats.get_stat(&"strength")))
	var agi_val: int = int(roundi(stats.get_stat(&"agility")))
	var int_val: int = int(roundi(stats.get_stat(&"intelligence")))

	_stats_label.text = "[color=#e6ba5a]✦ ATRIBUTOS GLOBAIS:[/color]\n" + \
		"♥ Vida: [color=#ffffff]%d[/color]   |   🛡️ Armadura: [color=#ffffff]%d[/color]\n" % [hp, armor] + \
		"⚔ Dano: [color=#ffffff]%d[/color]   |   ⚡ Força: [color=#ffffff]%d[/color]\n" % [dmg, str_val] + \
		"🏹 Agilidade: [color=#ffffff]%d[/color]   |   🔮 Inteligência: [color=#ffffff]%d[/color]" % [agi_val, int_val]


# --- INTERAÇÃO COM O MOUSE ---
func _on_grid_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var cell := Vector2i(int(mb.position.x / CELL_SIZE), int(mb.position.y / CELL_SIZE))
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _held_item != null:
				# Tenta colocar o item na célula clicada
				if inventory.can_place_at(_held_item, cell):
					inventory.place_item(_held_item, cell)
					_set_held_item(null)
			else:
				var clicked: ItemInstance = inventory.get_item_at(cell)
				if clicked != null:
					inventory.remove_item(clicked)
					_set_held_item(clicked)


func _on_item_panel_input(item: ItemInstance, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _held_item == null:
				inventory.remove_item(item)
				_set_held_item(item)
			else:
				# Troca
				var prev_held: ItemInstance = _held_item
				inventory.remove_item(item)
				if inventory.can_place_at(prev_held, item.grid_position):
					inventory.place_item(prev_held, item.grid_position)
					_set_held_item(item)
				else:
					inventory.place_item(item, item.grid_position)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			# Clique direito: equipa direto no slot correspondente!
			if item.definition.is_equippable():
				var target_slot: ItemDefinition.EquipmentSlot = item.definition.equip_slot
				if target_slot == ItemDefinition.EquipmentSlot.RING_1 and equipment.get_equipped_item(ItemDefinition.EquipmentSlot.RING_1) != null:
					target_slot = ItemDefinition.EquipmentSlot.RING_2
				if equipment.can_equip(item, target_slot, stats):
					inventory.remove_item(item)
					var prev: ItemInstance = equipment.equip_item(item, target_slot, stats)
					if prev != null:
						inventory.auto_add_item(prev)
					_refresh_all()


func _on_doll_slot_input(slot: ItemDefinition.EquipmentSlot, event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		var equipped_item: ItemInstance = equipment.get_equipped_item(slot)
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if _held_item != null:
				if equipment.can_equip(_held_item, slot, stats):
					var prev: ItemInstance = equipment.equip_item(_held_item, slot, stats)
					_set_held_item(prev)
			elif equipped_item != null:
				equipment.unequip_item(slot, stats)
				_set_held_item(equipped_item)
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			if equipped_item != null:
				# Desequipa direto para a mochila
				equipment.unequip_item(slot, stats)
				if not inventory.auto_add_item(equipped_item):
					_set_held_item(equipped_item)
				_refresh_all()


func _on_doll_slot_hover(slot: ItemDefinition.EquipmentSlot, entered: bool) -> void:
	if entered:
		var item: ItemInstance = equipment.get_equipped_item(slot)
		if item != null:
			_show_item_tooltip(item)
	else:
		_hide_tooltip()


func _set_held_item(item: ItemInstance) -> void:
	_held_item = item
	if _held_item != null and _held_item.definition != null:
		_held_preview.texture = ItemIconFactory.get_icon(_held_item.definition)
		_held_preview.size = Vector2(_held_item.definition.grid_size) * float(CELL_SIZE)
		_held_preview.visible = true
	else:
		_held_preview.texture = null
		_held_preview.visible = false
	_hide_tooltip()


func _on_equipment_changed(_slot: ItemDefinition.EquipmentSlot, _item: ItemInstance) -> void:
	_refresh_paperdoll_view()
	_refresh_stats_view()


func _show_item_tooltip(item: ItemInstance) -> void:
	if item == null or item.definition == null or _held_item != null:
		_hide_tooltip()
		return
	var def: ItemDefinition = item.definition
	var r_col: String = item.get_rarity_color().to_html(false)

	var t: String = "[center][b][color=#%s]%s[/color][/b][/center]\n" % [r_col, item.get_display_name()]
	if not item.is_identified:
		t += "[center][color=#ff4d4d]Não-Identificado (Leve ao Sábio)[/color][/center]\n"

	# Dano ou Armadura
	if def.category == ItemDefinition.ItemCategory.WEAPON_1H or def.category == ItemDefinition.ItemCategory.WEAPON_2H:
		var dmg: Vector2i = item.get_damage_range()
		t += "⚔ Dano: [color=#ffffff]%d - %d[/color]\n" % [dmg.x, dmg.y]
		t += "⚡ Vel. Ataque: [color=#ffffff]%.2fx[/color]\n" % def.base_attack_speed
	elif item.get_total_armor() > 0:
		t += "🛡️ Armadura: [color=#ffffff]%d[/color]\n" % item.get_total_armor()

	# Requisitos (Vermelho se não atingir)
	var req_text: String = ""
	if def.req_strength > 0:
		var ok: bool = stats == null or stats.get_stat(&"strength") >= def.req_strength
		var c: String = "#ffffff" if ok else "#ff4d4d"
		req_text += "Requer Força: [color=%s]%d[/color]  " % [c, def.req_strength]
	if def.req_agility > 0:
		var ok: bool = stats == null or stats.get_stat(&"agility") >= def.req_agility
		var c: String = "#ffffff" if ok else "#ff4d4d"
		req_text += "Requer Agilidade: [color=%s]%d[/color]  " % [c, def.req_agility]
	if not req_text.is_empty():
		t += "[color=#b3a898]" + req_text + "[/color]\n"

	# Afixos explícitos
	if item.is_identified and not item.explicit_affixes.is_empty():
		t += "[color=#5dade2]"
		for af in item.explicit_affixes:
			t += "• " + af.display_text + "\n"
		t += "[/color]"

	_tooltip_text.text = t
	_tooltip_panel.visible = true
	_tooltip_panel.reset_size()
	var mp: Vector2 = get_local_mouse_position()
	_tooltip_panel.position = mp + Vector2(16, 16)


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
