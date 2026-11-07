extends RefCounted
class_name MonsterDifficultyService

## ============================================================================
## SERVIÇO CENTRAL DE DIFICULDADE, ESCALONAMENTO E AFIXOS DE MONSTROS (ARPG PvE)
## ============================================================================
## Baseado na Especificação 05 (Estudo Completo de Dificuldade dos Monstros).
## • Escalonamento contínuo do nível 1 ao 90+ sem limites artificiais no nível 25.
## • 5 Classes (Ranks): Normal, Mágico, Raro, Herói/Elite e Chefe.
## • 6 Arquétipos de Combate: Melee, Ranged, Caster, Tank, Support, Summoner.
## • Biblioteca de Modificadores com regras estritas de conflito e tiers T1 (melhor) a T5.
## • Orçamento de Encontros e limites de densidade.

const Rank = LootBalanceConfig.MonsterClass
const MonsterModifierDefinition = preload("res://core/combat/monster_modifier_definition.gd")

## ----------------------------------------------------------------------------
## 1. TABELAS DE MULTIPLICADORES POR CLASSE / RANK (Seção 5.2)
## ----------------------------------------------------------------------------
const RANK_CONFIG: Dictionary = {
	Rank.NORMAL: {
		"id": "normal",
		"name": "Normal",
		"hp_mult": 1.00,
		"dmg_mult": 1.00,
		"speed_mult": 1.00,
		"xp_mult": 1.00,
		"budget": 1.0,
		"color": Color(0.92, 0.88, 0.80), # Branco / Osso neutro
		"name_prefix": "",
	},
	Rank.MAGIC: {
		"id": "magic",
		"name": "Mágico",
		"hp_mult": 1.50,
		"dmg_mult": 1.12,
		"speed_mult": 1.03,
		"xp_mult": 1.50,
		"budget": 2.0,
		"color": Color(0.32, 0.68, 1.00), # Azul arcano
		"name_prefix": "Mágico",
	},
	Rank.RARE: {
		"id": "rare",
		"name": "Raro",
		"hp_mult": 2.40,
		"dmg_mult": 1.22,
		"speed_mult": 1.05,
		"xp_mult": 2.50,
		"budget": 5.0,
		"color": Color(1.00, 0.82, 0.22), # Ouro / Amarelo épico
		"name_prefix": "Raro",
	},
	Rank.HERO: {
		"id": "hero",
		"name": "Herói/Elite",
		"hp_mult": 3.80,
		"dmg_mult": 1.30,
		"speed_mult": 1.08,
		"xp_mult": 4.00,
		"budget": 9.0,
		"color": Color(0.85, 0.38, 1.00), # Roxo / Púrpura abissal
		"name_prefix": "Elite",
	},
	Rank.BOSS: {
		"id": "boss",
		"name": "Chefe",
		"hp_mult": 6.00,
		"dmg_mult": 1.50,
		"speed_mult": 1.00,
		"xp_mult": 8.00,
		"budget": 25.0,
		"color": Color(1.00, 0.22, 0.22), # Vermelho carmesim
		"name_prefix": "Chefe",
	},
}

## ----------------------------------------------------------------------------
## 2. MULTIPLICADORES POR ARQUÉTIPO DE COMBATE (Seção 7)
## ----------------------------------------------------------------------------
const ARCHETYPE_CONFIG: Dictionary = {
	"melee": {
		"hp_mult": 1.00, "dmg_mult": 1.00, "speed_mult": 1.00, "defense_pct": 0.00
	},
	"tank": {
		"hp_mult": 1.60, "dmg_mult": 0.75, "speed_mult": 0.85, "defense_pct": 0.22
	},
	"ranged": {
		"hp_mult": 0.75, "dmg_mult": 1.15, "speed_mult": 1.05, "defense_pct": 0.00
	},
	"caster": {
		"hp_mult": 0.70, "dmg_mult": 1.25, "speed_mult": 0.95, "defense_pct": 0.00
	},
	"support": {
		"hp_mult": 0.90, "dmg_mult": 0.70, "speed_mult": 1.00, "defense_pct": 0.05
	},
	"summoner": {
		"hp_mult": 1.10, "dmg_mult": 0.80, "speed_mult": 0.90, "defense_pct": 0.08
	},
}

## Catálogo de modificadores registrados
static var _catalog: Dictionary = {}
static var _catalog_initialized: bool = false


## ----------------------------------------------------------------------------
## 3. FÓRMULAS DE PROGRESSÃO BASE POR NÍVEL (1 A 90+) (Seção 4.1)
## ----------------------------------------------------------------------------
static func calculate_base_hp(ref_hp: int, monster_level: int) -> int:
	var l: int = maxi(1, monster_level)
	var growth: float = 1.0 + 0.055 * float(l - 1)
	return maxi(1, roundi(float(ref_hp) * pow(growth, 1.10)))


static func calculate_base_damage(ref_dmg: int, monster_level: int) -> int:
	var l: int = maxi(1, monster_level)
	var growth: float = 1.0 + 0.035 * float(l - 1)
	return maxi(1, roundi(float(ref_dmg) * pow(growth, 1.05)))


static func calculate_base_speed(ref_spd: float, monster_level: int) -> float:
	var l: int = maxi(1, monster_level)
	# Crescimento suave (máximo +0.55m/s no endgame) para não quebrar a sincronia de animações
	return ref_spd + minf(float(l - 1) * 0.007, 0.55)


## ----------------------------------------------------------------------------
## 4. RESOLUÇÃO COMPLETA DE STATS DE COMBATE
## ----------------------------------------------------------------------------
static func resolve_monster_stats(
	ref_hp: int,
	ref_dmg: int,
	ref_spd: float,
	monster_level: int,
	monster_rank: int,
	archetype: String = "melee",
	active_modifiers: Array = []
) -> Dictionary:
	var lvl := maxi(1, monster_level)
	var r_cfg: Dictionary = RANK_CONFIG.get(monster_rank, RANK_CONFIG[Rank.NORMAL])
	var a_cfg: Dictionary = ARCHETYPE_CONFIG.get(archetype, ARCHETYPE_CONFIG["melee"])

	# 1. Base por Nível
	var base_hp: int = calculate_base_hp(ref_hp, lvl)
	var base_dmg: int = calculate_base_damage(ref_dmg, lvl)
	var base_spd: float = calculate_base_speed(ref_spd, lvl)

	# 2. Multiplicadores de Rank e Arquétipo
	var rank_hp_m: float = float(r_cfg.get("hp_mult", 1.0))
	var rank_dmg_m: float = float(r_cfg.get("dmg_mult", 1.0))
	var rank_spd_m: float = float(r_cfg.get("speed_mult", 1.0))

	var arch_hp_m: float = float(a_cfg.get("hp_mult", 1.0))
	var arch_dmg_m: float = float(a_cfg.get("dmg_mult", 1.0))
	var arch_spd_m: float = float(a_cfg.get("speed_mult", 1.0))
	var arch_def_p: float = float(a_cfg.get("defense_pct", 0.0))

	# 3. Agregação Aditiva de Modificadores (evita cascatas multiplicativas explosivas)
	var mod_dmg_bonus: float = 0.0
	var mod_spd_bonus: float = 0.0
	var mod_dmg_reduction: float = 0.0
	var mod_burn_ratio: float = 0.0
	var mod_burn_duration: float = 0.0
	var mod_slow_pct: float = 0.0
	var mod_slow_duration: float = 0.0
	var mod_regen_pct: float = 0.0
	var mod_regen_cooldown: float = 3.5
	var mod_aura_radius: float = 0.0
	var mod_aura_dmg_mult: float = 1.0
	var mod_aura_spd_mult: float = 1.0

	for amod in active_modifiers:
		if not (amod is Dictionary):
			continue
		var p: Dictionary = amod.get("params", {})
		mod_dmg_bonus += float(p.get("damage_mult", 1.0)) - 1.0
		mod_spd_bonus += float(p.get("speed_mult", 1.0)) - 1.0
		mod_dmg_reduction += float(p.get("damage_reduction", 0.0))
		if p.has("burn_ratio"):
			mod_burn_ratio = maxf(mod_burn_ratio, float(p["burn_ratio"]))
			mod_burn_duration = maxf(mod_burn_duration, float(p.get("burn_duration", 3.0)))
		if p.has("slow_pct"):
			mod_slow_pct = maxf(mod_slow_pct, float(p["slow_pct"]))
			mod_slow_duration = maxf(mod_slow_duration, float(p.get("slow_duration", 2.0)))
		if p.has("regen_pct_sec"):
			mod_regen_pct = maxf(mod_regen_pct, float(p["regen_pct_sec"]))
			mod_regen_cooldown = minf(mod_regen_cooldown, float(p.get("hit_cooldown", 3.0)))
		if p.has("aura_radius"):
			mod_aura_radius = maxf(mod_aura_radius, float(p["aura_radius"]))
			mod_aura_dmg_mult = maxf(mod_aura_dmg_mult, float(p.get("aura_dmg_mult", 1.10)))
			mod_aura_spd_mult = maxf(mod_aura_spd_mult, float(p.get("aura_spd_mult", 1.12)))

	# 4. Cálculo final protegido por limites sanitários
	var final_hp: int = maxi(1, roundi(float(base_hp) * rank_hp_m * arch_hp_m))
	var final_dmg_mult: float = (1.0 + mod_dmg_bonus)
	var final_dmg: int = maxi(1, roundi(float(base_dmg) * rank_dmg_m * arch_dmg_m * final_dmg_mult))
	var final_spd: float = clampf(base_spd * rank_spd_m * arch_spd_m * (1.0 + mod_spd_bonus), 1.2, 5.5)
	var final_def_pct: float = clampf(arch_def_p + mod_dmg_reduction, 0.0, 0.65) # Cap de 65% de redução de dano

	return {
		"level": lvl,
		"rank": monster_rank,
		"archetype": archetype,
		"max_health": final_hp,
		"touch_damage": final_dmg,
		"movement_speed": final_spd,
		"damage_reduction_pct": final_def_pct,
		"burn_ratio": mod_burn_ratio,
		"burn_duration": mod_burn_duration,
		"slow_pct": mod_slow_pct,
		"slow_duration": mod_slow_duration,
		"regen_pct_sec": mod_regen_pct,
		"regen_cooldown": mod_regen_cooldown,
		"aura_radius": mod_aura_radius,
		"aura_dmg_mult": mod_aura_dmg_mult,
		"aura_spd_mult": mod_aura_spd_mult,
		"xp_reward_mult": float(r_cfg.get("xp_mult", 1.0)),
		"rank_color": r_cfg.get("color", Color.WHITE),
	}


## ----------------------------------------------------------------------------
## 5. CATÁLOGO DE MODIFICADORES (Seção 6.2)
## ----------------------------------------------------------------------------
static func _ensure_catalog_initialized() -> void:
	if _catalog_initialized:
		return
	_catalog_initialized = true
	_catalog.clear()

	# 1. BRUTAL (Ofensivo)
	var brutal: MonsterModifierDefinition = MonsterModifierDefinition.new()
	brutal.id = "brutal"
	brutal.display_name = "Brutal"
	brutal.category = "offensive"
	brutal.allowed_ranks = [Rank.MAGIC, Rank.RARE, Rank.HERO]
	brutal.allowed_archetypes = ["melee", "tank"]
	brutal.min_monster_level = 5
	brutal.conflict_groups = ["damage_boost"]
	brutal.budget_cost = 2.0
	brutal.color_tint = Color(1.0, 0.45, 0.35)
	brutal.tiers = [
		{"tier": 5, "min_level": 5,  "weight": 100, "params": {"damage_mult": 1.20}},
		{"tier": 4, "min_level": 15, "weight": 45,  "params": {"damage_mult": 1.26}},
		{"tier": 3, "min_level": 30, "weight": 20,  "params": {"damage_mult": 1.32}},
		{"tier": 2, "min_level": 55, "weight": 8,   "params": {"damage_mult": 1.38}},
		{"tier": 1, "min_level": 75, "weight": 2,   "params": {"damage_mult": 1.45}},
	]
	_catalog[brutal.id] = brutal

	# 2. VELOZ (Mobilidade)
	var fast: MonsterModifierDefinition = MonsterModifierDefinition.new()
	fast.id = "extra_fast"
	fast.display_name = "Veloz"
	fast.category = "mobility"
	fast.allowed_ranks = [Rank.MAGIC, Rank.RARE, Rank.HERO]
	fast.allowed_archetypes = ["melee", "ranged", "caster", "tank", "support", "summoner"]
	fast.min_monster_level = 6
	fast.conflict_groups = ["movement_speed"]
	fast.budget_cost = 2.0
	fast.color_tint = Color(0.40, 1.0, 0.60)
	fast.tiers = [
		{"tier": 5, "min_level": 6,  "weight": 100, "params": {"speed_mult": 1.12}},
		{"tier": 4, "min_level": 18, "weight": 45,  "params": {"speed_mult": 1.16}},
		{"tier": 3, "min_level": 35, "weight": 20,  "params": {"speed_mult": 1.20}},
		{"tier": 2, "min_level": 60, "weight": 8,   "params": {"speed_mult": 1.24}},
		{"tier": 1, "min_level": 75, "weight": 2,   "params": {"speed_mult": 1.28}},
	]
	_catalog[fast.id] = fast

	# 3. COURAÇADO (Defensivo)
	var armored: MonsterModifierDefinition = MonsterModifierDefinition.new()
	armored.id = "armored"
	armored.display_name = "Couraçado"
	armored.category = "defensive"
	armored.allowed_ranks = [Rank.MAGIC, Rank.RARE, Rank.HERO]
	armored.allowed_archetypes = ["melee", "tank", "support"]
	armored.min_monster_level = 5
	armored.conflict_groups = ["damage_reduction"]
	armored.budget_cost = 2.0
	armored.color_tint = Color(0.70, 0.75, 0.85)
	armored.tiers = [
		{"tier": 5, "min_level": 5,  "weight": 100, "params": {"damage_reduction": 0.18, "speed_mult": 0.95}},
		{"tier": 4, "min_level": 15, "weight": 45,  "params": {"damage_reduction": 0.24, "speed_mult": 0.93}},
		{"tier": 3, "min_level": 30, "weight": 20,  "params": {"damage_reduction": 0.30, "speed_mult": 0.90}},
		{"tier": 2, "min_level": 55, "weight": 8,   "params": {"damage_reduction": 0.34, "speed_mult": 0.88}},
		{"tier": 1, "min_level": 75, "weight": 2,   "params": {"damage_reduction": 0.38, "speed_mult": 0.86}},
	]
	_catalog[armored.id] = armored

	# 4. REGENERADOR (Defensivo / Recuperação)
	var regen: MonsterModifierDefinition = MonsterModifierDefinition.new()
	regen.id = "regenerator"
	regen.display_name = "Regenerador"
	regen.category = "defensive"
	regen.allowed_ranks = [Rank.MAGIC, Rank.RARE, Rank.HERO]
	regen.allowed_archetypes = ["melee", "tank", "support", "summoner"]
	regen.min_monster_level = 14
	regen.conflict_groups = ["healing_passive"]
	regen.budget_cost = 3.0
	regen.color_tint = Color(0.35, 1.0, 0.40)
	regen.tiers = [
		{"tier": 5, "min_level": 14, "weight": 100, "params": {"regen_pct_sec": 0.015, "hit_cooldown": 3.5}},
		{"tier": 4, "min_level": 25, "weight": 45,  "params": {"regen_pct_sec": 0.020, "hit_cooldown": 3.2}},
		{"tier": 3, "min_level": 45, "weight": 20,  "params": {"regen_pct_sec": 0.025, "hit_cooldown": 3.0}},
		{"tier": 2, "min_level": 65, "weight": 8,   "params": {"regen_pct_sec": 0.028, "hit_cooldown": 2.8}},
		{"tier": 1, "min_level": 80, "weight": 2,   "params": {"regen_pct_sec": 0.032, "hit_cooldown": 2.5}},
	]
	_catalog[regen.id] = regen

	# 5. INCENDIÁRIO (Ofensivo / Elemento Fogo)
	var ignite: MonsterModifierDefinition = MonsterModifierDefinition.new()
	ignite.id = "ignited"
	ignite.display_name = "Incendiário"
	ignite.category = "offensive"
	ignite.allowed_ranks = [Rank.MAGIC, Rank.RARE, Rank.HERO]
	ignite.allowed_archetypes = ["melee", "ranged", "caster"]
	ignite.min_monster_level = 10
	ignite.conflict_groups = ["elemental_attack"]
	ignite.budget_cost = 3.0
	ignite.color_tint = Color(1.0, 0.55, 0.15)
	ignite.tiers = [
		{"tier": 5, "min_level": 10, "weight": 100, "params": {"burn_ratio": 0.25, "burn_duration": 2.5}},
		{"tier": 4, "min_level": 20, "weight": 45,  "params": {"burn_ratio": 0.30, "burn_duration": 2.8}},
		{"tier": 3, "min_level": 40, "weight": 20,  "params": {"burn_ratio": 0.35, "burn_duration": 3.0}},
		{"tier": 2, "min_level": 65, "weight": 8,   "params": {"burn_ratio": 0.40, "burn_duration": 3.2}},
		{"tier": 1, "min_level": 80, "weight": 2,   "params": {"burn_ratio": 0.45, "burn_duration": 3.5}},
	]
	_catalog[ignite.id] = ignite

	# 6. GLACIAL (Controle / Elemento Gelo)
	var glacial: MonsterModifierDefinition = MonsterModifierDefinition.new()
	glacial.id = "glacial"
	glacial.display_name = "Glacial"
	glacial.category = "control"
	glacial.allowed_ranks = [Rank.MAGIC, Rank.RARE, Rank.HERO]
	glacial.allowed_archetypes = ["melee", "ranged", "caster"]
	glacial.min_monster_level = 13
	glacial.conflict_groups = ["elemental_attack"]
	glacial.budget_cost = 3.0
	glacial.color_tint = Color(0.45, 0.85, 1.0)
	glacial.tiers = [
		{"tier": 5, "min_level": 13, "weight": 100, "params": {"slow_pct": 0.18, "slow_duration": 1.8}},
		{"tier": 4, "min_level": 22, "weight": 45,  "params": {"slow_pct": 0.22, "slow_duration": 2.0}},
		{"tier": 3, "min_level": 45, "weight": 20,  "params": {"slow_pct": 0.25, "slow_duration": 2.2}},
		{"tier": 2, "min_level": 68, "weight": 8,   "params": {"slow_pct": 0.28, "slow_duration": 2.5}},
		{"tier": 1, "min_level": 82, "weight": 2,   "params": {"slow_pct": 0.30, "slow_duration": 2.8}},
	]
	_catalog[glacial.id] = glacial

	# 7. COMANDANTE (Suporte / Aura de Grupo)
	var commander: MonsterModifierDefinition = MonsterModifierDefinition.new()
	commander.id = "commander"
	commander.display_name = "Comandante"
	commander.category = "support"
	commander.allowed_ranks = [Rank.RARE, Rank.HERO]
	commander.allowed_archetypes = ["melee", "tank", "support"]
	commander.min_monster_level = 15
	commander.conflict_groups = ["aura_buff"]
	commander.budget_cost = 3.0
	commander.color_tint = Color(1.0, 0.85, 0.40)
	commander.tiers = [
		{"tier": 5, "min_level": 15, "weight": 100, "params": {"aura_radius": 6.0, "aura_dmg_mult": 1.10, "aura_spd_mult": 1.12}},
		{"tier": 4, "min_level": 25, "weight": 45,  "params": {"aura_radius": 6.5, "aura_dmg_mult": 1.14, "aura_spd_mult": 1.15}},
		{"tier": 3, "min_level": 45, "weight": 20,  "params": {"aura_radius": 7.0, "aura_dmg_mult": 1.18, "aura_spd_mult": 1.18}},
		{"tier": 2, "min_level": 70, "weight": 8,   "params": {"aura_radius": 7.5, "aura_dmg_mult": 1.22, "aura_spd_mult": 1.20}},
		{"tier": 1, "min_level": 85, "weight": 2,   "params": {"aura_radius": 8.0, "aura_dmg_mult": 1.25, "aura_spd_mult": 1.22}},
	]
	_catalog[commander.id] = commander


static func get_all_modifiers() -> Dictionary:
	_ensure_catalog_initialized()
	return _catalog


static func get_modifier(id: String) -> MonsterModifierDefinition:
	_ensure_catalog_initialized()
	return _catalog.get(id, null) as MonsterModifierDefinition


## ----------------------------------------------------------------------------
## 6. SORTEIO DETERMINÍSTICO E REGRAS DE EXCLUSÃO DE AFIXOS (Seção 6.3)
## ----------------------------------------------------------------------------
static func roll_modifiers(
	monster_level: int,
	monster_rank: int,
	archetype: String = "melee",
	family_tags: Array = [],
	rng: RandomNumberGenerator = null
) -> Array[Dictionary]:
	_ensure_catalog_initialized()
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()

	# 1. Quantidade de afixos permitida para a classe/nível (Tabela 5.3)
	var mod_count: int = 0
	match monster_rank:
		Rank.NORMAL, Rank.BOSS:
			mod_count = 0
		Rank.MAGIC:
			mod_count = 1
		Rank.RARE:
			if monster_level <= 12:
				mod_count = 2
			elif monster_level <= 25:
				mod_count = 2 if rng.randf() < 0.70 else 3
			elif monster_level <= 50:
				mod_count = 2 if rng.randf() < 0.40 else 3
			else:
				mod_count = 3 if rng.randf() < 0.50 else 4
		Rank.HERO:
			mod_count = 1 if rng.randf() < 0.50 else 2

	if mod_count <= 0:
		return []

	# 2. Filtragem de afixos elegíveis
	var candidates: Array[MonsterModifierDefinition] = []
	for m_id in _catalog.keys():
		var m_def: MonsterModifierDefinition = _catalog[m_id]
		if monster_level < m_def.min_monster_level:
			continue
		if not m_def.allowed_ranks.has(monster_rank):
			continue
		if not m_def.allowed_archetypes.has(archetype):
			continue
		if not m_def.allowed_families.is_empty():
			var match_fam := false
			for fam in family_tags:
				if m_def.allowed_families.has(fam):
					match_fam = true
					break
			if not match_fam:
				continue
		candidates.append(m_def)

	# 3. Sorteio com exclusão mútua e limite de categorias (máx 1 controle, máx 1 suporte)
	var chosen: Array[Dictionary] = []
	var blocked_conflicts: Array[String] = []
	var used_categories: Dictionary = {}
	candidates.shuffle()

	for m_def in candidates:
		if chosen.size() >= mod_count:
			break

		# Checagem de conflitos
		var has_conflict := false
		for cg in m_def.conflict_groups:
			if blocked_conflicts.has(cg):
				has_conflict = true
				break
		if has_conflict:
			continue

		# Limite de categorias de perigo simultâneas (Seção 6.3)
		if m_def.category == "control" and used_categories.get("control", 0) >= 1:
			continue
		if m_def.category == "support" and used_categories.get("support", 0) >= 1:
			continue

		# Sorteia o tier conforme o nível (T1 melhor.. T5 pior)
		var rolled_tier: Dictionary = m_def.roll_tier(monster_level, rng)

		chosen.append({
			"id": m_def.id,
			"display_name": m_def.display_name,
			"category": m_def.category,
			"tier": int(rolled_tier.get("tier", 5)),
			"params": rolled_tier.get("params", {}),
			"budget_cost": m_def.budget_cost,
			"color_tint": m_def.color_tint,
		})

		for cg in m_def.conflict_groups:
			blocked_conflicts.append(cg)
		used_categories[m_def.category] = used_categories.get(m_def.category, 0) + 1

	return chosen


## ----------------------------------------------------------------------------
## 7. GERAÇÃO DE TÍTULO LEGÍVEL DO MONSTRO
## ----------------------------------------------------------------------------
static func build_monster_title(
	base_display_name: String,
	monster_rank: int,
	active_modifiers: Array = []
) -> String:
	if active_modifiers.is_empty():
		return base_display_name

	var mod_names: Array[String] = []
	for m in active_modifiers:
		if m is Dictionary and m.has("display_name"):
			mod_names.append(String(m["display_name"]))

	if mod_names.is_empty():
		return base_display_name

	var mods_str: String = ""
	if mod_names.size() == 1:
		mods_str = mod_names[0]
	elif mod_names.size() == 2:
		mods_str = "%s e %s" % [mod_names[0], mod_names[1]]
	else:
		var last: String = String(mod_names.pop_back())
		mods_str = "%s e %s" % [", ".join(mod_names), last]

	return "%s %s" % [base_display_name, mods_str]
