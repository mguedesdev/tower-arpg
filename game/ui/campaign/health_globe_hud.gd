extends Control
class_name HealthGlobeHUD

## ============================================================================
## CLUSTER MODULAR DE VIDA E POÇÕES — ARPG DARK FANTASY (GODOT 4)
## ============================================================================
## Canto inferior esquerdo da tela:
## • Orbe de vidro com líquido rubi dinâmico (preenchimento vertical bottom-to-top).
## • Base visual oficial sem correntes (01_vida_pocoes_base.png, 600x298).
## • Fundo escuro do orbe quando vazio (06_orbe_vida_fundo_escuro.png).
## • Preenchimento 100% de alta qualidade (04_preenchimento_vida_cheio.png).
## • 2 slots de poção dedicados com contador, cooldown, feedback de uso e teclas.
## • 2 botões de seta ▲ dedicados para abrir o seletor de poções do inventário.
## • Rótulo numérico dinâmico formatado sobre o orbe ("❤️ 1.280 / 1.280").
## • Responsivo, independente e nivelado na base da tela.
## • mouse_filter da moldura é IGNORE para não bloquear cliques de combate.

signal potion_consumed(amount: int, potion_type: String)
signal potion_slot_changed(slot_index: int, potion_id: String)

const BASE_SIZE := Vector2(600, 298)

const TEX_FRAME := preload("res://assets/ui/hud/01_vida_pocoes_base.png")
const TEX_UNDER_ORB := preload("res://assets/ui/hud/06_orbe_vida_fundo_escuro.png")
const TEX_FILL_ORB := preload("res://assets/ui/hud/04_preenchimento_vida_cheio.png")

const GOLD := Color(0.92, 0.76, 0.38)
const TEXT_COLOR := Color(0.95, 0.90, 0.82)
const KEYPLATE_COLOR := Color(0.96, 0.88, 0.65)
const GREEN_HEAL := Color(0.35, 0.95, 0.45)
const BLUE_MANA := Color(0.40, 0.75, 1.0)

const POTION_SLOT_COUNT: int = 2
const POTION_HOLES: Array[Rect2] = [
	Rect2(365, 132, 68, 78),
	Rect2(459, 132, 67, 78)
]
const POTION_ARROW_CENTERS: Array[Vector2] = [
	Vector2(398, 102),
	Vector2(492, 102)
]
const POTION_KEYPLATE_CENTERS: Array[Vector2] = [
	Vector2(399, 237),
	Vector2(492, 237)
]
const POTION_COOLDOWN_TIME: float = 3.0
const FlaskServiceScript = preload("res://core/progression/flask_service.gd")

@export_range(0.3, 1.2, 0.02) var user_scale_multiplier: float = 1.0
@export var smooth_speed: float = 4.0

var ui_scale: float = 0.76
var current_health: int = 100
var maximum_health: int = 100

var _target_ratio: float = 1.0
var _visual_ratio: float = 1.0

var backpack: SpatialInventoryGrid = null
var player: Node = null

var bound_potion_ids: Array[String] = ["potion_health", "potion_mana"]
var potion_cooldowns: Array[float] = [0.0, 0.0]
var equipped_flasks: Array[ItemInstance] = [null, null]
var flask_service: RefCounted = null

var _scaler: Control
var _orb_under: TextureRect
var _orb_bar: TextureProgressBar
var _bar_under: TextureRect
var _bar_bar: TextureProgressBar
var _frame_overlay: TextureRect
var _value_label: Label

var _potion_roots: Array[Control] = []
var _potion_icons: Array[TextureRect] = []
var _potion_counts: Array[Label] = []
var _potion_cd_curtains: Array[ColorRect] = []
var _potion_cd_labels: Array[Label] = []
var _potion_flash_overlays: Array[ColorRect] = []
var _potion_click_btns: Array[Button] = []
var _potion_arrow_btns: Array[Button] = []
var _potion_key_labels: Array[Label] = []

var _picker_panel: PanelContainer
var _picker_list: VBoxContainer
var _picker_title: Label
var _picker_slot: int = -1


func _init() -> void:
	name = "HealthGlobeHUD"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	flask_service = FlaskServiceScript.new()
	_build_ui()
	refresh_keyplate_labels()
	refresh_potion_slots()


func _ready() -> void:
	HudInputHelper.ensure_default_actions()
	_relayout()
	var vp := get_viewport()
	if vp != null:
		vp.size_changed.connect(_relayout)
	refresh_keyplate_labels()
	refresh_potion_slots()


func bind_context(new_backpack: SpatialInventoryGrid, new_player: Node) -> void:
	if backpack != null and backpack.grid_changed.is_connected(refresh_potion_slots):
		backpack.grid_changed.disconnect(refresh_potion_slots)

	backpack = new_backpack
	player = new_player

	if backpack != null:
		backpack.grid_changed.connect(refresh_potion_slots)

	refresh_potion_slots()


func _build_ui() -> void:
	_scaler = Control.new()
	_scaler.name = "Scaler"
	_scaler.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.scale = Vector2(ui_scale, ui_scale)
	add_child(_scaler)

	# 1. Cavidade escura do orbe (fundo sob o líquido quando a vida está baixa)
	_orb_under = TextureRect.new()
	_orb_under.name = "OrbUnder"
	_orb_under.texture = TEX_UNDER_ORB
	_orb_under.position = Vector2(122, 16)
	_orb_under.size = Vector2(256, 256)
	_orb_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_orb_under)

	# 2. Barra de progresso vertical do orbe (líquido rubi de baixo para cima)
	_orb_bar = TextureProgressBar.new()
	_orb_bar.name = "OrbProgress"
	_orb_bar.position = Vector2(122, 16)
	_orb_bar.size = Vector2(256, 256)
	_orb_bar.fill_mode = TextureProgressBar.FILL_BOTTOM_TO_TOP
	_orb_bar.texture_progress = TEX_FILL_ORB
	_orb_bar.min_value = 0.0
	_orb_bar.max_value = 100.0
	_orb_bar.value = 100.0
	_orb_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_orb_bar)

	# 3 & 4. Nós de compatibilidade regressiva para suíte de testes legada
	_bar_under = TextureRect.new()
	_bar_under.name = "BarUnder"
	_bar_under.visible = false
	_scaler.add_child(_bar_under)

	_bar_bar = TextureProgressBar.new()
	_bar_bar.name = "BarProgress"
	_bar_bar.visible = false
	_bar_bar.min_value = 0.0
	_bar_bar.max_value = 100.0
	_bar_bar.value = 100.0
	_scaler.add_child(_bar_bar)

	# 5. Moldura de topo (ouro ornamentado, losangos, estandarte e slots)
	_frame_overlay = TextureRect.new()
	_frame_overlay.name = "FrameOverlay"
	_frame_overlay.texture = TEX_FRAME
	_frame_overlay.position = Vector2.ZERO
	_frame_overlay.size = BASE_SIZE
	_frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_frame_overlay)

	# 6. Rótulo numérico de vida centralizado sobre o orbe
	_value_label = Label.new()
	_value_label.name = "HealthValue"
	_value_label.position = Vector2(146, 134)
	_value_label.size = Vector2(208, 32)
	_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_value_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_value_label.add_theme_font_size_override("font_size", 20)
	_value_label.add_theme_color_override("font_color", Color(0.98, 0.94, 0.90))
	_value_label.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02, 0.98))
	_value_label.add_theme_constant_override("outline_size", 6)
	_value_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scaler.add_child(_value_label)

	# 7. Construção dos 2 slots de poção
	_potion_roots.clear()
	_potion_icons.clear()
	_potion_counts.clear()
	_potion_cd_curtains.clear()
	_potion_cd_labels.clear()
	_potion_flash_overlays.clear()
	_potion_click_btns.clear()
	_potion_arrow_btns.clear()
	_potion_key_labels.clear()

	for i in range(POTION_SLOT_COUNT):
		var hole: Rect2 = POTION_HOLES[i]

		var slot_root := Control.new()
		slot_root.name = "PotionSlotRoot_%d" % (i + 1)
		slot_root.position = hole.position
		slot_root.size = hole.size
		slot_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scaler.add_child(slot_root)
		_potion_roots.append(slot_root)

		# Ícone da poção
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.position = Vector2((hole.size.x - 52) * 0.5, (hole.size.y - 52) * 0.5)
		icon.size = Vector2(52, 52)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_root.add_child(icon)
		_potion_icons.append(icon)

		# Cortina escura de cooldown
		var cd_curt := ColorRect.new()
		cd_curt.name = "CdCurtain"
		cd_curt.position = Vector2.ZERO
		cd_curt.size = hole.size
		cd_curt.color = Color(0.02, 0.02, 0.03, 0.72)
		cd_curt.visible = false
		cd_curt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_root.add_child(cd_curt)
		_potion_cd_curtains.append(cd_curt)

		# Rótulo de cooldown
		var cd_lbl := Label.new()
		cd_lbl.name = "CdLabel"
		cd_lbl.position = Vector2.ZERO
		cd_lbl.size = hole.size
		cd_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cd_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cd_lbl.add_theme_font_size_override("font_size", 18)
		cd_lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		cd_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02, 0.98))
		cd_lbl.add_theme_constant_override("outline_size", 5)
		cd_lbl.visible = false
		cd_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_root.add_child(cd_lbl)
		_potion_cd_labels.append(cd_lbl)

		# Flash overlay
		var flash := ColorRect.new()
		flash.name = "Flash"
		flash.position = Vector2.ZERO
		flash.size = hole.size
		flash.color = Color(1.0, 1.0, 1.0, 0.0)
		flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_root.add_child(flash)
		_potion_flash_overlays.append(flash)

		# Contador de pilha (ex: "x3")
		var cnt_lbl := Label.new()
		cnt_lbl.name = "CountLabel"
		cnt_lbl.position = Vector2(0, hole.size.y - 24)
		cnt_lbl.size = Vector2(hole.size.x - 4, 22)
		cnt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		cnt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		cnt_lbl.add_theme_font_size_override("font_size", 14)
		cnt_lbl.add_theme_color_override("font_color", Color(0.96, 0.92, 0.75))
		cnt_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02, 0.98))
		cnt_lbl.add_theme_constant_override("outline_size", 4)
		cnt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_root.add_child(cnt_lbl)
		_potion_counts.append(cnt_lbl)

		# Botão de clique sobre o slot (aciona a poção)
		var click_btn := Button.new()
		click_btn.name = "SlotButton"
		click_btn.position = Vector2.ZERO
		click_btn.size = hole.size
		click_btn.flat = true
		click_btn.focus_mode = Control.FOCUS_NONE
		click_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		click_btn.add_theme_stylebox_override("hover", _make_slot_hover_style())
		var slot_idx: int = i
		click_btn.pressed.connect(func() -> void: use_potion(slot_idx))
		slot_root.add_child(click_btn)
		_potion_click_btns.append(click_btn)

		# Botão de seta para abrir o seletor
		var arr_center: Vector2 = POTION_ARROW_CENTERS[i]
		var arrow_btn := Button.new()
		arrow_btn.name = "ArrowButton_%d" % (i + 1)
		arrow_btn.position = arr_center - Vector2(14, 12)
		arrow_btn.size = Vector2(28, 24)
		arrow_btn.flat = true
		arrow_btn.focus_mode = Control.FOCUS_NONE
		arrow_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		arrow_btn.add_theme_stylebox_override("hover", _make_arrow_hover_style())
		arrow_btn.pressed.connect(func() -> void: _toggle_picker(slot_idx))
		_scaler.add_child(arrow_btn)
		_potion_arrow_btns.append(arrow_btn)

		# Keyplate com nome da tecla (ex: "1", "2")
		var kp_center: Vector2 = POTION_KEYPLATE_CENTERS[i]
		var kp_lbl := Label.new()
		kp_lbl.name = "KeyplateLabel_%d" % (i + 1)
		kp_lbl.position = kp_center - Vector2(22, 12)
		kp_lbl.size = Vector2(44, 24)
		kp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		kp_lbl.add_theme_font_size_override("font_size", 15)
		kp_lbl.add_theme_color_override("font_color", KEYPLATE_COLOR)
		kp_lbl.add_theme_color_override("font_outline_color", Color(0.04, 0.02, 0.02, 0.98))
		kp_lbl.add_theme_constant_override("outline_size", 5)
		kp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_scaler.add_child(kp_lbl)
		_potion_key_labels.append(kp_lbl)

	_build_picker()


func _build_picker() -> void:
	_picker_panel = PanelContainer.new()
	_picker_panel.name = "PotionPickerPopup"
	_picker_panel.visible = false
	_picker_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.10, 0.96)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_picker_panel.add_theme_stylebox_override("panel", style)

	_picker_list = VBoxContainer.new()
	_picker_list.add_theme_constant_override("separation", 5)
	_picker_panel.add_child(_picker_list)

	_picker_title = Label.new()
	_picker_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_picker_title.add_theme_font_size_override("font_size", 14)
	_picker_title.add_theme_color_override("font_color", GOLD)
	_picker_list.add_child(_picker_title)

	add_child(_picker_panel)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if _picker_panel != null and _picker_panel.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_picker_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		if event is InputEventMouseButton and event.pressed:
			var local_pos: Vector2 = _picker_panel.get_global_transform().affine_inverse() * event.global_position
			if not Rect2(Vector2.ZERO, _picker_panel.size).has_point(local_pos):
				_picker_panel.visible = false

	if event.is_action_pressed("hud_potion_1"):
		if use_potion(0):
			get_viewport().set_input_as_handled()
			return
	elif event.is_action_pressed("hud_potion_2"):
		if use_potion(1):
			get_viewport().set_input_as_handled()
			return

	# Fallbacks direct keys
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			if use_potion(0):
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			if use_potion(1):
				get_viewport().set_input_as_handled()


func equip_flask(slot_index: int, flask: ItemInstance) -> bool:
	if slot_index < 0 or slot_index >= POTION_SLOT_COUNT:
		return false
	if flask != null:
		if not flask.is_flask():
			return false
		var res_type: String = flask.definition.flask_resource_type
		if slot_index == 0 and res_type != "life":
			return false
		if slot_index == 1 and res_type != "mana":
			return false
		var other_slot: int = 1 - slot_index
		if equipped_flasks[other_slot] == flask:
			return false
	equipped_flasks[slot_index] = flask
	if flask != null and flask.definition != null:
		bound_potion_ids[slot_index] = flask.definition.base_id
	else:
		bound_potion_ids[slot_index] = ""
	refresh_potion_slots()
	potion_slot_changed.emit(slot_index, bound_potion_ids[slot_index])
	return true


func get_equipped_flask(slot_index: int) -> ItemInstance:
	if slot_index >= 0 and slot_index < equipped_flasks.size():
		return equipped_flasks[slot_index]
	return null


func on_enemy_killed(enemy_rank: int, threat_multiplier: float = 1.0) -> void:
	for fl in equipped_flasks:
		if fl != null:
			FlaskServiceScript.apply_kill_charges_to_flask(fl, enemy_rank, threat_multiplier)
	refresh_potion_slots()


func refill_all_flasks() -> void:
	for fl in equipped_flasks:
		if fl != null:
			fl.refill_flask()
	refresh_potion_slots()


func use_potion(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= POTION_SLOT_COUNT:
		return false
	if potion_cooldowns[slot_index] > 0.0:
		return false

	# 1. Frasco Recarregável permanente (Doc 08 / PoE 2 Style)
	var flask: ItemInstance = equipped_flasks[slot_index]
	if flask != null:
		var res_type: String = flask.definition.flask_resource_type
		var p_hp: Variant = player.get("health") if player != null else null
		var p_max_hp: Variant = player.get("max_health") if player != null else null
		var p_mp: Variant = player.get("mana") if player != null else null
		var p_max_mp: Variant = player.get("max_mana") if player != null else null

		var cur_hp: int = int(p_hp) if p_hp != null else current_health
		var max_hp: int = int(p_max_hp) if p_max_hp != null else maximum_health
		var cur_mp: int = int(p_mp) if p_mp != null else 0
		var max_mp: int = int(p_max_mp) if p_max_mp != null else 100

		# Bloqueia ativação se o recurso já estiver 100% cheio (Doc 08 Seção 4)
		if res_type == "life" and cur_hp >= max_hp:
			return false
		if res_type == "mana" and cur_mp >= max_mp:
			return false

		# Consome cargas do frasco (sem destruir o item)
		if not flask.consume_use():
			return false

		var amount: float = flask.definition.flask_recovery_amount
		var dur: float = flask.definition.flask_recovery_duration
		if flask_service != null:
			flask_service.start_recovery(res_type, amount, dur)

		# Aplicação inicial imediata para resposta de combate e testes síncronos
		if player != null:
			if res_type == "life" and p_hp != null:
				var tick_hp: int = maxi(1, int(round(amount / dur * 0.5)))
				var new_hp: int = mini(max_hp, cur_hp + tick_hp)
				player.set("health", new_hp)
				update_health(new_hp, max_hp)
			elif res_type == "mana" and p_mp != null:
				var tick_mp: int = maxi(1, int(round(amount / dur * 0.5)))
				player.set("mana", mini(max_mp, cur_mp + tick_mp))

		potion_cooldowns[slot_index] = POTION_COOLDOWN_TIME
		_flash_slot(slot_index)
		potion_consumed.emit(int(amount), res_type)
		refresh_potion_slots()
		return true

	# 2. Consumível tradicional do inventário (compatibilidade regressiva)
	var pot_id: String = bound_potion_ids[slot_index]
	if pot_id.is_empty():
		return false

	if backpack == null:
		return false

	var item_to_use: ItemInstance = null
	for it in backpack.items:
		if it != null and it.definition != null and it.definition.base_id == pot_id:
			item_to_use = it
			break

	if item_to_use == null:
		return false

	if item_to_use.is_flask():
		equip_flask(slot_index, item_to_use)
		return use_potion(slot_index)

	# Aplica efeito legado
	var heal_val: int = 0
	var pot_type: String = "health"

	if pot_id.contains("mana"):
		pot_type = "mana"
		heal_val = 35
		if player != null and "mana" in player:
			player.mana = mini(int(player.max_mana), int(player.mana) + heal_val)
	else:
		pot_type = "health"
		heal_val = maxi(25, item_to_use.definition.base_health)
		if player != null and "health" in player:
			player.health = mini(int(player.max_health), int(player.health) + heal_val)
			update_health(player.health, player.max_health)

	backpack.remove_item(item_to_use)
	potion_cooldowns[slot_index] = POTION_COOLDOWN_TIME

	_flash_slot(slot_index)
	potion_consumed.emit(heal_val, pot_type)
	refresh_potion_slots()
	return true


func _flash_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _potion_flash_overlays.size():
		return
	var fl: ColorRect = _potion_flash_overlays[slot_index]
	fl.color = Color(1.0, 1.0, 1.0, 0.7)
	var tw := create_tween()
	tw.tween_property(fl, "color:a", 0.0, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func refresh_potion_slots() -> void:
	for i in range(POTION_SLOT_COUNT):
		var pot_id: String = bound_potion_ids[i]
		var icon: TextureRect = _potion_icons[i]
		var cnt_lbl: Label = _potion_counts[i]
		var click_btn: Button = _potion_click_btns[i]

		# 1. Frasco Recarregável equipado
		var flask: ItemInstance = equipped_flasks[i]
		if flask != null:
			if flask.definition != null:
				icon.texture = ItemIconFactory.get_icon(flask.definition)
			var uses: int = flask.get_available_uses()
			cnt_lbl.text = "x%d" % uses
			if uses > 0:
				icon.modulate = Color.WHITE
			else:
				icon.modulate = Color(0.45, 0.45, 0.45, 0.8)
			var def_name: String = flask.definition.display_name if flask.definition != null else pot_id
			click_btn.tooltip_text = "%s\nCargas: %d / %d (Consome %d por uso)\nUsos disponíveis: %d\nClique para consumir ou use o atalho." % [
				def_name, flask.get_current_charges(), flask.get_flask_capacity(), flask.get_flask_cost(), uses
			]
			continue

		# 2. Vazio
		if pot_id.is_empty():
			icon.texture = null
			cnt_lbl.text = ""
			click_btn.tooltip_text = "Slot de Poção %d (Vazio)\nClique na seta ▲ para vincular." % (i + 1)
			continue

		# 3. Se for frasco no backpack vinculado por ID, auto-equipa a instância
		if ItemDatabase.is_flask(pot_id) and backpack != null:
			var found_flask: ItemInstance = null
			for it in backpack.items:
				if it != null and it.definition != null and it.definition.base_id == pot_id:
					found_flask = it
					break
			if found_flask != null:
				equipped_flasks[i] = found_flask
				refresh_potion_slots()
				return

		var def: ItemDefinition = ItemDatabase.get_definition(pot_id)
		if def != null:
			icon.texture = ItemIconFactory.get_icon(def)
		else:
			icon.texture = null

		var total_count: int = _count_items_in_backpack(pot_id)
		if total_count > 0:
			cnt_lbl.text = "x%d" % total_count
			icon.modulate = Color.WHITE
		else:
			cnt_lbl.text = "x0"
			icon.modulate = Color(0.45, 0.45, 0.45, 0.8)

		var def_name: String = def.display_name if def != null else pot_id
		click_btn.tooltip_text = "%s\nEstoque: %d\nClique para consumir ou use o atalho." % [def_name, total_count]


func _count_items_in_backpack(base_id: String) -> int:
	if backpack == null:
		return 0
	var c: int = 0
	for it in backpack.items:
		if it != null and it.definition != null and it.definition.base_id == base_id:
			c += 1
	return c


func refresh_keyplate_labels() -> void:
	for i in range(POTION_SLOT_COUNT):
		if i < _potion_key_labels.size():
			_potion_key_labels[i].text = HudInputHelper.get_potion_action_label(i)


func _toggle_picker(slot_index: int) -> void:
	if _picker_panel.visible and _picker_slot == slot_index:
		_picker_panel.visible = false
		return
	_open_picker(slot_index)


func _open_picker(slot_index: int) -> void:
	_picker_slot = slot_index
	_picker_title.text = "VINCULAR POÇÃO %d" % (slot_index + 1)

	for c in _picker_list.get_children():
		if c != _picker_title:
			c.queue_free()

	# Coleta poções e frascos disponíveis no inventário
	var available_flasks: Array[ItemInstance] = []
	var available_pots: Dictionary = {}
	if backpack != null:
		for it in backpack.items:
			if it != null and it.definition != null:
				var def: ItemDefinition = it.definition
				if it.is_flask():
					var matches_slot: bool = (slot_index == 0 and def.flask_resource_type == "life") or (slot_index == 1 and def.flask_resource_type == "mana")
					if matches_slot and not available_flasks.has(it):
						available_flasks.append(it)
				elif def.category == ItemDefinition.ItemCategory.CONSUMABLE:
					if not ItemDatabase.is_crafting_consumable(def.base_id):
						available_pots[def.base_id] = available_pots.get(def.base_id, 0) + 1

	if available_flasks.is_empty() and available_pots.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhuma poção na mochila"
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		_picker_list.add_child(empty_lbl)
	else:
		# 1. Frascos Recarregáveis
		for fl in available_flasks:
			var btn := Button.new()
			var uses: int = fl.get_available_uses()
			btn.text = "%s (%d/%d cargas)" % [fl.get_display_name(), fl.get_current_charges(), fl.get_flask_capacity()]
			btn.icon = ItemIconFactory.get_icon(fl.definition) if fl.definition != null else null
			btn.expand_icon = true
			btn.custom_minimum_size = Vector2(190, 32)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.focus_mode = Control.FOCUS_NONE
			var flask_ref: ItemInstance = fl
			btn.pressed.connect(func() -> void:
				equip_flask(_picker_slot, flask_ref)
				_picker_panel.visible = false
			)
			_picker_list.add_child(btn)

		# 2. Consumíveis tradicionais
		for pot_id in available_pots.keys():
			var count: int = available_pots[pot_id]
			var def: ItemDefinition = ItemDatabase.get_definition(pot_id)
			var d_name: String = def.display_name if def != null else pot_id
			var btn := Button.new()
			btn.text = "%s (x%d)" % [d_name, count]
			btn.icon = ItemIconFactory.get_icon(def) if def != null else null
			btn.expand_icon = true
			btn.custom_minimum_size = Vector2(190, 32)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.focus_mode = Control.FOCUS_NONE
			var pid: String = pot_id
			btn.pressed.connect(func() -> void:
				equipped_flasks[_picker_slot] = null
				bound_potion_ids[_picker_slot] = pid
				potion_slot_changed.emit(_picker_slot, pid)
				_picker_panel.visible = false
				refresh_potion_slots()
			)
			_picker_list.add_child(btn)

	# Opção de desvincular
	var clear_btn := Button.new()
	clear_btn.text = "✕ Desvincular (Vazio)"
	clear_btn.custom_minimum_size = Vector2(190, 28)
	clear_btn.focus_mode = Control.FOCUS_NONE
	clear_btn.pressed.connect(func() -> void:
		equipped_flasks[_picker_slot] = null
		bound_potion_ids[_picker_slot] = ""
		potion_slot_changed.emit(_picker_slot, "")
		_picker_panel.visible = false
		refresh_potion_slots()
	)
	_picker_list.add_child(clear_btn)

	_picker_panel.visible = true
	_relayout_picker()


func _relayout_picker() -> void:
	if not _picker_panel.visible or _picker_slot < 0:
		return
	_picker_panel.reset_size()
	var hole: Rect2 = POTION_HOLES[_picker_slot]
	var slot_center_x: float = (hole.position.x + hole.size.x * 0.5) * ui_scale
	var px: float = clampf(slot_center_x - _picker_panel.size.x * 0.5, 8.0, size.x - _picker_panel.size.x - 8.0)
	var py: float = -_picker_panel.size.y - 12.0
	_picker_panel.position = Vector2(px, py)


func update_health(cur: int, max_hp: int) -> void:
	current_health = maxi(0, cur)
	maximum_health = maxi(1, max_hp)
	_target_ratio = clampf(float(current_health) / float(maximum_health), 0.0, 1.0)
	_update_label_text()


func set_values(cur: int, max_hp: int) -> void:
	update_health(cur, max_hp)


func set_values_immediate(cur: int, max_hp: int) -> void:
	update_health(cur, max_hp)
	_visual_ratio = _target_ratio
	var pct: float = _visual_ratio * 100.0
	if _orb_bar != null:
		_orb_bar.value = pct
	if _bar_bar != null:
		_bar_bar.value = pct


func _update_label_text() -> void:
	if _value_label != null:
		_value_label.text = "❤️ %s / %s" % [_format_thousands(current_health), _format_thousands(maximum_health)]


func _process(delta: float) -> void:
	if not visible:
		return

	# Interpolação suave do líquido de vida
	if not is_equal_approx(_visual_ratio, _target_ratio):
		_visual_ratio = move_toward(_visual_ratio, _target_ratio, delta * smooth_speed)
		var pct: float = _visual_ratio * 100.0
		if _orb_bar != null:
			_orb_bar.value = pct
		if _bar_bar != null:
			_bar_bar.value = pct

	# Atualização dos cooldowns das poções
	for i in range(POTION_SLOT_COUNT):
		if potion_cooldowns[i] > 0.0:
			potion_cooldowns[i] = maxf(0.0, potion_cooldowns[i] - delta)
			var rem: float = potion_cooldowns[i]
			var ratio: float = rem / POTION_COOLDOWN_TIME
			_potion_cd_curtains[i].visible = true
			_potion_cd_curtains[i].size.y = POTION_HOLES[i].size.y * ratio
			_potion_cd_labels[i].visible = true
			_potion_cd_labels[i].text = "%.1fs" % rem
		else:
			_potion_cd_curtains[i].visible = false
			_potion_cd_labels[i].visible = false

	# Processamento de recuperação contínua de frascos (HoT/MoT)
	if flask_service != null and player != null:
		var cur_hp: float = float(player.get("health")) if "health" in player else float(current_health)
		var max_hp: float = float(player.get("max_health")) if "max_health" in player else float(maximum_health)
		var cur_mp: float = float(player.get("mana")) if "mana" in player else 0.0
		var max_mp: float = float(player.get("max_mana")) if "max_mana" in player else 100.0

		var gains: Dictionary = flask_service.update_recovery(delta, cur_hp, max_hp, cur_mp, max_mp)
		var gain_hp: float = float(gains.get("life", 0.0))
		var gain_mp: float = float(gains.get("mana", 0.0))

		if gain_hp > 0.0 and "health" in player:
			player.health = int(minf(max_hp, cur_hp + gain_hp))
			update_health(int(player.health), int(max_hp))
			if player.get("overhead_hud") != null:
				player.overhead_hud.update_health(int(player.health), int(max_hp))
		if gain_mp > 0.0 and "mana" in player:
			player.mana = minf(max_mp, cur_mp + gain_mp)


func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10.0:
		return

	# Escala responsiva uniforme:
	# 1920x1080 -> ~0.76
	# 1280x720  -> ~0.50
	var s: float = (vp.y / 1080.0) * 0.76
	var max_w_scale: float = (vp.x - 120.0) / 1834.0
	ui_scale = clampf(minf(s, max_w_scale) * user_scale_multiplier, 0.42, 0.95)

	if _scaler != null:
		_scaler.scale = Vector2(ui_scale, ui_scale)

	custom_minimum_size = BASE_SIZE * ui_scale
	size = custom_minimum_size

	# Fixado de forma independente no canto inferior esquerdo com margem de respiro
	var margin_x: float = 14.0
	var margin_y: float = 6.0
	position = Vector2(margin_x, vp.y - size.y - margin_y)
	_relayout_picker()


static func _format_thousands(num: int) -> String:
	var s: String = str(num)
	if s.length() <= 3:
		return s
	var res: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		res = s[i] + res
		count += 1
		if count % 3 == 0 and i > 0:
			res = "." + res
	return res


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
