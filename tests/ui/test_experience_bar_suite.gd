extends SceneTree

## ============================================================================
## SUÍTE DE QA: BARRA DE EXPERIÊNCIA (XP) & LEVELING DO ARPG (GODOT 4)
## ============================================================================

const ExperienceService = preload("res://core/progression/experience_service.gd")
const ExperienceBarHUD = preload("res://game/ui/campaign/experience_bar_hud.gd")
const SkillBarHUD = preload("res://game/ui/campaign/skill_bar_hud.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	call_deferred("_run_suite")


func _check(condition: bool, desc: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % desc)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % desc)


func _run_suite() -> void:
	print("=================================================================")
	print("SUÍTE DE QA: BARRA DE EXPERIÊNCIA (XP) & LEVELING (GODOT 4 ARPG) ")
	print("=================================================================")

	var root_node := get_root()
	root_node.size = Vector2i(1920, 1080)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "TestHUD"
	root_node.add_child(hud_layer)

	var hotbar := SkillBarHUD.new()
	hud_layer.add_child(hotbar)

	var xp_service := ExperienceService.new(1, 0)
	var xp_bar := ExperienceBarHUD.new()
	hud_layer.add_child(xp_bar)
	xp_bar.bind_service(xp_service)
	xp_bar.bind_hotbar(hotbar)

	for _i in range(3):
		await process_frame

	# -------------------------------------------------------------------------
	# 1. TEXTURAS, ALINHAMENTO E ESTRUTURA VISUAL
	# -------------------------------------------------------------------------
	print("\n--- 1. TEXTURAS, ALINHAMENTO E ESTRUTURA VISUAL ---")
	_check(xp_bar.is_inside_tree(), "ExperienceBarHUD devidamente instanciada na árvore")
	var pb: TextureProgressBar = xp_bar.get_node_or_null("Scaler/ProgressBar") as TextureProgressBar
	_check(pb != null, "Nó 'ProgressBar' (TextureProgressBar) existe")
	_check(pb.texture_under != null, "Textura de fundo/moldura (xp_bar_empty.png) carregada")
	_check(pb.texture_progress != null, "Textura do líquido mágico (xp_bar_fill_aligned.png) carregada")
	_check(pb.fill_mode == TextureProgressBar.FILL_LEFT_TO_RIGHT, "Preenchimento horizontal da esquerda para a direita")
	_check(pb.min_value == 0.0 and pb.max_value == 100.0, "Escala percentual de 0 a 100")
	_check(xp_bar.mouse_filter == Control.MOUSE_FILTER_PASS, "mouse_filter é PASS (permite hover de tooltip sem bloquear combate)")

	# -------------------------------------------------------------------------
	# 2. PREENCHIMENTO VISUAL: 0%, 25%, 50%, 75% E 100%
	# -------------------------------------------------------------------------
	print("\n--- 2. PREENCHIMENTO VISUAL (0%, 25%, 50%, 75%, 100%) ---")
	xp_bar._set_visual_ratio(0.0, false)
	_check(is_equal_approx(pb.value, 0.0), "Barra vazia em 0%% (valor: %.1f)" % pb.value)

	xp_bar._set_visual_ratio(0.25, false)
	_check(is_equal_approx(pb.value, 25.0), "Barra em 25%% (valor: %.1f)" % pb.value)

	xp_bar._set_visual_ratio(0.50, false)
	_check(is_equal_approx(pb.value, 50.0), "Barra em 50%% (valor: %.1f)" % pb.value)

	xp_bar._set_visual_ratio(0.75, false)
	_check(is_equal_approx(pb.value, 75.0), "Barra em 75%% (valor: %.1f)" % pb.value)

	xp_bar._set_visual_ratio(1.00, false)
	_check(is_equal_approx(pb.value, 100.0), "Barra cheia em 100%% (valor: %.1f)" % pb.value)

	# -------------------------------------------------------------------------
	# 3. CÁLCULO DE XP POR ABATE: FAMÍLIAS, ARQUÉTIPOS E RARIDADES (DOC 09)
	# -------------------------------------------------------------------------
	print("\n--- 3. CÁLCULO DE XP POR MONSTRO (DOC 09) ---")
	var s := ExperienceService.new(1, 0)
	# Nível 1: base_monster_xp(1) = 22
	var xp_skel_w: int = s.calculate_kill_xp(1, "skeleton", LootBalanceConfig.MonsterClass.NORMAL)
	var xp_wolf_w: int = s.calculate_kill_xp(1, "wolf", LootBalanceConfig.MonsterClass.NORMAL)
	var xp_boss_w: int = s.calculate_kill_xp(1, "skeleton_boss", LootBalanceConfig.MonsterClass.NORMAL)

	_check(xp_skel_w == 22, "Caveira Branca Nível 1 concede 22 XP (atual: %d)" % xp_skel_w)
	_check(xp_wolf_w == 26, "Lobo Branco Nível 1 (fator 1.2x) concede 26 XP (atual: %d)" % xp_wolf_w)
	_check(xp_boss_w == 40, "Caveirão Branco Nível 1 (fator 1.8x) concede 40 XP (atual: %d)" % xp_boss_w)

	# Raridades
	var xp_skel_magic: int = s.calculate_kill_xp(1, "skeleton", LootBalanceConfig.MonsterClass.MAGIC)
	var xp_skel_rare: int = s.calculate_kill_xp(1, "skeleton", LootBalanceConfig.MonsterClass.RARE)
	_check(xp_skel_magic == 33, "Caveira Mágica (Azul 1.5x) concede 33 XP (atual: %d)" % xp_skel_magic)
	_check(xp_skel_rare == 55, "Caveira Rara (Amarela 2.5x) concede 55 XP (atual: %d)" % xp_skel_rare)

	# Chefe Autoral e Primeira Vitória
	var s_lvl10 := ExperienceService.new(10)
	var xp_boss_repeat: int = s_lvl10.calculate_kill_xp(10, "skeleton_boss", LootBalanceConfig.MonsterClass.BOSS, true, "malakor")
	_check(xp_boss_repeat >= 3000, "Chefe de Nível 10 com 1ª vitória concede XP épica autoral (%d XP)" % xp_boss_repeat)

	# Anti-Power-Leveling e Anti-Farm Trivial
	var s_lvl1 := ExperienceService.new(1, 0)
	var xp_high_capped: int = s_lvl1.calculate_kill_xp(90, "skeleton", LootBalanceConfig.MonsterClass.NORMAL)
	_check(xp_high_capped < 200, "Anti-Boost: Player nível 1 enfrentando mob nível 90 tem crédito travado em Lvl 6 (%d XP)" % xp_high_capped)

	var s_lvl50 := ExperienceService.new(50)
	var xp_low_penalized: int = s_lvl50.calculate_kill_xp(1, "skeleton", LootBalanceConfig.MonsterClass.NORMAL)
	_check(xp_low_penalized <= 2, "Anti-Farm Trivial: Player nível 50 derrotando mob nível 1 sofre penalidade severa (%d XP)" % xp_low_penalized)

	# -------------------------------------------------------------------------
	# 4. PROGRESSÃO, LEVEL-UP, OVERFLOW E MÚLTIPLOS NÍVEIS
	# -------------------------------------------------------------------------
	print("\n--- 4. PROGRESSÃO, LEVEL-UP E PRESERVAÇÃO DE OVERFLOW ---")
	var sim_service := ExperienceService.new(1, 0)
	xp_bar.bind_service(sim_service)

	_check(sim_service.current_level == 1, "Inicia no Nível 1")
	_check(sim_service.get_xp_required_for_next_level(1) == 90, "Nível 1 requer exatamente 90 XP para o Nível 2")

	# Adiciona 50 XP (Progresso parcial sem subir de nível)
	sim_service.add_xp(50)
	_check(sim_service.current_level == 1, "Permanece Nível 1 com 50/90 XP")
	_check(sim_service.current_xp_in_level == 50, "XP atual no nível é 50")
	_check(sim_service.get_progress_percentage() == 56, "Progresso relativo é 56%% (50/90)")
	_check(sim_service.get_xp_remaining() == 40, "Faltam exatamente 40 XP")

	# Adiciona 50 XP adicionais (Total 100 XP -> Level Up para Nível 2 com 10 XP de overflow!)
	var levels: Array[int] = sim_service.add_xp(50)
	_check(sim_service.current_level == 2, "Alcançou Nível 2 com sucesso")
	_check(levels.has(2), "Retornou nível 2 na lista de levels alcançados")
	_check(sim_service.current_xp_in_level == 10, "Overflow preservado estritamente: 10 XP no Nível 2 (100 - 90)")
	_check(sim_service.total_xp == 100, "Total vitalício de XP é 100")

	# Múltiplos level-ups com um único abate grande (ex: Boss concedendo 2.000 XP)
	var multi_levels: Array[int] = sim_service.add_xp(2000)
	_check(multi_levels.size() >= 3, "Processou múltiplos level-ups em um único abate (%d níveis)" % multi_levels.size())
	_check(sim_service.current_level >= 5, "Subiu para o Nível %d" % sim_service.current_level)
	_check(sim_service.current_xp_in_level < sim_service.get_xp_required_for_next_level(sim_service.current_level), "XP restante é estritamente menor que o threshold do nível atual")

	# -------------------------------------------------------------------------
	# 5. ESCALONAMENTO ALÉM DO NÍVEL 25 (90, 100, 120+)
	# -------------------------------------------------------------------------
	print("\n--- 5. ESCALONAMENTO DA CURVA (NÍVEIS 25, 50, 90, 100, 120) ---")
	_check(ExperienceService.get_xp_required_for_next_level(25) == 35707, "Nível 25 requer 35.707 XP conforme fórmula oficial (L=25)")
	_check(ExperienceService.get_xp_required_for_next_level(50) == 159540, "Nível 50 requer 159.540 XP conforme fórmula oficial (L=50)")
	_check(ExperienceService.get_xp_required_for_next_level(90) == 558472, "Nível 90 requer 558.472 XP conforme fórmula oficial (L=90)")
	_check(ExperienceService.get_xp_required_for_next_level(100) == 698397, "Nível 100 requer 698.397 XP conforme fórmula oficial (L=100)")
	_check(ExperienceService.get_xp_required_for_next_level(120) > 1000000, "Nível 120 calculado matematicamente sem limites artificiais (> 1.000.000 XP)")

	# -------------------------------------------------------------------------
	# 6. TOOLTIP DE EXPERIÊNCIA FORMATADO E SEM NÚMEROS PERMANENTES
	# -------------------------------------------------------------------------
	print("\n--- 6. TOOLTIP DINÂMICO E LIMPEZA VISUAL ---")
	var t_service := ExperienceService.new(12)
	xp_bar.bind_service(t_service)
	xp_bar.cached_xp_in_level = 2450
	xp_bar.cached_xp_required = 5000
	xp_bar._update_tooltip_text()

	var tt_text: String = xp_bar.tooltip_text
	_check(tt_text.contains("Nível 12"), "Tooltip contém 'Nível 12'")
	_check(tt_text.contains("Experiência:"), "Tooltip contém 'Experiência:'")
	_check(tt_text.contains("Progresso:"), "Tooltip contém 'Progresso:'")
	_check(tt_text.contains("Faltam:"), "Tooltip contém 'Faltam:'")

	# -------------------------------------------------------------------------
	# 7. SINCRONIZAÇÃO DE POSICIONAMENTO E RESPONSIVIDADE COM A HOTBAR
	# -------------------------------------------------------------------------
	print("\n--- 7. SINCRONIZAÇÃO E RESPONSIVIDADE COM A HOTBAR ---")
	root_node.size = Vector2i(1920, 1080)
	for _i in range(2):
		await process_frame
	hotbar._relayout()
	xp_bar._relayout()

	_check(is_equal_approx(xp_bar.ui_scale, hotbar.ui_scale), "XP Bar compartilha a mesma ui_scale da hotbar (1920x1080: %.2f)" % xp_bar.ui_scale)
	_check(xp_bar.position.y < hotbar.position.y, "XP Bar está localizada fisicamente ACIMA da hotbar (xp_y: %.1f < hotbar_y: %.1f)" % [xp_bar.position.y, hotbar.position.y])
	var center_diff: float = absf((xp_bar.position.x + xp_bar.size.x * 0.5) - (hotbar.position.x + hotbar.size.x * 0.5))
	_check(center_diff < 2.0, "XP Bar perfeitamente centralizada em relação à hotbar (delta x: %.2f px)" % center_diff)

	# Resolução 1280x720
	root_node.size = Vector2i(1280, 720)
	for _i in range(2):
		await process_frame
	hotbar._relayout()
	xp_bar._relayout()
	_check(is_equal_approx(xp_bar.ui_scale, hotbar.ui_scale), "Escala reduzida proporcionalmente em 1280x720 (%.2f)" % xp_bar.ui_scale)
	_check(xp_bar.position.y < hotbar.position.y, "Continua acima da hotbar em 1280x720")

	# Resolução Ultrawide 3440x1440
	root_node.size = Vector2i(3440, 1440)
	for _i in range(2):
		await process_frame
	hotbar._relayout()
	xp_bar._relayout()
	var center_diff_uw: float = absf((xp_bar.position.x + xp_bar.size.x * 0.5) - (hotbar.position.x + hotbar.size.x * 0.5))
	_check(center_diff_uw < 2.0, "Permanece centralizada em ultrawide 3440x1440 (delta: %.2f px)" % center_diff_uw)

	# -------------------------------------------------------------------------
	# 8. PERSISTÊNCIA E SERIALIZAÇÃO DO SERVIÇO DE XP
	# -------------------------------------------------------------------------
	print("\n--- 8. PERSISTÊNCIA E SERIALIZAÇÃO DE SAVE ---")
	var save_data: Dictionary = sim_service.to_dictionary()
	_check(save_data.has("level") and save_data.has("total_xp"), "SaveData contém 'level' e 'total_xp'")

	var restored_service := ExperienceService.new(1, 0)
	restored_service.from_dictionary(save_data)
	_check(restored_service.current_level == sim_service.current_level, "Nível restaurado com perfeição (%d)" % restored_service.current_level)
	_check(restored_service.total_xp == sim_service.total_xp, "Total de XP restaurado com perfeição (%d)" % restored_service.total_xp)
	_check(restored_service.current_xp_in_level == sim_service.current_xp_in_level, "Progresso no nível restaurado (%d)" % restored_service.current_xp_in_level)

	# -------------------------------------------------------------------------
	# RESULTADO FINAL
	# -------------------------------------------------------------------------
	print("\n=================================================================")
	print("RESULTADO QA BARRA DE XP: %d/%d PASSARAM (%d FALHAS)" % [passed_tests, total_tests, failed_tests])
	print("=================================================================")
	if failed_tests == 0:
		print(">> TODOS OS REQUISITOS DA BARRA DE EXPERIÊNCIA FORAM APROVADOS! <<")
		quit(0)
	else:
		printerr(">> HOUVE FALHAS NA SUÍTE DE TESTES <<")
		quit(1)
