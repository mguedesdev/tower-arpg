extends RefCounted
class_name LootBalanceConfig

## ===========================================================================
## CONFIGURACAO CENTRALIZADA E ORIENTADA A DADOS DO SISTEMA DE LOOT PROGRESSIVO
## ===========================================================================
## Inspirado em Path of Exile, Diablo II, Grim Dawn e Last Epoch.
## Projetado para o Ato 1 (niveis 1-25) e totalmente expansivel para o Endgame
## (niveis 40, 60, 80, 90, 100+) sem limites fixos no nivel 25.

const SCHEMA_VERSION: String = "loot_act1_v1_expandable"

## Classificacao (Rank) do inimigo — independente da raridade do equipamento.
enum MonsterClass {
	NORMAL = 0, ## Monstro comum, sem modificadores especiais
	MAGIC = 1,  ## Monstro aprimorado, com modificadores de combate
	RARE = 2,   ## Monstro poderoso, com multiplos modificadores
	BOSS = 3,   ## Chefe / inimigo especial
	HERO = 4,   ## Herói / Elite especial
}

## Marcos de nivel para interpolacao continua (cobre Ato 1: 1..25 e Endgame: 40..100+)
const KEYFRAME_LEVELS: Array[int] = [1, 5, 10, 15, 20, 25, 40, 60, 80, 90, 100]

## ---------------------------------------------------------------------------
## 1. PROBABILIDADE BASE DE TENTATIVA DE EQUIPAMENTO POR MORTE (MONSTRO NORMAL)
## ---------------------------------------------------------------------------
## Antes de aplicar o multiplicador de rank (Seção 4 e Seção 8 da especificação).
## Do nível 1 (8%) ao nível 25 (16%), desacelerando de forma controlada até o nível 100 (22.5%)
## para evitar inundação de tela no endgame quando a densidade de inimigos aumenta.
const BASE_EQUIPMENT_DROP_CHANCE_BY_LEVEL: Dictionary = {
	1:   0.080,
	5:   0.090,
	10:  0.100,
	15:  0.120,
	20:  0.140,
	25:  0.160,
	40:  0.180,
	60:  0.200,
	80:  0.210,
	90:  0.220,
	100: 0.225,
}
const MAX_ASYMPTOTIC_BASE_DROP_CHANCE: float = 0.240

## ---------------------------------------------------------------------------
## 2. MULTIPLICADORES DE RANK DO INIMIGO (Seção 5 e Seção 8)
## ---------------------------------------------------------------------------
## - drop_mult: multiplica a chance base de tentativa de equipamento (clamp 0..1)
## - magic_weight_mult: multiplica o peso da raridade Azul (MAGIC) antes de renormalizar
## - rare_weight_mult: multiplica o peso da raridade Amarela (RARE) antes de renormalizar
## - extra_roll_chance: chance de uma 2ª tentativa independente de equipamento
const ENEMY_RANK_CONFIG: Dictionary = {
	MonsterClass.NORMAL: {
		"id": "normal",
		"name": "Normal",
		"drop_mult": 1.00,
		"normal_weight_mult": 1.00,
		"uncommon_weight_mult": 1.00,
		"magic_weight_mult": 1.00,
		"rare_weight_mult": 1.00,
		"extra_roll_chance": 0.00,
	},
	MonsterClass.MAGIC: {
		"id": "magic",
		"name": "Mágico",
		"drop_mult": 1.50,
		"normal_weight_mult": 1.00,
		"uncommon_weight_mult": 1.00,
		"magic_weight_mult": 1.70,
		"rare_weight_mult": 2.00,
		"extra_roll_chance": 0.00,
	},
	MonsterClass.RARE: {
		"id": "rare",
		"name": "Raro",
		"drop_mult": 2.00,
		"normal_weight_mult": 1.00,
		"uncommon_weight_mult": 1.00,
		"magic_weight_mult": 2.60,
		"rare_weight_mult": 4.00,
		"extra_roll_chance": 0.15,
	},
	MonsterClass.BOSS: {
		"id": "boss",
		"name": "Chefe",
		"drop_mult": 3.00,
		"normal_weight_mult": 1.00,
		"uncommon_weight_mult": 1.00,
		"magic_weight_mult": 3.20,
		"rare_weight_mult": 6.00,
		"extra_roll_chance": 0.30,
	},
	MonsterClass.HERO: {
		"id": "hero",
		"name": "Herói/Elite",
		"drop_mult": 2.50,
		"normal_weight_mult": 1.00,
		"uncommon_weight_mult": 1.00,
		"magic_weight_mult": 2.90,
		"rare_weight_mult": 5.00,
		"extra_roll_chance": 0.22,
	},
}

## ---------------------------------------------------------------------------
## 3. PESOS BASE DE RARIDADE POR NIVEL DO MONSTRO (MONSTRO NORMAL)
## ---------------------------------------------------------------------------
## Ordem do vetor: [NORMAL (Branco), UNCOMMON (Verde), MAGIC (Azul), RARE (Amarelo)]
## Nota: Vermelho / Único NÃO entra nesta distribuição de 100%; é uma checagem separada
## restrita a tabelas de únicos elegíveis (Seção 4 e Seção 7).
## Nos níveis 40..100+, a curva apresenta retornos decrescentes para que itens Amarelos
## não se tornem excessivamente comuns no endgame.
const BASE_RARITY_WEIGHTS_BY_LEVEL: Dictionary = {
	1:   [85.00, 14.00,  0.95,  0.05],
	5:   [78.00, 19.00,  2.80,  0.20],
	10:  [70.00, 23.00,  6.00,  1.00],
	15:  [59.00, 26.00, 13.00,  2.00],
	20:  [47.00, 28.00, 21.00,  4.00],
	25:  [35.00, 28.00, 30.00,  7.00],
	40:  [26.00, 28.00, 36.00, 10.00],
	60:  [20.00, 26.00, 41.00, 13.00],
	80:  [16.00, 24.00, 44.50, 15.50],
	90:  [14.50, 23.00, 46.00, 16.50],
	100: [13.00, 22.00, 47.50, 17.50],
}

## ---------------------------------------------------------------------------
## 4. REGRAS DE NIVEL DO ITEM (ILVL) E BONUS OPCIONAL DE RANK (Seção 6)
## ---------------------------------------------------------------------------
## Na V1 do protótipo, `ilvl = enemy_level` (ENABLE_RANK_ILVL_BONUS = false) para não avançar
## além do nível da zona no Ato 1. O campo `RANK_ILVL_BONUS` já está preparado para ativação futura.
static var enable_rank_ilvl_bonus: bool = false

const RANK_ILVL_BONUS: Dictionary = {
	MonsterClass.NORMAL: 0,
	MonsterClass.MAGIC:  1,
	MonsterClass.RARE:   2,
	MonsterClass.HERO:   2,
	MonsterClass.BOSS:   2,
}

## Chance de um item Amarelo (RARE) sortear 4 afixos em vez de 3, escalando suavemente com ilvl.
const RARE_FOUR_MOD_CHANCE_BY_LEVEL: Dictionary = {
	1:   0.15,
	5:   0.20,
	10:  0.25,
	15:  0.30,
	20:  0.36,
	25:  0.42,
	40:  0.48,
	60:  0.52,
	80:  0.56,
	90:  0.58,
	100: 0.60,
}

## ---------------------------------------------------------------------------
## 5. TABELA DEDICADA DE EQUIPAMENTOS UNICOS / VERMELHOS (Seção 7 e Seção 8)
## ---------------------------------------------------------------------------
## Cada Único é uma definição própria associada a um `base_id`, com `unique_id`, nome próprio,
## `min_ilvl`, ranks elegíveis, zonas/inimigos elegíveis e chance específica na checagem separada.
const ENABLED_ONLY_FOR_ELIGIBLE_UNIQUE_TABLES: bool = true
const DEFAULT_GENERIC_UNIQUE_CHANCE: float = 0.0

static func get_unique_item_definitions() -> Array[Dictionary]:
	var A := ItemAffix.AffixType
	return [
		{
			"unique_id": "unique_crimson_runic_greatsword",
			"base_id": "greatsword_iron",
			"display_name": "Espada Grande Rúnica Carmesim",
			"min_ilvl": 3,
			"allowed_ranks": [MonsterClass.RARE, MonsterClass.BOSS],
			"allowed_zones": [],     # Vazio = qualquer zona elegível do Ato 1+ desde que ilvl >= 3
			"allowed_enemy_ids": [], # Vazio = qualquer inimigo dos ranks elegíveis
			"chance_by_rank": {
				MonsterClass.NORMAL: 0.0000,
				MonsterClass.MAGIC:  0.0000,
				MonsterClass.RARE:   0.0020, # 0.20% quando um Raro gera equipamento elegível
				MonsterClass.BOSS:   0.0100, # 1.00% quando um Chefe gera equipamento elegível
			},
			"max_endgame_chance_mult": 1.35, # Limita crescimento no endgame (nv 80-90+) para nunca banalizar únicos
			"fixed_affixes": [
				ItemAffix.create("uniq_gs_dmg",  A.UNIQUE_FIXED, "damage",      5.0,  "+5 de Dano",     1, 3, "flat_damage",     5.0,  5.0),
				ItemAffix.create("uniq_gs_str",  A.UNIQUE_FIXED, "strength",    2.0,  "+2 de Força",    1, 3, "attr_strength",   2.0,  2.0),
				ItemAffix.create("uniq_gs_hp",   A.UNIQUE_FIXED, "max_health",  10.0, "+10 de Vida",    1, 3, "flat_max_health", 10.0, 10.0),
				ItemAffix.create("uniq_gs_crit", A.UNIQUE_FIXED, "crit_chance", 0.03, "+3% de Crítico", 1, 3, "crit_chance",     0.03, 0.03),
			],
		}
	]

## ---------------------------------------------------------------------------
## 6. FAMÍLIAS E TIERS DE AFIXOS (CONVENÇÃO OBRIGATÓRIA: T1 = MELHOR, MAIOR = PIOR)
## ---------------------------------------------------------------------------
## Implementa a especificação `04_especificacao_prefixos_sufixos_tiers_afixos.md`:
## - Em TODAS as famílias, T1 (tier = 1) é o tier mais poderoso (maior min_ilvl).
## - O maior número de tier da família (ex.: T5 ou T6) é o mais fraco (min_ilvl = 1).
## - Não há obrigação de 5 degraus globais: `flat_damage` e `flat_max_health` possuem 6 tiers (T6→T1),
##   enquanto `attack_speed_pct`, `flat_armor`, atributos e `crit_chance` possuem 5 tiers (T5→T1).
## - Desbloquear tiers superiores NÃO elimina os tiers inferiores: o sorteio é ponderado pelos pesos
##   de cada tier elegível na família (ex.: em ilvl 80-90, T5 continua elegível e mais provável que T1).

## Limites de quantidade de prefixos e sufixos por raridade (Seção 5):
## - Branco (NORMAL):   0 afixos (0P, 0S)
## - Verde (UNCOMMON):  1 afixo  (1P ou 1S)
## - Azul (MAGIC):      2 afixos (máx 1P + 1S)
## - Amarelo (RARE):  3-4 afixos (máx 2P + 2S)
const RARITY_AFFIX_LIMITS: Dictionary = {
	ItemInstance.ItemRarity.NORMAL:   {"min_total": 0, "max_total": 0, "max_prefixes": 0, "max_suffixes": 0},
	ItemInstance.ItemRarity.UNCOMMON: {"min_total": 1, "max_total": 1, "max_prefixes": 1, "max_suffixes": 1},
	ItemInstance.ItemRarity.MAGIC:    {"min_total": 2, "max_total": 2, "max_prefixes": 1, "max_suffixes": 1},
	ItemInstance.ItemRarity.RARE:     {"min_total": 3, "max_total": 4, "max_prefixes": 2, "max_suffixes": 2},
	ItemInstance.ItemRarity.UNIQUE:   {"min_total": 0, "max_total": 0, "max_prefixes": 0, "max_suffixes": 0},
}

static var _cached_families: Array[Dictionary] = []
static var _cached_family_by_id: Dictionary = {}

static func _ensure_families_loaded() -> void:
	if not _cached_families.is_empty():
		return
	var C := ItemDefinition.ItemCategory
	var A := ItemAffix.AffixType
	var all_equip: Array[int] = [
		C.WEAPON_1H, C.WEAPON_2H, C.SHIELD, C.HELMET, C.CHEST,
		C.GLOVES, C.BOOTS, C.BELT, C.RING, C.AMULET
	]
	var weapons: Array[int] = [C.WEAPON_1H, C.WEAPON_2H]
	var armors: Array[int] = [C.SHIELD, C.HELMET, C.CHEST, C.GLOVES, C.BOOTS, C.BELT]
	var vitality_gear: Array[int] = [C.SHIELD, C.HELMET, C.CHEST, C.BELT, C.RING, C.AMULET, C.GLOVES, C.BOOTS]
	var crit_gear: Array[int] = [C.WEAPON_1H, C.WEAPON_2H, C.RING, C.AMULET, C.GLOVES]

	_cached_families = [
		# 1. PREFIXO: Velocidade de Ataque (5 tiers: T5 -> T1, contrato exato das Seções 3, 7, 9 e 16)
		{
			"id": "attack_speed_pct",
			"display_name": "Velocidade de Ataque",
			"kind": A.PREFIX,
			"stat_id": "attack_speed_pct",
			"value_kind": "percentage_fraction",
			"valid_categories": weapons,
			"exclusive_group": "attack_speed",
			"family_weight": 30.0,
			"roll_step": 0.01,
			"format_template": "+%d%% Velocidade de Ataque",
			"tiers": [
				{"tier": 5, "min_ilvl": 1,  "min_value": 0.01, "max_value": 0.05, "weight": 60.0},
				{"tier": 4, "min_ilvl": 15, "min_value": 0.06, "max_value": 0.09, "weight": 25.0},
				{"tier": 3, "min_ilvl": 30, "min_value": 0.10, "max_value": 0.14, "weight": 10.0},
				{"tier": 2, "min_ilvl": 55, "min_value": 0.15, "max_value": 0.19, "weight": 4.0},
				{"tier": 1, "min_ilvl": 75, "min_value": 0.20, "max_value": 0.25, "weight": 1.0},
			],
		},
		# 2. PREFIXO: Dano Físico Adicional (6 tiers: T6 -> T1, cobrindo Ato 1 [1, 8, 16, 24] e Endgame [50, 75])
		{
			"id": "flat_damage",
			"display_name": "Dano Físico",
			"kind": A.PREFIX,
			"stat_id": "damage",
			"value_kind": "integer",
			"valid_categories": weapons,
			"exclusive_group": "flat_damage",
			"family_weight": 45.0,
			"roll_step": 1.0,
			"format_template": "+%d de Dano",
			"tiers": [
				{"tier": 6, "min_ilvl": 1,  "min_value": 1.0,  "max_value": 3.0,  "weight": 55.0},
				{"tier": 5, "min_ilvl": 8,  "min_value": 4.0,  "max_value": 6.0,  "weight": 25.0},
				{"tier": 4, "min_ilvl": 16, "min_value": 7.0,  "max_value": 10.0, "weight": 12.0},
				{"tier": 3, "min_ilvl": 24, "min_value": 11.0, "max_value": 15.0, "weight": 5.0},
				{"tier": 2, "min_ilvl": 50, "min_value": 16.0, "max_value": 22.0, "weight": 2.0},
				{"tier": 1, "min_ilvl": 75, "min_value": 23.0, "max_value": 30.0, "weight": 1.0},
			],
		},
		# 3. PREFIXO: Armadura (5 tiers: T5 -> T1)
		{
			"id": "flat_armor",
			"display_name": "Armadura",
			"kind": A.PREFIX,
			"stat_id": "armor",
			"value_kind": "integer",
			"valid_categories": armors,
			"exclusive_group": "flat_armor",
			"family_weight": 45.0,
			"roll_step": 1.0,
			"format_template": "+%d de Armadura",
			"tiers": [
				{"tier": 5, "min_ilvl": 1,  "min_value": 2.0,  "max_value": 5.0,  "weight": 60.0},
				{"tier": 4, "min_ilvl": 12, "min_value": 6.0,  "max_value": 10.0, "weight": 25.0},
				{"tier": 3, "min_ilvl": 24, "min_value": 11.0, "max_value": 17.0, "weight": 10.0},
				{"tier": 2, "min_ilvl": 50, "min_value": 18.0, "max_value": 28.0, "weight": 4.0},
				{"tier": 1, "min_ilvl": 75, "min_value": 29.0, "max_value": 42.0, "weight": 1.0},
			],
		},
		# 4. PREFIXO: Vida Máxima (6 tiers: T6 -> T1, demonstrando família com mais degraus conforme Seção 3)
		{
			"id": "flat_max_health",
			"display_name": "Vida Máxima",
			"kind": A.PREFIX,
			"stat_id": "max_health",
			"value_kind": "integer",
			"valid_categories": vitality_gear,
			"exclusive_group": "flat_max_health",
			"family_weight": 50.0,
			"roll_step": 1.0,
			"format_template": "+%d de Vida",
			"tiers": [
				{"tier": 6, "min_ilvl": 1,  "min_value": 4.0,  "max_value": 8.0,  "weight": 55.0},
				{"tier": 5, "min_ilvl": 8,  "min_value": 9.0,  "max_value": 14.0, "weight": 25.0},
				{"tier": 4, "min_ilvl": 16, "min_value": 15.0, "max_value": 22.0, "weight": 12.0},
				{"tier": 3, "min_ilvl": 24, "min_value": 23.0, "max_value": 32.0, "weight": 5.0},
				{"tier": 2, "min_ilvl": 50, "min_value": 33.0, "max_value": 48.0, "weight": 2.0},
				{"tier": 1, "min_ilvl": 75, "min_value": 49.0, "max_value": 68.0, "weight": 1.0},
			],
		},
		# 5. SUFIXO: Força (5 tiers: T5 -> T1)
		{
			"id": "attr_strength",
			"display_name": "Força",
			"kind": A.SUFFIX,
			"stat_id": "strength",
			"value_kind": "integer",
			"valid_categories": all_equip,
			"exclusive_group": "attr_strength",
			"family_weight": 40.0,
			"roll_step": 1.0,
			"format_template": "+%d de Força",
			"tiers": [
				{"tier": 5, "min_ilvl": 1,  "min_value": 1.0,  "max_value": 2.0,  "weight": 60.0},
				{"tier": 4, "min_ilvl": 12, "min_value": 3.0,  "max_value": 5.0,  "weight": 25.0},
				{"tier": 3, "min_ilvl": 24, "min_value": 6.0,  "max_value": 8.0,  "weight": 10.0},
				{"tier": 2, "min_ilvl": 50, "min_value": 9.0,  "max_value": 12.0, "weight": 4.0},
				{"tier": 1, "min_ilvl": 75, "min_value": 13.0, "max_value": 16.0, "weight": 1.0},
			],
		},
		# 6. SUFIXO: Agilidade (5 tiers: T5 -> T1)
		{
			"id": "attr_agility",
			"display_name": "Agilidade",
			"kind": A.SUFFIX,
			"stat_id": "agility",
			"value_kind": "integer",
			"valid_categories": all_equip,
			"exclusive_group": "attr_agility",
			"family_weight": 40.0,
			"roll_step": 1.0,
			"format_template": "+%d de Agilidade",
			"tiers": [
				{"tier": 5, "min_ilvl": 1,  "min_value": 1.0,  "max_value": 2.0,  "weight": 60.0},
				{"tier": 4, "min_ilvl": 12, "min_value": 3.0,  "max_value": 5.0,  "weight": 25.0},
				{"tier": 3, "min_ilvl": 24, "min_value": 6.0,  "max_value": 8.0,  "weight": 10.0},
				{"tier": 2, "min_ilvl": 50, "min_value": 9.0,  "max_value": 12.0, "weight": 4.0},
				{"tier": 1, "min_ilvl": 75, "min_value": 13.0, "max_value": 16.0, "weight": 1.0},
			],
		},
		# 7. SUFIXO: Inteligência (5 tiers: T5 -> T1)
		{
			"id": "attr_intelligence",
			"display_name": "Inteligência",
			"kind": A.SUFFIX,
			"stat_id": "intelligence",
			"value_kind": "integer",
			"valid_categories": all_equip,
			"exclusive_group": "attr_intelligence",
			"family_weight": 38.0,
			"roll_step": 1.0,
			"format_template": "+%d de Inteligência",
			"tiers": [
				{"tier": 5, "min_ilvl": 1,  "min_value": 1.0,  "max_value": 2.0,  "weight": 60.0},
				{"tier": 4, "min_ilvl": 12, "min_value": 3.0,  "max_value": 5.0,  "weight": 25.0},
				{"tier": 3, "min_ilvl": 24, "min_value": 6.0,  "max_value": 8.0,  "weight": 10.0},
				{"tier": 2, "min_ilvl": 50, "min_value": 9.0,  "max_value": 12.0, "weight": 4.0},
				{"tier": 1, "min_ilvl": 75, "min_value": 13.0, "max_value": 16.0, "weight": 1.0},
			],
		},
		# 8. SUFIXO: Chance de Crítico (5 tiers: T5 -> T1)
		{
			"id": "crit_chance",
			"display_name": "Chance de Crítico",
			"kind": A.SUFFIX,
			"stat_id": "crit_chance",
			"value_kind": "percentage_fraction",
			"valid_categories": crit_gear,
			"exclusive_group": "crit_chance",
			"family_weight": 28.0,
			"roll_step": 0.01,
			"format_template": "+%d%% de Crítico",
			"tiers": [
				{"tier": 5, "min_ilvl": 1,  "min_value": 0.01, "max_value": 0.02, "weight": 60.0},
				{"tier": 4, "min_ilvl": 15, "min_value": 0.02, "max_value": 0.03, "weight": 25.0},
				{"tier": 3, "min_ilvl": 30, "min_value": 0.03, "max_value": 0.04, "weight": 10.0},
				{"tier": 2, "min_ilvl": 55, "min_value": 0.04, "max_value": 0.05, "weight": 4.0},
				{"tier": 1, "min_ilvl": 75, "min_value": 0.05, "max_value": 0.06, "weight": 1.0},
			],
		},
	]

	_cached_family_by_id.clear()
	for fam in _cached_families:
		_cached_family_by_id[String(fam["id"])] = fam

static func get_affix_families() -> Array[Dictionary]:
	_ensure_families_loaded()
	return _cached_families

static func get_affix_family(family_id: String) -> Dictionary:
	_ensure_families_loaded()
	return _cached_family_by_id.get(family_id, {})

static func get_eligible_tiers_for_family(family: Dictionary, ilvl: int) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	var tiers_list: Array = family.get("tiers", [])
	for t_entry in tiers_list:
		if ilvl >= int(t_entry.get("min_ilvl", 1)):
			eligible.append(t_entry)
	return eligible

## Retorna o MELHOR (menor número, pois T1 = melhor) tier desbloqueado na família para o `ilvl` informado.
static func get_best_unlocked_tier_for_family(family: Dictionary, ilvl: int) -> int:
	var eligible: Array[Dictionary] = get_eligible_tiers_for_family(family, ilvl)
	if eligible.is_empty():
		return 99
	var best_tier: int = int(eligible[0].get("tier", 5))
	for t_entry in eligible:
		var t_num: int = int(t_entry.get("tier", 5))
		if t_num < best_tier:
			best_tier = t_num
	return best_tier

## Retorna o melhor tier de referência desbloqueado para um `ilvl` (baseado na escala de 5 tiers T5->T1 da Seção 3).
static func get_max_unlocked_affix_tier_for_ilvl(ilvl: int) -> int:
	var spd_fam: Dictionary = get_affix_family("attack_speed_pct")
	return get_best_unlocked_tier_for_family(spd_fam, ilvl)

static func format_affix_value_text(family: Dictionary, rolled_val: float) -> String:
	var tmpl: String = String(family.get("format_template", "+%d"))
	var v_kind: String = String(family.get("value_kind", "integer"))
	if v_kind == "percentage_fraction":
		var pct_val: float = rolled_val * 100.0
		var step_pct: float = float(family.get("roll_step", 0.01)) * 100.0
		if step_pct < 0.99 and absf(pct_val - roundf(pct_val)) > 0.01:
			var num_str: String = ("%.1f" % pct_val).replace(".", ",")
			return "+%s%% %s" % [num_str, String(family.get("display_name", ""))]
		return tmpl % int(roundi(pct_val))
	return tmpl % int(roundi(rolled_val))

static func get_progressive_affix_pool() -> Array[Dictionary]:
	_ensure_families_loaded()
	var flat_pool: Array[Dictionary] = []
	for fam in _cached_families:
		var f_id: String = String(fam["id"])
		var f_name: String = String(fam["display_name"])
		var f_kind: int = int(fam["kind"])
		var f_stat: String = String(fam["stat_id"])
		var f_group: String = String(fam["exclusive_group"])
		var f_fmt: String = String(fam["format_template"])
		var f_slots: Array = fam["valid_categories"]
		for t_entry in fam["tiers"]:
			flat_pool.append({
				"id": "%s_t%d" % [f_id, int(t_entry["tier"])],
				"family_id": f_id,
				"name": f_name,
				"type": f_kind,
				"stat": f_stat,
				"group": f_group,
				"fmt": f_fmt,
				"min": float(t_entry["min_value"]),
				"max": float(t_entry["max_value"]),
				"tier": int(t_entry["tier"]),
				"min_ilvl": int(t_entry["min_ilvl"]),
				"weight": float(t_entry["weight"]),
				"slots": f_slots,
			})
	return flat_pool

## ---------------------------------------------------------------------------
## CONSULTA DE CURVAS, PESOS NORMALIZADOS E INTERPOLACAO (NIVEIS 1 A 100+)
## ---------------------------------------------------------------------------
static func get_monster_class_name(monster_class: int) -> String:
	var cfg: Dictionary = get_rank_config(monster_class)
	return String(cfg.get("name", "Normal"))

static func get_rank_config(monster_class: int) -> Dictionary:
	var clamped_class: int = clampi(monster_class, MonsterClass.NORMAL, MonsterClass.HERO)
	return ENEMY_RANK_CONFIG.get(clamped_class, ENEMY_RANK_CONFIG[MonsterClass.NORMAL])

static func get_base_equipment_drop_chance(enemy_level: int) -> float:
	var raw: float = _interpolate_scalar_dict(maxi(1, enemy_level), BASE_EQUIPMENT_DROP_CHANCE_BY_LEVEL)
	return clampf(raw, 0.0, MAX_ASYMPTOTIC_BASE_DROP_CHANCE)

## Retorna `p_drop_final = clamp(p_drop_base * multiplicador_de_chance, 0.0, 1.0)` (Seção 5)
static func get_equipment_drop_chance(enemy_level: int, monster_class: int) -> float:
	var p_base: float = get_base_equipment_drop_chance(enemy_level)
	var rank_cfg: Dictionary = get_rank_config(monster_class)
	var mult: float = float(rank_cfg.get("drop_mult", 1.0))
	return clampf(p_base * mult, 0.0, 1.0)

static func get_extra_roll_chance(monster_class: int) -> float:
	var rank_cfg: Dictionary = get_rank_config(monster_class)
	return clampf(float(rank_cfg.get("extra_roll_chance", 0.0)), 0.0, 1.0)

## Retorna os pesos base [Branco, Verde, Azul, Amarelo] para o nível antes do multiplicador de rank
static func get_base_rarity_weights_for_level(enemy_level: int) -> Array[float]:
	return _interpolate_vector_table(maxi(1, enemy_level), BASE_RARITY_WEIGHTS_BY_LEVEL, 4)

## Aplica multiplicadores de rank aos PESOS (Branco x1, Verde x1, Azul x magic_mult, Amarelo x rare_mult)
## e renormaliza internamente para somar 1.0 (Seção 5 e Seção 8, linhas 236-240).
static func get_non_unique_rarity_weights(enemy_level: int, monster_class: int) -> Array[float]:
	var base_w: Array[float] = get_base_rarity_weights_for_level(enemy_level)
	var rank_cfg: Dictionary = get_rank_config(monster_class)
	var weighted: Array[float] = [
		base_w[0] * float(rank_cfg.get("normal_weight_mult", 1.0)),
		base_w[1] * float(rank_cfg.get("uncommon_weight_mult", 1.0)),
		base_w[2] * float(rank_cfg.get("magic_weight_mult", 1.0)),
		base_w[3] * float(rank_cfg.get("rare_weight_mult", 1.0)),
	]
	return normalize_weights(weighted)

## Calcula a chance separada de Único para `(enemy_level, monster_class, base_id, zone_id, enemy_id)`
static func get_eligible_unique_definition_and_chance(
	ilvl: int,
	monster_class: int,
	preferred_base_id: String = "",
	zone_id: String = "act1",
	enemy_id: String = ""
) -> Dictionary:
	var clamped_class: int = clampi(monster_class, MonsterClass.NORMAL, MonsterClass.HERO)
	var candidates: Array[Dictionary] = []

	for u_def in get_unique_item_definitions():
		if ilvl < int(u_def.get("min_ilvl", 1)):
			continue
		var allowed_ranks: Array = u_def.get("allowed_ranks", [])
		if not allowed_ranks.is_empty() and not allowed_ranks.has(clamped_class):
			continue
		if not preferred_base_id.is_empty() and String(u_def.get("base_id", "")) != preferred_base_id:
			continue
		var allowed_zones: Array = u_def.get("allowed_zones", [])
		if not allowed_zones.is_empty() and not zone_id.is_empty() and not allowed_zones.has(zone_id):
			continue
		var allowed_enemies: Array = u_def.get("allowed_enemy_ids", [])
		if not allowed_enemies.is_empty() and not enemy_id.is_empty() and not allowed_enemies.has(enemy_id):
			continue

		var chance_map: Dictionary = u_def.get("chance_by_rank", {})
		var base_chance: float = float(chance_map.get(clamped_class, DEFAULT_GENERIC_UNIQUE_CHANCE))
		if base_chance <= 0.0:
			continue

		# Escalonamento suave controlado por nível, limitado por `max_endgame_chance_mult`
		var max_mult: float = float(u_def.get("max_endgame_chance_mult", 1.35))
		var level_factor: float = clampf(1.0 + float(maxi(0, ilvl - 3)) * 0.008, 1.0, max_mult)
		var final_chance: float = clampf(base_chance * level_factor, 0.0, 0.025)
		candidates.append({
			"unique_def": u_def,
			"chance": final_chance,
		})

	if candidates.is_empty():
		return {"eligible": false, "chance": 0.0, "unique_def": {}}
	return {
		"eligible": true,
		"chance": float(candidates[0]["chance"]),
		"unique_def": candidates[0]["unique_def"],
	}

## Compatibilidade: retorna vetor de 5 pesos [Branco, Verde, Azul, Amarelo, Único] combinados
static func get_rarity_weights(enemy_level: int, monster_class: int, allow_unique: bool = true) -> Array[float]:
	var non_uniq: Array[float] = get_non_unique_rarity_weights(enemy_level, monster_class)
	var ilvl: int = get_effective_item_level(enemy_level, monster_class)
	var uniq_chance: float = 0.0
	if allow_unique:
		var u_info: Dictionary = get_eligible_unique_definition_and_chance(ilvl, monster_class)
		if bool(u_info.get("eligible", false)):
			uniq_chance = float(u_info.get("chance", 0.0))
	var scale: float = clampf(1.0 - uniq_chance, 0.0, 1.0)
	return [
		non_uniq[0] * scale,
		non_uniq[1] * scale,
		non_uniq[2] * scale,
		non_uniq[3] * scale,
		uniq_chance,
	]

## Determina o `ilvl` a partir do `enemy_level` e `monster_class` (Seção 6, linha 163)
static func get_effective_item_level(enemy_level: int, monster_class: int = MonsterClass.NORMAL, zone_max_ilvl: int = -1) -> int:
	var clamped_class: int = clampi(monster_class, MonsterClass.NORMAL, MonsterClass.HERO)
	var bonus: int = int(RANK_ILVL_BONUS.get(clamped_class, 0)) if enable_rank_ilvl_bonus else 0
	var ilvl: int = maxi(1, enemy_level + bonus)
	if zone_max_ilvl > 0:
		ilvl = mini(ilvl, zone_max_ilvl)
	return ilvl

static func get_rare_four_mod_chance(item_level: int) -> float:
	return clampf(_interpolate_scalar_dict(maxi(1, item_level), RARE_FOUR_MOD_CHANCE_BY_LEVEL), 0.0, 0.65)

static func normalize_weights(weights: Array[float]) -> Array[float]:
	var total: float = 0.0
	for w in weights:
		total += maxf(0.0, w)
	var normalized: Array[float] = []
	if total <= 0.000001:
		normalized.resize(weights.size())
		if not normalized.is_empty():
			normalized[0] = 1.0
		return normalized
	for w in weights:
		normalized.append(maxf(0.0, w) / total)
	return normalized

static func roll_weighted_index(weights: Array[float], rng: RandomNumberGenerator = null) -> int:
	var norm: Array[float] = normalize_weights(weights)
	var roll: float = rng.randf() if rng != null else randf()
	var accum: float = 0.0
	for i in range(norm.size()):
		accum += norm[i]
		if roll <= accum:
			return i
	return maxi(0, norm.size() - 1)

static func _interpolate_scalar_dict(level: int, table: Dictionary) -> float:
	var first_lv: int = KEYFRAME_LEVELS[0]
	var last_idx: int = KEYFRAME_LEVELS.size() - 1
	var last_lv: int = KEYFRAME_LEVELS[last_idx]

	if level <= first_lv:
		return float(table[first_lv])
	if level >= last_lv:
		var extra: int = level - last_lv
		var prev_lv: int = KEYFRAME_LEVELS[last_idx - 1]
		var slope: float = (float(table[last_lv]) - float(table[prev_lv])) / float(maxi(1, last_lv - prev_lv))
		return float(table[last_lv]) + slope * float(extra) * 0.25

	for i in range(last_idx):
		var lv_a: int = KEYFRAME_LEVELS[i]
		var lv_b: int = KEYFRAME_LEVELS[i + 1]
		if level >= lv_a and level <= lv_b:
			var t: float = float(level - lv_a) / float(maxi(1, lv_b - lv_a))
			return lerpf(float(table[lv_a]), float(table[lv_b]), t)
	return float(table[last_lv])

static func _interpolate_vector_table(level: int, table: Dictionary, vec_size: int) -> Array[float]:
	var result: Array[float] = []
	result.resize(vec_size)
	var first_lv: int = KEYFRAME_LEVELS[0]
	var last_idx: int = KEYFRAME_LEVELS.size() - 1
	var last_lv: int = KEYFRAME_LEVELS[last_idx]

	if level <= first_lv:
		var v0: Array = table[first_lv]
		for j in range(vec_size):
			result[j] = float(v0[j])
		return result

	if level >= last_lv:
		var v_last: Array = table[last_lv]
		var v_prev: Array = table[KEYFRAME_LEVELS[last_idx - 1]]
		var span: float = float(maxi(1, last_lv - KEYFRAME_LEVELS[last_idx - 1]))
		var extra: float = float(level - last_lv)
		for j in range(vec_size):
			var slope: float = (float(v_last[j]) - float(v_prev[j])) / span
			result[j] = maxf(1.0, float(v_last[j]) + slope * extra * 0.20)
		return result

	for i in range(last_idx):
		var lv_a: int = KEYFRAME_LEVELS[i]
		var lv_b: int = KEYFRAME_LEVELS[i + 1]
		if level >= lv_a and level <= lv_b:
			var t: float = float(level - lv_a) / float(maxi(1, lv_b - lv_a))
			var va: Array = table[lv_a]
			var vb: Array = table[lv_b]
			for j in range(vec_size):
				result[j] = lerpf(float(va[j]), float(vb[j]), t)
			return result

	var v_end: Array = table[last_lv]
	for j in range(vec_size):
		result[j] = float(v_end[j])
	return result

## ---------------------------------------------------------------------------
## 8. DROP DE CONSUMÍVEIS DE CRAFTING (ESCRITURAS ARCANAS)
## ---------------------------------------------------------------------------
## Conforme Seção 9 do documento `06_estudo_escrituras_arcanas_crafting.md`:
## - Probabilidade separada de drop por abate.
## - Gating por nível: Primeira Marca (Lv 1+), Contrasselo (Lv 1+), Cláusula Áurea (Lv 8+),
##   Pedra da Rasura (Lv 12+), Pedra do Veredito (Lv 45+ ou Chefes).
const CRAFTING_CONSUMABLE_BASE_DROP_CHANCE_BY_LEVEL: Dictionary = {
	1:   0.050,
	5:   0.060,
	10:  0.075,
	15:  0.090,
	20:  0.110,
	25:  0.130,
	40:  0.150,
	60:  0.170,
	80:  0.190,
	90:  0.200,
	100: 0.210,
}

static func get_crafting_drop_chance(enemy_level: int, monster_class: int = MonsterClass.NORMAL) -> float:
	var base_chance: float = _interpolate_scalar_dict(enemy_level, CRAFTING_CONSUMABLE_BASE_DROP_CHANCE_BY_LEVEL)
	var mult: float = 1.0
	match monster_class:
		MonsterClass.NORMAL:
			mult = 1.0
		MonsterClass.MAGIC:
			mult = 1.6
		MonsterClass.RARE:
			mult = 2.4
		MonsterClass.HERO:
			mult = 3.0
		MonsterClass.BOSS:
			return 1.0 # 100% garantido pelo menos 1 drop de crafting em Chefes
	return clampf(base_chance * mult, 0.0, 1.0)

static func get_crafting_consumable_weights(enemy_level: int, monster_class: int = MonsterClass.NORMAL) -> Dictionary:
	var weights: Dictionary = {}
	var lv: int = maxi(1, enemy_level)
	var is_boss: bool = (monster_class == MonsterClass.BOSS)
	var is_rare_or_above: bool = (monster_class == MonsterClass.RARE or monster_class == MonsterClass.HERO or is_boss)

	# 1. Pergaminho da Primeira Marca (Lv 1+)
	weights["scroll_first_mark"] = 60.0

	# 2. Pergaminho do Contrasselo (Lv 1+)
	weights["scroll_counterseal"] = 35.0

	# 3. Pergaminho da Cláusula Áurea (Lv 8+)
	if lv >= 8 or is_rare_or_above:
		var w_clause: float = 16.0
		if is_rare_or_above:
			w_clause *= 1.8
		weights["scroll_golden_clause"] = w_clause

	# 4. Pedra da Rasura (Lv 12+)
	if lv >= 12 or is_rare_or_above:
		var w_eraser: float = 9.0
		if is_rare_or_above:
			w_eraser *= 2.0
		weights["stone_eraser"] = w_eraser

	# 5. Pedra do Veredito (Lv 45+ ou Chefes em qualquer nível)
	if lv >= 45 or is_boss:
		var w_verdict: float = 3.0
		if is_boss:
			w_verdict *= 4.0
		weights["stone_verdict"] = w_verdict

	return weights

static func roll_crafting_consumable_id(
	enemy_level: int,
	monster_class: int = MonsterClass.NORMAL,
	rng: RandomNumberGenerator = null
) -> String:
	var weights_dict: Dictionary = get_crafting_consumable_weights(enemy_level, monster_class)
	if weights_dict.is_empty():
		return "scroll_first_mark"
	var keys: Array[String] = []
	var weights: Array[float] = []
	for k in weights_dict.keys():
		keys.append(String(k))
		weights.append(float(weights_dict[k]))
	var chosen_idx: int = roll_weighted_index(weights, rng)
	return keys[chosen_idx]

