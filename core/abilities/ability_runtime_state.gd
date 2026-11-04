extends RefCounted
class_name AbilityRuntimeState
## Estado mutável de uma habilidade durante UMA tentativa (run).
## Isolado da definição estática (AbilityDefinition) para impedir contaminação entre runs/instâncias.

const AbilityDef = preload("res://core/abilities/ability_definition.gd")

var definition: AbilityDefinition
var ability_id: String = ""
var active_behavior: int = AbilityDef.Behavior.STAB
var active_display_name: String = "Estocada"
var active_transformation_id: String = ""

var damage_multiplier_bonus: float = 0.0
var behavior_damage_multiplier: float = 1.0
var behavior_cooldown_override: float = -1.0
var behavior_radius_override: float = -1.0
var behavior_half_angle_override: float = -1.0
var behavior_corridor_width_override: float = -1.0
var behavior_max_targets_override: int = -1

var cooldown_multiplier: float = 1.0
var area_multiplier: float = 1.0
var extra_targets: int = 0
var extra_strikes: int = 0
var active_tags: Array[String] = []
var special_modifiers: Dictionary = {}


func _init(p_definition: AbilityDefinition = null) -> void:
	setup_from_definition(p_definition)


func setup_from_definition(p_definition: AbilityDefinition) -> void:
	definition = p_definition
	if definition == null:
		ability_id = "warrior_strike"
		active_behavior = AbilityDef.Behavior.STAB
		active_display_name = "Estocada"
	else:
		ability_id = definition.id
		active_behavior = definition.base_behavior
		active_display_name = definition.display_name
	active_transformation_id = ""
	damage_multiplier_bonus = 0.0
	behavior_damage_multiplier = 1.0
	behavior_cooldown_override = -1.0
	behavior_radius_override = -1.0
	behavior_half_angle_override = -1.0
	behavior_corridor_width_override = -1.0
	behavior_max_targets_override = -1
	cooldown_multiplier = 1.0
	area_multiplier = 1.0
	extra_targets = 0
	extra_strikes = 0
	active_tags.clear()
	if definition != null:
		for t in definition.base_tags:
			if not active_tags.has(String(t)):
				active_tags.append(String(t))
	special_modifiers.clear()


func apply_transformation(
	transformation_id: String,
	new_behavior: int,
	new_display_name: String,
	params: Dictionary = {},
	granted_tags: PackedStringArray = PackedStringArray()
) -> void:
	# Substitui o comportamento ativo sem duplicar efeitos de transformações anteriores.
	active_transformation_id = transformation_id
	active_behavior = new_behavior
	if not new_display_name.is_empty():
		active_display_name = new_display_name
	behavior_damage_multiplier = float(params.get("damage_multiplier", 1.0))
	behavior_cooldown_override = float(params.get("cooldown", -1.0))
	behavior_radius_override = float(params.get("radius", -1.0))
	behavior_half_angle_override = float(params.get("half_angle", -1.0))
	behavior_corridor_width_override = float(params.get("corridor_width", -1.0))
	behavior_max_targets_override = int(params.get("max_targets", -1))
	for tag in granted_tags:
		add_tag(String(tag))


func apply_ability_upgrade(deltas: Dictionary, granted_tags: PackedStringArray = PackedStringArray()) -> void:
	if deltas.has("damage_multiplier_bonus"):
		damage_multiplier_bonus += float(deltas["damage_multiplier_bonus"])
	if deltas.has("area_multiplier_add"):
		area_multiplier = maxf(0.25, area_multiplier + float(deltas["area_multiplier_add"]))
	if deltas.has("cooldown_multiplier_factor"):
		cooldown_multiplier = clampf(cooldown_multiplier * float(deltas["cooldown_multiplier_factor"]), 0.25, 3.0)
	if deltas.has("extra_targets"):
		extra_targets += int(deltas["extra_targets"])
	if deltas.has("extra_strikes"):
		extra_strikes += int(deltas["extra_strikes"])
	for tag in granted_tags:
		add_tag(String(tag))


func add_special_modifier(effect_id: String, params: Dictionary, granted_tags: PackedStringArray = PackedStringArray()) -> void:
	if effect_id.is_empty():
		return
	if not special_modifiers.has(effect_id):
		var initial_entry: Dictionary = params.duplicate(true)
		initial_entry["rank"] = 1
		special_modifiers[effect_id] = initial_entry
	else:
		var existing: Dictionary = special_modifiers[effect_id]
		existing["rank"] = int(existing.get("rank", 1)) + 1
		if params.has("dps_per_rank"):
			existing["dps"] = float(existing.get("dps", params.get("dps", 5.0))) + float(params["dps_per_rank"])
		if params.has("damage_ratio_per_rank"):
			existing["damage_ratio"] = minf(1.0, float(existing.get("damage_ratio", 0.5)) + float(params["damage_ratio_per_rank"]))
		special_modifiers[effect_id] = existing
	for tag in granted_tags:
		add_tag(String(tag))


func has_special_modifier(effect_id: String) -> bool:
	return special_modifiers.has(effect_id)


func get_special_modifier(effect_id: String) -> Dictionary:
	return special_modifiers.get(effect_id, {})


func add_tag(tag: String) -> void:
	if not tag.is_empty() and not active_tags.has(tag):
		active_tags.append(tag)


func has_tag(tag: String) -> bool:
	return active_tags.has(tag)


func get_effective_radius(stats: CharacterStats = null) -> float:
	var base_rad: float = definition.base_radius if definition != null else 2.7
	if behavior_radius_override > 0.0:
		base_rad = behavior_radius_override
	var stat_area: float = stats.get_area_scale() if stats != null else 1.0
	return base_rad * area_multiplier * stat_area


func get_effective_half_angle() -> float:
	if behavior_half_angle_override > 0.0:
		return behavior_half_angle_override
	return definition.base_half_angle if definition != null else 0.28


func get_effective_corridor_width(stats: CharacterStats = null) -> float:
	var base_width: float = definition.base_corridor_width if definition != null else 0.95
	if behavior_corridor_width_override > 0.0:
		base_width = behavior_corridor_width_override
	var stat_area: float = stats.get_area_scale() if stats != null else 1.0
	return base_width * sqrt(maxf(0.25, area_multiplier * stat_area))


func get_effective_cooldown(stats: CharacterStats = null) -> float:
	var base_cd: float = definition.base_cooldown if definition != null else 0.8
	if behavior_cooldown_override > 0.0:
		base_cd = behavior_cooldown_override
	var atk_spd: float = stats.get_attack_speed() if stats != null else 1.0
	var cdr: float = stats.get_cooldown_reduction() if stats != null else 0.0
	var raw_cd: float = (base_cd * cooldown_multiplier * (1.0 - cdr)) / maxf(0.2, atk_spd)
	return maxf(0.15, raw_cd)


func get_effective_damage(stats: CharacterStats = null) -> int:
	var base_dmg: float = float(stats.get_damage()) if stats != null else 14.0
	var base_mult: float = definition.base_damage_multiplier if definition != null else 1.0
	var final_dmg: float = base_dmg * maxf(0.1, base_mult + damage_multiplier_bonus) * behavior_damage_multiplier
	return maxi(1, roundi(final_dmg))


func get_effective_max_targets() -> int:
	var base_targets: int = definition.base_max_targets if definition != null else 2
	if behavior_max_targets_override > 0:
		base_targets = behavior_max_targets_override
	return maxi(1, base_targets + extra_targets)


## Regra explícita anti-recursão infinita (Seção 5):
## Golpes secundários (como Eco ou ticks de Queimadura) NUNCA geram novos golpes secundários.
func can_trigger_secondary_effects(is_secondary_hit: bool) -> bool:
	return not is_secondary_hit
