extends Node3D
class_name ZonePortal3D
## Portão / Arco de Pedra 3D que conecta os caminhos entre a Vila e as Zonas do ARPG.
## • Suporta travessia física automática ao passar pelo arco.
## • Placa 2D interativa na tela com borda grossa no hover e clique direto com o mouse.

signal zone_transition_requested(target_zone_id: String, origin_zone_id: String)

@export var origin_zone_id: String = "town"
@export var target_zone_id: String = "zone_1_road"
@export var destination_label: String = "Estrada Profanada (Nv. 1)"
@export var is_return_gate: bool = false
@export var trigger_radius: float = 1.95

static var _active_portals: Array[ZonePortal3D] = []
static var _hovered_portal: ZonePortal3D = null

var _grace_timer: float = 1.35
var _label_dest: Label3D
var _click_area: Area3D
var _is_hovered: bool = false

var _plate_panel: PanelContainer
var _plate_style: StyleBoxFlat
var _plate_title_label: Label
var _plate_prompt_label: Label

var _pending_travel_player: Node3D = null


static func get_hovered_portal() -> ZonePortal3D:
	if is_instance_valid(_hovered_portal):
		return _hovered_portal
	return null


func _ready() -> void:
	if not _active_portals.has(self):
		_active_portals.append(self)
	_create_screen_plate()


func _exit_tree() -> void:
	_active_portals.erase(self)
	if _hovered_portal == self:
		_hovered_portal = null
	if is_instance_valid(_plate_panel):
		_plate_panel.queue_free()
		_plate_panel = null


func configure(from_zone: String, to_zone: String, label_text: String, pos: Vector3, return_gate: bool = false) -> void:
	origin_zone_id = from_zone
	target_zone_id = to_zone
	destination_label = label_text
	is_return_gate = return_gate
	position = pos
	_grace_timer = 1.35
	_build_gate_visuals()
	_create_screen_plate()


func _build_gate_visuals() -> void:
	for child in get_children():
		child.queue_free()
	_click_area = null

	var stone_dark := Color(0.14, 0.14, 0.17)
	var stone_mid := Color(0.22, 0.22, 0.26)
	var accent := Color(0.36, 0.82, 0.98) if is_return_gate else Color(1.0, 0.54, 0.18)

	# Pilares laterais do Portão de Pedra
	_add_box(Vector3(-2.15, 1.55, 0.0), Vector3(0.85, 3.10, 0.95), stone_mid)
	_add_box(Vector3(2.15, 1.55, 0.0), Vector3(0.85, 3.10, 0.95), stone_mid)
	_add_box(Vector3(-2.15, 0.20, 0.0), Vector3(1.15, 0.40, 1.20), stone_dark)
	_add_box(Vector3(2.15, 0.20, 0.0), Vector3(1.15, 0.40, 1.20), stone_dark)

	# Verga / Arco superior do Portão
	_add_box(Vector3(0.0, 3.22, 0.0), Vector3(5.40, 0.52, 1.10), stone_dark)
	_add_box(Vector3(0.0, 3.60, 0.0), Vector3(3.20, 0.34, 0.90), stone_mid)

	# Tochas / Chamas nas colunas do portão
	_add_box(Vector3(-1.55, 2.10, 0.0), Vector3(0.24, 0.36, 0.24), accent, 2.2)
	_add_box(Vector3(1.55, 2.10, 0.0), Vector3(0.24, 0.36, 0.24), accent, 2.2)

	# Tapete / Limiar luminoso de passagem no chão
	_add_box(Vector3(0.0, 0.02, 0.0), Vector3(3.30, 0.03, 1.10), Color(accent.r, accent.g, accent.b, 0.45), 1.2, true)

	var prefix: String = "⬅ RETORNAR: " if is_return_gate else "➔ AVANÇAR: "
	_label_dest = Label3D.new()
	_label_dest.text = "[ %s%s ]\n(Atravesse o Portão)" % [prefix, destination_label]
	_label_dest.font_size = 32
	_label_dest.outline_size = 12
	_label_dest.modulate = accent.lightened(0.40)
	_label_dest.outline_modulate = Color(0.01, 0.01, 0.02, 1.0)
	_label_dest.render_priority = 25
	_label_dest.outline_render_priority = 24
	_label_dest.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_dest.no_depth_test = true
	_label_dest.pixel_size = 0.0085
	_label_dest.position = Vector3(0.0, 4.35, 0.0)
	_label_dest.visible = false
	add_child(_label_dest)

	# Área física 3D para capturar clique sobre o portal
	_click_area = Area3D.new()
	_click_area.name = "PortalClickArea"
	_click_area.collision_layer = 16
	_click_area.collision_mask = 0
	_click_area.input_ray_pickable = true
	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4.8, 3.6, 1.8)
	col_shape.shape = box
	col_shape.position = Vector3(0.0, 1.8, 0.0)
	_click_area.add_child(col_shape)
	_click_area.mouse_entered.connect(_on_portal_mouse_entered)
	_click_area.mouse_exited.connect(_on_portal_mouse_exited)
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
	_plate_panel.name = "ZonePortalPlate_%s" % target_zone_id
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

	var prefix: String = "⬅ RETORNAR: " if is_return_gate else "➔ AVANÇAR: "
	_plate_title_label = Label.new()
	_plate_title_label.text = "%s%s" % [prefix, destination_label]
	_plate_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plate_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_title_label.add_theme_font_size_override("font_size", 13)
	vbox.add_child(_plate_title_label)

	_plate_prompt_label = Label.new()
	_plate_prompt_label.text = "[Clique para Atravessar]"
	_plate_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plate_prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_prompt_label.add_theme_font_size_override("font_size", 10)
	vbox.add_child(_plate_prompt_label)

	_plate_panel.mouse_entered.connect(_on_portal_mouse_entered)
	_plate_panel.mouse_exited.connect(_on_portal_mouse_exited)
	_plate_panel.gui_input.connect(_on_plate_gui_input)

	hud_parent.add_child(_plate_panel)
	hud_parent.move_child(_plate_panel, 0)
	_apply_plate_visual_state(false, true)


func _update_plate_content() -> void:
	if _plate_title_label != null:
		var prefix: String = "⬅ RETORNAR: " if is_return_gate else "➔ AVANÇAR: "
		_plate_title_label.text = "%s%s" % [prefix, destination_label]
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


func _on_portal_mouse_entered() -> void:
	_hovered_portal = self
	_apply_plate_visual_state(true)


func _on_portal_mouse_exited() -> void:
	if _hovered_portal == self:
		_hovered_portal = null
	_apply_plate_visual_state(false)


func _on_plate_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_handle_transition_click()


func _on_3d_input_event(_cam: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			_handle_transition_click()


func _apply_plate_visual_state(highlighted: bool, force: bool = false) -> void:
	if not force and _is_hovered == highlighted:
		return
	_is_hovered = highlighted
	if not is_instance_valid(_plate_panel) or _plate_style == null:
		return

	var accent := Color(0.36, 0.82, 0.98) if is_return_gate else Color(1.0, 0.54, 0.18)
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
			_plate_prompt_label.text = "✦ Entrar na Zona ✦"
	else:
		_plate_style.bg_color = Color(0.035, 0.035, 0.045, 0.90)
		_plate_style.border_color = Color(accent.r * 0.65, accent.g * 0.65, accent.b * 0.65, 0.75)
		_plate_style.shadow_size = 4
		_plate_panel.z_index = 4
		if _plate_title_label != null:
			_plate_title_label.add_theme_color_override("font_color", accent.lightened(0.30))
		if _plate_prompt_label != null:
			_plate_prompt_label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.86, 0.80))
			_plate_prompt_label.text = "[Clique para Atravessar]"


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


func _handle_transition_click() -> void:
	var p_node: Node3D = _get_player()

	if p_node == null:
		zone_transition_requested.emit(target_zone_id, origin_zone_id)
		return

	var dist_xz: float = Vector2(p_node.global_position.x - global_position.x, p_node.global_position.z - global_position.z).length()
	if dist_xz <= trigger_radius * 1.8:
		_pending_travel_player = null
		if "chase_direction" in p_node:
			p_node.set("chase_direction", Vector3.ZERO)
		zone_transition_requested.emit(target_zone_id, origin_zone_id)
	else:
		_pending_travel_player = p_node
		var move_vec := Vector3(global_position.x - p_node.global_position.x, 0.0, global_position.z - p_node.global_position.z)
		if "chase_direction" in p_node:
			p_node.set("chase_direction", move_vec.normalized())
		var scene: Node = get_tree().current_scene if get_tree() != null else null
		if scene != null and "status_label" in scene and scene.status_label != null:
			scene.status_label.text = "✦ Indo até: %s..." % destination_label
			if "_status_timer" in scene:
				scene._status_timer = 2.0


func _process(delta: float) -> void:
	if _pending_travel_player != null:
		var has_manual: bool = false
		if _pending_travel_player.has_method("has_manual_move_input"):
			has_manual = _pending_travel_player.has_manual_move_input()
		if not is_instance_valid(_pending_travel_player) or has_manual:
			_pending_travel_player = null
		else:
			var p_pos: Vector3 = _pending_travel_player.global_position
			var dist_xz: float = Vector2(p_pos.x - global_position.x, p_pos.z - global_position.z).length()
			if dist_xz <= trigger_radius * 1.2:
				if "chase_direction" in _pending_travel_player:
					_pending_travel_player.set("chase_direction", Vector3.ZERO)
				_pending_travel_player = null
				zone_transition_requested.emit(target_zone_id, origin_zone_id)
			else:
				var move_vec := Vector3(global_position.x - p_pos.x, 0.0, global_position.z - p_pos.z)
				if "chase_direction" in _pending_travel_player:
					_pending_travel_player.set("chase_direction", move_vec.normalized())

	_update_screen_plate()


func _update_screen_plate() -> void:
	if not is_instance_valid(_plate_panel):
		_create_screen_plate()
	if not is_instance_valid(_plate_panel):
		return

	if not is_visible_in_tree():
		_plate_panel.visible = false
		return

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

	var world_anchor: Vector3 = global_position + Vector3(0.0, 4.35, 0.0)
	if cam.is_position_behind(world_anchor):
		_plate_panel.visible = false
		return

	var screen_pt: Vector2 = cam.unproject_position(world_anchor)
	var vp_size: Vector2 = vp.get_visible_rect().size

	if screen_pt.x < -140.0 or screen_pt.x > vp_size.x + 140.0 or screen_pt.y < -140.0 or screen_pt.y > vp_size.y + 140.0:
		_plate_panel.visible = false
		return

	_plate_panel.visible = true
	var sz: Vector2 = _plate_panel.size
	if sz.x < 30.0:
		sz = _plate_panel.get_combined_minimum_size()
	_plate_panel.position = Vector2(screen_pt.x - sz.x * 0.5, screen_pt.y - sz.y)


func _add_box(pos: Vector3, size: Vector3, col: Color, emission: float = 0.0, alpha: bool = false) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.88
	if alpha:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = Color(col.r, col.g, col.b, 1.0)
		mat.emission_energy_multiplier = emission
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func check_player_crossing(player_pos: Vector3, delta: float) -> bool:
	if _grace_timer > 0.0:
		_grace_timer = maxf(_grace_timer - delta, 0.0)
		return false
	var dx: float = absf(player_pos.x - global_position.x)
	var dz: float = absf(player_pos.z - global_position.z)
	if dx <= 1.85 and dz <= 1.45:
		_grace_timer = 1.6
		zone_transition_requested.emit(target_zone_id, origin_zone_id)
		return true
	return false
