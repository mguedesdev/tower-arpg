extends Node3D
class_name BeltLantern3D

## ============================================================================
## ILUMINAÇÃO CIRCULAR DO PERSONAGEM — ARPG DARK FANTASY (GODOT 4)
## ============================================================================
## • Luz radial pura (OmniLight3D) em círculo ao redor do personagem.
## • Sem modelo 3D de lanterna, sem barras, ganchos ou oscilações de ossos.
## • Projeção circular limpa de 360° ao redor do herói (raio ~8.0m).
## • Ativa-se suavemente em ambientes escuros (noite, minas, cavernas, criptas).
## • Totalmente compatível com o ciclo de dia/noite e transição de zonas.

signal lantern_state_changed(is_lit: bool, has_belt: bool)

const DEFAULT_AMBER_COLOR := Color(1.0, 0.82, 0.54, 1.0)
const DEFAULT_LIGHT_RANGE := 8.0
const DEFAULT_MAX_ENERGY := 1.60
const DEFAULT_ATTENUATION := 1.0

@export var shadow_enabled: bool = false
@export var requires_belt: bool = false

var has_belt_equipped: bool = true
var is_dark_zone: bool = false
var is_night_time: bool = false
var current_light_energy: float = 0.0
var target_light_energy: float = 0.0

var _player_ref: CharacterBody3D = null
var _equipment_ref: CharacterEquipment = null
var _day_night_ref: DayNightCycleHUD = null

var _lantern_model_root: Node3D = null
var _candle_material: StandardMaterial3D = null
var _omni_light: OmniLight3D = null
var _flicker_time: float = 0.0


func _ready() -> void:
	name = "BeltLantern3D"
	_build_light()
	_update_lighting(true)


func setup_on_character(player: CharacterBody3D) -> void:
	_player_ref = player
	if _player_ref == null:
		return

	if get_parent() != null:
		get_parent().remove_child(self)

	# Fixada diretamente no personagem a 1.0m de altura, centralizada
	# para produzir uma iluminação perfeitamente circular de 360° no chão
	_player_ref.add_child(self)
	position = Vector3(0.0, 1.0, 0.0)
	rotation = Vector3.ZERO


func bind_equipment(p_equipment: CharacterEquipment) -> void:
	if _equipment_ref != null and _equipment_ref.equipment_changed.is_connected(_on_equipment_changed):
		_equipment_ref.equipment_changed.disconnect(_on_equipment_changed)

	_equipment_ref = p_equipment
	if _equipment_ref != null:
		_equipment_ref.equipment_changed.connect(_on_equipment_changed)
		var initial_belt = _equipment_ref.get_equipped_item(ItemDefinition.EquipmentSlot.BELT)
		set_belt_equipped(initial_belt != null, true)
	else:
		set_belt_equipped(true, true)


func bind_day_night(p_hud: DayNightCycleHUD) -> void:
	if _day_night_ref != null and _day_night_ref.phase_changed.is_connected(_on_day_night_phase_changed):
		_day_night_ref.phase_changed.disconnect(_on_day_night_phase_changed)

	_day_night_ref = p_hud
	if _day_night_ref != null:
		_day_night_ref.phase_changed.connect(_on_day_night_phase_changed)
		_check_day_night_state(_day_night_ref.get_current_phase_id())
	else:
		is_night_time = false
		_update_lighting(false)


func set_zone_context(zone_id: String) -> void:
	is_dark_zone = (zone_id == "zone_3_crypt" or zone_id == "zone_4_mines" or zone_id.contains("crypt") or zone_id.contains("cave") or zone_id.contains("dungeon") or zone_id.contains("mine"))
	_update_lighting(false)


func set_belt_equipped(equipped: bool, immediate: bool = false) -> void:
	has_belt_equipped = equipped
	if requires_belt and not has_belt_equipped:
		current_light_energy = 0.0
		target_light_energy = 0.0
		if _omni_light != null:
			_omni_light.light_energy = 0.0
		visible = false
		lantern_state_changed.emit(false, false)
	else:
		visible = true
		_update_lighting(immediate)
		lantern_state_changed.emit(target_light_energy > 0.01, has_belt_equipped)


func is_lantern_lit() -> bool:
	return (not requires_belt or has_belt_equipped) and (current_light_energy > 0.05 or target_light_energy > 0.05)


func _on_equipment_changed(slot: ItemDefinition.EquipmentSlot, item: ItemInstance) -> void:
	if slot == ItemDefinition.EquipmentSlot.BELT:
		set_belt_equipped(item != null)


func _on_day_night_phase_changed(phase_id: String) -> void:
	_check_day_night_state(phase_id)


func _check_day_night_state(phase_id: String) -> void:
	is_night_time = (phase_id == "night")
	_update_lighting(false)


func _update_lighting(immediate: bool) -> void:
	if requires_belt and not has_belt_equipped:
		target_light_energy = 0.0
		current_light_energy = 0.0
		visible = false
		if _omni_light != null:
			_omni_light.light_energy = 0.0
		return

	visible = true

	var should_illuminate: bool = (is_night_time or is_dark_zone)
	target_light_energy = DEFAULT_MAX_ENERGY if should_illuminate else 0.0

	if immediate:
		current_light_energy = target_light_energy
		if _omni_light != null:
			_omni_light.light_energy = current_light_energy
		if _candle_material != null:
			_candle_material.emission_energy_multiplier = (1.4 if current_light_energy > 0.05 else 0.0)


func _process(delta: float) -> void:
	if requires_belt and not has_belt_equipped:
		if visible:
			visible = false
		if _omni_light != null and _omni_light.light_energy > 0.0:
			_omni_light.light_energy = 0.0
		return

	_flicker_time += delta

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

	if not is_equal_approx(current_light_energy, target_light_energy):
		current_light_energy = move_toward(current_light_energy, target_light_energy, delta * 3.2)

	var flicker: float = 1.0
	if current_light_energy > 0.02:
		flicker = 1.0 + 0.02 * sin(_flicker_time * 5.0)

	if _omni_light != null:
		_omni_light.light_energy = current_light_energy * flicker

	if _candle_material != null:
		_candle_material.emission_energy_multiplier = (current_light_energy / DEFAULT_MAX_ENERGY) * 1.5 * flicker


func _build_light() -> void:
	_lantern_model_root = Node3D.new()
	_lantern_model_root.name = "LanternModel"
	add_child(_lantern_model_root)

	_candle_material = StandardMaterial3D.new()
	_candle_material.resource_name = "PlayerLightEmission"
	_candle_material.emission_enabled = true
	_candle_material.emission = DEFAULT_AMBER_COLOR

	_omni_light = OmniLight3D.new()
	_omni_light.name = "PlayerLight"
	_omni_light.position = Vector3.ZERO
	_omni_light.light_color = DEFAULT_AMBER_COLOR
	_omni_light.light_energy = 0.0
	_omni_light.omni_range = DEFAULT_LIGHT_RANGE
	_omni_light.omni_attenuation = DEFAULT_ATTENUATION
	_omni_light.shadow_enabled = shadow_enabled
	_lantern_model_root.add_child(_omni_light)
