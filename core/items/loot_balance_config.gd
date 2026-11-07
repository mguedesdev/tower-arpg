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
## 6. TABELA DE TIERS DE AFIXOS (T1 A T8 — NÍVEIS 1 A 90+) (Seção 6 e Seção 8)
## ---------------------------------------------------------------------------
## Marcos de ilvl mínimo por Tier:
## - Ato 1 (Níveis 1–25): T1 (ilvl 1), T2 (ilvl 8), T3 (ilvl 16), T4 (ilvl 24)
## - Expansão Endgame (Níveis 26–90+): T5 (ilvl 36), T6 (ilvl 50), T7 (ilvl 65), T8 (ilvl 80)
## Nenhum valor usa multiplicação bruta `roll * ilvl`; todos possuem faixas [min, max] explícitas
## e `exclusion_group` para impedir dois afixos da mesma família no mesmo item.
const AFFIX_TIER_MIN_ILVL: Dictionary = {
	1: 1,
	2: 8,
	3: 16,
	4: 24,
	5: 36,
	6: 50,
	7: 65,
	8: 80,
}

static func get_max_unlocked_affix_tier_for_ilvl(ilvl: int) -> int:
	var best_tier: int = 1
	for t in [1, 2, 3, 4, 5, 6, 7, 8]:
		if ilvl >= int(AFFIX_TIER_MIN_ILVL[t]):
			best_tier = t
	return best_tier

static func get_progressive_affix_pool() -> Array[Dictionary]:
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

	return [
		# ===================== PREFIXOS: FAMÍLIA "flat_damage" (ARMAS) =====================
		{"id": "pref_dmg_t1", "name": "Afiado",       "type": A.PREFIX, "stat": "damage", "group": "flat_damage", "fmt": "+%d de Dano", "min": 1.0,  "max": 3.0,  "tier": 1, "min_ilvl": 1,  "weight": 100.0, "slots": weapons},
		{"id": "pref_dmg_t2", "name": "Talhante",     "type": A.PREFIX, "stat": "damage", "group": "flat_damage", "fmt": "+%d de Dano", "min": 3.0,  "max": 5.0,  "tier": 2, "min_ilvl": 8,  "weight": 92.0,  "slots": weapons},
		{"id": "pref_dmg_t3", "name": "Cruel",        "type": A.PREFIX, "stat": "damage", "group": "flat_damage", "fmt": "+%d de Dano", "min": 5.0,  "max": 8.0,  "tier": 3, "min_ilvl": 16, "weight": 84.0,  "slots": weapons},
		{"id": "pref_dmg_t4", "name": "Impiedoso",    "type": A.PREFIX, "stat": "damage", "group": "flat_damage", "fmt": "+%d de Dano", "min": 8.0,  "max": 12.0, "tier": 4, "min_ilvl": 24, "weight": 75.0,  "slots": weapons},
		{"id": "pref_dmg_t5", "name": "Tirânico",     "type": A.PREFIX, "stat": "damage", "group": "flat_damage", "fmt": "+%d de Dano", "min": 12.0, "max": 17.0, "tier": 5, "min_ilvl": 36, "weight": 66.0,  "slots": weapons},
		{"id": "pref_dmg_t6", "name": "Sanguinário",  "type": A.PREFIX, "stat": "damage", "group": "flat_damage", "fmt": "+%d de Dano", "min": 17.0, "max": 23.0, "tier": 6, "min_ilvl": 50, "weight": 58.0,  "slots": weapons},
		{"id": "pref_dmg_t7", "name": "Conquistador", "type": A.PREFIX, "stat": "damage", "group": "flat_damage", "fmt": "+%d de Dano", "min": 23.0, "max": 30.0, "tier": 7, "min_ilvl": 65, "weight": 50.0,  "slots": weapons},
		{"id": "pref_dmg_t8", "name": "Abissal",      "type": A.PREFIX, "stat": "damage", "group": "flat_damage", "fmt": "+%d de Dano", "min": 30.0, "max": 38.0, "tier": 8, "min_ilvl": 80, "weight": 42.0,  "slots": weapons},

		# ===================== PREFIXOS: FAMÍLIA "flat_armor" (ARMADURAS/ESCUDOS/CINTOS) =====================
		{"id": "pref_arm_t1", "name": "Reforçado",    "type": A.PREFIX, "stat": "armor", "group": "flat_armor", "fmt": "+%d de Armadura", "min": 2.0,  "max": 4.0,  "tier": 1, "min_ilvl": 1,  "weight": 100.0, "slots": armors},
		{"id": "pref_arm_t2", "name": "Blindado",     "type": A.PREFIX, "stat": "armor", "group": "flat_armor", "fmt": "+%d de Armadura", "min": 4.0,  "max": 7.0,  "tier": 2, "min_ilvl": 8,  "weight": 92.0,  "slots": armors},
		{"id": "pref_arm_t3", "name": "Murado",       "type": A.PREFIX, "stat": "armor", "group": "flat_armor", "fmt": "+%d de Armadura", "min": 7.0,  "max": 11.0, "tier": 3, "min_ilvl": 16, "weight": 84.0,  "slots": armors},
		{"id": "pref_arm_t4", "name": "Inabalável",   "type": A.PREFIX, "stat": "armor", "group": "flat_armor", "fmt": "+%d de Armadura", "min": 11.0, "max": 16.0, "tier": 4, "min_ilvl": 24, "weight": 75.0,  "slots": armors},
		{"id": "pref_arm_t5", "name": "Impenetrável", "type": A.PREFIX, "stat": "armor", "group": "flat_armor", "fmt": "+%d de Armadura", "min": 16.0, "max": 22.0, "tier": 5, "min_ilvl": 36, "weight": 66.0,  "slots": armors},
		{"id": "pref_arm_t6", "name": "Bastilha",     "type": A.PREFIX, "stat": "armor", "group": "flat_armor", "fmt": "+%d de Armadura", "min": 22.0, "max": 30.0, "tier": 6, "min_ilvl": 50, "weight": 58.0,  "slots": armors},
		{"id": "pref_arm_t7", "name": "Colossal",     "type": A.PREFIX, "stat": "armor", "group": "flat_armor", "fmt": "+%d de Armadura", "min": 30.0, "max": 40.0, "tier": 7, "min_ilvl": 65, "weight": 50.0,  "slots": armors},
		{"id": "pref_arm_t8", "name": "Eterno",       "type": A.PREFIX, "stat": "armor", "group": "flat_armor", "fmt": "+%d de Armadura", "min": 40.0, "max": 52.0, "tier": 8, "min_ilvl": 80, "weight": 42.0,  "slots": armors},

		# ===================== PREFIXOS: FAMÍLIA "flat_max_health" (VIDA MÁXIMA) =====================
		{"id": "pref_hp_t1",  "name": "Saudável",     "type": A.PREFIX, "stat": "max_health", "group": "flat_max_health", "fmt": "+%d de Vida", "min": 3.0,  "max": 6.0,  "tier": 1, "min_ilvl": 1,  "weight": 100.0, "slots": vitality_gear},
		{"id": "pref_hp_t2",  "name": "Robusto",      "type": A.PREFIX, "stat": "max_health", "group": "flat_max_health", "fmt": "+%d de Vida", "min": 6.0,  "max": 10.0, "tier": 2, "min_ilvl": 8,  "weight": 92.0,  "slots": vitality_gear},
		{"id": "pref_hp_t3",  "name": "Vigoroso",     "type": A.PREFIX, "stat": "max_health", "group": "flat_max_health", "fmt": "+%d de Vida", "min": 10.0, "max": 15.0, "tier": 3, "min_ilvl": 16, "weight": 84.0,  "slots": vitality_gear},
		{"id": "pref_hp_t4",  "name": "Vital",        "type": A.PREFIX, "stat": "max_health", "group": "flat_max_health", "fmt": "+%d de Vida", "min": 15.0, "max": 22.0, "tier": 4, "min_ilvl": 24, "weight": 75.0,  "slots": vitality_gear},
		{"id": "pref_hp_t5",  "name": "Imortal",      "type": A.PREFIX, "stat": "max_health", "group": "flat_max_health", "fmt": "+%d de Vida", "min": 22.0, "max": 32.0, "tier": 5, "min_ilvl": 36, "weight": 66.0,  "slots": vitality_gear},
		{"id": "pref_hp_t6",  "name": "Titânico",     "type": A.PREFIX, "stat": "max_health", "group": "flat_max_health", "fmt": "+%d de Vida", "min": 32.0, "max": 45.0, "tier": 6, "min_ilvl": 50, "weight": 58.0,  "slots": vitality_gear},
		{"id": "pref_hp_t7",  "name": "Ancestral",    "type": A.PREFIX, "stat": "max_health", "group": "flat_max_health", "fmt": "+%d de Vida", "min": 45.0, "max": 62.0, "tier": 7, "min_ilvl": 65, "weight": 50.0,  "slots": vitality_gear},
		{"id": "pref_hp_t8",  "name": "Primordial",   "type": A.PREFIX, "stat": "max_health", "group": "flat_max_health", "fmt": "+%d de Vida", "min": 62.0, "max": 82.0, "tier": 8, "min_ilvl": 80, "weight": 42.0,  "slots": vitality_gear},

		# ===================== SUFIXOS: FAMÍLIA "attr_strength" (FORÇA) =====================
		{"id": "suff_str_t1", "name": "do Bruto",     "type": A.SUFFIX, "stat": "strength", "group": "attr_strength", "fmt": "+%d de Força", "min": 1.0,  "max": 2.0,  "tier": 1, "min_ilvl": 1,  "weight": 100.0, "slots": all_equip},
		{"id": "suff_str_t2", "name": "do Guerreiro", "type": A.SUFFIX, "stat": "strength", "group": "attr_strength", "fmt": "+%d de Força", "min": 2.0,  "max": 4.0,  "tier": 2, "min_ilvl": 8,  "weight": 92.0,  "slots": all_equip},
		{"id": "suff_str_t3", "name": "do Urso",      "type": A.SUFFIX, "stat": "strength", "group": "attr_strength", "fmt": "+%d de Força", "min": 4.0,  "max": 6.0,  "tier": 3, "min_ilvl": 16, "weight": 84.0,  "slots": all_equip},
		{"id": "suff_str_t4", "name": "do Golias",    "type": A.SUFFIX, "stat": "strength", "group": "attr_strength", "fmt": "+%d de Força", "min": 6.0,  "max": 9.0,  "tier": 4, "min_ilvl": 24, "weight": 75.0,  "slots": all_equip},
		{"id": "suff_str_t5", "name": "do Titã",      "type": A.SUFFIX, "stat": "strength", "group": "attr_strength", "fmt": "+%d de Força", "min": 9.0,  "max": 13.0, "tier": 5, "min_ilvl": 36, "weight": 66.0,  "slots": all_equip},
		{"id": "suff_str_t6", "name": "do Colosso",   "type": A.SUFFIX, "stat": "strength", "group": "attr_strength", "fmt": "+%d de Força", "min": 13.0, "max": 18.0, "tier": 6, "min_ilvl": 50, "weight": 58.0,  "slots": all_equip},
		{"id": "suff_str_t7", "name": "do Leviatã",   "type": A.SUFFIX, "stat": "strength", "group": "attr_strength", "fmt": "+%d de Força", "min": 18.0, "max": 24.0, "tier": 7, "min_ilvl": 65, "weight": 50.0,  "slots": all_equip},
		{"id": "suff_str_t8", "name": "do Deus-Guerreiro", "type": A.SUFFIX, "stat": "strength", "group": "attr_strength", "fmt": "+%d de Força", "min": 24.0, "max": 32.0, "tier": 8, "min_ilvl": 80, "weight": 42.0,  "slots": all_equip},

		# ===================== SUFIXOS: FAMÍLIA "attr_agility" (AGILIDADE) =====================
		{"id": "suff_agi_t1", "name": "da Raposa",    "type": A.SUFFIX, "stat": "agility", "group": "attr_agility", "fmt": "+%d de Agilidade", "min": 1.0,  "max": 2.0,  "tier": 1, "min_ilvl": 1,  "weight": 100.0, "slots": all_equip},
		{"id": "suff_agi_t2", "name": "do Caçador",   "type": A.SUFFIX, "stat": "agility", "group": "attr_agility", "fmt": "+%d de Agilidade", "min": 2.0,  "max": 4.0,  "tier": 2, "min_ilvl": 8,  "weight": 92.0,  "slots": all_equip},
		{"id": "suff_agi_t3", "name": "do Falcão",    "type": A.SUFFIX, "stat": "agility", "group": "attr_agility", "fmt": "+%d de Agilidade", "min": 4.0,  "max": 6.0,  "tier": 3, "min_ilvl": 16, "weight": 84.0,  "slots": all_equip},
		{"id": "suff_agi_t4", "name": "do Lince",     "type": A.SUFFIX, "stat": "agility", "group": "attr_agility", "fmt": "+%d de Agilidade", "min": 6.0,  "max": 9.0,  "tier": 4, "min_ilvl": 24, "weight": 75.0,  "slots": all_equip},
		{"id": "suff_agi_t5", "name": "do Vento",     "type": A.SUFFIX, "stat": "agility", "group": "attr_agility", "fmt": "+%d de Agilidade", "min": 9.0,  "max": 13.0, "tier": 5, "min_ilvl": 36, "weight": 66.0,  "slots": all_equip},
		{"id": "suff_agi_t6", "name": "da Tempestade","type": A.SUFFIX, "stat": "agility", "group": "attr_agility", "fmt": "+%d de Agilidade", "min": 13.0, "max": 18.0, "tier": 6, "min_ilvl": 50, "weight": 58.0,  "slots": all_equip},
		{"id": "suff_agi_t7", "name": "do Relâmpago", "type": A.SUFFIX, "stat": "agility", "group": "attr_agility", "fmt": "+%d de Agilidade", "min": 18.0, "max": 24.0, "tier": 7, "min_ilvl": 65, "weight": 50.0,  "slots": all_equip},
		{"id": "suff_agi_t8", "name": "do Espectro",  "type": A.SUFFIX, "stat": "agility", "group": "attr_agility", "fmt": "+%d de Agilidade", "min": 24.0, "max": 32.0, "tier": 8, "min_ilvl": 80, "weight": 42.0,  "slots": all_equip},

		# ===================== SUFIXOS: FAMÍLIA "attr_intelligence" (INTELIGÊNCIA) =====================
		{"id": "suff_int_t1", "name": "do Aprendiz",  "type": A.SUFFIX, "stat": "intelligence", "group": "attr_intelligence", "fmt": "+%d de Inteligência", "min": 1.0,  "max": 2.0,  "tier": 1, "min_ilvl": 1,  "weight": 95.0,  "slots": all_equip},
		{"id": "suff_int_t2", "name": "do Acólito",   "type": A.SUFFIX, "stat": "intelligence", "group": "attr_intelligence", "fmt": "+%d de Inteligência", "min": 2.0,  "max": 4.0,  "tier": 2, "min_ilvl": 8,  "weight": 88.0,  "slots": all_equip},
		{"id": "suff_int_t3", "name": "da Coruja",    "type": A.SUFFIX, "stat": "intelligence", "group": "attr_intelligence", "fmt": "+%d de Inteligência", "min": 4.0,  "max": 6.0,  "tier": 3, "min_ilvl": 16, "weight": 80.0,  "slots": all_equip},
		{"id": "suff_int_t4", "name": "do Sábio",     "type": A.SUFFIX, "stat": "intelligence", "group": "attr_intelligence", "fmt": "+%d de Inteligência", "min": 6.0,  "max": 9.0,  "tier": 4, "min_ilvl": 24, "weight": 72.0,  "slots": all_equip},
		{"id": "suff_int_t5", "name": "do Oráculo",   "type": A.SUFFIX, "stat": "intelligence", "group": "attr_intelligence", "fmt": "+%d de Inteligência", "min": 9.0,  "max": 13.0, "tier": 5, "min_ilvl": 36, "weight": 64.0,  "slots": all_equip},
		{"id": "suff_int_t6", "name": "do Arquimago", "type": A.SUFFIX, "stat": "intelligence", "group": "attr_intelligence", "fmt": "+%d de Inteligência", "min": 13.0, "max": 18.0, "tier": 6, "min_ilvl": 50, "weight": 56.0,  "slots": all_equip},
		{"id": "suff_int_t7", "name": "do Astral",    "type": A.SUFFIX, "stat": "intelligence", "group": "attr_intelligence", "fmt": "+%d de Inteligência", "min": 18.0, "max": 24.0, "tier": 7, "min_ilvl": 65, "weight": 48.0,  "slots": all_equip},
		{"id": "suff_int_t8", "name": "do Onisciente","type": A.SUFFIX, "stat": "intelligence", "group": "attr_intelligence", "fmt": "+%d de Inteligência", "min": 24.0, "max": 32.0, "tier": 8, "min_ilvl": 80, "weight": 40.0,  "slots": all_equip},

		# ===================== SUFIXOS: FAMÍLIA "crit_chance" (CHANCE CRÍTICA) =====================
		{"id": "suff_crit_t1", "name": "da Precisão",   "type": A.SUFFIX, "stat": "crit_chance", "group": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.01, "max": 0.02, "tier": 1, "min_ilvl": 1,  "weight": 75.0, "slots": crit_gear},
		{"id": "suff_crit_t2", "name": "do Golpe",      "type": A.SUFFIX, "stat": "crit_chance", "group": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.02, "max": 0.03, "tier": 2, "min_ilvl": 8,  "weight": 68.0, "slots": crit_gear},
		{"id": "suff_crit_t3", "name": "da Ferocidade", "type": A.SUFFIX, "stat": "crit_chance", "group": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.02, "max": 0.04, "tier": 3, "min_ilvl": 16, "weight": 62.0, "slots": crit_gear},
		{"id": "suff_crit_t4", "name": "da Ruína",      "type": A.SUFFIX, "stat": "crit_chance", "group": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.03, "max": 0.05, "tier": 4, "min_ilvl": 24, "weight": 55.0, "slots": crit_gear},
		{"id": "suff_crit_t5", "name": "da Execução",   "type": A.SUFFIX, "stat": "crit_chance", "group": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.04, "max": 0.06, "tier": 5, "min_ilvl": 36, "weight": 48.0, "slots": crit_gear},
		{"id": "suff_crit_t6", "name": "da Aniquilação","type": A.SUFFIX, "stat": "crit_chance", "group": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.05, "max": 0.07, "tier": 6, "min_ilvl": 50, "weight": 42.0, "slots": crit_gear},
		{"id": "suff_crit_t7", "name": "da Fatalidade", "type": A.SUFFIX, "stat": "crit_chance", "group": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.06, "max": 0.08, "tier": 7, "min_ilvl": 65, "weight": 36.0, "slots": crit_gear},
		{"id": "suff_crit_t8", "name": "do Apocalipse", "type": A.SUFFIX, "stat": "crit_chance", "group": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.07, "max": 0.10, "tier": 8, "min_ilvl": 80, "weight": 30.0, "slots": crit_gear},
	]

## ---------------------------------------------------------------------------
## CONSULTA DE CURVAS, PESOS NORMALIZADOS E INTERPOLACAO (NIVEIS 1 A 100+)
## ---------------------------------------------------------------------------
static func get_monster_class_name(monster_class: int) -> String:
	var cfg: Dictionary = get_rank_config(monster_class)
	return String(cfg.get("name", "Normal"))

static func get_rank_config(monster_class: int) -> Dictionary:
	var clamped_class: int = clampi(monster_class, MonsterClass.NORMAL, MonsterClass.BOSS)
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
	var clamped_class: int = clampi(monster_class, MonsterClass.NORMAL, MonsterClass.BOSS)
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
	var clamped_class: int = clampi(monster_class, MonsterClass.NORMAL, MonsterClass.BOSS)
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
