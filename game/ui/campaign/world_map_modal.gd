extends Control
class_name WorldMapModal
## ============================================================================
## MAPA DO ATO 1 — AS TERRAS DE VELEN & SISTEMA DE WAYPOINTS E VIAGEM RÁPIDA
## ============================================================================
## Arquitetura Visual em Camadas Compartilhando o Mesmo Sistema de Coordenadas:
## • WaypointMapOverlay / FullscreenRoot (Control tela cheia com fundo dimerizado)
##   • DimBackdrop (ColorRect, impede cliques atravessando para o 3D)
##   • MapAspect (AspectRatioContainer 16:9 / 1672x941 fit-center)
##     • MapCanvas (Control compartilhando resolução exata do mapa)
##       • MapBackground (TextureRect com arte original limpa)
##       • RouteOverlay (Control com estrada dourada luminosa e nós ◆)
##       • RegionCards (Control com os 8 cards interativos)
##         • WaypointCard01 .. WaypointCard08 (TextureButtons reais)
##   • MapStatus (Banner superior informando Modo Consulta [M] vs Waypoint)
##   • CloseButton (Botão [✕] no topo direito e botão no rodapé)
##   • FeedbackToast (Painel flutuante com mensagens contextuais)
##
## Dois Modos de Operação:
## • Modo A (Tecla M / Consulta): Permite inspecionar o mapa; NÃO teleporta.
## • Modo B (Waypoint Ancestral): Permite viajar para waypoints desbloqueados.

signal closed()
signal opened()
signal waypoint_travel_requested(zone_id: String)

const BG_TEX_PATH: String = "res://assets/ui/world_map/act1_velen_map_bg.png"
const MAP_ORIGINAL_SIZE := Vector2(1672.0, 941.0)
const MAP_ASPECT_RATIO: float = 1672.0 / 941.0

const COLOR_GOLD_BRIGHT := Color(1.0, 0.88, 0.45, 1.0)
const COLOR_GOLD_TITLE := Color(0.96, 0.84, 0.48, 1.0)
const COLOR_BRONZE_BORDER := Color(0.72, 0.54, 0.24, 0.96)
const COLOR_CURRENT_LOCATION := Color(0.35, 0.95, 0.55, 1.0)

## Configuração dos 8 Locais do Ato 1 (calibrados com precisão subpixel na imagem de referência)
const ACT1_LOCATIONS: Array[Dictionary] = [
	{
		"index": 1,
		"zone_id": "town",
		"title": "1. Vila de Velen",
		"level_text": "Nível 1 – 3",
		"tex_path": "res://assets/ui/world_map/01_vila_de_velen.png",
		"marker_tex": "res://assets/ui/world_map/01_vila_de_velen.png",
		"center_uv": Vector2(0.1732, 0.7657),
		"badge_uv": Vector2(0.1732, 0.7657),
		"size_uv": Vector2(0.1801, 0.1073),
		"node_uv": Vector2(0.153, 0.837),
	},
	{
		"index": 2,
		"zone_id": "zone_1_road",
		"title": "2. Floresta de Arath",
		"level_text": "Nível 3 – 6",
		"tex_path": "res://assets/ui/world_map/02_floresta_de_arath.png",
		"marker_tex": "res://assets/ui/world_map/02_floresta_de_arath.png",
		"center_uv": Vector2(0.3079, 0.5770),
		"badge_uv": Vector2(0.3079, 0.5770),
		"size_uv": Vector2(0.1849, 0.1063),
		"node_uv": Vector2(0.309, 0.653),
	},
	{
		"index": 3,
		"zone_id": "zone_2_woods",
		"title": "3. Ruínas Antigas",
		"level_text": "Nível 6 – 9",
		"tex_path": "res://assets/ui/world_map/03_ruinas_antigas.png",
		"marker_tex": "res://assets/ui/world_map/03_ruinas_antigas.png",
		"center_uv": Vector2(0.5548, 0.6865),
		"badge_uv": Vector2(0.5548, 0.6865),
		"size_uv": Vector2(0.1903, 0.1063),
		"node_uv": Vector2(0.533, 0.750),
	},
	{
		"index": 4,
		"zone_id": "zone_4_mines",
		"title": "4. Minas de Karpon",
		"level_text": "Nível 9 – 12",
		"tex_path": "res://assets/ui/world_map/04_minas_de_karpon.png",
		"marker_tex": "res://assets/ui/world_map/04_minas_de_karpon.png",
		"center_uv": Vector2(0.8196, 0.6658),
		"badge_uv": Vector2(0.8196, 0.6658),
		"size_uv": Vector2(0.1885, 0.1073),
		"node_uv": Vector2(0.775, 0.729),
	},
	{
		"index": 5,
		"zone_id": "zone_3_crypt",
		"title": "5. Cripta do Carrasco",
		"level_text": "Nível 12 – 15",
		"tex_path": "res://assets/ui/world_map/05_cripta_do_carrasco.png",
		"marker_tex": "res://assets/ui/world_map/05_cripta_do_carrasco.png",
		"center_uv": Vector2(0.8848, 0.3900),
		"badge_uv": Vector2(0.8848, 0.3900),
		"size_uv": Vector2(0.1825, 0.1041),
		"node_uv": Vector2(0.859, 0.538),
	},
	{
		"index": 6,
		"zone_id": "zone_6_hills",
		"title": "6. Colinas Sombrias",
		"level_text": "Nível 15 – 18",
		"tex_path": "res://assets/ui/world_map/06_colinas_sombrias.png",
		"marker_tex": "res://assets/ui/world_map/06_colinas_sombrias.png",
		"center_uv": Vector2(0.5527, 0.4394),
		"badge_uv": Vector2(0.5527, 0.4394),
		"size_uv": Vector2(0.1741, 0.0946),
		"node_uv": Vector2(0.560, 0.510),
	},
	{
		"index": 7,
		"zone_id": "zone_7_plateau",
		"title": "7. Planalto Esquecido",
		"level_text": "Nível 18 – 21",
		"tex_path": "res://assets/ui/world_map/07_planalto_esquecido.png",
		"marker_tex": "res://assets/ui/world_map/07_planalto_esquecido.png",
		"center_uv": Vector2(0.6586, 0.2163),
		"badge_uv": Vector2(0.6586, 0.2163),
		"size_uv": Vector2(0.1753, 0.0988),
		"node_uv": Vector2(0.624, 0.295),
	},
	{
		"index": 8,
		"zone_id": "zone_8_rift",
		"title": "8. Fenda Abissal",
		"level_text": "Nível 21 – 25",
		"tex_path": "res://assets/ui/world_map/08_fenda_abissal.png",
		"marker_tex": "res://assets/ui/world_map/08_fenda_abissal.png",
		"center_uv": Vector2(0.4476, 0.1690),
		"badge_uv": Vector2(0.4476, 0.1690),
		"size_uv": Vector2(0.1855, 0.1084),
		"node_uv": Vector2(0.426, 0.233),
	},
]

## Segmentos da estrada dourada conectando os waypoints
const PATH_SEGMENTS_UV: Array[Array] = [
	[Vector2(0.153, 0.837), Vector2(0.225, 0.785), Vector2(0.278, 0.735), Vector2(0.285, 0.678), Vector2(0.309, 0.653)],
	[Vector2(0.309, 0.653), Vector2(0.365, 0.668), Vector2(0.415, 0.698), Vector2(0.455, 0.738), Vector2(0.500, 0.748), Vector2(0.533, 0.750)],
	[Vector2(0.533, 0.750), Vector2(0.595, 0.768), Vector2(0.655, 0.778), Vector2(0.708, 0.732), Vector2(0.775, 0.729)],
	[Vector2(0.775, 0.729), Vector2(0.842, 0.695), Vector2(0.885, 0.628), Vector2(0.878, 0.572), Vector2(0.859, 0.538)],
	[Vector2(0.425, 0.635), Vector2(0.435, 0.565), Vector2(0.432, 0.518), Vector2(0.495, 0.512), Vector2(0.560, 0.510)],
	[Vector2(0.560, 0.510), Vector2(0.618, 0.492), Vector2(0.655, 0.438), Vector2(0.722, 0.382), Vector2(0.742, 0.348), Vector2(0.685, 0.312), Vector2(0.624, 0.295)],
	[Vector2(0.624, 0.295), Vector2(0.548, 0.295), Vector2(0.502, 0.292), Vector2(0.462, 0.262), Vector2(0.426, 0.233)],
]

var can_teleport: bool = false
var current_zone_id: String = "town"
var unlocked_zones: Array[String] = []

# Referências da Hierarquia de UI
var _dim_backdrop: ColorRect
var _map_aspect: AspectRatioContainer
var _map_canvas: Control
var _map_background: TextureRect
var _route_overlay: Control
var _region_cards_root: Control

var _card_roots: Array[Control] = []
var _card_buttons: Array[TextureButton] = []
var _card_lock_badges: Array[PanelContainer] = []
var _card_current_badges: Array[PanelContainer] = []

var _mode_banner_panel: PanelContainer
var _mode_banner_title: Label
var _mode_banner_sub: Label
var _close_top_btn: Button
var _close_bottom_btn: Button
var _feedback_panel: PanelContainer
var _feedback_label: Label

var _feedback_timer: float = 0.0
var _anim_time: float = 0.0
var _was_paused_before_open: bool = false
var _hidden_hud_elements: Array[CanvasItem] = []


func _ready() -> void:
	name = "WorldMapModal"
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 120
	visible = false

	_build_ui_hierarchy()


func _build_ui_hierarchy() -> void:
	# 1. DimBackdrop — escurece o jogo e impede cliques no mundo 3D
	_dim_backdrop = ColorRect.new()
	_dim_backdrop.name = "DimBackdrop"
	_dim_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim_backdrop.color = Color(0.015, 0.012, 0.025, 0.94)
	_dim_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim_backdrop)

	# 2. MapAspect — AspectRatioContainer que preserva a proporção 16:9
	_map_aspect = AspectRatioContainer.new()
	_map_aspect.name = "MapAspect"
	_map_aspect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_aspect.ratio = MAP_ASPECT_RATIO
	_map_aspect.alignment_horizontal = AspectRatioContainer.ALIGNMENT_CENTER
	_map_aspect.alignment_vertical = AspectRatioContainer.ALIGNMENT_CENTER
	_map_aspect.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_map_aspect)

	# 3. MapCanvas — Contêiner de coordenadas unificadas para fundo, caminhos e cards
	_map_canvas = Control.new()
	_map_canvas.name = "MapCanvas"
	_map_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_map_canvas.resized.connect(_on_map_canvas_resized)
	_map_aspect.add_child(_map_canvas)

	# 4. MapBackground — Imagem do mapa sem os cards
	_map_background = TextureRect.new()
	_map_background.name = "MapBackground"
	_map_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_background.stretch_mode = TextureRect.STRETCH_SCALE
	_map_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(BG_TEX_PATH):
		_map_background.texture = load(BG_TEX_PATH) as Texture2D
	_map_canvas.add_child(_map_background)

	# 5. RouteOverlay — Estradas douradas luminosas e nós ◆ (puramente decorativo)
	_route_overlay = Control.new()
	_route_overlay.name = "RouteOverlay"
	_route_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_route_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_route_overlay.draw.connect(_on_route_overlay_draw)
	_map_canvas.add_child(_route_overlay)

	# 6. RegionCards — Raiz dos 8 cards interativos
	_region_cards_root = Control.new()
	_region_cards_root.name = "RegionCards"
	_region_cards_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_region_cards_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_canvas.add_child(_region_cards_root)

	_build_region_cards()

	# 7. MapStatus — Banner do topo informando o modo ativo
	_build_status_banner()

	# 8. Botões de Fechar
	_build_close_buttons()

	# 9. FeedbackToast — Mensagens flutuantes
	_build_feedback_toast()


func _build_region_cards() -> void:
	_card_roots.clear()
	_card_buttons.clear()
	_card_lock_badges.clear()
	_card_current_badges.clear()

	for loc_idx in range(ACT1_LOCATIONS.size()):
		var loc: Dictionary = ACT1_LOCATIONS[loc_idx]
		var card_root := Control.new()
		card_root.name = "WaypointCard%02d" % int(loc["index"])
		card_root.mouse_filter = Control.MOUSE_FILTER_PASS

		# Botão real com a textura oficial do card
		var btn := TextureButton.new()
		btn.name = "CardButton"
		btn.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.ignore_texture_size = true
		btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		btn.mouse_filter = Control.MOUSE_FILTER_STOP
		btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		btn.focus_mode = Control.FOCUS_ALL

		var tex_path: String = String(loc["tex_path"])
		if ResourceLoader.exists(tex_path):
			btn.texture_normal = load(tex_path) as Texture2D

		# Conexões de eventos reais do botão
		var idx_capture: int = loc_idx
		btn.mouse_entered.connect(func(): _on_card_mouse_entered(idx_capture))
		btn.mouse_exited.connect(func(): _on_card_mouse_exited(idx_capture))
		btn.pressed.connect(func(): _on_card_pressed(idx_capture))
		btn.focus_entered.connect(func(): _on_card_mouse_entered(idx_capture))
		btn.focus_exited.connect(func(): _on_card_mouse_exited(idx_capture))
		card_root.add_child(btn)

		# Badge de Bloqueio (Cadeado sobreposto sem alterar o PNG original)
		var lock_panel := PanelContainer.new()
		lock_panel.name = "LockBadge"
		lock_panel.anchor_left = 1.0
		lock_panel.anchor_right = 1.0
		lock_panel.anchor_top = 0.0
		lock_panel.anchor_bottom = 0.0
		lock_panel.offset_left = -38.0
		lock_panel.offset_right = -8.0
		lock_panel.offset_top = 8.0
		lock_panel.offset_bottom = 38.0
		lock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lock_st := StyleBoxFlat.new()
		lock_st.bg_color = Color(0.08, 0.06, 0.09, 0.92)
		lock_st.border_color = Color(0.72, 0.45, 0.22, 0.95)
		lock_st.set_border_width_all(2)
		lock_st.set_corner_radius_all(15)
		lock_panel.add_theme_stylebox_override("panel", lock_st)

		var lock_lbl := Label.new()
		lock_lbl.text = "🔒"
		lock_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lock_lbl.add_theme_font_size_override("font_size", 14)
		lock_panel.add_child(lock_lbl)
		card_root.add_child(lock_panel)

		# Badge de Local Atual (Estandarte luminoso)
		var cur_panel := PanelContainer.new()
		cur_panel.name = "CurrentBadge"
		cur_panel.anchor_left = 0.5
		cur_panel.anchor_right = 0.5
		cur_panel.anchor_top = 0.0
		cur_panel.anchor_bottom = 0.0
		cur_panel.offset_left = -64.0
		cur_panel.offset_right = 64.0
		cur_panel.offset_top = -14.0
		cur_panel.offset_bottom = 12.0
		cur_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var cur_st := StyleBoxFlat.new()
		cur_st.bg_color = Color(0.10, 0.08, 0.04, 0.95)
		cur_st.border_color = COLOR_GOLD_BRIGHT
		cur_st.set_border_width_all(2)
		cur_st.set_corner_radius_all(4)
		cur_st.content_margin_left = 8
		cur_st.content_margin_right = 8
		cur_panel.add_theme_stylebox_override("panel", cur_st)

		var cur_lbl := Label.new()
		cur_lbl.text = "★ LOCAL ATUAL"
		cur_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cur_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cur_lbl.add_theme_font_size_override("font_size", 11)
		cur_lbl.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
		cur_panel.add_child(cur_lbl)
		card_root.add_child(cur_panel)

		_region_cards_root.add_child(card_root)
		_card_roots.append(card_root)
		_card_buttons.append(btn)
		_card_lock_badges.append(lock_panel)
		_card_current_badges.append(cur_panel)


func _build_status_banner() -> void:
	_mode_banner_panel = PanelContainer.new()
	_mode_banner_panel.name = "MapStatus"
	_mode_banner_panel.anchor_left = 0.5
	_mode_banner_panel.anchor_right = 0.5
	_mode_banner_panel.anchor_top = 0.0
	_mode_banner_panel.anchor_bottom = 0.0
	_mode_banner_panel.offset_left = -320.0
	_mode_banner_panel.offset_right = 320.0
	_mode_banner_panel.offset_top = 14.0
	_mode_banner_panel.offset_bottom = 64.0
	_mode_banner_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var mb_style := StyleBoxFlat.new()
	mb_style.bg_color = Color(0.06, 0.05, 0.08, 0.94)
	mb_style.border_color = COLOR_BRONZE_BORDER
	mb_style.set_border_width_all(2)
	mb_style.set_corner_radius_all(6)
	mb_style.content_margin_left = 18
	mb_style.content_margin_right = 18
	mb_style.content_margin_top = 5
	mb_style.content_margin_bottom = 5
	mb_style.shadow_color = Color(0, 0, 0, 0.8)
	mb_style.shadow_size = 10
	_mode_banner_panel.add_theme_stylebox_override("panel", mb_style)
	add_child(_mode_banner_panel)

	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 2)
	_mode_banner_panel.add_child(vb)

	_mode_banner_title = Label.new()
	_mode_banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_banner_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_banner_title.add_theme_font_size_override("font_size", 15)
	_mode_banner_title.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
	vb.add_child(_mode_banner_title)

	_mode_banner_sub = Label.new()
	_mode_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mode_banner_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mode_banner_sub.add_theme_font_size_override("font_size", 12)
	_mode_banner_sub.add_theme_color_override("font_color", Color(0.85, 0.82, 0.88, 0.85))
	vb.add_child(_mode_banner_sub)


func _build_close_buttons() -> void:
	# Botão [✕] superior direito
	_close_top_btn = Button.new()
	_close_top_btn.name = "CloseTopBtn"
	_close_top_btn.text = "✕"
	_close_top_btn.anchor_left = 1.0
	_close_top_btn.anchor_right = 1.0
	_close_top_btn.anchor_top = 0.0
	_close_top_btn.anchor_bottom = 0.0
	_close_top_btn.offset_left = -58.0
	_close_top_btn.offset_right = -18.0
	_close_top_btn.offset_top = 16.0
	_close_top_btn.offset_bottom = 56.0
	_close_top_btn.focus_mode = Control.FOCUS_NONE
	_close_top_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_top_btn.add_theme_font_size_override("font_size", 20)
	_close_top_btn.add_theme_color_override("font_color", Color(1.0, 0.95, 0.90))

	var x_norm := StyleBoxFlat.new()
	x_norm.bg_color = Color(0.48, 0.12, 0.12, 0.94)
	x_norm.border_color = COLOR_BRONZE_BORDER
	x_norm.set_border_width_all(2)
	x_norm.set_corner_radius_all(6)
	x_norm.shadow_color = Color(0, 0, 0, 0.75)
	x_norm.shadow_size = 6

	var x_hov := x_norm.duplicate() as StyleBoxFlat
	x_hov.bg_color = Color(0.72, 0.18, 0.18, 0.99)
	x_hov.border_color = COLOR_GOLD_BRIGHT

	_close_top_btn.add_theme_stylebox_override("normal", x_norm)
	_close_top_btn.add_theme_stylebox_override("hover", x_hov)
	_close_top_btn.add_theme_stylebox_override("pressed", x_hov)
	_close_top_btn.pressed.connect(close_map)
	add_child(_close_top_btn)

	# Botão inferior "FECHAR MAPA (ESC / M)"
	_close_bottom_btn = Button.new()
	_close_bottom_btn.name = "CloseBottomBtn"
	_close_bottom_btn.text = "FECHAR MAPA (ESC / M)"
	_close_bottom_btn.anchor_left = 1.0
	_close_bottom_btn.anchor_right = 1.0
	_close_bottom_btn.anchor_top = 1.0
	_close_bottom_btn.anchor_bottom = 1.0
	_close_bottom_btn.offset_left = -220.0
	_close_bottom_btn.offset_right = -20.0
	_close_bottom_btn.offset_top = -52.0
	_close_bottom_btn.offset_bottom = -16.0
	_close_bottom_btn.focus_mode = Control.FOCUS_NONE
	_close_bottom_btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_close_bottom_btn.add_theme_font_size_override("font_size", 13)
	_close_bottom_btn.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)

	var b_norm := StyleBoxFlat.new()
	b_norm.bg_color = Color(0.08, 0.07, 0.10, 0.92)
	b_norm.border_color = COLOR_BRONZE_BORDER
	b_norm.set_border_width_all(2)
	b_norm.set_corner_radius_all(6)
	b_norm.content_margin_left = 12
	b_norm.content_margin_right = 12

	var b_hov := b_norm.duplicate() as StyleBoxFlat
	b_hov.bg_color = Color(0.18, 0.15, 0.22, 0.96)
	b_hov.border_color = COLOR_GOLD_BRIGHT

	_close_bottom_btn.add_theme_stylebox_override("normal", b_norm)
	_close_bottom_btn.add_theme_stylebox_override("hover", b_hov)
	_close_bottom_btn.add_theme_stylebox_override("pressed", b_hov)
	_close_bottom_btn.pressed.connect(close_map)
	add_child(_close_bottom_btn)


func _build_feedback_toast() -> void:
	_feedback_panel = PanelContainer.new()
	_feedback_panel.name = "FeedbackToast"
	_feedback_panel.anchor_left = 0.5
	_feedback_panel.anchor_right = 0.5
	_feedback_panel.anchor_top = 1.0
	_feedback_panel.anchor_bottom = 1.0
	_feedback_panel.offset_left = -340.0
	_feedback_panel.offset_right = 340.0
	_feedback_panel.offset_top = -68.0
	_feedback_panel.offset_bottom = -22.0
	_feedback_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feedback_panel.visible = false

	var fb_style := StyleBoxFlat.new()
	fb_style.bg_color = Color(0.10, 0.05, 0.07, 0.96)
	fb_style.border_color = Color(0.95, 0.35, 0.25, 0.95)
	fb_style.set_border_width_all(2)
	fb_style.set_corner_radius_all(6)
	fb_style.content_margin_left = 16
	fb_style.content_margin_right = 16
	_feedback_panel.add_theme_stylebox_override("panel", fb_style)
	add_child(_feedback_panel)

	_feedback_label = Label.new()
	_feedback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_feedback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_feedback_label.add_theme_font_size_override("font_size", 14)
	_feedback_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.88))
	_feedback_panel.add_child(_feedback_label)


# ============================================================================
# GERENCIAMENTO E SINCRONIZAÇÃO ESPACIAL DOS CARDS
# ============================================================================
func _on_map_canvas_resized() -> void:
	_layout_region_cards()
	if _route_overlay != null:
		_route_overlay.queue_redraw()


func _layout_region_cards() -> void:
	if _map_canvas == null or _region_cards_root == null:
		return
	var canvas_sz: Vector2 = _map_canvas.size
	if canvas_sz.x < 10.0 or canvas_sz.y < 10.0:
		if _map_aspect != null and _map_aspect.size.x >= 10.0:
			var asp_w: float = _map_aspect.size.x
			var asp_h: float = _map_aspect.size.y
			if asp_w / asp_h > MAP_ASPECT_RATIO:
				canvas_sz = Vector2(asp_h * MAP_ASPECT_RATIO, asp_h)
			else:
				canvas_sz = Vector2(asp_w, asp_w / MAP_ASPECT_RATIO)
		elif size.x >= 10.0:
			canvas_sz = size
		else:
			canvas_sz = Vector2(1280.0, 720.0)

	for i in range(ACT1_LOCATIONS.size()):
		if i >= _card_roots.size():
			continue
		var loc: Dictionary = ACT1_LOCATIONS[i]
		var card_root: Control = _card_roots[i]
		var center_uv: Vector2 = loc["center_uv"] as Vector2
		var size_uv: Vector2 = loc["size_uv"] as Vector2

		var card_size: Vector2 = canvas_sz * size_uv
		var card_pos: Vector2 = canvas_sz * center_uv - card_size * 0.5

		card_root.size = card_size
		card_root.position = card_pos
		card_root.pivot_offset = card_size * 0.5


func _refresh_cards_visual_states() -> void:
	for i in range(ACT1_LOCATIONS.size()):
		if i >= _card_roots.size():
			continue
		var loc: Dictionary = ACT1_LOCATIONS[i]
		var zid: String = String(loc["zone_id"])
		var btn: TextureButton = _card_buttons[i]
		var lock_b: Control = _card_lock_badges[i]
		var cur_b: Control = _card_current_badges[i]

		var is_unlocked: bool = unlocked_zones.is_empty() or unlocked_zones.has(zid)
		var is_current: bool = (zid == current_zone_id)

		lock_b.visible = not is_unlocked
		cur_b.visible = is_current

		if not is_unlocked:
			btn.self_modulate = Color(0.38, 0.38, 0.44, 0.82)
			btn.tooltip_text = "%s (%s)\n🔒 Waypoint Bloqueado: Descubra o marco nesta região para viajar." % [loc["title"], loc["level_text"]]
		elif is_current:
			btn.self_modulate = Color(1.05, 1.02, 0.95, 1.0)
			btn.tooltip_text = "%s (%s)\n★ Local Atual: Você já se encontra nesta região." % [loc["title"], loc["level_text"]]
		else:
			btn.self_modulate = Color(1.0, 1.0, 1.0, 1.0)
			if can_teleport:
				btn.tooltip_text = "%s (%s)\n✦ Clique para viajar imediatamente." % [loc["title"], loc["level_text"]]
			else:
				btn.tooltip_text = "%s (%s)\n🗺 Modo Consulta (M): Teleporte indisponível fora de Waypoints." % [loc["title"], loc["level_text"]]


func _on_card_mouse_entered(idx: int) -> void:
	if idx < 0 or idx >= _card_roots.size():
		return
	var card_root: Control = _card_roots[idx]
	var btn: TextureButton = _card_buttons[idx]
	var loc: Dictionary = ACT1_LOCATIONS[idx]
	var zid: String = String(loc["zone_id"])
	var is_unlocked: bool = unlocked_zones.is_empty() or unlocked_zones.has(zid)

	var target_scale: Vector2 = Vector2(1.05, 1.05) if is_unlocked else Vector2(1.02, 1.02)
	var target_mod: Color = Color(1.2, 1.2, 1.2, 1.0) if is_unlocked else Color(0.55, 0.55, 0.62, 0.90)

	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_root, "scale", target_scale, 0.12)
	tw.tween_property(btn, "self_modulate", target_mod, 0.12)


func _on_card_mouse_exited(idx: int) -> void:
	if idx < 0 or idx >= _card_roots.size():
		return
	var card_root: Control = _card_roots[idx]
	var btn: TextureButton = _card_buttons[idx]
	var loc: Dictionary = ACT1_LOCATIONS[idx]
	var zid: String = String(loc["zone_id"])
	var is_unlocked: bool = unlocked_zones.is_empty() or unlocked_zones.has(zid)
	var is_current: bool = (zid == current_zone_id)

	var base_mod: Color
	if not is_unlocked:
		base_mod = Color(0.38, 0.38, 0.44, 0.82)
	elif is_current:
		base_mod = Color(1.05, 1.02, 0.95, 1.0)
	else:
		base_mod = Color(1.0, 1.0, 1.0, 1.0)

	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(card_root, "scale", Vector2.ONE, 0.14)
	tw.tween_property(btn, "self_modulate", base_mod, 0.14)


func _on_card_pressed(idx: int) -> void:
	if idx < 0 or idx >= ACT1_LOCATIONS.size():
		return
	_on_location_clicked(ACT1_LOCATIONS[idx])


func _on_location_clicked(loc: Dictionary) -> void:
	var target_zone: String = String(loc["zone_id"])
	var title_str: String = String(loc["title"])

	# 1. Checa se o mapa foi aberto pelo Waypoint
	if not can_teleport:
		show_map_feedback("⚠ Teleporte indisponível no Modo Consulta! Encontre um Waypoint no mundo para viajar.")
		return

	# 2. Checa se a região está desbloqueada
	var is_unlocked: bool = unlocked_zones.is_empty() or unlocked_zones.has(target_zone)
	if not is_unlocked:
		show_map_feedback("🔒 Waypoint Bloqueado! Você precisa descobrir e ativar o marco desta região primeiro.")
		return

	# 3. Checa se já está na região presente
	if target_zone == current_zone_id:
		show_map_feedback("✦ Você já está em %s!" % title_str)
		return

	# 4. Teleporte autorizado!
	close_map()
	waypoint_travel_requested.emit(target_zone)


# ============================================================================
# CICLO DE VIDA DO MODAL: ABERTURA, FECHAMENTO E PAUSA
# ============================================================================
func open_map(p_can_teleport: bool, p_current_zone: String, p_unlocked_zones: Array[String] = []) -> void:
	can_teleport = p_can_teleport
	current_zone_id = p_current_zone
	unlocked_zones = p_unlocked_zones.duplicate()

	_feedback_timer = 0.0
	if _feedback_panel != null:
		_feedback_panel.visible = false

	_update_mode_banner()
	_refresh_cards_visual_states()
	_layout_region_cards()

	if not visible:
		_hide_combat_hud_elements()
		_was_paused_before_open = get_tree().paused if get_tree() != null else false
		visible = true
		if get_tree() != null:
			get_tree().paused = true
		opened.emit()

	call_deferred("_layout_region_cards")


func close_map() -> void:
	if not visible:
		return
	visible = false
	if _feedback_panel != null:
		_feedback_panel.visible = false
	_restore_combat_hud_elements()
	if get_tree() != null and not _was_paused_before_open:
		get_tree().paused = false
	closed.emit()


func _update_mode_banner() -> void:
	if _mode_banner_panel == null or _mode_banner_title == null or _mode_banner_sub == null:
		return
	var st := _mode_banner_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if can_teleport:
		_mode_banner_title.text = "✦ WAYPOINT ANCESTRAL — SELEÇÃO DE DESTINO"
		_mode_banner_title.add_theme_color_override("font_color", Color(0.55, 0.96, 1.0))
		_mode_banner_sub.text = "Clique em uma região desbloqueada para se teleportar imediatamente."
		if st != null:
			st.border_color = Color(0.38, 0.84, 1.0, 0.96)
	else:
		_mode_banner_title.text = "🗺 MAPA DO ATO 1 — AS TERRAS DE VELEN [MODO CONSULTA]"
		_mode_banner_title.add_theme_color_override("font_color", COLOR_GOLD_TITLE)
		_mode_banner_sub.text = "Pressione [M] ou [ESC] para fechar. Para viajar, interaja com um Waypoint no mundo."
		if st != null:
			st.border_color = COLOR_BRONZE_BORDER


func show_map_feedback(msg: String) -> void:
	if _feedback_label == null or _feedback_panel == null:
		return
	_feedback_label.text = msg
	_feedback_panel.visible = true
	_feedback_timer = 3.2


func _hide_combat_hud_elements() -> void:
	_hidden_hud_elements.clear()
	var p := get_parent()
	if p != null:
		for child in p.get_children():
			if child != self and child is CanvasItem:
				var ci := child as CanvasItem
				var n: String = ci.name
				if (n.contains("Health") or n.contains("Mana") or n.contains("Skill") or n.contains("Controls") or n.contains("Info") or n.contains("TitlePlate")) and ci.visible:
					_hidden_hud_elements.append(ci)
					ci.visible = false


func _restore_combat_hud_elements() -> void:
	for el in _hidden_hud_elements:
		if is_instance_valid(el):
			el.visible = true
	_hidden_hud_elements.clear()


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
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0 and _feedback_panel != null:
			_feedback_panel.visible = false
	if _route_overlay != null:
		_route_overlay.queue_redraw()


# ============================================================================
# DESENHO DO CAMINHO LUMINOSO (ESTRADA DOURADA E NÓS ◆)
# ============================================================================
func _on_route_overlay_draw() -> void:
	if _map_canvas == null:
		return
	var canvas_sz: Vector2 = _map_canvas.size
	if canvas_sz.x < 10.0 or canvas_sz.y < 10.0:
		return

	var pulse: float = 0.5 + 0.5 * sin(_anim_time * 2.8)
	var glow_color := Color(1.0, 0.86, 0.40, 0.22 + 0.12 * pulse)
	var line_color := Color(1.0, 0.94, 0.65, 0.70 + 0.20 * pulse)

	# 1. Traçado da estrada dourada
	for segment in PATH_SEGMENTS_UV:
		var pts := PackedVector2Array()
		for uv_v in segment:
			pts.append((uv_v as Vector2) * canvas_sz)
		if pts.size() >= 2:
			_route_overlay.draw_polyline(pts, glow_color, 6.0, true)
			_route_overlay.draw_polyline(pts, line_color, 2.2, true)

	# 2. Nós dourados dos waypoints (◆)
	for loc in ACT1_LOCATIONS:
		var node_pos: Vector2 = (loc["node_uv"] as Vector2) * canvas_sz
		var zid: String = String(loc["zone_id"])
		var is_unlocked: bool = unlocked_zones.is_empty() or unlocked_zones.has(zid)
		var is_current: bool = (zid == current_zone_id)

		var node_color: Color = COLOR_GOLD_BRIGHT
		if is_current:
			node_color = COLOR_CURRENT_LOCATION
		elif not is_unlocked:
			node_color = Color(0.45, 0.42, 0.50, 0.65)

		_route_overlay.draw_circle(node_pos, 8.0, Color(0.04, 0.03, 0.06, 0.95))
		_route_overlay.draw_circle(node_pos, 6.0, node_color)
		_route_overlay.draw_circle(node_pos, 2.5, Color(1.0, 1.0, 1.0, 0.9))
