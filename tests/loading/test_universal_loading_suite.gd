extends SceneTree

const GAME_SCENE_PATH := "res://scenes/arpg/arpg_game.tscn"
const LoadingManagerScript = preload("res://core/loading/loading_manager.gd")
const PipelineWarmupServiceScript = preload("res://core/loading/pipeline_warmup_service.gd")

var _passed: int = 0
var _failed: int = 0

func _init() -> void:
	call_deferred("_run_all_tests")


func _assert_test(cond: bool, test_name: String) -> void:
	if cond:
		_passed += 1
		print("  [PASS] %s" % test_name)
	else:
		_failed += 1
		push_error("  [FAIL] %s" % test_name)


func _run_all_tests() -> void:
	print("\n=================================================================")
	print("SUÍTE DE QA: SISTEMA UNIVERSAL DE LOADING & CARREGAMENTO (ARPG)")
	print("=================================================================\n")

	var root_vp := get_root()

	# -------------------------------------------------------------------------
	# 1. ESTRUTURA E DISPONIBILIDADE DO LOADING MANAGER & LOADING SCREEN
	# -------------------------------------------------------------------------
	print("--- 1. SINGLETON / AUTOLOAD & TELA DE LOADING ---")
	var lm: Node = LoadingManagerScript.get_instance()
	_assert_test(lm != null, "LoadingManager instance está disponível e inicializado")
	_assert_test(is_instance_valid(lm), "LoadingManager é uma instância válida na SceneTree")

	var screen = lm.get("_screen")
	_assert_test(screen != null, "LoadingScreen criada como filha do LoadingManager")
	_assert_test(screen is CanvasLayer, "LoadingScreen é um CanvasLayer")
	_assert_test((screen as CanvasLayer).layer >= 100, "LoadingScreen opera em layer >= 100 (sobrepõe HUD e 3D)")

	var root_ctrl: Control = screen.get("_root_control") as Control
	_assert_test(root_ctrl != null, "Control raiz da tela de loading existe")
	_assert_test(root_ctrl.mouse_filter == Control.MOUSE_FILTER_STOP, "Tela de loading bloqueia inputs do mouse (MOUSE_FILTER_STOP)")

	var title_lbl: Label = screen.get("_title_label") as Label
	var bar_fill: Panel = screen.get("_progress_bar_fill") as Panel
	var percent_lbl: Label = screen.get("_percent_label") as Label
	_assert_test(title_lbl != null and bar_fill != null and percent_lbl != null, "Elementos visuais (Título, Barra, Porcentagem) existem")

	# -------------------------------------------------------------------------
	# 2. MAPEAMENTO DE ILUSTRAÇÕES REGIONAIS OFICIAIS
	# -------------------------------------------------------------------------
	print("\n--- 2. MAPEAMENTO DE ILUSTRAÇÕES REGIONAIS DO MAPA ---")
	var icon_town: String = LoadingManagerScript.get_zone_icon_path("town")
	var icon_arath: String = LoadingManagerScript.get_zone_icon_path("zone_1_road")
	var icon_mines: String = LoadingManagerScript.get_zone_icon_path("zone_4_mines")
	_assert_test(ResourceLoader.exists(icon_town), "Ícone regional da Vila de Velen existe (%s)" % icon_town)
	_assert_test(ResourceLoader.exists(icon_arath), "Ícone regional da Floresta de Arath existe (%s)" % icon_arath)
	_assert_test(ResourceLoader.exists(icon_mines), "Ícone regional das Minas de Karpon existe (%s)" % icon_mines)

	# -------------------------------------------------------------------------
	# 3. TRANSIÇÃO DE REGIÃO IN-GAME (VILA -> FLORESTA DE ARATH)
	# -------------------------------------------------------------------------
	print("\n--- 3. TRANSIÇÃO DE REGIÃO COM TELA DE LOADING (Vila -> Floresta) ---")
	var game_scene := load(GAME_SCENE_PATH) as PackedScene
	_assert_test(game_scene != null, "Cena do jogo ARPG carregada com sucesso")

	var game: Node = game_scene.instantiate()
	root_vp.add_child(game)

	# Inicializa em town
	game.call("load_zone", "town", null, false)
	for _f in range(4):
		await process_frame

	var player = game.get("player")
	_assert_test(player != null, "Jogador instanciado no jogo")
	player.health = 85 # Define HP para testar integridade de persistência

	# Executa transição via LoadingManager para Floresta de Arath
	var start_ms: int = Time.get_ticks_msec()
	var step_events: Array[String] = []

	var on_progress := func(step: String, p: float) -> void:
		step_events.append("%s (%.0f%%)" % [step, p * 100.0])

	lm.transition_progress.connect(on_progress)

	# Inicia transição assíncrona com tela de loading
	lm.transition_to_region(game, "zone_1_road", null)

	# Verifica se player está bloqueado durante o loading
	_assert_test(lm.is_loading() == true, "LoadingManager reporta is_loading() == true durante transição")
	_assert_test(player.get("input_enabled") == false, "Player input_enabled é desativado durante loading")

	# Aguarda conclusão
	while lm.is_loading():
		await process_frame

	var duration_ms: int = Time.get_ticks_msec() - start_ms
	lm.transition_progress.disconnect(on_progress)

	print("  [INFO] Transição para Floresta de Arath concluída em %d ms." % duration_ms)
	_assert_test(game.get("current_zone_id") == "zone_1_road", "Zona atual atualizada para 'zone_1_road'")
	_assert_test(player.get("input_enabled") == true, "Player input_enabled restaurado para true ao concluir")
	_assert_test(player.health == 85, "Vida do jogador preservada com integridade (85 HP)")
	_assert_test(step_events.size() >= 3, "Múltiplas etapas de progresso reportadas de forma transparente")

	# Verifica se o spawn é o da Floresta de Arath (+Z)
	_assert_test(player.global_position.z > 10.0, "Player posicionado no spawn correto da Floresta de Arath (Z=%.2f)" % player.global_position.z)

	# -------------------------------------------------------------------------
	# 4. TRANSIÇÃO POR WAYPOINT ANCESTRAL
	# -------------------------------------------------------------------------
	print("\n--- 4. TELEPORTE POR WAYPOINT (Floresta -> Ruínas Antigas) ---")
	var wp_status := {"started": false, "completed": false}

	var on_wp_start := func(id: String) -> void: wp_status["started"] = true
	var on_wp_done := func(id: String) -> void: wp_status["completed"] = true

	lm.transition_started.connect(on_wp_start)
	lm.transition_completed.connect(on_wp_done)

	game.call("_on_waypoint_travel_requested", "zone_2_woods")

	while lm.is_loading():
		await process_frame

	lm.transition_started.disconnect(on_wp_start)
	lm.transition_completed.disconnect(on_wp_done)

	_assert_test(wp_status["started"] == true, "Sinal transition_started disparado no Waypoint")
	_assert_test(wp_status["completed"] == true, "Sinal transition_completed disparado no Waypoint")
	_assert_test(game.get("current_zone_id") == "zone_2_woods", "Zona atualizada para 'zone_2_woods'")

	# -------------------------------------------------------------------------
	# 5. TRANSIÇÃO POR PORTAL DE ZONA (RETORNO À VILA)
	# -------------------------------------------------------------------------
	print("\n--- 5. TRANSIÇÃO POR PORTAL DE ZONA (Ruínas -> Vila) ---")
	game.call("_on_zone_gate_crossed", "town", "zone_2_woods")

	while lm.is_loading():
		await process_frame

	_assert_test(game.get("current_zone_id") == "town", "Retorno à Vila Segura com sucesso")
	_assert_test(player.health == player.max_health, "Vida restaurada a 100%% na Vila Segura conforme regra de design")

	# -------------------------------------------------------------------------
	# 6. REJEIÇÃO SEGURA DE TRANSIÇÕES CONCORRENTES / SIMULTÂNEAS
	# -------------------------------------------------------------------------
	print("\n--- 6. REJEIÇÃO DE TRANSIÇÕES SIMULTÂNEAS ---")
	lm.transition_to_region(game, "zone_1_road", null)
	_assert_test(lm.is_loading() == true, "Primeira transição iniciada")

	# Tenta disparar outra transição concorrente enquanto a primeira está ativa
	lm.transition_to_region(game, "zone_3_crypt", null)

	while lm.is_loading():
		await process_frame

	_assert_test(game.get("current_zone_id") == "zone_1_road", "Segunda transição concorrente foi bloqueada com segurança (permaneceu em zone_1_road)")

	# -------------------------------------------------------------------------
	# 7. TRATAMENTO DE ERRO COM ZONA INEXISTENTE
	# -------------------------------------------------------------------------
	print("\n--- 7. TRATAMENTO DE ERROS & RECUPERAÇÃO SEGURA ---")
	var err_status := {"received": false}
	var on_err := func(dest: String, msg: String) -> void: err_status["received"] = true
	lm.transition_failed.connect(on_err)

	lm.transition_to_region(game, "zona_fantasma_inexistente_999", null)

	while lm.is_loading():
		await process_frame

	lm.transition_failed.disconnect(on_err)
	_assert_test(err_status["received"] == true, "Falha em zona inválida capturada com sinal transition_failed")
	_assert_test(lm.get_last_error().contains("não cadastrada"), "Mensagem técnica de erro registrada corretamente")
	_assert_test(game.get("current_zone_id") == "zone_1_road", "Estado do jogo permaneceu seguro na zona válida anterior")

	# -------------------------------------------------------------------------
	# 8. PRÉ-AQUECIMENTO DE PIPELINES GRÁFICOS (COMPILER WARMUP)
	# -------------------------------------------------------------------------
	print("\n--- 8. AQUECIMENTO DE PIPELINES GRÁFICOS & SHADERS ---")
	var warm_service = PipelineWarmupServiceScript.new()
	_assert_test(warm_service != null, "PipelineWarmupService instanciado com sucesso")

	var nodes_before: int = root_vp.get_child_count()
	await PipelineWarmupServiceScript.warm_up_pipelines(self, "zone_1_road")
	var nodes_after: int = root_vp.get_child_count()
	_assert_test(nodes_before == nodes_after, "PipelineWarmupService limpou seu SubViewport temporário sem vazamento de nós na SceneTree")

	# -------------------------------------------------------------------------
	# CONCLUSÃO
	# -------------------------------------------------------------------------
	print("\n=================================================================")
	print("RESULTADO QA LOADING: %d PASSARAM | %d FALHARAM" % [_passed, _failed])
	print("=================================================================\n")

	game.queue_free()
	for _f in range(2):
		await process_frame

	if _failed == 0:
		print(">> TODOS OS REQUISITOS DO SISTEMA UNIVERSAL DE LOADING FORAM APROVADOS! <<\n")
		quit(0)
	else:
		push_error(">> HOUVE FALHAS NA VALIDAÇÃO DO LOADING! <<")
		quit(1)
