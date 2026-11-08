extends Control
class_name SkillBarHUD

## ============================================================================
## HOTBAR MODULAR DEFINITIVA — 6 SKILLS CENTRAIS (GODOT 4)
## ============================================================================
## Rodapé central da tela:
## • 6 slots configuráveis: [LMB] [RMB] [Q] [E] [R] [F].
## • Base visual oficial sem correntes (02_hotbar_6_skills_base.png).
## • Nenhum ícone permanente na arte-base: slots vazios exibem apenas a cavidade.
## • 6 botões de seta ▲ dedicados para abrir o seletor em cada um dos 6 slots.
## • Keyplates inferiores renderizam as teclas dinamicamente via InputMap.
## • Exibição em tempo real de cooldown, custo de mana, indisponibilidade e feedback de uso.
## • mouse_filter da moldura é IGNORE para não bloquear cliques no gameplay.

const BASE_SIZE := Vector2(820, 291)
const TEX_FRAME := preload("res://assets/ui/hud/02_hotbar_6_skills_base.png")

const GOLD := Color(0.92, 0.76, 0.38)
const TEXT_COLOR := Color(0.95, 0.90, 0.82)
const KEYPLATE_COLOR := Color(0.96, 0.88, 0.65)
const MANA_BLUE := Color(0.42, 0.78, 1.0)
const MANA_EMPTY := Color(1.0, 0.35, 0.35)

const SLOT_COUNT: int = 6
const SLOT_HOLES: Array[Rect2] = [
	Rect2(52, 112, 99, 96),
	Rect2(175, 112, 99, 96),
	Rect2(298, 112, 98, 96),
	Rect2(421, 112, 97, 96),
	Rect2(542, 112, 99, 96),
	Rect2(666, 112, 100, 96)
]
const ARROW_CENTERS: Array[Vector2] = [
	Vector2(101, 85),
	Vector2(224, 85),
	Vector2(347, 85),
	Vector2(469, 85),
	Vector2(591, 85),
	Vector2(716, 85)
]
const KEYPLATE_CENTERS: Array[Vector2] = [
	Vector2(101, 239),
	Vector2(224, 239),
	Vector2(347, 239),
	Vector2(469, 239),
	Vector2(591, 239),
	Vector2(716, 239)
]

@export_range(0.3, 1.2, 0.02) var user_scale_multiplier: float = 1.0
var ui_scale: float = 0.76

var controller: PlayerSkillController

var _scaler: Control
var _frame_rect: TextureRect

var _slot_roots: Array[Control] = []
var _slot_icons: Array[TextureRect] = []
var _slot_arrow_btns: Array[Button] = []
var _slot_click_btns: Array[Button] = []
var _slot_key_labels: Array[Label] = []
var _slot_cd_curtains: Array[ColorRect] = []
var _slot_cd_labels: Array[Label] = []
var _slot_mana_overlays: Array[ColorRect] = []
var _slot_mana_labels: Array[Label] = []
var _slot_flash_overlays: Array[ColorRect] = []

var _picker_panel: PanelContainer
var _picker_list: VBoxContainer
var _picker_title: Label
var _picker_slot: int = -1

var _icon_cache: Dictionary = {}


func _init() -> void:
	name = "SkillBarHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	refresh_keyplate_labels()


func _ready() -> void:
	HudInputHelper.ensure_default_actions()
	_relayout()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_relayout)
	refresh_keyplate_labels()


func bind_controller(new_controller: PlayerSkillController) -> void:
	if controller != null:
		if controller.slots_changed.is_connected(refresh_slots):
			controller.slots_changed.disconnect(refresh_slots)
		if controller.skill_cast.is_connected(_on_skill_cast):
			controller.skill_cast.disconnect(_on_skill_cast)
		if controller.has_signal("insufficient_mana") and controller.is_connected("insufficient_mana", _on_insufficient_mana):
			controller.disconnect("insufficient_mana", _on_insufficient_mana)

	controller = new_controller

	if controller != null:
		controller.slots_changed.connect(refresh_slots)
		controller.skill_cast.connect(_on_skill_cast)
		if controller.has_signal("insufficient_mana"):
			controller.connect("insufficient_mana", _on_insufficient_mana)

	refresh_slots()


func _build_ui() -> void:
	_scaler = Control.new()
	_scaler.name = "Scaler"
	_scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.scale = Vector2(ui_scale, ui_scale)
	add_child(_scaler)

	# 1. Moldura oficial 02_hotbar_6_skills_base.png
	_frame_rect = TextureRect.new()
	_frame_rect.name = "HotbarFrame"
	_frame_rect.texture = TEX_FRAME
	_frame_rect.position = Vector2.ZERO
	_frame_rect.size = BASE_SIZE
	_frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_frame_rect)

	var empty_style := StyleBoxEmpty.new()

	# 2. Configuração dos 6 slots
	for i in range(SLOT_COUNT):
		var hole: Rect2 = SLOT_HOLES[i]
		var arrow_c: Vector2 = ARROW_CENTERS[i]
		var key_c: Vector2 = KEYPLATE_CENTERS[i]

		var slot_ctrl := Control.new()
		slot_ctrl.name = "Slot_%d" % i
		slot_ctrl.position = hole.position
		slot_ctrl.size = hole.size
		slot_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scaler.add_child(slot_ctrl)

		# Ícone dinâmico centralizado no orifício
		var icon_sz := Vector2(72, 72)
		var icon_pos := (hole.size - icon_sz) * 0.5
		var icon := TextureRect.new()
		icon.name = "SkillIcon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = icon_sz
		icon.position = icon_pos
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(icon)

		# Cortina escura de cooldown
		var cd_curtain := ColorRect.new()
		cd_curtain.name = "CooldownCurtain"
		cd_curtain.color = Color(0.02, 0.02, 0.03, 0.72)
		cd_curtain.position = icon_pos
		cd_curtain.size = Vector2(icon_sz.x, 0.0)
		cd_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(cd_curtain)

		# Contador numérico de recarga
		var cd_lbl := Label.new()
		cd_lbl.name = "CooldownLabel"
		cd_lbl.position = icon_pos
		cd_lbl.size = icon_sz
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 20)
		cd_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		cd_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		cd_lbl.add_theme_constant_override("outline_size", 5)
		cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(cd_lbl)

		# Filtro de mana insuficiente
		var mana_overlay := ColorRect.new()
		mana_overlay.name = "ManaOverlay"
		mana_overlay.color = Color(0.05, 0.10, 0.28, 0.68)
		mana_overlay.position = icon_pos
		mana_overlay.size = icon_sz
		mana_overlay.visible = false
		mana_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(mana_overlay)

		# Custo numérico de mana
		var mana_lbl := Label.new()
		mana_lbl.name = "ManaCostLabel"
		mana_lbl.position = Vector2(icon_pos.x + 2, icon_pos.y + icon_sz.y - 18)
		mana_lbl.size = Vector2(icon_sz.x - 4, 16)
		mana_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mana_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		mana_lbl.add_theme_font_size_override("font_size", 11)
		mana_lbl.add_theme_color_override("font_color", MANA_BLUE)
		mana_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		mana_lbl.add_theme_constant_override("outline_size", 4)
		mana_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(mana_lbl)

		# Flash de conjuração
		var flash := ColorRect.new()
		flash.name = "FlashOverlay"
		flash.color = Color(1.0, 0.95, 0.75, 0.0)
		flash.position = icon_pos
		flash.size = icon_sz
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(flash)

		# Botão invisível sobre o orifício para clique / hover
		var slot_btn := Button.new()
		slot_btn.name = "SlotButton"
		slot_btn.position = icon_pos
		slot_btn.size = icon_sz
		slot_btn.flat = true
		slot_btn.focus_mode = Control.FOCUS_NONE
		slot_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_btn.add_theme_stylebox_override("normal", empty_style)
		slot_btn.add_theme_stylebox_override("pressed", empty_style)
		slot_btn.add_theme_stylebox_override("hover", _make_slot_hover_style())
		var idx: int = i
		slot_btn.pressed.connect(func() -> void: _on_slot_clicked(idx))
		slot_ctrl.add_child(slot_btn)

		# Botão dedicado sobre a seta ▲ no topo
		var arrow_sz := Vector2(32, 28)
		var arrow_btn := Button.new()
		arrow_btn.name = "ArrowButton_%d" % i
		arrow_btn.size = arrow_sz
		arrow_btn.position = arrow_c - (arrow_sz * 0.5)
		arrow_btn.focus_mode = Control.FOCUS_NONE
		arrow_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		arrow_btn.flat = true
		arrow_btn.tooltip_text = "Escolher habilidade para este slot"
		arrow_btn.add_theme_stylebox_override("normal", empty_style)
		arrow_btn.add_theme_stylebox_override("hover", _make_arrow_hover_style())
		arrow_btn.add_theme_stylebox_override("pressed", _make_arrow_hover_style())
		arrow_btn.pressed.connect(func() -> void: _open_picker(idx))
		_scaler.add_child(arrow_btn)

		# Rótulo de texto da tecla no keyplate inferior
		var key_lbl := Label.new()
		key_lbl.name = "KeyLabel_%d" % i
		key_lbl.position = Vector2(key_c.x - 30, key_c.y - 12)
		key_lbl.size = Vector2(60, 24)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 12)
		key_lbl.add_theme_color_override("font_color", KEYPLATE_COLOR)
		key_lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.05, 0.02, 0.95))
		key_lbl.add_theme_constant_override("outline_size", 4)
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scaler.add_child(key_lbl)

		_slot_roots.append(slot_ctrl)
		_slot_icons.append(icon)
		_slot_arrow_btns.append(arrow_btn)
		_slot_click_btns.append(slot_btn)
		_slot_key_labels.append(key_lbl)
		_slot_cd_curtains.append(cd_curtain)
		_slot_cd_labels.append(cd_lbl)
		_slot_mana_overlays.append(mana_overlay)
		_slot_mana_labels.append(mana_lbl)
		_slot_flash_overlays.append(flash)

	# 3. Painel Seletor de Habilidades (Popup Gótico)
	_picker_panel = PanelContainer.new()
	_picker_panel.name = "SkillPickerPanel"
	_picker_panel.visible = false
	_picker_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.06, 0.045, 0.05, 0.98)
	ps.border_color = GOLD
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(6)
	ps.content_margin_left = 12
	ps.content_margin_right = 12
	ps.content_margin_top = 10
	ps.content_margin_bottom = 10
	_picker_panel.add_theme_stylebox_override("panel", ps)
	add_child(_picker_panel)

	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 6)
	_picker_panel.add_child(pv)

	_picker_title = Label.new()
	_picker_title.add_theme_font_size_override("font_size", 14)
	_picker_title.add_theme_color_override("font_color", GOLD)
	pv.add_child(_picker_title)

	_picker_list = VBoxContainer.new()
	_picker_list.add_theme_constant_override("separation", 4)
	pv.add_child(_picker_list)


func _unhandled_input(event: InputEvent) -> void:
	if _picker_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_picker_panel.visible = false
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.pressed:
			var local_p := _picker_panel.get_local_mouse_position()
			if not Rect2(Vector2.ZERO, _picker_panel.size).has_point(local_p):
				_picker_panel.visible = false


func refresh_keyplate_labels() -> void:
	for i in range(SLOT_COUNT):
		if i < _slot_key_labels.size():
			var lbl_str: String = HudInputHelper.get_skill_action_label(i)
			_slot_key_labels[i].text = lbl_str


func refresh_slots() -> void:
	refresh_keyplate_labels()
	for i in range(SLOT_COUNT):
		var sid: String = controller.slots[i] if (controller != null and i < controller.slots.size()) else ""
		var icon_ctrl: TextureRect = _slot_icons[i]
		var mana_lbl: Label = _slot_mana_labels[i]
		var btn: Button = _slot_click_btns[i]
		var arrow_b: Button = _slot_arrow_btns[i]

		if sid.is_empty() or controller == null or not controller.skills.has(sid):
			icon_ctrl.texture = null
			mana_lbl.text = ""
			btn.tooltip_text = "Slot vazio [%s] — clique na seta acima para atribuir" % _slot_key_labels[i].text
			arrow_b.tooltip_text = "Escolher habilidade para [%s]" % _slot_key_labels[i].text
			continue

		var def: SkillDefinition = controller.skills[sid] as SkillDefinition
		icon_ctrl.texture = _get_icon(def.icon_path)
		mana_lbl.text = str(def.mana_cost) if def.mana_cost > 0 else ""
		btn.tooltip_text = "%s\nCusto de Mana: %d | Recarga: %.1fs\n%s" % [def.display_name, def.mana_cost, def.base_cooldown, def.description]
		arrow_b.tooltip_text = "Substituir habilidade em [%s]" % _slot_key_labels[i].text


func refresh_mana_availability(current_mana: int) -> void:
	if controller == null:
		return
	for i in range(SLOT_COUNT):
		var sid: String = controller.slots[i] if i < controller.slots.size() else ""
		if sid.is_empty() or not controller.skills.has(sid):
			_slot_mana_overlays[i].visible = false
			continue
		var def: SkillDefinition = controller.skills[sid] as SkillDefinition
		var lacks_mana: bool = def.mana_cost > 0 and current_mana < def.mana_cost
		_slot_mana_overlays[i].visible = lacks_mana
		if lacks_mana:
			_slot_mana_labels[i].add_theme_color_override("font_color", MANA_EMPTY)
		else:
			_slot_mana_labels[i].add_theme_color_override("font_color", MANA_BLUE)


func _on_skill_cast(sid: String) -> void:
	if controller == null:
		return
	for i in range(SLOT_COUNT):
		if i < controller.slots.size() and controller.slots[i] == sid:
			_trigger_flash(i)


func _on_insufficient_mana(slot_idx: int, _cost: int) -> void:
	if slot_idx >= 0 and slot_idx < _slot_mana_overlays.size():
		var overlay := _slot_mana_overlays[slot_idx]
		var tw := create_tween()
		tw.tween_property(overlay, "color:a", 0.95, 0.08)
		tw.tween_property(overlay, "color:a", 0.68, 0.20)


func _trigger_flash(slot_idx: int) -> void:
	if slot_idx < 0 or slot_idx >= _slot_flash_overlays.size():
		return
	var f := _slot_flash_overlays[slot_idx]
	var tw := create_tween()
	tw.tween_property(f, "color:a", 0.85, 0.06)
	tw.tween_property(f, "color:a", 0.0, 0.25)


func _process(delta: float) -> void:
	if not visible:
		return
	if controller == null:
		return

	for i in range(SLOT_COUNT):
		var sid: String = controller.slots[i] if i < controller.slots.size() else ""
		var curtain: ColorRect = _slot_cd_curtains[i]
		var cd_lbl: Label = _slot_cd_labels[i]

		if sid.is_empty() or not controller.skills.has(sid):
			curtain.size.y = 0.0
			cd_lbl.text = ""
			continue

		var def: SkillDefinition = controller.skills[sid] as SkillDefinition
		var rem: float = controller.get_cooldown_remaining(sid)
		var total: float = def.get_cooldown(controller._stats())

		if rem > 0.05 and total > 0.01:
			var ratio: float = clampf(rem / total, 0.0, 1.0)
			curtain.size.y = 72.0 * ratio
			curtain.position.y = (96.0 - 72.0) * 0.5 + (72.0 * (1.0 - ratio))
			cd_lbl.text = "%.1f" % rem if rem < 10.0 else "%d" % int(ceil(rem))
		else:
			curtain.size.y = 0.0
			cd_lbl.text = ""


func _on_slot_clicked(slot_idx: int) -> void:
	_open_picker(slot_idx)


func _open_picker(slot_idx: int) -> void:
	if controller == null:
		return
	if _picker_panel.visible and _picker_slot == slot_idx:
		_picker_panel.visible = false
		return
	_picker_slot = slot_idx
	var key_label: String = _slot_key_labels[slot_idx].text
	_picker_title.text = "Atribuir Habilidade a [%s]" % key_label

	for child in _picker_list.get_children():
		child.queue_free()

	for sid in controller.get_assignable_skill_ids():
		var def: SkillDefinition = controller.skills[sid] as SkillDefinition
		var btn := Button.new()
		var tag: String = "  [Básico]" if def.is_basic_attack else ""
		var mana_tag: String = "  (💧 %d)" % def.mana_cost if def.mana_cost > 0 else ""
		var current: bool = controller.slots[slot_idx] == sid
		btn.text = ("✔ " if current else "   ") + def.display_name + tag + mana_tag
		btn.tooltip_text = "%s\nCusto: %d | Recarga: %.1fs\n%s" % [def.display_name, def.mana_cost, def.base_cooldown, def.description]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = _get_icon(def.icon_path)
		btn.expand_icon = false
		btn.add_theme_constant_override("icon_max_width", 24)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", def.accent_color.lightened(0.25))

		var b_style := StyleBoxFlat.new()
		b_style.bg_color = Color(0.10, 0.08, 0.09, 0.92)
		b_style.border_color = Color(0.40, 0.32, 0.22, 0.8)
		b_style.set_border_width_all(1)
		b_style.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", b_style)

		var h_style := b_style.duplicate() as StyleBoxFlat
		h_style.bg_color = Color(0.20, 0.16, 0.12, 0.95)
		h_style.border_color = GOLD
		btn.add_theme_stylebox_override("hover", h_style)
		btn.add_theme_stylebox_override("pressed", h_style)

		var skill_to_assign: String = sid
		btn.pressed.connect(func() -> void:
			controller.assign_skill_to_slot(_picker_slot, skill_to_assign)
			_picker_panel.visible = false
			refresh_slots()
		)
		_picker_list.add_child(btn)

	# Botão para desequipar / limpar o slot
	var clear_btn := Button.new()
	clear_btn.text = "   ✕ Deixar Slot Vazio"
	clear_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.add_theme_font_size_override("font_size", 12)
	clear_btn.add_theme_color_override("font_color", Color(0.75, 0.45, 0.45))
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.12, 0.06, 0.06, 0.92)
	c_style.border_color = Color(0.55, 0.25, 0.25, 0.8)
	c_style.set_border_width_all(1)
	c_style.set_corner_radius_all(4)
	clear_btn.add_theme_stylebox_override("normal", c_style)
	clear_btn.pressed.connect(func() -> void:
		controller.slots[_picker_slot] = ""
		controller.slots_changed.emit()
		_picker_panel.visible = false
		refresh_slots()
	)
	_picker_list.add_child(clear_btn)

	_picker_panel.visible = true
	_relayout_picker()


func _relayout_picker() -> void:
	if not _picker_panel.visible or _picker_slot < 0:
		return
	_picker_panel.reset_size()
	var hole: Rect2 = SLOT_HOLES[_picker_slot]
	var slot_center_x: float = (hole.position.x + hole.size.x * 0.5) * ui_scale
	var px: float = clampf(slot_center_x - _picker_panel.size.x * 0.5, 8.0, size.x - _picker_panel.size.x - 8.0)
	var py: float = -_picker_panel.size.y - 12.0
	_picker_panel.position = Vector2(px, py)


func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10.0:
		return

	# Escala responsiva proporcional:
	# 1920x1080 -> 0.76
	# 1280x720  -> 0.50
	var s: float = (vp.y / 1080.0) * 0.76
	var max_w_scale: float = (vp.x - 120.0) / 1834.0
	ui_scale = clampf(minf(s, max_w_scale) * user_scale_multiplier, 0.42, 0.95)

	if _scaler != null:
		_scaler.scale = Vector2(ui_scale, ui_scale)

	custom_minimum_size = BASE_SIZE * ui_scale
	size = custom_minimum_size

	# Centralizado na base
	var margin_y: float = 6.0
	position = Vector2((vp.x - size.x) * 0.5, vp.y - size.y - margin_y)
	_relayout_picker()


func _get_icon(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _icon_cache.has(path):
		return _icon_cache[path] as Texture2D
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		_icon_cache[path] = tex
		return tex
	return null


func _make_slot_hover_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1.0, 0.85, 0.35, 0.12)
	st.border_color = GOLD
	st.set_border_width_all(1)
	st.set_corner_radius_all(6)
	return st


func _make_arrow_hover_style() -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(1.0, 0.85, 0.35, 0.28)
	st.border_color = GOLD
	st.set_border_width_all(1)
	st.set_corner_radius_all(14)
	return st
