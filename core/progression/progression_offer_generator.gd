extends RefCounted
class_name ProgressionOfferGenerator
## Gerador determinístico de ofertas de evolução (Level Up).
## Respeita classe, habilidades, nível máximo, pré-requisitos, exclusões, grupos de exclusividade e pesos.

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var early_transformation_weight_boost: float = 3.5


func _init(seed_value: int = -1) -> void:
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()


func set_seed(seed_value: int) -> void:
	rng.seed = seed_value


func is_upgrade_eligible(upgrade: ProgressionUpgradeDefinition, state: RunProgressionState) -> bool:
	if upgrade == null or upgrade.id.is_empty():
		return false
	if upgrade.weight <= 0.0:
		return false
	if state == null:
		return false
	if state.level < upgrade.min_run_level:
		return false

	# 1. Nível máximo da evolução
	var current_rank: int = state.get_upgrade_rank(upgrade.id)
	if current_rank >= upgrade.max_rank:
		return false

	# 2. Classe compatível
	if not upgrade.target_class_id.is_empty() and upgrade.target_class_id != state.class_id:
		return false

	# 3. Habilidade compatível
	if not upgrade.target_ability_id.is_empty() and not state.available_ability_ids.has(upgrade.target_ability_id):
		return false

	# 4. Desbloqueio de metaprogressão (se exigido)
	if not upgrade.requires_meta_unlock_id.is_empty() and not state.meta_unlocks.has(upgrade.requires_meta_unlock_id):
		return false

	# 5. Exclusões explícitas (em ambas as direções)
	if state.excluded_upgrade_ids.has(upgrade.id):
		return false
	for ex_id in upgrade.excluded_upgrade_ids:
		if state.has_upgrade(String(ex_id)):
			return false

	# 6. Grupo de exclusividade
	if not upgrade.exclusivity_group.is_empty():
		if state.acquired_exclusivity_groups.has(upgrade.exclusivity_group):
			var chosen_in_group: String = String(state.acquired_exclusivity_groups[upgrade.exclusivity_group])
			if chosen_in_group != upgrade.id:
				return false

	# 7. Pré-requisitos de evoluções
	for req_id in upgrade.required_upgrade_ids:
		if not state.has_upgrade(String(req_id)):
			return false

	# 8. Pré-requisitos de tags
	for req_tag in upgrade.required_tags:
		if not state.has_tag(String(req_tag)):
			return false

	return true


func get_effective_weight(upgrade: ProgressionUpgradeDefinition, state: RunProgressionState) -> float:
	var w: float = maxf(0.0, upgrade.weight)
	if state != null and upgrade.category == ProgressionUpgradeDefinition.Category.ABILITY_TRANSFORMATION:
		# Prioriza transformações nas primeiras escolhas se o jogador ainda estiver na forma inicial.
		if not state.has_chosen_any_transformation() and state.upgrade_history.size() <= 2:
			w *= early_transformation_weight_boost
	if state != null and upgrade.special_effect_id == "burn" and state.meta_unlocks.has("pyromancy_boost"):
		w *= 1.6
	return w


func generate_offers(
	pool: Array[ProgressionUpgradeDefinition],
	state: RunProgressionState,
	offer_count: int = 3
) -> Array[ProgressionUpgradeDefinition]:
	var result: Array[ProgressionUpgradeDefinition] = []
	if offer_count <= 0 or pool.is_empty() or state == null:
		return result

	var candidates: Array[ProgressionUpgradeDefinition] = []
	var seen_ids: Dictionary = {}
	for item in pool:
		if item == null or seen_ids.has(item.id):
			continue
		if is_upgrade_eligible(item, state):
			candidates.append(item)
			seen_ids[item.id] = true

	var target_count: int = mini(offer_count, candidates.size())
	for _pick_idx in range(target_count):
		var total_weight: float = 0.0
		var weights: Array[float] = []
		for candidate in candidates:
			var w: float = get_effective_weight(candidate, state)
			weights.append(w)
			total_weight += w

		if total_weight <= 0.0001:
			result.append(candidates.pop_front())
			continue

		var roll: float = rng.randf_range(0.0, total_weight)
		var cumulative: float = 0.0
		var chosen_index: int = candidates.size() - 1
		for idx in range(candidates.size()):
			cumulative += weights[idx]
			if roll <= cumulative:
				chosen_index = idx
				break

		result.append(candidates[chosen_index])
		candidates.remove_at(chosen_index)

	return result
