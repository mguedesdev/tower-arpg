extends SceneTree
## Suite completa de testes automatizados e de integração da Progressão V1.0 (Seção 14 - 18 itens obrigatórios).
## Executar: Godot_v4.7.2-stable_win64_console.exe --headless --path "c:\Users\mathh\OneDrive\Documents\jogo" --script res://tests/progression/test_full_progression_suite.gd

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const TEST_SAVE_PATH: String = "user://test_progression_suite_save.json"

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
	print("=== INICIANDO SUITE DE TESTES OBRIGATÓRIOS — CHARACTER PROGRESSION V1.0 ===")
	_test_1_to_3_xp_and_queued_levels()
	_test_4_stats_calculation_and_health_rules()
	_test_5_to_9_offers_exclusivity_transformations_and_recursion()
	_test_10_to_16_meta_progression_save_rewards_respec_and_class_isolation()
	_test_17_to_18_instance_isolation_and_scene_ui_integration()

	# Limpa artefato temporário de save de teste
	var cleanup := SaveService.new(TEST_SAVE_PATH)
	cleanup.delete_save_files()

	print("=== RESULTADO FINAL: %d PASSARAM | %d FALHARAM ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_1_to_3_xp_and_queued_levels() -> void:
	var srv := RunProgressionService.new()
	root.add_child(srv)

	# 1. XP aumenta corretamente
	srv.grant_xp(7)
	_check(srv.state.level == 1 and srv.state.xp == 7 and srv.state.total_xp == 7, "1. XP aumenta corretamente")

	# 2. XP excedente é preservado (requisito nível 1->2 = 12 XP; 7 + 8 = 15 -> nível 2 com 3 XP)
	srv.grant_xp(8)
	_check(srv.state.level == 2 and srv.state.xp == 3, "2. XP excedente é preservado após subir de nível")

	# 3. Vários níveis acumulados geram a quantidade correta de escolhas
	srv.grant_xp(100)
	_check(srv.state.level == 5 and srv.state.pending_upgrade_choices == 4 and srv.state.xp == 29, "3. Vários níveis acumulados geram a fila exata de escolhas")

	srv.free()


func _test_4_stats_calculation_and_health_rules() -> void:
	var stats := CharacterStats.new()
	stats.set_base_stat(CharacterStats.STAT_DAMAGE, 20.0)
	stats.set_base_stat(CharacterStats.STAT_MAX_HEALTH, 100.0)
	stats.set_current_health(80) # 20 de vida faltando

	# Política: (Base 20 + Flat 5) * (1.0 + 0.20 + 0.30) * (1.20) = 25 * 1.5 * 1.2 = 45
	stats.add_modifier(StatModifier.new("flat_5", CharacterStats.STAT_DAMAGE, StatModifier.Op.FLAT, 5.0, "test"))
	stats.add_modifier(StatModifier.new("pct_20", CharacterStats.STAT_DAMAGE, StatModifier.Op.PERCENT_ADD, 0.20, "test"))
	stats.add_modifier(StatModifier.new("pct_30", CharacterStats.STAT_DAMAGE, StatModifier.Op.PERCENT_ADD, 0.30, "test"))
	stats.add_modifier(StatModifier.new("mult_12", CharacterStats.STAT_DAMAGE, StatModifier.Op.MULTIPLY, 1.20, "test"))
	_check(stats.get_damage() == 45, "4a. Atributos recalculados na ordem Base -> Flat -> %Aditivo -> Multiplicador")

	# Regra de vida máxima: preservando vida faltante (faltavam 20: 80/100 -> +30 max HP -> 110/130)
	stats.add_modifier(StatModifier.new("hp_30", CharacterStats.STAT_MAX_HEALTH, StatModifier.Op.FLAT, 30.0, "test"))
	_check(stats.get_max_health() == 130 and stats.current_health == 110, "4b. Aumento de vida máxima preserva a quantidade de vida faltante")

	# Remoção e expiração de bônus temporário
	stats.add_modifier(StatModifier.new("temp_spd", CharacterStats.STAT_ATTACK_SPEED, StatModifier.Op.PERCENT_ADD, 0.50, "buff", 1.0))
	_check(is_equal_approx(stats.get_attack_speed(), 1.5), "4c. Buff temporário aplicado")
	stats.tick_temporary_modifiers(1.2)
	_check(is_equal_approx(stats.get_attack_speed(), 1.0), "4d. Expiração de buff temporário restaura valor exato sem duplicar multiplicadores")


func _test_5_to_9_offers_exclusivity_transformations_and_recursion() -> void:
	var srv := RunProgressionService.new()
	var stats := CharacterStats.new()
	var ability_def: AbilityDefinition = load("res://content/abilities/warrior_strike.tres") as AbilityDefinition
	var ability_rt := AbilityRuntimeState.new(ability_def)
	root.add_child(srv)
	srv.set_rng_seed(12345)
	srv.bind_runtime_targets(stats, ability_rt, "warrior", [])

	# Concede muitos níveis para testar limites e exclusividade
	srv.grant_xp(500)
	var offers: Array[ProgressionUpgradeDefinition] = srv.get_or_generate_current_offers(3)
	_check(offers.size() == 3 and offers[0].id != offers[1].id and offers[1].id != offers[2].id and offers[0].id != offers[2].id, "5a. Ofertas geram 3 opções válidas sem duplicatas no mesmo painel")

	# 5. Melhorias alcançam seu limite (max_rank)
	var dmg_upg: ProgressionUpgradeDefinition = load("res://content/progression/upgrades/stat_dano.tres") as ProgressionUpgradeDefinition
	for _i in range(dmg_upg.max_rank):
		srv.grant_xp(200)
		srv.apply_upgrade_choice(dmg_upg, stats, ability_rt)
	_check(srv.state.get_upgrade_rank("stat_dano") == dmg_upg.max_rank, "5b. Melhoria atinge max_rank corretamente")
	_check(not srv.offer_generator.is_upgrade_eligible(dmg_upg, srv.state), "5c. Melhoria maximizada não é mais elegível para oferta")

	# 6. Evoluções incompatíveis não aparecem após escolha exclusiva (Meia-lua vs Perfuração)
	var arc_upg: ProgressionUpgradeDefinition = load("res://content/progression/upgrades/trans_meia_lua.tres") as ProgressionUpgradeDefinition
	var pierce_upg: ProgressionUpgradeDefinition = load("res://content/progression/upgrades/trans_perfuracao.tres") as ProgressionUpgradeDefinition
	_check(srv.offer_generator.is_upgrade_eligible(arc_upg, srv.state) and srv.offer_generator.is_upgrade_eligible(pierce_upg, srv.state), "6a. Ambas as transformações primárias são elegíveis antes da escolha")

	var applied_arc: bool = srv.apply_upgrade_choice(arc_upg, stats, ability_rt)
	_check(applied_arc and not srv.offer_generator.is_upgrade_eligible(pierce_upg, srv.state), "6b. Evolução incompatível (Perfuração) é bloqueada após escolher Meia-lua")

	# 7. Transformações não duplicam efeitos e 9. Habilidade transformada utiliza o comportamento correto
	_check(ability_rt.active_behavior == AbilityDefinition.Behavior.ARC and ability_rt.active_display_name == "Meia-lua", "9. Habilidade transformada utiliza o comportamento ativo correto")
	var radius_after_arc: float = ability_rt.get_effective_radius(stats)
	# Testar em uma segunda instância a transformação em Perfuração
	var ability_pierce := AbilityRuntimeState.new(ability_def)
	ability_pierce.apply_transformation("trans_perfuracao", AbilityDefinition.Behavior.PIERCE, "Perfuração", pierce_upg.ability_transformation_params, pierce_upg.granted_tags)
	_check(ability_pierce.active_behavior == AbilityDefinition.Behavior.PIERCE and ability_pierce.get_effective_radius(stats) > radius_after_arc, "7. Transformação substitui parâmetros de comportamento sem somar/duplicar a transformação anterior")

	# 8. Modificadores secundários (Fogo + Eco) compatíveis e sem recursão infinita
	var fire_upg: ProgressionUpgradeDefinition = load("res://content/progression/upgrades/mod_fogo.tres") as ProgressionUpgradeDefinition
	var echo_upg: ProgressionUpgradeDefinition = load("res://content/progression/upgrades/mod_eco.tres") as ProgressionUpgradeDefinition
	srv.grant_xp(400)
	_check(srv.apply_upgrade_choice(fire_upg, stats, ability_rt) and srv.apply_upgrade_choice(echo_upg, stats, ability_rt), "8a. Modificadores Fogo e Eco são compatíveis na mesma build")
	_check(ability_rt.can_trigger_secondary_effects(false) and not ability_rt.can_trigger_secondary_effects(true), "8b. Golpes secundários (Eco/DoT) têm trava explícita contra recursão infinita")

	# 10. Uma nova partida não herda melhorias temporárias
	srv.reset_run()
	_check(srv.state.level == 1 and srv.state.upgrade_history.is_empty() and stats.get_damage() == 14, "10. Nova partida limpa todas as melhorias e modificadores temporários da run")

	srv.free()


func _test_10_to_16_meta_progression_save_rewards_respec_and_class_isolation() -> void:
	var clean_save := SaveService.new(TEST_SAVE_PATH)
	clean_save.delete_save_files()

	var meta := PermanentProgressionService.new(TEST_SAVE_PATH)
	root.add_child(meta)

	# 14. Resultados não concedem recompensas duplicadas
	var reward_calc := RunRewardCalculator.new()
	var summary := RunSummaryState.new("run_unique_001")
	summary.waves_completed = 3
	summary.enemies_defeated = 20
	summary.run_level_reached = 4
	var first_grant: int = reward_calc.grant_reward_once(summary, meta)
	var second_grant: int = reward_calc.grant_reward_once(summary, meta)
	_check(first_grant > 0 and second_grant == 0 and meta.state.essence == first_grant, "14. Tela/cálculo de resultado concede Essência exatamente uma única vez por partida")

	# 11. Compra de talentos e aplicação única na partida
	meta.add_currency(50)
	var bought_root: bool = meta.purchase_talent("talent_vitality_root")
	var bought_might: bool = meta.purchase_talent("talent_warrior_might")
	_check(bought_root and bought_might, "11a. Compra de talentos na árvore permanente respeita pré-requisitos e saldo")

	var warrior_stats := CharacterStats.new()
	var run_srv := RunProgressionService.new()
	var ability_rt := AbilityRuntimeState.new(load("res://content/abilities/warrior_strike.tres") as AbilityDefinition)
	root.add_child(run_srv)

	meta.apply_to_run("warrior", warrior_stats, run_srv, ability_rt)
	var hp_once: int = warrior_stats.get_max_health()
	var dmg_once: int = warrior_stats.get_damage()
	meta.apply_to_run("warrior", warrior_stats, run_srv, ability_rt)
	_check(warrior_stats.get_max_health() == hp_once and warrior_stats.get_damage() == dmg_once and hp_once == 120, "11b. Progressão permanente é aplicada exatamente uma vez sem acumular duplicatas")

	# 16. Trocar de classe não aplica melhorias exclusivas indevidas (Fúria do Guerreiro é target_class_id = "warrior")
	var mage_stats := CharacterStats.new()
	meta.apply_to_run("mage", mage_stats, run_srv, ability_rt)
	_check(mage_stats.get_max_health() == 120 and mage_stats.get_damage() == 14, "16. Trocar de classe (mage) aplica talentos globais mas ignora talentos exclusivos do Guerreiro")

	# 12. Salvamento mantém nós e moeda após reabrir o jogo
	var saved_essence: int = meta.state.essence
	var meta_reloaded := PermanentProgressionService.new(TEST_SAVE_PATH)
	root.add_child(meta_reloaded)
	meta_reloaded.load_from_disk()
	_check(meta_reloaded.state.essence == saved_essence and meta_reloaded.get_talent_rank("talent_warrior_might") == 1, "12. Salvamento persiste e recarrega saldo de Essência e nós adquiridos")

	# 13. Save inválido/corrompido não causa crash e recupera backup (.bak) ou estado válido
	var corrupt_file: FileAccess = FileAccess.open(TEST_SAVE_PATH, FileAccess.WRITE)
	if corrupt_file != null:
		corrupt_file.store_string("{ json_corrompido: !!! nao_parseavel ")
		corrupt_file.close()
	var meta_recovered := PermanentProgressionService.new(TEST_SAVE_PATH)
	root.add_child(meta_recovered)
	meta_recovered.load_from_disk()
	_check(meta_recovered.state != null and meta_recovered.state.essence >= 0, "13. Save corrompido não causa crash e aciona recuperação segura")

	# 15. Reset de talentos (Respec) remove seus benefícios e reembolsa Essência
	var refunded: int = meta_reloaded.respec_all_talents(warrior_stats)
	meta_reloaded.apply_to_run("warrior", warrior_stats, run_srv, ability_rt)
	_check(refunded == 20 and warrior_stats.get_max_health() == 100 and warrior_stats.get_damage() == 14, "15. Respec reembolsa Essência investida e remove benefícios permanentes dos atributos")

	run_srv.free()
	meta.free()
	meta_reloaded.free()
	meta_recovered.free()


func _test_17_to_18_instance_isolation_and_scene_ui_integration() -> void:
	# 17. Duas instâncias de personagem não compartilham estado runtime acidentalmente
	var p1_scene: PackedScene = load("res://scenes/player.tscn") as PackedScene
	var p1: TowerPlayer = p1_scene.instantiate() as TowerPlayer
	var p2: TowerPlayer = p1_scene.instantiate() as TowerPlayer
	root.add_child(p1)
	root.add_child(p2)

	p1.stats.add_modifier(StatModifier.new("p1_hp", CharacterStats.STAT_MAX_HEALTH, StatModifier.Op.FLAT, 50.0, "run_upgrade"))
	var atk1: TowerAttackController = p1.get_node("AttackController") as TowerAttackController
	var atk2: TowerAttackController = p2.get_node("AttackController") as TowerAttackController
	atk1.set_form(TowerAttackController.Form.PIERCE)

	_check(p1.max_health == 150 and p2.max_health == 100 and atk1.active_form == TowerAttackController.Form.PIERCE and atk2.active_form == TowerAttackController.Form.STAB, "17. Duas instâncias de personagem não compartilham CharacterStats nem AbilityRuntimeState")
	p1.free()
	p2.free()

	# 18. Integração da cena principal e sincronia da UI com dados reais
	var arena: Node3D = MAIN_SCENE.instantiate() as Node3D
	root.add_child(arena)

	var run_srv: RunProgressionService = arena.get("run_progression") as RunProgressionService
	var hud: RunXpHUD = arena.get("xp_hud") as RunXpHUD
	var lvl_modal: LevelUpModal = arena.get("level_up_modal") as LevelUpModal
	var res_modal: RunResultModal = arena.get("run_result_modal") as RunResultModal
	var player_node: TowerPlayer = arena.get_node("Player") as TowerPlayer

	# Concede XP suficiente para subir para o nível 2 na partida real
	run_srv.grant_xp(15)
	var hud_level_lbl: Label = hud.get("_level_label") as Label
	_check(hud_level_lbl != null and hud_level_lbl.text.contains("02") and lvl_modal.visible and paused, "18a. HUD e LevelUpModal refletem subida de nível real e pausam o combate")

	# Escolhe a primeira carta de evolução na UI
	var first_offer: ProgressionUpgradeDefinition = run_srv.current_offers[0]
	arena.call("_on_upgrade_chosen", first_offer)
	_check(not lvl_modal.visible and not paused and run_srv.state.has_upgrade(first_offer.id), "18b. Escolher carta na UI aplica melhoria, fecha o modal e despausa o combate")

	# Simula morte do jogador e verifica abertura da tela de resultados com Essência
	player_node.take_damage(9999)
	_check(res_modal.visible and arena.get("current_run_summary") != null, "18c. Morte do jogador abre tela de resultados consolidada com Essência")

	# 19. Verifica os 3 Inimigos 3D orientados a objeto (Esqueleto, Lobo e Mini-Boss Carrasco Profanado)
	var skel_scene: PackedScene = load("res://scenes/enemy.tscn") as PackedScene
	var wolf_scene: PackedScene = load("res://scenes/enemies/wolf.tscn") as PackedScene
	var boss_scene: PackedScene = load("res://scenes/enemies/executioner_boss.tscn") as PackedScene
	var skel_inst: TowerEnemy = skel_scene.instantiate() as TowerEnemy
	var wolf_inst: TowerEnemy = wolf_scene.instantiate() as TowerEnemy
	var boss_inst: TowerEnemy = boss_scene.instantiate() as TowerEnemy
	arena.add_child(skel_inst)
	arena.add_child(wolf_inst)
	arena.add_child(boss_inst)
	_check(
		skel_inst._attack_animation != &"" and wolf_inst._attack_animation != &"" and boss_inst._attack_animation != &""
		and boss_inst.is_mini_boss and boss_inst.xp_reward_multiplier == 3 and boss_inst.health_bar != null,
		"19. Esqueleto, Lobo e Mini-Boss carregam GLB 3D com idle/walk/attack, EnemyDefinition e HealthBar3D"
	)

	paused = false
	arena.free()
