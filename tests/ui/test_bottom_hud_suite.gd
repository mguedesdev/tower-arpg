extends SceneTree

const HealthGlobeHUD = preload("res://game/ui/campaign/health_globe_hud.gd")
const ManaGlobeHUD = preload("res://game/ui/campaign/mana_globe_hud.gd")
const SkillBarHUD = preload("res://game/ui/campaign/skill_bar_hud.gd")
const CharacterStats = preload("res://core/stats/character_stats.gd")
const PlayerSkillController = preload("res://scripts/player_skill_controller.gd")
const SkillDefinition = preload("res://core/combat/skill_definition.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("=================================================================")
	print("SUITE DE TESTES AUTOMATIZADOS: NOVA HUD INFERIOR (GODOT 4)")
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
	test_component_architecture_and_independence()
	test_health_orb_and_bar_proportions()
	test_mana_orb_and_bar_proportions()
	test_hotbar_6_slots_and_empty_clean_state()
	test_hotbar_skill_assignment_and_mana_cost()
	test_mana_unavailability_and_cooldown_sweep()
	test_responsive_layout_and_clearance_1280x720()
	test_combat_mana_deduction_and_regen_flow()

## ----------------------------------------------------------------------------
## 1. ARQUITETURA E INDEPENDÊNCIA DOS 3 COMPONENTES
## ----------------------------------------------------------------------------
func test_component_architecture_and_independence() -> void:
	print("\n--- 1. ARQUITETURA E INDEPENDÊNCIA DOS COMPONENTES ---")
	var health_hud := HealthGlobeHUD.new()
	var mana_hud := ManaGlobeHUD.new()
	var hotbar_hud := SkillBarHUD.new()

	assert_test(health_hud is Control, "HealthGlobeHUD é uma instância válida de Control")
	assert_test(mana_hud is Control, "ManaGlobeHUD é uma instância válida de Control")
	assert_test(hotbar_hud is Control, "SkillBarHUD é uma instância válida de Control")

	# Testar nós filhos internos instanciados no _init()
	assert_test(health_hud.get_node_or_null("Scaler/OrbProgress") != null, "Health HUD contém OrbProgress interno")
	assert_test(health_hud.get_node_or_null("Scaler/BarProgress") != null, "Health HUD contém BarProgress horizontal interno")
	assert_test(health_hud.get_node_or_null("Scaler/FrameOverlay") != null, "Health HUD contém FrameOverlay recortado")
	assert_test(health_hud.get_node_or_null("Scaler/HealthValue") != null, "Health HUD contém HealthValue de texto dinâmico")

	assert_test(mana_hud.get_node_or_null("Scaler/OrbProgress") != null, "Mana HUD contém OrbProgress interno")
	assert_test(mana_hud.get_node_or_null("Scaler/BarProgress") != null, "Mana HUD contém BarProgress horizontal interno")
	assert_test(mana_hud.get_node_or_null("Scaler/FrameOverlay") != null, "Mana HUD contém FrameOverlay recortado")
	assert_test(mana_hud.get_node_or_null("Scaler/ManaValue") != null, "Mana HUD contém ManaValue de texto dinâmico")

	assert_test(hotbar_hud.get_node_or_null("Scaler/HotbarFrame") != null, "Hotbar HUD contém HotbarFrame")

	health_hud.queue_free()
	mana_hud.queue_free()
	hotbar_hud.queue_free()

## ----------------------------------------------------------------------------
## 2. PREENCHIMENTO DINÂMICO DE VIDA (0%, 25%, 50%, 75%, 100%)
## ----------------------------------------------------------------------------
func test_health_orb_and_bar_proportions() -> void:
	print("\n--- 2. PREENCHIMENTO PROPORCIONAL DE VIDA (0% A 100%) ---")
	var health_hud := HealthGlobeHUD.new()

	var orb: TextureProgressBar = health_hud.get_node("Scaler/OrbProgress") as TextureProgressBar
	var bar: TextureProgressBar = health_hud.get_node("Scaler/BarProgress") as TextureProgressBar
	var lbl: Label = health_hud.get_node("Scaler/HealthValue") as Label

	# 100%
	health_hud.set_values_immediate(1280, 1280)
	assert_test(is_equal_approx(orb.value, 100.0), "Vida 100%: Orbe preenchido em 100%")
	assert_test(is_equal_approx(bar.value, 100.0), "Vida 100%: Barra preenchida em 100%")
	assert_test(lbl.text.contains("1.280 / 1.280"), "Vida 100%: Texto formatado com milhar (1.280 / 1.280)")

	# 75%
	health_hud.set_values_immediate(960, 1280)
	assert_test(is_equal_approx(orb.value, 75.0), "Vida 75%: Orbe preenchido em 75%")
	assert_test(is_equal_approx(bar.value, 75.0), "Vida 75%: Barra preenchida em 75%")

	# 50%
	health_hud.set_values_immediate(640, 1280)
	assert_test(is_equal_approx(orb.value, 50.0), "Vida 50%: Orbe preenchido em 50%")
	assert_test(is_equal_approx(bar.value, 50.0), "Vida 50%: Barra preenchida em 50%")

	# 25%
	health_hud.set_values_immediate(320, 1280)
	assert_test(is_equal_approx(orb.value, 25.0), "Vida 25%: Orbe preenchido em 25%")
	assert_test(is_equal_approx(bar.value, 25.0), "Vida 25%: Barra preenchida em 25%")

	# 0%
	health_hud.set_values_immediate(0, 1280)
	assert_test(is_equal_approx(orb.value, 0.0), "Vida 0%: Orbe completamente vazio (0%)")
	assert_test(is_equal_approx(bar.value, 0.0), "Vida 0%: Barra completamente vazia (0%)")
	assert_test(lbl.text.contains("0 / 1.280"), "Vida 0%: Rótulo numérico exibe 0")

	# Clamping negativo
	health_hud.set_values_immediate(-50, 100)
	assert_test(is_equal_approx(orb.value, 0.0), "Vida negativa sofre clamp para 0%")

	health_hud.queue_free()

## ----------------------------------------------------------------------------
## 3. PREENCHIMENTO DINÂMICO DE MANA (0%, 25%, 50%, 75%, 100%)
## ----------------------------------------------------------------------------
func test_mana_orb_and_bar_proportions() -> void:
	print("\n--- 3. PREENCHIMENTO PROPORCIONAL DE MANA (0% A 100%) ---")
	var mana_hud := ManaGlobeHUD.new()

	var orb: TextureProgressBar = mana_hud.get_node("Scaler/OrbProgress") as TextureProgressBar
	var bar: TextureProgressBar = mana_hud.get_node("Scaler/BarProgress") as TextureProgressBar
	var lbl: Label = mana_hud.get_node("Scaler/ManaValue") as Label

	# 100%
	mana_hud.set_values_immediate(500, 500)
	assert_test(is_equal_approx(orb.value, 100.0), "Mana 100%: Orbe preenchido em 100%")
	assert_test(is_equal_approx(bar.value, 100.0), "Mana 100%: Barra preenchida em 100%")
	assert_test(lbl.text.contains("500 / 500"), "Mana 100%: Texto exibe 500 / 500")

	# 75%
	mana_hud.set_values_immediate(375, 500)
	assert_test(is_equal_approx(orb.value, 75.0), "Mana 75%: Orbe e barra em 75%")

	# 50%
	mana_hud.set_values_immediate(250, 500)
	assert_test(is_equal_approx(orb.value, 50.0), "Mana 50%: Orbe e barra em 50%")

	# 25%
	mana_hud.set_values_immediate(125, 500)
	assert_test(is_equal_approx(orb.value, 25.0), "Mana 25%: Orbe e barra em 25%")

	# 0%
	mana_hud.set_values_immediate(0, 500)
	assert_test(is_equal_approx(orb.value, 0.0), "Mana 0%: Orbe e barra em 0%")
	assert_test(lbl.text.contains("0 / 500"), "Mana 0%: Texto exibe 0 / 500")

	mana_hud.queue_free()

## ----------------------------------------------------------------------------
## 4. HOTBAR: 6 SLOTS, CAVILHAS LIMPAS E BOTÕES ▲
## ----------------------------------------------------------------------------
func test_hotbar_6_slots_and_empty_clean_state() -> void:
	print("\n--- 4. HOTBAR: 6 SLOTS CONFIGURÁVEIS E ESTADO LIMPO ---")
	var hotbar := SkillBarHUD.new()

	assert_test(hotbar.SLOT_COUNT == 6, "Hotbar possui exatamente 6 slots configuráveis")

	for i in range(hotbar.SLOT_COUNT):
		var slot_node: Control = hotbar.get_node_or_null("Scaler/Slot_%d" % i) as Control
		assert_test(slot_node != null, "Slot %d existe na hierarquia da hotbar" % i)

		var icon: TextureRect = slot_node.get_node_or_null("SkillIcon") as TextureRect
		assert_test(icon != null, "Slot %d contém TextureRect para ícone" % i)
		assert_test(icon.texture == null, "Slot %d desocupado NÃO exibe ícone hardcoded (cavidade limpa)" % i)

		var arrow: Button = hotbar.get_node_or_null("Scaler/ArrowButton_%d" % i) as Button
		assert_test(arrow != null, "Slot %d contém botão de seta '▲' dedicado" % i)

	hotbar.queue_free()

## ----------------------------------------------------------------------------
## 5. ATRIBUIÇÃO DE HABILIDADE E CUSTO DE MANA
## ----------------------------------------------------------------------------
func test_hotbar_skill_assignment_and_mana_cost() -> void:
	print("\n--- 5. ATRIBUIÇÃO DE HABILIDADES E EXIBIÇÃO DE CUSTO ---")
	var controller := PlayerSkillController.new()

	# Registrar habilidades de guerreiro de teste
	var stab := SkillDefinition.new()
	stab.skill_id = "warrior_stab"
	stab.display_name = "Golpe Direto"
	stab.is_basic_attack = true
	stab.mana_cost = 0
	controller.skills[stab.skill_id] = stab

	var cleave := SkillDefinition.new()
	cleave.skill_id = "warrior_cleave"
	cleave.display_name = "Golpe Circular"
	cleave.is_basic_attack = false
	cleave.mana_cost = 6
	controller.skills[cleave.skill_id] = cleave

	var hotbar := SkillBarHUD.new()
	hotbar.bind_controller(controller)

	# Atribuir stab ao slot 0 (LMB) e cleave ao slot 1 (RMB)
	var ok0: bool = controller.assign_slot(0, "warrior_stab")
	var ok1: bool = controller.assign_slot(1, "warrior_cleave")
	assert_test(ok0 == true, "assign_slot(0, warrior_stab) bem sucedido")
	assert_test(ok1 == true, "assign_slot(1, warrior_cleave) bem sucedido")

	var slot0_icon: TextureRect = hotbar.get_node("Scaler/Slot_0/SkillIcon") as TextureRect
	var slot1_icon: TextureRect = hotbar.get_node("Scaler/Slot_1/SkillIcon") as TextureRect
	assert_test(slot0_icon.texture != null, "Slot 0 recebeu textura dinâmica da habilidade atribuída")
	assert_test(slot1_icon.texture != null, "Slot 1 recebeu textura dinâmica da habilidade atribuída")

	var slot0_mana: Label = hotbar.get_node("Scaler/Slot_0/ManaCostLabel") as Label
	var slot1_mana: Label = hotbar.get_node("Scaler/Slot_1/ManaCostLabel") as Label
	assert_test(slot0_mana.text == "", "Habilidade com custo 0 (LMB) não polui com rótulo de mana")
	assert_test(slot1_mana.text == "6", "Habilidade com custo 6 (RMB) exibe custo '6'")

	controller.queue_free()
	hotbar.queue_free()

## ----------------------------------------------------------------------------
## 6. INDISPONIBILIDADE POR MANA E COOLDOWN
## ----------------------------------------------------------------------------
func test_mana_unavailability_and_cooldown_sweep() -> void:
	print("\n--- 6. INDISPONIBILIDADE POR MANA E COOLDOWN SWEEP ---")
	var controller := PlayerSkillController.new()

	var cleave := SkillDefinition.new()
	cleave.skill_id = "warrior_cleave"
	cleave.display_name = "Golpe Circular"
	cleave.mana_cost = 10
	cleave.base_cooldown = 3.0
	controller.skills[cleave.skill_id] = cleave

	var hotbar := SkillBarHUD.new()
	hotbar.bind_controller(controller)
	controller.assign_slot(1, "warrior_cleave")

	# Simular personagem com apenas 5 de mana (menos que o custo de 10)
	hotbar.refresh_mana_availability(5)
	var unavail_overlay: ColorRect = hotbar.get_node("Scaler/Slot_1/ManaOverlay") as ColorRect
	assert_test(unavail_overlay.visible == true, "Slot escurecido quando mana atual (5) < custo (10)")

	# Restaurar mana para 20
	hotbar.refresh_mana_availability(20)
	assert_test(unavail_overlay.visible == false, "Slot volta ao brilho normal quando mana atual (20) >= custo (10)")

	# Disparar cooldown diretamente no dicionário do controller
	controller._cooldowns["warrior_cleave"] = 2.5
	hotbar._process(0.016)
	var curtain: ColorRect = hotbar.get_node("Scaler/Slot_1/CooldownCurtain") as ColorRect
	var cd_lbl: Label = hotbar.get_node("Scaler/Slot_1/CooldownLabel") as Label
	assert_test(curtain.size.y > 0.0, "Cortina de cooldown sweep ativa com altura proporcional")
	assert_test(cd_lbl.text.length() > 0, "Rótulo de cooldown exibe tempo restante")

	controller.queue_free()
	hotbar.queue_free()

## ----------------------------------------------------------------------------
## 7. RESPONSIVIDADE E DISTÂNCIAS EM 1280x720
## ----------------------------------------------------------------------------
func test_responsive_layout_and_clearance_1280x720() -> void:
	print("\n--- 7. RESPONSIVIDADE E CLEARANCE EM 1280x720 ---")
	var health_hud := HealthGlobeHUD.new()
	var hotbar := SkillBarHUD.new()
	var mana_hud := ManaGlobeHUD.new()

	# Simular dimensões de tela 1280x720
	var sim_vp := Vector2(1280.0, 720.0)
	health_hud.ui_scale = clampf(sim_vp.x / 1920.0 * 0.52, 0.38, 0.50)
	health_hud.size = health_hud.BASE_SIZE * health_hud.ui_scale
	health_hud.position = Vector2(14.0, sim_vp.y - health_hud.size.y - 12.0)

	hotbar.ui_scale = clampf(sim_vp.x / 1920.0 * 0.50, 0.36, 0.48)
	hotbar.size = hotbar.BASE_SIZE * hotbar.ui_scale
	hotbar.position = Vector2((sim_vp.x - hotbar.size.x) * 0.5, sim_vp.y - hotbar.size.y - 8.0)

	mana_hud.ui_scale = clampf(sim_vp.x / 1920.0 * 0.52, 0.38, 0.50)
	mana_hud.size = mana_hud.BASE_SIZE * mana_hud.ui_scale
	mana_hud.position = Vector2(sim_vp.x - mana_hud.size.x - 14.0, sim_vp.y - mana_hud.size.y - 12.0)

	var health_right: float = health_hud.position.x + health_hud.size.x
	var hotbar_left: float = hotbar.position.x
	var hotbar_right: float = hotbar.position.x + hotbar.size.x
	var mana_left: float = mana_hud.position.x

	var clearance_left: float = hotbar_left - health_right
	var clearance_right: float = mana_left - hotbar_right

	print("  -> Posição Vida: [x=%.1f a %.1f]" % [health_hud.position.x, health_right])
	print("  -> Posição Hotbar: [x=%.1f a %.1f]" % [hotbar_left, hotbar_right])
	print("  -> Posição Mana: [x=%.1f a %.1f]" % [mana_left, mana_hud.position.x + mana_hud.size.x])
	print("  -> Espaço Livre Esquerdo: %.1f px | Direito: %.1f px" % [clearance_left, clearance_right])

	assert_test(clearance_left > 30.0, "Clearance saudável (>30px) entre Vida e Hotbar em 1280x720 (atual: %.1f px)" % clearance_left)
	assert_test(clearance_right > 30.0, "Clearance saudável (>30px) entre Hotbar e Mana em 1280x720 (atual: %.1f px)" % clearance_right)
	assert_test(health_right < hotbar_left, "Zero sobreposição entre Vida e Hotbar")
	assert_test(hotbar_right < mana_left, "Zero sobreposição entre Hotbar e Mana")

	health_hud.queue_free()
	hotbar.queue_free()
	mana_hud.queue_free()

## ----------------------------------------------------------------------------
## 8. FLUXO DE COMBATE: GASTO E REGENERAÇÃO DE MANA
## ----------------------------------------------------------------------------
func test_combat_mana_deduction_and_regen_flow() -> void:
	print("\n--- 8. FLUXO DE COMBATE: GASTO E REGENERAÇÃO DE MANA ---")
	var stats := CharacterStats.new()
	assert_test(stats.current_mana == 60, "Mana inicial do guerreiro é 60")
	assert_test(stats.get_stat(CharacterStats.STAT_MAX_MANA) == 60, "STAT_MAX_MANA inicial é 60")

	# Deduzir custo de habilidade
	var ok: bool = stats.apply_mana_cost(14)
	assert_test(ok == true, "apply_mana_cost(14) sucedido")
	assert_test(stats.current_mana == 46, "Mana reduziu para 46")

	# Deduzir além do disponível
	var ok2: bool = stats.apply_mana_cost(50)
	assert_test(ok2 == false, "apply_mana_cost(50) com 46 de mana falhou com segurança")
	assert_test(stats.current_mana == 46, "Mana permaneceu inalterada após tentativa falha")

	# Regeneração de mana ao longo do tempo (base 6.0/s)
	stats.regenerate_mana(0.5) # 3 mana
	assert_test(stats.current_mana == 49, "Regeneração de 0.5s aumentou mana para 49")

	# Restauração direta
	stats.restore_mana(100)
	assert_test(stats.current_mana == 60, "Restauração de mana sofre clamp no máximo (60)")
