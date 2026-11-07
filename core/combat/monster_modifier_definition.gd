extends RefCounted
class_name MonsterModifierDefinition

## ============================================================================
## DEFINIÇÃO DE AFIXO / MODIFICADOR DE MONSTRO PvE (ARPG)
## ============================================================================
## Conforme Seção 6 da Especificação 05 (Sistema Completo de Dificuldade de Monstros).
## Independente de afixos de equipamentos (não confundir com prefixos/sufixos de loot).
## Convenção oficial do projeto: T1 = mais forte, T5 = mais fraco.

var id: String = ""
var display_name: String = ""
var category: String = "offensive" # "offensive", "defensive", "mobility", "control", "support", "hazard"
var allowed_ranks: Array[int] = [] # LootBalanceConfig.MonsterClass
var allowed_archetypes: Array[String] = [] # "melee", "ranged", "caster", "tank", "support", "summoner"
var allowed_families: Array[String] = [] # "undead", "beast", "humanoid", "demon", "construct"
var min_monster_level: int = 1
var conflict_groups: Array[String] = []
var budget_cost: float = 2.0
var color_tint: Color = Color.WHITE

## Lista de Tiers disponíveis:
## Cada tier: {"tier": int, "min_level": int, "weight": int, "params": Dictionary}
var tiers: Array[Dictionary] = []


func get_eligible_tiers(monster_level: int) -> Array[Dictionary]:
	var eligible: Array[Dictionary] = []
	for t in tiers:
		if monster_level >= int(t.get("min_level", 1)):
			eligible.append(t)
	return eligible


func roll_tier(monster_level: int, rng: RandomNumberGenerator) -> Dictionary:
	var eligible := get_eligible_tiers(monster_level)
	if eligible.is_empty():
		# Fallback para o tier mais brando (T5) se houver
		return tiers[0] if not tiers.is_empty() else {}

	var total_w: int = 0
	for t in eligible:
		total_w += int(t.get("weight", 100))

	var roll_val: int = rng.randi_range(1, maxi(1, total_w))
	var accum: int = 0
	for t in eligible:
		accum += int(t.get("weight", 100))
		if roll_val <= accum:
			return t
	return eligible[0]
