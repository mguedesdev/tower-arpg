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
## SORTEIO EM TRÊS ETAPAS INDEPENDENTES (FAMÍLIA -> TIER -> VALOR) (Seções 7, 8 e 10)
## ---------------------------------------------------------------------------
## Etapa A: Filtrar famílias elegíveis para (kind, category, ilvl, used_exclusive_groups) e sortear por `family_weight`.
## Etapa B: Filtrar tiers da família onde `ilvl >= min_ilvl` e sortear por `tier.weight` (T1 = melhor, maior = pior).
## Etapa C: Sortear valor inclusivo entre `min_value` e `max_value` respeitando `roll_step`.

static func get_eligible_affix_families(
	target_kind: int,
	item_category: int,
	ilvl: int,
	used_exclusive_groups: Dictionary = {},
	used_family_ids: Dictionary = {}
) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for fam in LootBalanceConfig.get_affix_families():
		if int(fam.get("kind", -1)) != target_kind:
			continue
		var valid_cats: Array = fam.get("valid_categories", [])
		if not valid_cats.has(item_category):
			continue
		var f_id: String = String(fam.get("id", ""))
		if used_family_ids.has(f_id):
			continue
		var group_key: String = String(fam.get("exclusive_group", f_id))
		if used_exclusive_groups.has(group_key):
			continue
		var valid_tiers: Array[Dictionary] = LootBalanceConfig.get_eligible_tiers_for_family(fam, ilvl)
		if valid_tiers.is_empty():
			continue
		eligible.append(fam)
	return eligible

## Monta o layout viável de slots (PREFIX / SUFFIX) antes da rolagem, garantindo que nenhuma vaga fique sem candidatos
## e respeitando as cotas da raridade (Verde = 1P ou 1S; Azul = 1P + 1S; Amarelo = 3-4 afixos com máx 2P + 2S).
static func _build_viable_affix_slot_layout(
	item_category: int,
	ilvl: int,
	target_count: int,
	max_prefixes: int,
	max_suffixes: int,
	rng: RandomNumberGenerator = null
) -> Array[int]:
	var P: int = ItemAffix.AffixType.PREFIX
	var S: int = ItemAffix.AffixType.SUFFIX

	# Conta quantas famílias distintas por exclusive_group existem para PREFIX e SUFFIX nesta categoria/ilvl
	var pref_groups: Dictionary = {}
	var suff_groups: Dictionary = {}
	for fam in LootBalanceConfig.get_affix_families():
		var valid_cats: Array = fam.get("valid_categories", [])
		if not valid_cats.has(item_category):
			continue
		if LootBalanceConfig.get_eligible_tiers_for_family(fam, ilvl).is_empty():
			continue
		var grp: String = String(fam.get("exclusive_group", fam.get("id", "")))
		if int(fam.get("kind", -1)) == P:
			pref_groups[grp] = true
		elif int(fam.get("kind", -1)) == S:
			suff_groups[grp] = true

	var cap_p: int = mini(max_prefixes, pref_groups.size())
	var cap_s: int = mini(max_suffixes, suff_groups.size())
	var max_viable_total: int = cap_p + cap_s
	var final_total: int = mini(target_count, max_viable_total)

	# Se um item Amarelo (RARE) pediu 4 afixos mas a categoria só possui 1 família de prefixo + 2 de sufixos (ex.: Anéis/Amuletos),
	# gera 3 afixos válidos (1P + 2S), cumprindo a regra de 3–4 afixos de Amarelo sem erro nem slot vazio!
	var layout: Array[int] = []
	if final_total <= 0:
		return layout

	if final_total == 1:
		if cap_p > 0 and cap_s > 0:
			var pick_p: bool = (rng.randf() if rng != null else randf()) < 0.5
			layout.append(P if pick_p else S)
		elif cap_p > 0:
			layout.append(P)
		else:
			layout.append(S)
		return layout

	if final_total == 2:
		if cap_p >= 1 and cap_s >= 1:
			layout = [P, S]
		elif cap_p >= 2:
			layout = [P, P]
		elif cap_s >= 2:
			layout = [S, S]
		elif cap_p == 1:
			layout = [P]
		elif cap_s == 1:
			layout = [S]
		return layout

	# Para 3 ou 4 afixos (Amarelo / RARE):
	var min_p: int = maxi(0, final_total - cap_s)
	var max_p: int = mini(cap_p, final_total)
	var chosen_p: int = min_p
	if max_p > min_p:
		chosen_p = rng.randi_range(min_p, max_p) if rng != null else randi_range(min_p, max_p)
	var chosen_s: int = final_total - chosen_p

	for _i in range(chosen_p):
		layout.append(P)
	for _j in range(chosen_s):
		layout.append(S)
	return layout

## Sorteia um único afixo diretamente de uma família específica (usado na Etapa B+C e nos testes de 100.000 sorteios da Seção 16)
static func roll_single_affix_from_family(
	family: Dictionary,
	ilvl: int,
	rng: RandomNumberGenerator = null
) -> ItemAffix:
	if family.is_empty():
		return null
	var eligible_tiers: Array[Dictionary] = LootBalanceConfig.get_eligible_tiers_for_family(family, maxi(1, ilvl))
	if eligible_tiers.is_empty():
		return null

	# Etapa B: Sorteio ponderado do tier usando os pesos da própria família
	var tier_weights: Array[float] = []
	for t_entry in eligible_tiers:
		tier_weights.append(float(t_entry.get("weight", 1.0)))
	var chosen_t_idx: int = LootBalanceConfig.roll_weighted_index(tier_weights, rng)
	var chosen_tier: Dictionary = eligible_tiers[chosen_t_idx]

	# Etapa C: Sorteio do valor entre min_value e max_value (inclusivo) respeitando roll_step
	var min_v: float = float(chosen_tier.get("min_value", 0.0))
	var max_v: float = float(chosen_tier.get("max_value", min_v))
	var step: float = maxf(0.0001, float(family.get("roll_step", 1.0)))
	var total_steps: int = maxi(0, int(round((max_v - min_v) / step)))
	var step_pick: int = rng.randi_range(0, total_steps) if rng != null else randi_range(0, total_steps)
	var rolled_val: float = snappedf(min_v + float(step_pick) * step, step)
	rolled_val = clampf(rolled_val, min_v, max_v)

	var f_id: String = String(family.get("id", ""))
	var f_kind: int = int(family.get("kind", ItemAffix.AffixType.PREFIX))
	var f_stat: String = String(family.get("stat_id", ""))
	var f_group: String = String(family.get("exclusive_group", f_stat))
	var tier_num: int = int(chosen_tier.get("tier", 1))
	var tier_min_ilvl: int = int(chosen_tier.get("min_ilvl", 1))
	var display_text: String = LootBalanceConfig.format_affix_value_text(family, rolled_val)

	return ItemAffix.create(
		f_id,
		f_kind as ItemAffix.AffixType,
		f_stat,
		rolled_val,
		display_text,
		tier_num,
		tier_min_ilvl,
		f_group,
		min_v,
		max_v
	)

static func _roll_random_affixes_onto_item(
	item: ItemInstance,
	target_count: int,
	max_prefixes: int,
	max_suffixes: int,
	rng: RandomNumberGenerator = null
) -> void:
	if item == null or item.definition == null:
		return
	var item_cat: int = item.definition.category
	var ilvl: int = maxi(1, item.item_level)

	var slot_layout: Array[int] = _build_viable_affix_slot_layout(
		item_cat, ilvl, target_count, max_prefixes, max_suffixes, rng
	)
	var used_exclusive_groups: Dictionary = {}
	var used_family_ids: Dictionary = {}

	for kind_slot in slot_layout:
		# Etapa A: Selecionar família elegível para a vaga (PREFIX ou SUFFIX)
		var eligible_families: Array[Dictionary] = get_eligible_affix_families(
			kind_slot, item_cat, ilvl, used_exclusive_groups, used_family_ids
		)
		if eligible_families.is_empty():
			# Fallback seguro caso a combinação tenha esgotado o tipo primário: tenta o tipo complementar dentro do limite global
			var alt_kind: int = ItemAffix.AffixType.SUFFIX if kind_slot == ItemAffix.AffixType.PREFIX else ItemAffix.AffixType.PREFIX
			eligible_families = get_eligible_affix_families(
				alt_kind, item_cat, ilvl, used_exclusive_groups, used_family_ids
			)
			if eligible_families.is_empty():
				break

		var fam_weights: Array[float] = []
		for fam in eligible_families:
			fam_weights.append(float(fam.get("family_weight", 10.0)))
		var chosen_fam_idx: int = LootBalanceConfig.roll_weighted_index(fam_weights, rng)
		var chosen_family: Dictionary = eligible_families[chosen_fam_idx]

		# Etapas B e C: Selecionar tier elegível da família e valor dentro da faixa do tier
		var rolled_affix: ItemAffix = roll_single_affix_from_family(chosen_family, ilvl, rng)
		if rolled_affix == null:
			continue

		used_exclusive_groups[rolled_affix.exclusion_group] = true
		used_family_ids[rolled_affix.affix_id] = true
		item.explicit_affixes.append(rolled_affix)
