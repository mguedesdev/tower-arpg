extends Control
class_name SkillBarHUD

## ============================================================================
## HOTBAR GÓTICA DE HABILIDADES — ARPG DARK FANTASY (GODOT 4)
## ============================================================================
## Rodapé central da tela:
## • 6 slots configuráveis: [LMB] [RMB] [1] [2] [3] [4].
## • Base visual na moldura oficial com simetria e ornamentos (hotbar_frame.png).
## • Nenhum ícone permanente na arte-base: slots vazios exibem apenas o interior.
## • Ícones carregados dinamicamente das habilidades atribuídas.
## • 6 botões de seta ▲ dedicados para abrir o seletor em cada um dos 6 slots.
## • Exibição em tempo real de cooldown, custo de mana, indisponibilidade e feedback de uso.
## • Totalmente integrado ao PlayerSkillController sem duplicar controles de combate.

const BASE_SIZE := Vector2(938, 393)

const TEX_FRAME := preload("res://assets/ui/hud/hotbar_frame.png")

const GOLD := Color(0.92, 0.76, 0.38)
const TEXT_COLOR := Color(0.94, 0.90, 0.82)
const MUTED_COLOR := Color(0.60, 0.55, 0.48)
const MANA_BLUE := Color(0.42, 0.78, 1.0)
const MANA_EMPTY := Color(1.0, 0.35, 0.35)

# Coordenadas originais dos 6 slots na arte 938x393
const SLOT_COUNT: int = 6
const SLOT_CENTERS: Array[float] = [179.0, 296.0, 411.0, 526.0, 641.0, 756.0]
const SLOT_Y_TOP: float = 160.0
const SLOT_WIDTH: float = 98.0
const SLOT_HEIGHT: float = 92.0
const ARROW_Y: float = 138.0
const ARROW_RADIUS: float = 16.0

@export_range(0.2, 1.0, 0.02) var ui_scale: float = 0.44

var controller: PlayerSkillController

var _scaler: Control
var _frame_rect: TextureRect

var _slot_roots: Array[Control] = []
var _slot_icons: Array[TextureRect] = []
var _slot_arrow_btns: Array[Button] = []
var _slot_click_btns: Array[Button] = []
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


func _ready() -> void:
	_relayout()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_relayout)


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

	# 1. Moldura de fundo oficial com todos os ornamentos e etiquetas (LMB, RMB, 1, 2, 3, 4)
	_frame_rect = TextureRect.new()
	_frame_rect.name = "HotbarFrame"
	_frame_rect.texture = TEX_FRAME
	_frame_rect.position = Vector2.ZERO
	_frame_rect.size = BASE_SIZE
	_frame_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_frame_rect)

	# 2. Configuração dos 6 slots
	for i in range(PlayerSkillController.SLOT_COUNT):
		var cx: float = SLOT_CENTERS[i]
		var slot_x: float = cx - (SLOT_WIDTH * 0.5)

		var slot_ctrl := Control.new()
		slot_ctrl.name = "Slot_%d" % i
		slot_ctrl.position = Vector2(slot_x, SLOT_Y_TOP)
		slot_ctrl.size = Vector2(SLOT_WIDTH, SLOT_HEIGHT)
		slot_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scaler.add_child(slot_ctrl)

		# Ícone dinâmico da habilidade atribuída (vazio por padrão)
		var icon := TextureRect.new()
		icon.name = "SkillIcon"
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(66, 66)
		icon.position = Vector2((SLOT_WIDTH - 66) * 0.5, (SLOT_HEIGHT - 66) * 0.5 - 2)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(icon)

		# Cortina de cooldown (desce de cima para baixo ou sobe)
		var cd_curtain := ColorRect.new()
		cd_curtain.name = "CooldownCurtain"
		cd_curtain.color = Color(0.02, 0.02, 0.03, 0.72)
		cd_curtain.position = icon.position
		cd_curtain.size = Vector2(icon.size.x, 0.0)
		cd_curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(cd_curtain)

		# Rótulo de segundos restantes do cooldown
		var cd_lbl := Label.new()
		cd_lbl.name = "CooldownLabel"
		cd_lbl.position = icon.position
		cd_lbl.size = icon.size
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 22)
		cd_lbl.add_theme_color_override("font_color", Color(1, 1, 1))
		cd_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		cd_lbl.add_theme_constant_override("outline_size", 6)
		cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(cd_lbl)

		# Indicador de indisponibilidade por falta de mana
		var mana_overlay := ColorRect.new()
		mana_overlay.name = "ManaOverlay"
		mana_overlay.color = Color(0.04, 0.08, 0.22, 0.65)
		mana_overlay.position = icon.position
		mana_overlay.size = icon.size
		mana_overlay.visible = false
		mana_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(mana_overlay)

		# Custo numérico de mana da habilidade
		var mana_lbl := Label.new()
		mana_lbl.name = "ManaCostLabel"
		mana_lbl.position = Vector2(icon.position.x + 2, icon.position.y + icon.size.y - 18)
		mana_lbl.size = Vector2(icon.size.x - 4, 16)
		mana_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		mana_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		mana_lbl.add_theme_font_size_override("font_size", 12)
		mana_lbl.add_theme_color_override("font_color", MANA_BLUE)
		mana_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		mana_lbl.add_theme_constant_override("outline_size", 4)
		mana_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(mana_lbl)

		# Flash de feedback ao conjurar
		var flash := ColorRect.new()
		flash.name = "FlashOverlay"
		flash.color = Color(1.0, 0.95, 0.75, 0.0)
		flash.position = icon.position
		flash.size = icon.size
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_ctrl.add_child(flash)

		# Botão invisível sobre o slot para hover / clique / tooltip
		var slot_btn := Button.new()
		slot_btn.name = "SlotButton"
		slot_btn.position = icon.position
		slot_btn.size = icon.size
		slot_btn.flat = true
		slot_btn.focus_mode = Control.FOCUS_NONE
		slot_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		var empty_style := StyleBoxEmpty.new()
		slot_btn.add_theme_stylebox_override("normal", empty_style)
		slot_btn.add_theme_stylebox_override("pressed", empty_style)
		slot_btn.add_theme_stylebox_override("hover", _make_slot_hover_style())
		var idx: int = i
		slot_btn.pressed.connect(func() -> void: _open_picker(idx))
		slot_ctrl.add_child(slot_btn)

		# Botão dedicado sobre a seta ▲ no topo do slot
		var arrow_btn := Button.new()
		arrow_btn.name = "ArrowButton_%d" % i
		arrow_btn.size = Vector2(ARROW_RADIUS * 2.0, ARROW_RADIUS * 2.0)
		arrow_btn.position = Vector2(cx - ARROW_RADIUS, ARROW_Y - ARROW_RADIUS)
		arrow_btn.focus_mode = Control.FOCUS_NONE
		arrow_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		arrow_btn.flat = true
		arrow_btn.tooltip_text = "Escolher habilidade para [%s]" % PlayerSkillController.SLOT_LABELS[i]
		arrow_btn.add_theme_stylebox_override("normal", empty_style)
		arrow_btn.add_theme_stylebox_override("hover", _make_arrow_hover_style())
		arrow_btn.add_theme_stylebox_override("pressed", _make_arrow_hover_style())
		arrow_btn.pressed.connect(func() -> void: _open_picker(idx))
		_scaler.add_child(arrow_btn)

		_slot_roots.append(slot_ctrl)
		_slot_icons.append(icon)
		_slot_arrow_btns.append(arrow_btn)
		_slot_click_btns.append(slot_btn)
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


func _open_picker(slot_idx: int) -> void:
	if controller == null:
		return
	if _picker_panel.visible and _picker_slot == slot_idx:
		_picker_panel.visible = false
		return
	_picker_slot = slot_idx
	var slot_name: String = PlayerSkillController.SLOT_LABELS[slot_idx]
	_picker_title.text = "Atribuir Habilidade a [%s] (Máx. %d Ativas)" % [slot_name, PlayerSkillController.MAX_ACTIVE_SKILLS]

	for child in _picker_list.get_children():
		child.queue_free()

	for sid in controller.get_assignable_skill_ids():
		var def: SkillDefinition = controller.skills[sid]
		var btn := Button.new()
		var tag: String = "  [Ataque Básico]" if def.is_basic_attack else ""
		var mana_tag: String = "  (💧 %d)" % def.mana_cost if def.mana_cost > 0 else ""
		var current: bool = controller.slots[slot_idx] == sid
		btn.text = ("✔ " if current else "   ") + def.display_name + tag + mana_tag
		btn.tooltip_text = "%s\nCusto de Mana: %d | Recarga: %.1fs\n%s" % [def.display_name, def.mana_cost, def.base_cooldown, def.description]
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

		var allowed: bool = controller.can_assign(slot_idx, sid)
		btn.disabled = not allowed
		if not allowed:
			btn.text += "  [Limite Atingido]"

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
	clear_btn.add_theme_color_override("font_color", MUTED_COLOR)
	clear_btn.pressed.connect(func() -> void:
		controller.assign_slot(_picker_slot, "")
		_picker_panel.visible = false
	)
	_picker_list.add_child(clear_btn)

	_picker_panel.visible = true
	_picker_panel.reset_size()
	await get_tree().process_frame

	var slot_ctrl: Control = _slot_roots[slot_idx]
	var sp: Vector2 = slot_ctrl.global_position
	var vp: Vector2 = get_viewport_rect().size
	var px: float = clampf(sp.x + (SLOT_WIDTH * ui_scale * 0.5) - (_picker_panel.size.x * 0.5), 10.0, vp.x - _picker_panel.size.x - 10.0)
	var py: float = maxf(10.0, global_position.y - _picker_panel.size.y - 12.0)
	_picker_panel.position = Vector2(px, py)


func refresh_slots() -> void:
	if controller == null:
		return
	for i in range(PlayerSkillController.SLOT_COUNT):
		var def: SkillDefinition = controller.get_slot_skill(i)
		if def == null:
			_slot_icons[i].texture = null
			_slot_click_btns[i].tooltip_text = "Slot [%s] vazio — clique na seta ▲ para atribuir" % PlayerSkillController.SLOT_LABELS[i]
			_slot_mana_labels[i].text = ""
			_slot_mana_overlays[i].visible = false
		else:
			_slot_icons[i].texture = _get_icon(def.icon_path)
			_slot_click_btns[i].tooltip_text = "%s (Custo: %d Mana)\n%s" % [def.display_name, def.mana_cost, def.description]
			if def.mana_cost > 0:
				_slot_mana_labels[i].text = "%d" % def.mana_cost
			else:
				_slot_mana_labels[i].text = ""


func refresh_mana_availability(mana_amount: int) -> void:
	if controller == null:
		return
	for i in range(PlayerSkillController.SLOT_COUNT):
		if i >= _slot_mana_overlays.size():
			continue
		var sid: String = controller.slots[i]
		if sid.is_empty():
			_slot_mana_overlays[i].visible = false
			continue
		var def: SkillDefinition = controller.skills.get(sid, null) as SkillDefinition
		if def != null and def.mana_cost > 0:
			var not_enough: bool = (mana_amount < def.mana_cost)
			_slot_mana_overlays[i].visible = not_enough
			_slot_mana_labels[i].add_theme_color_override("font_color", MANA_EMPTY if not_enough else MANA_BLUE)
		else:
			_slot_mana_overlays[i].visible = false


func _process(_delta: float) -> void:
	if controller == null or not visible:
		return

	var char_mana: int = 0
	if controller.character != null:
		char_mana = controller.character.mana

	for i in range(PlayerSkillController.SLOT_COUNT):
		var sid: String = controller.slots[i]
		if sid.is_empty():
			_slot_cd_curtains[i].size = Vector2(66, 0.0)
			_slot_cd_labels[i].text = ""
			_slot_mana_overlays[i].visible = false
			continue

		var ratio: float = controller.get_cooldown_ratio(sid)
		var remaining: float = controller.get_cooldown_remaining(sid)

		var icon_h: float = _slot_icons[i].size.y
		_slot_cd_curtains[i].size = Vector2(_slot_icons[i].size.x, icon_h * ratio)
		_slot_cd_curtains[i].position = Vector2(_slot_icons[i].position.x, _slot_icons[i].position.y + icon_h * (1.0 - ratio))
		_slot_cd_labels[i].text = ("%.1f" % remaining) if remaining > 0.30 else ""

		var def: SkillDefinition = controller.skills.get(sid, null)
		if def != null and def.mana_cost > 0:
			var not_enough_mana: bool = (char_mana < def.mana_cost)
			_slot_mana_overlays[i].visible = not_enough_mana
			_slot_mana_labels[i].add_theme_color_override("font_color", MANA_EMPTY if not_enough_mana else MANA_BLUE)
		else:
			_slot_mana_overlays[i].visible = false


func _on_skill_cast(skill_id: String) -> void:
	for i in range(PlayerSkillController.SLOT_COUNT):
		if controller != null and controller.slots[i] == skill_id:
			_trigger_slot_flash(i)


func _on_insufficient_mana(slot_idx: int, _cost: int) -> void:
	if slot_idx >= 0 and slot_idx < _slot_flash_overlays.size():
		var flash: ColorRect = _slot_flash_overlays[slot_idx]
		flash.color = Color(1.0, 0.2, 0.2, 0.55)
		var tw := create_tween()
		tw.tween_property(flash, "color", Color(1.0, 0.2, 0.2, 0.0), 0.25)


func _trigger_slot_flash(slot_idx: int) -> void:
	if slot_idx >= 0 and slot_idx < _slot_flash_overlays.size():
		var flash: ColorRect = _slot_flash_overlays[slot_idx]
		flash.color = Color(1.0, 0.95, 0.70, 0.65)
		var tw := create_tween()
		tw.tween_property(flash, "color", Color(1.0, 0.95, 0.70, 0.0), 0.20)


func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10.0:
		return

	var responsive_scale: float = clampf(vp.x / 1920.0 * 0.50, 0.36, 0.48)
	ui_scale = responsive_scale
	if _scaler != null:
		_scaler.scale = Vector2(ui_scale, ui_scale)

	custom_minimum_size = BASE_SIZE * ui_scale
	size = custom_minimum_size

	var center_x: float = (vp.x - size.x) * 0.5
	var margin_y: float = 8.0
	position = Vector2(center_x, vp.y - size.y - margin_y)


func _input(event: InputEvent) -> void:
	if _picker_panel == null or not _picker_panel.visible:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		var mpos: Vector2 = (event as InputEventMouseButton).position
		if _picker_panel.get_global_rect().has_point(mpos):
			return
		for abtn in _slot_arrow_btns:
			if abtn.get_global_rect().has_point(mpos):
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


static func _make_arrow_hover_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1.0, 0.85, 0.40, 0.35)
	s.border_color = Color(1.0, 0.90, 0.50, 0.90)
	s.set_border_width_all(1)
	s.set_corner_radius_all(12)
	return s


static func _make_slot_hover_style() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(1.0, 0.88, 0.45, 0.12)
	s.border_color = Color(1.0, 0.80, 0.30, 0.75)
	s.set_border_width_all(1)
	s.set_corner_radius_all(8)
	return s
