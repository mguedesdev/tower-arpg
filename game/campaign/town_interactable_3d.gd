extends Node3D
class_name TownInteractable3D
## Objeto 3D interativo orientado a objetos para a Vila e Zonas (Diablo 2 / PoE / Grim Dawn):
## - "stash": Baú Pessoal (Stash)
## - "vendor_physical": Vendedor de Itens Físicos (Ferreiro)
## - "vendor_magic": Vendedor de Itens Mágicos (Arcanista)
## - "identifier_respec": Identificador de Itens, Cura & Resetar Build (Sábio)
## - "scribe_crafting": Mesa do Escriba (Encantamento e Forja de Afixos)
## - "waypoint": Waypoint Ancestral (Teleporte entre Vila e Zonas descobertas)
##
## Suporte completo a interação estilo loot de chão (Path of Exile / Last Epoch):
## • Placa 2D dinâmica na tela posicionada perfeitamente sobre a estação.
## • Ao passar o mouse por cima (hover): ganha borda grossa (3px) e brilho intenso.
## • Cursor em formato de mãozinha apontadora (CURSOR_POINTING_HAND).
## • Clique Esquerdo do mouse (LMB) interage diretamente sem disparar ataques da hotbar.
## • Se o jogador estiver longe, caminha automaticamente até a estação e interage ao chegar.

signal interaction_requested(station_id: String, station_title: String)

@export var station_id: String = "stash"
@export var station_title: String = "Baú Pessoal"
@export var station_subtitle: String = "[Clique] Abrir Baú"
@export var interaction_radius: float = 3.1

static var _active_stations: Array[TownInteractable3D] = []
static var _hovered_station: TownInteractable3D = null

var _label_title: Label3D
var _label_prompt: Label3D
var _highlight_ring: MeshInstance3D
var _npc_pivot: Node3D
var _animated_prop: Node3D
var _station_light: OmniLight3D
var _click_area: Area3D
var _player_in_range: bool = false
var _is_hovered: bool = false
var _pulse_time: float = 0.0

var _plate_panel: PanelContainer
var _plate_style: StyleBoxFlat
var _plate_title_label: Label
var _plate_prompt_label: Label

var _pending_interact_player: Node3D = null


static func get_hovered_station() -> TownInteractable3D:
	if is_instance_valid(_hovered_station):
		return _hovered_station
	return null


static func is_any_station_hovered() -> bool:
	return is_instance_valid(_hovered_station)


func _ready() -> void:
	if not _active_stations.has(self):
		_active_stations.append(self)
	_create_screen_plate()


func _exit_tree() -> void:
	_active_stations.erase(self)
	if _hovered_station == self:
		_hovered_station = null
	if is_instance_valid(_plate_panel):
		_plate_panel.queue_free()
		_plate_panel = null


func configure(id_value: String, title_value: String, subtitle_value: String, pos: Vector3, yaw_deg: float = 0.0) -> void:
	station_id = id_value
	station_title = title_value
	station_subtitle = subtitle_value
	position = pos
	rotation_degrees.y = yaw_deg
	_pulse_time = randf() * TAU
	_build_visuals()
	_create_screen_plate()


func _build_visuals() -> void:
	for child in get_children():
		child.queue_free()
	_npc_pivot = null
	_animated_prop = null
	_station_light = null
	_click_area = null

	var accent_color := _get_accent_color()

	# Anel de destaque rúnico no chão
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.32
	ring_mesh.bottom_radius = 1.38
	ring_mesh.height = 0.03
	ring_mesh.radial_segments = 24
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.36)
	ring_mat.emission_enabled = true
	ring_mat.emission = accent_color
	ring_mat.emission_energy_multiplier = 1.0
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_ring = MeshInstance3D.new()
	_highlight_ring.mesh = ring_mesh
	_highlight_ring.material_override = ring_mat
	_highlight_ring.position = Vector3(0.0, 0.02, 0.0)
	_highlight_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight_ring)

	# Iluminação atmosférica suave por estação (sincronizada com Dia/Noite para não lavar as sombras de dia)
	_station_light = OmniLight3D.new()
	_station_light.name = "StationFireLight"
	_station_light.light_color = accent_color
	_station_light.light_energy = 0.55
	_station_light.omni_range = 3.2
	_station_light.omni_attenuation = 1.5
	_station_light.shadow_blur = 0.0
	_station_light.position = Vector3(0.0, 1.8, 0.3)
	add_child(_station_light)

	match station_id:
		"stash":
			_build_stash_chest()
		"vendor_physical":
			_build_npc_figure(Color(0.32, 0.17, 0.12), Color(0.75, 0.48, 0.22), true, false)
		"vendor_magic":
			_build_npc_figure(Color(0.14, 0.18, 0.38), Color(0.38, 0.72, 1.0), false, true)
		"identifier_respec":
			_build_npc_figure(Color(0.24, 0.22, 0.19), Color(0.95, 0.78, 0.36), false, false)
		"scribe_crafting":
			_build_scribe_desk()
		"waypoint":
			_build_waypoint_pad()

	var label_height: float = 1.95 if (station_id == "stash" or station_id == "waypoint" or station_id == "scribe_crafting") else 2.55

	# Labels 3D mantidos internamente para compatibilidade, ocultados em prol da placa 2D interativa
	_label_title = Label3D.new()
	_label_title.text = "✦ %s ✦" % station_title
	_label_title.font_size = 32
	_label_title.outline_size = 12
	_label_title.modulate = accent_color.lightened(0.35)
	_label_title.outline_modulate = Color(0.01, 0.01, 0.02, 1.0)
	_label_title.render_priority = 25
	_label_title.outline_render_priority = 24
	_label_title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_title.no_depth_test = true
	_label_title.pixel_size = 0.0085
	_label_title.position = Vector3(0.0, label_height, 0.0)
	_label_title.visible = false
	add_child(_label_title)

	_label_prompt = Label3D.new()
	_label_prompt.text = "%s" % station_subtitle
	_label_prompt.font_size = 26
	_label_prompt.outline_size = 10
	_label_prompt.modulate = Color(0.98, 0.95, 0.88, 0.98)
	_label_prompt.outline_modulate = Color(0.01, 0.01, 0.02, 1.0)
	_label_prompt.render_priority = 25
	_label_prompt.outline_render_priority = 24
	_label_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_prompt.no_depth_test = true
	_label_prompt.pixel_size = 0.0075
	_label_prompt.position = Vector3(0.0, label_height - 0.35, 0.0)
	_label_prompt.visible = false
	add_child(_label_prompt)

	# Área física 3D para capturar hover e clique diretamente no modelo 3D
	_click_area = Area3D.new()
	_click_area.name = "StationClickArea"
	_click_area.collision_layer = 16
	_click_area.collision_mask = 0
	_click_area.input_ray_pickable = true
	var col_shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 1.35
	cyl.height = 2.4
	col_shape.shape = cyl
	col_shape.position = Vector3(0.0, 1.2, 0.0)
	_click_area.add_child(col_shape)
	_click_area.mouse_entered.connect(_on_plate_mouse_entered)
	_click_area.mouse_exited.connect(_on_plate_mouse_exited)
	_click_area.input_event.connect(_on_3d_input_event)
	add_child(_click_area)


func _create_screen_plate() -> void:
	if is_instance_valid(_plate_panel):
		_update_plate_content()
		return
	var hud_parent: Node = _find_hud_layer()
	if hud_parent == null:
		return

	_plate_panel = PanelContainer.new()
	_plate_panel.name = "StationPlate_%s" % station_id
	_plate_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_plate_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_plate_panel.z_index = 4

	_plate_style = StyleBoxFlat.new()
	_plate_style.set_corner_radius_all(3)
	_plate_style.shadow_color = Color(0.0, 0.0, 0.0, 0.85)
	_plate_style.content_margin_left = 12
	_plate_style.content_margin_right = 12
	_plate_style.content_margin_top = 4
	_plate_style.content_margin_bottom = 4
	_plate_panel.add_theme_stylebox_override("panel", _plate_style)

	var vbox := VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override("separation", 1)
	_plate_panel.add_child(vbox)

	_plate_title_label = Label.new()
	_plate_title_label.text = _format_station_title()
	_plate_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plate_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_title_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_plate_title_label)

	_plate_prompt_label = Label.new()
	_plate_prompt_label.text = station_subtitle
	_plate_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plate_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_prompt_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_plate_prompt_label)

	_plate_panel.mouse_entered.connect(_on_plate_mouse_entered)
	_plate_panel.mouse_exited.connect(_on_plate_mouse_exited)
	_plate_panel.gui_input.connect(_on_plate_gui_input)

	hud_parent.add_child(_plate_panel)
	hud_parent.move_child(_plate_panel, 0)
	_apply_plate_visual_state(false, true)


func _update_plate_content() -> void:
	if _plate_title_label != null:
		_plate_title_label.text = _format_station_title()
	if _plate_prompt_label != null:
		_plate_prompt_label.text = station_subtitle
	_apply_plate_visual_state(_is_hovered, true)


func _find_hud_layer() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var scene: Node = tree.current_scene
	if scene == null:
		scene = get_parent()
	if scene != null:
		var hud: Node = scene.get_node_or_null("HUD")
		if hud != null:
			return hud
	return scene


func _format_station_title() -> String:
	match station_id:
		"waypoint":
			return "◆  %s  ◆" % station_title
		"stash":
			return "✦  %s  ✦" % station_title
		"vendor_physical":
			return "⚒  %s  ⚒" % station_title
		"vendor_magic":
			return "✦  %s  ✦" % station_title
		"identifier_respec":
			return "📜  %s  📜" % station_title
		"scribe_crafting":
			return "✒  %s  ✒" % station_title
		_:
			return "✦  %s  ✦" % station_title


func _on_plate_mouse_entered() -> void:
	_hovered_station = self
	_apply_plate_visual_state(true)


func _on_plate_mouse_exited() -> void:
	if _hovered_station == self:
		_hovered_station = null
	_apply_plate_visual_state(false)


func _on_plate_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_handle_interaction_click()


func _on_3d_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_handle_interaction_click()


func _apply_plate_visual_state(highlighted: bool, force: bool = false) -> void:
	if not force and _is_hovered == highlighted:
		return
	_is_hovered = highlighted
	if not is_instance_valid(_plate_panel) or _plate_style == null:
		return

	var accent := _get_accent_color()

	# Borda grossa (3px) no hover conforme solicitado pelo usuário:
	# "coloque uma borda grossa e talz a gente vai saber q ta com o mouse em cima"
	var bw: int = 3 if highlighted else 1
	_plate_style.set_border_width_all(bw)

	if highlighted:
		_plate_style.bg_color = Color(accent.r * 0.18, accent.g * 0.18, accent.b * 0.18, 0.96).lerp(Color(0.08, 0.08, 0.12, 0.96), 0.45)
		_plate_style.border_color = accent.lightened(0.35)
		_plate_style.shadow_size = 8
		_plate_panel.z_index = 16
		if _plate_title_label != null:
			_plate_title_label.add_theme_color_override("font_color", Color.WHITE)
		if _plate_prompt_label != null:
			_plate_prompt_label.add_theme_color_override("font_color", Color(1.0, 0.94, 0.62))
			_plate_prompt_label.text = "✦ %s ✦" % station_subtitle.replace("[", "").replace("]", "")
		if _highlight_ring != null and _highlight_ring.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = _highlight_ring.material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 2.4
			_highlight_ring.scale = Vector3(1.18, 1.0, 1.18)
		if _station_light != null:
			_station_light.light_energy = 0.90
	else:
		_plate_style.bg_color = Color(0.035, 0.035, 0.045, 0.90)
		_plate_style.border_color = Color(accent.r * 0.65, accent.g * 0.65, accent.b * 0.65, 0.75)
		_plate_style.shadow_size = 4
		_plate_panel.z_index = 4
		if _plate_title_label != null:
			_plate_title_label.add_theme_color_override("font_color", accent.lightened(0.30))
		if _plate_prompt_label != null:
			_plate_prompt_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.86, 0.80))
			_plate_prompt_label.text = station_subtitle
		if _highlight_ring != null and _highlight_ring.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = _highlight_ring.material_override as StandardMaterial3D
			mat.emission_energy_multiplier = 1.0
			_highlight_ring.scale = Vector3(1.0, 1.0, 1.0)
		if _station_light != null:
			_station_light.light_energy = 0.55


func _get_player() -> Node3D:
	var tree := get_tree()
	if tree == null:
		return null
	var p_nodes := tree.get_nodes_in_group("player")
	if not p_nodes.is_empty():
		return p_nodes[0] as Node3D
	var scene: Node = tree.current_scene
	if scene == null:
		scene = get_parent()
	if scene != null:
		if "player" in scene and scene.player != null and scene.player is Node3D:
			return scene.player as Node3D
		var found = scene.find_child("player", true, false)
		if found is Node3D:
			return found as Node3D
		found = scene.find_child("Player", true, false)
		if found is Node3D:
			return found as Node3D
	return null


func _handle_interaction_click() -> void:
	var p_node: Node3D = _get_player()

	if p_node == null:
		trigger_interaction()
		return

	var dist_xz: float = Vector2(p_node.global_position.x - global_position.x, p_node.global_position.z - global_position.z).length()
	if dist_xz <= interaction_radius * 1.5:
		# Perto o suficiente: aciona imediatamente!
		_pending_interact_player = null
		if "chase_direction" in p_node:
			p_node.set("chase_direction", Vector3.ZERO)
		trigger_interaction()
	else:
		# Se estiver distante, o herói caminha suavemente até o NPC/Waypoint e abre a janela ao chegar!
		_pending_interact_player = p_node
		var move_vec := Vector3(global_position.x - p_node.global_position.x, 0.0, global_position.z - p_node.global_position.z)
		if "chase_direction" in p_node:
			p_node.set("chase_direction", move_vec.normalized())
		var scene: Node = get_tree().current_scene if get_tree() != null else null
		if scene != null and "status_label" in scene and scene.status_label != null:
			scene.status_label.text = "✦ A caminho de: %s..." % station_title
			if "_status_timer" in scene:
				scene._status_timer = 2.0


func _process(delta: float) -> void:
	# 1. Movimentação automática até a estação quando clicada de longe
	if _pending_interact_player != null:
		var has_manual: bool = false
		if _pending_interact_player.has_method("has_manual_move_input"):
			has_manual = _pending_interact_player.has_manual_move_input()
		if not is_instance_valid(_pending_interact_player) or has_manual:
			_pending_interact_player = null
		else:
			var p_pos: Vector3 = _pending_interact_player.global_position
			var dist_xz: float = Vector2(p_pos.x - global_position.x, p_pos.z - global_position.z).length()
			if dist_xz <= interaction_radius * 1.15:
				if "chase_direction" in _pending_interact_player:
					_pending_interact_player.set("chase_direction", Vector3.ZERO)
				_pending_interact_player = null
				trigger_interaction()
			else:
				var move_vec := Vector3(global_position.x - p_pos.x, 0.0, global_position.z - p_pos.z)
				if "chase_direction" in _pending_interact_player:
					_pending_interact_player.set("chase_direction", move_vec.normalized())

	# 2. Atualização da posição 2D da placa flutuante na tela
	_update_screen_plate()


func _update_screen_plate() -> void:
	if not is_instance_valid(_plate_panel):
		_create_screen_plate()
	if not is_instance_valid(_plate_panel):
		return

	if not is_visible_in_tree():
		_plate_panel.visible = false
		return

	# Oculta se alguma janela modal bloqueante estiver aberta (Inventário / Diálogo)
	var tree := get_tree()
	if tree != null:
		for m in tree.get_nodes_in_group("blocking_modal"):
			if m is CanvasItem and (m as CanvasItem).visible:
				_plate_panel.visible = false
				return

	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null:
		return

	var label_height: float = 1.95 if (station_id == "stash" or station_id == "waypoint" or station_id == "scribe_crafting") else 2.55
	var world_anchor: Vector3 = global_position + Vector3(0.0, label_height, 0.0)

	if cam.is_position_behind(world_anchor):
		_plate_panel.visible = false
		return

	var screen_pt: Vector2 = cam.unproject_position(world_anchor)
	var vp_size: Vector2 = vp.get_visible_rect().size

	if screen_pt.x < -120.0 or screen_pt.x > vp_size.x + 120.0 or screen_pt.y < -120.0 or screen_pt.y > vp_size.y + 120.0:
		_plate_panel.visible = false
		return

	_plate_panel.visible = true
	var sz: Vector2 = _plate_panel.size
	if sz.x < 30.0:
		sz = _plate_panel.get_combined_minimum_size()
	_plate_panel.position = Vector2(screen_pt.x - sz.x * 0.5, screen_pt.y - sz.y)


func _get_accent_color() -> Color:
	match station_id:
		"stash":
			return Color(0.94, 0.76, 0.32)
		"vendor_physical":
			return Color(0.95, 0.52, 0.24)
		"vendor_magic":
			return Color(0.42, 0.76, 1.0)
		"identifier_respec":
			return Color(0.92, 0.84, 0.52)
		"scribe_crafting":
			return Color(0.88, 0.65, 0.98)
		"waypoint":
			return Color(0.36, 0.84, 1.0)
	return Color(0.86, 0.72, 0.38)


func _build_scribe_desk() -> void:
	# Tapete violeta arcano + Mesa de mogno do escriba + Pergaminhos, cinzel e tinteiro
	_add_box(self, Vector3(0.0, 0.02, 0.0), Vector3(2.1, 0.04, 1.55), Color(0.28, 0.14, 0.38), 0.9)
	# Pedestal de pedra escura
	_add_box(self, Vector3(0.0, 0.12, 0.0), Vector3(1.68, 0.20, 1.15), Color(0.16, 0.16, 0.19))
	# Tampo e corpo da mesa de escrita
	_add_box(self, Vector3(0.0, 0.56, 0.0), Vector3(1.42, 0.68, 0.86), Color(0.24, 0.13, 0.08), 0.75)
	_add_box(self, Vector3(0.0, 0.92, 0.0), Vector3(1.48, 0.10, 0.92), Color(0.32, 0.17, 0.10), 0.70)
	# Manuscrito aberto com runas arcanas brilhantes
	_add_box(self, Vector3(-0.20, 0.98, 0.05), Vector3(0.55, 0.03, 0.42), Color(0.92, 0.88, 0.78), 0.4, 0.2)
	# Lacre de cera carmesim no manuscrito
	_add_box(self, Vector3(-0.20, 1.00, 0.16), Vector3(0.09, 0.02, 0.09), Color(0.78, 0.12, 0.14), 0.2, 0.6)
	# Rolo de pergaminho fechado ao lado
	_add_cyl(self, Vector3(0.35, 1.00, -0.15), 0.07, 0.45, Color(0.88, 0.82, 0.70), 10)
	# Tinteiro com pena e cinzel de pedra
	_add_cyl(self, Vector3(0.42, 1.00, 0.20), 0.08, 0.14, Color(0.12, 0.12, 0.14), 8)
	_add_box(self, Vector3(0.15, 0.98, -0.22), Vector3(0.26, 0.04, 0.08), Color(0.42, 0.42, 0.48), 0.1, 0.5)


func _build_stash_chest() -> void:
	# Tapete real carmesim + Pedestal de pedra + Baú de madeira escura reforçado com ferro e fecho dourado
	_add_box(self, Vector3(0.0, 0.02, 0.0), Vector3(2.1, 0.04, 1.55), Color(0.45, 0.12, 0.12), 0.9)
	_add_box(self, Vector3(0.0, 0.14, 0.0), Vector3(1.58, 0.28, 1.12), Color(0.18, 0.18, 0.21))
	_add_box(self, Vector3(0.0, 0.52, 0.0), Vector3(1.26, 0.52, 0.80), Color(0.26, 0.15, 0.09), 0.82)
	_add_box(self, Vector3(0.0, 0.84, 0.0), Vector3(1.30, 0.24, 0.84), Color(0.30, 0.17, 0.10), 0.80)
	# Tiras de ferro e fecho de bronze dourado brilhante
	_add_box(self, Vector3(-0.42, 0.58, 0.0), Vector3(0.10, 0.68, 0.86), Color(0.24, 0.26, 0.30), 0.40)
	_add_box(self, Vector3(0.42, 0.58, 0.0), Vector3(0.10, 0.68, 0.86), Color(0.24, 0.26, 0.30), 0.40)
	_add_box(self, Vector3(0.0, 0.68, 0.42), Vector3(0.24, 0.28, 0.08), Color(0.94, 0.76, 0.28), 0.30, 0.85)


func _build_npc_figure(robe_color: Color, trim_color: Color, is_blacksmith: bool, is_mage: bool) -> void:
	# Base circular de pedra ornamentada
	_add_cyl(self, Vector3(0.0, 0.08, 0.0), 0.72, 0.16, Color(0.17, 0.17, 0.20), 14)

	# Pivô animado do corpo do NPC (respiração suave e vida)
	_npc_pivot = Node3D.new()
	add_child(_npc_pivot)

	# Manto/Corpo
	_add_cyl(_npc_pivot, Vector3(0.0, 0.72, 0.0), 0.36, 1.15, robe_color, 10)
	# Cinto e Avental/Estola
	_add_box(_npc_pivot, Vector3(0.0, 0.70, 0.20), Vector3(0.42, 0.75, 0.08), trim_color.darkened(0.15), 0.75)
	# Ombreiras / Manto superior
	_add_box(_npc_pivot, Vector3(0.0, 1.24, 0.0), Vector3(0.84, 0.28, 0.48), trim_color.darkened(0.22), 0.60)
	# Braços
	_add_box(_npc_pivot, Vector3(-0.44, 0.96, 0.10), Vector3(0.18, 0.52, 0.22), robe_color.lightened(0.08))
	_add_box(_npc_pivot, Vector3(0.44, 0.96, 0.12), Vector3(0.18, 0.52, 0.22), robe_color.lightened(0.08))
	# Cabeça + Capuz Gótico
	_add_cyl(_npc_pivot, Vector3(0.0, 1.56, 0.0), 0.21, 0.34, Color(0.78, 0.65, 0.55), 10)
	_add_box_rot(_npc_pivot, Vector3(0.0, 1.66, -0.04), Vector3(0.48, 0.38, 0.48), robe_color.darkened(0.2), Vector3(0.15, 0.0, 0.0))

	_animated_prop = Node3D.new()
	add_child(_animated_prop)

	if is_blacksmith:
		# Bigorna de ferro + Fornalha em brasa pulsante + Martelo na mão
		_add_box(self, Vector3(0.92, 0.28, 0.25), Vector3(0.54, 0.56, 0.44), Color(0.22, 0.15, 0.10))
		_add_box(self, Vector3(0.92, 0.66, 0.25), Vector3(0.82, 0.24, 0.38), Color(0.28, 0.30, 0.35), 0.35)
		# Braseiro da forja ao lado esquerdo
		_add_cyl(self, Vector3(-0.92, 0.38, 0.15), 0.38, 0.76, Color(0.18, 0.16, 0.16), 10)
		_add_cyl(_animated_prop, Vector3(-0.92, 0.80, 0.15), 0.30, 0.14, Color(1.0, 0.42, 0.12), 10, 0.3, 2.4)
		# Espada em brasa sobre a bigorna
		_add_box(self, Vector3(0.92, 0.80, 0.25), Vector3(0.55, 0.04, 0.12), Color(1.0, 0.55, 0.18), 0.3, 1.8)
	elif is_mage:
		# Pedestal místico com Orbe Arcano flutuante e cristais orbitando
		_add_cyl(self, Vector3(0.88, 0.48, 0.25), 0.24, 0.96, Color(0.20, 0.21, 0.28), 10)
		_animated_prop.position = Vector3(0.88, 1.22, 0.25)
		_add_cyl(_animated_prop, Vector3.ZERO, 0.20, 0.32, Color(0.32, 0.74, 1.0), 12, 0.15, 2.5)
		_add_box(_animated_prop, Vector3(0.34, 0.05, 0.0), Vector3(0.10, 0.22, 0.10), Color(0.55, 0.85, 1.0), 0.2, 2.0)
		_add_box(_animated_prop, Vector3(-0.34, -0.05, 0.0), Vector3(0.10, 0.22, 0.10), Color(0.55, 0.85, 1.0), 0.2, 2.0)
	else:
		# Atril do Sábio Identificador com Tomo Dourado e Lanterna Ancestral flutuante
		_add_cyl(self, Vector3(0.86, 0.48, 0.28), 0.18, 0.96, Color(0.26, 0.17, 0.11), 8)
		_add_box_rot(self, Vector3(0.86, 1.02, 0.28), Vector3(0.50, 0.10, 0.40), Color(0.92, 0.74, 0.28), Vector3(0.45, 0.0, 0.0))
		_animated_prop.position = Vector3(-0.78, 1.35, 0.28)
		_add_cyl(_animated_prop, Vector3.ZERO, 0.15, 0.28, Color(0.98, 0.84, 0.42), 8, 0.2, 2.2)


func _build_waypoint_pad() -> void:
	_add_cyl(self, Vector3(0.0, 0.05, 0.0), 1.42, 0.10, Color(0.18, 0.19, 0.23), 18)
	_add_cyl(self, Vector3(0.0, 0.10, 0.0), 1.12, 0.08, Color(0.25, 0.27, 0.32), 18)
	_animated_prop = Node3D.new()
	_animated_prop.position = Vector3(0.0, 0.15, 0.0)
	add_child(_animated_prop)
	_add_cyl(_animated_prop, Vector3.ZERO, 0.72, 0.04, Color(0.28, 0.80, 1.0), 16, 0.2, 2.5)


func _add_box(parent: Node3D, pos: Vector3, size: Vector3, col: Color, rough: float = 0.90, emission: float = 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = _make_mat(col, rough, emission)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (emission > 0.0 or size.y <= 0.06) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func _add_box_rot(parent: Node3D, pos: Vector3, size: Vector3, col: Color, rot: Vector3) -> MeshInstance3D:
	var mi := _add_box(parent, pos, size, col)
	mi.rotation = rot
	return mi


func _add_cyl(parent: Node3D, pos: Vector3, rad: float, h: float, col: Color, segs: int = 10, rough: float = 0.90, emission: float = 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = rad
	m.bottom_radius = rad
	m.height = h
	m.radial_segments = segs
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = _make_mat(col, rough, emission)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (emission > 0.0 or h <= 0.12) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mi)
	return mi


func _make_mat(col: Color, rough: float = 0.90, emission: float = 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = rough
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = emission
	return mat


func update_proximity(player_pos: Vector3, delta: float) -> bool:
	var dist_xz: float = Vector2(player_pos.x - global_position.x, player_pos.z - global_position.z).length()
	_player_in_range = dist_xz <= interaction_radius
	_pulse_time += delta * 3.2

	if _label_prompt != null:
		_label_prompt.visible = _player_in_range
	if _highlight_ring != null and not _is_hovered:
		var scale_f: float = (1.07 + 0.05 * sin(_pulse_time * 1.4)) if _player_in_range else 1.0
		_highlight_ring.scale = Vector3(scale_f, 1.0, scale_f)

	# Animação de vida/respiração dos NPCs e artefatos mágicos
	if _npc_pivot != null:
		_npc_pivot.position.y = sin(_pulse_time) * 0.035
		_npc_pivot.rotation.y = sin(_pulse_time * 0.5) * 0.06
	if _animated_prop != null:
		if station_id == "vendor_magic":
			_animated_prop.position.y = 1.22 + sin(_pulse_time * 1.3) * 0.08
			_animated_prop.rotation.y += delta * 1.8
		elif station_id == "identifier_respec":
			_animated_prop.position.y = 1.35 + sin(_pulse_time * 1.1) * 0.06
		elif station_id == "waypoint":
			_animated_prop.rotation.y += delta * 0.8

	return _player_in_range


func is_player_in_range() -> bool:
	return _player_in_range


func trigger_interaction() -> void:
	interaction_requested.emit(station_id, station_title)
