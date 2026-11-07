extends RefCounted
class_name LootGenerationService

## ===========================================================================
## SERVICO DE GERACAO DE LOOT PROGRESSIVO EM 7 ETAPAS SEPARADAS (ATO 1)
## ===========================================================================
## Etapas desacopladas conforme arquitetura ARPG:
## 1. stage1_should_drop_equipment()  -> Verifica se o inimigo derrubara equipamentos
## 2. stage2_roll_drop_count()        -> Determina quantos equipamentos serao gerados
## 3. stage3_select_valid_base_item() -> Seleciona um item-base valido para o nivel e regiao
## 4. stage4_roll_item_rarity()       -> Sorteia a raridade usando pesos por nivel e classificacao
## 5. stage5_determine_item_level()   -> Define o nivel do item (ilvl) conforme regras de loot
## 6. stage6_roll_affixes()           -> Sorteia prefixos, sufixos e valores compativeis com item e ilvl
## 7. stage7_create_final_instance()  -> Cria a instancia final pronta para o sistema de drops

static var _cached_affix_pool: Array[Dictionary] = []

static func _ensure_affix_pool() -> void:
	if _cached_affix_pool.is_empty():
		_cached_affix_pool = LootBalanceConfig.get_progressive_affix_pool()

## ---------------------------------------------------------------------------
## ETAPA 1: Verificar se o inimigo derrubara equipamentos
## ---------------------------------------------------------------------------
static func stage1_should_drop_equipment(
	monster_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	rng: RandomNumberGenerator = null
) -> bool:
	var drop_chance: float = LootBalanceConfig.get_equipment_drop_chance(monster_level, monster_class)
	var roll: float = rng.randf() if rng != null else randf()
	return roll <= drop_chance

## ---------------------------------------------------------------------------
## ETAPA 2: Determinar quantos equipamentos serao gerados, quando aplicavel
## ---------------------------------------------------------------------------
static func stage2_roll_drop_count(
	monster_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	rng: RandomNumberGenerator = null
) -> int:
	var weights: Array[float] = LootBalanceConfig.get_drop_count_weights(monster_level, monster_class)
	var idx: int = LootBalanceConfig.roll_weighted_index(weights, rng)
	return idx + 1

## ---------------------------------------------------------------------------
## ETAPA 3: Selecionar um item-base valido para o nivel e a regiao
## ---------------------------------------------------------------------------
static func stage3_select_valid_base_item(
	monster_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	region_id: String = "act1",
	rng: RandomNumberGenerator = null
) -> ItemDefinition:
	var effective_ilvl: int = LootBalanceConfig.get_effective_item_level(monster_level, monster_class)
	var valid_defs: Array[ItemDefinition] = []
	var weights: Array[float] = []

	for item_id in ItemDatabase.get_act1_equipment_ids():
		var def: ItemDefinition = ItemDatabase.get_definition(item_id)
		if def == null or not def.is_equippable():
			continue
		# Respeita nivel minimo do item-base para que monstros de nivel 1 nao gerem bases incompativeis
		if def.base_item_level > effective_ilvl and def.req_level > effective_ilvl:
			continue
		valid_defs.append(def)
		var base_weight: float = 10.0
		if def.suggested_source == "recompensa_unica_chefe_ou_evento":
			base_weight = 4.5
		weights.append(base_weight)

	if valid_defs.is_empty():
		return ItemDatabase.get_definition("sword_steel")

	var chosen_idx: int = LootBalanceConfig.roll_weighted_index(weights, rng)
	return valid_defs[chosen_idx]

## ---------------------------------------------------------------------------
## ETAPA 4: Sortear a raridade usando pesos influenciados por nivel e classificacao
## ---------------------------------------------------------------------------
static func stage4_roll_item_rarity(
	monster_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	base_def: ItemDefinition = null,
	rng: RandomNumberGenerator = null
) -> ItemInstance.ItemRarity:
	var effective_ilvl: int = LootBalanceConfig.get_effective_item_level(monster_level, monster_class)
	var allow_unique: bool = effective_ilvl >= LootBalanceConfig.MIN_ILVL_FOR_UNIQUE
	if base_def != null and base_def.base_item_level > effective_ilvl:
		allow_unique = false

	var weights: Array[float] = LootBalanceConfig.get_rarity_weights(monster_level, monster_class, allow_unique)
	var rarity_idx: int = LootBalanceConfig.roll_weighted_index(weights, rng)
	match rarity_idx:
		0:
			return ItemInstance.ItemRarity.NORMAL
		1:
			return ItemInstance.ItemRarity.UNCOMMON
		2:
			return ItemInstance.ItemRarity.MAGIC
		3:
			return ItemInstance.ItemRarity.RARE
		4:
			return ItemInstance.ItemRarity.UNIQUE
		_:
			return ItemInstance.ItemRarity.NORMAL

## ---------------------------------------------------------------------------
## ETAPA 5: Definir o nivel do item (ilvl) conforme as regras de loot
## ---------------------------------------------------------------------------
static func stage5_determine_item_level(
	monster_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	base_def: ItemDefinition = null
) -> int:
	var raw_ilvl: int = LootBalanceConfig.get_effective_item_level(monster_level, monster_class)
	if base_def != null:
		return maxi(base_def.base_item_level, raw_ilvl)
	return maxi(1, raw_ilvl)

## ---------------------------------------------------------------------------
## ETAPA 6: Sortear prefixos, sufixos e valores compativeis com o item e seu nivel
## ---------------------------------------------------------------------------
## Regras de modificadores por raridade:
## - Branco (NORMAL):   0 modificadores aleatorios
## - Verde (UNCOMMON):  1 modificador aleatorio (prefixo ou sufixo)
## - Azul (MAGIC):      2 modificadores aleatorios (ate 1 prefixo + 1 sufixo)
## - Amarelo (RARE):    3 a 4 modificadores aleatorios (ate 2 prefixos + 2 sufixos)
## - Vermelho (UNIQUE): propriedades especiais fixas predefinidas (sem afixos aleatorios)
## Propriedades intrinsecas (implicit_affixes) permanecem na definicao e NUNCA sao contadas nem duplicadas.
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
			for fixed_affix in item.definition.unique_fixed_affixes:
				if fixed_affix != null:
					item.explicit_affixes.append(fixed_affix.duplicate_affix())
			return
		ItemInstance.ItemRarity.UNCOMMON:
			_roll_random_affixes_onto_item(item, 1, 1, 1, rng)
		ItemInstance.ItemRarity.MAGIC:
			_roll_random_affixes_onto_item(item, 2, 1, 1, rng)
		ItemInstance.ItemRarity.RARE:
			var four_mod_chance: float = LootBalanceConfig.get_rare_four_mod_chance(item.item_level)
			var roll: float = rng.randf() if rng != null else randf()
			var target_mods: int = 4 if roll < four_mod_chance else 3
			_roll_random_affixes_onto_item(item, target_mods, 2, 2, rng)

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

	# Se a raridade sorteada for UNIQUE (Vermelho), garante que o item-base possua variante unica cadastrada
	if rarity == ItemInstance.ItemRarity.UNIQUE and resolved_def.unique_fixed_affixes.is_empty():
		var unique_def: ItemDefinition = ItemDatabase.get_unique_eligible_definition(item_level, rng)
		if unique_def != null:
			resolved_def = unique_def
		else:
			rarity = ItemInstance.ItemRarity.RARE

	var final_ilvl: int = maxi(resolved_def.base_item_level, item_level)
	var instance := ItemInstance.new(resolved_def, rarity, final_ilvl)
	instance.is_identified = true
	# Mantem sempre o nome-base oficial sem concatenar afixos no nome
	instance.custom_name = ""

	stage6_roll_affixes(instance, rng)
	return instance

## ---------------------------------------------------------------------------
## PIPELINE COMPLETO DE DROP DE UM MONSTRO (EXECUTA AS 7 ETAPAS EM ORDEM)
## ---------------------------------------------------------------------------
static func generate_monster_loot_drops(
	monster_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	region_id: String = "act1",
	rng: RandomNumberGenerator = null
) -> Array[ItemInstance]:
	var drops: Array[ItemInstance] = []

	# Etapa 1: Verificar se o inimigo derrubara equipamentos
	if not stage1_should_drop_equipment(monster_level, monster_class, rng):
		return drops

	# Etapa 2: Determinar quantos equipamentos serao gerados
	var drop_count: int = stage2_roll_drop_count(monster_level, monster_class, rng)

	for _i in range(drop_count):
		var item: ItemInstance = generate_single_equipment_drop(monster_level, monster_class, region_id, rng)
		if item != null:
			drops.append(item)

	return drops

static func generate_single_equipment_drop(
	monster_level: int,
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	region_id: String = "act1",
	rng: RandomNumberGenerator = null
) -> ItemInstance:
	# Etapa 3: Selecionar um item-base valido para o nivel e a regiao
	var base_def: ItemDefinition = stage3_select_valid_base_item(monster_level, monster_class, region_id, rng)

	# Etapa 4: Sortear a raridade usando pesos influenciados pelo nivel e classificacao
	var rarity: ItemInstance.ItemRarity = stage4_roll_item_rarity(monster_level, monster_class, base_def, rng)

	# Etapa 5: Definir o nivel do item conforme as regras de loot
	var ilvl: int = stage5_determine_item_level(monster_level, monster_class, base_def)

	# Etapas 6 e 7: Sortear modificadores compativeis e criar a instancia final
	return stage7_create_final_instance(base_def, rarity, ilvl, rng)

## ---------------------------------------------------------------------------
## LOGICA INTERNA DE SORTEIO PONDERADO DE PREFIXOS E SUFIXOS POR ILVL
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

	var used_stats: Dictionary = {}
	var prefix_count: int = 0
	var suffix_count: int = 0

	for _step in range(target_count):
		var candidates: Array[Dictionary] = []
		var candidate_weights: Array[float] = []

		for entry in _cached_affix_pool:
			var min_req_ilvl: int = int(entry["min_ilvl"])
			# Impede que monstros fracos gerem afixos avancados incompativeis com o nivel do item
			if min_req_ilvl > ilvl:
				continue
			var slots: Array = entry["slots"]
			if not slots.has(item_cat):
				continue
			var stat_key: String = String(entry["stat"])
			if used_stats.has(stat_key):
				continue
			var affix_type: int = int(entry["type"])
			if affix_type == ItemAffix.AffixType.PREFIX and prefix_count >= max_prefixes:
				continue
			if affix_type == ItemAffix.AffixType.SUFFIX and suffix_count >= max_suffixes:
				continue

			var weight: float = float(entry["weight"])
			# Favorece tiers mais proximos do ilvl atual sem zerar tiers imediatamente inferiores
			var tier_distance: int = maxi(0, int((ilvl - min_req_ilvl) / 5.0))
			if tier_distance == 0:
				weight *= 1.35
			elif tier_distance == 1:
				weight *= 1.0
			else:
				weight *= maxf(0.25, 0.70 - float(tier_distance - 1) * 0.22)

			candidates.append(entry)
			candidate_weights.append(weight)

		# Fallback caso limites de prefixo/sufixo tenham restringido demais um slot especifico
		if candidates.is_empty():
			for entry in _cached_affix_pool:
				if int(entry["min_ilvl"]) > ilvl:
					continue
				var slots: Array = entry["slots"]
				if not slots.has(item_cat):
					continue
				var stat_key: String = String(entry["stat"])
				if used_stats.has(stat_key):
					continue
				candidates.append(entry)
				candidate_weights.append(float(entry["weight"]))

		if candidates.is_empty():
			break

		var chosen_idx: int = LootBalanceConfig.roll_weighted_index(candidate_weights, rng)
		var chosen: Dictionary = candidates[chosen_idx]
		var stat_name: String = String(chosen["stat"])
		used_stats[stat_name] = true

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
			int(chosen["min_ilvl"])
		)
		item.explicit_affixes.append(affix)
