extends Node3D
class_name TownInteractable3D
## Objeto 3D interativo orientado a objetos para a Vila e Zonas (Diablo 2 / PoE / Grim Dawn):
## - "stash": Baú Pessoal (Stash)
## - "vendor_physical": Vendedor de Itens Físicos (Ferreiro)
## - "vendor_magic": Vendedor de Itens Mágicos (Arcanista)
## - "identifier_respec": Identificador de Itens & Resetar Build (Sábio)
## - "waypoint": Waypoint Ancestral (Teleporte entre Vila e Zonas descobertas)

signal interaction_requested(station_id: String, station_title: String)

@export var station_id: String = "stash"
@export var station_title: String = "Baú Pessoal"
@export var station_subtitle: String = "[E] Abrir Baú"
@export var interaction_radius: float = 2.75

var _label_title: Label3D
var _label_prompt: Label3D
var _highlight_ring: MeshInstance3D
var _player_in_range: bool = false
var _pulse_time: float = 0.0


func configure(id_value: String, title_value: String, subtitle_value: String, pos: Vector3, yaw_deg: float = 0.0) -> void:
	station_id = id_value
	station_title = title_value
	station_subtitle = subtitle_value
	position = pos
	rotation_degrees.y = yaw_deg
	_build_visuals()


func _build_visuals() -> void:
	for child in get_children():
		child.queue_free()

	var accent_color := _get_accent_color()

	# Anel de destaque no chão
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 1.25
	ring_mesh.bottom_radius = 1.30
	ring_mesh.height = 0.03
	ring_mesh.radial_segments = 24
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = Color(accent_color.r, accent_color.g, accent_color.b, 0.35)
	ring_mat.emission_enabled = true
	ring_mat.emission = accent_color
	ring_mat.emission_energy_multiplier = 0.9
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_highlight_ring = MeshInstance3D.new()
	_highlight_ring.mesh = ring_mesh
	_highlight_ring.material_override = ring_mat
	_highlight_ring.position = Vector3(0.0, 0.018, 0.0)
	_highlight_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight_ring)

	match station_id:
		"stash":
			_build_stash_chest()
		"vendor_physical":
			_build_npc_figure(Color(0.28, 0.16, 0.12), Color(0.55, 0.42, 0.25), true, false)
		"vendor_magic":
			_build_npc_figure(Color(0.14, 0.18, 0.36), Color(0.38, 0.68, 0.98), false, true)
		"identifier_respec":
			_build_npc_figure(Color(0.24, 0.22, 0.20), Color(0.92, 0.75, 0.36), false, false)
		"waypoint":
			_build_waypoint_pad()

	var label_height: float = 1.75 if station_id == "stash" or station_id == "waypoint" else 2.38

	_label_title = Label3D.new()
	_label_title.text = station_title
	_label_title.font_size = 34
	_label_title.outline_size = 10
	_label_title.modulate = accent_color.lightened(0.22)
	_label_title.outline_modulate = Color(0.03, 0.03, 0.04, 0.96)
	_label_title.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_title.no_depth_test = true
	_label_title.pixel_size = 0.0045
	_label_title.position = Vector3(0.0, label_height, 0.0)
	add_child(_label_title)

	_label_prompt = Label3D.new()
	_label_prompt.text = station_subtitle
	_label_prompt.font_size = 26
	_label_prompt.outline_size = 8
	_label_prompt.modulate = Color(0.95, 0.92, 0.84, 0.95)
	_label_prompt.outline_modulate = Color(0.03, 0.03, 0.04, 0.96)
	_label_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_prompt.no_depth_test = true
	_label_prompt.pixel_size = 0.0042
	_label_prompt.position = Vector3(0.0, label_height - 0.24, 0.0)
	_label_prompt.visible = false
	add_child(_label_prompt)


func _get_accent_color() -> Color:
	match station_id:
		"stash":
			return Color(0.92, 0.74, 0.32)
		"vendor_physical":
			return Color(0.92, 0.52, 0.28)
		"vendor_magic":
			return Color(0.42, 0.74, 0.98)
		"identifier_respec":
			return Color(0.88, 0.82, 0.58)
		"waypoint":
			return Color(0.36, 0.82, 0.98)
	return Color(0.86, 0.72, 0.38)


func _build_stash_chest() -> void:
	# Pedestal de pedra + Baú de madeira escura reforçado com ferro e fecho dourado
	_add_box(Vector3(0.0, 0.14, 0.0), Vector3(1.55, 0.28, 1.10), Color(0.18, 0.18, 0.21))
	_add_box(Vector3(0.0, 0.52, 0.0), Vector3(1.24, 0.52, 0.78), Color(0.24, 0.14, 0.09), 0.85)
	_add_box(Vector3(0.0, 0.84, 0.0), Vector3(1.28, 0.22, 0.82), Color(0.28, 0.16, 0.10), 0.82)
	# Tiras de ferro e fecho de bronze dourado
	_add_box(Vector3(-0.42, 0.58, 0.0), Vector3(0.10, 0.68, 0.84), Color(0.22, 0.24, 0.28), 0.45)
	_add_box(Vector3(0.42, 0.58, 0.0), Vector3(0.10, 0.68, 0.84), Color(0.22, 0.24, 0.28), 0.45)
	_add_box(Vector3(0.0, 0.68, 0.41), Vector3(0.22, 0.26, 0.08), Color(0.84, 0.64, 0.24), 0.35, 0.4)


func _build_npc_figure(robe_color: Color, trim_color: Color, is_blacksmith: bool, is_mage: bool) -> void:
	# Silhueta low-poly gótica do NPC sobre base de pedra + bancada temática
	_add_cyl(Vector3(0.0, 0.08, 0.0), 0.62, 0.16, Color(0.17, 0.17, 0.20), 12)
	# Manto/Corpo
	_add_cyl(Vector3(0.0, 0.72, 0.0), 0.36, 1.15, robe_color, 8)
	# Ombreiras / Manto superior
	_add_box(Vector3(0.0, 1.24, 0.0), Vector3(0.82, 0.28, 0.48), trim_color.darkened(0.25), 0.65)
	# Cabeça + Capuz Gótico
	_add_cyl(Vector3(0.0, 1.56, 0.0), 0.21, 0.34, Color(0.76, 0.64, 0.54), 8)
	_add_Box_rot(Vector3(0.0, 1.66, -0.04), Vector3(0.46, 0.38, 0.48), robe_color.darkened(0.2), Vector3(0.15, 0.0, 0.0))

	if is_blacksmith:
		# Bigorna de ferro ao lado do Ferreiro
		_add_box(Vector3(0.88, 0.28, 0.25), Vector3(0.52, 0.56, 0.42), Color(0.22, 0.15, 0.10))
		_add_box(Vector3(0.88, 0.66, 0.25), Vector3(0.78, 0.24, 0.36), Color(0.26, 0.28, 0.32), 0.42)
	elif is_mage:
		# Pedestal com orbe arcano azulado
		_add_cyl(Vector3(0.85, 0.48, 0.25), 0.22, 0.96, Color(0.20, 0.21, 0.26), 8)
		_add_cyl(Vector3(0.85, 1.14, 0.25), 0.18, 0.28, Color(0.32, 0.72, 1.0), 10, 0.2, 2.2)
	else:
		# Atril do Sábio Identificador (Deckard Cain style) com Tomo Dourado
		_add_cyl(Vector3(0.82, 0.48, 0.28), 0.16, 0.96, Color(0.26, 0.17, 0.11), 8)
		_add_Box_rot(Vector3(0.82, 1.02, 0.28), Vector3(0.48, 0.10, 0.38), Color(0.86, 0.68, 0.26), Vector3(0.45, 0.0, 0.0))


func _build_waypoint_pad() -> void:
	_add_cyl(Vector3(0.0, 0.05, 0.0), 1.38, 0.10, Color(0.18, 0.19, 0.23), 16)
	_add_cyl(Vector3(0.0, 0.10, 0.0), 1.08, 0.08, Color(0.25, 0.27, 0.32), 16)
	_add_cyl(Vector3(0.0, 0.145, 0.0), 0.68, 0.04, Color(0.28, 0.78, 0.98), 16, 0.2, 2.4)


func _add_box(pos: Vector3, size: Vector3, col: Color, rough: float = 0.92, emission: float = 0.0) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = _make_mat(col, rough, emission)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _add_Box_rot(pos: Vector3, size: Vector3, col: Color, rot: Vector3) -> MeshInstance3D:
	var mi := _add_box(pos, size, col)
	mi.rotation = rot
	return mi


func _add_cyl(pos: Vector3, rad: float, h: float, col: Color, segs: int = 10, rough: float = 0.90, emission: float = 0.0) -> MeshInstance3D:
	var m := CylinderMesh.new()
	m.top_radius = rad
	m.bottom_radius = rad
	m.height = h
	m.radial_segments = segs
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.material_override = _make_mat(col, rough, emission)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
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
	if _label_prompt != null:
		_label_prompt.visible = _player_in_range
	if _highlight_ring != null:
		_pulse_time += delta * 4.0
		var scale_f: float = (1.06 + 0.05 * sin(_pulse_time)) if _player_in_range else 1.0
		_highlight_ring.scale = Vector3(scale_f, 1.0, scale_f)
	return _player_in_range


func is_player_in_range() -> bool:
	return _player_in_range


func trigger_interaction() -> void:
	interaction_requested.emit(station_id, station_title)
