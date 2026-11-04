extends Control
class_name RunXpHUD
## V0.18 - HUD de gameplay dark fantasy.
## Substitui apenas a camada visual criada pela v0.17.
## Mantem o contrato attach_progression(service) e nao altera regras de jogo.

const BG := Color(0.042, 0.057, 0.071, 0.93)
const BG_STRONG := Color(0.035, 0.048, 0.060, 0.97)
const BG_SLOT := Color(0.076, 0.094, 0.109, 0.94)
const BORDER := Color(0.27, 0.32, 0.34, 0.85)
const TEXT := Color(0.96, 0.94, 0.87, 1.0)
const MUTED := Color(0.62, 0.68, 0.67, 1.0)
const MINT := Color(0.55, 0.82, 0.69, 1.0)
const GOLD := Color(0.92, 0.72, 0.40, 1.0)
const RED := Color(0.88, 0.36, 0.33, 1.0)

const ICON_STAB: Texture2D = preload("res://game/ui/icons/stab.png")
const ICON_ARC: Texture2D = preload("res://game/ui/icons/arc.png")
const ICON_SPIN: Texture2D = preload("res://game/ui/icons/spin.png")

var _service: RunProgressionService
var _arena: Node
var _player: Node
var _attack: Node
var _status_source: Label

var _header_panel: Panel
var _location_label: Label
var _location_subtitle: Label
var _wave_header: Label
var _kills_header: Label
var _wave_divider: ColorRect
var _wave_panel: Panel
var _life_panel: Panel
var _xp_panel: Panel
var _forms_root: Control
var _toast_panel: Panel

var _hp_bar: ProgressBar
var _xp_bar: ProgressBar
var _hp_caption: Label
var _hp_value: Label
var _hp_warning: Label
var _level_label: Label
var _xp_value: Label
var _pending_label: Label
var _wave_value: Label
var _kills_value: Label
var _toast_label: Label
var _form_slots: Array[Panel] = []
var _form_icons: Array[TextureRect] = []
var _form_names: Array[Label] = []
var _form_keys: Array[Label] = []

var _hp_tween: Tween
var _xp_tween: Tween
var _last_wave: int = -1
var _last_kills: int = -1
var _last_status: String = ""
var _refresh_timer: float = 0.0
var _toast_timer: float = 0.0
var _toast_priority: int = 0
var _pending_count: int = 0
var _dead: bool = false
var _current_form: int = 0


func _ready() -> void:
    name = "RunXpHUD"
    process_mode = Node.PROCESS_MODE_ALWAYS
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build_ui()
    _bind_existing_game()
    _layout()
    get_viewport().size_changed.connect(_layout)
    set_process(true)


func attach_progression(service: RunProgressionService) -> void:
    if _service != null:
        if _service.progress_changed.is_connected(_on_progress_changed):
            _service.progress_changed.disconnect(_on_progress_changed)
        if _service.choices_changed.is_connected(_on_choices_changed):
            _service.choices_changed.disconnect(_on_choices_changed)
        if _service.level_gained.is_connected(_on_level_gained):
            _service.level_gained.disconnect(_on_level_gained)
    _service = service
    if _service == null:
        return
    _service.progress_changed.connect(_on_progress_changed)
    _service.choices_changed.connect(_on_choices_changed)
    _service.level_gained.connect(_on_level_gained)
    _on_progress_changed(
        _service.state.level,
        _service.state.xp,
        _service.balance.xp_to_next_level(_service.state.level)
    )
    _on_choices_changed(_service.state.pending_upgrade_choices)


func _bind_existing_game() -> void:
    # Main.gd v0.17 ainda escreve nesses nodes. So os ocultamos na tela;
    # ficam presentes para evitar quebrar os caminhos de @onready.
    var canvas: Node = get_parent()
    if canvas == null:
        return
    for legacy_path in ["TitlePlate", "Info", "ControlsPlate", "StatusLabel"]:
        var legacy_node: CanvasItem = canvas.get_node_or_null(NodePath(String(legacy_path))) as CanvasItem
        if legacy_node != null:
            legacy_node.visible = false

    _status_source = canvas.get_node_or_null("StatusLabel") as Label
    _arena = canvas.get_parent()
    if _arena == null:
        return
    _player = _arena.get_node_or_null("Player")
    _attack = _arena.get_node_or_null("Player/AttackController")

    if _player != null:
        if _player.has_signal("health_changed"):
            _player.connect("health_changed", Callable(self, "_on_health_changed"))
        if _player.has_signal("died"):
            _player.connect("died", Callable(self, "_on_player_died"))
        _on_health_changed(int(_player.get("health")), int(_player.get("max_health")))

    if _attack != null:
        if _attack.has_signal("form_changed"):
            _attack.connect("form_changed", Callable(self, "_on_form_changed"))
        if _attack.has_method("form_label"):
            _on_form_changed(String(_attack.call("form_label")))

    _update_wave_kills()


func _build_ui() -> void:
    # Cabecalho discreto; a area central do combate permanece desobstruida.
    _header_panel = _panel(self, "Location", BG, BORDER, 1)
    _make_rect(_header_panel, "Accent", Vector2(14, 18), Vector2(3, 40), MINT)
    _location_label = _label(_header_panel, "ALTAR PROFANADO", 18, TEXT, Vector2(29, 14), Vector2(230, 28))
    _location_subtitle = _label(_header_panel, "A TORRE  /  GUERREIRO", 11, MINT, Vector2(30, 43), Vector2(230, 18))

    _wave_panel = _panel(self, "WaveCounter", BG, BORDER, 1)
    _wave_header = _label(_wave_panel, "ONDA ATUAL", 10, MUTED, Vector2(16, 10), Vector2(132, 18))
    _wave_value = _label(_wave_panel, "01", 30, TEXT, Vector2(14, 25), Vector2(90, 37))
    _wave_divider = _make_rect(_wave_panel, "Separator", Vector2(106, 15), Vector2(1, 45), BORDER)
    _kills_header = _label(_wave_panel, "ABATES", 10, MUTED, Vector2(122, 12), Vector2(104, 19))
    _kills_value = _label(_wave_panel, "0", 22, GOLD, Vector2(122, 28), Vector2(110, 32))

    _life_panel = _panel(self, "Life", BG_STRONG, BORDER, 1)
    _make_rect(_life_panel, "Accent", Vector2(14, 15), Vector2(3, 23), RED)
    _hp_caption = _label(_life_panel, "VIDA", 12, MUTED, Vector2(26, 14), Vector2(86, 25))
    _hp_value = _label(_life_panel, "100 / 100", 18, TEXT, Vector2(123, 10), Vector2(180, 31), HORIZONTAL_ALIGNMENT_RIGHT)
    _hp_bar = _bar(_life_panel, "HealthBar", RED)
    _hp_warning = _label(_life_panel, "GUERREIRO  •  EM COMBATE", 10, MUTED, Vector2(17, 79), Vector2(265, 19))

    _xp_panel = _panel(self, "Experience", BG_STRONG, BORDER, 1)
    _make_rect(_xp_panel, "Accent", Vector2(14, 15), Vector2(3, 23), GOLD)
    _level_label = _label(_xp_panel, "NÍVEL 01", 18, TEXT, Vector2(26, 12), Vector2(132, 27))
    _xp_value = _label(_xp_panel, "0 / 12 XP", 12, MUTED, Vector2(158, 17), Vector2(156, 20), HORIZONTAL_ALIGNMENT_RIGHT)
    _xp_bar = _bar(_xp_panel, "XPBar", GOLD)
    _pending_label = _label(_xp_panel, "PRÓXIMA EVOLUÇÃO", 11, MUTED, Vector2(17, 79), Vector2(265, 18))

    _forms_root = Control.new()
    _forms_root.name = "CombatForms"
    _forms_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(_forms_root)

    var form_titles: Array[String] = ["ESTOCADA", "MEIA-LUA", "GIRO 360"]
    var form_textures: Array[Texture2D] = [ICON_STAB, ICON_ARC, ICON_SPIN]
    for i in range(3):
        var slot: Panel = _panel(_forms_root, "Form_%d" % (i + 1), BG_SLOT, BORDER, 1)
        var icon_view := TextureRect.new()
        icon_view.name = "Icon"
        icon_view.texture = form_textures[i]
        icon_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
        slot.add_child(icon_view)
        var key_label: Label = _label(slot, "%d" % (i + 1), 12, MUTED, Vector2.ZERO, Vector2(20, 18), HORIZONTAL_ALIGNMENT_CENTER)
        var title_label: Label = _label(slot, form_titles[i], 11, TEXT, Vector2.ZERO, Vector2(115, 18), HORIZONTAL_ALIGNMENT_CENTER)
        _form_slots.append(slot)
        _form_icons.append(icon_view)
        _form_names.append(title_label)
        _form_keys.append(key_label)
    _select_form(0)

    _toast_panel = _panel(self, "GameEvent", BG_STRONG, GOLD, 1)
    _toast_label = _label(_toast_panel, "", 13, TEXT, Vector2(12, 7), Vector2(336, 24), HORIZONTAL_ALIGNMENT_CENTER)
    _toast_panel.visible = false


func _panel(parent_node: Node, node_id: String, background_color: Color, border_color: Color, border_width: int) -> Panel:
    var panel := Panel.new()
    panel.name = node_id
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_theme_stylebox_override("panel", _style(background_color, border_color, border_width, 13))
    parent_node.add_child(panel)
    return panel


func _style(background_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
    var box_style := StyleBoxFlat.new()
    box_style.bg_color = background_color
    box_style.border_color = border_color
    box_style.set_border_width_all(border_width)
    box_style.set_corner_radius_all(radius)
    box_style.shadow_color = Color(0, 0, 0, 0.18)
    box_style.shadow_size = 4
    return box_style


func _label(parent_node: Node, content: String, font_size: int, font_color: Color, at: Vector2, dims: Vector2, align_mode: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
    var node := Label.new()
    node.text = content
    node.position = at
    node.size = dims
    node.horizontal_alignment = align_mode
    node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    node.add_theme_font_size_override("font_size", font_size)
    node.add_theme_color_override("font_color", font_color)
    node.mouse_filter = Control.MOUSE_FILTER_IGNORE
    node.clip_text = true
    parent_node.add_child(node)
    return node


func _make_rect(parent_node: Node, node_id: String, at: Vector2, dims: Vector2, rect_color: Color) -> ColorRect:
    var rect := ColorRect.new()
    rect.name = node_id
    rect.color = rect_color
    rect.position = at
    rect.size = dims
    rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent_node.add_child(rect)
    return rect


func _bar(parent_node: Node, node_id: String, bar_color: Color) -> ProgressBar:
    var bar := ProgressBar.new()
    bar.name = node_id
    bar.show_percentage = false
    bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bar.min_value = 0.0
    bar.max_value = 100.0
    bar.value = 100.0 if node_id == "HealthBar" else 0.0
    bar.step = 0.01
    bar.add_theme_stylebox_override("background", _style(Color(0.018, 0.029, 0.035, 1), Color(0.15, 0.18, 0.20, 1), 1, 5))
    bar.add_theme_stylebox_override("fill", _style(bar_color, bar_color.darkened(0.2), 0, 5))
    parent_node.add_child(bar)
    return bar


func _layout() -> void:
    var view_size: Vector2 = get_viewport_rect().size
    if view_size.x < 1.0 or view_size.y < 1.0:
        return
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    var vw: float = view_size.x
    var vh: float = view_size.y
    var compact: bool = vw < 940.0
    var narrow: bool = vw < 800.0
    var margin: float = 14.0 if compact else 24.0

    if compact:
        var top_width: float = minf(218.0, (vw - margin * 3.0) * 0.5)
        _header_panel.position = Vector2(margin, 12)
        _header_panel.size = Vector2(top_width, 67)
        _wave_panel.position = Vector2(vw - margin - top_width, 12)
        _wave_panel.size = Vector2(top_width, 67)
    else:
        _header_panel.position = Vector2(margin, margin)
        _header_panel.size = Vector2(270, 76)
        _wave_panel.position = Vector2(vw - margin - 232, margin)
        _wave_panel.size = Vector2(232, 76)

    _location_label.text = "ALTAR" if _header_panel.size.x < 205.0 else "ALTAR PROFANADO"
    _location_label.size.x = _header_panel.size.x - 36.0
    _location_subtitle.text = "DARK FANTASY" if _header_panel.size.x < 205.0 else "A TORRE  /  GUERREIRO"
    _location_subtitle.size.x = _header_panel.size.x - 36.0
    var right_group_x: float = minf(122.0, _wave_panel.size.x * 0.53)
    _wave_divider.position.x = right_group_x - 12.0
    _kills_header.position.x = right_group_x
    _kills_header.size.x = _wave_panel.size.x - right_group_x - 8.0
    _kills_value.position.x = right_group_x
    _kills_value.size.x = _wave_panel.size.x - right_group_x - 8.0

    if narrow:
        # Layout compacto para telas estreitas: barras numa linha superior
        # e formas abaixo, sem sobrepor nenhuma informacao.
        var panel_width: float = (vw - margin * 3.0) * 0.5
        _life_panel.position = Vector2(margin, vh - 195)
        _life_panel.size = Vector2(panel_width, 94)
        _xp_panel.position = Vector2(vw - margin - panel_width, vh - 195)
        _xp_panel.size = Vector2(panel_width, 94)
        _forms_root.position = Vector2((vw - 300) * 0.5, vh - 88)
        _forms_root.size = Vector2(300, 76)
    else:
        var panel_width: float = 232.0 if compact else 312.0
        var form_width: float = 282.0 if compact else 376.0
        _life_panel.position = Vector2(margin, vh - 126)
        _life_panel.size = Vector2(panel_width, 104)
        _xp_panel.position = Vector2(vw - margin - panel_width, vh - 126)
        _xp_panel.size = Vector2(panel_width, 104)
        _forms_root.position = Vector2((vw - form_width) * 0.5, vh - 105)
        _forms_root.size = Vector2(form_width, 84)

    var life_width: float = _life_panel.size.x
    var xp_width: float = _xp_panel.size.x
    _hp_value.position = Vector2(life_width - 161, 12)
    _hp_value.size = Vector2(145, 29)
    _xp_value.position = Vector2(xp_width - 149, 16)
    _xp_value.size = Vector2(133, 19)
    if vw < 480.0:
        _hp_caption.text = "HP"
        _hp_value.add_theme_font_size_override("font_size", 13)
        _hp_value.position = Vector2(life_width - 108, 13)
        _hp_value.size = Vector2(92, 26)
        _xp_value.position = Vector2(xp_width - 120, 36)
        _xp_value.size = Vector2(103, 17)
        _xp_value.add_theme_font_size_override("font_size", 10)
    else:
        _hp_caption.text = "VIDA"
        _hp_value.add_theme_font_size_override("font_size", 18)
        _xp_value.add_theme_font_size_override("font_size", 12)
    _hp_bar.position = Vector2(17, 52)
    _hp_bar.size = Vector2(life_width - 34, 13)
    _xp_bar.position = Vector2(17, 52)
    _xp_bar.size = Vector2(xp_width - 34, 13)
    _hp_warning.position = Vector2(17, 76)
    _hp_warning.size = Vector2(life_width - 34, 20)
    _pending_label.position = Vector2(17, 76)
    _pending_label.size = Vector2(xp_width - 34, 20)

    var slot_gap: float = 7.0
    var slot_width: float = (_forms_root.size.x - slot_gap * 2.0) / 3.0
    for i in range(_form_slots.size()):
        var slot: Panel = _form_slots[i]
        slot.position = Vector2(float(i) * (slot_width + slot_gap), 0)
        slot.size = Vector2(slot_width, _forms_root.size.y)
        _form_icons[i].position = Vector2((slot_width - 31) * 0.5, 10)
        _form_icons[i].size = Vector2(31, 31)
        _form_keys[i].position = Vector2(slot_width - 26, 7)
        _form_names[i].position = Vector2(3, _forms_root.size.y - 28)
        _form_names[i].size = Vector2(slot_width - 6, 18)

    _refresh_pending_text()
    _toast_panel.size = Vector2(minf(360.0, vw - 32.0), 40)
    _toast_panel.position = Vector2((vw - _toast_panel.size.x) * 0.5, 90.0 if compact else 24.0)
    _toast_label.size = Vector2(_toast_panel.size.x - 24.0, 26)


func _on_health_changed(current: int, maximum: int) -> void:
    var limit: int = maxi(maximum, 1)
    _hp_value.text = "%d / %d" % [current, maximum]
    _hp_bar.max_value = float(limit)
    if _hp_tween != null and _hp_tween.is_running():
        _hp_tween.kill()
    _hp_tween = create_tween()
    _hp_tween.tween_property(_hp_bar, "value", float(current), 0.22).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    var ratio: float = float(current) / float(limit)
    _hp_warning.text = "PERIGO  •  VIDA CRÍTICA" if ratio <= 0.25 else "GUERREIRO  •  EM COMBATE"
    _hp_warning.add_theme_color_override("font_color", RED if ratio <= 0.25 else MUTED)


func _on_progress_changed(level: int, current_xp: int, xp_required: int) -> void:
    _level_label.text = "NÍVEL %02d" % level
    _xp_value.text = "%d / %d XP" % [current_xp, xp_required]
    _xp_bar.max_value = maxf(float(xp_required), 1.0)
    if _xp_tween != null and _xp_tween.is_running():
        _xp_tween.kill()
    _xp_tween = create_tween()
    _xp_tween.tween_property(_xp_bar, "value", float(current_xp), 0.24).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _on_choices_changed(pending: int) -> void:
    _pending_count = pending
    _refresh_pending_text()


func _refresh_pending_text() -> void:
    if _pending_label == null:
        return
    if _pending_count > 0:
        if get_viewport_rect().size.x < 900.0:
            _pending_label.text = "%d ESCOLHA(S) PENDENTE(S)" % _pending_count
        else:
            _pending_label.text = "%d EVOLUÇÃO(ÕES) AGUARDANDO ESCOLHA" % _pending_count
        _pending_label.add_theme_color_override("font_color", GOLD)
    elif _service != null and not _service.state.upgrade_history.is_empty():
        _pending_label.text = "MELHORIAS ATIVAS NA PARTIDA: %d" % _service.state.upgrade_history.size()
        _pending_label.add_theme_color_override("font_color", MINT)
    else:
        _pending_label.text = "PRÓXIMA EVOLUÇÃO"
        _pending_label.add_theme_color_override("font_color", MUTED)


func _on_level_gained(level: int) -> void:
    _show_toast("NÍVEL %d ALCANÇADO  •  ESCOLHA UMA EVOLUÇÃO" % level, 2.7, 2)


func _on_form_changed(form_name: String) -> void:
    var lower_form: String = form_name.to_lower()
    if lower_form.contains("giro"):
        _select_form(2)
    elif lower_form.contains("lua") or lower_form.contains("arco"):
        _select_form(1)
    elif lower_form.contains("perfura"):
        if not _form_names.is_empty():
            _form_names[0].text = "PERFURAÇÃO"
        _select_form(0)
    else:
        if not _form_names.is_empty():
            _form_names[0].text = "ESTOCADA"
        _select_form(0)


func _select_form(index: int) -> void:
    _current_form = index
    for i in range(_form_slots.size()):
        var active: bool = i == index
        var fill: Color = Color(0.10, 0.16, 0.16, 0.97) if active else BG_SLOT
        var edge: Color = MINT if active else BORDER
        _form_slots[i].add_theme_stylebox_override("panel", _style(fill, edge, 2 if active else 1, 10))
        _form_icons[i].modulate = TEXT if active else MUTED
        _form_names[i].add_theme_color_override("font_color", TEXT if active else MUTED)
        _form_keys[i].add_theme_color_override("font_color", MINT if active else MUTED)


func _on_player_died() -> void:
    _dead = true
    _show_toast("VOCÊ MORREU  •  PRESSIONE R PARA RECOMEÇAR", 0.0, 5)
    _hp_warning.text = "DERROTADO"
    _hp_warning.add_theme_color_override("font_color", RED)


func _show_toast(message: String, seconds: float, priority: int = 1) -> void:
    if _toast_panel.visible and _toast_priority > priority and _toast_timer > 0.0:
        return
    _toast_priority = priority
    _toast_label.text = message
    _toast_panel.modulate.a = 1.0
    _toast_panel.visible = true
    _toast_timer = seconds


func _update_wave_kills() -> void:
    if _arena == null:
        return
    var wave: int = int(_arena.get("current_wave"))
    var kills: int = int(_arena.get("kills"))
    if wave != _last_wave:
        _last_wave = wave
        _wave_value.text = "%02d" % maxi(wave, 0)
    if kills != _last_kills:
        _last_kills = kills
        _kills_value.text = "%d" % kills


func _process(delta: float) -> void:
    _refresh_timer -= delta
    if _refresh_timer <= 0.0:
        _refresh_timer = 0.14
        _update_wave_kills()
        # Preserva mensagens de wave/estado de main.gd sem altera-lo.
        if _status_source != null and not _dead:
            var status_text: String = _status_source.text
            if status_text != _last_status:
                _last_status = status_text
                if status_text.begins_with("Wave ") or status_text.begins_with("Wave concluida"):
                    _show_toast(status_text, 2.4)

    if not _dead and _toast_panel.visible and _toast_timer > 0.0:
        _toast_timer -= delta
        if _toast_timer <= 0.0:
            _toast_panel.visible = false
            _toast_priority = 0
        elif _toast_timer < 0.45:
            _toast_panel.modulate.a = clampf(_toast_timer / 0.45, 0.0, 1.0)
