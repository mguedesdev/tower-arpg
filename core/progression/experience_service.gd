extends RefCounted
class_name ExperienceService

## ============================================================================
## SERVIÇO CANÔNICO DE EXPERIÊNCIA E LEVELING (ARPG GODOT 4)
## ============================================================================
## Baseado na Especificação 09 (Estudo e Especificação do Sistema de Leveling).
## • Curva matemática contínua: xp_to_next(L) = round(90 + 45 * (L - 1)^2.10).
## • Suporte integral de níveis: 1 a 25 (Ato 1) e escala até 90, 100, 120+.
## • XP-base de monstro escalonável: base_monster_xp(L) = round(18 + 4.2 * L^1.35).
## • Fatores de família: Caveira (1.0), Lobo (1.2), Caveirão (1.8).
## • Multiplicadores por classe/raridade: Normal (1.0), Mágico (1.5), Raro (2.5), Elite (4.0).
## • Chefes autorais: base * boss_xp_units (20) + bônus de 1.5x na 1ª vitória.
## • Anti-Power-Leveling: crédito máximo até player_level + 5.
## • Anti-Farm Trivial: redução suave pow(0.80, excesso_gap) com piso de 5%.
## • Múltiplos level-ups e preservação estrita de overflow.

signal progress_changed(level: int, current_xp_in_level: int, xp_required_for_next: int, total_xp: int)
signal level_gained(new_level: int, previous_level: int)

const HIGH_LEVEL_CREDIT_CAP: int = 5
const BOSS_DEFAULT_XP_UNITS: int = 20
const FIRST_DEFEAT_MULTIPLIER: float = 1.50
const MIN_UNDERLEVEL_FACTOR: float = 0.05

var current_level: int = 1
var total_xp: int = 0
var current_xp_in_level: int = 0

## Registro persistente de chefes derrotados pela primeira vez
var defeated_boss_ids: Array[String] = []


func _init(p_level: int = 1, p_total_xp: int = -1) -> void:
	current_level = maxi(1, p_level)
	if p_total_xp >= 0:
		total_xp = p_total_xp
		_recalculate_level_and_progress_from_total()
	else:
		total_xp = get_cumulative_xp_for_level(current_level)
		current_xp_in_level = 0


## ----------------------------------------------------------------------------
## 1. FÓRMULAS MATEMÁTICAS DA ESPECIFICAÇÃO 09
## ----------------------------------------------------------------------------
static func get_xp_required_for_next_level(lvl: int) -> int:
	var l: int = maxi(1, lvl)
	var exp_factor: float = pow(float(l - 1), 2.10)
	return maxi(90, roundi(90.0 + 45.0 * exp_factor))


static func get_cumulative_xp_for_level(target_lvl: int) -> int:
	var total: int = 0
	for l in range(1, target_lvl):
		total += get_xp_required_for_next_level(l)
	return total


static func get_base_monster_xp(monster_lvl: int) -> int:
	var l: int = maxi(1, monster_lvl)
	var exp_factor: float = pow(float(l), 1.35)
	return maxi(1, roundi(18.0 + 4.2 * exp_factor))


static func get_family_factor(family_id: String) -> float:
	match family_id.to_lower():
		"wolf", "lobo":
			return 1.20
		"boss", "caveirao", "heavy", "skeleton_boss":
			return 1.80
		"archer", "arqueiro":
			return 1.15
		"caster", "conjurador":
			return 1.35
		_:
			return 1.00 # Caveira / esqueleto padrão


static func get_rank_multiplier(monster_rank: int) -> float:
	match monster_rank:
		LootBalanceConfig.MonsterClass.MAGIC:
			return 1.50
		LootBalanceConfig.MonsterClass.RARE:
			return 2.50
		LootBalanceConfig.MonsterClass.HERO:
			return 4.00
		LootBalanceConfig.MonsterClass.BOSS:
			return 1.00 # Chefes usam cálculo autoral via boss_units
		_:
			return 1.00 # Normal


static func get_underlevel_penalty(p_level: int, m_level: int) -> float:
	var allowed_lower_gap: int = mini(7, 3 + int(p_level / 30))
	var lower_gap_excess: int = maxi(0, p_level - m_level - allowed_lower_gap)
	if lower_gap_excess <= 0:
		return 1.0
	return maxf(MIN_UNDERLEVEL_FACTOR, pow(0.80, float(lower_gap_excess)))


## ----------------------------------------------------------------------------
## 2. CÁLCULO CENTRAL DE XP DE ABATE (PURAMENTE DETERMINÍSTICO)
## ----------------------------------------------------------------------------
func calculate_kill_xp(
	m_level: int,
	family_id: String,
	m_rank: int,
	is_boss: bool = false,
	boss_id: String = ""
) -> int:
	var p_lvl: int = current_level
	# 1. Anti-Power-Leveling: crédito máximo de nível
	var credited_level: int = mini(m_level, p_lvl + HIGH_LEVEL_CREDIT_CAP)
	var base_xp: float = float(get_base_monster_xp(credited_level))

	var raw_xp: float = 0.0
	if is_boss:
		# Cálculo autoral de chefes
		raw_xp = base_xp * float(BOSS_DEFAULT_XP_UNITS)
		if not boss_id.is_empty() and not defeated_boss_ids.has(boss_id):
			raw_xp *= FIRST_DEFEAT_MULTIPLIER
	else:
		var fam_mult: float = get_family_factor(family_id)
		var rank_mult: float = get_rank_multiplier(m_rank)
		raw_xp = base_xp * fam_mult * rank_mult

	# 2. Anti-Farm Trivial: penalidade suave para monstros fracos
	var underlevel_factor: float = get_underlevel_penalty(p_lvl, m_level)
	var final_xp: int = maxi(1, roundi(raw_xp * underlevel_factor))
	return final_xp


## ----------------------------------------------------------------------------
## 3. CONCESSÃO DE XP, SUBIDA DE NÍVEL E OVERFLOW
## ----------------------------------------------------------------------------
func add_xp(amount: int, boss_id_defeated: String = "") -> Array[int]:
	if amount <= 0:
		return []

	if not boss_id_defeated.is_empty() and not defeated_boss_ids.has(boss_id_defeated):
		defeated_boss_ids.append(boss_id_defeated)

	total_xp += amount
	current_xp_in_level += amount

	var levels_gained: Array[int] = []
	var req: int = get_xp_required_for_next_level(current_level)

	# Processa subida de nível com preservação estrita de overflow (suporta múltiplos níveis)
	while current_xp_in_level >= req:
		current_xp_in_level -= req
		var old_level: int = current_level
		current_level += 1
		levels_gained.append(current_level)
		level_gained.emit(current_level, old_level)
		req = get_xp_required_for_next_level(current_level)

	progress_changed.emit(current_level, current_xp_in_level, req, total_xp)
	return levels_gained


## ----------------------------------------------------------------------------
## 4. CONSULTA DE PROGRESSO VISUAL
## ----------------------------------------------------------------------------
func get_progress_ratio() -> float:
	var req: int = get_xp_required_for_next_level(current_level)
	if req <= 0:
		return 1.0
	return clampf(float(current_xp_in_level) / float(req), 0.0, 1.0)


func get_progress_percentage() -> int:
	return roundi(get_progress_ratio() * 100.0)


func get_xp_remaining() -> int:
	var req: int = get_xp_required_for_next_level(current_level)
	return maxi(0, req - current_xp_in_level)


## ----------------------------------------------------------------------------
## 5. RECONSTRUÇÃO E PERSISTÊNCIA
## ----------------------------------------------------------------------------
func _recalculate_level_and_progress_from_total() -> void:
	if total_xp <= 0:
		current_level = 1
		current_xp_in_level = 0
		return

	var lvl: int = 1
	var xp_acc: int = total_xp
	while true:
		var req: int = get_xp_required_for_next_level(lvl)
		if xp_acc >= req:
			xp_acc -= req
			lvl += 1
		else:
			break

	current_level = lvl
	current_xp_in_level = xp_acc


func to_dictionary() -> Dictionary:
	return {
		"version": 1,
		"level": current_level,
		"total_xp": total_xp,
		"current_xp_in_level": current_xp_in_level,
		"defeated_boss_ids": defeated_boss_ids.duplicate()
	}


func from_dictionary(data: Dictionary) -> void:
	current_level = maxi(1, int(data.get("level", 1)))
	total_xp = maxi(0, int(data.get("total_xp", 0)))
	current_xp_in_level = maxi(0, int(data.get("current_xp_in_level", 0)))
	defeated_boss_ids.clear()
	for b in data.get("defeated_boss_ids", []):
		defeated_boss_ids.append(String(b))
	_recalculate_level_and_progress_from_total()
	var req: int = get_xp_required_for_next_level(current_level)
	progress_changed.emit(current_level, current_xp_in_level, req, total_xp)
