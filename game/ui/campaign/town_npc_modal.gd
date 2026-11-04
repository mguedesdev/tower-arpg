extends Control
class_name TownNpcModal
## Modal Gótico Dark-Fantasy (estilo Diablo 2 / Path of Exile) para os NPCs e Baú da Vila:
## - "stash": Baú Pessoal (Stash)
## - "vendor_physical": Vendedor de Itens Físicos (Ferreiro)
## - "vendor_magic": Vendedor de Itens Mágicos (Arcanista)
## - "identifier_respec": Identificador de Itens & Resetar Build (Sábio)
## - "waypoint": Rede de Waypoints Ancestrais (Teleporte entre Vila e Zonas)

signal waypoint_travel_requested(zone_id: String)
signal respec_build_requested()

const COLOR_BRONZE_BORDER := Color(0.66, 0.50, 0.25, 0.96)
const COLOR_GOLD_TITLE := Color(0.94, 0.80, 0.46)
const COLOR_PARCHMENT := Color(0.86, 0.82, 0.74)
const COLOR_MUTED := Color(0.62, 0.59, 0.54)

var _title_label: Label
var _subtitle_label: Label
var _content_box: VBoxContainer
var _feedback_label: Label
var _unlocked_zones: Array[String] = ["town", "zone_1_road"]
var _current_zone_id: String = "town"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_E:
			close_modal()
			get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.02, 0.03, 0.74)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 420)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.045, 0.055, 0.97)
	style.border_color = COLOR_BRONZE_BORDER
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 12)
	card.add_child(root_vbox)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 24)
	_title_label.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", 14)
	_subtitle_label.add_theme_color_override("font_color", COLOR_MUTED)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_vbox.add_child(_subtitle_label)

	var sep := HSeparator.new()
	root_vbox.add_child(sep)

	_content_box = VBoxContainer.new()
	_content_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_box.add_theme_constant_override("separation", 10)
	root_vbox.add_child(_content_box)

	_feedback_label = Label.new()
	_feedback_label.add_theme_font_size_override("font_size", 14)
	_feedback_label.add_theme_color_override("font_color", Color(0.56, 0.90, 0.62))
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root_vbox.add_child(_feedback_label)

	var close_btn := _make_gothic_button("FECHAR (ESC / E)", false)
	close_btn.pressed.connect(close_modal)
	root_vbox.add_child(close_btn)


func open_station(station_id: String, unlocked_zones: Array[String], current_zone: String) -> void:
	_unlocked_zones = unlocked_zones
	_current_zone_id = current_zone
	_feedback_label.text = ""
	for child in _content_box.get_children():
		child.queue_free()

	match station_id:
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

	visible = true


func close_modal() -> void:
	visible = false


func _populate_stash() -> void:
	_title_label.text = "📦 BAÚ PESSOAL (STASH)"
	_subtitle_label.text = "Guarde armas, armaduras e relíquias entre suas jornadas pelas Zonas."
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	for i in range(18):
		var slot := PanelContainer.new()
		slot.custom_minimum_size = Vector2(88, 64)
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.08, 0.08, 0.10, 0.95)
		st.border_color = Color(0.32, 0.28, 0.22, 0.85)
		st.border_width_left = 1
		st.border_width_top = 1
		st.border_width_right = 1
		st.border_width_bottom = 1
		slot.add_theme_stylebox_override("panel", st)
		var lbl := Label.new()
		lbl.text = "Vazio"
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0.38, 0.36, 0.34))
		slot.add_child(lbl)
		grid.add_child(slot)
	_content_box.add_child(grid)
	var note := Label.new()
	note.text = "Nota: Os itens terão requisitos de Força, Agilidade e Inteligência (sem distribuição manual de pontos)."
	note.add_theme_font_size_override("font_size", 13)
	note.add_theme_color_override("font_color", COLOR_PARCHMENT)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content_box.add_child(note)


func _populate_vendor_physical() -> void:
	_title_label.text = "⚒ FERREIRO — VENDEDOR DE ITENS FÍSICOS"
	_subtitle_label.text = "\"Aço temperado para quem sobrevive à Estrada Profanada. Veja minhas armas e armaduras:\""
	var items := [
		["Espada Bastarda de Ferro", "Dano Físico: 14–22 | Requisito: 18 Força", Color(0.88, 0.88, 0.88)],
		["Cutelo Pesado do Carrasco", "Dano Físico: 20–31 (+15% Sangramento) | Requisito: 26 Força", Color(0.45, 0.68, 0.98)],
		["Broquel de Bronze Cravejado", "Armadura: +38 | Bloqueio: 22% | Requisito: 16 Força, 12 Agilidade", Color(0.45, 0.68, 0.98)],
		["Cota de Malha dos Exilados", "Armadura: +65 | +18 Vida Máxima | Requisito: 24 Força", Color(0.95, 0.84, 0.36)],
	]
	for entry in items:
		_content_box.add_child(_make_item_preview_row(entry[0], entry[1], entry[2]))


func _populate_vendor_magic() -> void:
	_title_label.text = "🔮 ARCANISTA — VENDEDOR DE ITENS MÁGICOS"
	_subtitle_label.text = "\"Relíquias imbuídas com cinzas e ecos arcanos. Apenas mentes preparadas suportam seu poder:\""
	var items := [
		["Anel da Brasa Profana (Mágico)", "+25% Dano de Queimadura | +8 Inteligência | Requisito: 15 Inteligência", Color(0.45, 0.68, 0.98)],
		["Amuleto do Eco Astral (Raro)", "+12% Velocidade de Ataque | +15% Chance de Eco | Requisito: 22 Inteligência, 16 Agilidade", Color(0.95, 0.84, 0.36)],
		["Lâmina Rúnica Incandescente (Raro)", "Dano Físico/Fogo: 16–28 | Concede Lâmina Ígnea | Requisito: 18 Força, 20 Inteligência", Color(0.95, 0.84, 0.36)],
		["Botas do Passo Sombrio (Mágico)", "+18% Velocidade de Movimento | Requisito: 20 Agilidade", Color(0.45, 0.68, 0.98)],
	]
	for entry in items:
		_content_box.add_child(_make_item_preview_row(entry[0], entry[1], entry[2]))


func _populate_identifier_respec() -> void:
	_title_label.text = "📜 SÁBIO IDENTIFICADOR & RESET DE BUILD"
	_subtitle_label.text = "\"Fique um instante e escute... Posso revelar os segredos de itens misteriosos ou purificar sua Build.\""

	var id_btn := _make_gothic_button("🔍 IDENTIFICAR TODOS OS ITENS DO INVENTÁRIO (GRÁTIS)", false)
	id_btn.pressed.connect(func() -> void:
		_feedback_label.text = "✦ Todos os seus itens foram inspecionados pelo Sábio!"
	)
	_content_box.add_child(id_btn)

	var respec_btn := _make_gothic_button("↺ RESETAR BUILD & HABILIDADES ATUAIS", true)
	respec_btn.pressed.connect(func() -> void:
		respec_build_requested.emit()
		_feedback_label.text = "✦ Sua Build e Transformações foram resetadas com sucesso!"
	)
	_content_box.add_child(respec_btn)

	var lore := Label.new()
	lore.text = "• Atributos (Força, Agilidade, Inteligência) não são adicionados por botões manuais.\n• Você os conquistará através de marcos, relíquias e equipamentos para cumprir os requisitos dos itens."
	lore.add_theme_font_size_override("font_size", 13)
	lore.add_theme_color_override("font_color", COLOR_PARCHMENT)
	lore.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content_box.add_child(lore)


func _populate_waypoint() -> void:
	_title_label.text = "✦ WAYPOINT ANCESTRAL — TELEPORTE DE ZONAS"
	_subtitle_label.text = "Selecione uma Zona descoberta para viajar instantaneamente:"

	var all_zones := [
		["town", "🏰 Acampamento dos Exilados (Vila Segura)"],
		["zone_1_road", "⚔ Zona 1 — Estrada Profanada (Nível 1)"],
		["zone_2_woods", "🌲 Zona 2 — Mata das Sombras (Nível 2)"],
		["zone_3_crypt", "☠ Zona 3 — Cripta do Carrasco (Nível 3 - Boss)"],
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
			btn_text += "  [BLOQUEADO — Alcance a pé primeiro]"
		var btn := _make_gothic_button(btn_text, zid == "zone_3_crypt" and is_unlocked)
		btn.disabled = (not is_unlocked) or is_current
		btn.pressed.connect(func() -> void:
			close_modal()
			waypoint_travel_requested.emit(zid)
		)
		_content_box.add_child(btn)


func _make_item_preview_row(item_name: String, item_desc: String, name_col: Color) -> PanelContainer:
	var row := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.08, 0.075, 0.09, 0.94)
	st.border_color = Color(0.36, 0.30, 0.22, 0.85)
	st.border_width_left = 1
	st.border_width_top = 1
	st.border_width_right = 1
	st.border_width_bottom = 1
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	row.add_theme_stylebox_override("panel", st)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	row.add_child(vb)

	var nl := Label.new()
	nl.text = item_name
	nl.add_theme_font_size_override("font_size", 15)
	nl.add_theme_color_override("font_color", name_col)
	vb.add_child(nl)

	var dl := Label.new()
	dl.text = item_desc
	dl.add_theme_font_size_override("font_size", 12)
	dl.add_theme_color_override("font_color", COLOR_PARCHMENT)
	vb.add_child(dl)
	return row


func _make_gothic_button(text_val: String, is_crimson: bool) -> Button:
	var btn := Button.new()
	btn.text = text_val
	btn.custom_minimum_size = Vector2(0, 42)
	btn.add_theme_font_size_override("font_size", 15)
	btn.add_theme_color_override("font_color", Color(0.96, 0.92, 0.82))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.42, 0.10, 0.10, 0.96) if is_crimson else Color(0.11, 0.10, 0.13, 0.96)
	normal.border_color = COLOR_BRONZE_BORDER
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.corner_radius_top_left = 3
	normal.corner_radius_top_right = 3
	normal.corner_radius_bottom_left = 3
	normal.corner_radius_bottom_right = 3
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = normal.bg_color.lightened(0.14)
	hover.border_color = COLOR_GOLD_TITLE
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	return btn
