extends Area3D
class_name GroundItem3D
## Drop 3D no chão com placa 2D em tela ("tooltip de chão" estilo Last Epoch / Path of Exile 2):
## • Empilhamento vertical automático sem sobreposição quando 2 ou mais loots caem juntos.
## • O item em destaque (sob o mouse ou mais próximo do herói) ganha borda mais grossa (3px) e caixa/texto maior.
## • Permite selecionar e pegar com Clique Esquerdo do mouse ou tecla [E].

signal picked_up(item: ItemInstance)

const VFX = preload("res://scripts/vfx/tower_vfx_spawner.gd")

static var _mat_cache: Dictionary = {}
static var _beam_mat_cache: Dictionary = {}
static var _cyl_mesh: CylinderMesh = null
static var _beam_mesh: CylinderMesh = null
static var _box_meshes: Dictionary = {}

static var _active_items: Array[GroundItem3D] = []
static var _hovered_item: GroundItem3D = null
static var _last_layout_frame: int = -1

var item: ItemInstance
var is_picked: bool = false
var _mesh_instance: MeshInstance3D
var _light_beam: MeshInstance3D
var _bob_time: float = 0.0

var _is_in_range: bool = false
var _is_highlighted: bool = false
var _plate_panel: PanelContainer
var _plate_label: Label
var _plate_style: StyleBoxFlat
var _spawn_order: int = 0
static var _spawn_counter: int = 0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = false
	_spawn_counter += 1
	_spawn_order = _spawn_counter
	if not _active_items.has(self):
		_active_items.append(self)


func _exit_tree() -> void:
	_active_items.erase(self)
	if _hovered_item == self:
		_hovered_item = null
	if is_instance_valid(_plate_panel):
		_plate_panel.queue_free()


func setup_drop(p_item: ItemInstance, spawn_pos: Vector3) -> void:
	item = p_item
	global_position = spawn_pos + Vector3(0.0, 0.12, 0.0)

	var r_col: Color = item.get_rarity_color() if item != null else Color.WHITE

	# 1. Geometria 3D Primitiva em cache (Bloco para armas/armaduras, cilindro para anéis/amuletos)
	_mesh_instance = MeshInstance3D.new()
	var is_round: bool = item != null and (
		item.definition.category == ItemDefinition.ItemCategory.RING
		or item.definition.category == ItemDefinition.ItemCategory.AMULET
		or item.definition.category == ItemDefinition.ItemCategory.CONSUMABLE
	)

	if is_round:
		if _cyl_mesh == null:
			_cyl_mesh = CylinderMesh.new()
			_cyl_mesh.top_radius = 0.18
			_cyl_mesh.bottom_radius = 0.18
			_cyl_mesh.height = 0.12
		_mesh_instance.mesh = _cyl_mesh
	else:
		var sz: Vector2i = item.definition.grid_size if item != null and item.definition != null else Vector2i(2, 3)
		var box_key: Vector2i = sz
		if not _box_meshes.has(box_key):
			var box := BoxMesh.new()
			box.size = Vector3(float(sz.x) * 0.18, 0.08, float(sz.y) * 0.22)
			_box_meshes[box_key] = box
		_mesh_instance.mesh = _box_meshes[box_key]

	var mat_key: int = item.rarity if item != null else 0
	if not _mat_cache.has(mat_key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = r_col
		mat.metallic = 0.5
		mat.roughness = 0.3
		mat.emission_enabled = true
		mat.emission = r_col * 0.4
		_mat_cache[mat_key] = mat
	_mesh_instance.material_override = _mat_cache[mat_key]
	add_child(_mesh_instance)

	# 2. Feixe de Luz Vertical em cache (Pilar de raridade em itens Mágicos, Raros e Únicos)
	if item != null and item.rarity != ItemInstance.ItemRarity.NORMAL:
		_light_beam = MeshInstance3D.new()
		if _beam_mesh == null:
			_beam_mesh = CylinderMesh.new()
			_beam_mesh.top_radius = 0.05
			_beam_mesh.bottom_radius = 0.10
			_beam_mesh.height = 2.0
		_light_beam.mesh = _beam_mesh
		_light_beam.position = Vector3(0.0, 1.0, 0.0)

		if not _beam_mat_cache.has(mat_key):
			var beam_mat := StandardMaterial3D.new()
			beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			beam_mat.albedo_color = Color(r_col.r, r_col.g, r_col.b, 0.24)
			beam_mat.emission_enabled = true
			beam_mat.emission = r_col * 0.75
			beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_beam_mat_cache[mat_key] = beam_mat
		_light_beam.material_override = _beam_mat_cache[mat_key]
		add_child(_light_beam)

	# 3. Placa 2D de Item no Chão (Estilo Last Epoch / Path of Exile 2)
	_create_screen_plate()


func _create_screen_plate() -> void:
	var hud_parent: Node = _find_hud_layer()
	if hud_parent == null:
		return

	_plate_panel = PanelContainer.new()
	_plate_panel.name = "GroundLootPlate_%d" % _spawn_order
	_plate_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_plate_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_plate_panel.z_index = 2

	_plate_style = StyleBoxFlat.new()
	_plate_style.set_corner_radius_all(2)
	_plate_style.shadow_color = Color(0.0, 0.0, 0.0, 0.78)
	_plate_panel.add_theme_stylebox_override("panel", _plate_style)

	_plate_label = Label.new()
	_plate_label.text = _format_ground_plate_text()
	_plate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_plate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_plate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate_panel.add_child(_plate_label)

	_plate_panel.mouse_entered.connect(_on_plate_mouse_entered)
	_plate_panel.mouse_exited.connect(_on_plate_mouse_exited)
	_plate_panel.gui_input.connect(_on_plate_gui_input)

	hud_parent.add_child(_plate_panel)
	hud_parent.move_child(_plate_panel, 0)
	_apply_plate_visual_state(false, true)


func _find_hud_layer() -> Node:
	var scene: Node = get_tree().current_scene if get_tree() != null else null
	if scene == null:
		scene = get_parent()
	if scene != null:
		var hud: Node = scene.get_node_or_null("HUD")
		if hud != null:
			return hud
	return scene


func _format_ground_plate_text() -> String:
	if item == null:
		return "Item"
	var base_name: String = item.get_display_name()
	if item.definition != null and item.definition.category == ItemDefinition.ItemCategory.CONSUMABLE:
		return "♦  %s  ♦" % base_name
	match item.rarity:
		ItemInstance.ItemRarity.UNIQUE:
			return "★  %s  ★" % base_name
		ItemInstance.ItemRarity.RARE:
			return "• •  %s  • •" % base_name
		ItemInstance.ItemRarity.MAGIC:
			return "•  %s  •" % base_name
		_:
			return base_name


func _on_plate_mouse_entered() -> void:
	if is_picked:
		return
	_hovered_item = self
	_refresh_all_highlights()


func _on_plate_mouse_exited() -> void:
	if _hovered_item == self:
		_hovered_item = null
		_refresh_all_highlights()


func _on_plate_gui_input(event: InputEvent) -> void:
	if is_picked:
		return
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			var scene: Node = get_tree().current_scene if get_tree() != null else null
			var p_node: Node3D = null
			if scene != null and "player" in scene:
				p_node = scene.player as Node3D
			if p_node != null:
				var dist: float = p_node.global_position.distance_to(global_position)
				if dist <= 4.5:
					attempt_pickup(p_node)
					get_viewport().set_input_as_handled()
				else:
					if scene != null and "status_label" in scene and scene.status_label != null:
						scene.status_label.text = "⚠ Aproxime-se do item para coletar: %s" % (item.get_display_name() if item != null else "Item")
						if "_status_timer" in scene:
							scene._status_timer = 2.0
					get_viewport().set_input_as_handled()


func set_in_pickup_range(in_range: bool) -> void:
	if _is_in_range == in_range:
		return
	_is_in_range = in_range
	_refresh_all_highlights()


static func get_highlighted_item(player_pos: Vector3, max_dist: float = 4.2) -> GroundItem3D:
	if is_instance_valid(_hovered_item) and not _hovered_item.is_picked:
		if player_pos.distance_to(_hovered_item.global_position) <= max_dist:
			return _hovered_item
	var nearest: GroundItem3D = null
	var min_d: float = max_dist
	for it in _active_items:
		if is_instance_valid(it) and not it.is_picked:
			var d: float = player_pos.distance_to(it.global_position)
			if d < min_d:
				min_d = d
				nearest = it
	return nearest


static func _refresh_all_highlights() -> void:
	var active_highlight: GroundItem3D = null
	if is_instance_valid(_hovered_item) and not _hovered_item.is_picked:
		active_highlight = _hovered_item
	else:
		for it in _active_items:
			if is_instance_valid(it) and not it.is_picked and it._is_in_range:
				active_highlight = it
				break

	for it in _active_items:
		if is_instance_valid(it) and not it.is_picked:
			it._apply_plate_visual_state(it == active_highlight)


func _apply_plate_visual_state(highlighted: bool, force: bool = false) -> void:
	if not force and _is_highlighted == highlighted:
		return
	_is_highlighted = highlighted
	if not is_instance_valid(_plate_panel) or _plate_style == null or _plate_label == null:
		return

	var bg_col := Color(0.035, 0.035, 0.045, 0.90)
	var border_col := Color(0.32, 0.32, 0.36, 0.82)
	var text_col := Color(0.92, 0.92, 0.94)

	if item != null:
		if item.definition != null and item.definition.category == ItemDefinition.ItemCategory.CONSUMABLE:
			bg_col = Color(0.16, 0.04, 0.05, 0.96) if highlighted else Color(0.10, 0.03, 0.04, 0.90)
			border_col = Color(1.0, 0.52, 0.55, 1.0) if highlighted else Color(0.62, 0.20, 0.24, 0.85)
			text_col = Color(1.0, 0.86, 0.86) if highlighted else Color(0.96, 0.65, 0.68)
		else:
			match item.rarity:
				ItemInstance.ItemRarity.MAGIC:
					bg_col = Color(0.08, 0.14, 0.28, 0.97) if highlighted else Color(0.035, 0.055, 0.12, 0.90)
					border_col = Color(0.68, 0.86, 1.0, 1.0) if highlighted else Color(0.26, 0.46, 0.82, 0.85)
					text_col = Color(0.82, 0.92, 1.0) if highlighted else Color(0.46, 0.72, 1.0)
				ItemInstance.ItemRarity.RARE:
					bg_col = Color(0.16, 0.13, 0.04, 0.97) if highlighted else Color(0.06, 0.055, 0.025, 0.92)
					border_col = Color(1.0, 0.92, 0.44, 1.0) if highlighted else Color(0.65, 0.54, 0.18, 0.86)
					text_col = Color(1.0, 0.95, 0.58) if highlighted else Color(0.98, 0.85, 0.30)
				ItemInstance.ItemRarity.UNIQUE:
					bg_col = Color(0.44, 0.22, 0.07, 0.98) if highlighted else Color(0.28, 0.14, 0.05, 0.93)
					border_col = Color(1.0, 0.86, 0.52, 1.0) if highlighted else Color(0.84, 0.48, 0.16, 0.90)
					text_col = Color(1.0, 0.95, 0.84) if highlighted else Color(1.0, 0.80, 0.55)
				_:
					bg_col = Color(0.09, 0.09, 0.12, 0.97) if highlighted else Color(0.035, 0.035, 0.045, 0.90)
					border_col = Color(0.96, 0.96, 1.0, 1.0) if highlighted else Color(0.32, 0.32, 0.36, 0.80)
					text_col = Color(1.0, 1.0, 1.0) if highlighted else Color(0.88, 0.88, 0.90)

	# Quando em destaque: borda mais grossa (3px vs 1px) e "tooltip" maior (fonte 16px + margens maiores)!
	var bw: int = 3 if highlighted else 1
	_plate_style.bg_color = bg_col
	_plate_style.border_color = border_col
	_plate_style.set_border_width_all(bw)
	_plate_style.content_margin_left = 15 if highlighted else 10
	_plate_style.content_margin_right = 15 if highlighted else 10
	_plate_style.content_margin_top = 6 if highlighted else 3
	_plate_style.content_margin_bottom = 6 if highlighted else 3
	_plate_style.shadow_size = 8 if highlighted else 3

	_plate_label.text = _format_ground_plate_text()
	_plate_label.add_theme_font_size_override("font_size", 16 if highlighted else 13)
	_plate_label.add_theme_color_override("font_color", text_col)
	_plate_panel.z_index = 12 if highlighted else 2
	_plate_panel.reset_size()


func _process(delta: float) -> void:
	if is_picked:
		return
	_bob_time += delta
	if _mesh_instance != null:
		_mesh_instance.rotation.y += delta * 1.5
		_mesh_instance.position.y = 0.12 + sin(_bob_time * 3.0) * 0.04

	var cur_frame: int = Engine.get_process_frames()
	if _last_layout_frame != cur_frame:
		_last_layout_frame = cur_frame
		_update_all_screen_plates()


static func _update_all_screen_plates() -> void:
	if _active_items.is_empty():
		return
	var first_valid: GroundItem3D = null
	for it in _active_items:
		if is_instance_valid(it) and not it.is_picked:
			first_valid = it
			break
	if first_valid == null or first_valid.get_viewport() == null:
		return

	var vp: Viewport = first_valid.get_viewport()
	var cam: Camera3D = vp.get_camera_3d()
	if cam == null:
		return

	# Oculta placas de chão se uma janela modal bloqueante (Inventário / NPC) estiver aberta
	var modal_open: bool = false
	if first_valid.get_tree() != null:
		for m in first_valid.get_tree().get_nodes_in_group("blocking_modal"):
			if m is CanvasItem and (m as CanvasItem).visible:
				modal_open = true
				break

	var vp_size: Vector2 = vp.get_visible_rect().size
	var entries: Array[Dictionary] = []

	for it in _active_items:
		if not is_instance_valid(it) or it.is_picked:
			continue
		if not is_instance_valid(it._plate_panel):
			it._create_screen_plate()
		if not is_instance_valid(it._plate_panel):
			continue
		if modal_open or not it.is_visible_in_tree():
			it._plate_panel.visible = false
			continue
		var world_anchor: Vector3 = it.global_position + Vector3(0.0, 0.42, 0.0)
		if cam.is_position_behind(world_anchor):
			it._plate_panel.visible = false
			continue

		var screen_pt: Vector2 = cam.unproject_position(world_anchor)
		if screen_pt.x < -120.0 or screen_pt.x > vp_size.x + 120.0 or screen_pt.y < -120.0 or screen_pt.y > vp_size.y + 120.0:
			it._plate_panel.visible = false
			continue

		it._plate_panel.visible = true
		it._plate_panel.reset_size()
		var sz: Vector2 = it._plate_panel.size
		if sz.x < 40.0:
			sz = it._plate_panel.get_combined_minimum_size()
		entries.append({
			"item": it,
			"world_pos": it.global_position,
			"anchor_x": screen_pt.x,
			"anchor_y": screen_pt.y,
			"size": sz,
			"order": it._spawn_order
		})

	if entries.is_empty():
		return

	# Agrupa itens próximos no chão para alinhar o centro X da pilha (estilo Last Epoch / PoE 2)
	for i in range(entries.size()):
		var sum_x: float = float(entries[i]["anchor_x"])
		var count_x: int = 1
		var wi: Vector3 = entries[i]["world_pos"]
		for j in range(entries.size()):
			if i == j:
				continue
			var wj: Vector3 = entries[j]["world_pos"]
			if wi.distance_to(wj) <= 2.1:
				sum_x += float(entries[j]["anchor_x"])
				count_x += 1
		entries[i]["cluster_x"] = sum_x / float(count_x)

	# Ordena de baixo para cima na tela (ou por ordem de spawn para estabilidade quando no mesmo ponto)
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var dy: float = float(a["anchor_y"]) - float(b["anchor_y"])
		if absf(dy) > 18.0:
			return dy > 0.0 # Mais embaixo na tela posiciona primeiro (base da pilha)
		return int(a["order"]) < int(b["order"])
	)

	# Posiciona cada placa sem nenhuma sobreposição (empilhando para cima com espaçamento de 3px)
	var placed_rects: Array[Rect2] = []
	var gap_y: float = 3.0

	for e in entries:
		var it: GroundItem3D = e["item"]
		var sz: Vector2 = e["size"]
		var cx: float = float(e["cluster_x"])
		var pos_x: float = clampf(cx - sz.x * 0.5, 6.0, maxf(6.0, vp_size.x - sz.x - 6.0))
		var pos_y: float = float(e["anchor_y"]) - sz.y

		var candidate := Rect2(Vector2(pos_x, pos_y), sz)
		var safety: int = 0
		while safety < 32:
			var overlapped: bool = false
			for r in placed_rects:
				# Verifica colisão horizontal (com margem de 4px) e vertical (com gap de 3px)
				if candidate.position.x < r.end.x + 4.0 and candidate.end.x + 4.0 > r.position.x:
					if candidate.position.y < r.end.y + gap_y and candidate.end.y + gap_y > r.position.y:
						candidate.position.y = r.position.y - sz.y - gap_y
						overlapped = true
						break
			if not overlapped:
				break
			safety += 1

		candidate.position.y = maxf(6.0, candidate.position.y)
		placed_rects.append(candidate)
		it._plate_panel.position = candidate.position


## Chamado ao apertar [E] ou clicar com o Mouse sobre a placa do item
func attempt_pickup(_player: Node = null) -> bool:
	if is_picked or item == null:
		return false
	var scene = get_tree().current_scene
	if scene == null or not ("backpack" in scene):
		scene = find_parent("ARPGGame")
		if scene == null:
			scene = find_parent("Arena")
	if scene == null or not ("backpack" in scene):
		return false

	var backpack: SpatialInventoryGrid = scene.backpack as SpatialInventoryGrid
	if backpack == null:
		return false

	if backpack.auto_add_item(item):
		is_picked = true
		if _hovered_item == self:
			_hovered_item = null
		if is_instance_valid(_plate_panel):
			_plate_panel.queue_free()
		picked_up.emit(item)
		if scene != null:
			var vfx_root: Node3D = scene as Node3D
			if vfx_root != null:
				VFX.impact(vfx_root, global_position + Vector3.UP * 0.35, 0.65)
		if scene.has_method("notify_item_pickup"):
			scene.call("notify_item_pickup", item)
		_refresh_all_highlights()
		queue_free()
		return true
	else:
		if scene.has_method("notify_inventory_full"):
			scene.call("notify_inventory_full")
		return false
