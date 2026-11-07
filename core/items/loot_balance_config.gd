extends RefCounted
class_name LootBalanceConfig

## Classificacao do monstro — totalmente independente da raridade do equipamento.
enum MonsterClass {
	NORMAL = 0, ## Monstro comum, sem modificadores especiais
	MAGIC = 1,  ## Monstro aprimorado, com modificadores de combate
	RARE = 2,   ## Monstro poderoso, com multiplos modificadores
	BOSS = 3,   ## Inimigo especial/chefe com melhores chances de qualidade e quantidade
}

## Niveis de referencia para curvas de progressao (expansivel alem do nivel 25).
const KEYFRAME_LEVELS: Array[int] = [1, 5, 10, 15, 20, 25]

## ---------------------------------------------------------------------------
## 1. CHANCE DE DERRUBAR EQUIPAMENTO POR MORTE (0.0 a 1.0)
## ---------------------------------------------------------------------------
## Separado da raridade e da quantidade de itens gerados.
const DROP_CHANCE_BY_CLASS_KEYFRAMES: Dictionary = {
	MonsterClass.NORMAL: [0.22, 0.24, 0.26, 0.28, 0.30, 0.32],
	MonsterClass.MAGIC:  [0.48, 0.52, 0.56, 0.60, 0.64, 0.68],
	MonsterClass.RARE:   [0.82, 0.85, 0.88, 0.90, 0.93, 0.95],
	MonsterClass.BOSS:   [1.00, 1.00, 1.00, 1.00, 1.00, 1.00],
}

## ---------------------------------------------------------------------------
## 2. QUANTIDADE DE EQUIPAMENTOS GERADOS QUANDO OCORRE DROP
## ---------------------------------------------------------------------------
## Pesos ponderados para [1 item, 2 itens, 3 itens, 4 itens] por classificacao e nivel.
const DROP_COUNT_WEIGHTS_BY_CLASS: Dictionary = {
	MonsterClass.NORMAL: {
		1:  [96.0, 4.0, 0.0, 0.0],
		5:  [95.0, 5.0, 0.0, 0.0],
		10: [93.0, 7.0, 0.0, 0.0],
		15: [91.0, 9.0, 0.0, 0.0],
		20: [89.0, 11.0, 0.0, 0.0],
		25: [87.0, 13.0, 0.0, 0.0],
	},
	MonsterClass.MAGIC: {
		1:  [82.0, 18.0, 0.0, 0.0],
		5:  [79.0, 20.0, 1.0, 0.0],
		10: [75.0, 23.0, 2.0, 0.0],
		15: [71.0, 26.0, 3.0, 0.0],
		20: [67.0, 28.0, 5.0, 0.0],
		25: [64.0, 30.0, 6.0, 0.0],
	},
	MonsterClass.RARE: {
		1:  [55.0, 38.0, 7.0, 0.0],
		5:  [50.0, 40.0, 10.0, 0.0],
		10: [44.0, 43.0, 12.0, 1.0],
		15: [39.0, 45.0, 14.0, 2.0],
		20: [34.0, 46.0, 17.0, 3.0],
		25: [30.0, 47.0, 19.0, 4.0],
	},
	MonsterClass.BOSS: {
		1:  [0.0, 58.0, 34.0, 8.0],
		5:  [0.0, 50.0, 38.0, 12.0],
		10: [0.0, 42.0, 42.0, 16.0],
		15: [0.0, 34.0, 45.0, 21.0],
		20: [0.0, 26.0, 48.0, 26.0],
		25: [0.0, 20.0, 50.0, 30.0],
	},
}

## ---------------------------------------------------------------------------
## 3. TABELAS DE PESOS DE RARIDADE POR CLASSIFICACAO E NIVEL (1..25)
## ---------------------------------------------------------------------------
## Ordem dos pesos no vetor: [NORMAL (Branco), UNCOMMON (Verde), MAGIC (Azul), RARE (Amarelo), UNIQUE (Vermelho)]
## Regras de design:
## - Nivel 1 Normal: predominantemente Branco (~67%) e Verde (~29.5%), Azul baixissimo (~3.2%), Amarelo muito raro (~0.3%), Vermelho (0%).
## - Nivel 1 Magico/Raro/Chefe: progressivamente melhores, sem banalizar Amarelos no inicio.
## - Nivel 25 Normal: entrega mais Azuis (~29.5%) e Verdes (~42.5%), com Amarelos moderados (~4.9%).
## - Monstro Raro NUNCA e garantia automatica de item Amarelo (mesmo no nv 25, Amarelo ~28%).
## - Unicos (Vermelhos) restritos a tabelas elegiveis (ilvl >= 3, com chances muito baixas).
const RARITY_WEIGHTS_BY_CLASS: Dictionary = {
	MonsterClass.NORMAL: {
		1:  [67.0, 29.5,  3.2,  0.30, 0.00],
		5:  [56.0, 35.5,  7.6,  0.90, 0.00],
		10: [45.0, 40.0, 13.3,  1.68, 0.02],
		15: [36.0, 42.5, 18.8,  2.66, 0.04],
		20: [29.0, 43.0, 24.2,  3.74, 0.06],
		25: [23.0, 42.5, 29.5,  4.90, 0.10],
	},
	MonsterClass.MAGIC: {
		1:  [48.0, 41.0,  9.8,  1.20, 0.00],
		5:  [38.0, 43.5, 15.8,  2.65, 0.05],
		10: [28.0, 44.0, 23.2,  4.70, 0.10],
		15: [20.0, 42.0, 30.5,  7.32, 0.18],
		20: [14.0, 39.0, 36.8,  9.92, 0.28],
		25: [10.0, 35.0, 41.8, 12.80, 0.40],
	},
	MonsterClass.RARE: {
		1:  [26.0, 48.0, 21.5,  4.50, 0.00],
		5:  [18.0, 44.0, 29.5,  8.30, 0.20],
		10: [12.0, 38.0, 36.5, 13.10, 0.40],
		15: [ 8.0, 32.0, 41.5, 17.85, 0.65],
		20: [ 5.0, 26.0, 45.0, 23.05, 0.95],
		25: [ 3.0, 21.0, 46.7, 28.00, 1.30],
	},
	MonsterClass.BOSS: {
		1:  [ 6.0, 42.0, 39.5, 12.50, 0.00],
		5:  [ 3.0, 31.0, 45.5, 19.50, 1.00],
		10: [ 1.0, 22.0, 48.0, 27.30, 1.70],
		15: [ 0.0, 15.0, 47.5, 35.00, 2.50],
		20: [ 0.0, 10.0, 44.5, 42.10, 3.40],
		25: [ 0.0,  6.0, 40.5, 49.00, 4.50],
	},
}

## Bonus de Item Level (ilvl) por classificacao do monstro
const ILVL_BONUS_BY_CLASS: Dictionary = {
	MonsterClass.NORMAL: 0,
	MonsterClass.MAGIC:  1,
	MonsterClass.RARE:   2,
	MonsterClass.BOSS:   3,
}

## Chance de 4 modificadores (em vez de 3) ao gerar um item RARE (Amarelo), escalando por ilvl.
const RARE_FOUR_MOD_CHANCE_KEYFRAMES: Array[float] = [0.15, 0.22, 0.30, 0.38, 0.46, 0.55]

## Nivel minimo de item (ilvl) para habilitar sorteio de equipamento UNIQUE (Vermelho) no Ato 1.
const MIN_ILVL_FOR_UNIQUE: int = 3

## ---------------------------------------------------------------------------
## 4. TABELAS DE AFIXOS PROGRESSIVOS POR TIER E NIVEL DE ITEM (ILVL)
## ---------------------------------------------------------------------------
## Cada entrada define:
## - id, name, type (PREFIX ou SUFFIX), stat, fmt, min, max, tier (1..5), min_ilvl (1, 5, 10, 15, 20), weight, slots.
##
## Nota de Design (Sobreposicao Intencional):
## Os intervalos entre tiers possuem leve sobreposicao e amplitude suficiente para que um item
## Azul (MAGIC, 2 modificadores com rolagem alta de tier compativel) possa superar em poder efetivo
## um item Amarelo (RARE, 3 modificadores com rolagens baixas ou de tiers inferiores).
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
		# ===================== PREFIXOS DE DANO FISICO (ARMAS) =====================
		{"id": "pref_dmg_t1", "name": "Afiado",       "type": A.PREFIX, "stat": "damage", "fmt": "+%d de Dano", "min": 1.0,  "max": 3.0,  "tier": 1, "min_ilvl": 1,  "weight": 100.0, "slots": weapons},
		{"id": "pref_dmg_t2", "name": "Talhante",     "type": A.PREFIX, "stat": "damage", "fmt": "+%d de Dano", "min": 2.0,  "max": 5.0,  "tier": 2, "min_ilvl": 5,  "weight": 90.0,  "slots": weapons},
		{"id": "pref_dmg_t3", "name": "Cruel",        "type": A.PREFIX, "stat": "damage", "fmt": "+%d de Dano", "min": 4.0,  "max": 8.0,  "tier": 3, "min_ilvl": 10, "weight": 80.0,  "slots": weapons},
		{"id": "pref_dmg_t4", "name": "Impiedoso",    "type": A.PREFIX, "stat": "damage", "fmt": "+%d de Dano", "min": 6.0,  "max": 12.0, "tier": 4, "min_ilvl": 15, "weight": 68.0,  "slots": weapons},
		{"id": "pref_dmg_t5", "name": "Tirânico",     "type": A.PREFIX, "stat": "damage", "fmt": "+%d de Dano", "min": 9.0,  "max": 16.0, "tier": 5, "min_ilvl": 20, "weight": 55.0,  "slots": weapons},

		# ===================== PREFIXOS DE ARMADURA (DEFESA) =====================
		{"id": "pref_arm_t1", "name": "Reforçado",    "type": A.PREFIX, "stat": "armor",  "fmt": "+%d de Armadura", "min": 2.0,  "max": 4.0,  "tier": 1, "min_ilvl": 1,  "weight": 100.0, "slots": armors},
		{"id": "pref_arm_t2", "name": "Blindado",     "type": A.PREFIX, "stat": "armor",  "fmt": "+%d de Armadura", "min": 3.0,  "max": 7.0,  "tier": 2, "min_ilvl": 5,  "weight": 90.0,  "slots": armors},
		{"id": "pref_arm_t3", "name": "Murado",       "type": A.PREFIX, "stat": "armor",  "fmt": "+%d de Armadura", "min": 5.0,  "max": 11.0, "tier": 3, "min_ilvl": 10, "weight": 80.0,  "slots": armors},
		{"id": "pref_arm_t4", "name": "Inabalável",   "type": A.PREFIX, "stat": "armor",  "fmt": "+%d de Armadura", "min": 8.0,  "max": 16.0, "tier": 4, "min_ilvl": 15, "weight": 68.0,  "slots": armors},
		{"id": "pref_arm_t5", "name": "Impenetrável", "type": A.PREFIX, "stat": "armor",  "fmt": "+%d de Armadura", "min": 11.0, "max": 22.0, "tier": 5, "min_ilvl": 20, "weight": 55.0,  "slots": armors},

		# ===================== PREFIXOS DE VIDA MAXIMA =====================
		{"id": "pref_hp_t1",  "name": "Saudável",     "type": A.PREFIX, "stat": "max_health", "fmt": "+%d de Vida", "min": 4.0,  "max": 10.0, "tier": 1, "min_ilvl": 1,  "weight": 100.0, "slots": vitality_gear},
		{"id": "pref_hp_t2",  "name": "Robusto",      "type": A.PREFIX, "stat": "max_health", "fmt": "+%d de Vida", "min": 8.0,  "max": 16.0, "tier": 2, "min_ilvl": 5,  "weight": 92.0,  "slots": vitality_gear},
		{"id": "pref_hp_t3",  "name": "Vigoroso",     "type": A.PREFIX, "stat": "max_health", "fmt": "+%d de Vida", "min": 13.0, "max": 25.0, "tier": 3, "min_ilvl": 10, "weight": 82.0,  "slots": vitality_gear},
		{"id": "pref_hp_t4",  "name": "Vital",        "type": A.PREFIX, "stat": "max_health", "fmt": "+%d de Vida", "min": 20.0, "max": 36.0, "tier": 4, "min_ilvl": 15, "weight": 70.0,  "slots": vitality_gear},
		{"id": "pref_hp_t5",  "name": "Imortal",      "type": A.PREFIX, "stat": "max_health", "fmt": "+%d de Vida", "min": 28.0, "max": 50.0, "tier": 5, "min_ilvl": 20, "weight": 58.0,  "slots": vitality_gear},

		# ===================== SUFIXOS DE FORCA =====================
		{"id": "suff_str_t1", "name": "do Bruto",     "type": A.SUFFIX, "stat": "strength",     "fmt": "+%d de Força", "min": 1.0, "max": 2.0,  "tier": 1, "min_ilvl": 1,  "weight": 100.0, "slots": all_equip},
		{"id": "suff_str_t2", "name": "do Guerreiro", "type": A.SUFFIX, "stat": "strength",     "fmt": "+%d de Força", "min": 2.0, "max": 4.0,  "tier": 2, "min_ilvl": 5,  "weight": 90.0,  "slots": all_equip},
		{"id": "suff_str_t3", "name": "do Urso",      "type": A.SUFFIX, "stat": "strength",     "fmt": "+%d de Força", "min": 3.0, "max": 6.0,  "tier": 3, "min_ilvl": 10, "weight": 80.0,  "slots": all_equip},
		{"id": "suff_str_t4", "name": "do Golias",    "type": A.SUFFIX, "stat": "strength",     "fmt": "+%d de Força", "min": 5.0, "max": 9.0,  "tier": 4, "min_ilvl": 15, "weight": 68.0,  "slots": all_equip},
		{"id": "suff_str_t5", "name": "do Titã",      "type": A.SUFFIX, "stat": "strength",     "fmt": "+%d de Força", "min": 7.0, "max": 12.0, "tier": 5, "min_ilvl": 20, "weight": 55.0,  "slots": all_equip},

		# ===================== SUFIXOS DE AGILIDADE =====================
		{"id": "suff_agi_t1", "name": "da Raposa",    "type": A.SUFFIX, "stat": "agility",      "fmt": "+%d de Agilidade", "min": 1.0, "max": 2.0,  "tier": 1, "min_ilvl": 1,  "weight": 100.0, "slots": all_equip},
		{"id": "suff_agi_t2", "name": "do Caçador",   "type": A.SUFFIX, "stat": "agility",      "fmt": "+%d de Agilidade", "min": 2.0, "max": 4.0,  "tier": 2, "min_ilvl": 5,  "weight": 90.0,  "slots": all_equip},
		{"id": "suff_agi_t3", "name": "do Falcão",    "type": A.SUFFIX, "stat": "agility",      "fmt": "+%d de Agilidade", "min": 3.0, "max": 6.0,  "tier": 3, "min_ilvl": 10, "weight": 80.0,  "slots": all_equip},
		{"id": "suff_agi_t4", "name": "do Lince",     "type": A.SUFFIX, "stat": "agility",      "fmt": "+%d de Agilidade", "min": 5.0, "max": 9.0,  "tier": 4, "min_ilvl": 15, "weight": 68.0,  "slots": all_equip},
		{"id": "suff_agi_t5", "name": "do Vento",     "type": A.SUFFIX, "stat": "agility",      "fmt": "+%d de Agilidade", "min": 7.0, "max": 12.0, "tier": 5, "min_ilvl": 20, "weight": 55.0,  "slots": all_equip},

		# ===================== SUFIXOS DE INTELIGENCIA =====================
		{"id": "suff_int_t1", "name": "do Aprendiz",  "type": A.SUFFIX, "stat": "intelligence", "fmt": "+%d de Inteligência", "min": 1.0, "max": 2.0,  "tier": 1, "min_ilvl": 1,  "weight": 95.0,  "slots": all_equip},
		{"id": "suff_int_t2", "name": "do Acólito",   "type": A.SUFFIX, "stat": "intelligence", "fmt": "+%d de Inteligência", "min": 2.0, "max": 4.0,  "tier": 2, "min_ilvl": 5,  "weight": 86.0,  "slots": all_equip},
		{"id": "suff_int_t3", "name": "da Coruja",    "type": A.SUFFIX, "stat": "intelligence", "fmt": "+%d de Inteligência", "min": 3.0, "max": 6.0,  "tier": 3, "min_ilvl": 10, "weight": 76.0,  "slots": all_equip},
		{"id": "suff_int_t4", "name": "do Sábio",     "type": A.SUFFIX, "stat": "intelligence", "fmt": "+%d de Inteligência", "min": 5.0, "max": 9.0,  "tier": 4, "min_ilvl": 15, "weight": 64.0,  "slots": all_equip},
		{"id": "suff_int_t5", "name": "do Oráculo",   "type": A.SUFFIX, "stat": "intelligence", "fmt": "+%d de Inteligência", "min": 7.0, "max": 12.0, "tier": 5, "min_ilvl": 20, "weight": 52.0,  "slots": all_equip},

		# ===================== SUFIXOS DE CHANCE CRITICA =====================
		{"id": "suff_crit_t1", "name": "da Precisão",   "type": A.SUFFIX, "stat": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.01, "max": 0.02, "tier": 1, "min_ilvl": 1,  "weight": 75.0, "slots": crit_gear},
		{"id": "suff_crit_t2", "name": "do Golpe",      "type": A.SUFFIX, "stat": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.02, "max": 0.03, "tier": 2, "min_ilvl": 5,  "weight": 68.0, "slots": crit_gear},
		{"id": "suff_crit_t3", "name": "da Ferocidade", "type": A.SUFFIX, "stat": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.02, "max": 0.04, "tier": 3, "min_ilvl": 10, "weight": 60.0, "slots": crit_gear},
		{"id": "suff_crit_t4", "name": "da Ruína",      "type": A.SUFFIX, "stat": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.03, "max": 0.05, "tier": 4, "min_ilvl": 15, "weight": 52.0, "slots": crit_gear},
		{"id": "suff_crit_t5", "name": "da Execução",   "type": A.SUFFIX, "stat": "crit_chance", "fmt": "+%d%% de Crítico", "min": 0.04, "max": 0.06, "tier": 5, "min_ilvl": 20, "weight": 44.0, "slots": crit_gear},
	]

## ---------------------------------------------------------------------------
## UTILITARIOS DE INTERPOLACAO E CONSULTA DE CURVAS
## ---------------------------------------------------------------------------
static func get_monster_class_name(monster_class: int) -> String:
	match monster_class:
		MonsterClass.NORMAL:
			return "Normal"
		MonsterClass.MAGIC:
			return "Mágico"
		MonsterClass.RARE:
			return "Raro"
		MonsterClass.BOSS:
			return "Chefe"
		_:
			return "Normal"

static func get_equipment_drop_chance(monster_level: int, monster_class: int) -> float:
	var clamped_class: int = clampi(monster_class, MonsterClass.NORMAL, MonsterClass.BOSS)
	var curve: Array = DROP_CHANCE_BY_CLASS_KEYFRAMES.get(clamped_class, DROP_CHANCE_BY_CLASS_KEYFRAMES[MonsterClass.NORMAL])
	return clampf(_interpolate_scalar_curve(monster_level, curve), 0.0, 1.0)

static func get_drop_count_weights(monster_level: int, monster_class: int) -> Array[float]:
	var clamped_class: int = clampi(monster_class, MonsterClass.NORMAL, MonsterClass.BOSS)
	var table: Dictionary = DROP_COUNT_WEIGHTS_BY_CLASS.get(clamped_class, DROP_COUNT_WEIGHTS_BY_CLASS[MonsterClass.NORMAL])
	return _interpolate_vector_table(monster_level, table, 4)

static func get_rarity_weights(monster_level: int, monster_class: int, allow_unique: bool = true) -> Array[float]:
	var clamped_class: int = clampi(monster_class, MonsterClass.NORMAL, MonsterClass.BOSS)
	var table: Dictionary = RARITY_WEIGHTS_BY_CLASS.get(clamped_class, RARITY_WEIGHTS_BY_CLASS[MonsterClass.NORMAL])
	var weights: Array[float] = _interpolate_vector_table(monster_level, table, 5)
	var effective_ilvl: int = get_effective_item_level(monster_level, clamped_class)
	if not allow_unique or effective_ilvl < MIN_ILVL_FOR_UNIQUE:
		weights[4] = 0.0
	return normalize_weights(weights)

static func get_effective_item_level(monster_level: int, monster_class: int) -> int:
	var clamped_class: int = clampi(monster_class, MonsterClass.NORMAL, MonsterClass.BOSS)
	var bonus: int = int(ILVL_BONUS_BY_CLASS.get(clamped_class, 0))
	return maxi(1, monster_level + bonus)

static func get_rare_four_mod_chance(item_level: int) -> float:
	return clampf(_interpolate_scalar_curve(item_level, RARE_FOUR_MOD_CHANCE_KEYFRAMES), 0.0, 1.0)

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

static func _interpolate_scalar_curve(level: int, values: Array) -> float:
	if values.is_empty():
		return 0.0
	if level <= KEYFRAME_LEVELS[0]:
		return float(values[0])
	var last_idx: int = KEYFRAME_LEVELS.size() - 1
	if level >= KEYFRAME_LEVELS[last_idx]:
		var extra_levels: int = level - KEYFRAME_LEVELS[last_idx]
		var prev_slope: float = (float(values[last_idx]) - float(values[last_idx - 1])) / float(KEYFRAME_LEVELS[last_idx] - KEYFRAME_LEVELS[last_idx - 1])
		return float(values[last_idx]) + prev_slope * float(extra_levels) * 0.35
	for i in range(last_idx):
		var lv_a: int = KEYFRAME_LEVELS[i]
		var lv_b: int = KEYFRAME_LEVELS[i + 1]
		if level >= lv_a and level <= lv_b:
			var t: float = float(level - lv_a) / float(maxi(1, lv_b - lv_a))
			return lerpf(float(values[i]), float(values[i + 1]), t)
	return float(values[last_idx])

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
		for j in range(vec_size):
			result[j] = float(v_last[j])
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
