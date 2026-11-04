extends Control
class_name SkillBarHUD
## Barra de Skills Gótica (estilo Diablo 2 / Path of Exile 2) no rodapé central:
##   [LMB] [RMB]  |  [1] [2] [3] [4]
## • Mostra ícone, nome curto e a recarga em tempo real (cortina escura + segundos).
## • Clique na setinha ▲ acima do slot para escolher qual skill fica nele.
## • Limite de 4 skills ativas diferentes (o Ataque Básico não conta).

const BG := Color(0.055, 0.045, 0.042, 0.94)
const BORDER := Color(0.52, 0.39, 0.22, 0.95)
const GOLD := Color(0.90, 0.72, 0.36)
const TEXT := Color(0.93, 0.89, 0.80)
const MUTED := Color(0.60, 0.56, 0.50)
const SLOT_SIZE := Vector2(58, 58)

var controller: PlayerSkillController
var _slot_panels: Array[Panel] = []
var _slot_icons: Array[TextureRect] = []
var _slot_names: Array[Label] = []
var _slot_cd_curtains: Array[ColorRect] = []
var _slot_cd_labels: Array[Label] = []
var _picker_panel: PanelContainer
var _picker_list: VBoxContainer
var _picker_title: Label
var _picker_slot: int = -1
var _bar_root: Control
var _icon_cache: Dictionary = {}


func _ready() -> void:
	name = "SkillBarHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_relayout()
	get_viewport().size_changed.connect(_relayout)


func bind_controller(new_controller: PlayerSkillController) -> void:
	if controller != null and controller.slots_changed.is_connected(refresh_slots):
		controller.slots_changed.disconnect(refresh_slots)
	controller = new_controller
	if controller != null:
		controller.slots_changed.connect(refresh_slots)
	refresh_slots()


func _build_ui() -> void:
	_bar_root = Control.new()
	_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar_root)

	for i in range(PlayerSkillController.SLOT_COUNT):
		var slot := Panel.new()
		slot.custom_minimum_size = SLOT_SIZE
		slot.size = SLOT_SIZE
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.tooltip_text = ""
		slot.add_theme_stylebox_override("panel", _style(BG, BORDER, 2))
		_bar_root.add_child(slot)

		var icon := TextureRect.new()
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.position = Vector2(9, 7)
		icon.size = Vector2(40, 36)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.position = Vector2(2, 44)
		name_lbl.size = Vector2(60, 16)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", TEXT)
		name_lbl.clip_text = true
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(name_lbl)

		var curtain := ColorRect.new()
		curtain.color = Color(0.0, 0.0, 0.0, 0.62)
		curtain.position = Vector2(2, 2)
		curtain.size = Vector2(60, 0)
		curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(curtain)

		var cd_lbl := Label.new()
		cd_lbl.position = Vector2(0, 16)
		cd_lbl.size = Vector2(64, 24)
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 16)
		cd_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		cd_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		cd_lbl.add_theme_constant_override("outline_size", 5)
		cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(cd_lbl)

		var key_lbl := Label.new()
		key_lbl.text = PlayerSkillController.SLOT_LABELS[i]
		key_lbl.position = Vector2(4, 40)
		key_lbl.size = Vector2(50, 16)
		key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key_lbl.add_theme_font_size_override("font_size", 10)
		key_lbl.add_theme_color_override("font_color", GOLD)
		key_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		key_lbl.add_theme_constant_override("outline_size", 4)
		key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(key_lbl)

		# Setinha ▲ para abrir o seletor de skill daquele slot
		var pick_btn := Button.new()
		pick_btn.text = "▲"
		pick_btn.add_theme_font_size_override("font_size", 10)
		pick_btn.add_theme_color_override("font_color", GOLD)
		pick_btn.add_theme_stylebox_override("normal", _style(BG, BORDER, 1))
		pick_btn.add_theme_stylebox_override("hover", _style(BG.lightened(0.12), GOLD, 1))
		pick_btn.add_theme_stylebox_override("pressed", _style(BG.lightened(0.12), GOLD, 1))
		pick_btn.size = Vector2(26, 16)
		pick_btn.position = Vector2(19, -18)
		pick_btn.focus_mode = Control.FOCUS_NONE
		var idx: int = i
		pick_btn.pressed.connect(func() -> void: _open_picker(idx))
		slot.add_child(pick_btn)

		_slot_panels.append(slot)
		_slot_icons.append(icon)
		_slot_names.append(name_lbl)
		_slot_cd_curtains.append(curtain)
		_slot_cd_labels.append(cd_lbl)

	# Seletor de skill (popup)
	_picker_panel = PanelContainer.new()
	_picker_panel.visible = false
	_picker_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ps := _style(Color(0.05, 0.045, 0.055, 0.98), GOLD, 2)
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
	_picker_title.add_theme_font_size_override("font_size", 13)
	_picker_title.add_theme_color_override("font_color", GOLD)
	pv.add_child(_picker_title)
	_picker_list = VBoxContainer.new()
	_picker_list.add_theme_constant_override("separation", 4)
	pv.add_child(_picker_list)


func _open_picker(slot_idx: int) -> void:
	if controller == null:
		return
	if _picker_panel.visible and _picker_slot == slot_idx:
		_picker_panel.visible = false
		return
	_picker_slot = slot_idx
	_picker_title.text = "Escolher skill para [%s]  (máx. %d skills)" % [PlayerSkillController.SLOT_LABELS[slot_idx], PlayerSkillController.MAX_ACTIVE_SKILLS]
	for child in _picker_list.get_children():
		child.queue_free()

	for sid in controller.get_assignable_skill_ids():
		var def: SkillDefinition = controller.skills[sid]
		var btn := Button.new()
		var tag: String = "  (Ataque Básico)" if def.is_basic_attack else ""
		var current: bool = controller.slots[slot_idx] == sid
		btn.text = ("✔ " if current else "   ") + def.display_name + tag
		btn.tooltip_text = def.description
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = _get_icon(def.icon_path)
		btn.expand_icon = false
		btn.add_theme_constant_override("icon_max_width", 22)
		btn.focus_mode = Control.FOCUS_NONE
		btn.add_theme_font_size_override("font_size", 13)
		btn.add_theme_color_override("font_color", def.accent_color.lightened(0.25))
		btn.add_theme_stylebox_override("normal", _style(BG, BORDER, 1))
		btn.add_theme_stylebox_override("hover", _style(BG.lightened(0.12), GOLD, 1))
		btn.add_theme_stylebox_override("pressed", _style(BG.lightened(0.12), GOLD, 1))
		var allowed: bool = controller.can_assign(slot_idx, sid)
		btn.disabled = not allowed
		if not allowed:
			btn.text += "  [limite de 4 skills]"
		var chosen: String = sid
		btn.pressed.connect(func() -> void:
			controller.assign_slot(_picker_slot, chosen)
			_picker_panel.visible = false
		)
		_picker_list.add_child(btn)

	var clear_btn := Button.new()
	clear_btn.text = "   — Deixar vazio —"
	clear_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.add_theme_font_size_override("font_size", 12)
	clear_btn.add_theme_color_override("font_color", MUTED)
	clear_btn.add_theme_stylebox_override("normal", _style(BG, BORDER, 1))
	clear_btn.add_theme_stylebox_override("hover", _style(BG.lightened(0.12), GOLD, 1))
	clear_btn.pressed.connect(func() -> void:
		controller.assign_slot(_picker_slot, "")
		_picker_panel.visible = false
	)
	_picker_list.add_child(clear_btn)

	_picker_panel.visible = true
	_picker_panel.reset_size()
	await get_tree().process_frame
	var slot_panel: Panel = _slot_panels[slot_idx]
	var sp: Vector2 = slot_panel.global_position
	var vp: Vector2 = get_viewport_rect().size
	var px: float = clampf(sp.x + SLOT_SIZE.x * 0.5 - _picker_panel.size.x * 0.5, 8.0, vp.x - _picker_panel.size.x - 8.0)
	_picker_panel.position = Vector2(px, sp.y - _picker_panel.size.y - 26.0)


func refresh_slots() -> void:
	if controller == null:
		return
	for i in range(PlayerSkillController.SLOT_COUNT):
		var def: SkillDefinition = controller.get_slot_skill(i)
		if def == null:
			_slot_icons[i].texture = null
			_slot_names[i].text = "vazio"
			_slot_names[i].add_theme_color_override("font_color", MUTED)
			_slot_panels[i].tooltip_text = "Slot vazio — clique em ▲ para escolher"
			_slot_panels[i].add_theme_stylebox_override("panel", _style(BG, BORDER.darkened(0.3), 2))
		else:
			_slot_icons[i].texture = _get_icon(def.icon_path)
			_slot_icons[i].modulate = Color(1, 1, 1) if def.vfx_kind != "ember" and def.vfx_kind != "pierce" else def.accent_color.lightened(0.35)
			_slot_names[i].text = def.display_name
			_slot_names[i].add_theme_color_override("font_color", TEXT)
			_slot_panels[i].tooltip_text = "%s\n%s" % [def.display_name, def.description]
			var border_col: Color = GOLD if def.is_basic_attack else def.accent_color.darkened(0.15)
			_slot_panels[i].add_theme_stylebox_override("panel", _style(BG, border_col, 2))


func _process(_delta: float) -> void:
	if controller == null or not visible:
		return
	for i in range(PlayerSkillController.SLOT_COUNT):
		var sid: String = controller.slots[i]
		var ratio: float = controller.get_cooldown_ratio(sid)
		var remaining: float = controller.get_cooldown_remaining(sid)
		_slot_cd_curtains[i].size = Vector2(54, 54.0 * ratio)
		_slot_cd_curtains[i].position = Vector2(2, 2 + 54.0 * (1.0 - ratio))
		_slot_cd_labels[i].text = ("%.1f" % remaining) if remaining > 0.35 else ""


func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10.0:
		return
	var gap: float = 8.0
	var group_gap: float = 22.0
	var total_w: float = SLOT_SIZE.x * 6.0 + gap * 4.0 + group_gap
	var x: float = (vp.x - total_w) * 0.5
	var y: float = vp.y - SLOT_SIZE.y - 22.0
	for i in range(_slot_panels.size()):
		_slot_panels[i].position = Vector2(x, y)
		x += SLOT_SIZE.x + (group_gap if i == 1 else gap)


func _input(event: InputEvent) -> void:
	# Clique fora do seletor (e fora das setinhas) fecha o popup.
	if _picker_panel == null or not _picker_panel.visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mpos: Vector2 = (event as InputEventMouseButton).position
		if _picker_panel.get_global_rect().has_point(mpos):
			return
		for slot in _slot_panels:
			var arrow_rect := Rect2(slot.global_position + Vector2(0, -20), Vector2(SLOT_SIZE.x, 20))
			if arrow_rect.has_point(mpos):
				return
		_picker_panel.visible = false


func _get_icon(path: String) -> Texture2D:
	if path.is_empty():
		return null
	if _icon_cache.has(path):
		return _icon_cache[path]
	var tex: Texture2D = load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icon_cache[path] = tex
	return tex


func _style(bg: Color, border: Color, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(29)
	s.shadow_color = Color(0, 0, 0, 0.3)
	s.shadow_size = 4
	return s
