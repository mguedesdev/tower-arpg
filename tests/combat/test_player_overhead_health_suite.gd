extends SceneTree
## ============================================================================
## SUÍTE DE QA: BARRA DE VIDA OVERHEAD DO PLAYER (ARPG DARK FANTASY GODOT 4)
## Valida integridade visual (shader PBR, moldura gótica, notches, degradê rubi,
## ghost trail, números de HP), reatividade instantânea com o Player, cura e dano.
## ============================================================================

const PlayerScript = preload("res://scripts/player.gd")
const OverheadHUDScript = preload("res://core/combat/player_overhead_hud_3d.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("\n=================================================================")
	print("SUÍTE DE QA: BARRA DE VIDA OVERHEAD DO PLAYER (ARPG GODOT 4)")
	print("=================================================================\n")
	_run_suite()


func _run_suite() -> void:
	await _run_all_tests()
	_print_summary()
	quit(0 if failed_tests == 0 else 1)


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % test_name)


func _run_all_tests() -> void:
	await _test_01_component_structure_and_shader()
	await _test_02_player_initial_synchronization()
	await _test_03_damage_reaction_and_ghost_trail()
	await _test_04_healing_and_full_recovery()
	await _test_05_max_health_scaling_and_equipment()
	await _test_06_critical_health_pulse()
	await _test_07_death_and_zero_health()


func _test_01_component_structure_and_shader() -> void:
	print("--- 1. ESTRUTURA VISUAL E SHADER ESTILIZADO (DARK FANTASY) ---")

	var hud: PlayerOverheadHUD3D = OverheadHUDScript.new()
	root.add_child(hud)
	await process_frame

	assert_test(hud != null, "PlayerOverheadHUD3D instanciado com sucesso")
	assert_test(hud._shader_mat != null, "ShaderMaterial instanciado no HUD")
	assert_test(hud._shader_mat.shader != null, "Shader 'player_health_bar_3d.gdshader' vinculado e compilado")
	assert_test(hud._bar_mesh_node != null, "Nó MeshInstance3D da barra existe")
	assert_test(hud._name_label != null, "Label3D de Nome do Herói existe")
	assert_test(hud._name_label.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Nome do herói possui BILLBOARD_ENABLED")
	assert_test(hud._hp_label != null, "Label3D de números de HP existe")
	assert_test(hud._hp_label.billboard == BaseMaterial3D.BILLBOARD_ENABLED, "Texto de HP possui BILLBOARD_ENABLED")

	hud.queue_free()
	await process_frame


func _test_02_player_initial_synchronization() -> void:
	print("\n--- 2. SINCRONIZAÇÃO INICIAL COM O PERSONAGEM ---")

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	assert_test(player_scene != null, "Cena do Player carregada com sucesso")

	var player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	assert_test(player.overhead_hud != null, "OverheadHUD anexado automaticamente ao Player")
	assert_test(player.overhead_hud.is_inside_tree(), "OverheadHUD ativo na árvore de cena")
	assert_test(player.overhead_hud._current_health == player.health, "Vida na barra (%d) é idêntica à vida do player (%d)" % [player.overhead_hud._current_health, player.health])
	assert_test(player.overhead_hud._maximum_health == player.max_health, "Vida máxima na barra (%d) é idêntica ao max_health (%d)" % [player.overhead_hud._maximum_health, player.max_health])
	assert_test(is_equal_approx(player.overhead_hud._target_ratio, 1.0), "Proporção inicial está 100% cheia (ratio: 1.0)")
	assert_test(player.overhead_hud._hp_label.text == "%d / %d" % [player.health, player.max_health], "Texto numérico reflete exata saúde: '%s'" % player.overhead_hud._hp_label.text)

	player.queue_free()
	await process_frame


func _test_03_damage_reaction_and_ghost_trail() -> void:
	print("\n--- 3. REAÇÃO A DANO E RASTRO DE DANO (GHOST TRAIL) ---")

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	var initial_hp: int = player.health
	player.take_damage(35)

	assert_test(player.health < initial_hp, "Player sofreu dano (HP atual: %d)" % player.health)
	assert_test(player.overhead_hud._current_health == player.health, "OverheadHUD sincronizou instantaneamente no dano (HP: %d)" % player.overhead_hud._current_health)
	assert_test(player.overhead_hud._target_ratio < 1.0, "Proporção da barra diminuiu com o dano (ratio: %.2f)" % player.overhead_hud._target_ratio)
	assert_test(player.overhead_hud._trail_ratio >= player.overhead_hud._target_ratio, "Rastro âmbar (trail: %.2f) permanece acima da vida alvo (%.2f) para feedback tátil de impacto" % [player.overhead_hud._trail_ratio, player.overhead_hud._target_ratio])
	assert_test(player.overhead_hud._hp_label.text == "%d / %d" % [player.health, player.max_health], "Texto numérico atualizado: '%s'" % player.overhead_hud._hp_label.text)

	# Simula avanço de tempo para o rastro alcançar a barra
	player.overhead_hud._process(1.5)
	assert_test(is_equal_approx(player.overhead_hud._trail_ratio, player.overhead_hud._target_ratio), "Rastro de dano drena suavemente e alcança a vida atual")

	player.queue_free()
	await process_frame


func _test_04_healing_and_full_recovery() -> void:
	print("\n--- 4. CURA REATIVA E RECARGA TOTAL ---")

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	player.take_damage(50)
	var damaged_hp: int = player.health

	# Cura via método heal
	player.heal(25)
	assert_test(player.health == damaged_hp + 25, "Player curado com sucesso (HP: %d)" % player.health)
	assert_test(player.overhead_hud._current_health == player.health, "OverheadHUD reflete cura imediatamente (HP: %d)" % player.overhead_hud._current_health)
	assert_test(player.overhead_hud._trail_ratio == player.overhead_hud._target_ratio, "Rastro acompanha a cura instantaneamente sem artefatos de defasagem")

	# Cura total (ex: Vila segura / Poço)
	player.health = player.max_health
	assert_test(player.health == player.max_health, "Vida restaurada a 100%")
	assert_test(player.overhead_hud._current_health == player.max_health, "OverheadHUD registra 100% no reset de vida da Vila")
	assert_test(is_equal_approx(player.overhead_hud._target_ratio, 1.0), "Proporção da barra totalmente preenchida (1.0)")
	assert_test(player.overhead_hud._hp_label.text == "%d / %d" % [player.max_health, player.max_health], "Texto numérico exibe 100%% cheia: '%s'" % player.overhead_hud._hp_label.text)

	player.queue_free()
	await process_frame


func _test_05_max_health_scaling_and_equipment() -> void:
	print("\n--- 5. ESCALONAMENTO DE VIDA MÁXIMA & EQUIPAMENTOS ---")

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	# Simula aumento de vida máxima por armadura peitoral (+40 HP -> 140)
	player.max_health = 140
	assert_test(player.max_health == 140, "Vida máxima aumentada para 140")
	assert_test(player.overhead_hud._maximum_health == 140, "OverheadHUD atualizou teto para 140")

	# Define vida parcial (70 / 140 = 50%)
	player.health = 70
	var expected_ratio: float = 70.0 / 140.0
	assert_test(is_equal_approx(player.overhead_hud._target_ratio, expected_ratio), "Proporção calcula com exatidão matemática (esperado: %.4f, obtido: %.4f)" % [expected_ratio, player.overhead_hud._target_ratio])
	assert_test(player.overhead_hud._hp_label.text == "70 / 140", "Texto numérico reflete exato '70 / 140'")

	# Cura completa na vila para 140/140
	player.health = 140
	assert_test(is_equal_approx(player.overhead_hud._target_ratio, 1.0), "Barra em 140/140 fica 100% cheia e alinhada com a HUD (ratio 1.0)")
	assert_test(player.overhead_hud._hp_label.text == "140 / 140", "Texto numérico reflete exato '140 / 140'")

	player.queue_free()
	await process_frame


func _test_06_critical_health_pulse() -> void:
	print("\n--- 6. PULSO DE ALERTA PARA VIDA CRÍTICA (< 25%) ---")

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	player.max_health = 100
	player.health = 15 # 15% < 25%

	assert_test(player.overhead_hud._target_ratio < 0.25, "Vida está em nível crítico (15%)")
	player.overhead_hud._process(0.2)

	var pulse: float = float(player.overhead_hud._shader_mat.get_shader_parameter("pulse_intensity"))
	assert_test(pulse >= 0.0 and pulse <= 1.0, "Pulso de alerta do shader operando suavemente no intervalo [0, 1] (obtido: %.2f)" % pulse)

	# Ao curar para > 25%, pulso cessa
	player.health = 50
	player.overhead_hud._process(0.01)
	var pulse_off: float = float(player.overhead_hud._shader_mat.get_shader_parameter("pulse_intensity"))
	assert_test(is_equal_approx(pulse_off, 0.0), "Pulso de alerta desativado imediatamente quando HP >= 25%")

	player.queue_free()
	await process_frame


func _test_07_death_and_zero_health() -> void:
	print("\n--- 7. MORTE E COMPORTAMENTO COM HP ZERO ---")

	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player: CharacterBody3D = player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame

	player.take_damage(9999)

	assert_test(player.health == 0, "Vida do player é 0")
	assert_test(player.overhead_hud._current_health == 0, "OverheadHUD registra 0")
	assert_test(is_equal_approx(player.overhead_hud._target_ratio, 0.0), "Proporção visual é zero (vazia)")
	assert_test(player.overhead_hud._hp_label.text == "0 / %d" % player.max_health, "Texto numérico exibe '0 / %d'" % player.max_health)

	player.queue_free()
	await process_frame


func _print_summary() -> void:
	print("\n=================================================================")
	print("RESULTADO QA BARRA OVERHEAD: %d/%d PASSARAM (%d FALHAS)" % [passed_tests, total_tests, failed_tests])
	print("=================================================================")
	if failed_tests == 0:
		print(">> TODOS OS REQUISITOS DA BARRA OVERHEAD FORAM APROVADOS! <<\n")
	else:
		printerr(">> HOUVE FALHAS NA VALIDAÇÃO DA BARRA OVERHEAD! <<\n")
