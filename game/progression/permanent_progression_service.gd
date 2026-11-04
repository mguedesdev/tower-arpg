extends Node
class_name PermanentProgressionService
## Gerencia compras na árvore de talentos permanentes, validação de pré-requisitos, respec e aplicação na partida.

signal currency_changed(new_balance: int)
signal talents_changed
signal state_loaded

var state: PermanentProgressionState = PermanentProgressionState.new()
var save_service: SaveService = SaveService.new()
var talent_tree: Array[TalentNodeDefinition] = []
var _talent_map: Dictionary = {}
var auto_save: bool = true


func _init(custom_save_path: String = SaveService.DEFAULT_SAVE_PATH) -> void:
	save_service = SaveService.new(custom_save_path)
	set_talent_tree(TalentNodeDefinition.build_default_tree())


func _ready() -> void:
	if talent_tree.is_empty():
		set_talent_tree(TalentNodeDefinition.build_default_tree())


func set_talent_tree(nodes: Array[TalentNodeDefinition]) -> void:
	talent_tree = nodes
	_talent_map.clear()
	for node in talent_tree:
		if node != null and not node.id.is_empty():
			_talent_map[node.id] = node
	_rebuild_meta_unlocks()


func get_talent_definition(talent_id: String) -> TalentNodeDefinition:
	return _talent_map.get(talent_id, null) as TalentNodeDefinition


func load_from_disk() -> void:
	state = save_service.load_state()
	_rebuild_meta_unlocks()
	currency_changed.emit(state.essence)
	talents_changed.emit()
	state_loaded.emit()


func save_to_disk() -> bool:
	return save_service.save_state(state)


func add_currency(amount: int) -> void:
	if amount <= 0:
		return
	state.essence += amount
	state.total_essence_earned += amount
	if auto_save:
		save_to_disk()
	currency_changed.emit(state.essence)


func get_talent_rank(talent_id: String) -> int:
	return state.get_talent_rank(talent_id)


func get_talent_cost(talent_id: String) -> int:
	var def: TalentNodeDefinition = get_talent_definition(talent_id)
	if def == null:
		return 0
	var current_rank: int = get_talent_rank(talent_id)
	return def.cost * (current_rank + 1)


func are_prerequisites_met(talent_id: String) -> bool:
	var def: TalentNodeDefinition = get_talent_definition(talent_id)
	if def == null:
		return false
	for req_id in def.prerequisite_ids:
		if not state.is_talent_unlocked(String(req_id)):
			return false
	if not def.any_prerequisite_ids.is_empty():
		var any_ok: bool = false
		for opt_id in def.any_prerequisite_ids:
			if state.is_talent_unlocked(String(opt_id)):
				any_ok = true
				break
		if not any_ok:
			return false
	return true


func can_purchase_talent(talent_id: String) -> bool:
	var def: TalentNodeDefinition = get_talent_definition(talent_id)
	if def == null:
		return false
	var current_rank: int = get_talent_rank(talent_id)
	if current_rank >= def.max_rank:
		return false
	if not are_prerequisites_met(talent_id):
		return false
	var next_cost: int = get_talent_cost(talent_id)
	return state.essence >= next_cost


func purchase_talent(talent_id: String) -> bool:
	if not can_purchase_talent(talent_id):
		return false
	var cost: int = get_talent_cost(talent_id)
	var next_rank: int = get_talent_rank(talent_id) + 1
	state.essence -= cost
	state.unlocked_talents[talent_id] = next_rank
	_rebuild_meta_unlocks()
	if auto_save:
		save_to_disk()
	currency_changed.emit(state.essence)
	talents_changed.emit()
	return true


func compute_total_invested_currency() -> int:
	var spent: int = 0
	for talent_id in state.unlocked_talents.keys():
		var def: TalentNodeDefinition = get_talent_definition(String(talent_id))
		var rank: int = int(state.unlocked_talents[talent_id])
		if def != null and rank > 0:
			for r in range(1, rank + 1):
				spent += def.cost * r
	return spent


func respec_all_talents(stats_to_refresh: CharacterStats = null) -> int:
	var refunded: int = compute_total_invested_currency()
	state.essence += refunded
	state.unlocked_talents.clear()
	state.meta_unlocks.clear()
	if stats_to_refresh != null:
		stats_to_refresh.remove_modifiers_by_source("meta_progression")
	if auto_save:
		save_to_disk()
	currency_changed.emit(state.essence)
	talents_changed.emit()
	return refunded


func get_meta_unlocks_for_class(class_id: String) -> Array[String]:
	var result: Array[String] = []
	for talent_id in state.unlocked_talents.keys():
		var rank: int = int(state.unlocked_talents[talent_id])
		if rank <= 0:
			continue
		var def: TalentNodeDefinition = get_talent_definition(String(talent_id))
		if def == null:
			continue
		if not def.target_class_id.is_empty() and def.target_class_id != class_id:
			continue
		for unlock_id in def.granted_meta_unlocks:
			var u_str: String = String(unlock_id)
			if not u_str.is_empty() and not result.has(u_str):
				result.append(u_str)
	return result


func apply_to_run(
	class_id: String,
	stats: CharacterStats,
	run_service: RunProgressionService = null,
	ability_runtime: AbilityRuntimeState = null
) -> void:
	# Limpa modificadores permanentes anteriores para garantir aplicação EXATAMENTE UMA VEZ por partida.
	if stats != null:
		stats.remove_modifiers_by_source("meta_progression")

	var starting_xp: int = 0
	var class_unlocks: Array[String] = get_meta_unlocks_for_class(class_id)

	for talent_id in state.unlocked_talents.keys():
		var rank: int = int(state.unlocked_talents[talent_id])
		if rank <= 0:
			continue
		var def: TalentNodeDefinition = get_talent_definition(String(talent_id))
		if def == null:
			continue
		# Respeita restrição de classe (ex.: talentos exclusivos de Guerreiro não se aplicam a Mago).
		if not def.target_class_id.is_empty() and def.target_class_id != class_id:
			continue

		if stats != null and not def.stat_modifiers_data.is_empty():
			for idx in range(def.stat_modifiers_data.size()):
				var entry: Dictionary = def.stat_modifiers_data[idx]
				var stat_name := StringName(String(entry.get("stat", "")))
				var op: int = int(entry.get("op", StatModifier.Op.FLAT))
				var val: float = float(entry.get("value", 0.0)) * float(rank)
				var mod_id: String = "meta:%s:i%d" % [def.id, idx]
				var mod := StatModifier.new(mod_id, stat_name, op, val, "meta_progression")
				stats.add_modifier(mod)

		starting_xp += def.starting_xp_bonus * rank

	# Se a vida máxima subiu no início da run, começa a partida com a vida cheia!
	if stats != null:
		stats.set_current_health(stats.get_max_health())

	if run_service != null:
		run_service.bind_runtime_targets(stats, ability_runtime, class_id, class_unlocks)
		if starting_xp > 0 and run_service.state.total_xp == 0:
			run_service.grant_xp(starting_xp)


func _rebuild_meta_unlocks() -> void:
	state.meta_unlocks.clear()
	for talent_id in state.unlocked_talents.keys():
		var rank: int = int(state.unlocked_talents[talent_id])
		if rank <= 0:
			continue
		var def: TalentNodeDefinition = get_talent_definition(String(talent_id))
		if def == null:
			continue
		for unlock_id in def.granted_meta_unlocks:
			var u_str: String = String(unlock_id)
			if not u_str.is_empty() and not state.meta_unlocks.has(u_str):
				state.meta_unlocks.append(u_str)
