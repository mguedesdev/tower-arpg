extends Control
class_name SanctuaryLobbyHUD
## Lobby Minimalista do Santuário (A Torre).
## Deixa o cenário 3D e o Cavaleiro sobre o Altar totalmente visíveis,
## exibindo apenas um cartão limpo com Atributos + Passivas Ativas e os 2 botões principais.

signal start_battle_requested
signal open_talent_tree_requested
signal preview_attack_requested(form_index: int)
signal rotate_character_requested(delta_degrees: float)

const BG_DARK := Color(0.055, 0.045, 0.042, 0.93)
const BG_PILL := Color(0.095, 0.072, 0.062, 0.96)
const BORDER := Color(0.52, 0.39, 0.22, 0.92)
const TEXT := Color(0.92, 0.87, 0.76, 1.0)
const MUTED := Color(0.66, 0.60, 0.52, 1.0)
const MINT := Color(0.92, 0.64, 0.26, 1.0)
const GOLD := Color(0.88, 0.68, 0.32, 1.0)
const CRIMSON := Color(0.52, 0.11, 0.11, 0.98)
const CRIMSON_HOVER := Color(0.68, 0.16, 0.14, 1.0)

var _perm_service: PermanentProgressionService
var _run_service: RunProgressionService
var _player: TowerPlayer
var _attack: TowerAttackController

var _title_badge: Panel
var _title_lbl: Label
var _subtitle_lbl: Label

var _essence_badge: Panel
var _essence_lbl: Label

var _status_card: Panel
var _card_title_lbl: Label
var _stats_vbox: VBoxContainer
var _divider: ColorRect
var _passives_title_lbl: Label
var _passives_vbox: VBoxContainer

var _talents_btn: Button
var _start_btn: Button


func _ready() -> void:
	name = "SanctuaryLobbyHUD"
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_PASS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	_relayout()
	get_viewport().size_changed.connect(_relayout)


func bind_context(
	perm_service: PermanentProgressionService,
	run_service: RunProgressionService,
	player_node: TowerPlayer,
	attack_node: TowerAttackController
) -> void:
	if _perm_service != null:
		if _perm_service.currency_changed.is_connected(_on_perm_currency_changed):
			_perm_service.currency_changed.disconnect(_on_perm_currency_changed)
		if _perm_service.talents_changed.is_connected(refresh_lobby):
			_perm_service.talents_changed.disconnect(refresh_lobby)

	_perm_service = perm_service
	_run_service = run_service
	_player = player_node
	_attack = attack_node

	if _perm_service != null:
		_perm_service.currency_changed.connect(_on_perm_currency_changed)
		_perm_service.talents_changed.connect(refresh_lobby)

	refresh_lobby()


func _on_perm_currency_changed(_new_val: int) -> void:
	refresh_lobby()


func _build_ui() -> void:
	# 1. Topo Esquerdo: Selo discreto do Jogo (moldura gótica chanfrada)
	_title_badge = _make_panel(self, "TitleBadge", BG_DARK, BORDER, 2, 3)
	_title_lbl = _make_label(_title_badge, "A TORRE", 22, GOLD)
	_subtitle_lbl = _make_label(_title_badge, "SANTUÁRIO  •  GUERREIRO", 11, MUTED)

	# 2. Topo Direito: Saldo de Essência
	_essence_badge = _make_panel(self, "EssenceBadge", BG_DARK, GOLD, 2, 3)
	_essence_lbl = _make_label(_essence_badge, "✦ 0 ESSÊNCIA", 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	# 3. Esquerda: Cartão Compacto (4 Atributos + Passivas Ativas)
	_status_card = _make_panel(self, "StatusCard", BG_DARK, BORDER, 2, 3)
	_card_title_lbl = _make_label(_status_card, "ATRIBUTOS DO GUERREIRO", 12, GOLD)

	_stats_vbox = VBoxContainer.new()
	_stats_vbox.add_theme_constant_override("separation", 5)
	_status_card.add_child(_stats_vbox)

	_divider = ColorRect.new()
	_divider.color = BORDER
	_status_card.add_child(_divider)

	_passives_title_lbl = _make_label(_status_card, "PASSIVAS ATIVAS", 12, GOLD)
	_passives_vbox = VBoxContainer.new()
	_passives_vbox.add_theme_constant_override("separation", 4)
	_status_card.add_child(_passives_vbox)

	# 4. Rodapé Central: Apenas os 2 Botões Essenciais (Passivas em Bronze e Jogar em Carmesim/Ouro Gótico)
	_talents_btn = Button.new()
	_talents_btn.name = "TalentsButton"
	_talents_btn.text = "✦  PASSIVAS & TALENTOS"
	_talents_btn.add_theme_font_size_override("font_size", 15)
	_talents_btn.add_theme_color_override("font_color", TEXT)
	_talents_btn.add_theme_stylebox_override("normal", _style(BG_PILL, BORDER, 2, 3))
	_talents_btn.add_theme_stylebox_override("hover", _style(BG_PILL.lightened(0.10), GOLD, 2, 3))
	_talents_btn.add_theme_stylebox_override("pressed", _style(BG_PILL.darkened(0.10), GOLD, 2, 3))
	_talents_btn.pressed.connect(func() -> void: open_talent_tree_requested.emit())
	add_child(_talents_btn)

	_start_btn = Button.new()
	_start_btn.name = "StartBattleButton"
	_start_btn.text = "⚔  ENTRAR NA TORRE  (ENTER)"
	_start_btn.add_theme_font_size_override("font_size", 16)
	_start_btn.add_theme_color_override("font_color", TEXT)
	_start_btn.add_theme_stylebox_override("normal", _style(CRIMSON, GOLD, 2, 3))
	_start_btn.add_theme_stylebox_override("hover", _style(CRIMSON_HOVER, GOLD.lightened(0.2), 2, 3))
	_start_btn.add_theme_stylebox_override("pressed", _style(CRIMSON.darkened(0.2), GOLD, 2, 3))
	_start_btn.pressed.connect(func() -> void: start_battle_requested.emit())
	add_child(_start_btn)


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
		start_battle_requested.emit()
		get_viewport().set_input_as_handled()


func refresh_lobby() -> void:
	var essence: int = _perm_service.state.essence if _perm_service != null else 0
	_essence_lbl.text = "✦  %d ESSÊNCIA" % essence

	# Verifica se há alguma passiva que pode ser comprada agora para avisar no botão
	var any_buyable: bool = false
	if _perm_service != null:
		for def in _perm_service.talent_tree:
			if _perm_service.can_purchase_talent(def.id):
				any_buyable = true
				break
	_talents_btn.text = "✦  PASSIVAS  (EVOLUIR!)" if any_buyable else "✦  PASSIVAS & TALENTOS"

	_refresh_stats()
	_refresh_active_passives()
	_relayout()


func _refresh_stats() -> void:
	for child in _stats_vbox.get_children():
		child.queue_free()

	if _player == null or _player.stats == null:
		return

	var s: CharacterStats = _player.stats
	var def: CharacterDefinition = _player.character_definition
	var base_hp: int = def.base_max_health if def != null else 100
	var base_dmg: int = def.base_damage if def != null else 14

	var cur_hp: int = s.get_max_health()
	var cur_dmg: int = s.get_damage()
	var cur_aspd: float = s.get_attack_speed()
	var cur_spd: float = s.get_move_speed()

	_add_stat_line("♥  Vida", "%d" % cur_hp, cur_hp > base_hp)
	_add_stat_line("⚔  Dano", "%d" % cur_dmg, cur_dmg > base_dmg)
	_add_stat_line("⚡  Ataque", "%.2fx" % cur_aspd, cur_aspd > 1.01)
	_add_stat_line("👟  Velocidade", "%.1f" % cur_spd, cur_spd > 6.25)


func _add_stat_line(label_text: String, value_text: String, buffed: bool) -> void:
	var row := HBoxContainer.new()
	var l := Label.new()
	l.text = label_text
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", MUTED)
	row.add_child(l)

	var v := Label.new()
	v.text = value_text
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_theme_font_size_override("font_size", 14)
	v.add_theme_color_override("font_color", MINT if buffed else TEXT)
	row.add_child(v)

	_stats_vbox.add_child(row)


func _refresh_active_passives() -> void:
	for child in _passives_vbox.get_children():
		child.queue_free()

	var active_count: int = 0
	if _perm_service != null:
		for def in _perm_service.talent_tree:
			var rank: int = _perm_service.get_talent_rank(def.id)
			if rank <= 0:
				continue
			active_count += 1
			var item := Label.new()
			item.text = "✦ %s  (Nv %d/%d)" % [def.title, rank, def.max_rank]
			item.add_theme_font_size_override("font_size", 12)
			item.add_theme_color_override("font_color", MINT)
			_passives_vbox.add_child(item)

	if active_count == 0:
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhuma passiva ativa ainda."
		empty_lbl.add_theme_font_size_override("font_size", 12)
		empty_lbl.add_theme_color_override("font_color", MUTED)
		_passives_vbox.add_child(empty_lbl)


func _relayout() -> void:
	var vp: Vector2 = get_viewport_rect().size
	if vp.x < 10.0 or vp.y < 10.0:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var margin: float = 24.0

	# Topo Esquerdo
	_title_badge.position = Vector2(margin, margin)
	_title_badge.size = Vector2(230.0, 66.0)
	_title_lbl.position = Vector2(18.0, 8.0)
	_title_lbl.size = Vector2(194.0, 28.0)
	_subtitle_lbl.position = Vector2(18.0, 36.0)
	_subtitle_lbl.size = Vector2(194.0, 20.0)

	# Topo Direito
	_essence_badge.position = Vector2(vp.x - margin - 210.0, margin)
	_essence_badge.size = Vector2(210.0, 48.0)
	_essence_lbl.position = Vector2(10.0, 8.0)
	_essence_lbl.size = Vector2(190.0, 32.0)

	# Cartão Esquerdo Compacto
	var card_w: float = 250.0
	var passive_rows: int = maxi(1, _passives_vbox.get_child_count())
	var card_h: float = 205.0 + float(passive_rows) * 22.0
	_status_card.position = Vector2(margin, 106.0)
	_status_card.size = Vector2(card_w, card_h)

	_card_title_lbl.position = Vector2(16.0, 12.0)
	_card_title_lbl.size = Vector2(card_w - 32.0, 20.0)

	_stats_vbox.position = Vector2(16.0, 38.0)
	_stats_vbox.size = Vector2(card_w - 32.0, 108.0)

	_divider.position = Vector2(16.0, 152.0)
	_divider.size = Vector2(card_w - 32.0, 1.0)

	_passives_title_lbl.position = Vector2(16.0, 162.0)
	_passives_title_lbl.size = Vector2(card_w - 32.0, 20.0)

	_passives_vbox.position = Vector2(16.0, 186.0)
	_passives_vbox.size = Vector2(card_w - 32.0, float(passive_rows) * 22.0)

	# Rodapé Central: 2 Botões limpos lado a lado
	var btn_gap: float = 16.0
	var talents_w: float = 250.0
	var start_w: float = 270.0
	var total_w: float = talents_w + btn_gap + start_w
	var start_x: float = (vp.x - total_w) * 0.5
	var btn_y: float = vp.y - margin - 52.0

	_talents_btn.position = Vector2(start_x, btn_y)
	_talents_btn.size = Vector2(talents_w, 52.0)

	_start_btn.position = Vector2(start_x + talents_w + btn_gap, btn_y)
	_start_btn.size = Vector2(start_w, 52.0)


func _make_panel(parent_node: Node, node_name: String, bg: Color, border: Color, bw: int, radius: int) -> Panel:
	var p := Panel.new()
	p.name = node_name
	p.add_theme_stylebox_override("panel", _style(bg, border, bw, radius))
	parent_node.add_child(p)
	return p


func _make_label(parent_node: Node, txt: String, fsize: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = txt
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fsize)
	l.add_theme_color_override("font_color", col)
	parent_node.add_child(l)
	return l


func _style(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 5
	return s
