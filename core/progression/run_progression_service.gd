extends Node
class_name RunProgressionService
## Coordenação das regras de XP, níveis, fila de escolhas, geração de ofertas e aplicação de evoluções.
## Mantém compatibilidade integral com o contrato da v0.17 e expande para o Vertical Slice completo.

signal progress_changed(level: int, current_xp: int, xp_required: int)
signal level_gained(level: int)
signal choices_changed(pending: int)
signal offers_ready(offers: Array[ProgressionUpgradeDefinition])
signal upgrade_applied(upgrade: ProgressionUpgradeDefinition, new_rank: int)

@export var balance: ProgressionBalance = preload("res://content/progression/balance_dev.tres")

var state: RunProgressionState = RunProgressionState.new()
var offer_generator: ProgressionOfferGenerator = ProgressionOfferGenerator.new()
var upgrade_pool: Array[ProgressionUpgradeDefinition] = []
var current_offers: Array[ProgressionUpgradeDefinition] = []

var _bound_stats: CharacterStats
var _bound_ability: AbilityRuntimeState


func _ready() -> void:
	if upgrade_pool.is_empty():
		upgrade_pool = UpgradeCatalog.load_default_pool()
	_notify_current_state()


func bind_runtime_targets(
	stats: CharacterStats,
	ability_runtime: AbilityRuntimeState,
	class_id: String = "warrior",
	meta_unlocks: Array[String] = []
) -> void:
	_bound_stats = stats
	_bound_ability = ability_runtime
	var ability_ids: Array[String] = []
	var initial_tags: Array[String] = ["melee", "physical", "strike", "stab"]
	if ability_runtime != null:
		ability_ids.append(ability_runtime.ability_id)
		initial_tags = ability_runtime.active_tags.duplicate()
	else:
		ability_ids.append("warrior_strike")
	state.configure_for_class(class_id, ability_ids, initial_tags, meta_unlocks)
	current_offers.clear()
	_notify_current_state()


func set_rng_seed(seed_value: int) -> void:
	offer_generator.set_seed(seed_value)


func grant_enemy_kill_xp() -> void:
	grant_xp(balance.enemy_xp)


func grant_xp(amount: int) -> void:
	if amount <= 0:
		return
	if balance == null:
		push_error("RunProgressionService: BalanceConfig não configurado")
		return

	state.total_xp += amount
	state.xp += amount
	var leveled_up: bool = false
	while state.xp >= balance.xp_to_next_level(state.level):
		state.xp -= balance.xp_to_next_level(state.level)
		state.level += 1
		state.pending_upgrade_choices += 1
		leveled_up = true
		level_gained.emit(state.level)

	progress_changed.emit(state.level, state.xp, balance.xp_to_next_level(state.level))
	if leveled_up:
		choices_changed.emit(state.pending_upgrade_choices)
		if current_offers.is_empty():
			_prepare_next_offers()


func get_or_generate_current_offers(offer_count: int = 3) -> Array[ProgressionUpgradeDefinition]:
	if state.pending_upgrade_choices <= 0:
		current_offers.clear()
		return current_offers
	if current_offers.is_empty():
		if upgrade_pool.is_empty():
			upgrade_pool = UpgradeCatalog.load_default_pool()
		current_offers = offer_generator.generate_offers(upgrade_pool, state, offer_count)
	return current_offers


func apply_upgrade_choice(
	upgrade: ProgressionUpgradeDefinition,
	stats_override: CharacterStats = null,
	ability_override: AbilityRuntimeState = null
) -> bool:
	if upgrade == null or state.pending_upgrade_choices <= 0:
		return false
	if not offer_generator.is_upgrade_eligible(upgrade, state):
		return false

	var target_stats: CharacterStats = stats_override if stats_override != null else _bound_stats
	var target_ability: AbilityRuntimeState = ability_override if ability_override != null else _bound_ability

	state.record_upgrade_choice(
		upgrade.id,
		upgrade.exclusivity_group,
		upgrade.excluded_upgrade_ids,
		upgrade.granted_tags
	)
	var new_rank: int = state.get_upgrade_rank(upgrade.id)

	# 1. Modificadores de atributos (Stats)
	if target_stats != null and not upgrade.stat_modifiers_data.is_empty():
		for idx in range(upgrade.stat_modifiers_data.size()):
			var entry: Dictionary = upgrade.stat_modifiers_data[idx]
			var stat_name := StringName(String(entry.get("stat", "")))
			var op: int = int(entry.get("op", StatModifier.Op.FLAT))
			var val: float = float(entry.get("value", 0.0))
			var mod_id: String = "run_upg:%s:r%d:i%d" % [upgrade.id, new_rank, idx]
			var mod := StatModifier.new(mod_id, stat_name, op, val, "run_upgrade")
			target_stats.add_modifier(mod)

	# 2. Transformação de comportamento da habilidade
	if target_ability != null and upgrade.ability_behavior_override >= 0:
		target_ability.apply_transformation(
			upgrade.id,
			upgrade.ability_behavior_override,
			upgrade.ability_display_name_override,
			upgrade.ability_transformation_params,
			upgrade.granted_tags
		)

	# 3. Melhorias numéricas da habilidade
	if target_ability != null and not upgrade.ability_upgrade_deltas.is_empty():
		target_ability.apply_ability_upgrade(upgrade.ability_upgrade_deltas, upgrade.granted_tags)

	# 4. Modificadores especiais (ex.: Queimadura, Eco)
	if target_ability != null and not upgrade.special_effect_id.is_empty():
		var params: Dictionary = upgrade.special_effect_params.duplicate(true)
		# Se tiver especialização de piromancia na metaprogressão, aumenta o dano de queimadura em +35%.
		if upgrade.special_effect_id == "burn" and state.meta_unlocks.has("pyromancy_boost"):
			params["dps"] = float(params.get("dps", 6.0)) * 1.35
			params["dps_per_rank"] = float(params.get("dps_per_rank", 4.0)) * 1.35
		target_ability.add_special_modifier(upgrade.special_effect_id, params, upgrade.granted_tags)

	state.pending_upgrade_choices -= 1
	current_offers.clear()
	upgrade_applied.emit(upgrade, new_rank)
	choices_changed.emit(state.pending_upgrade_choices)

	if state.pending_upgrade_choices > 0:
		_prepare_next_offers()
	return true


func resolve_one_upgrade_choice() -> bool:
	if state.pending_upgrade_choices <= 0:
		return false
	state.pending_upgrade_choices -= 1
	current_offers.clear()
	choices_changed.emit(state.pending_upgrade_choices)
	if state.pending_upgrade_choices > 0:
		_prepare_next_offers()
	return true


func reset_run() -> void:
	state = RunProgressionState.new()
	current_offers.clear()
	if _bound_stats != null:
		_bound_stats.remove_modifiers_by_source("run_upgrade")
	_notify_current_state()


func _prepare_next_offers() -> void:
	if state.pending_upgrade_choices <= 0:
		current_offers.clear()
		return
	if upgrade_pool.is_empty():
		upgrade_pool = UpgradeCatalog.load_default_pool()
	current_offers = offer_generator.generate_offers(upgrade_pool, state, 3)
	if not current_offers.is_empty():
		offers_ready.emit(current_offers)


func _notify_current_state() -> void:
	if balance == null:
		return
	progress_changed.emit(state.level, state.xp, balance.xp_to_next_level(state.level))
	choices_changed.emit(state.pending_upgrade_choices)
