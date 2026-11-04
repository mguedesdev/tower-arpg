extends Resource
class_name RunRewardCalculator
## Cálculo centralizado de recompensas (Essência) ao final de cada tentativa.
## Garante que cada resultado de partida conceda moeda exatamente uma única vez.

@export_range(0, 500, 1) var essence_per_completed_wave: int = 6
@export_range(0, 1000, 1) var essence_per_boss: int = 15
@export_range(0, 500, 1) var essence_per_special_objective: int = 10
@export_range(0.0, 50.0, 0.1) var essence_per_kill: float = 0.6
@export_range(0, 200, 1) var essence_per_level_above_one: int = 4
@export_range(0, 1000, 1) var victory_bonus_essence: int = 20
@export_range(0, 50, 1) var consolation_essence_with_effort: int = 3

var _claimed_run_ids: Dictionary = {}


func calculate_reward(summary: RunSummaryState) -> int:
	if summary == null:
		return 0
	var raw: float = 0.0
	raw += float(maxi(0, summary.waves_completed)) * float(essence_per_completed_wave)
	raw += float(maxi(0, summary.bosses_defeated)) * float(essence_per_boss)
	raw += float(maxi(0, summary.special_objectives_completed)) * float(essence_per_special_objective)
	raw += float(maxi(0, summary.enemies_defeated)) * essence_per_kill
	raw += float(maxi(0, summary.run_level_reached - 1)) * float(essence_per_level_above_one)
	if summary.victory:
		raw += float(victory_bonus_essence)

	var scaled: int = roundi(raw * maxf(0.1, summary.difficulty_multiplier))
	if scaled <= 0 and (summary.enemies_defeated > 0 or summary.waves_completed > 0):
		scaled = consolation_essence_with_effort
	return maxi(0, scaled)


func grant_reward_once(summary: RunSummaryState, permanent_service: Object) -> int:
	if summary == null:
		return 0
	if summary.reward_claimed:
		return 0
	if not summary.run_id.is_empty() and _claimed_run_ids.has(summary.run_id):
		summary.reward_claimed = true
		return 0

	var amount: int = calculate_reward(summary)
	summary.essence_rewarded = amount
	summary.reward_claimed = true
	if not summary.run_id.is_empty():
		_claimed_run_ids[summary.run_id] = amount

	if permanent_service != null and permanent_service.has_method("add_currency") and amount > 0:
		permanent_service.call("add_currency", amount)
	return amount
