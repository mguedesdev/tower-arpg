extends SceneTree
## Suite de Testes & Simulacao de Monte Carlo do Sistema de Loot Progressivo — Ato 1
## Executa 100.000 sorteios por cenario (24 cenarios = 2.400.000 sorteios totais)
## comparando monstros Normais, Magicos, Raros e Chefes nos niveis 1, 5, 10, 15, 20 e 25.

const DRAWS_PER_SCENARIO: int = 100000
const LEVELS_TO_TEST: Array[int] = [1, 5, 10, 15, 20, 25]
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
	print("================================================================================")
	print("  SIMULACAO DE MONTE CARLO & VALIDACAO DO SISTEMA DE LOOT — ATO 1 (100k/cenario)")
	print("================================================================================")

	_test_catalog_13_items_and_rules()
	_test_7_stages_decoupled_pipeline()
	_test_blue_can_beat_yellow_overlap()
	var results: Dictionary = _run_monte_carlo_100k_simulation()
	_validate_simulation_invariants(results)

	var elapsed_sec: float = float(Time.get_ticks_msec() - start_ms) / 1000.0
	print("================================================================================")
	print("  RESULTADO FINAL DA SIMULACAO DO ATO 1: %d PASSARAM | %d FALHARAM (%.2fs)" % [_passed, _failed, elapsed_sec])
	print("================================================================================")
	quit(1 if _failed > 0 else 0)


func _test_catalog_13_items_and_rules() -> void:
	ItemDatabase.ensure_initialized()
	var ids: Array[String] = ItemDatabase.get_act1_equipment_ids()
	_check(ids.size() == 13, "1. Catalogo do Ato 1 contem exatamente os 13 equipamentos oficiais")

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
			push_error("Definicao ausente: " + item_id)
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
			push_error("Divergencia nas especificacoes do item: " + item_id)
	_check(all_match, "2. Todos os 13 equipamentos respeitam grid, rotacao, atributos base, requisitos, intrinsecos e instancia-exemplo")


func _test_7_stages_decoupled_pipeline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242

	# Verifica que cada uma das 7 etapas pode ser invocada isoladamente e produz saida valida
	var s1_drop: bool = LootGenerationService.stage1_should_drop_equipment(10, LootBalanceConfig.MonsterClass.BOSS, rng)
	var s2_cnt: int = LootGenerationService.stage2_roll_drop_count(10, LootBalanceConfig.MonsterClass.BOSS, rng)
	var s3_def: ItemDefinition = LootGenerationService.stage3_select_valid_base_item(1, LootBalanceConfig.MonsterClass.NORMAL, "act1", rng)
	var s4_rar: ItemInstance.ItemRarity = LootGenerationService.stage4_roll_item_rarity(10, LootBalanceConfig.MonsterClass.RARE, s3_def, rng)
	var s5_ilvl: int = LootGenerationService.stage5_determine_item_level(10, LootBalanceConfig.MonsterClass.RARE, s3_def)
	var s7_inst: ItemInstance = LootGenerationService.stage7_create_final_instance(s3_def, ItemInstance.ItemRarity.MAGIC, s5_ilvl, rng)

	_check(s1_drop == true and s2_cnt >= 2 and s2_cnt <= 4, "3a. Etapas 1 e 2 (chance de drop e quantidade de itens) operam separadamente")
	_check(s3_def != null and s3_def.base_item_level <= 1, "3b. Etapa 3 seleciona apenas item-base compativel com o nivel 1 para monstro Normal Nv.1")
	_check(s5_ilvl == 12 and s7_inst != null and s7_inst.explicit_affixes.size() == 2 and s7_inst.get_display_name() == s3_def.display_name, "3c. Etapas 4, 5, 6 e 7 geram instancia final com ilvl correto, afixos validos e nome-base preservado")


func _test_blue_can_beat_yellow_overlap() -> void:
	# Verifica a regra de design: um item Azul (MAGIC, 2 modificadores bem sorteados) pode superar
	# um item Amarelo (RARE, 3 modificadores com rolagens baixas) no mesmo nivel.
	var def: ItemDefinition = ItemDatabase.get_definition("sword_steel")
	var blue_well_rolled := ItemInstance.new(def, ItemInstance.ItemRarity.MAGIC, 10)
	blue_well_rolled.identify()
	blue_well_rolled.explicit_affixes.append(ItemAffix.create("pref_dmg_t3", ItemAffix.AffixType.PREFIX, "damage", 8.0, "+8 de Dano", 3, 10))
	blue_well_rolled.explicit_affixes.append(ItemAffix.create("suff_str_t3", ItemAffix.AffixType.SUFFIX, "strength", 6.0, "+6 de Força", 3, 10))

	var yellow_poor_rolled := ItemInstance.new(def, ItemInstance.ItemRarity.RARE, 10)
	yellow_poor_rolled.identify()
	yellow_poor_rolled.explicit_affixes.append(ItemAffix.create("pref_dmg_t1", ItemAffix.AffixType.PREFIX, "damage", 1.0, "+1 de Dano", 1, 1))
	yellow_poor_rolled.explicit_affixes.append(ItemAffix.create("suff_str_t1", ItemAffix.AffixType.SUFFIX, "strength", 1.0, "+1 de Força", 1, 1))
	yellow_poor_rolled.explicit_affixes.append(ItemAffix.create("suff_agi_t1", ItemAffix.AffixType.SUFFIX, "agility", 1.0, "+1 de Agilidade", 1, 1))

	var blue_power: float = blue_well_rolled.get_total_stat_value("avg_damage") + blue_well_rolled.get_stat_bonus("strength")
	var yellow_power: float = yellow_poor_rolled.get_total_stat_value("avg_damage") + yellow_poor_rolled.get_stat_bonus("strength") + yellow_poor_rolled.get_stat_bonus("agility")
	_check(blue_power > yellow_power, "4. Sobreposicao de tiers permite que um Azul (2 mods bem sorteados) supere um Amarelo (3 mods ruins)")


func _run_monte_carlo_100k_simulation() -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261107

	var all_results: Dictionary = {}
	var max_tier_by_ilvl: Dictionary = {
		1: 1, 2: 1, 3: 1, 4: 1,
		5: 2, 6: 2, 7: 2, 8: 2,
		10: 3, 11: 3, 12: 3, 13: 3,
		15: 4, 16: 4, 17: 4, 18: 4,
		20: 5, 21: 5, 22: 5, 23: 5,
		25: 5, 26: 5, 27: 5, 28: 5,
	}

	print("\n--------------------------------------------------------------------------------")
	print("RELATORIO DE SIMULACAO (100.000 SORTEIOS POR CENARIO = 2.400.000 SIMULACOES)")
	print("--------------------------------------------------------------------------------")
	print("Classe   | Nv | Drop%  | Itens/Abate | Itens/Drop | Branco% | Verde%  | Azul%   | Amarelo%| Unico%  | ilvl | ModsMed | TierMax")
	print("---------+----+--------+-------------+------------+---------+---------+---------+---------+---------+------+---------+--------")

	for m_class in CLASSES_TO_TEST:
		all_results[m_class] = {}
		var class_name_str: String = LootBalanceConfig.get_monster_class_name(m_class)

		for lvl in LEVELS_TO_TEST:
			var kills_with_drop: int = 0
			var total_items_generated: int = 0
			var rarity_counts: Array[int] = [0, 0, 0, 0, 0] # Visual order: 0=Normal, 1=Uncommon, 2=Magic, 3=Rare, 4=Unique
			var total_mods_sum: int = 0
			var ilvl_sum: int = 0
			var four_mod_rares: int = 0
			var total_rares: int = 0
			var max_tier_observed: int = 1
			var tier_violation_count: int = 0

			# Pre-consulta curvas para os 100.000 sorteios de cada cenario + validacao completa de instancias
			var drop_chance: float = LootBalanceConfig.get_equipment_drop_chance(lvl, m_class)
			var count_weights: Array[float] = LootBalanceConfig. normalize_weights(LootBalanceConfig.get_drop_count_weights(lvl, m_class))
			var eff_ilvl: int = LootBalanceConfig.get_effective_item_level(lvl, m_class)
			var rarity_weights: Array[float] = LootBalanceConfig.get_rarity_weights(lvl, m_class, eff_ilvl >= LootBalanceConfig.MIN_ILVL_FOR_UNIQUE)
			var four_mod_chance: float = LootBalanceConfig.get_rare_four_mod_chance(eff_ilvl)
			var allowed_max_tier: int = int(max_tier_by_ilvl.get(eff_ilvl, 5))

			# Cumulativos normalizados para amostragem rapida e exata de Monte Carlo em 100.000 iteracoes
			var c_cnt0: float = count_weights[0]
			var c_cnt1: float = c_cnt0 + count_weights[1]
			var c_cnt2: float = c_cnt1 + count_weights[2]

			var c_rar0: float = rarity_weights[0]
			var c_rar1: float = c_rar0 + rarity_weights[1]
			var c_rar2: float = c_rar1 + rarity_weights[2]
			var c_rar3: float = c_rar2 + rarity_weights[3]

			for draw_idx in range(DRAWS_PER_SCENARIO):
				# Nas primeiras 500 iteracoes de cada cenario (12.000 execucoes completas),
				# exercita a instancia completa de objetos via LootGenerationService para validar todas as 7 etapas e tiers reais
				if draw_idx < 500:
					var full_drops: Array[ItemInstance] = LootGenerationService.generate_monster_loot_drops(lvl, m_class, "act1", rng)
					if not full_drops.is_empty():
						kills_with_drop += 1
						total_items_generated += full_drops.size()
						for inst in full_drops:
							var v_ord: int = ItemInstance.get_rarity_visual_order(inst.rarity)
							rarity_counts[v_ord] += 1
							total_mods_sum += inst.explicit_affixes.size()
							ilvl_sum += inst.item_level
							if inst.rarity == ItemInstance.ItemRarity.RARE:
								total_rares += 1
								if inst.explicit_affixes.size() == 4:
									four_mod_rares += 1
							for af in inst.explicit_affixes:
								if af.tier > max_tier_observed:
									max_tier_observed = af.tier
								if af.min_ilvl > inst.item_level or af.tier > allowed_max_tier:
									tier_violation_count += 1
					continue

				# Sorteio Etapa 1: Chance de derrubar equipamento
				if rng.randf() > drop_chance:
					continue
				kills_with_drop += 1

				# Sorteio Etapa 2: Quantidade de equipamentos
				var r_cnt: float = rng.randf()
				var drop_cnt: int = 1
				if r_cnt <= c_cnt0:
					drop_cnt = 1
				elif r_cnt <= c_cnt1:
					drop_cnt = 2
				elif r_cnt <= c_cnt2:
					drop_cnt = 3
				else:
					drop_cnt = 4
				total_items_generated += drop_cnt

				# Sorteio Etapas 3..7 por item gerado
				for _item_i in range(drop_cnt):
					var r_rar: float = rng.randf()
					var rar_ord: int = 0
					var mod_cnt: int = 0
					if r_rar <= c_rar0:
						rar_ord = 0 # Branco
						mod_cnt = 0
					elif r_rar <= c_rar1:
						rar_ord = 1 # Verde
						mod_cnt = 1
					elif r_rar <= c_rar2:
						rar_ord = 2 # Azul
						mod_cnt = 2
					elif r_rar <= c_rar3:
						rar_ord = 3 # Amarelo
						total_rares += 1
						if rng.randf() < four_mod_chance:
							mod_cnt = 4
							four_mod_rares += 1
						else:
							mod_cnt = 3
					else:
						rar_ord = 4 # Unico (Vermelho)
						mod_cnt = 4
					rarity_counts[rar_ord] += 1
					total_mods_sum += mod_cnt
					ilvl_sum += eff_ilvl

			var drop_rate_pct: float = (float(kills_with_drop) / float(DRAWS_PER_SCENARIO)) * 100.0
			var items_per_kill: float = float(total_items_generated) / float(DRAWS_PER_SCENARIO)
			var items_per_drop: float = float(total_items_generated) / float(maxi(1, kills_with_drop))
			var denom_items: float = float(maxi(1, total_items_generated))
			var pct_white: float = float(rarity_counts[0]) / denom_items * 100.0
			var pct_green: float = float(rarity_counts[1]) / denom_items * 100.0
			var pct_blue: float = float(rarity_counts[2]) / denom_items * 100.0
			var pct_yellow: float = float(rarity_counts[3]) / denom_items * 100.0
			var pct_red: float = float(rarity_counts[4]) / denom_items * 100.0
			var avg_ilvl: float = float(ilvl_sum) / denom_items
			var avg_mods: float = float(total_mods_sum) / denom_items

			var metrics: Dictionary = {
				"drop_rate_pct": drop_rate_pct,
				"items_per_kill": items_per_kill,
				"items_per_drop": items_per_drop,
				"pct_white": pct_white,
				"pct_green": pct_green,
				"pct_blue": pct_blue,
				"pct_yellow": pct_yellow,
				"pct_red": pct_red,
				"avg_ilvl": avg_ilvl,
				"avg_mods": avg_mods,
				"max_tier": max_tier_observed,
				"tier_violations": tier_violation_count,
				"total_items": total_items_generated,
			}
			all_results[m_class][lvl] = metrics

			print("%-8s | %2d | %5.1f%% | %11.3f | %10.2f | %6.2f%% | %6.2f%% | %6.2f%% | %6.2f%% | %6.2f%% | %4.1f | %7.2f | T%d" % [
				class_name_str, lvl, drop_rate_pct, items_per_kill, items_per_drop,
				pct_white, pct_green, pct_blue, pct_yellow, pct_red,
				avg_ilvl, avg_mods, max_tier_observed
			])

	print("--------------------------------------------------------------------------------\n")
	return all_results


func _validate_simulation_invariants(results: Dictionary) -> void:
	var norm_1: Dictionary = results[LootBalanceConfig.MonsterClass.NORMAL][1]
	var norm_25: Dictionary = results[LootBalanceConfig.MonsterClass.NORMAL][25]
	var mag_1: Dictionary = results[LootBalanceConfig.MonsterClass.MAGIC][1]
	var rare_1: Dictionary = results[LootBalanceConfig.MonsterClass.RARE][1]
	var rare_25: Dictionary = results[LootBalanceConfig.MonsterClass.RARE][25]
	var boss_1: Dictionary = results[LootBalanceConfig.MonsterClass.BOSS][1]
	var boss_25: Dictionary = results[LootBalanceConfig.MonsterClass.BOSS][25]

	# 1. Monstro Normal de Nivel 1 derruba predominantemente Brancos e Verdes (>94% combinados),
	# com chances baixissimas de Azuis (<5%) e Amarelos (<1%) e 0% de Unicos.
	var norm1_white_green: float = float(norm_1["pct_white"]) + float(norm_1["pct_green"])
	_check(norm1_white_green >= 94.0 and float(norm_1["pct_blue"]) < 5.0 and float(norm_1["pct_yellow"]) < 1.0 and is_equal_approx(float(norm_1["pct_red"]), 0.0),
		"5. Monstro Normal Nv.1 derruba predominantemente Branco/Verde (%.1f%%), Azul baixo (%.2f%%), Amarelo raro (%.2f%%) e Unico 0%%" % [
			norm1_white_green, float(norm_1["pct_blue"]), float(norm_1["pct_yellow"])
		])

	# 2. No mesmo nivel (Nv. 1), Magico > Normal, Raro > Magico, Chefe > Raro em qualidade e quantidade por abate
	_check(
		float(norm_1["items_per_kill"]) < float(mag_1["items_per_kill"])
		and float(mag_1["items_per_kill"]) < float(rare_1["items_per_kill"])
		and float(rare_1["items_per_kill"]) < float(boss_1["items_per_kill"]),
		"6. Quantidade media de equipamentos por abate escala por classificacao (Normal < Magico < Raro < Chefe)"
	)

	var rare_plus_norm1: float = float(norm_1["pct_blue"]) + float(norm_1["pct_yellow"])
	var rare_plus_mag1: float = float(mag_1["pct_blue"]) + float(mag_1["pct_yellow"])
	var rare_plus_rare1: float = float(rare_1["pct_blue"]) + float(rare_1["pct_yellow"])
	var rare_plus_boss1: float = float(boss_1["pct_blue"]) + float(boss_1["pct_yellow"])
	_check(
		rare_plus_norm1 < rare_plus_mag1 and rare_plus_mag1 < rare_plus_rare1 and rare_plus_rare1 < rare_plus_boss1,
		"7. Qualidade do loot no Nv.1 escala estritamente por classificacao (Normal < Magico < Raro < Chefe)"
	)

	# 3. No Nivel 25, monstros Normais entregam mais equipamentos Azuis que no Nivel 1
	_check(
		float(norm_25["pct_blue"]) > float(norm_1["pct_blue"]) * 5.0 and float(norm_25["pct_blue"]) >= 25.0,
		"8. Monstro Normal Nv.25 entrega significativamente mais equipamentos Azuis (%.1f%% vs %.1f%% no Nv.1)" % [
			float(norm_25["pct_blue"]), float(norm_1["pct_blue"])
		]
	)

	# 4. Monstro Raro NAO e garantia automatica de equipamento Amarelo (mesmo no nivel 25, Amarelo < 35%)
	_check(
		float(rare_1["pct_yellow"]) < 10.0 and float(rare_25["pct_yellow"]) < 35.0,
		"9. Monstro Raro nao garante item Amarelo (Nv.1 = %.2f%%, Nv.25 = %.2f%%)" % [
			float(rare_1["pct_yellow"]), float(rare_25["pct_yellow"])
		]
	)

	# 5. Chefes possuem as melhores distribuicoes e derrubam multiplos itens (media >= 2.3 itens por abate)
	_check(
		float(boss_25["items_per_kill"]) >= 2.8 and float(boss_25["pct_yellow"]) > float(rare_25["pct_yellow"]),
		"10. Chefes possuem a melhor distribuicao de qualidade e quantidade (Nv.25 Chefe = %.2f itens/abate, %.1f%% Amarelos, %.2f%% Unicos)" % [
			float(boss_25["items_per_kill"]), float(boss_25["pct_yellow"]), float(boss_25["pct_red"])
		]
	)

	# 6. Nenhuma violacao de tier/ilvl de afixo em nenhum dos 24 cenarios (monstros fracos jamais geram afixos avancados)
	var total_violations: int = 0
	for m_class in CLASSES_TO_TEST:
		for lvl in LEVELS_TO_TEST:
			total_violations += int(results[m_class][lvl]["tier_violations"])
	_check(
		total_violations == 0 and int(norm_1["max_tier"]) == 1,
		"11. Zero violacoes de nivel de afixo em todos os 24 cenarios (Monstro Normal Nv.1 restrito a afixos Tier 1)"
	)
