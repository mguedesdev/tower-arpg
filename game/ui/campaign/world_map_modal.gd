extends Control
class_name WorldMapModal
## Mapa de Tela Cheia do Ato 1 ("ATO 1 — AS TERRAS DE VELEN") & Sistema de Teleporte via Waypoint:
## • Ocupa 100% da tela (PRESET_FULL_RECT) e pausa o jogo (get_tree().paused = true) enquanto aberto.
## • Quando aberto em um Waypoint (can_teleport = true): clicar em qualquer um dos 8 locais teleporta o herói.
## • Quando aberto pela tecla [M] fora de um Waypoint (can_teleport = false): permite consultar o mapa, mas bloqueia o teleporte com aviso.
## • Fecha com [ESC], [M], botão [✕] no topo direito ou botão "FECHAR MAPA (ESC / M)" no rodapé.
## • Inclui animação viva leve (água ondulando, árvores com brisa, pássaros voando e partículas de luz).

signal closed()
signal waypoint_travel_requested(zone_id: String)

const BG_TEX_PATH: String = "res://assets/ui/world_map/act1_velen_map_bg.png"
const LIVING_SHADER_PATH: String = "res://assets/materials/world_map_living.gdshader"

const COLOR_GOLD_BRIGHT := Color(1.0, 0.88, 0.45, 1.0)
const COLOR_GOLD_TITLE := Color(0.96, 0.82, 0.44, 1.0)
const COLOR_BRONZE_BORDER := Color(0.72, 0.54, 0.24, 0.96)
const COLOR_DARK_BANNER := Color(0.06, 0.05, 0.07, 0.94)

## Configuração dos 8 Locais do Ato 1 (coordenadas normalizadas 0..1 fiéis à imagem de referência 1024x576)
const ACT1_LOCATIONS: Array[Dictionary] = [
	{
		"index": 1,
		"zone_id": "town",
		"title": "1. Vila de Velen",
		"level_text": "Nível 1 – 3",
		"marker_tex": "res://assets/ui/world_map/01_vila_de_velen.png",
		"badge_uv": Vector2(0.172, 0.760),
		"node_uv": Vector2(0.155, 0.832),
	},
	{
		"index": 2,
		"zone_id": "zone_1_road",
		"title": "2. Floresta de Arath",
		"level_text": "Nível 3 – 6",
		"marker_tex": "res://assets/ui/world_map/02_floresta_de_arath.png",
		"badge_uv": Vector2(0.312, 0.568),
		"node_uv": Vector2(0.309, 0.646),
	},
	{
		"index": 3,
		"zone_id": "zone_2_woods",
		"title": "3. Ruínas Antigas",
		"level_text": "Nível 6 – 9",
		"marker_tex": "res://assets/ui/world_map/03_ruinas_antigas.png",
		"badge_uv": Vector2(0.550, 0.680),
		"node_uv": Vector2(0.533, 0.745),
	},
	{
		"index": 4,
		"zone_id": "zone_4_mines",
		"title": "4. Minas de Karpon",
		"level_text": "Nível 9 – 12",
		"marker_tex": "res://assets/ui/world_map/04_minas_de_karpon.png",
		"badge_uv": Vector2(0.822, 0.660),
		"node_uv": Vector2(0.778, 0.728),
	},
	{
		"index": 5,
		"zone_id": "zone_3_crypt",
		"title": "5. Cripta do Carrasco",
		"level_text": "Nível 12 – 15",
		"marker_tex": "res://assets/ui/world_map/05_cripta_do_carrasco.png",
		"badge_uv": Vector2(0.884, 0.385),
		"node_uv": Vector2(0.858, 0.533),
	},
	{
		"index": 6,
		"zone_id": "zone_6_hills",
		"title": "6. Colinas Sombrias",
		"level_text": "Nível 15 – 18",
		"marker_tex": "res://assets/ui/world_map/06_colinas_sombrias.png",
		"badge_uv": Vector2(0.554, 0.438),
		"node_uv": Vector2(0.559, 0.507),
	},
	{
		"index": 7,
		"zone_id": "zone_7_plateau",
		"title": "7. Planalto Esquecido",
		"level_text": "Nível 18 – 21",
		"marker_tex": "res://assets/ui/world_map/07_planalto_esquecido.png",
		"badge_uv": Vector2(0.660, 0.210),
		"node_uv": Vector2(0.625, 0.295),
	},
	{
		"index": 8,
		"zone_id": "zone_8_rift",
		"title": "8. Fenda Abissal",
		"level_text": "Nível 21 – 25",
		"marker_tex": "res://assets/ui/world_map/08_fenda_abissal.png",
		"badge_uv": Vector2(0.454, 0.165),
		"node_uv": Vector2(0.425, 0.228),
	},
]

## Pontos intermediários normalizados da estrada dourada entre os 8 locais (fiel à curva da imagem de referência)
const PATH_SEGMENTS_UV: Array[Array] = [
	# 1 (Vila) -> 2 (Floresta)
	[Vector2(0.155, 0.832), Vector2(0.225, 0.785), Vector2(0.278, 0.735), Vector2(0.285, 0.678), Vector2(0.309, 0.646)],
	# 2 (Floresta) -> 3 (Ruínas)
	[Vector2(0.309, 0.646), Vector2(0.365, 0.668), Vector2(0.415, 0.698), Vector2(0.455, 0.738), Vector2(0.500, 0.748), Vector2(0.533, 0.745)],
	# 3 (Ruínas) -> 4 (Minas)
	[Vector2(0.533, 0.745), Vector2(0.595, 0.768), Vector2(0.655, 0.778), Vector2(0.708, 0.732), Vector2(0.778, 0.728)],
	# 4 (Minas) -> 5 (Cripta)
	[Vector2(0.778, 0.728), Vector2(0.842, 0.695), Vector2(0.885, 0.628), Vector2(0.878, 0.572), Vector2(0.858, 0.533)],
	# 5 (Cripta) -> 6 (Colinas)
	[Vector2(0.420, 0.630), Vector2(0.435, 0.565), Vector2(0.432, 0.518), Vector2(0.495, 0.512), Vector2(0.559, 0.507)],
	# 6 (Colinas) -> 7 (Planalto)
	[Vector2(0.559, 0.507), Vector2(0.618, 0.492), Vector2(0.655, 0.438), Vector2(0.722, 0.382), Vector2(0.742, 0.348), Vector2(0.685, 0.312), Vector2(0.625, 0.295)],
	# 7 (Planalto) -> 8 (Fenda Abissal)
	[Vector2(0.548, 0.295), Vector2(0.502, 0.292), Vector2(0.462, 0.262), Vector2(0.425, 0.228)],
]

var can_teleport: bool = false
var current_zone_id: String = "town"
var unlocked_zones: Array[String] = []

var _bg_rect: TextureRect
var _bg_shader_mat: ShaderMaterial
var _canvas_overlay: Control
var _close_top_btn: Button
var _close_bottom_btn: Button
var _mode_banner_panel: PanelContainer
var _mode_banner_label: Label
var _feedback_panel: PanelContainer
var _feedback_label: Label
var _feedback_timer: float = 0.0

var _marker_textures: Dictionary = {}
var _hovered_index: int = -1
var _anim_time: float = 0.0
var _was_paused_before_open: bool = false

# Pássaros animados e partículas mágicas no mapa
var _birds: Array[Dictionary] = []
var _light_motes: Array[Dictionary] = []


func _ready() -> void:
	name = "WorldMapModal"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 140
	visible = false

	_load_assets()
	_init_ambient_life()
	_build_ui()


func _load_assets() -> void:
	for loc in ACT1_LOCATIONS:
		var path: String = String(loc["marker_tex"])
		if ResourceLoader.exists(path):
			_marker_textures[int(loc["index"])] = load(path) as Texture2D


func _init_ambient_life() -> void:
	_birds.clear()
	# Bandos de pássaros voando suavemente pelas montanhas, floresta e costa
	var bird_seeds := [
		{"uv": Vector2(0.18, 0.28), "speed": Vector2(0.022, -0.003), "wing_speed": 6.5, "scale": 1.0, "phase": 0.0},
		{"uv": Vector2(0.165, 0.295), "speed": Vector2(0.022, -0.003), "wing_speed": 6.8, "scale": 0.85, "phase": 1.2},
		{"uv": Vector2(0.192, 0.292), "speed": Vector2(0.022, -0.003), "wing_speed": 6.2, "scale": 0.78, "phase": 2.4},
		{"uv": Vector2(0.55, 0.14), "speed": Vector2(0.018, 0.002), "wing_speed": 5.8, "scale": 0.92, "phase": 0.7},
		{"uv": Vector2(0.535, 0.152), "speed": Vector2(0.018, 0.002), "wing_speed": 6.1, "scale": 0.80, "phase": 2.1},
		{"uv": Vector2(0.32, 0.48), "speed": Vector2(0.025, -0.004), "wing_speed": 7.2, "scale": 0.88, "phase": 3.5},
		{"uv": Vector2(0.305, 0.492), "speed": Vector2(0.025, -0.004), "wing_speed": 7.5, "scale": 0.75, "phase": 4.8},
	]
	for b in bird_seeds:
		_birds.append(b.duplicate())

	_light_motes.clear()
	# Vagalumes dourados na floresta/ruínas, fagulhas roxas nas Minas/Cripta e brasas rubras na Fenda Abissal
	var rng := RandomNumberGenerator.new()
	rng.seed = 4012026
	for i in range(42):
		var kind: int = i % 3 # 0 = dourado (floresta/vila), 1 = roxo (minas/cripta), 2 = rubro (fenda)
		var base_uv := Vector2(0.45, 0.65)
		var col := Color(1.0, 0.88, 0.42, 0.85)
		if kind == 0:
			base_uv = Vector2(rng.randf_range(0.14, 0.68), rng.randf_range(0.42, 0.84))
			col = Color(1.0, 0.90, 0.46, 0.80)
		elif kind == 1:
			base_uv = Vector2(rng.randf_range(0.74, 0.92), rng.randf_range(0.44, 0.78))
			col = Color(0.84, 0.42, 1.0, 0.85)
		else:
			base_uv = Vector2(rng.randf_range(0.34, 0.48), rng.randf_range(0.14, 0.28))
			col = Color(1.0, 0.32, 0.24, 0.88)
		_light_motes.append({
			"origin_uv": base_uv,
			"radius": rng.randf_range(2.2, 4.2),
			"speed": rng.randf_range(1.2, 2.6),
			"phase": rng.randf_range(0.0, TAU),
			"color": col,
		})


func _build_ui() -> void:
	# 1. Fundo escuro de segurança
	var bg_color_rect := ColorRect.new()
	bg_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_color_rect.color = Color(0.02, 0.015, 0.03, 1.0)
	bg_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg_color_rect)

	# 2. Imagem do Mapa do Ato 1 em Tela Cheia com Shader de Água/Vento/Luzes
	_bg_rect = TextureRect.new()
	_bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BG_TEX_PATH):
		_bg_rect.texture = load(BG_TEX_PATH) as Texture2D
	if ResourceLoader.exists(LIVING_SHADER_PATH):
		var sh := load(LIVING_SHADER_PATH) as Shader
		if sh != null:
			_bg_shader_mat = ShaderMaterial.new()
			_bg_shader_mat.shader = sh
			_bg_rect.material = _bg_shader_mat
	add_child(_bg_rect)

	# 3. Camada Interativa de Desenho (Estrada Dourada, Nodos ◆, 8 Marcações PNG, Pássaros, Luzes e Brasão)
	_canvas_overlay = Control.new()
	_canvas_overlay.name = "MapInteractiveCanvas"
	_canvas_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas_overlay.draw.connect(_on_canvas_draw)
	_canvas_overlay.gui_input.connect(_on_canvas_gui_input)
	add_child(_canvas_overlay)

	# 4. Banner de Status do Modo (Waypoint vs Tecla M) no Topo Central/Direito
	_mode_banner_panel = PanelContainer.new()
	_mode_banner_panel.anchor_left = 0.5
	_mode_banner_panel.anchor_right = 0.5
	_mode_banner_panel.anchor_top = 0.0
	_mode_banner_panel.anchor_bottom = 0.0
	_mode_banner_panel.offset_left = -250.0
	_mode_banner_panel.offset_right = 250.0
	_mode_banner_panel.offset_top = 16.0
	_mode_banner_panel.offset_bottom = 54.0
	_mode_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mb_style := StyleBoxFlat.new()
	mb_style.bg_color = Color(0.05, 0.045, 0.065, 0.92)
	mb_style.border_color = COLOR_BRONZE_BORDER
	mb_style.set_border_width_all(2)
	mb_style.set_corner_radius_all(6)
	mb_style.content_margin_left = 16
	mb_style.content_margin_right = 16
	mb_style.content_margin_top = 6
	mb_style.content_margin_bottom = 6
	_mode_banner_panel.add_theme_stylebox_override("panel", mb_style)
	add_child(_mode_banner_panel)

	_mode_banner_label = Label.new()
	_mode_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_banner_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_banner_label.add_theme_font_size_override("font_size", 14)
	_mode_banner_label.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	_mode_banner_panel.add_child(_mode_banner_label)

	# 5. Botão [✕] no Canto Superior Direito para Fechar
	_close_top_btn = Button.new()
	_close_top_btn.name = "CloseTopRightBtn"
	_close_top_btn.text = "✕"
	_close_top_btn.anchor_left = 1.0
	_close_top_btn.anchor_right = 1.0
	_close_top_btn.anchor_top = 0.0
	_close_top_btn.anchor_bottom = 0.0
	_close_top_btn.offset_left = -62.0
	_close_top_btn.offset_right = -18.0
	_close_top_btn.offset_top = 16.0
	_close_top_btn.offset_bottom = 60.0
	_close_top_btn.focus_mode = Control.FOCUS_NONE
	_close_top_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_top_btn.add_theme_font_size_override("font_size", 20)
	_close_top_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.90))
	var x_norm := StyleBoxFlat.new()
	x_norm.bg_color = Color(0.52, 0.12, 0.12, 0.96)
	x_norm.border_color = COLOR_BRONZE_BORDER
	x_norm.set_border_width_all(2)
	x_norm.set_corner_radius_all(6)
	x_norm.shadow_color = Color(0, 0, 0, 0.75)
	x_norm.shadow_size = 8
	var x_hov := x_norm.duplicate() as StyleBoxFlat
	x_hov.bg_color = Color(0.72, 0.18, 0.18, 0.99)
	x_hov.border_color = COLOR_GOLD_BRIGHT
	_close_top_btn.add_theme_stylebox_override("normal", x_norm)
	_close_top_btn.add_theme_stylebox_override("hover", x_hov)
	_close_top_btn.add_theme_stylebox_override("pressed", x_hov)
	_close_top_btn.pressed.connect(close_map)
	add_child(_close_top_btn)

	# 6. Botão "FECHAR MAPA (ESC / M)" no Rodapé Direito
	_close_bottom_btn = Button.new()
	_close_bottom_btn.name = "CloseBottomBtn"
	_close_bottom_btn.text = "FECHAR MAPA (ESC / M)"
	_close_bottom_btn.anchor_left = 1.0
	_close_bottom_btn.anchor_right = 1.0
	_close_bottom_btn.anchor_top = 1.0
	_close_bottom_btn.anchor_bottom = 1.0
	_close_bottom_btn.offset_left = -246.0
	_close_bottom_btn.offset_right = -20.0
	_close_bottom_btn.offset_top = -54.0
	_close_bottom_btn.offset_bottom = -16.0
	_close_bottom_btn.focus_mode = Control.FOCUS_NONE
	_close_bottom_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_bottom_btn.add_theme_font_size_override("font_size", 14)
	_close_bottom_btn.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	var b_norm := StyleBoxFlat.new()
	b_norm.bg_color = Color(0.07, 0.06, 0.09, 0.95)
	b_norm.border_color = COLOR_BRONZE_BORDER
	b_norm.set_border_width_all(2)
	b_norm.set_corner_radius_all(6)
	b_norm.shadow_color = Color(0, 0, 0, 0.8)
	b_norm.shadow_size = 8
	var b_hov := b_norm.duplicate() as StyleBoxFlat
	b_hov.bg_color = Color(0.14, 0.11, 0.16, 0.98)
	b_hov.border_color = COLOR_GOLD_BRIGHT
	_close_bottom_btn.add_theme_stylebox_override("normal", b_norm)
	_close_bottom_btn.add_theme_stylebox_override("hover", b_hov)
	_close_bottom_btn.add_theme_stylebox_override("pressed", b_hov)
	_close_bottom_btn.pressed.connect(close_map)
	add_child(_close_bottom_btn)

	# 7. Aviso flutuante no rodapé central quando tenta teleportar fora de um Waypoint
	_feedback_panel = PanelContainer.new()
	_feedback_panel.visible = false
	_feedback_panel.anchor_left = 0.5
	_feedback_panel.anchor_right = 0.5
	_feedback_panel.anchor_top = 1.0
	_feedback_panel.anchor_bottom = 1.0
	_feedback_panel.offset_left = -310.0
	_feedback_panel.offset_right = 310.0
	_feedback_panel.offset_top = -64.0
	_feedback_panel.offset_bottom = -20.0
	_feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fb_style := StyleBoxFlat.new()
	fb_style.bg_color = Color(0.18, 0.05, 0.06, 0.96)
	fb_style.border_color = Color(1.0, 0.42, 0.38, 0.98)
	fb_style.set_border_width_all(2)
	fb_style.set_corner_radius_all(6)
	fb_style.content_margin_left = 16
	fb_style.content_margin_right = 16
	fb_style.content_margin_top = 8
	fb_style.content_margin_bottom = 8
	_feedback_panel.add_theme_stylebox_override("panel", fb_style)
	add_child(_feedback_panel)

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 14)
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.86))
	_feedback_panel.add_child(_feedback_label)


func open_map(p_can_teleport: bool, p_current_zone: String, p_unlocked_zones: Array[String] = []) -> void:
	can_teleport = p_can_teleport
	current_zone_id = p_current_zone
	unlocked_zones = p_unlocked_zones.duplicate()
	_hovered_index = -1
	_feedback_timer = 0.0
	if _feedback_panel != null:
		_feedback_panel.visible = false

	_update_mode_banner()

	if not visible:
		_was_paused_before_open = get_tree().paused if get_tree() != null else false
		visible = true
		if get_tree() != null:
			get_tree().paused = true
	if _canvas_overlay != null:
		_canvas_overlay.queue_redraw()


func close_map() -> void:
	if not visible:
		return
	visible = false
	_hovered_index = -1
	if get_tree() != null:
		get_tree().paused = false
	closed.emit()


func _update_mode_banner() -> void:
	if _mode_banner_label == null or _mode_banner_panel == null:
		return
	var st := _mode_banner_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if can_teleport:
		_mode_banner_label.text = "✦ WAYPOINT ANCESTRAL — Clique em qualquer local do Ato 1 para se teleportar"
		_mode_banner_label.add_theme_color_override("font_color", Color(0.55, 0.96, 1.0))
		if st != null:
			st.border_color = Color(0.38, 0.84, 1.0, 0.96)
	else:
		_mode_banner_label.text = "🗺 MAPA DO ATO 1 [M] — Apenas consulta (use um Waypoint para se teleportar)"
		_mode_banner_label.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
		if st != null:
			st.border_color = COLOR_BRONZE_BORDER


func show_map_feedback(msg: String) -> void:
	if _feedback_label == null or _feedback_panel == null:
		return
	_feedback_label.text = msg
	_feedback_panel.visible = true
	_feedback_timer = 3.2


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M or event.keycode == KEY_E:
			close_map()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_M:
			close_map()
			get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	_anim_time += delta
	if _bg_shader_mat != null:
		_bg_shader_mat.set_shader_parameter("anim_time", _anim_time)

	for b in _birds:
		var uv: Vector2 = b["uv"] as Vector2
		var spd: Vector2 = b["speed"] as Vector2
		uv += spd * delta
		if uv.x > 1.06:
			uv.x = -0.06
		if uv.y < 0.05:
			uv.y = 0.55
		elif uv.y > 0.75:
			uv.y = 0.18
		b["uv"] = uv

	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0 and _feedback_panel != null:
			_feedback_panel.visible = false

	if _canvas_overlay != null:
		_canvas_overlay.queue_redraw()


func _get_marker_rect(loc: Dictionary, vp_size: Vector2) -> Rect2:
	var scale_f: float = clampf(minf(vp_size.x / 1280.0, vp_size.y / 720.0), 0.65, 1.45)
	var idx: int = int(loc["index"])
	var tex: Texture2D = _marker_textures.get(idx, null) as Texture2D
	var base_w: float = 216.0 * scale_f
	var base_h: float = 72.0 * scale_f
	if tex != null and tex.get_height() > 0:
		var aspect: float = float(tex.get_width()) / float(tex.get_height())
		base_h = 70.0 * scale_f
		base_w = base_h * aspect
	var center: Vector2 = (loc["badge_uv"] as Vector2) * vp_size
	return Rect2(center - Vector2(base_w * 0.5, base_h * 0.5), Vector2(base_w, base_h))


func _get_node_screen_pos(loc: Dictionary, vp_size: Vector2) -> Vector2:
	return (loc["node_uv"] as Vector2) * vp_size


func _find_location_at_point(pt: Vector2, vp_size: Vector2) -> int:
	# Verifica clique/hover na placa PNG ou no losango dourado do Waypoint (◆)
	for i in range(ACT1_LOCATIONS.size() - 1, -1, -1):
		var loc: Dictionary = ACT1_LOCATIONS[i]
		var rect: Rect2 = _get_marker_rect(loc, vp_size).grow(4.0)
		var node_pos: Vector2 = _get_node_screen_pos(loc, vp_size)
		if rect.has_point(pt) or pt.distance_to(node_pos) <= 22.0:
			return i
	return -1


func _on_canvas_gui_input(event: InputEvent) -> void:
	if not visible or _canvas_overlay == null:
		return
	var vp_size: Vector2 = _canvas_overlay.size
	if vp_size.x < 10.0:
		vp_size = get_viewport_rect().size

	if event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var new_hov: int = _find_location_at_point(mm.position, vp_size)
		if new_hov != _hovered_index:
			_hovered_index = new_hov
			_canvas_overlay.mouse_default_cursor_shape = (
				Control.CURSOR_POINTING_HAND if _hovered_index >= 0 else Control.CURSOR_ARROW
			)
			_canvas_overlay.queue_redraw()

	elif event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var clicked_idx: int = _find_location_at_point(mb.position, vp_size)
			if clicked_idx >= 0:
				_on_location_clicked(ACT1_LOCATIONS[clicked_idx])
				accept_event()


func _on_location_clicked(loc: Dictionary) -> void:
	var target_zone: String = String(loc["zone_id"])
	var title_str: String = String(loc["title"])

	if not can_teleport:
		show_map_feedback("⚠ Teleporte indisponível fora dos Waypoints! Aproxime-se de um Waypoint Ancestral para viajar.")
		return

	if target_zone == current_zone_id:
		show_map_feedback("✦ Você já está em %s!" % title_str)
		return

	close_map()
	waypoint_travel_requested.emit(target_zone)


# ============================================================================
# RENDERIZAÇÃO DO MAPA VIVO (ESTRADA DOURADA, PÁSSAROS, LUZES, 8 MARCAÇÕES E BRASÃO)
# ============================================================================
func _on_canvas_draw() -> void:
	var vp: Vector2 = _canvas_overlay.size
	if vp.x < 10.0:
		vp = Vector2(1280.0, 720.0)

	# 1. Partículas de Luz Flutuantes (Vagalumes, Cristais Roxos e Brasas da Fenda)
	_draw_ambient_light_motes(vp)

	# 2. Pássaros Voando pelas Montanhas e Floresta
	_draw_flying_birds(vp)

	# 3. Trilha Dourada Brilhante conectando os 8 Locais do Ato 1
	_draw_golden_waypoint_paths(vp)

	# 4. Nodos de Waypoint Dourados (Círculo + Losango ◆)
	_draw_waypoint_diamond_nodes(vp)

	# 5. As 8 Placas Oficiais em PNG Transparente (01_vila_de_velen .. 08_fenda_abissal)
	_draw_location_markers(vp)

	# 6. Brasão e Estandarte Superior Esquerdo: "ATO 1 — AS TERRAS DE VELEN"
	_draw_act1_top_left_banner()


func _draw_ambient_light_motes(vp: Vector2) -> void:
	for mote in _light_motes:
		var orig: Vector2 = mote["origin_uv"] as Vector2
		var spd: float = float(mote["speed"])
		var ph: float = float(mote["phase"])
		var rad: float = float(mote["radius"])
		var col: Color = mote["color"] as Color

		var offset := Vector2(
			sin(_anim_time * spd + ph) * 0.012,
			-fposmod(_anim_time * 0.014 * spd + ph * 0.1, 0.045)
		)
		var pos: Vector2 = (orig + offset) * vp
		var alpha_Wave: float = 0.35 + 0.65 * (0.5 + 0.5 * sin(_anim_time * spd * 2.2 + ph))
		var glow_col := Color(col.r, col.g, col.b, col.a * alpha_Wave * 0.32)
		var core_col := Color(1.0, 0.96, 0.86, col.a * alpha_Wave)
		_canvas_overlay.draw_circle(pos, rad * 2.4, glow_col)
		_canvas_overlay.draw_circle(pos, rad * 0.85, core_col)


func _draw_flying_birds(vp: Vector2) -> void:
	for b in _birds:
		var pos: Vector2 = (b["uv"] as Vector2) * vp
		var w_spd: float = float(b["wing_speed"])
		var sc: float = float(b["scale"])
		var ph: float = float(b["phase"])
		var flap: float = sin(_anim_time * w_spd + ph)
		var wing_y: float = flap * 4.5 * sc
		var span: float = 7.5 * sc

		var bird_col := Color(0.14, 0.10, 0.18, 0.78)
		var left_tip := pos + Vector2(-span, -wing_y)
		var mid_left := pos + Vector2(-span * 0.45, -wing_y * 0.55 - 1.5 * sc)
		var right_tip := pos + Vector2(span, -wing_y)
		var mid_right := pos + Vector2(span * 0.45, -wing_y * 0.55 - 1.5 * sc)

		_canvas_overlay.draw_line(left_tip, mid_left, bird_col, 1.8 * sc, true)
		_canvas_overlay.draw_line(mid_left, pos, bird_col, 2.0 * sc, true)
		_canvas_overlay.draw_line(pos, mid_right, bird_col, 2.0 * sc, true)
		_canvas_overlay.draw_line(mid_right, right_tip, bird_col, 1.8 * sc, true)


func _draw_golden_waypoint_paths(vp: Vector2) -> void:
	var pulse: float = 0.82 + 0.18 * sin(_anim_time * 3.0)
	var outer_glow := Color(1.0, 0.62, 0.12, 0.28 * pulse)
	var mid_glow := Color(1.0, 0.78, 0.22, 0.62 * pulse)
	var core_line := Color(1.0, 0.95, 0.68, 0.95)

	for seg in PATH_SEGMENTS_UV:
		var pts := PackedVector2Array()
		for i in range(seg.size() - 1):
			var p0: Vector2 = (seg[i] as Vector2) * vp
			var p1: Vector2 = (seg[i + 1] as Vector2) * vp
			var steps: int = 8
			for s in range(steps):
				var t: float = float(s) / float(steps)
				pts.append(p0.lerp(p1, t))
		pts.append((seg[seg.size() - 1] as Vector2) * vp)

		if pts.size() >= 2:
			_canvas_overlay.draw_polyline(pts, outer_glow, 11.0, true)
			_canvas_overlay.draw_polyline(pts, mid_glow, 5.5, true)
			_canvas_overlay.draw_polyline(pts, core_line, 2.5, true)

			# Partícula viajante de luz dourada percorrendo a estrada
			var travel_idx: float = fposmod(_anim_time * 6.5, float(pts.size() - 1))
			var i0: int = int(floorf(travel_idx))
			var i1: int = mini(i0 + 1, pts.size() - 1)
			var spark_pos: Vector2 = pts[i0].lerp(pts[i1], travel_idx - float(i0))
			_canvas_overlay.draw_circle(spark_pos, 6.5, Color(1.0, 0.85, 0.32, 0.45))
			_canvas_overlay.draw_circle(spark_pos, 3.0, Color(1.0, 0.98, 0.85, 0.95))


func _draw_waypoint_diamond_nodes(vp: Vector2) -> void:
	for i in range(ACT1_LOCATIONS.size()):
		var loc: Dictionary = ACT1_LOCATIONS[i]
		var z_id: String = String(loc["zone_id"])
		var is_current: bool = (z_id == current_zone_id)
		var is_hovered: bool = (i == _hovered_index)
		var pos: Vector2 = _get_node_screen_pos(loc, vp)

		var pulse: float = 1.0 + 0.14 * sin(_anim_time * 4.2 + float(i))
		var r: float = (13.5 if (is_hovered or is_current) else 11.0) * pulse

		# Halo externo
		var halo_col := Color(0.35, 0.88, 1.0, 0.48) if is_current else Color(1.0, 0.78, 0.24, 0.42 if is_hovered else 0.26)
		_canvas_overlay.draw_circle(pos, r * 1.65, halo_col)

		# Anel escuro e borda dourada
		_canvas_overlay.draw_circle(pos, r, Color(0.10, 0.07, 0.05, 0.96))
		var ring_col := Color(0.55, 0.95, 1.0, 1.0) if is_current else Color(1.0, 0.86, 0.38, 1.0)
		_canvas_overlay.draw_arc(pos, r, 0.0, TAU, 24, ring_col, 2.4, true)

		# Losango central (◆)
		var d_r: float = r * 0.52
		var diamond := PackedVector2Array([
			pos + Vector2(0.0, -d_r),
			pos + Vector2(d_r, 0.0),
			pos + Vector2(0.0, d_r),
			pos + Vector2(-d_r, 0.0),
		])
		var d_col := Color(0.68, 0.98, 1.0, 1.0) if is_current else Color(1.0, 0.92, 0.55, 1.0)
		_canvas_overlay.draw_colored_polygon(diamond, d_col)


func _draw_location_markers(vp: Vector2) -> void:
	var font: Font = ThemeDB.fallback_font
	for i in range(ACT1_LOCATIONS.size()):
		var loc: Dictionary = ACT1_LOCATIONS[i]
		var idx: int = int(loc["index"])
		var z_id: String = String(loc["zone_id"])
		var is_current: bool = (z_id == current_zone_id)
		var is_hovered: bool = (i == _hovered_index)

		var rect: Rect2 = _get_marker_rect(loc, vp)
		if is_hovered:
			var grow_px: float = 5.0 + 1.5 * sin(_anim_time * 6.0)
			rect = rect.grow(grow_px)
			rect.position.y -= 2.5

		# Brilho atrás da placa quando sob o mouse ou na zona atual
		if is_hovered or is_current:
			var glow_style := StyleBoxFlat.new()
			glow_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			glow_style.border_color = Color(0.45, 0.92, 1.0, 0.85) if is_current else Color(1.0, 0.86, 0.36, 0.90)
			glow_style.set_border_width_all(3)
			glow_style.set_corner_radius_all(8)
			glow_style.shadow_color = glow_style.border_color
			glow_style.shadow_size = 12 if is_hovered else 8
			_canvas_overlay.draw_style_box(glow_style, rect.grow(2.0))

		var tex: Texture2D = _marker_textures.get(idx, null) as Texture2D
		if tex != null:
			var modulate_col := Color(1.12, 1.10, 1.06, 1.0) if is_hovered else Color.WHITE
			_canvas_overlay.draw_texture_rect(tex, rect, false, modulate_col)
		else:
			# Fallback caso rode sem textura
			var fb_st := StyleBoxFlat.new()
			fb_st.bg_color = COLOR_DARK_BANNER
			fb_st.border_color = COLOR_BRONZE_BORDER
			fb_st.set_border_width_all(2)
			_canvas_overlay.draw_style_box(fb_st, rect)
			if font != null:
				_canvas_overlay.draw_string(font, rect.position + Vector2(16, 32), String(loc["title"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, COLOR_GOLD_BRIGHT)

		# Tag "✦ VOCÊ ESTÁ AQUI" ou "✦ CLIQUE PARA TELEPORTAR"
		if font != null and (is_current or (is_hovered and can_teleport)):
			var tag_txt: String = "✦ VOCÊ ESTÁ AQUI" if is_current else "⚡ CLIQUE PARA TELEPORTAR"
			var tag_col: Color = Color(0.48, 0.95, 1.0) if is_current else Color(0.52, 1.0, 0.64)
			var tag_w: float = 162.0
			var tag_h: float = 20.0
			var tag_rect := Rect2(
				Vector2(rect.get_center().x - tag_w * 0.5, rect.position.y - tag_h - 3.0),
				Vector2(tag_w, tag_h)
			)
			var tag_st := StyleBoxFlat.new()
			tag_st.bg_color = Color(0.04, 0.05, 0.08, 0.94)
			tag_st.border_color = tag_col
			tag_st.set_border_width_all(1)
			tag_st.set_corner_radius_all(4)
			_canvas_overlay.draw_style_box(tag_st, tag_rect)
			_canvas_overlay.draw_string(
				font,
				Vector2(tag_rect.position.x, tag_rect.position.y + 14.0),
				tag_txt,
				HORIZONTAL_ALIGNMENT_CENTER,
				tag_w,
				11,
				tag_col
			)


func _draw_act1_top_left_banner() -> void:
	var font: Font = ThemeDB.fallback_font
	# Placa horizontal escura com moldura dourada: "ATO 1 — AS TERRAS DE VELEN"
	var bar_rect := Rect2(Vector2(66.0, 14.0), Vector2(368.0, 44.0))
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.06, 0.045, 0.055, 0.96)
	bar_style.border_color = Color(0.82, 0.62, 0.26, 0.98)
	bar_style.set_border_width_all(2)
	bar_style.set_corner_radius_all(4)
	bar_style.shadow_color = Color(0, 0, 0, 0.78)
	bar_style.shadow_size = 10
	_canvas_overlay.draw_style_box(bar_style, bar_rect)

	# Ponta triangular dourada à direita da placa
	var tip_pts := PackedVector2Array([
		Vector2(bar_rect.end.x, bar_rect.position.y + 4.0),
		Vector2(bar_rect.end.x + 22.0, bar_rect.get_center().y),
		Vector2(bar_rect.end.x, bar_rect.end.y - 4.0),
	])
	_canvas_overlay.draw_colored_polygon(tip_pts, Color(0.78, 0.58, 0.24, 0.98))

	# Estandarte Carmesim e Ouro à esquerda (Brasão de Velen)
	var banner_pts := PackedVector2Array([
		Vector2(18.0, 6.0),
		Vector2(74.0, 6.0),
		Vector2(74.0, 64.0),
		Vector2(46.0, 86.0),
		Vector2(18.0, 64.0),
	])
	_canvas_overlay.draw_colored_polygon(banner_pts, Color(0.56, 0.09, 0.09, 0.98))
	var banner_border := PackedVector2Array([
		Vector2(18.0, 6.0),
		Vector2(74.0, 6.0),
		Vector2(74.0, 64.0),
		Vector2(46.0, 86.0),
		Vector2(18.0, 64.0),
		Vector2(18.0, 6.0),
	])
	_canvas_overlay.draw_polyline(banner_border, Color(0.92, 0.72, 0.30, 1.0), 2.5, true)

	# Emblema da Cruz Solar dentro do Estandarte Carmesim
	var crest_c := Vector2(46.0, 40.0)
	_canvas_overlay.draw_arc(crest_c, 13.0, 0.0, TAU, 24, Color(0.96, 0.78, 0.34, 1.0), 2.2, true)
	_canvas_overlay.draw_line(crest_c + Vector2(0.0, -19.0), crest_c + Vector2(0.0, 19.0), Color(0.98, 0.82, 0.38, 1.0), 2.2, true)
	_canvas_overlay.draw_line(crest_c + Vector2(-17.0, 0.0), crest_c + Vector2(17.0, 0.0), Color(0.98, 0.82, 0.38, 1.0), 2.2, true)

	if font != null:
		_canvas_overlay.draw_string(
			font,
			Vector2(bar_rect.position.x + 18.0, bar_rect.position.y + 29.0),
			"ATO 1 — AS TERRAS DE VELEN",
			HORIZONTAL_ALIGNMENT_CENTER,
			bar_rect.size.x - 24.0,
			18,
			Color(0.98, 0.84, 0.46, 1.0)
		)
