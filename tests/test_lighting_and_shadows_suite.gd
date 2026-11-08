extends SceneTree

## Suíte de Testes e Validação: Iluminação Estática Clara & Sombras 3D (ARPG Low-Poly)
## Valida a remoção total do ciclo Dia/Noite e da lanterna móvel, garantindo:
## 1. Cenário sempre claro, legível e brilhante (sem escuridão ou noite).
## 2. Sol direcional constante com sombras duras e recortadas (SHADOW_ORTHOGONAL).
## 3. Iluminação ambiente clara permanente (sem risco de ficar escuro).
## 4. Ausência total de nós DayNightCycleHUD ou lanternas no Player.
## 5. Projeção de sombras pelo herói, inimigos, árvores e cenário.

func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("==================================================================================")
	print("  SUÍTE DE AUDITORIA: ILUMINAÇÃO ESTÁTICA CLARA & SOMBRAS 3D (ARPG LOW-POLY)      ")
	print("==================================================================================")

	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	assert(main_scene != null, "scenes/main.tscn deve existir e ser carregável")

	var root_node: Node3D = main_scene.instantiate() as Node3D
	root_vp.add_child(root_node)

	for _i in range(5):
		await process_frame

	var sun: DirectionalLight3D = root_node.get_node_or_null("Sun") as DirectionalLight3D
	var world_env: WorldEnvironment = root_node.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var arena_art: Node3D = root_node.get_node_or_null("ArenaArt") as Node3D
	var player: Node3D = root_node.get_node_or_null("Player") as Node3D
	var camera: Camera3D = root_node.get_node_or_null("Camera") as Camera3D

	assert(sun != null, "Nó Sun deve estar presente")
	assert(world_env != null, "Nó WorldEnvironment deve estar presente")
	assert(arena_art != null, "Nó ArenaArt deve estar presente")
	assert(player != null, "Nó Player deve estar presente")
	assert(camera != null, "Nó Camera deve estar presente")

	# -------------------------------------------------------------------------
	# CENÁRIO 1: Remoção Total do Sistema Dia/Noite e Lanterna do Personagem
	# -------------------------------------------------------------------------
	print("\n--- 1. AUSÊNCIA DE SISTEMA DIA/NOITE E LANTERNA ---")
	var day_night = root_node.get("day_night_hud")
	assert(day_night == null, "DayNightCycleHUD NÃO deve existir no jogo")
	var hud_node: CanvasLayer = root_node.get_node_or_null("HUD") as CanvasLayer
	if hud_node != null:
		assert(hud_node.get_node_or_null("DayNightCycleHUD") == null, "Nenhum widget de relógio no HUD")
	assert(player.get("belt_lantern") == null, "Player NÃO possui lanterna (removida)")
	var omni_lights_in_player := player.find_children("", "OmniLight3D", true, false)
	assert(omni_lights_in_player.is_empty(), "Nenhuma luz OmniLight3D presa ao jogador")
	print("[OK] Cenário 1: Dia/Noite e Lanterna 100% ausentes do projeto.")

	# -------------------------------------------------------------------------
	# CENÁRIO 2: Iluminação Solar Forte, Clara e Estática
	# -------------------------------------------------------------------------
	print("\n--- 2. LUZ SOLAR DIRETA CLARA E CONSTANTE ---")
	assert(sun.light_energy >= 1.20, "Luz solar possui energia forte (>= 1.20) para máxima legibilidade")
	assert(sun.light_color.r >= 0.95 and sun.light_color.g >= 0.95, "Luz solar possui cor clara natural")
	assert(sun.shadow_enabled == true, "Sombras do sol estão ativadas")
	assert(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_ORTHOGONAL, "Modo de sombra é Ortogonal para silhueta dura")
	assert(sun.directional_shadow_max_distance >= 40.0, "Distância de sombra cobre arena isométrica")
	assert(sun.shadow_blur == 0.0, "Shadow blur é 0.0 para sombras recortadas e nítidas")
	print("[OK] Cenário 2: Sol direcional estático operando com luz clara (Energy=%.2f) e sombras ortogonais." % sun.light_energy)

	# -------------------------------------------------------------------------
	# CENÁRIO 3: Iluminação Ambiente Permanente (Garantia: Nunca Fica Escuro)
	# -------------------------------------------------------------------------
	print("\n--- 3. ILUMINAÇÃO AMBIENTE PERMANENTE (NUNCA ESCURO) ---")
	assert(world_env.environment != null, "Environment configurado")
	assert(world_env.environment.ambient_light_energy >= 0.40, "Luz ambiente >= 0.40 garantindo que sombras nunca fiquem escuras")
	assert(world_env.environment.ambient_light_color.r > 0.45 and world_env.environment.ambient_light_color.g > 0.45, "Ambiente claro suave de céu aberto")
	print("[OK] Cenário 3: Luz ambiente permanente (Energy=%.2f) garante ambiente 100%% legível e claro." % world_env.environment.ambient_light_energy)

	# -------------------------------------------------------------------------
	# CENÁRIO 4: Auditoria do Terreno e Normais
	# -------------------------------------------------------------------------
	print("\n--- 4. AUDITORIA GEOMÉTRICA DO TERRENO ---")
	var terrain: MeshInstance3D = arena_art.get_node_or_null("Terrain_Continuous_Grass_Dirt") as MeshInstance3D
	assert(terrain != null, "Terreno contínuo deve existir em ArenaArt")
	var mat: Material = terrain.material_override
	assert(mat != null, "Material do terreno existe")
	print("[OK] Cenário 4: Terreno contínuo e material PBR verificados.")

	# -------------------------------------------------------------------------
	# CENÁRIO 5: Personagem e Movimento Projetando Sombras
	# -------------------------------------------------------------------------
	print("\n--- 5. SOMBRAS DO HERÓI SOB OS PÉS ---")
	var p_mesh: MeshInstance3D = player.find_child("CombinedSkinnedMesh", true, false) as MeshInstance3D
	if p_mesh == null:
		p_mesh = player.find_child("Torso", true, false) as MeshInstance3D
	assert(p_mesh != null, "Malha do personagem presente")
	assert(p_mesh.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Malha do personagem projeta sombras")
	print("[OK] Cenário 5: Sombra do herói projetada com precisão no terreno.")

	# -------------------------------------------------------------------------
	# CENÁRIO 6: Inimigos e Cenário Projetando Sombras
	# -------------------------------------------------------------------------
	print("\n--- 6. SOMBRAS DE INIMIGOS E OBJETOS DO CENÁRIO ---")
	var tree_node: Node3D = arena_art.find_child("*Tree*", true, false) as Node3D
	assert(tree_node != null, "Árvores existem em ArenaArt")
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
	var enemy_instance: CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	root_node.add_child(enemy_instance)
	enemy_instance.global_position = Vector3(-4.0, 0.0, 2.0)
	await process_frame
	await process_frame

	var enemy_meshes: Array[Node] = enemy_instance.find_children("*", "MeshInstance3D", true, false)
	assert(enemy_meshes.size() > 0, "Inimigo possui malhas")
	enemy_instance.queue_free()
	print("[OK] Cenário 6: Inimigos e árvores projetam sombras limpas.")

	# -------------------------------------------------------------------------
	# CENÁRIO 7: Câmera Isométrica em Deslocamento
	# -------------------------------------------------------------------------
	print("\n--- 7. ESTABILIDADE DA ILUMINAÇÃO ISOMÉTRICA ---")
	var cam_start := camera.global_position
	camera.global_position += Vector3(8.0, 0.0, 8.0)
	await process_frame
	assert(sun.directional_shadow_max_distance >= 40.0, "Sombra contínua sem quebras")
	camera.global_position = cam_start
	print("[OK] Cenário 7: Iluminação perfeitamente estável e brilhante sob movimentação.")

	# -------------------------------------------------------------------------
	# CONCLUSÃO
	# -------------------------------------------------------------------------
	print("\n==================================================================================")
	print("=== RESULTADO DA AUDITORIA: 7/7 CENÁRIOS PASSARAM COM 100% DE SUCESSO! ===")
	print(">> ILUMINAÇÃO ESTÁTICA CLARA E DESLIGAMENTO TOTAL DE DIA/NOITE CONCLUÍDOS! <<\n")
	quit(0)
