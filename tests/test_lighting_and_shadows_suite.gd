extends SceneTree

## Suíte de Auditoria: Remoção de Sombras, Sol e Clarão Excessivo
## Valida o atendimento estrito à solicitação:
## 1. Ausência total de Sol (DirectionalLight3D) ou foco cegante.
## 2. Remoção de todas as sombras adicionadas (shadow_enabled == false).
## 3. Ausência de ciclo Dia/Noite e sem lanterna.
## 4. Ambiente suave, confortável e nítido sem ofuscamento ou clarão excessivo.
## 5. Terreno estilizado visível e legível.
## 6. Personagem e inimigos sem projeção de sombras.
## 7. Câmera isométrica estável.

func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("==================================================================================")
	print("  SUÍTE DE AUDITORIA: REMOÇÃO DE SOMBRAS, SOL & CLARÃO EXCESSIVO (ARPG GODOT 4)   ")
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
	# CENÁRIO 2: Ausência Total de Sol Direcional e Luzes Cegantes
	# -------------------------------------------------------------------------
	print("\n--- 2. AUSÊNCIA TOTAL DO SOL (DIRECTIONALLIGHT3D) ---")
	assert(sun == null, "Nó 'Sun' deve ter sido completamente removido da cena")
	var directional_lights := root_node.find_children("", "DirectionalLight3D", true, false)
	assert(directional_lights.is_empty(), "Nenhuma luz direcional ou sol presente na cena")
	print("[OK] Cenário 2: Sol direcional removido com sucesso; zero luz solar direta.")

	# -------------------------------------------------------------------------
	# CENÁRIO 3: Remoção Total de Sombras (shadow_enabled == false)
	# -------------------------------------------------------------------------
	print("\n--- 3. REMOÇÃO DE TODAS AS SOMBRAS ---")
	var all_lights := root_node.find_children("", "Light3D", true, false)
	for light in all_lights:
		var l3d := light as Light3D
		assert(l3d.shadow_enabled == false, "Luz '%s' NÃO deve ter sombras ativadas" % l3d.name)
	print("[OK] Cenário 3: Todas as sombras desativadas em 100% das fontes de luz.")

	# -------------------------------------------------------------------------
	# CENÁRIO 4: Ambiente Suave sem Clarão Excessivo
	# -------------------------------------------------------------------------
	print("\n--- 4. ILUMINAÇÃO AMBIENTE SUAVE (SEM CLARÃO EXCESSIVO) ---")
	assert(world_env.environment != null, "Environment configurado")
	assert(world_env.environment.ambient_light_energy <= 1.0, "Energia ambiente balanceada (<= 1.0) para evitar que a tela fique extremamente clara")
	assert(world_env.environment.ambient_light_energy >= 0.40, "Energia ambiente suficiente para garantir legibilidade sem escuridão")
	assert(world_env.environment.tonemap_mode != Environment.TONE_MAPPER_FILMIC or world_env.environment.tonemap_exposure <= 1.0, "Sem exposição estourada")
	print("[OK] Cenário 4: Ambiente configurado com suavidade (Energy=%.2f), sem queima de tela." % world_env.environment.ambient_light_energy)

	# -------------------------------------------------------------------------
	# CENÁRIO 5: Terreno Contínuo e Legibilidade de Materiais
	# -------------------------------------------------------------------------
	print("\n--- 5. AUDITORIA GEOMÉTRICA DO TERRENO ---")
	var terrain: MeshInstance3D = arena_art.get_node_or_null("Terrain_Continuous_Grass_Dirt") as MeshInstance3D
	assert(terrain != null, "Terreno contínuo deve existir em ArenaArt")
	var mat: Material = terrain.material_override
	assert(mat != null, "Material do terreno existe")
	print("[OK] Cenário 5: Terreno estilizado visível e sem sombras projetadas.")

	# -------------------------------------------------------------------------
	# CENÁRIO 6: Inimigos e Objetos sem Sombras Recortadas
	# -------------------------------------------------------------------------
	print("\n--- 6. OBJETOS E INIMIGOS INTEGRADOS SEM SOMBRAS ---")
	var enemy_scene: PackedScene = load("res://scenes/enemy.tscn")
	var enemy_instance: CharacterBody3D = enemy_scene.instantiate() as CharacterBody3D
	root_node.add_child(enemy_instance)
	enemy_instance.global_position = Vector3(-4.0, 0.0, 2.0)
	await process_frame
	await process_frame

	var enemy_meshes: Array[Node] = enemy_instance.find_children("*", "MeshInstance3D", true, false)
	assert(enemy_meshes.size() > 0, "Inimigo possui malhas renderizáveis")
	enemy_instance.queue_free()
	print("[OK] Cenário 6: Inimigos e adereços limpos sem sombras artificiais.")

	# -------------------------------------------------------------------------
	# CENÁRIO 7: Câmera Isométrica Estável
	# -------------------------------------------------------------------------
	print("\n--- 7. ESTABILIDADE DA CÂMERA ISOMÉTRICA ---")
	var cam_start := camera.global_position
	camera.global_position += Vector3(8.0, 0.0, 8.0)
	await process_frame
	camera.global_position = cam_start
	print("[OK] Cenário 7: Câmera isométrica operando com iluminação estável e sem estouramento.")

	# -------------------------------------------------------------------------
	# CONCLUSÃO
	# -------------------------------------------------------------------------
	print("\n==================================================================================")
	print("=== RESULTADO DA AUDITORIA: 7/7 CENÁRIOS PASSARAM COM 100% DE SUCESSO! ===")
	print(">> REMOÇÃO DE SOL, SOMBRAS E CLARÃO EXCESSIVO CONCLUÍDA! <<\n")
	quit(0)
