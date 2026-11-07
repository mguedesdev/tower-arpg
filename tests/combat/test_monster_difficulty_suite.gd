extends SceneTree

const MonsterDifficultyService = preload("res://core/combat/monster_difficulty_service.gd")
# MonsterModifierDefinition é class_name global
const LootBalanceConfig = preload("res://core/items/loot_balance_config.gd")
# LootGenerationService é class_name global
const EnemyDefScript = preload("res://core/combat/enemy_definition.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("=================================================================")
	print("SUITE DE TESTES AUTOMATIZADOS: SISTEMA COMPLETO DE DIFICULDADE (ARPG)")
	print("=================================================================")
	_run_all_tests()
	print("=================================================================")
	print("RESULTADO FINAL: %d/%d TESTES PASSARAM (%d FALHAS)" % [passed_tests, total_tests, failed_tests])
	print("=================================================================")
	if failed_tests == 0:
		print(">> TODOS OS TESTES PASSARAM COM SUCESSO! <<")
		quit(0)
	else:
		push_error(">> FALHAS ENCONTRADAS NA SUÍTE DE TESTES <<")
		quit(1)

func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % test_name)

func _run_all_tests() -> void:
	test_horizontal_validation_all_archetypes_and_ranks()
	test_vertical_validation_continuous_curve_1_to_100()
	test_tier_unlocking_and_weights()
	test_cascading_validation_enemy_combat_loop()
	test_additive_modifier_stacking_and_caps()
	test_title_generation()
	test_monte_carlo_100k_modifier_rolls()

## ----------------------------------------------------------------------------
## 1. VALIDAÇÃO HORIZONTAL: Todos os Arquétipos e Ranks
## ----------------------------------------------------------------------------
func test_horizontal_validation_all_archetypes_and_ranks() -> void:
	print("\n--- 1. VALIDAÇÃO HORIZONTAL (6 Arquétipos x 5 Ranks no Nível 10) ---")
	var archetypes: Array[String] = ["melee", "tank", "ranged", "caster", "support", "summoner"]
	var ranks: Array[int] = [
		LootBalanceConfig.MonsterClass.NORMAL,
		LootBalanceConfig.MonsterClass.MAGIC,
		LootBalanceConfig.MonsterClass.RARE,
		LootBalanceConfig.MonsterClass.HERO,
		LootBalanceConfig.MonsterClass.BOSS,
	]

	var ref_hp: int = 32
	var ref_dmg: int = 5
	var ref_spd: float = 2.4

	for arch in archetypes:
		for rk in ranks:
			var stats: Dictionary = MonsterDifficultyService.resolve_monster_stats(
				ref_hp, ref_dmg, ref_spd, 10, rk, arch
			)
			var label: String = "%s / %s" % [arch, LootBalanceConfig.get_monster_class_name(rk)]
			assert_test(int(stats["max_health"]) > 0, "HP > 0 para %s" % label)
			assert_test(int(stats["touch_damage"]) > 0, "Dano > 0 para %s" % label)
			assert_test(float(stats["movement_speed"]) >= 1.2 and float(stats["movement_speed"]) <= 5.5, "Velocidade sã [1.2, 5.5] para %s" % label)
			assert_test(float(stats["damage_reduction_pct"]) >= 0.0 and float(stats["damage_reduction_pct"]) <= 0.65, "Defesa sã [0.0, 0.65] para %s" % label)

	# Checagem de papéis táticos distintos
	var tank_stats: Dictionary = MonsterDifficultyService.resolve_monster_stats(ref_hp, ref_dmg, ref_spd, 10, LootBalanceConfig.MonsterClass.NORMAL, "tank")
	var caster_stats: Dictionary = MonsterDifficultyService.resolve_monster_stats(ref_hp, ref_dmg, ref_spd, 10, LootBalanceConfig.MonsterClass.NORMAL, "caster")
	var melee_stats: Dictionary = MonsterDifficultyService.resolve_monster_stats(ref_hp, ref_dmg, ref_spd, 10, LootBalanceConfig.MonsterClass.NORMAL, "melee")

	assert_test(int(tank_stats["max_health"]) > int(melee_stats["max_health"]), "Tank possui mais HP que Melee")
	assert_test(float(tank_stats["damage_reduction_pct"]) > float(melee_stats["damage_reduction_pct"]), "Tank possui mitigação natural de dano")
	assert_test(int(caster_stats["touch_damage"]) > int(melee_stats["touch_damage"]), "Caster possui dano superior a Melee")
	assert_test(int(caster_stats["max_health"]) < int(melee_stats["max_health"]), "Caster é mais frágil que Melee")

## ----------------------------------------------------------------------------
## 2. VALIDAÇÃO VERTICAL: Progressão Contínua (Nível 1 ao 100)
## ----------------------------------------------------------------------------
func test_vertical_validation_continuous_curve_1_to_100() -> void:
	print("\n--- 2. VALIDAÇÃO VERTICAL (Curva Contínua de Níveis 1 a 100) ---")
	var levels: Array[int] = [1, 5, 10, 15, 20, 25, 40, 60, 80, 90, 100]
	var last_hp: int = 0
	var last_dmg: int = 0
	var monotonic_hp: bool = true
	var monotonic_dmg: bool = true

	var ref_hp: int = 32
	var ref_dmg: int = 5
	var ref_spd: float = 2.4

	for lvl in levels:
		var hp: int = MonsterDifficultyService.calculate_base_hp(ref_hp, lvl)
		var dmg: int = MonsterDifficultyService.calculate_base_damage(ref_dmg, lvl)
		var spd: float = MonsterDifficultyService.calculate_base_speed(ref_spd, lvl)

		if hp < last_hp and lvl > 1:
			monotonic_hp = false
		if dmg < last_dmg and lvl > 1:
			monotonic_dmg = false

		last_hp = hp
		last_dmg = dmg

		assert_test(spd >= 2.4 and spd <= 3.2, "Velocidade no nível %d cresce suavemente (%.2f m/s)" % [lvl, spd])

	assert_test(monotonic_hp, "HP base cresce de forma estritamente contínua e monotônica")
	assert_test(monotonic_dmg, "Dano base cresce de forma estritamente contínua e monotônica")

	# Checagem de valores de referência (Ato 1 vs Endgame)
	var hp_1: int = MonsterDifficultyService.calculate_base_hp(ref_hp, 1)
	var hp_25: int = MonsterDifficultyService.calculate_base_hp(ref_hp, 25)
	var hp_90: int = MonsterDifficultyService.calculate_base_hp(ref_hp, 90)

	assert_test(hp_1 == 32, "Nível 1 HP base é 32")
	assert_test(hp_25 >= 75 and hp_25 <= 90, "Nível 25 HP base fica na faixa saudável do Ato 1 (obtido: %d)" % hp_25)
	assert_test(hp_90 >= 210 and hp_90 <= 250, "Nível 90 HP base escala para o endgame sem virar 'esponja de dano' irracional (obtido: %d)" % hp_90)

## ----------------------------------------------------------------------------
## 3. DESBLOQUEIO DE TIERS E PESOS
## ----------------------------------------------------------------------------
func test_tier_unlocking_and_weights() -> void:
	print("\n--- 3. DESBLOQUEIO DE TIERS DE AFIXOS CONFORME NÍVEL ---")
	var brutal: MonsterModifierDefinition = MonsterDifficultyService.get_modifier("brutal")
	assert_test(brutal != null, "Modificador 'brutal' existe no catálogo")

	# Nível 5: apenas T5 deve estar disponível
	var tiers_lvl5: Array[Dictionary] = brutal.get_eligible_tiers(5)
	assert_test(tiers_lvl5.size() == 1 and int(tiers_lvl5[0]["tier"]) == 5, "Nível 5 só tem acesso ao Tier 5")

	# Nível 20: T5 e T4 disponíveis
	var tiers_lvl20: Array[Dictionary] = brutal.get_eligible_tiers(20)
	assert_test(tiers_lvl20.size() == 2, "Nível 20 desbloqueou Tier 4 além do Tier 5")

	# Nível 80: Todos os 5 tiers desbloqueados (T1 a T5)
	var tiers_lvl80: Array[Dictionary] = brutal.get_eligible_tiers(80)
	assert_test(tiers_lvl80.size() == 5, "Nível 80 possui todos os 5 tiers desbloqueados")

	# Sorteio ponderado no nível 80: T5 ainda tem maior probabilidade que T1
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 12345
	var roll_counts: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	for i in range(10000):
		var rolled: Dictionary = brutal.roll_tier(80, rng)
		var t_num: int = int(rolled.get("tier", 5))
		roll_counts[t_num] = roll_counts[t_num] + 1

	assert_test(roll_counts[5] > roll_counts[1], "No nível 80, Tier 5 ainda é sorteado com maior frequência que Tier 1 (T5: %d, T1: %d)" % [roll_counts[5], roll_counts[1]])
	assert_test(roll_counts[1] > 0, "No nível 80, Tier 1 é acessível (T1: %d vezes)" % roll_counts[1])

## ----------------------------------------------------------------------------
## 4. VALIDAÇÃO EM CASCATA: Fluxo Completo de Combate e Drops
## ----------------------------------------------------------------------------
func test_cascading_validation_enemy_combat_loop() -> void:
	print("\n--- 4. VALIDAÇÃO EM CASCATA (Instanciação -> Combate -> Morte -> Loot) ---")
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
	assert_test(enemy_scene != null, "Cena enemy.tscn carregada com sucesso")

	var enemy = enemy_scene.instantiate()
	assert_test(enemy != null, "Inimigo instanciado com sucesso")

	var forced_mods: Array = [
		{"id": "armored", "display_name": "Couraçado", "params": {"damage_reduction": 0.25, "speed_mult": 0.90}},
		{"id": "regenerator", "display_name": "Regenerador", "params": {"regen_pct_sec": 0.05, "hit_cooldown": 0.1}},
		{"id": "ignited", "display_name": "Incendiário", "params": {"burn_ratio": 0.30, "burn_duration": 2.0}},
	]

	enemy.configure_difficulty(20, LootBalanceConfig.MonsterClass.RARE, "tank", forced_mods)

	assert_test(enemy.monster_level == 20, "Nível do monstro configurado para 20")
	assert_test(enemy.monster_rank == LootBalanceConfig.MonsterClass.RARE, "Rank do monstro configurado para Raro")
	assert_test(enemy.combat_archetype == "tank", "Arquétipo configurado para Tank")
	assert_test(enemy.damage_reduction_pct >= 0.40, "Mitigação combinada (Tank + Couraçado) aplicada (obtido: %.2f%%)" % [enemy.damage_reduction_pct * 100.0])
	assert_test(enemy.burn_on_hit_ratio == 0.30, "Incendiário configurou burn_on_hit_ratio corretamente")
	assert_test(enemy.regen_pct_sec == 0.05, "Regenerador configurou regen_pct_sec corretamente")

	# Mitigação de dano em take_damage
	var initial_hp: int = enemy.health
	var raw_hit: int = 100
	var expected_dmg: int = maxi(1, roundi(float(raw_hit) * (1.0 - enemy.damage_reduction_pct)))
	enemy.take_damage(raw_hit)
	assert_test(enemy.health == initial_hp - expected_dmg, "Dano mitigado corretamente: esperado -%d, vida atual %d/%d" % [expected_dmg, enemy.health, enemy.maximum_health])

	# Regeneração passiva
	var damaged_hp: int = enemy.health
	enemy._regen_cooldown_timer = 0.0 # simula expiração do cooldown de golpe
	enemy._process(0.5) # processa 0.5s de regeneração
	assert_test(enemy.health > damaged_hp, "Inimigo regenerou vida com sucesso após o cooldown")

	# Geração de loot associada ao monstro abatido
	var drops: Array = LootGenerationService.generate_monster_loot_drops(
		enemy.monster_level,
		enemy.monster_rank,
		"act1"
	)
	assert_test(drops != null, "Drops de loot gerados com base no nível e rank do monstro")

	enemy.free()

## ----------------------------------------------------------------------------
## 5. EMPILHAMENTO ADITIVO E LIMITES SANITÁRIOS (CAPS)
## ----------------------------------------------------------------------------
func test_additive_modifier_stacking_and_caps() -> void:
	print("\n--- 5. EMPILHAMENTO ADITIVO DE MODIFICADORES E TETO DE DEFESA (65%) ---")
	# Criar modificadores extremos para testar proteção contra explosão
	var extreme_mods: Array = [
		{"id": "armored", "params": {"damage_reduction": 0.40, "speed_mult": 0.80}},
		{"id": "super_shield", "params": {"damage_reduction": 0.50, "speed_mult": 0.80}},
	]

	var stats: Dictionary = MonsterDifficultyService.resolve_monster_stats(
		50, 10, 2.5, 30, LootBalanceConfig.MonsterClass.RARE, "tank", extreme_mods
	)

	assert_test(float(stats["damage_reduction_pct"]) == 0.65, "Teto máximo de 65%% de mitigação respeitado estritamente (obtido: %.2f)" % stats["damage_reduction_pct"])
	assert_test(float(stats["movement_speed"]) >= 1.2, "Velocidade mínima respeita o assoalho sanitário de 1.2 m/s (obtido: %.2f)" % stats["movement_speed"])

## ----------------------------------------------------------------------------
## 6. GERAÇÃO DE TÍTULO LEGÍVEL
## ----------------------------------------------------------------------------
func test_title_generation() -> void:
	print("\n--- 6. GERAÇÃO DE TÍTULO DINÂMICO DO MONSTRO ---")
	var title_1: String = MonsterDifficultyService.build_monster_title(
		"Esqueleto",
		LootBalanceConfig.MonsterClass.MAGIC,
		[{"display_name": "Brutal"}]
	)
	assert_test(title_1 == "Esqueleto Brutal", "Título com 1 modificador gerado corretamente: '%s'" % title_1)

	var title_2: String = MonsterDifficultyService.build_monster_title(
		"Esqueleto",
		LootBalanceConfig.MonsterClass.RARE,
		[{"display_name": "Brutal"}, {"display_name": "Veloz"}]
	)
	assert_test(title_2 == "Esqueleto Brutal e Veloz", "Título com 2 modificadores formatado com 'e': '%s'" % title_2)

	var title_3: String = MonsterDifficultyService.build_monster_title(
		"Lobo Alfa",
		LootBalanceConfig.MonsterClass.RARE,
		[{"display_name": "Couraçado"}, {"display_name": "Incendiário"}, {"display_name": "Regenerador"}]
	)
	assert_test(title_3 == "Lobo Alfa Couraçado, Incendiário e Regenerador", "Título com 3 modificadores formatado com vírgulas e 'e': '%s'" % title_3)

## ----------------------------------------------------------------------------
## 7. SIMULAÇÃO MONTE CARLO (100.000 SORTEIOS)
## ----------------------------------------------------------------------------
func test_monte_carlo_100k_modifier_rolls() -> void:
	print("\n--- 7. SIMULAÇÃO MONTE CARLO (100.000 Sorteios de Modificadores) ---")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 987654321

	var test_levels: Array[int] = [5, 10, 15, 25, 45, 65, 85, 95]
	var test_ranks: Array[int] = [
		LootBalanceConfig.MonsterClass.MAGIC,
		LootBalanceConfig.MonsterClass.RARE,
		LootBalanceConfig.MonsterClass.HERO,
	]
	var test_archs: Array[String] = ["melee", "tank", "ranged", "caster", "support"]

	var total_rolls: int = 100000
	var conflict_violations: int = 0
	var control_violations: int = 0
	var support_violations: int = 0
	var rank_count_violations: int = 0

	var tier_distribution: Dictionary = {1: 0, 2: 0, 3: 0, 4: 0, 5: 0}
	var total_mods_rolled: int = 0

	var mod_catalog: Dictionary = MonsterDifficultyService.get_all_modifiers()

	for i in range(total_rolls):
		var lvl: int = test_levels[i % test_levels.size()]
		var rk: int = test_ranks[i % test_ranks.size()]
		var arch: String = test_archs[i % test_archs.size()]

		var mods: Array[Dictionary] = MonsterDifficultyService.roll_modifiers(lvl, rk, arch, ["undead"], rng)

		# 1. Checagem de quantidade por rank
		match rk:
			LootBalanceConfig.MonsterClass.MAGIC:
				if mods.size() > 1:
					rank_count_violations += 1
			LootBalanceConfig.MonsterClass.RARE:
				if mods.size() > 4:
					rank_count_violations += 1
			LootBalanceConfig.MonsterClass.HERO:
				if mods.size() > 2:
					rank_count_violations += 1

		# 2. Checagem de regras de conflito e categorias
		var seen_conflicts: Dictionary = {}
		var control_count: int = 0
		var support_count: int = 0

		for m in mods:
			var m_id: String = m["id"]
			var m_def: MonsterModifierDefinition = mod_catalog.get(m_id)
			if m_def != null:
				for cg in m_def.conflict_groups:
					if seen_conflicts.has(cg):
						conflict_violations += 1
					seen_conflicts[cg] = true

			var cat: String = m.get("category", "")
			if cat == "control":
				control_count += 1
			elif cat == "support":
				support_count += 1

			var t_num: int = int(m.get("tier", 5))
			tier_distribution[t_num] = tier_distribution.get(t_num, 0) + 1
			total_mods_rolled += 1

		if control_count > 1:
			control_violations += 1
		if support_count > 1:
			support_violations += 1

	print("  -> Total de Sorteios Executados: %d" % total_rolls)
	print("  -> Total de Modificadores Concedidos: %d" % total_mods_rolled)
	print("  -> Violações de Conflito Mútuo: %d" % conflict_violations)
	print("  -> Violações de Limite de Controle (>1): %d" % control_violations)
	print("  -> Violações de Limite de Suporte (>1): %d" % support_violations)
	print("  -> Violações de Quantidade por Rank: %d" % rank_count_violations)
	print("  -> Distribuição de Tiers em 100k sorteios:")
	for t in [1, 2, 3, 4, 5]:
		var pct: float = float(tier_distribution[t]) / maxf(1.0, float(total_mods_rolled)) * 100.0
		print("     - Tier %d: %d (%.2f%%)" % [t, tier_distribution[t], pct])

	assert_test(conflict_violations == 0, "Zero violações de grupos de conflito em 100.000 sorteios")
	assert_test(control_violations == 0, "Zero violações de limite de controle (máx 1) em 100.000 sorteios")
	assert_test(support_violations == 0, "Zero violações de limite de suporte (máx 1) em 100.000 sorteios")
	assert_test(rank_count_violations == 0, "Zero violações de contagem máxima de modificadores por rank")
	assert_test(tier_distribution[5] > tier_distribution[1], "Distribuição global respeita pirâmide de raridade ponderada (T5 > T1)")
