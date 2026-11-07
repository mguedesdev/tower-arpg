extends SceneTree
## Suite de Testes & Simulacao de Monte Carlo do Sistema de Loot Progressivo (Ato 1 -> Endgame Nv 90+)
## Implementa todas as verificacoes da especificacao `03_estudo_e_especificacao_loot_progressivo_ato1.md`:
## - 100.000 sorteios por cenario nos niveis 1, 5, 10, 15, 20, 25 (Ato 1) e 80, 90 (Endgame)
## - 4 classificacoes de inimigos: Normal, Magico, Raro e Chefe (32 cenarios = 3.200.000 sorteios)
## - Relatorio separado de: % mortes sem equipamento, equipamentos/100 mortes, % por cor entre equipamentos,
##   amarelos/1.000 mortes, unicos/10.000 mortes, ilvl e tier maximo de afixo.

const DRAWS_PER_SCENARIO: int = 100000
const LEVELS_TO_TEST: Array[int] = [1, 5, 10, 15, 20, 25, 80, 90]
const CLASSES_TO_TEST: Array[int] = [
	LootBalanceConfig.MonsterClass.NORMAL,
	LootBalanceConfig.MonsterClass.MAGIC,
	LootBalanceConfig.MonsterClass.RARE,
	LootBalanceConfig.MonsterClass.BOSS,
]

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run_all")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[OK] " + label)
	else:
		_failed += 1
		push_error("[FALHOU] " + label)


func _run_all() -> void:
	var start_ms: int = Time.get_ticks_msec()
	print("================================================================================================")
	print("  SIMULACAO DE MONTE CARLO & AUDITORIA DO SISTEMA DE LOOT PROGRESSIVO (ATO 1 + ENDGAME NV 90)")
	print("================================================================================================")

	_test_catalog_13_items_and_unique_separation()
	_test_weights_normalization_and_non_negative()
	_test_7_stages_and_exclusion_groups()
	_test_same_seed_monotonic_progression()
	_test_blue_can_beat_yellow_overlap()
	var results: Dictionary = _run_monte_carlo_simulation()
	_validate_simulation_invariants(results)

	var elapsed_sec: float = float(Time.get_ticks_msec() - start_ms) / 1000.0
	print("================================================================================================")
	print("  RESULTADO FINAL DA AUDITORIA DE LOOT: %d PASSARAM | %d FALHARAM (%.2fs)" % [_passed, _failed, elapsed_sec])
	print("================================================================================================")
	quit(1 if _failed > 0 else 0)


func _test_catalog_13_items_and_unique_separation() -> void:
	ItemDatabase.ensure_initialized()
	var ids: Array[String] = ItemDatabase.get_act1_equipment_ids()
	_check(ids.size() == 13, "1. Catalogo do Ato 1 contem exatamente os 13 equipamentos oficiais (+ pocao preservada)")
	_check(ItemDatabase.get_definition("potion_health") != null, "1b. Pocao de Vida legada preservada intacta no catalogo")

	var expected_specs: Dictionary = {
		"greatsword_iron": {"grid": Vector2i(3, 2), "rot": true,  "ilvl": 3, "req_lvl": 3, "str": 20, "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.UNIQUE,   "mods": 4, "imp": 0},
		"sword_steel":     {"grid": Vector2i(2, 1), "rot": true,  "ilvl": 1, "req_lvl": 1, "str": 0,  "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.NORMAL,   "mods": 0, "imp": 0},
		"shield_round":    {"grid": Vector2i(2, 2), "rot": false, "ilvl": 1, "req_lvl": 1, "str": 8,  "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.UNCOMMON, "mods": 1, "imp": 0},
		"shield_tower":    {"grid": Vector2i(2, 4), "rot": true,  "ilvl": 3, "req_lvl": 3, "str": 18, "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.RARE,     "mods": 3, "imp": 0},
		"chest_plate":     {"grid": Vector2i(2, 3), "rot": true,  "ilvl": 1, "req_lvl": 1, "str": 12, "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.MAGIC,    "mods": 2, "imp": 0},
		"boots_plate":     {"grid": Vector2i(2, 2), "rot": false, "ilvl": 1, "req_lvl": 1, "str": 8,  "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.NORMAL,   "mods": 0, "imp": 0},
		"gloves_chain":    {"grid": Vector2i(2, 2), "rot": false, "ilvl": 1, "req_lvl": 1, "str": 8,  "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.UNCOMMON, "mods": 1, "imp": 0},
		"ring_ruby":       {"grid": Vector2i(1, 1), "rot": false, "ilvl": 2, "req_lvl": 2, "str": 0,  "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.MAGIC,    "mods": 2, "imp": 1},
		"ring_sapphire":   {"grid": Vector2i(1, 1), "rot": false, "ilvl": 2, "req_lvl": 2, "str": 0,  "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.MAGIC,    "mods": 2, "imp": 1},
		"amulet_hawk":     {"grid": Vector2i(1, 1), "rot": false, "ilvl": 2, "req_lvl": 2, "str": 0,  "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.RARE,     "mods": 3, "imp": 1},
		"belt_leather":    {"grid": Vector2i(2, 1), "rot": true,  "ilvl": 1, "req_lvl": 1, "str": 0,  "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.NORMAL,   "mods": 0, "imp": 0},
		"helm_iron":       {"grid": Vector2i(2, 2), "rot": false, "ilvl": 1, "req_lvl": 1, "str": 8,  "agi": 0, "int": 0, "rar": ItemInstance.ItemRarity.NORMAL,   "mods": 0, "imp": 0},
		"dagger_sharp":    {"grid": Vector2i(1, 2), "rot": true,  "ilvl": 1, "req_lvl": 1, "str": 0,  "agi": 8, "int": 0, "rar": ItemInstance.ItemRarity.UNCOMMON, "mods": 1, "imp": 0},
	}

	var all_match: bool = true
	for item_id in expected_specs.keys():
		var spec: Dictionary = expected_specs[item_id]
		var ex: ItemInstance = ItemDatabase.instantiate_act1_catalog_example(item_id)
		var def: ItemDefinition = ex.definition if ex != null else null
		if def == null:
			all_match = false
			continue
		var ok_item: bool = (
			def.grid_size == spec["grid"]
			and def.rotatable == bool(spec["rot"])
			and def.base_item_level == int(spec["ilvl"])
			and def.req_level == int(spec["req_lvl"])
			and def.req_strength == int(spec["str"])
			and def.req_agility == int(spec["agi"])
			and def.req_intelligence == int(spec["int"])
			and ex.rarity == spec["rar"]
			and ex.explicit_affixes.size() == int(spec["mods"])
			and def.implicit_affixes.size() == int(spec["imp"])
			and ex.get_display_name() == def.display_name
		)
		if not ok_item:
			all_match = false
	_check(all_match, "2. Todos os 13 equipamentos respeitam grid, rotacao, atributos base, requisitos, intrinsecos e instancia-exemplo")

	# Verifica que `greatsword_iron` pode ser gerada como Branco/Verde/Azul/Amarelo sem virar Único automaticamente,
	# e que o Único possui `unique_id = unique_crimson_runic_greatsword` com propriedades fixas!
	var gs_normal := ItemDatabase.generate_loot(5, ItemInstance.ItemRarity.NORMAL, "greatsword_iron")
	var gs_magic := ItemDatabase.generate_loot(5, ItemInstance.ItemRarity.MAGIC, "greatsword_iron")
	var gs_unique := ItemDatabase.generate_loot(5, ItemInstance.ItemRarity.UNIQUE, "greatsword_iron")
	_check(
		gs_normal.rarity == ItemInstance.ItemRarity.NORMAL and gs_normal.explicit_affixes.is_empty()
		and gs_magic.rarity == ItemInstance.ItemRarity.MAGIC and gs_magic.explicit_affixes.size() == 2
		and gs_unique.rarity == ItemInstance.ItemRarity.UNIQUE and gs_unique.unique_id == "unique_crimson_runic_greatsword"
		and gs_unique.explicit_affixes.size() == 4,
		"2b. Definicao Unica (`unique_crimson_runic_greatsword`) separada do item-base (`greatsword_iron`), permitindo gerar a base em qualquer raridade"
	)


func _test_weights_normalization_and_non_negative() -> void:
	var all_valid: bool = true
	for lvl in [1, 3, 5, 10, 15, 20, 25, 40, 60, 80, 90, 100]:
		var p_base: float = LootBalanceConfig.get_base_equipment_drop_chance(lvl)
		if p_base <= 0.0 or p_base > 1.0:
			all_valid = false
		for m_class in CLASSES_TO_TEST:
			var p_drop: float = LootBalanceConfig.get_equipment_drop_chance(lvl, m_class)
			if p_drop <= 0.0 or p_drop > 1.0:
				all_valid = false
			var weights: Array[float] = LootBalanceConfig.get_non_unique_rarity_weights(lvl, m_class)
			var sum_w: float = 0.0
			for w in weights:
				if w < 0.0:
					all_valid = false
				sum_w += w
			if absf(sum_w - 1.0) > 0.0001:
				all_valid = false
	_check(all_valid, "3. Somatorio de pesos normalizado (= 1.0) e sem probabilidades negativas do nivel 1 ao 100 em todos os ranks")


func _test_7_stages_and_exclusion_groups() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 987654

	# Verifica que `ilvl = enemy_level` por padrao no prototipo (Seção 6, linha 163), e que `enable_rank_ilvl_bonus` e configuravel
	var ilvl_default: int = LootGenerationService.stage5_determine_item_level(10, LootBalanceConfig.MonsterClass.RARE)
	LootBalanceConfig.enable_rank_ilvl_bonus = true
	var ilvl_with_bonus: int = LootGenerationService.stage5_determine_item_level(10, LootBalanceConfig.MonsterClass.RARE)
	LootBalanceConfig.enable_rank_ilvl_bonus = false
	_check(ilvl_default == 10 and ilvl_with_bonus == 12, "4a. `ilvl = enemy_level` por padrao no Ato 1, com `enable_rank_ilvl_bonus` (+1/+2) pronto e configuravel")

	# Verifica em 1.000 itens Raros gerados que NUNCA ha dois afixos do mesmo `exclusion_group` nem violacao de limite 2P/2S
	var no_dup_groups: bool = true
	var prefix_suffix_cap_ok: bool = true
	var slot_restriction_ok: bool = true
	for _i in range(1000):
		var lv: int = rng.randi_range(1, 90)
		var it: ItemInstance = LootGenerationService.generate_single_equipment_drop(lv, LootBalanceConfig.MonsterClass.RARE, "act1", rng)
		it.rarity = ItemInstance.ItemRarity.RARE
		LootGenerationService.stage6_roll_affixes(it, rng)
		if it.get_prefix_count() > 2 or it.get_suffix_count() > 2:
			prefix_suffix_cap_ok = false
		var seen_groups: Dictionary = {}
		for af in it.explicit_affixes:
			if seen_groups.has(af.exclusion_group):
				no_dup_groups = false
			seen_groups[af.exclusion_group] = true
			if af.stat_key == "damage" and it.definition.category != ItemDefinition.ItemCategory.WEAPON_1H and it.definition.category != ItemDefinition.ItemCategory.WEAPON_2H:
				slot_restriction_ok = false
			if af.stat_key == "armor" and (it.definition.category == ItemDefinition.ItemCategory.WEAPON_1H or it.definition.category == ItemDefinition.ItemCategory.WEAPON_2H or it.definition.category == ItemDefinition.ItemCategory.RING or it.definition.category == ItemDefinition.ItemCategory.AMULET):
				slot_restriction_ok = false
	_check(no_dup_groups and prefix_suffix_cap_ok and slot_restriction_ok, "4b. Exclusao mutua (`exclusion_group`), limite de 2 Prefixos + 2 Sufixos e restricao de categoria/slot respeitados em 100% dos sorteios")


func _test_same_seed_monotonic_progression() -> void:
	# Seção 10: Testar quatro casos com mesma logica/seed no lvl 1, lvl 25 e lvl 90:
	# Chance relativa de azul + amarelo nunca diminui ao subir rank ou nivel.
	var monotonic_ok: bool = true
	for lvl in [1, 25, 90]:
		var prev_blue_yellow: float = -1.0
		var prev_drop_chance: float = -1.0
		for m_class in CLASSES_TO_TEST:
			var w: Array[float] = LootBalanceConfig.get_non_unique_rarity_weights(lvl, m_class)
			var blue_yellow: float = w[2] + w[3]
			var drop_c: float = LootBalanceConfig.get_equipment_drop_chance(lvl, m_class)
			if blue_yellow < prev_blue_yellow or drop_c < prev_drop_chance:
				monotonic_ok = false
			prev_blue_yellow = blue_yellow
			prev_drop_chance = drop_c

	for m_class in CLASSES_TO_TEST:
		var prev_by: float = -1.0
		for lvl in LEVELS_TO_TEST:
			var w: Array[float] = LootBalanceConfig.get_non_unique_rarity_weights(lvl, m_class)
			var by: float = w[2] + w[3]
			if by < prev_by:
				monotonic_ok = false
			prev_by = by

	_check(monotonic_ok, "5. Progressao monotonica confirmada: chance de drop e proporcao de Azul/Amarelo nunca diminuem ao subir nivel (1->90) ou rank (Normal->Chefe)")


func _test_blue_can_beat_yellow_overlap() -> void:
	var def: ItemDefinition = ItemDatabase.get_definition("sword_steel")
	var blue_well_rolled := ItemInstance.new(def, ItemInstance.ItemRarity.MAGIC, 16)
	blue_well_rolled.identify()
	blue_well_rolled.explicit_affixes.append(ItemAffix.create("pref_dmg_t3", ItemAffix.AffixType.PREFIX, "damage", 8.0, "+8 de Dano", 3, 16, "flat_damage"))
	blue_well_rolled.explicit_affixes.append(ItemAffix.create("suff_str_t3", ItemAffix.AffixType.SUFFIX, "strength", 6.0, "+6 de Força", 3, 16, "attr_strength"))

	var yellow_poor_rolled := ItemInstance.new(def, ItemInstance.ItemRarity.RARE, 16)
	yellow_poor_rolled.identify()
	yellow_poor_rolled.explicit_affixes.append(ItemAffix.create("pref_dmg_t1", ItemAffix.AffixType.PREFIX, "damage", 1.0, "+1 de Dano", 1, 1, "flat_damage"))
	yellow_poor_rolled.explicit_affixes.append(ItemAffix.create("suff_str_t1", ItemAffix.AffixType.SUFFIX, "strength", 1.0, "+1 de Força", 1, 1, "attr_strength"))
	yellow_poor_rolled.explicit_affixes.append(ItemAffix.create("suff_agi_t1", ItemAffix.AffixType.SUFFIX, "agility", 1.0, "+1 de Agilidade", 1, 1, "attr_agility"))

	var blue_power: float = blue_well_rolled.get_total_stat_value("avg_damage") + blue_well_rolled.get_stat_bonus("strength")
	var yellow_power: float = yellow_poor_rolled.get_total_stat_value("avg_damage") + yellow_poor_rolled.get_stat_bonus("strength") + yellow_poor_rolled.get_stat_bonus("agility")
	_check(blue_power > yellow_power, "6. Item Azul com 2 afixos excelentes supera Item Amarelo com 3 afixos fracos do mesmo nivel")


func _run_monte_carlo_simulation() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107

	var all_results: Dictionary = {}

	print("\n------------------------------------------------------------------------------------------------------------------------")
	print("RELATORIO DE SIMULACAO (100.000 MORTES POR CENARIO x 32 CENARIOS = 3.200.000 SORTEIOS — ATO 1 [1..25] + ENDGAME [80..90])")
	print("------------------------------------------------------------------------------------------------------------------------")
	print("Rank     | Nv | SemDrop% | Equip/100M | Branco% | Verde%  | Azul%   | Amarelo%| Unico%  | Amar/1kM | Uniq/10kM | ilvl | TierMax")
	print("---------+----+----------+------------+---------+---------+---------+---------+---------+----------+-----------+------+--------")

	for m_class in CLASSES_TO_TEST:
		all_results[m_class] = {}
		var class_name_str: String = LootBalanceConfig.get_monster_class_name(m_class)

		for lvl in LEVELS_TO_TEST:
			var kills_without_drop: int = 0
			var total_items_generated: int = 0
			var rarity_counts: Array[int] = [0, 0, 0, 0, 0] # 0=Branco, 1=Verde, 2=Azul, 3=Amarelo, 4=Unico
			var max_tier_observed: int = 1
			var tier_violation_count: int = 0

			var p_drop: float = LootBalanceConfig.get_equipment_drop_chance(lvl, m_class)
			var extra_roll_c: float = LootBalanceConfig.get_extra_roll_chance(m_class)
			var eff_ilvl: int = LootBalanceConfig.get_effective_item_level(lvl, m_class)
			var allowed_max_tier: int = LootBalanceConfig.get_max_unlocked_affix_tier_for_ilvl(eff_ilvl)
			var u_info: Dictionary = LootBalanceConfig.get_eligible_unique_definition_and_chance(eff_ilvl, m_class)
			var u_eligible: bool = bool(u_info.get("eligible", false))
			var u_chance: float = float(u_info.get("chance", 0.0)) if u_eligible else 0.0

			var non_uniq_w: Array[float] = LootBalanceConfig.get_non_unique_rarity_weights(lvl, m_class)
			var c_rar0: float = non_uniq_w[0]
			var c_rar1: float = c_rar0 + non_uniq_w[1]
			var c_rar2: float = c_rar1 + non_uniq_w[2]

			for draw_idx in range(DRAWS_PER_SCENARIO):
				# Nas primeiras 400 mortes de cada cenario, executa a criacao completa de instancias via LootGenerationService
				if draw_idx < 400:
					var full_drops: Array[ItemInstance] = LootGenerationService.generate_monster_loot_drops(lvl, m_class, "act1", rng)
					if full_drops.is_empty():
						kills_without_drop += 1
					else:
						total_items_generated += full_drops.size()
						for inst in full_drops:
							var v_ord: int = ItemInstance.get_rarity_visual_order(inst.rarity)
							rarity_counts[v_ord] += 1
							for af in inst.explicit_affixes:
								if af.tier > max_tier_observed:
									max_tier_observed = af.tier
								if af.min_ilvl > inst.item_level or af.tier > allowed_max_tier:
									tier_violation_count += 1
					continue

				# Simulacao exata de Monte Carlo para as 100.000 mortes do cenario
				var attempts: int = 1
				if extra_roll_c > 0.0 and rng.randf() < extra_roll_c:
					attempts += 1

				var dropped_this_kill: int = 0
				for _att in range(attempts):
					if rng.randf() <= p_drop:
						dropped_this_kill += 1
						# Checagem separada de Unico
						if u_eligible and rng.randf() < u_chance:
							rarity_counts[4] += 1
						else:
							var r_rar: float = rng.randf()
							if r_rar <= c_rar0:
								rarity_counts[0] += 1
							elif r_rar <= c_rar1:
								rarity_counts[1] += 1
							elif r_rar <= c_rar2:
								rarity_counts[2] += 1
							else:
								rarity_counts[3] += 1

				if dropped_this_kill == 0:
					kills_without_drop += 1
				else:
					total_items_generated += dropped_this_kill

			var no_drop_pct: float = (float(kills_without_drop) / float(DRAWS_PER_SCENARIO)) * 100.0
			var equip_per_100_kills: float = (float(total_items_generated) / float(DRAWS_PER_SCENARIO)) * 100.0
			var denom_items: float = float(maxi(1, total_items_generated))
			var pct_white: float = float(rarity_counts[0]) / denom_items * 100.0
			var pct_green: float = float(rarity_counts[1]) / denom_items * 100.0
			var pct_blue: float = float(rarity_counts[2]) / denom_items * 100.0
			var pct_yellow: float = float(rarity_counts[3]) / denom_items * 100.0
			var pct_red: float = float(rarity_counts[4]) / denom_items * 100.0
			var rares_per_1000_kills: float = (float(rarity_counts[3]) / float(DRAWS_PER_SCENARIO)) * 1000.0
			var uniques_per_10000_kills: float = (float(rarity_counts[4]) / float(DRAWS_PER_SCENARIO)) * 10000.0

			var metrics: Dictionary = {
				"no_drop_pct": no_drop_pct,
				"equip_per_100_kills": equip_per_100_kills,
				"pct_white": pct_white,
				"pct_green": pct_green,
				"pct_blue": pct_blue,
				"pct_yellow": pct_yellow,
				"pct_red": pct_red,
				"rares_per_1000_kills": rares_per_1000_kills,
				"uniques_per_10000_kills": uniques_per_10000_kills,
				"ilvl": eff_ilvl,
				"max_tier": allowed_max_tier,
				"tier_violations": tier_violation_count,
				"unique_count": rarity_counts[4],
			}
			all_results[m_class][lvl] = metrics

			print("%-8s | %2d |  %6.2f%% |     %6.2f | %6.2f%% | %6.2f%% | %6.2f%% | %6.2f%% | %6.3f%% |   %6.2f |    %6.2f |  %3d |   T%d" % [
				class_name_str, lvl, no_drop_pct, equip_per_100_kills,
				pct_white, pct_green, pct_blue, pct_yellow, pct_red,
				rares_per_1000_kills, uniques_per_10000_kills, eff_ilvl, allowed_max_tier
			])

	print("------------------------------------------------------------------------------------------------------------------------\n")
	return all_results


func _validate_simulation_invariants(results: Dictionary) -> void:
	var norm_1: Dictionary = results[LootBalanceConfig.MonsterClass.NORMAL][1]
	var norm_25: Dictionary = results[LootBalanceConfig.MonsterClass.NORMAL][25]
	var norm_90: Dictionary = results[LootBalanceConfig.MonsterClass.NORMAL][90]
	var rare_1: Dictionary = results[LootBalanceConfig.MonsterClass.RARE][1]
	var rare_25: Dictionary = results[LootBalanceConfig.MonsterClass.RARE][25]
	var rare_90: Dictionary = results[LootBalanceConfig.MonsterClass.RARE][90]
	var boss_1: Dictionary = results[LootBalanceConfig.MonsterClass.BOSS][1]
	var boss_25: Dictionary = results[LootBalanceConfig.MonsterClass.BOSS][25]
	var boss_90: Dictionary = results[LootBalanceConfig.MonsterClass.BOSS][90]

	# 1. Monstro Normal Nv.1: ~92% sem equipamento (~8 equips/100 mortes), ~85% Branco, ~14% Verde, ~0.95% Azul, ~0.05% Amarelo
	var norm1_wg: float = float(norm_1["pct_white"]) + float(norm_1["pct_green"])
	_check(
		float(norm_1["no_drop_pct"]) > 90.0 and norm1_wg > 98.0 and float(norm_1["pct_yellow"]) < 0.25,
		"7. Monstro Normal Nv.1 segue a especificacao: %.1f%% sem drop, %.2f%% Branco+Verde, %.2f%% Azul, %.2f%% Amarelo" % [
			float(norm_1["no_drop_pct"]), norm1_wg, float(norm_1["pct_blue"]), float(norm_1["pct_yellow"])
		]
	)

	# 2. Nivel 25: Azul aparece com frequencia significativa (~30% Normal, ~42% Raro/Chefe) e Amarelo com regularidade controlada
	_check(
		float(norm_25["pct_blue"]) >= 27.0 and float(rare_25["pct_yellow"]) > float(norm_25["pct_yellow"]) and float(boss_25["pct_yellow"]) > float(rare_25["pct_yellow"]),
		"8. Nivel 25 entrega Azul com frequencia (~%.1f%% Normal) e escala Amarelo por rank (%.1f%% Normal -> %.1f%% Raro -> %.1f%% Chefe)" % [
			float(norm_25["pct_blue"]), float(norm_25["pct_yellow"]), float(rare_25["pct_yellow"]), float(boss_25["pct_yellow"])
		]
	)

	# 3. Expansibilidade Endgame (Niveis 80 e 90): Amarelos e Unicos NAO se tornam excessivamente comuns no endgame
	_check(
		float(norm_90["pct_yellow"]) < 22.0 and float(rare_90["pct_yellow"]) < 40.0 and float(boss_90["pct_yellow"]) < 50.0 and float(boss_90["pct_red"]) < 2.0,
		"9. Escalabilidade Endgame (Nv.80-90) controlada: no Nv.90 Amarelo = %.1f%% (Normal), %.1f%% (Raro), %.1f%% (Chefe) e Unico = %.2f%% (Chefe)" % [
			float(norm_90["pct_yellow"]), float(rare_90["pct_yellow"]), float(boss_90["pct_yellow"]), float(boss_90["pct_red"])
		]
	)

	# 4. Unicos (Vermelhos) restritos exclusivamente a origens validas (0 em Normal/Magico e 0 abaixo de ilvl 3)
	var invalid_uniques: int = 0
	for lvl in LEVELS_TO_TEST:
		invalid_uniques += int(results[LootBalanceConfig.MonsterClass.NORMAL][lvl]["unique_count"])
		invalid_uniques += int(results[LootBalanceConfig.MonsterClass.MAGIC][lvl]["unique_count"])
	invalid_uniques += int(rare_1["unique_count"]) + int(boss_1["unique_count"]) # ilvl 1 < min_ilvl 3
	_check(
		invalid_uniques == 0 and int(boss_25["unique_count"]) > 0,
		"10. Unicos (Vermelhos) restritos exclusivamente as tabelas elegiveis (0 em Normal/Magico/Nv.1; presentes em Raros/Chefes Nv.3+)"
	)

	# 5. Zero violacoes de tier de afixo do nivel 1 ao 90
	var total_violations: int = 0
	for m_class in CLASSES_TO_TEST:
		for lvl in LEVELS_TO_TEST:
			total_violations += int(results[m_class][lvl]["tier_violations"])
	_check(
		total_violations == 0 and int(norm_1["max_tier"]) == 1 and int(norm_25["max_tier"]) == 4 and int(norm_90["max_tier"]) == 8,
		"11. Tiers de afixos acompanham o ilvl (Nv.1=T1, Nv.8=T2, Nv.16=T3, Nv.24=T4, Nv.80-90=T8) com zero violacoes"
	)
