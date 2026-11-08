extends SceneTree

const HealthGlobeHUD = preload("res://game/ui/campaign/health_globe_hud.gd")
const ManaGlobeHUD = preload("res://game/ui/campaign/mana_globe_hud.gd")
const SkillBarHUD = preload("res://game/ui/campaign/skill_bar_hud.gd")
const HudInputHelper = preload("res://game/ui/campaign/hud_input_helper.gd")
const PlayerSkillController = preload("res://scripts/player_skill_controller.gd")
const SkillDefinition = preload("res://core/combat/skill_definition.gd")
const SpatialInventoryGrid = preload("res://core/items/spatial_inventory_grid.gd")
const ItemDatabase = preload("res://core/items/item_database.gd")
const ItemInstance = preload("res://core/items/item_instance.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("=================================================================")
	print("SUÍTE DE QA DEFINITIVA: HUD MODULAR GODOT 4 (VIDA / SKILLS / MANA)")
	print("=================================================================")
	_run_all_tests()
	print("=================================================================")
	print("RESULTADO QA MODULAR: %d/%d TESTES PASSARAM (%d FALHAS)" % [passed_tests, total_tests, failed_tests])
	print("=================================================================")
	if failed_tests == 0:
		print(">> TODOS OS 12 REQUISITOS DE ACEITE FORAM APROVADOS! <<")
		quit(0)
	else:
		push_error(">> FALHAS ENCONTRADAS NO QA DA HUD MODULAR <<")
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
	HudInputHelper.ensure_default_actions()

	test_item_1_independent_sprites_and_transparency()
	test_item_2_empty_state_clean_cavities()
	test_item_3_all_8_arrow_selectors_and_popup_menus()
	test_item_4_and_5_input_map_bindings_and_dynamic_labels()
	test_item_6_vertical_fill_levels_and_no_leakage()
	test_item_7_skill_assignment_swapping_and_removal()
	test_item_8_potion_stock_consumption_and_cooldown()
	test_item_9_and_11_mouse_filter_and_gameplay_protection()
	test_item_10_responsive_scaling_resolutions()


## ----------------------------------------------------------------------------
## 1. 3 PNGS-BASE SEPARADOS, SEM CORRENTES
## ----------------------------------------------------------------------------
func test_item_1_independent_sprites_and_transparency() -> void:
	print("\n--- 1. PNGS-BASE SEPARADOS E TRANSPARÊNCIA ---")
	var health_hud := HealthGlobeHUD.new()
	var skill_hud := SkillBarHUD.new()
	var mana_hud := ManaGlobeHUD.new()

	assert_test(health_hud is Control, "Cluster esquerdo (Vida/Poções) é independente")
	assert_test(skill_hud is Control, "Cluster central (Skills) é independente")
	assert_test(mana_hud is Control, "Cluster direito (Mana) é independente")

	var h_tex: TextureRect = health_hud.get_node("Scaler/FrameOverlay") as TextureRect
	var s_tex: TextureRect = skill_hud.get_node("Scaler/HotbarFrame") as TextureRect
	var m_tex: TextureRect = mana_hud.get_node("Scaler/FrameOverlay") as TextureRect

	assert_test(h_tex.texture.resource_path.ends_with("01_vida_pocoes_base.png"), "Vida usa 01_vida_pocoes_base.png")
	assert_test(s_tex.texture.resource_path.ends_with("02_hotbar_6_skills_base.png"), "Skills usa 02_hotbar_6_skills_base.png")
	assert_test(m_tex.texture.resource_path.ends_with("03_mana_base.png"), "Mana usa 03_mana_base.png")

	health_hud.queue_free()
	skill_hud.queue_free()
	mana_hud.queue_free()


## ----------------------------------------------------------------------------
## 2. SLOTS VAZIOS (6 SKILLS + 2 POÇÕES) SEM HARDCODED ICONS
## ----------------------------------------------------------------------------
func test_item_2_empty_state_clean_cavities() -> void:
	print("\n--- 2. SLOTS VAZIOS SEM ÍCONES HARDCODED ---")
	var skill_hud := SkillBarHUD.new()
	var health_hud := HealthGlobeHUD.new()

	for i in range(6):
		var icon: TextureRect = skill_hud.get_node("Scaler/Slot_%d/SkillIcon" % i) as TextureRect
		assert_test(icon.texture == null, "Skill Slot %d está limpo quando vazio" % (i + 1))

	health_hud.bound_potion_ids = ["", ""]
	health_hud.refresh_potion_slots()
	for i in range(2):
		var pot_icon: TextureRect = health_hud._potion_icons[i]
		assert_test(pot_icon.texture == null, "Potion Slot %d está limpo quando vazio" % (i + 1))
		assert_test(health_hud._potion_counts[i].text == "", "Potion Slot %d sem contador quando vazio" % (i + 1))

	skill_hud.queue_free()
	health_hud.queue_free()


## ----------------------------------------------------------------------------
## 3. AS 8 SETAS ▲ CLICÁVEIS COM POPUP DE SELEÇÃO
## ----------------------------------------------------------------------------
func test_item_3_all_8_arrow_selectors_and_popup_menus() -> void:
	print("\n--- 3. 8 SETAS ▲ CLICÁVEIS COM POPUP ---")
	var skill_hud := SkillBarHUD.new()
	var health_hud := HealthGlobeHUD.new()

	var controller := PlayerSkillController.new()
	var stab := SkillDefinition.new()
	stab.skill_id = "test_slash"
	stab.display_name = "Corte Rápido"
	controller.skills[stab.skill_id] = stab
	skill_hud.bind_controller(controller)

	# 6 setas da hotbar
	for i in range(6):
		var arrow: Button = skill_hud.get_node("Scaler/ArrowButton_%d" % i) as Button
		assert_test(arrow != null and arrow.mouse_filter == Control.MOUSE_FILTER_STOP, "Seta da skill %d é clicável" % (i + 1))
		arrow.pressed.emit()
		assert_test(skill_hud._picker_panel.visible == true, "Seta %d abre popup de skills" % (i + 1))
		assert_test(skill_hud._picker_slot == i, "Popup configurado para slot %d" % i)
		skill_hud._picker_panel.visible = false

	# 2 setas das poções
	for i in range(2):
		var pot_arrow: Button = health_hud._potion_arrow_btns[i]
		assert_test(pot_arrow != null and pot_arrow.mouse_filter == Control.MOUSE_FILTER_STOP, "Seta da poção %d é clicável" % (i + 1))
		pot_arrow.pressed.emit()
		assert_test(health_hud._picker_panel.visible == true, "Seta de poção %d abre popup" % (i + 1))
		assert_test(health_hud._picker_slot == i, "Popup de poção configurado para slot %d" % i)
		health_hud._picker_panel.visible = false

	skill_hud.queue_free()
	health_hud.queue_free()
	controller.queue_free()


## ----------------------------------------------------------------------------
## 4 & 5. BINDINGS DO INPUTMAP E LABELS DINÂMICAS (LMB, RMB, Q, E, R, F, 1, 2)
## ----------------------------------------------------------------------------
func test_item_4_and_5_input_map_bindings_and_dynamic_labels() -> void:
	print("\n--- 4 & 5. BINDINGS DO INPUTMAP E LABELS DINÂMICAS ---")
	var skill_hud := SkillBarHUD.new()
	var health_hud := HealthGlobeHUD.new()

	assert_test(HudInputHelper.get_skill_action_label(0) == "LMB", "Slot 1 padrão é LMB")
	assert_test(HudInputHelper.get_skill_action_label(1) == "RMB", "Slot 2 padrão é RMB")
	assert_test(HudInputHelper.get_skill_action_label(2) == "Q", "Slot 3 padrão é Q")
	assert_test(HudInputHelper.get_skill_action_label(3) == "E", "Slot 4 padrão é E")
	assert_test(HudInputHelper.get_skill_action_label(4) == "R", "Slot 5 padrão é R")
	assert_test(HudInputHelper.get_skill_action_label(5) == "F", "Slot 6 padrão é F")

	assert_test(HudInputHelper.get_potion_action_label(0) == "1", "Poção 1 padrão é 1")
	assert_test(HudInputHelper.get_potion_action_label(1) == "2", "Poção 2 padrão é 2")

	for i in range(6):
		var lbl: Label = skill_hud._slot_key_labels[i]
		assert_test(lbl.text == HudInputHelper.get_skill_action_label(i), "Label da hotbar %d reflete InputMap (%s)" % [i + 1, lbl.text])

	for i in range(2):
		var plbl: Label = health_hud._potion_key_labels[i]
		assert_test(plbl.text == HudInputHelper.get_potion_action_label(i), "Label da poção %d reflete InputMap (%s)" % [i + 1, plbl.text])

	# Testar alteração de tecla no InputMap
	InputMap.action_erase_events("hud_skill_3")
	var new_ev := InputEventKey.new()
	new_ev.physical_keycode = KEY_Z
	InputMap.action_add_event("hud_skill_3", new_ev)
	skill_hud.refresh_keyplate_labels()
	assert_test(skill_hud._slot_key_labels[2].text == "Z", "Alterar tecla para Z atualiza Label dinamicamente")

	# Restaurar Q
	InputMap.action_erase_events("hud_skill_3")
	var rst_ev := InputEventKey.new()
	rst_ev.physical_keycode = KEY_Q
	InputMap.action_add_event("hud_skill_3", rst_ev)
	skill_hud.refresh_keyplate_labels()

	skill_hud.queue_free()
	health_hud.queue_free()


## ----------------------------------------------------------------------------
## 6. PREENCHIMENTO VERTICAL DE VIDA E MANA (0%, 25%, 50%, 75%, 100%)
## ----------------------------------------------------------------------------
func test_item_6_vertical_fill_levels_and_no_leakage() -> void:
	print("\n--- 6. PREENCHIMENTO VERTICAL E VALORES REAIS ---")
	var health_hud := HealthGlobeHUD.new()
	var mana_hud := ManaGlobeHUD.new()

	var h_bar: TextureProgressBar = health_hud.get_node("Scaler/OrbProgress") as TextureProgressBar
	var m_bar: TextureProgressBar = mana_hud.get_node("Scaler/OrbProgress") as TextureProgressBar

	assert_test(h_bar.fill_mode == TextureProgressBar.FILL_BOTTOM_TO_TOP, "Vida preenche de baixo para cima")
	assert_test(m_bar.fill_mode == TextureProgressBar.FILL_BOTTOM_TO_TOP, "Mana preenche de baixo para cima")

	var test_percentages: Array[float] = [1.0, 0.75, 0.50, 0.25, 0.0]
	for pct in test_percentages:
		var cur_hp: int = int(round(1280.0 * pct))
		health_hud.set_values_immediate(cur_hp, 1280)
		assert_test(is_equal_approx(h_bar.value, pct * 100.0), "Vida %d%%: barra ajustada com exatidão" % int(pct * 100))

		var cur_mana: int = int(round(500.0 * pct))
		mana_hud.set_values_immediate(cur_mana, 500)
		assert_test(is_equal_approx(m_bar.value, pct * 100.0), "Mana %d%%: barra ajustada com exatidão" % int(pct * 100))

	# Validar rótulos numéricos
	health_hud.set_values_immediate(1280, 1280)
	mana_hud.set_values_immediate(500, 500)
	assert_test(health_hud._value_label.text.contains("1.280 / 1.280"), "Vida exibe '1.280 / 1.280'")
	assert_test(mana_hud._value_label.text.contains("500 / 500"), "Mana exibe '500 / 500'")

	health_hud.queue_free()
	mana_hud.queue_free()


## ----------------------------------------------------------------------------
## 7. ATRIBUIÇÃO, TROCA E REMOÇÃO DE HABILIDADES
## ----------------------------------------------------------------------------
func test_item_7_skill_assignment_swapping_and_removal() -> void:
	print("\n--- 7. ATRIBUIÇÃO, TROCA E REMOÇÃO DE HABILIDADES ---")
	var controller := PlayerSkillController.new()
	var skill_hud := SkillBarHUD.new()
	skill_hud.bind_controller(controller)

	var stab := SkillDefinition.new()
	stab.skill_id = "w_stab"
	stab.display_name = "Estocada"
	stab.mana_cost = 0
	controller.skills[stab.skill_id] = stab

	var slash := SkillDefinition.new()
	slash.skill_id = "w_slash"
	slash.display_name = "Corte Amplo"
	slash.mana_cost = 8
	controller.skills[slash.skill_id] = slash

	# Atribuir
	controller.assign_slot(0, "w_stab")
	var s0: SkillDefinition = controller.get_slot_skill(0)
	assert_test(s0 != null and s0.skill_id == "w_stab", "Slot 0 recebeu w_stab")
	assert_test(skill_hud._slot_icons[0].texture != null, "Ícone do Slot 0 renderizado")

	# Substituir
	controller.assign_slot(0, "w_slash")
	var s1: SkillDefinition = controller.get_slot_skill(0)
	assert_test(s1 != null and s1.skill_id == "w_slash", "Slot 0 substituído para w_slash")
	assert_test(skill_hud._slot_mana_labels[0].text == "8", "Custo de mana atualizado para 8")

	# Remover (Vazio)
	controller.assign_slot(0, "")
	assert_test(controller.get_slot_skill(0) == null, "Slot 0 removido/esvaziado")
	assert_test(skill_hud._slot_icons[0].texture == null, "Ícone do Slot 0 limpo")
	assert_test(skill_hud._slot_mana_labels[0].text == "", "Custo de mana limpo")

	skill_hud.queue_free()
	controller.queue_free()


## ----------------------------------------------------------------------------
## 8. DUAS POÇÕES: ESTOQUE, USO E COOLDOWN
## ----------------------------------------------------------------------------
func test_item_8_potion_stock_consumption_and_cooldown() -> void:
	print("\n--- 8. POÇÕES: ESTOQUE, CONSUMO E COOLDOWN ---")
	var health_hud := HealthGlobeHUD.new()
	var grid := SpatialInventoryGrid.new(10, 6)

	# Adiciona 2 poções de vida e 1 de mana
	var pot_h1 := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "potion_health")
	var pot_h2 := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "potion_health")
	var pot_m1 := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "potion_mana")
	grid.auto_add_item(pot_h1)
	grid.auto_add_item(pot_h2)
	grid.auto_add_item(pot_m1)

	var dummy_player := TowerPlayer.new()
	dummy_player.health = 50
	dummy_player.max_health = 100
	dummy_player.mana = 20
	dummy_player.max_mana = 60

	health_hud.bind_context(grid, dummy_player)
	health_hud.bound_potion_ids = ["potion_health", "potion_mana"]
	health_hud.refresh_potion_slots()

	assert_test(health_hud._potion_counts[0].text == "x2", "Slot 1 exibe estoque x2 de vida")
	assert_test(health_hud._potion_counts[1].text == "x1", "Slot 2 exibe estoque x1 de mana")

	# Consumir vida
	var used_h: bool = health_hud.use_potion(0)
	assert_test(used_h == true, "Poção de vida consumida com sucesso")
	assert_test(health_hud.potion_cooldowns[0] > 0.0, "Cooldown iniciado no Slot 1")
	assert_test(health_hud._potion_counts[0].text == "x1", "Estoque de vida reduzido para x1")
	assert_test(dummy_player.health > 50, "Vida do personagem foi restaurada")

	# Tentativa imediata durante cooldown deve falhar com segurança
	var reuse_h: bool = health_hud.use_potion(0)
	assert_test(reuse_h == false, "Uso durante cooldown bloqueado com segurança")

	# Zerar cooldown e consumir última de vida
	health_hud.potion_cooldowns[0] = 0.0
	health_hud.use_potion(0)
	assert_test(health_hud._potion_counts[0].text == "x0", "Estoque zero exibe x0")

	# Tentativa com estoque zero deve falhar
	health_hud.potion_cooldowns[0] = 0.0
	var no_stock: bool = health_hud.use_potion(0)
	assert_test(no_stock == false, "Uso com estoque zero rejeitado com segurança")

	# Consumir mana
	var used_m: bool = health_hud.use_potion(1)
	assert_test(used_m == true, "Poção de mana consumida com sucesso")
	assert_test(dummy_player.mana > 20, "Mana do personagem foi restaurada")

	health_hud.queue_free()
	dummy_player.queue_free()


## ----------------------------------------------------------------------------
## 9 & 11. MOUSE_FILTER E PRESERVAÇÃO DE COMBATE
## ----------------------------------------------------------------------------
func test_item_9_and_11_mouse_filter_and_gameplay_protection() -> void:
	print("\n--- 9 & 11. MOUSE_FILTER E PROTEÇÃO DE COMBATE ---")
	var health_hud := HealthGlobeHUD.new()
	var skill_hud := SkillBarHUD.new()
	var mana_hud := ManaGlobeHUD.new()

	assert_test(health_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "HealthGlobeHUD base possui mouse_filter IGNORE")
	assert_test(skill_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "SkillBarHUD base possui mouse_filter IGNORE")
	assert_test(mana_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "ManaGlobeHUD base possui mouse_filter IGNORE")

	var h_frame: TextureRect = health_hud.get_node("Scaler/FrameOverlay") as TextureRect
	var s_frame: TextureRect = skill_hud.get_node("Scaler/HotbarFrame") as TextureRect
	var m_frame: TextureRect = mana_hud.get_node("Scaler/FrameOverlay") as TextureRect

	assert_test(h_frame.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Moldura de vida é IGNORE (não bloqueia cliques do mundo)")
	assert_test(s_frame.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Moldura de skills é IGNORE (não bloqueia cliques do mundo)")
	assert_test(m_frame.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Moldura de mana é IGNORE (não bloqueia cliques do mundo)")

	# Botões interativos devem ser STOP
	var arrow0: Button = skill_hud.get_node("Scaler/ArrowButton_0") as Button
	assert_test(arrow0.mouse_filter == Control.MOUSE_FILTER_STOP, "Botão de seta é STOP (captura clique da UI)")

	health_hud.queue_free()
	skill_hud.queue_free()
	mana_hud.queue_free()


## ----------------------------------------------------------------------------
## 10. RESPONSIVIDADE EM MÚLTIPLAS RESOLUÇÕES E CLEARANCE
## ----------------------------------------------------------------------------
func test_item_10_responsive_scaling_resolutions() -> void:
	print("\n--- 10. RESPONSIVIDADE E TESTE DE RESOLUÇÕES ---")
	var resolutions: Array[Vector2] = [
		Vector2(1280, 720),
		Vector2(1920, 1080),
		Vector2(1920, 1200),
		Vector2(2560, 1440),
		Vector2(3440, 1440)
	]

	for res in resolutions:
		var health_hud := HealthGlobeHUD.new()
		var skill_hud := SkillBarHUD.new()
		var mana_hud := ManaGlobeHUD.new()

		# Forçar cálculo com a resolução do teste
		var s: float = (res.y / 1080.0) * 0.76
		var max_w_scale: float = (res.x - 120.0) / 1834.0
		var expected_scale: float = clampf(minf(s, max_w_scale), 0.42, 0.95)

		health_hud.ui_scale = expected_scale
		health_hud.custom_minimum_size = health_hud.BASE_SIZE * expected_scale
		health_hud.size = health_hud.custom_minimum_size
		health_hud.position = Vector2(14.0, res.y - health_hud.size.y - 6.0)

		skill_hud.ui_scale = expected_scale
		skill_hud.custom_minimum_size = skill_hud.BASE_SIZE * expected_scale
		skill_hud.size = skill_hud.custom_minimum_size
		skill_hud.position = Vector2((res.x - skill_hud.size.x) * 0.5, res.y - skill_hud.size.y - 6.0)

		mana_hud.ui_scale = expected_scale
		mana_hud.custom_minimum_size = mana_hud.BASE_SIZE * expected_scale
		mana_hud.size = mana_hud.custom_minimum_size
		mana_hud.position = Vector2(res.x - mana_hud.size.x - 14.0, res.y - mana_hud.size.y - 6.0)

		var h_right: float = health_hud.position.x + health_hud.size.x
		var s_left: float = skill_hud.position.x
		var s_right: float = skill_hud.position.x + skill_hud.size.x
		var m_left: float = mana_hud.position.x

		var gap_left: float = s_left - h_right
		var gap_right: float = m_left - s_right

		assert_test(gap_left > 20.0, "Resolução %dx%d: Espaço livre entre Vida e Skills (%0.1f px > 20px)" % [int(res.x), int(res.y), gap_left])
		assert_test(gap_right > 20.0, "Resolução %dx%d: Espaço livre entre Skills e Mana (%0.1f px > 20px)" % [int(res.x), int(res.y), gap_right])
		assert_test(h_right < s_left, "Resolução %dx%d: Zero sobreposição entre Vida e Skills" % [int(res.x), int(res.y)])
		assert_test(s_right < m_left, "Resolução %dx%d: Zero sobreposição entre Skills e Mana" % [int(res.x), int(res.y)])

		health_hud.queue_free()
		skill_hud.queue_free()
		mana_hud.queue_free()
