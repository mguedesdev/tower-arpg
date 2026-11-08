extends Node3D
class_name BeltLantern3D
## Lanterna Medieval Presa ao Cinto do Personagem — Iluminação Dinâmica ARPG
## • Só pode existir e emitir luz se um cinto estiver equipado no slot correspondente (EquipmentSlot.BELT).
## • Durante o dia em áreas claras, permanece apagada.
## • À noite ou em masmorras/cavernas/zonas subterrâneas, acende automaticamente com luz âmbar suave (3 a 5m).
## • Se o cinto for removido, a lanterna e sua luz desaparecem imediatamente.
## • Fixada à cintura/osso 'hips' do herói, acompanhando idle, caminhada, corrida e golpes de combate.

signal lantern_state_changed(is_lit: bool, has_belt: bool)

const DEFAULT_AMBER_COLOR := Color(1.0, 0.76, 0.44, 1.0)
const DEFAULT_LIGHT_RANGE := 7.5
const DEFAULT_MAX_ENERGY := 1.60
const DEFAULT_ATTENUATION := 0.92

@export var shadow_enabled: bool = true

var has_belt_equipped: bool = false
var is_dark_zone: bool = false
var is_night_time: bool = false
var current_light_energy: float = 0.0
var target_light_energy: float = 0.0

var _player_ref: CharacterBody3D = null
var _equipment_ref: CharacterEquipment = null
var _day_night_ref: DayNightCycleHUD = null

var _lantern_model_root: Node3D = null
var _candle_core_mesh: MeshInstance3D = null
var _candle_material: StandardMaterial3D = null
var _omni_light: OmniLight3D = null
var _flicker_time: float = 0.0
var _bone_attachment: BoneAttachment3D = null


func _ready() -> void:
	name = "BeltLantern3D"
	_build_lantern_visual()
	_update_visibility_and_lighting(true)


func setup_on_character(player: CharacterBody3D) -> void:
	_player_ref = player
	if _player_ref == null:
		return

	if get_parent() != null:
		get_parent().remove_child(self)

	var visual: Node3D = _player_ref.get_node_or_null("Visual") as Node3D
	if visual == null:
		_player_ref.add_child(self)
		position = Vector3(0.28, 0.76, 0.06)
		return

	# Tenta encontrar o Skeleton3D do modelo importado do cavaleiro
	var skel: Skeleton3D = visual.find_child("Skeleton3D", true, false) as Skeleton3D
	if skel != null and skel.get_bone_count() > 0:
		var bone_idx: int = skel.find_bone("hips")
		if bone_idx < 0:
			bone_idx = skel.find_bone("spine")
		if bone_idx >= 0:
			_bone_attachment = BoneAttachment3D.new()
			_bone_attachment.name = "LanternHipsAttachment"
			_bone_attachment.bone_name = skel.get_bone_name(bone_idx)
			skel.add_child(_bone_attachment)
			_bone_attachment.add_child(self)
			# Posição anatômica lateral direita na cintura/cinto
			position = Vector3(0.26, 0.06, 0.02)
			rotation = Vector3(0.0, 0.15, -0.05)
			return

	# Fallback caso rode com o placeholder sem esqueleto
	visual.add_child(self)
	position = Vector3(0.28, 0.76, 0.06)


func bind_equipment(p_equipment: CharacterEquipment) -> void:
	if _equipment_ref != null and _equipment_ref.equipment_changed.is_connected(_on_equipment_changed):
		_equipment_ref.equipment_changed.disconnect(_on_equipment_changed)

	_equipment_ref = p_equipment
	if _equipment_ref != null:
		_equipment_ref.equipment_changed.connect(_on_equipment_changed)
		var initial_belt = _equipment_ref.get_equipped_item(ItemDefinition.EquipmentSlot.BELT)
		set_belt_equipped(initial_belt != null, true)
	else:
		set_belt_equipped(false, true)


func bind_day_night(p_hud: DayNightCycleHUD) -> void:
	if _day_night_ref != null and _day_night_ref.phase_changed.is_connected(_on_day_night_phase_changed):
		_day_night_ref.phase_changed.disconnect(_on_day_night_phase_changed)

	_day_night_ref = p_hud
	if _day_night_ref != null:
		_day_night_ref.phase_changed.connect(_on_day_night_phase_changed)
		_check_day_night_state(_day_night_ref.get_current_phase_id())
	else:
		is_night_time = false
		_update_visibility_and_lighting(false)


func set_zone_context(zone_id: String) -> void:
	# Criptas, masmorras, minas e cavernas subterrâneas são ambientes escuros
	is_dark_zone = (zone_id == "zone_3_crypt" or zone_id == "zone_4_mines" or zone_id.contains("crypt") or zone_id.contains("cave") or zone_id.contains("dungeon") or zone_id.contains("mine"))
	_update_visibility_and_lighting(false)


func set_belt_equipped(equipped: bool, immediate: bool = false) -> void:
	if has_belt_equipped == equipped:
		return
	has_belt_equipped = equipped
	if not has_belt_equipped:
		# REGRA OBRIGATÓRIA: Se remover o cinto, desaparece e apaga IMEDIATAMENTE!
		current_light_energy = 0.0
		target_light_energy = 0.0
		if _omni_light != null:
			_omni_light.light_energy = 0.0
		if _candle_material != null:
			_candle_material.emission_energy_multiplier = 0.0
		visible = false
		lantern_state_changed.emit(false, false)
	else:
		visible = true
		_update_visibility_and_lighting(immediate)
		lantern_state_changed.emit(target_light_energy > 0.01, true)


func is_lantern_lit() -> bool:
	return has_belt_equipped and (current_light_energy > 0.05 or target_light_energy > 0.05)


func _on_equipment_changed(slot: ItemDefinition.EquipmentSlot, item: ItemInstance) -> void:
	if slot == ItemDefinition.EquipmentSlot.BELT:
		set_belt_equipped(item != null)


func _on_day_night_phase_changed(phase_id: String) -> void:
	_check_day_night_state(phase_id)


func _check_day_night_state(phase_id: String) -> void:
	is_night_time = (phase_id == "night")
	_update_visibility_and_lighting(false)


func _update_visibility_and_lighting(immediate: bool) -> void:
	if not has_belt_equipped:
		target_light_energy = 0.0
		current_light_energy = 0.0
		visible = false
		if _omni_light != null:
			_omni_light.light_energy = 0.0
		if _candle_material != null:
			_candle_material.emission_energy_multiplier = 0.0
		return

	# Com cinto equipado: o modelo da lanterna fica visível preso à cintura
	visible = true

	# Deve acender se for noite OU se estiver em caverna/masmorra escura
	var should_illuminate: bool = (is_night_time or is_dark_zone)
	target_light_energy = DEFAULT_MAX_ENERGY if should_illuminate else 0.0

	if immediate:
		current_light_energy = target_light_energy
		if _omni_light != null:
			_omni_light.light_energy = current_light_energy
		if _candle_material != null:
			_candle_material.emission_energy_multiplier = (1.4 if current_light_energy > 0.05 else 0.0)


func _process(delta: float) -> void:
	if not has_belt_equipped:
		if visible:
			visible = false
		if _omni_light != null and _omni_light.light_energy > 0.0:
			_omni_light.light_energy = 0.0
		return

	_flicker_time += delta

	# Reavalia dinamicamente iluminação por ciclo solar ou zona escura
	var dark_underground := false
	if _day_night_ref != null and _day_night_ref.has_method("is_underground"):
		dark_underground = _day_night_ref.is_underground()
	var effective_dark := is_dark_zone or dark_underground

	if _day_night_ref != null and not effective_dark:
		var cur_phase: String = _day_night_ref.get_current_phase_id()
		var night_now: bool = (cur_phase == "night")
		if night_now != is_night_time:
			is_night_time = night_now

	var should_illuminate: bool = (is_night_time or effective_dark)
	target_light_energy = DEFAULT_MAX_ENERGY if should_illuminate else 0.0

	# Transição suave de intensidade luminosa (fade in / fade out sem estalo)
	if not is_equal_approx(current_light_energy, target_light_energy):
		current_light_energy = move_toward(current_light_energy, target_light_energy, delta * 3.2)

	# Oscilação natural suave e orgânica da chama da vela/lanterna (± 4%)
	var flicker: float = 1.0
	if current_light_energy > 0.02:
		flicker = 1.0 + 0.035 * sin(_flicker_time * 6.5) + 0.018 * cos(_flicker_time * 11.2)

	if _omni_light != null:
		_omni_light.light_energy = current_light_energy * flicker

	if _candle_material != null:
		_candle_material.emission_energy_multiplier = (current_light_energy / DEFAULT_MAX_ENERGY) * 1.5 * flicker


# ============================================================================
# CONSTRUÇÃO DO MODELO PROCEDURAL LOW-POLY DA LANTERNA MEDIEVAL
# ============================================================================
func _build_lantern_visual() -> void:
	_lantern_model_root = Node3D.new()
	_lantern_model_root.name = "LanternModel"
	add_child(_lantern_model_root)

	var iron_mat := StandardMaterial3D.new()
	iron_mat.resource_name = "LanternIron"
	iron_mat.albedo_color = Color(0.18, 0.16, 0.19, 1.0)
	iron_mat.roughness = 0.85
	iron_mat.metallic = 0.35

	var bronze_mat := StandardMaterial3D.new()
	bronze_mat.resource_name = "LanternBronze"
	bronze_mat.albedo_color = Color(0.32, 0.25, 0.18, 1.0)
	bronze_mat.roughness = 0.70
	bronze_mat.metallic = 0.45

	_candle_material = StandardMaterial3D.new()
	_candle_material.resource_name = "LanternCandleFlame"
	_candle_material.albedo_color = Color(1.0, 0.88, 0.60, 1.0)
	_candle_material.emission_enabled = true
	_candle_material.emission = Color(1.0, 0.70, 0.30, 1.0)
	_candle_material.emission_energy_multiplier = 0.0

	# 1. Alça / Gancho de engate no cinto
	var ring_mesh := CylinderMesh.new()
	ring_mesh.top_radius = 0.032
	ring_mesh.bottom_radius = 0.032
	ring_mesh.height = 0.012
	ring_mesh.radial_segments = 8
	var ring_node := MeshInstance3D.new()
	ring_node.name = "BeltHook"
	ring_node.mesh = ring_mesh
	ring_node.material_override = iron_mat
	ring_node.position = Vector3(0.0, 0.13, 0.0)
	ring_node.rotation.x = PI * 0.5
	ring_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern_model_root.add_child(ring_node)

	# 2. Tampa cônica superior da lanterna
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.015
	cap_mesh.bottom_radius = 0.075
	cap_mesh.height = 0.045
	cap_mesh.radial_segments = 6
	var cap_node := MeshInstance3D.new()
	cap_node.name = "LanternCap"
	cap_node.mesh = cap_mesh
	cap_node.material_override = bronze_mat
	cap_node.position = Vector3(0.0, 0.095, 0.0)
	cap_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern_model_root.add_child(cap_node)

	# 3. Base hexagonal inferior
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.072
	base_mesh.bottom_radius = 0.065
	base_mesh.height = 0.025
	base_mesh.radial_segments = 6
	var base_node := MeshInstance3D.new()
	base_node.name = "LanternBase"
	base_node.mesh = base_mesh
	base_node.material_override = bronze_mat
	base_node.position = Vector3(0.0, -0.075, 0.0)
	base_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern_model_root.add_child(base_node)

	# 4. Barras verticais da gaiola de ferro (4 cantos)
	for i in range(4):
		var bar_mesh := BoxMesh.new()
		bar_mesh.size = Vector3(0.012, 0.145, 0.012)
		var bar_node := MeshInstance3D.new()
		bar_node.name = "Strut_%d" % i
		bar_node.mesh = bar_mesh
		bar_node.material_override = iron_mat
		var ang: float = float(i) * (PI * 0.5) + (PI * 0.25)
		bar_node.position = Vector3(cos(ang) * 0.055, 0.01, sin(ang) * 0.055)
		bar_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_lantern_model_root.add_child(bar_node)

	# 5. Núcleo interno emissivo (Vela / Brasa)
	var core_mesh := CylinderMesh.new()
	core_mesh.top_radius = 0.028
	core_mesh.bottom_radius = 0.034
	core_mesh.height = 0.075
	core_mesh.radial_segments = 6
	_candle_core_mesh = MeshInstance3D.new()
	_candle_core_mesh.name = "CandleCore"
	_candle_core_mesh.mesh = core_mesh
	_candle_core_mesh.material_override = _candle_material
	_candle_core_mesh.position = Vector3(0.0, 0.005, 0.0)
	_candle_core_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lantern_model_root.add_child(_candle_core_mesh)

	# 6. Luz Radial Dinâmica (OmniLight3D)
	_omni_light = OmniLight3D.new()
	_omni_light.name = "LanternLight"
	_omni_light.position = Vector3(0.06, -0.02, 0.08)
	_omni_light.light_color = DEFAULT_AMBER_COLOR
	_omni_light.light_energy = 0.0
	_omni_light.omni_range = DEFAULT_LIGHT_RANGE
	_omni_light.omni_attenuation = DEFAULT_ATTENUATION
	_omni_light.shadow_enabled = shadow_enabled
	_omni_light.shadow_bias = 0.03
	_omni_light.shadow_normal_bias = 1.0
	_omni_light.shadow_blur = 0.0
	_lantern_model_root.add_child(_omni_light)
