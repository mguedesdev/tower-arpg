extends RefCounted
class_name LootGenerationService

## ===========================================================================
## SERVICO DE GERACAO DE LOOT PROGRESSIVO EM ETAPAS DESACOPLADAS (ATO 1 -> NV 100+)
## ===========================================================================
## Implementa o pipeline da especificacao `03_estudo_e_especificacao_loot_progressivo_ato1.md`:
## 1. stage1_should_drop_equipment()  -> Testa se uma tentativa de equipamento resulta em drop
## 2. stage2_roll_drop_count()        -> Determina quantas tentativas bem-sucedidas ocorrem na morte
## 3. stage3_select_valid_base_item() -> Seleciona item-base de equipamento valido para o ilvl/zona
## 4. stage4_roll_item_rarity()       -> Checa tabela especial de Unicos primeiro; senao sorteia Branco/Verde/Azul/Amarelo
## 5. stage5_determine_item_level()   -> Deriva ilvl do enemy_level (e rank_ilvl_bonus opcional)
## 6. stage6_roll_affixes()           -> Sorteia prefixos/sufixos por tier, exclusion_group e ilvl
## 7. stage7_create_final_instance()  -> Instancia o ItemInstance com nome-base preservado e IDs estaveis

static var _cached_affix_pool: Array[Dictionary] = []

static func _ensure_affix_pool() -> void:
	if _cached_affix_pool.is_empty():
		_cached_affix_pool = LootBalanceConfig.get_progressive_affix_pool()

## ---------------------------------------------------------------------------
## ETAPA 1: Verificar se uma tentativa de equipamento resulta em drop
## ---------------------------------------------------------------------------
static func stage1_should_drop_equipment(
	enemy_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	rng: RandomNumberGenerator = null
) -> bool:
	var p_drop_final: float = LootBalanceConfig.get_equipment_drop_chance(enemy_level, monster_class)
	var roll: float = rng.randf() if rng != null else randf()
	return roll <= p_drop_final

## ---------------------------------------------------------------------------
## ETAPA 2: Determinar quantas tentativas de equipamento ocorrem na morte
## ---------------------------------------------------------------------------
## Regra da Seção 5 e Seção 8:
## - Todo inimigo realiza 1 tentativa principal (que precisa passar por `stage1_should_drop_equipment`).
## - Inimigos com `extra_roll_chance > 0` (Raro = 15%, Chefe = 30%) podem ganhar +1 tentativa adicional,
##   que também passa independentemente pela sua regra de drop (`stage1_should_drop_equipment`).
static func stage2_roll_attempt_count(
	_enemy_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	rng: RandomNumberGenerator = null
) -> int:
	var attempts: int = 1
	var extra_chance: float = LootBalanceConfig.get_extra_roll_chance(monster_class)
	if extra_chance > 0.0:
		var r: float = rng.randf() if rng != null else randf()
		if r < extra_chance:
			attempts += 1
	return attempts

## Compatibilidade com chamadas que ja passaram pela Etapa 1 e querem saber quantos itens gerar:
## Como a 1ª tentativa ja teve sucesso, verifica se a tentativa extra (15% Raro / 30% Chefe) tambem ocorre e passa no drop!
static func stage2_roll_drop_count(
	enemy_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	rng: RandomNumberGenerator = null
) -> int:
	var count: int = 1
	var extra_chance: float = LootBalanceConfig.get_extra_roll_chance(monster_class)
	if extra_chance > 0.0:
		var r_extra: float = rng.randf() if rng != null else randf()
		if r_extra < extra_chance:
			if stage1_should_drop_equipment(enemy_level, monster_class, rng):
				count += 1
	return count

## ---------------------------------------------------------------------------
## ETAPA 3: Selecionar um item-base valido para o nivel e a regiao
## ---------------------------------------------------------------------------
static func stage3_select_valid_base_item(
	enemy_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	_region_id: String = "act1",
	rng: RandomNumberGenerator = null
) -> ItemDefinition:
	var effective_ilvl: int = stage5_determine_item_level(enemy_level, monster_class)
	var valid_defs: Array[ItemDefinition] = []
	var weights: Array[float] = []

	for item_id in ItemDatabase.get_act1_equipment_ids():
		var def: ItemDefinition = ItemDatabase.get_definition(item_id)
		if def == null or not def.is_equippable():
			continue
		# Respeita base_min_ilvl (base_item_level) para nao sortear bases acima do ilvl do monstro
		if def.base_item_level > effective_ilvl:
			continue
		valid_defs.append(def)
		var base_weight: float = 10.0
		if def.suggested_source == "recompensa_unica_chefe_ou_evento":
			base_weight = 5.0
		weights.append(base_weight)

	if valid_defs.is_empty():
		return ItemDatabase.get_definition("sword_steel")

	var chosen_idx: int = LootBalanceConfig.roll_weighted_index(weights, rng)
	return valid_defs[chosen_idx]

## ---------------------------------------------------------------------------
## ETAPA 4: Sortear a raridade (Checagem separada de Unico + Pesos Normalizados)
## ---------------------------------------------------------------------------
static func stage4_roll_item_rarity(
	enemy_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	base_def: ItemDefinition = null,
	rng: RandomNumberGenerator = null,
	zone_id: String = "act1",
	enemy_id: String = ""
) -> ItemInstance.ItemRarity:
	var ilvl: int = stage5_determine_item_level(enemy_level, monster_class, base_def)
	var pref_base: String = base_def.base_id if base_def != null else ""

	# 1. Checagem separada da tabela de Unicos elegiveis (Seção 7)
	var u_info: Dictionary = LootBalanceConfig.get_eligible_unique_definition_and_chance(
		ilvl, monster_class, pref_base, zone_id, enemy_id
	)
	if bool(u_info.get("eligible", false)):
		var u_chance: float = float(u_info.get("chance", 0.0))
		var u_roll: float = rng.randf() if rng != null else randf()
		if u_roll < u_chance:
			return ItemInstance.ItemRarity.UNIQUE

	# 2. Sorteio ponderado e normalizado entre Branco, Verde, Azul e Amarelo (Seção 4 e Seção 5)
	var non_uniq_weights: Array[float] = LootBalanceConfig.get_non_unique_rarity_weights(enemy_level, monster_class)
	var rarity_idx: int = LootBalanceConfig.roll_weighted_index(non_uniq_weights, rng)
	match rarity_idx:
		0:
			return ItemInstance.ItemRarity.NORMAL
		1:
			return ItemInstance.ItemRarity.UNCOMMON
		2:
			return ItemInstance.ItemRarity.MAGIC
		3:
			return ItemInstance.ItemRarity.RARE
		_:
			return ItemInstance.ItemRarity.NORMAL

## ---------------------------------------------------------------------------
## ETAPA 5: Definir o nivel do item (ilvl) conforme as regras de loot (Seção 6)
## ---------------------------------------------------------------------------
static func stage5_determine_item_level(
	enemy_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	_base_def: ItemDefinition = null,
	zone_max_ilvl: int = -1
) -> int:
	# Regra da Seção 6: `ilvl` deriva do nível do inimigo (e bônus opcional de rank se habilitado),
	# nunca do nível do personagem do jogador.
	return LootBalanceConfig.get_effective_item_level(enemy_level, monster_class, zone_max_ilvl)

## ---------------------------------------------------------------------------
## ETAPA 6: Sortear prefixos, sufixos e valores compativeis com o item e seu ilvl
## ---------------------------------------------------------------------------
static func stage6_roll_affixes(
	item: ItemInstance,
	rng: RandomNumberGenerator = null
) -> void:
	if item == null or item.definition == null:
		return
	item.explicit_affixes.clear()
	if not item.definition.is_equippable():
		return

	match item.rarity:
		ItemInstance.ItemRarity.NORMAL:
			return
		ItemInstance.ItemRarity.UNIQUE:
			_apply_unique_fixed_affixes(item)
			return
		ItemInstance.ItemRarity.UNCOMMON:
			# Verde: 1 afixo aleatorio (1 prefixo ou 1 sufixo)
			_roll_random_affixes_onto_item(item, 1, 1, 1, rng)
		ItemInstance.ItemRarity.MAGIC:
			# Azul: 2 afixos aleatorios, ate 1 prefixo e 1 sufixo
			_roll_random_affixes_onto_item(item, 2, 1, 1, rng)
		ItemInstance.ItemRarity.RARE:
			# Amarelo: 3-4 afixos aleatorios, limite de 2 prefixos e 2 sufixos
			var four_mod_chance: float = LootBalanceConfig.get_rare_four_mod_chance(item.item_level)
			var roll: float = rng.randf() if rng != null else randf()
			var target_mods: int = 4 if roll < four_mod_chance else 3
			_roll_random_affixes_onto_item(item, target_mods, 2, 2, rng)

static func _apply_unique_fixed_affixes(item: ItemInstance) -> void:
	# Busca definicao unica na tabela dedicada de Unicos pelo base_id
	for u_def in LootBalanceConfig.get_unique_item_definitions():
		if String(u_def.get("base_id", "")) == item.definition.base_id:
			item.unique_id = String(u_def.get("unique_id", ""))
			item.unique_display_name = String(u_def.get("display_name", item.definition.display_name))
			var fixed_list: Array = u_def.get("fixed_affixes", [])
			for fixed_af in fixed_list:
				if fixed_af is ItemAffix:
					item.explicit_affixes.append((fixed_af as ItemAffix).duplicate_affix())
			return

	# Fallback para unique_fixed_affixes registrados diretamente na definicao
	for fixed_affix in item.definition.unique_fixed_affixes:
		if fixed_affix != null:
			item.explicit_affixes.append(fixed_affix.duplicate_affix())

## ---------------------------------------------------------------------------
## ETAPA 7: Criar a instancia final e integra-la ao sistema de drops existente
## ---------------------------------------------------------------------------
static func stage7_create_final_instance(
	base_def: ItemDefinition,
	rarity: ItemInstance.ItemRarity,
	item_level: int,
	rng: RandomNumberGenerator = null
) -> ItemInstance:
	var resolved_def: ItemDefinition = base_def
	if resolved_def == null:
		resolved_def = ItemDatabase.get_definition("sword_steel")

	# Se a raridade sorteada for UNIQUE (Vermelho), garante que o item-base possua definicao Unica valida
	if rarity == ItemInstance.ItemRarity.UNIQUE and resolved_def.unique_fixed_affixes.is_empty():
		var unique_def: ItemDefinition = ItemDatabase.get_unique_eligible_definition(item_level, rng)
		if unique_def != null:
			resolved_def = unique_def
		else:
			rarity = ItemInstance.ItemRarity.RARE

	var final_ilvl: int = maxi(1, item_level)
	var instance := ItemInstance.new(resolved_def, rarity, final_ilvl)
	instance.is_identified = true
	instance.custom_name = ""

	stage6_roll_affixes(instance, rng)
	return instance

## ---------------------------------------------------------------------------
## PIPELINE COMPLETO DE DROP DE UM MONSTRO (EXECUTA TODAS AS ETAPAS)
## ---------------------------------------------------------------------------
static func generate_monster_loot_drops(
	enemy_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	zone_id: String = "act1",
	rng: RandomNumberGenerator = null,
	loot_profile: Dictionary = {}
) -> Array[ItemInstance]:
	var drops: Array[ItemInstance] = []
	var enemy_id: String = String(loot_profile.get("enemy_id", ""))
	var guaranteed_min: int = int(loot_profile.get("guaranteed_min_equipment_drops", 0))

	# Determina quantas tentativas de equipamento o inimigo possui (1 base + eventual extra_roll_chance)
	var attempts: int = stage2_roll_attempt_count(enemy_level, monster_class, rng)
	for _attempt_i in range(attempts):
		if stage1_should_drop_equipment(enemy_level, monster_class, rng):
			var item: ItemInstance = generate_single_equipment_drop(enemy_level, monster_class, zone_id, rng, enemy_id)
			if item != null:
				drops.append(item)

	# Suporte opcional a recompensa minima configurada para Chefe de encerramento de Ato (Seção 5, linha 143)
	while drops.size() < guaranteed_min:
		var guaranteed_item: ItemInstance = generate_single_equipment_drop(enemy_level, monster_class, zone_id, rng, enemy_id)
		if guaranteed_item == null:
			break
		drops.append(guaranteed_item)

	return drops

static func generate_single_equipment_drop(
	enemy_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	zone_id: String = "act1",
	rng: RandomNumberGenerator = null,
	enemy_id: String = ""
) -> ItemInstance:
	# Etapa 5: Definir o nivel do item (ilvl) a partir do nivel do inimigo
	var ilvl: int = stage5_determine_item_level(enemy_level, monster_class)

	# Etapa 4 (Parte A - Unicos): Verifica primeiro se um Unico elegivel foi sorteado na tabela especial
	var u_info: Dictionary = LootBalanceConfig.get_eligible_unique_definition_and_chance(
		ilvl, monster_class, "", zone_id, enemy_id
	)
	if bool(u_info.get("eligible", false)):
		var u_chance: float = float(u_info.get("chance", 0.0))
		var u_roll: float = rng.randf() if rng != null else randf()
		if u_roll < u_chance:
			var u_def_dict: Dictionary = u_info["unique_def"]
			var u_base_id: String = String(u_def_dict.get("base_id", "greatsword_iron"))
			var u_base_def: ItemDefinition = ItemDatabase.get_definition(u_base_id)
			return stage7_create_final_instance(u_base_def, ItemInstance.ItemRarity.UNIQUE, ilvl, rng)

	# Etapa 3: Selecionar um item-base valido para o nivel e a regiao
	var base_def: ItemDefinition = stage3_select_valid_base_item(enemy_level, monster_class, zone_id, rng)

	# Etapa 4 (Parte B - Padrao): Sorteia entre Branco, Verde, Azul e Amarelo com pesos normalizados
	var non_uniq_weights: Array[float] = LootBalanceConfig.get_non_unique_rarity_weights(enemy_level, monster_class)
	var rar_idx: int = LootBalanceConfig.roll_weighted_index(non_uniq_weights, rng)
	var rarity: ItemInstance.ItemRarity = ItemInstance.ItemRarity.NORMAL
	match rar_idx:
		0:
			rarity = ItemInstance.ItemRarity.NORMAL
		1:
			rarity = ItemInstance.ItemRarity.UNCOMMON
		2:
			rarity = ItemInstance.ItemRarity.MAGIC
		3:
			rarity = ItemInstance.ItemRarity.RARE

	# Etapas 6 e 7: Sortear modificadores compativeis e criar a instancia final
	return stage7_create_final_instance(base_def, rarity, ilvl, rng)

## ---------------------------------------------------------------------------
## SORTEIO PONDERADO DE AFIXOS COM EXCLUSION_GROUP, TIERS E RESTRICAO DE SLOT
## ---------------------------------------------------------------------------
static func _roll_random_affixes_onto_item(
	item: ItemInstance,
	target_count: int,
	max_prefixes: int,
	max_suffixes: int,
	rng: RandomNumberGenerator = null
) -> void:
	_ensure_affix_pool()
	var item_cat: int = item.definition.category
	var ilvl: int = maxi(1, item.item_level)
	var max_unlocked_tier: int = LootBalanceConfig.get_max_unlocked_affix_tier_for_ilvl(ilvl)

	var used_exclusion_groups: Dictionary = {}
	var prefix_count: int = 0
	var suffix_count: int = 0

	for _step in range(target_count):
		var candidates: Array[Dictionary] = []
		var candidate_weights: Array[float] = []

		for entry in _cached_affix_pool:
			var min_req_ilvl: int = int(entry["min_ilvl"])
			# Impede estritamente que monstros de nivel baixo gerem tiers de afixos acima do seu ilvl
			if min_req_ilvl > ilvl:
				continue
			var slots: Array = entry["slots"]
			if not slots.has(item_cat):
				continue
			var group_key: String = String(entry.get("group", entry["stat"]))
			if used_exclusion_groups.has(group_key):
				continue
			var affix_type: int = int(entry["type"])
			if affix_type == ItemAffix.AffixType.PREFIX and prefix_count >= max_prefixes:
				continue
			if affix_type == ItemAffix.AffixType.SUFFIX and suffix_count >= max_suffixes:
				continue

			var tier: int = int(entry["tier"])
			var weight: float = float(entry["weight"])
			# Pondera tiers disponiveis favorecendo tiers proximos ao topo desbloqueado pelo ilvl,
			# mas mantendo tiers anteriores possiveis (permitindo que um Azul com 2 rolls T3 altos supere um Amarelo com 3 rolls T1/T2 baixos)
			var tier_gap: int = maxi(0, max_unlocked_tier - tier)
			if tier_gap == 0:
				weight *= 1.40
			elif tier_gap == 1:
				weight *= 1.00
			else:
				weight *= maxf(0.22, 0.65 - float(tier_gap - 1) * 0.18)

			candidates.append(entry)
			candidate_weights.append(weight)

		if candidates.is_empty():
			break

		var chosen_idx: int = LootBalanceConfig.roll_weighted_index(candidate_weights, rng)
		var chosen: Dictionary = candidates[chosen_idx]
		var group_name: String = String(chosen.get("group", chosen["stat"]))
		var stat_name: String = String(chosen["stat"])
		used_exclusion_groups[group_name] = true

		var chosen_type: int = int(chosen["type"])
		if chosen_type == ItemAffix.AffixType.PREFIX:
			prefix_count += 1
		elif chosen_type == ItemAffix.AffixType.SUFFIX:
			suffix_count += 1

		var min_v: float = float(chosen["min"])
		var max_v: float = float(chosen["max"])
		var rolled_val: float = min_v
		var display_text: String = ""
		if stat_name == "crit_chance" or stat_name == "move_speed":
			var steps: int = maxi(1, int(round((max_v - min_v) * 100.0)))
			var step_pick: int = rng.randi_range(0, steps) if rng != null else randi_range(0, steps)
			rolled_val = snappedf(min_v + float(step_pick) * 0.01, 0.01)
			display_text = String(chosen["fmt"]) % int(roundi(rolled_val * 100.0))
		else:
			var min_i: int = int(round(min_v))
			var max_i: int = int(round(max_v))
			rolled_val = float(rng.randi_range(min_i, max_i) if rng != null else randi_range(min_i, max_i))
			display_text = String(chosen["fmt"]) % int(roundi(rolled_val))

		var affix := ItemAffix.create(
			String(chosen["id"]),
			chosen_type as ItemAffix.AffixType,
			stat_name,
			rolled_val,
			display_text,
			int(chosen["tier"]),
			int(chosen["min_ilvl"]),
			group_name,
			min_v,
			max_v
		)
		item.explicit_affixes.append(affix)
