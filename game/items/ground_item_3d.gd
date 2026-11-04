extends Area3D
class_name GroundItem3D
## Drop 3D no chão (bloco/cilindro + feixe de luz vertical + placa de texto flutuante).
## Estilo clássico Diablo 2 / Path of Exile. Coleta exclusivamente manual via tecla [E].

signal picked_up(item: ItemInstance)

const VFX = preload("res://scripts/vfx/tower_vfx_spawner.gd")

static var _mat_cache: Dictionary = {}
static var _beam_mat_cache: Dictionary = {}
static var _cyl_mesh: CylinderMesh = null
static var _beam_mesh: CylinderMesh = null
static var _box_meshes: Dictionary = {}

var item: ItemInstance
var is_picked: bool = false
var _mesh_instance: MeshInstance3D
var _light_beam: MeshInstance3D
var _label_3d: Label3D
var _bob_time: float = 0.0


func _ready() -> void:
	# Desativa detecção automática de colisão física com o jogador:
	# A coleta é EXCLUSIVA via tecla [E], evitando travamentos ou coletas indesejadas no meio da luta.
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = false


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

	# Material compartilhado em cache por raridade
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
			_beam_mesh.top_radius = 0.06
			_beam_mesh.bottom_radius = 0.12
			_beam_mesh.height = 2.4
		_light_beam.mesh = _beam_mesh
		_light_beam.position = Vector3(0.0, 1.2, 0.0)

		if not _beam_mat_cache.has(mat_key):
			var beam_mat := StandardMaterial3D.new()
			beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			beam_mat.albedo_color = Color(r_col.r, r_col.g, r_col.b, 0.28)
			beam_mat.emission_enabled = true
			beam_mat.emission = r_col * 0.8
			beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			_beam_mat_cache[mat_key] = beam_mat
		_light_beam.material_override = _beam_mat_cache[mat_key]
		add_child(_light_beam)

	# 3. Placa de Texto Flutuante Estilo Diablo 2 / Path of Exile
	_label_3d = Label3D.new()
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_3d.no_depth_test = true
	_label_3d.shaded = false
	_label_3d.render_priority = 25
	_label_3d.outline_render_priority = 24
	_label_3d.pixel_size = 0.010
	_label_3d.font_size = 32
	_label_3d.outline_size = 12
	_label_3d.outline_modulate = Color(0.01, 0.01, 0.02, 1.0)
	_label_3d.modulate = r_col.lightened(0.40)
	var prefix: String = "✦ " if item != null and item.rarity != ItemInstance.ItemRarity.NORMAL else ""
	_label_3d.text = "[E]  %s%s" % [prefix, item.get_display_name() if item != null else "Item"]
	_label_3d.position = Vector3(0.0, 0.75, 0.0)
	add_child(_label_3d)


func _process(delta: float) -> void:
	if is_picked:
		return
	_bob_time += delta
	if _mesh_instance != null:
		_mesh_instance.rotation.y += delta * 1.5
		_mesh_instance.position.y = 0.12 + sin(_bob_time * 3.0) * 0.04
	if _label_3d != null:
		_label_3d.position.y = 0.75 + sin(_bob_time * 3.0) * 0.04


var _is_in_range: bool = false


func set_in_pickup_range(in_range: bool) -> void:
	if _is_in_range == in_range:
		return
	_is_in_range = in_range
	if _label_3d != null:
		var r_col: Color = item.get_rarity_color() if item != null else Color.WHITE
		if in_range:
			_label_3d.modulate = Color(1.0, 0.95, 0.70)
			_label_3d.pixel_size = 0.012
			_label_3d.outline_size = 14
		else:
			_label_3d.modulate = r_col.lightened(0.40)
			_label_3d.pixel_size = 0.010
			_label_3d.outline_size = 12


## Chamado exclusivamente ao apertar [E] próximo ao item
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
		picked_up.emit(item)
		if scene != null:
			var vfx_root: Node3D = scene as Node3D
			if vfx_root != null:
				VFX.impact(vfx_root, global_position + Vector3.UP * 0.35, 0.65)
		if scene.has_method("notify_item_pickup"):
			scene.call("notify_item_pickup", item)
		queue_free()
		return true
	else:
		if scene.has_method("notify_inventory_full"):
			scene.call("notify_inventory_full")
		return false
