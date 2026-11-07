extends RefCounted
class_name ItemCraftingService

## ===========================================================================
## SERVIÇO DE EXECUÇÃO ATÔMICA DE ESCRITURAS ARCANAS (CRAFTING ARPG)
## ===========================================================================
## Implementa as operações atômicas da especificação `06_estudo_escrituras_arcanas_crafting.md`:
## • scroll_first_mark:    Branco 0 -> Verde 1 (1P ou 1S)
## • scroll_counterseal:   Verde 1 -> Azul 2 (1P + 1S)
## • scroll_golden_clause: Azul 2 -> Amarelo 3 | Amarelo 3 -> Amarelo 4 | Reconstrução -> 3
## • stone_eraser:         Remove 1 afixo uniforme (1/N) com normalização estrita de raridade
## • stone_verdict:        Transformação imprevisível com intenções (rewrite/preserve/elevate)
##                         e lacre permanente (VERDICT_SEALED) em 100% dos resultados.

const Eligibility = preload("res://core/items/crafting_eligibility_service.gd")
const LootGenerationService = preload("res://core/items/loot_generation_service.gd")


static func apply_craft(
	item: ItemInstance,
	consumable_id: String,
	options: Dictionary = {},
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var check: Dictionary = Eligibility.check_eligibility(item, consumable_id, options)
	if not bool(check.get("can_craft", false)):
		return {
			"success": false,
			"code": String(check.get("code", "FAILED")),
			"message": String(check.get("reason", "Ação de crafting inválida.")),
			"item": item,
			"changes": {}
		}

	match consumable_id:
		"scroll_first_mark":
			return _craft_first_mark(item, options, rng)
		"scroll_counterseal":
			return _craft_counterseal(item, options, rng)
		"scroll_golden_clause":
			return _craft_golden_clause(item, options, rng)
		"stone_eraser":
			return _craft_stone_eraser(item, options, rng)
		"stone_verdict":
			return _craft_stone_verdict(item, options, rng)
		_:
			return {
				"success": false,
				"code": "UNKNOWN_CONSUMABLE",
				"message": "Consumível não reconhecido.",
				"item": item,
				"changes": {}
			}


## ---------------------------------------------------------------------------
## 1. PERGAMINHO DA PRIMEIRA MARCA: Branco 0 -> Verde 1
## ---------------------------------------------------------------------------
static func _craft_first_mark(
	item: ItemInstance,
	options: Dictionary = {},
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var cat: int = item.definition.category
	var ilvl: int = maxi(1, item.item_level)

	var p_fams: Array[Dictionary] = LootGenerationService.get_eligible_affix_families(ItemAffix.AffixType.PREFIX, cat, ilvl)
	var s_fams: Array[Dictionary] = LootGenerationService.get_eligible_affix_families(ItemAffix.AffixType.SUFFIX, cat, ilvl)

	var chosen_kind: int = ItemAffix.AffixType.PREFIX
	if not p_fams.is_empty() and not s_fams.is_empty():
		var pick_p: bool = (rng.randf() if rng != null else randf()) < 0.5
		chosen_kind = ItemAffix.AffixType.PREFIX if pick_p else ItemAffix.AffixType.SUFFIX
	elif not p_fams.is_empty():
		chosen_kind = ItemAffix.AffixType.PREFIX
	elif not s_fams.is_empty():
		chosen_kind = ItemAffix.AffixType.SUFFIX
	else:
		return {"success": false, "code": "NO_ELIGIBLE_AFFIXES", "message": "Nenhum afixo elegível."}

	var eligible: Array[Dictionary] = p_fams if chosen_kind == ItemAffix.AffixType.PREFIX else s_fams
	var picked_family: Dictionary = _roll_family_with_optional_ink(eligible, options, rng)
	var affix: ItemAffix = LootGenerationService.roll_single_affix_from_family(picked_family, ilvl, rng)
	if affix == null:
		return {"success": false, "code": "ROLL_FAILED", "message": "Falha ao gerar afixo."}

	item.explicit_affixes.clear()
	item.explicit_affixes.append(affix)
	item.rarity = ItemInstance.ItemRarity.UNCOMMON
	item.craft_state = ItemInstance.CraftState.NORMAL

	var event := {
		"action": "scroll_first_mark",
		"added_affix": affix.to_dictionary(),
		"rarity_after": "uncommon"
	}
	item.add_craft_event("scroll_first_mark", event)

	return {
		"success": true,
		"code": "SUCCESS",
		"message": "Primeira Marca inscrita com sucesso! O equipamento tornou-se Incomum (Verde).",
		"item": item,
		"changes": event
	}


## ---------------------------------------------------------------------------
## 2. PERGAMINHO DO CONTRASSELO: Verde 1 -> Azul 2 (1P + 1S)
## ---------------------------------------------------------------------------
static func _craft_counterseal(
	item: ItemInstance,
	options: Dictionary = {},
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var existing: ItemAffix = item.explicit_affixes[0]
	var needed_kind: int = ItemAffix.AffixType.SUFFIX if existing.affix_type == ItemAffix.AffixType.PREFIX else ItemAffix.AffixType.PREFIX
	var cat: int = item.definition.category
	var ilvl: int = maxi(1, item.item_level)

	var used_exclusive: Dictionary = {existing.exclusion_group: true}
	var used_families: Dictionary = {existing.affix_id: true}

	var eligible: Array[Dictionary] = LootGenerationService.get_eligible_affix_families(
		needed_kind, cat, ilvl, used_exclusive, used_families
	)
	if eligible.is_empty():
		return {"success": false, "code": "NO_ELIGIBLE_AFFIXES", "message": "Sem afixos complementares viáveis."}

	var picked_family: Dictionary = _roll_family_with_optional_ink(eligible, options, rng)
	var affix: ItemAffix = LootGenerationService.roll_single_affix_from_family(picked_family, ilvl, rng)
	if affix == null:
		return {"success": false, "code": "ROLL_FAILED", "message": "Falha ao sortear o afixo complementar."}

	item.explicit_affixes.append(affix)
	item.rarity = ItemInstance.ItemRarity.MAGIC
	item.craft_state = ItemInstance.CraftState.NORMAL

	var event := {
		"action": "scroll_counterseal",
		"added_affix": affix.to_dictionary(),
		"rarity_after": "magic"
	}
	item.add_craft_event("scroll_counterseal", event)

	return {
		"success": true,
		"code": "SUCCESS",
		"message": "Contrasselo inscrito com sucesso! O equipamento tornou-se Mágico (Azul 1P+1S).",
		"item": item,
		"changes": event
	}


## ---------------------------------------------------------------------------
## 3. PERGAMINHO DA CLÁUSULA ÁUREA: Azul 2 -> Amarelo 3 | Amarelo 3 -> Amarelo 4
## ---------------------------------------------------------------------------
static func _craft_golden_clause(
	item: ItemInstance,
	options: Dictionary = {},
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var p_count: int = item.get_prefix_count()
	var s_count: int = item.get_suffix_count()
	var cat: int = item.definition.category
	var ilvl: int = maxi(1, item.item_level)

	var used_exclusive: Dictionary = {}
	var used_families: Dictionary = {}
	for af in item.explicit_affixes:
		if af != null:
			used_exclusive[af.exclusion_group] = true
			used_families[af.affix_id] = true

	# Determina tipos viáveis para o novo slot
	var candidate_kinds: Array[int] = []
	if p_count < 2:
		var pf: Array[Dictionary] = LootGenerationService.get_eligible_affix_families(ItemAffix.AffixType.PREFIX, cat, ilvl, used_exclusive, used_families)
		if not pf.is_empty():
			candidate_kinds.append(ItemAffix.AffixType.PREFIX)
	if s_count < 2:
		var sf: Array[Dictionary] = LootGenerationService.get_eligible_affix_families(ItemAffix.AffixType.SUFFIX, cat, ilvl, used_exclusive, used_families)
		if not sf.is_empty():
			candidate_kinds.append(ItemAffix.AffixType.SUFFIX)

	if candidate_kinds.is_empty():
		return {"success": false, "code": "NO_ELIGIBLE_AFFIXES", "message": "Nenhum afixo elegível para o novo slot."}

	var chosen_kind: int = candidate_kinds[0]
	if candidate_kinds.size() > 1:
		var pick_p: bool = (rng.randf() if rng != null else randf()) < 0.5
		chosen_kind = candidate_kinds[0] if pick_p else candidate_kinds[1]

	var eligible: Array[Dictionary] = LootGenerationService.get_eligible_affix_families(
		chosen_kind, cat, ilvl, used_exclusive, used_families
	)
	var picked_family: Dictionary = _roll_family_with_optional_ink(eligible, options, rng)
	var affix: ItemAffix = LootGenerationService.roll_single_affix_from_family(picked_family, ilvl, rng)
	if affix == null:
		return {"success": false, "code": "ROLL_FAILED", "message": "Falha ao sortear nova cláusula."}

	item.explicit_affixes.append(affix)
	item.rarity = ItemInstance.ItemRarity.RARE
	item.craft_state = ItemInstance.CraftState.NORMAL # Restaura estado normal se estava em reconstrução!

	var event := {
		"action": "scroll_golden_clause",
		"added_affix": affix.to_dictionary(),
		"total_mods": item.explicit_affixes.size(),
		"rarity_after": "rare"
	}
	item.add_craft_event("scroll_golden_clause", event)

	return {
		"success": true,
		"code": "SUCCESS",
		"message": "Cláusula Áurea inscrita com sucesso! O equipamento agora possui %d atributos (Raro)." % item.explicit_affixes.size(),
		"item": item,
		"changes": event
	}


## ---------------------------------------------------------------------------
## 4. PEDRA DA RASURA: Remove 1 afixo uniforme com normalização de raridade
## ---------------------------------------------------------------------------
static func _craft_stone_eraser(
	item: ItemInstance,
	_options: Dictionary = {},
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var total: int = item.explicit_affixes.size()
	if total == 0:
		return {"success": false, "code": "NO_AFFIXES", "message": "Nenhum afixo para apagar."}

	# Probabilidade uniforme estrita entre os afixos explícitos (1/N)
	var idx_to_remove: int = (rng.randi() % total) if rng != null else (randi() % total)
	var removed_affix: ItemAffix = item.explicit_affixes[idx_to_remove]
	item.explicit_affixes.remove_at(idx_to_remove)

	# Normalização de raridade pós-remoção (Seção 3.1 da especificação)
	var rem_p: int = item.get_prefix_count()
	var rem_s: int = item.get_suffix_count()
	var rem_total: int = item.explicit_affixes.size()

	var state_after: ItemInstance.CraftState = ItemInstance.CraftState.NORMAL

	if rem_total == 0:
		item.rarity = ItemInstance.ItemRarity.NORMAL
	elif rem_total == 1:
		item.rarity = ItemInstance.ItemRarity.UNCOMMON
	elif rem_total == 2:
		if rem_p == 1 and rem_s == 1:
			# Normaliza para Mágico (Azul 1P+1S)
			item.rarity = ItemInstance.ItemRarity.MAGIC
		else:
			# RARO EM RECONSTRUÇÃO: 2 afixos do mesmo lado (2P+0S ou 0P+2S)!
			item.rarity = ItemInstance.ItemRarity.RARE
			state_after = ItemInstance.CraftState.RECONSTRUCTING
	else:
		# 3 afixos restantes (2P+1S ou 1P+2S)
		item.rarity = ItemInstance.ItemRarity.RARE

	item.craft_state = state_after

	var event := {
		"action": "stone_eraser",
		"removed_affix": removed_affix.to_dictionary(),
		"remaining_count": rem_total,
		"rarity_after": ItemInstance.rarity_to_id(item.rarity),
		"reconstructing": (state_after == ItemInstance.CraftState.RECONSTRUCTING)
	}
	item.add_craft_event("stone_eraser", event)

	var msg: String = "Rasura executada! O atributo '%s' foi apagado." % removed_affix.display_text
	if state_after == ItemInstance.CraftState.RECONSTRUCTING:
		msg += " O item permanece Raro [Em Reconstrução] aguardando nova Cláusula Áurea."

	return {
		"success": true,
		"code": "SUCCESS",
		"message": msg,
		"item": item,
		"changes": event
	}


## ---------------------------------------------------------------------------
## 5. PEDRA DO VEREDITO: Transformação de risco e Lacre permanente
## ---------------------------------------------------------------------------
static func _craft_stone_verdict(
	item: ItemInstance,
	options: Dictionary = {},
	rng: RandomNumberGenerator = null
) -> Dictionary:
	var mode: String = String(options.get("intent", options.get("verdict_mode", "rewrite"))).to_lower().strip_edges()
	if mode != "preserve" and mode != "elevate":
		mode = "rewrite"

	var roll_pct: float = (rng.randf() if rng != null else randf()) * 100.0
	var outcome_log := {
		"intent": mode,
		"roll_pct": roll_pct,
		"action_taken": "none",
		"affixes_before": [],
		"affixes_after": []
	}

	for af in item.explicit_affixes:
		if af != null:
			outcome_log["affixes_before"].append(af.to_dictionary())

	match mode:
		"preserve":
			_apply_verdict_preserve(item, roll_pct, options, outcome_log, rng)
		"elevate":
			_apply_verdict_elevate(item, roll_pct, outcome_log, rng)
		_:
			_apply_verdict_rewrite(item, roll_pct, outcome_log, rng)

	for af in item.explicit_affixes:
		if af != null:
			outcome_log["affixes_after"].append(af.to_dictionary())

	# REGRA DE OURO: Lacrado permanentemente em 100% dos resultados!
	item.craft_state = ItemInstance.CraftState.VERDICT_SEALED
	item.verdict_mode = mode
	item.add_craft_event("stone_verdict", outcome_log)

	return {
		"success": true,
		"code": "SUCCESS",
		"message": "Sentença executada: %s. O equipamento está LACRADO PELO VEREDITO." % String(outcome_log["action_taken"]),
		"item": item,
		"changes": outcome_log
	}


static func _apply_verdict_rewrite(
	item: ItemInstance,
	roll_pct: float,
	log_dict: Dictionary,
	rng: RandomNumberGenerator = null
) -> void:
	# Tabela Seção 4.5:
	# 15% nada muda (0 <= roll < 15)
	# 20% altera 1 (15 <= roll < 35)
	# 25% altera 2 (35 <= roll < 60)
	# 40% reescreve todos (60 <= roll < 100)
	if roll_pct < 15.0:
		log_dict["action_taken"] = "Nada mudou na inscrição existente."
		return

	var count_to_change: int = 1
	if roll_pct < 35.0:
		count_to_change = 1
		log_dict["action_taken"] = "Reescreveu 1 atributo aleatório."
	elif roll_pct < 60.0:
		count_to_change = mini(2, item.explicit_affixes.size())
		log_dict["action_taken"] = "Reescreveu 2 atributos aleatórios."
	else:
		count_to_change = item.explicit_affixes.size()
		log_dict["action_taken"] = "Reescreveu TODOS os atributos do equipamento."

	_reroll_random_affixes_in_item(item, count_to_change, rng)


static func _apply_verdict_preserve(
	item: ItemInstance,
	roll_pct: float,
	options: Dictionary,
	log_dict: Dictionary,
	rng: RandomNumberGenerator = null
) -> void:
	# 30% nada muda (0 <= roll < 30)
	# 45% altera 1 outro (30 <= roll < 75)
	# 20% altera até 2 outros (75 <= roll < 95)
	# 5% reescreve todos os outros (95 <= roll < 100)
	var protected_idx: int = int(options.get("preserve_affix_index", 0))
	protected_idx = clampi(protected_idx, 0, item.explicit_affixes.size() - 1)
	var protected_affix: ItemAffix = item.explicit_affixes[protected_idx]
	log_dict["protected_affix"] = protected_affix.to_dictionary()

	if roll_pct < 30.0:
		log_dict["action_taken"] = "Nada mudou (atributo protegido intacto)."
		return

	var other_indices: Array[int] = []
	for i in range(item.explicit_affixes.size()):
		if i != protected_idx:
			other_indices.append(i)

	if other_indices.is_empty():
		log_dict["action_taken"] = "Apenas o atributo protegido existe no item."
		return

	var count_to_change: int = 1
	if roll_pct < 75.0:
		count_to_change = 1
		log_dict["action_taken"] = "Preservou '%s' e reescreveu 1 outro atributo." % protected_affix.display_text
	elif roll_pct < 95.0:
		count_to_change = mini(2, other_indices.size())
		log_dict["action_taken"] = "Preservou '%s' e reescreveu até 2 outros atributos." % protected_affix.display_text
	else:
		count_to_change = other_indices.size()
		log_dict["action_taken"] = "Preservou '%s' e reescreveu todos os outros atributos." % protected_affix.display_text

	# Embaralha os outros índices e re-sorteia os escolhidos
	_shuffle_array(other_indices, rng)
	var target_sub_indices: Array[int] = []
	for k in range(mini(count_to_change, other_indices.size())):
		target_sub_indices.append(other_indices[k])

	_reroll_specific_indices_in_item(item, target_sub_indices, rng)


static func _apply_verdict_elevate(
	item: ItemInstance,
	roll_pct: float,
	log_dict: Dictionary,
	rng: RandomNumberGenerator = null
) -> void:
	# 20% nada muda (0 <= roll < 20)
	# 35% sobe 1 tier em afixo elegível (20 <= roll < 55)
	# 20% desce 1 tier (55 <= roll < 75)
	# 15% refaz identidade/tier/roll de 1 (75 <= roll < 90)
	# 10% reescreve todos (90 <= roll < 100)
	if roll_pct < 20.0:
		log_dict["action_taken"] = "Nada mudou."
		return

	if roll_pct < 55.0:
		# Tentar subir 1 tier (ex: T3 -> T2; T1 é o teto máximo)
		var promotable: Array[int] = []
		for i in range(item.explicit_affixes.size()):
			var af: ItemAffix = item.explicit_affixes[i]
			if af != null and af.tier > 1:
				# Checa se o tier superior (af.tier - 1) é viável no ilvl do item
				var fam: Dictionary = LootBalanceConfig.get_affix_family(af.affix_id)
				var target_tier_num: int = af.tier - 1
				for t_entry in fam.get("tiers", []):
					if int(t_entry.get("tier", 1)) == target_tier_num and int(t_entry.get("min_ilvl", 1)) <= item.item_level:
						promotable.append(i)
						break

		if not promotable.is_empty():
			var p_idx: int = promotable[(rng.randi() % promotable.size()) if rng != null else (randi() % promotable.size())]
			var af_to_up: ItemAffix = item.explicit_affixes[p_idx]
			var fam: Dictionary = LootBalanceConfig.get_affix_family(af_to_up.affix_id)
			var old_t: int = af_to_up.tier
			var new_t: int = old_t - 1
			_apply_new_tier_to_affix(af_to_up, fam, new_t, rng)
			log_dict["action_taken"] = "Subiu o tier de '%s' de T%d para T%d!" % [af_to_up.stat_key, old_t, new_t]
			return

		# Fallback se nenhum afixo puder subir: refaz roll numérico de 1
		log_dict["action_taken"] = "Nenhum tier elegível para subir; recarimbou valores."
		_reroll_values_only_for_index(item, 0, rng)
		return

	if roll_pct < 75.0:
		# Desce 1 tier em afixo elegível (ex: T2 -> T3)
		var demotable: Array[int] = []
		for i in range(item.explicit_affixes.size()):
			var af: ItemAffix = item.explicit_affixes[i]
			if af != null:
				var fam: Dictionary = LootBalanceConfig.get_affix_family(af.affix_id)
				var max_t: int = 1
				for t_entry in fam.get("tiers", []):
					max_t = maxi(max_t, int(t_entry.get("tier", 1)))
				if af.tier < max_t:
					demotable.append(i)

		if not demotable.is_empty():
			var d_idx: int = demotable[(rng.randi() % demotable.size()) if rng != null else (randi() % demotable.size())]
			var af_to_down: ItemAffix = item.explicit_affixes[d_idx]
			var fam: Dictionary = LootBalanceConfig.get_affix_family(af_to_down.affix_id)
			var old_t: int = af_to_down.tier
			var new_t: int = old_t + 1
			_apply_new_tier_to_affix(af_to_down, fam, new_t, rng)
			log_dict["action_taken"] = "Desceu o tier de '%s' de T%d para T%d." % [af_to_down.stat_key, old_t, new_t]
			return

		log_dict["action_taken"] = "Nenhum tier elegível para descer; valores mantidos."
		return

	if roll_pct < 90.0:
		# Refaz identidade, tier e roll de 1 afixo
		var rand_idx: int = (rng.randi() % item.explicit_affixes.size()) if rng != null else (randi() % item.explicit_affixes.size())
		_reroll_specific_indices_in_item(item, [rand_idx], rng)
		log_dict["action_taken"] = "Refez a identidade completa de 1 atributo."
		return

	# 10%: Reescreve todos os afixos
	_reroll_random_affixes_in_item(item, item.explicit_affixes.size(), rng)
	log_dict["action_taken"] = "Reescreveu todos os atributos do equipamento."


## ---------------------------------------------------------------------------
## MÉTODOS AUXILIARES DE ROLAGEM E REESCRITA
## ---------------------------------------------------------------------------
static func _reroll_random_affixes_in_item(
	item: ItemInstance,
	count_to_change: int,
	rng: RandomNumberGenerator = null
) -> void:
	var total: int = item.explicit_affixes.size()
	if total == 0 or count_to_change <= 0:
		return

	var all_indices: Array[int] = []
	for i in range(total):
		all_indices.append(i)
	_shuffle_array(all_indices, rng)

	var targets: Array[int] = []
	for k in range(mini(count_to_change, total)):
		targets.append(all_indices[k])

	_reroll_specific_indices_in_item(item, targets, rng)


static func _reroll_specific_indices_in_item(
	item: ItemInstance,
	target_indices: Array[int],
	rng: RandomNumberGenerator = null
) -> void:
	if target_indices.is_empty():
		return

	var cat: int = item.definition.category
	var ilvl: int = maxi(1, item.item_level)

	# Coleta grupos e ids dos afixos que NÃO serão alterados
	var used_exclusive: Dictionary = {}
	var used_families: Dictionary = {}
	for i in range(item.explicit_affixes.size()):
		if not target_indices.has(i):
			var af: ItemAffix = item.explicit_affixes[i]
			if af != null:
				used_exclusive[af.exclusion_group] = true
				used_families[af.affix_id] = true

	for idx in target_indices:
		var old_af: ItemAffix = item.explicit_affixes[idx]
		var needed_kind: int = old_af.affix_type if old_af != null else ItemAffix.AffixType.PREFIX

		var eligible: Array[Dictionary] = LootGenerationService.get_eligible_affix_families(
			needed_kind, cat, ilvl, used_exclusive, used_families
		)
		if eligible.is_empty():
			# Tenta o tipo alternativo se viável
			var alt_kind: int = ItemAffix.AffixType.SUFFIX if needed_kind == ItemAffix.AffixType.PREFIX else ItemAffix.AffixType.PREFIX
			eligible = LootGenerationService.get_eligible_affix_families(
				alt_kind, cat, ilvl, used_exclusive, used_families
			)
			if eligible.is_empty():
				continue

		var fam_weights: Array[float] = []
		for fam in eligible:
			fam_weights.append(float(fam.get("family_weight", 10.0)))
		var chosen_fam_idx: int = LootBalanceConfig.roll_weighted_index(fam_weights, rng)
		var chosen_family: Dictionary = eligible[chosen_fam_idx]

		var new_affix: ItemAffix = LootGenerationService.roll_single_affix_from_family(chosen_family, ilvl, rng)
		if new_affix != null:
			item.explicit_affixes[idx] = new_affix
			used_exclusive[new_affix.exclusion_group] = true
			used_families[new_affix.affix_id] = true


static func _apply_new_tier_to_affix(
	affix: ItemAffix,
	family: Dictionary,
	new_tier_num: int,
	rng: RandomNumberGenerator = null
) -> void:
	for t_entry in family.get("tiers", []):
		if int(t_entry.get("tier", 1)) == new_tier_num:
			var min_v: float = float(t_entry.get("min_value", 0.0))
			var max_v: float = float(t_entry.get("max_value", min_v))
			var step: float = maxf(0.0001, float(family.get("roll_step", 1.0)))
			var total_steps: int = maxi(0, int(round((max_v - min_v) / step)))
			var step_pick: int = rng.randi_range(0, total_steps) if rng != null else randi_range(0, total_steps)
			var rolled_val: float = snappedf(min_v + float(step_pick) * step, step)
			rolled_val = clampf(rolled_val, min_v, max_v)

			affix.tier = new_tier_num
			affix.min_ilvl = int(t_entry.get("min_ilvl", 1))
			affix.value = rolled_val
			affix.min_value = min_v
			affix.max_value = max_v
			affix.display_text = LootBalanceConfig.format_affix_value_text(family, rolled_val)
			return


static func _reroll_values_only_for_index(
	item: ItemInstance,
	index: int,
	rng: RandomNumberGenerator = null
) -> void:
	if index < 0 or index >= item.explicit_affixes.size():
		return
	var af: ItemAffix = item.explicit_affixes[index]
	var fam: Dictionary = LootBalanceConfig.get_affix_family(af.affix_id)
	if fam.is_empty():
		return
	for t_entry in fam.get("tiers", []):
		if int(t_entry.get("tier", 1)) == af.tier:
			var min_v: float = float(t_entry.get("min_value", 0.0))
			var max_v: float = float(t_entry.get("max_value", min_v))
			var step: float = maxf(0.0001, float(family_get_step(fam)))
			var total_steps: int = maxi(0, int(round((max_v - min_v) / step)))
			var step_pick: int = rng.randi_range(0, total_steps) if rng != null else randi_range(0, total_steps)
			var rolled_val: float = snappedf(min_v + float(step_pick) * step, step)
			af.value = clampf(rolled_val, min_v, max_v)
			af.display_text = LootBalanceConfig.format_affix_value_text(fam, af.value)
			return


static func family_get_step(fam: Dictionary) -> float:
	return float(fam.get("roll_step", 1.0))


static func _roll_family_with_optional_ink(
	eligible_families: Array[Dictionary],
	options: Dictionary = {},
	rng: RandomNumberGenerator = null
) -> Dictionary:
	if eligible_families.is_empty():
		return {}

	var ink: String = String(options.get("ink", "")).to_lower().strip_edges()
	var weights: Array[float] = []

	for fam in eligible_families:
		var w: float = float(fam.get("family_weight", 10.0))
		var stat: String = String(fam.get("stat_id", ""))

		# Aplicação de Tintas de Intenção (Fase 2 / Suporte):
		if ink == "ink_war" and (stat.contains("damage") or stat.contains("attack_speed") or stat.contains("crit")):
			w *= 2.0
		elif ink == "ink_ward" and (stat.contains("armor") or stat.contains("health") or stat.contains("resist")):
			w *= 2.0
		elif ink == "ink_arcane" and (stat.contains("mana") or stat.contains("cooldown") or stat.contains("intel")):
			w *= 2.0

		weights.append(w)

	var chosen_idx: int = LootBalanceConfig.roll_weighted_index(weights, rng)
	return eligible_families[chosen_idx]


static func _shuffle_array(arr: Array, rng: RandomNumberGenerator = null) -> void:
	var n: int = arr.size()
	for i in range(n - 1, 0, -1):
		var j: int = (rng.randi() % (i + 1)) if rng != null else (randi() % (i + 1))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
