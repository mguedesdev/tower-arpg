extends Node3D
class_name ZonePortal3D
## Portão / Arco de Pedra 3D que conecta os caminhos entre a Vila e as Zonas do ARPG.
## Quando o jogador atravessa o portão (ou aperta E próximo a ele), transiciona para a área seguinte.

signal zone_transition_requested(target_zone_id: String, origin_zone_id: String)

@export var origin_zone_id: String = "town"
@export var target_zone_id: String = "zone_1_road"
@export var destination_label: String = "Estrada Profanada (Nv. 1)"
@export var is_return_gate: bool = false
@export var trigger_radius: float = 1.95

var _grace_timer: float = 1.35
var _label_dest: Label3D


func configure(from_zone: String, to_zone: String, label_text: String, pos: Vector3, return_gate: bool = false) -> void:
	origin_zone_id = from_zone
	target_zone_id = to_zone
	destination_label = label_text
	is_return_gate = return_gate
	position = pos
	_grace_timer = 1.35
	_build_gate_visuals()


func _build_gate_visuals() -> void:
	for child in get_children():
		child.queue_free()

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

	var prefix: String = "⬅ VOLTAR: " if is_return_gate else "➔ AVANÇAR: "
	_label_dest = Label3D.new()
	_label_dest.text = prefix + destination_label + "\n(Atravesse o Portão)"
	_label_dest.font_size = 34
	_label_dest.outline_size = 10
	_label_dest.modulate = accent.lightened(0.28)
	_label_dest.outline_modulate = Color(0.03, 0.03, 0.04, 0.96)
	_label_dest.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label_dest.no_depth_test = true
	_label_dest.pixel_size = 0.0046
	_label_dest.position = Vector3(0.0, 4.15, 0.0)
	add_child(_label_dest)


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
