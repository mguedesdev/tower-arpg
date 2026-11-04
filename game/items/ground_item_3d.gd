extends Area3D
class_name GroundItem3D
## Drop 3D primitivo no chão (bloco/cilindro + feixe de luz vertical + placa de texto flutuante).
## Estilo clássico Diablo 2 / Path of Exile.

signal picked_up(item: ItemInstance)

var item: ItemInstance
var is_picked: bool = false
var _mesh_instance: MeshInstance3D
var _light_beam: MeshInstance3D
var _label_3d: Label3D
var _bob_time: float = 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detecta o Player
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)


func setup_drop(p_item: ItemInstance, spawn_pos: Vector3) -> void:
	item = p_item
	global_position = spawn_pos + Vector3(0.0, 0.12, 0.0)

	var r_col: Color = item.get_rarity_color() if item != null else Color.WHITE

	# 1. Geometria 3D Primitiva (Bloco para armas/armaduras, cilindro para anéis/amuletos)
	_mesh_instance = MeshInstance3D.new()
	var is_round: bool = item != null and (item.definition.category == ItemDefinition.ItemCategory.RING or item.definition.category == ItemDefinition.ItemCategory.AMULET or item.definition.category == ItemDefinition.ItemCategory.CONSUMABLE)
	if is_round:
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.18
		cyl.bottom_radius = 0.18
		cyl.height = 0.12
		_mesh_instance.mesh = cyl
	else:
		var box := BoxMesh.new()
		var sz: Vector2i = item.definition.grid_size if item != null and item.definition != null else Vector2i(2, 3)
		box.size = Vector3(float(sz.x) * 0.18, 0.08, float(sz.y) * 0.22)
		_mesh_instance.mesh = box

	var mat := StandardMaterial3D.new()
	mat.albedo_color = r_col
	mat.metallic = 0.5
	mat.roughness = 0.3
	mat.emission_enabled = true
	mat.emission = r_col * 0.4
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)

	# 2. Feixe de Luz Vertical (Pilar de raridade em itens Mágicos, Raros e Únicos)
	if item != null and item.rarity != ItemInstance.ItemRarity.NORMAL:
		_light_beam = MeshInstance3D.new()
		var beam_mesh := CylinderMesh.new()
		beam_mesh.top_radius = 0.06
		beam_mesh.bottom_radius = 0.12
		beam_mesh.height = 2.4
		_light_beam.mesh = beam_mesh
		_light_beam.position = Vector3(0.0, 1.2, 0.0)

		var beam_mat := StandardMaterial3D.new()
		beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		beam_mat.albedo_color = Color(r_col.r, r_col.g, r_col.b, 0.28)
		beam_mat.emission_enabled = true
		beam_mat.emission = r_col * 0.8
		beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_light_beam.material_override = beam_mat
		add_child(_light_beam)

	# 3. Placa de Texto Flutuante Estilo Diablo 2 / Path of Exile (Grande, Nítida e com Fundo Escuro)
	_label_3d = Label3D.new()
	_label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_3d.no_depth_test = true
	_label_3d.shaded = false
	_label_3d.render_priority = 25
	_label_3d.outline_render_priority = 24
	_label_3d.pixel_size = 0.010
	_label_3d.font_size = 30
	_label_3d.outline_size = 10
	_label_3d.outline_modulate = Color(0.01, 0.01, 0.02, 1.0)
	_label_3d.modulate = r_col.lightened(0.40)
	_label_3d.background_color = Color(0.035, 0.03, 0.045, 0.92)
	_label_3d.background_render_priority = 23
	var prefix: String = "✦ " if item != null and item.rarity != ItemInstance.ItemRarity.NORMAL else ""
	_label_3d.text = "  %s%s  " % [prefix, item.get_display_name() if item != null else "Item"]
	_label_3d.position = Vector3(0.0, 0.75, 0.0)
	add_child(_label_3d)

	# Colisor esférico para detecção do jogador
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.35
	shape.shape = sphere
	add_child(shape)


func _process(delta: float) -> void:
	_bob_time += delta
	if _mesh_instance != null:
		_mesh_instance.rotation.y += delta * 1.5
		_mesh_instance.position.y = 0.12 + sin(_bob_time * 3.0) * 0.04
	if _label_3d != null:
		_label_3d.position.y = 0.75 + sin(_bob_time * 3.0) * 0.04


func _on_body_entered(body: Node3D) -> void:
	if is_picked or not (body is TowerPlayer):
		return
	attempt_pickup(body as TowerPlayer)


func attempt_pickup(player: TowerPlayer) -> bool:
	if is_picked or item == null:
		return false
	var main_scene = get_tree().current_scene
	if main_scene == null or not ("backpack" in main_scene):
		return false

	var backpack: SpatialInventoryGrid = main_scene.backpack as SpatialInventoryGrid
	if backpack == null:
		return false

	if backpack.auto_add_item(item):
		is_picked = true
		picked_up.emit(item)
		if main_scene.has_method("notify_item_pickup"):
			main_scene.call("notify_item_pickup", item)
		queue_free()
		return true
	else:
		if main_scene.has_method("notify_inventory_full"):
			main_scene.call("notify_inventory_full")
		return false
