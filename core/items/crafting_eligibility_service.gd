extends RefCounted
class_name CraftingEligibilityService

const LootGenerationService = preload("res://core/items/loot_generation_service.gd")

## ===========================================================================
## SERVIÇO DE ELEGIBILIDADE E AUDITORIA DE CRAFTING (ESCRITURAS ARCANAS)
## ===========================================================================
## Centraliza a validação prévia de operações de crafting segundo a especificação
## `06_estudo_escrituras_arcanas_crafting.md`:
## • Não consome recursos caso a ação seja impossível ou inválida.
## • Retorna códigos de erro estáveis e mensagens informativas em português.
## • Aplica limites intransponíveis: 2 prefixos + 2 sufixos (máx 4 explícitos),
##   impossibilidade em itens Únicos (vermelhos) e bloqueio absoluto em itens Lacrados.

const CODE_SUCCESS: String = "SUCCESS"
const CODE_ITEM_NULL: String = "ITEM_NULL"
const CODE_CONSUMABLE_UNKNOWN: String = "CONSUMABLE_UNKNOWN"
const CODE_ITEM_NOT_EQUIPPABLE: String = "ITEM_NOT_EQUIPPABLE"
const CODE_ITEM_UNIQUE: String = "ITEM_UNIQUE"
const CODE_ITEM_SEALED: String = "ITEM_SEALED"
const CODE_SLOTS_FULL: String = "SLOTS_FULL"
const CODE_REQUIRES_NORMAL: String = "REQUIRES_NORMAL"
const CODE_REQUIRES_UNCOMMON: String = "REQUIRES_UNCOMMON"
const CODE_REQUIRES_MAGIC_OR_RARE: String = "REQUIRES_MAGIC_OR_RARE"
const CODE_REQUIRES_AT_LEAST_ONE_AFFIX: String = "REQUIRES_AT_LEAST_ONE_AFFIX"
const CODE_REQUIRES_RARE_FOR_VERDICT: String = "REQUIRES_RARE_FOR_VERDICT"
const CODE_NO_ELIGIBLE_AFFIXES: String = "NO_ELIGIBLE_AFFIXES"
const CODE_INVALID_PRESERVE_TARGET: String = "INVALID_PRESERVE_TARGET"


static func check_eligibility(
	item: ItemInstance,
	consumable_id: String,
	options: Dictionary = {}
) -> Dictionary:
	var res := {
		"can_craft": false,
		"code": CODE_ITEM_NULL,
		"reason": "Nenhum equipamento selecionado.",
		"action_name": "",
		"description": "",
		"target_rarity_after": ItemInstance.ItemRarity.NORMAL,
		"allowed_kinds": [] # Array[int]: AffixType.PREFIX / SUFFIX
	}

	if item == null:
		return res

	if item.definition == null or not item.definition.is_equippable():
		res["code"] = CODE_ITEM_NOT_EQUIPPABLE
		res["reason"] = "O item selecionado não é um equipamento modificável."
		return res

	if item.rarity == ItemInstance.ItemRarity.UNIQUE:
		res["code"] = CODE_ITEM_UNIQUE
		res["reason"] = "Itens Únicos possuem propriedades especiais fixas e não aceitam escrituras de crafting."
		return res

	if item.is_sealed():
		res["code"] = CODE_ITEM_SEALED
		res["reason"] = "Este equipamento está Lacrado pelo Veredito. Nenhuma operação de escrita ou rasura é mais permitida."
		return res

	match consumable_id:
		"scroll_first_mark":
			return _check_first_mark(item)
		"scroll_counterseal":
			return _check_counterseal(item)
		"scroll_golden_clause":
			return _check_golden_clause(item)
		"stone_eraser":
			return _check_stone_eraser(item)
		"stone_verdict":
			return _check_stone_verdict(item, options)
		_:
			res["code"] = CODE_CONSUMABLE_UNKNOWN
			res["reason"] = "Consumível de crafting desconhecido: '%s'." % consumable_id
			return res


static func _check_first_mark(item: ItemInstance) -> Dictionary:
	var res := {
		"can_craft": false,
		"code": CODE_REQUIRES_NORMAL,
		"reason": "",
		"action_name": "Inscrição da Primeira Marca",
		"description": "Escreve o primeiro atributo explícito do item, tornando-o Incomum (Verde).",
		"target_rarity_after": ItemInstance.ItemRarity.UNCOMMON,
		"allowed_kinds": [ItemAffix.AffixType.PREFIX, ItemAffix.AffixType.SUFFIX]
	}

	# Requer Branco (NORMAL) com 0 afixos
	if item.rarity != ItemInstance.ItemRarity.NORMAL or not item.explicit_affixes.is_empty():
		res["reason"] = "A Primeira Marca só pode ser inscrita em equipamentos normais (brancos, sem afixos)."
		return res

	# Checar se há famílias elegíveis de prefixo ou sufixo
	var cat: int = item.definition.category
	var ilvl: int = maxi(1, item.item_level)
	var has_prefix: bool = not LootGenerationService.get_eligible_affix_families(ItemAffix.AffixType.PREFIX, cat, ilvl).is_empty()
	var has_suffix: bool = not LootGenerationService.get_eligible_affix_families(ItemAffix.AffixType.SUFFIX, cat, ilvl).is_empty()

	if not has_prefix and not has_suffix:
		res["code"] = CODE_NO_ELIGIBLE_AFFIXES
		res["reason"] = "Não existem afixos elegíveis para esta categoria de item no nível %d." % ilvl
		return res

	res["can_craft"] = true
	res["code"] = CODE_SUCCESS
	res["reason"] = "Pronto para inscrever o primeiro atributo."
	return res


static func _check_counterseal(item: ItemInstance) -> Dictionary:
	var res := {
		"can_craft": false,
		"code": CODE_REQUIRES_UNCOMMON,
		"reason": "",
		"action_name": "Inscrição do Contrasselo",
		"description": "Inscreve o contraponto oposto que falta ao equipamento, tornando-o Mágico (Azul 1P+1S).",
		"target_rarity_after": ItemInstance.ItemRarity.MAGIC,
		"allowed_kinds": []
	}

	# Requer Verde (UNCOMMON) com exatamente 1 afixo
	if item.rarity != ItemInstance.ItemRarity.UNCOMMON or item.explicit_affixes.size() != 1:
		res["reason"] = "O Contrasselo requer um equipamento incomum (verde) com exatamente 1 atributo explícito."
		return res

	var existing_affix: ItemAffix = item.explicit_affixes[0]
	var needed_kind: int = ItemAffix.AffixType.SUFFIX if existing_affix.affix_type == ItemAffix.AffixType.PREFIX else ItemAffix.AffixType.PREFIX
	res["allowed_kinds"] = [needed_kind]

	var used_exclusive: Dictionary = {existing_affix.exclusion_group: true}
	var used_families: Dictionary = {existing_affix.affix_id: true}
	var eligible: Array[Dictionary] = LootGenerationService.get_eligible_affix_families(
		needed_kind, item.definition.category, maxi(1, item.item_level), used_exclusive, used_families
	)

	if eligible.is_empty():
		res["code"] = CODE_NO_ELIGIBLE_AFFIXES
		res["reason"] = "Não existem afixos elegíveis do lado oposto (%s) para complementar este item." % ("Sufixo" if needed_kind == ItemAffix.AffixType.SUFFIX else "Prefixo")
		return res

	res["can_craft"] = true
	res["code"] = CODE_SUCCESS
	res["reason"] = "Pronto para inscrever o %s complementar." % ("Sufixo" if needed_kind == ItemAffix.AffixType.SUFFIX else "Prefixo")
	return res


static func _check_golden_clause(item: ItemInstance) -> Dictionary:
	var res := {
		"can_craft": false,
		"code": CODE_REQUIRES_MAGIC_OR_RARE,
		"reason": "",
		"action_name": "Inscrição da Cláusula Áurea",
		"description": "Inaugura ou completa a escrita rara, adicionando o 3º ou 4º atributo explícito (máx 2P+2S).",
		"target_rarity_after": ItemInstance.ItemRarity.RARE,
		"allowed_kinds": []
	}

	var p_count: int = item.get_prefix_count()
	var s_count: int = item.get_suffix_count()
	var total_mods: int = item.explicit_affixes.size()

	# Se já atingiu 4 mods (2P+2S)
	if total_mods >= 4 or (p_count >= 2 and s_count >= 2):
		res["code"] = CODE_SLOTS_FULL
		res["reason"] = "O equipamento já possui o limite máximo de 4 atributos explícitos (2 prefixos e 2 sufixos)."
		return res

	# Estados válidos:
	# 1. Azul Mágico com 2 afixos (1P+1S)
	# 2. Amarelo Raro com 3 afixos (2P+1S ou 1P+2S)
	# 3. Amarelo Raro em reconstrução com 2 afixos (2P+0S ou 0P+2S)
	var is_valid_blue: bool = (item.rarity == ItemInstance.ItemRarity.MAGIC and total_mods == 2 and p_count == 1 and s_count == 1)
	var is_valid_rare_3: bool = (item.rarity == ItemInstance.ItemRarity.RARE and total_mods == 3)
	var is_valid_rare_recon: bool = (item.rarity == ItemInstance.ItemRarity.RARE and item.is_reconstructing() and total_mods == 2)

	if not is_valid_blue and not is_valid_rare_3 and not is_valid_rare_recon:
		res["code"] = CODE_REQUIRES_MAGIC_OR_RARE
		res["reason"] = "A Cláusula Áurea requer um equipamento Mágico (azul com 2 atributos) ou Raro (amarelo com menos de 4 atributos)."
		return res

	var allowed: Array[int] = []
	if p_count < 2:
		allowed.append(ItemAffix.AffixType.PREFIX)
	if s_count < 2:
		allowed.append(ItemAffix.AffixType.SUFFIX)
	res["allowed_kinds"] = allowed

	# Verificar se há afixos elegíveis para os lados permitidos
	var used_exclusive: Dictionary = {}
	var used_families: Dictionary = {}
	for af in item.explicit_affixes:
		if af != null:
			used_exclusive[af.exclusion_group] = true
			used_families[af.affix_id] = true

	var cat: int = item.definition.category
	var ilvl: int = maxi(1, item.item_level)
	var has_viable_candidate: bool = false
	for kind in allowed:
		var fams: Array[Dictionary] = LootGenerationService.get_eligible_affix_families(
			kind, cat, ilvl, used_exclusive, used_families
		)
		if not fams.is_empty():
			has_viable_candidate = true
			break

	if not has_viable_candidate:
		res["code"] = CODE_NO_ELIGIBLE_AFFIXES
		res["reason"] = "Não existem afixos elegíveis para preencher as cláusulas restantes deste equipamento."
		return res

	res["can_craft"] = true
	res["code"] = CODE_SUCCESS
	if is_valid_blue:
		res["reason"] = "Elevará o equipamento para Raro (Amarelo) adicionando o 3º atributo."
	elif is_valid_rare_recon:
		res["reason"] = "Completará a reconstrução adicionando o %s que falta." % ("Sufixo" if p_count == 2 else "Prefixo")
	else:
		res["reason"] = "Completará o equipamento Raro com o 4º atributo (%s)." % ("Sufixo" if p_count == 2 else "Prefixo")
	return res


static func _check_stone_eraser(item: ItemInstance) -> Dictionary:
	var res := {
		"can_craft": false,
		"code": CODE_REQUIRES_AT_LEAST_ONE_AFFIX,
		"reason": "",
		"action_name": "Rasura Arcana",
		"description": "Apaga um atributo explícito aleatório (probabilidade uniforme 1/N), liberando espaço para nova inscrição.",
		"target_rarity_after": item.rarity,
		"allowed_kinds": []
	}

	if item.explicit_affixes.is_empty():
		res["reason"] = "O equipamento não possui nenhum atributo explícito para ser apagado."
		return res

	# Previsão da raridade após a rasura
	var count_after: int = item.explicit_affixes.size() - 1
	if count_after == 0:
		res["target_rarity_after"] = ItemInstance.ItemRarity.NORMAL
	elif count_after == 1:
		res["target_rarity_after"] = ItemInstance.ItemRarity.UNCOMMON
	elif count_after == 2:
		# Se o item era raro 3 (ex: 2P+1S), remover o sufixo deixa 2P+0S (Raro em reconstrução), enquanto remover um prefixo deixa 1P+1S (Azul)
		res["target_rarity_after"] = ItemInstance.ItemRarity.MAGIC
	else:
		res["target_rarity_after"] = ItemInstance.ItemRarity.RARE

	res["can_craft"] = true
	res["code"] = CODE_SUCCESS
	res["reason"] = "Atenção: A Rasura selecionará 1 atributo aleatório entre os %d existentes. O risco é real." % item.explicit_affixes.size()
	return res


static func _check_stone_verdict(item: ItemInstance, options: Dictionary = {}) -> Dictionary:
	var res := {
		"can_craft": false,
		"code": CODE_REQUIRES_RARE_FOR_VERDICT,
		"reason": "",
		"action_name": "Sentença do Veredito",
		"description": "Aplica uma transformação irreversível de alto risco e lacra o equipamento permanentemente.",
		"target_rarity_after": item.rarity,
		"allowed_kinds": []
	}

	# Requer Raro (Amarelo) com 3 ou 4 afixos (ou 2 em reconstrução)
	if item.rarity != ItemInstance.ItemRarity.RARE or item.explicit_affixes.size() < 2:
		res["reason"] = "O Veredito só pode ser sentenciado sobre equipamentos Raros (amarelos com 3 ou 4 atributos)."
		return res

	var mode: String = String(options.get("intent", options.get("verdict_mode", "rewrite"))).to_lower().strip_edges()
	if mode == "preserve":
		var target_idx: int = int(options.get("preserve_affix_index", -1))
		if target_idx < 0 or target_idx >= item.explicit_affixes.size():
			res["code"] = CODE_INVALID_PRESERVE_TARGET
			res["reason"] = "A intenção 'Conservar' exige a seleção de exatamente 1 atributo para ser protegido."
			return res

	res["can_craft"] = true
	res["code"] = CODE_SUCCESS
	res["reason"] = "⚠ O Veredito é IRREVERSÍVEL. O equipamento será LACRADO e nunca mais aceitará alterações."
	return res
