extends SceneTree
## ============================================================================
## SUÍTE DE QA: TERRENO ESTILIZADO PINTADO À MÃO (KIT 10 - GODOT 4)
## Valida integridade das texturas PBR, shader de blend, máscaras orgânicas por
## zona, construção de malha contínua, integração ao ArenaArt e física desacoplada.
## ============================================================================

const StylizedTerrainServiceScript = preload("res://core/terrain/stylized_terrain_service.gd")
const ArenaArtScript = preload("res://scripts/arena_art.gd")
const CampaignZoneDefScript = preload("res://game/campaign/campaign_zone_definition.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("\n=================================================================")
	print("SUÍTE DE QA: TERRENO ESTILIZADO (KIT 10 / PBR SHADER & MÁSCARAS)")
	print("=================================================================\n")
	_run_all_tests()
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
	_test_01_shader_and_texture_assets()
	_test_02_zone_control_masks()
	_test_03_material_generation_and_uniforms()
	_test_04_mesh_geometry_and_properties()
	_test_05_arena_art_integration()
	_test_06_physics_decoupling_and_collision()


func _test_01_shader_and_texture_assets() -> void:
	print("--- 1. SHADER GLSL E TEXTURAS PBR ESTILIZADAS (KIT 10 SEÇÃO 2) ---")

	var shader: Shader = StylizedTerrainServiceScript.get_shader()
	assert_test(shader != null, "Shader 'res://assets/terrain_v2/terreno_estilizado_blend.gdshader' compilado com sucesso")

	var expected_textures: Dictionary = {
		"grass_tex": "01_grama_base.png",
		"dirt_tex": "02_terra_base.png",
		"stone_tex": "03_pedra_base.png",
		"grass_pebble_tex": "04_grama_com_pedrinhas.png",
		"dirt_pebble_tex": "06_terra_com_pedrinhas.png",
		"rocky_path_tex": "07_trilha_pedregosa.png"
	}

	for uniform_name in expected_textures.keys():
		var tex_name: String = expected_textures[uniform_name]
		var tex: Texture2D = StylizedTerrainServiceScript.get_texture(uniform_name)
		assert_test(tex != null, "Textura base '%s' (%s) carregada com sucesso" % [uniform_name, tex_name])
		if tex != null:
			assert_test(tex.get_width() >= 512 and tex.get_height() >= 512, "Textura '%s' tem resolução adequada (>= 512x512, obtido: %dx%d)" % [uniform_name, tex.get_width(), tex.get_height()])

	# Validação de cache
	var cached_grass := StylizedTerrainServiceScript.get_texture("grass_tex")
	assert_test(cached_grass == StylizedTerrainServiceScript.get_texture("grass_tex"), "Cache estático de texturas opera sem leituras de disco repetidas")


func _test_02_zone_control_masks() -> void:
	print("\n--- 2. MÁSCARAS DE CONTROLE ORGÂNICAS POR REGIÃO (ATO 1 + LOBBY) ---")

	var zones: Array[String] = [
		"town",
		"zone_1_road",
		"zone_2_woods",
		"zone_4_mines",
		"zone_3_crypt",
		"lobby"
	]

	for zone_id in zones:
		var masks: Dictionary = StylizedTerrainServiceScript.get_zone_masks(zone_id)
		var base_mask: Texture2D = masks.get("base") as Texture2D
		var detail_mask: Texture2D = masks.get("detail") as Texture2D

		assert_test(base_mask != null, "Zona '%s': Máscara base (01_controle_base_terra_pedra.png) carregada" % zone_id)
		assert_test(detail_mask != null, "Zona '%s': Máscara detalhes (02_controle_detalhes_pedrinhas.png) carregada" % zone_id)

		if base_mask != null:
			assert_test(base_mask.get_width() >= 512 and base_mask.get_height() >= 512, "Zona '%s': Máscara base tem resolução satisfatória (%dx%d)" % [zone_id, base_mask.get_width(), base_mask.get_height()])
		if detail_mask != null:
			assert_test(detail_mask.get_width() >= 512 and detail_mask.get_height() >= 512, "Zona '%s': Máscara detalhes tem resolução satisfatória (%dx%d)" % [zone_id, detail_mask.get_width(), detail_mask.get_height()])

	# Fallback elegante em caso de zona desconhecida
	var fallback_masks: Dictionary = StylizedTerrainServiceScript.get_zone_masks("unknown_fantasy_zone_999")
	assert_test(fallback_masks.get("base") != null and fallback_masks.get("detail") != null, "Fallback gracioso para zona desconhecida fornece máscaras padrão sem quebrar a renderização")


func _test_03_material_generation_and_uniforms() -> void:
	print("\n--- 3. GERAÇÃO DE SHADERMATERIAL E UNIFORMS (PBR BURLEY / ROUGHNESS 0.96) ---")

	var mat: ShaderMaterial = StylizedTerrainServiceScript.get_material_for_zone("town", Vector2(12.0, 12.0))
	assert_test(mat != null, "ShaderMaterial gerado com sucesso para 'town'")
	assert_test(mat.shader != null, "Material possui shader anexado")

	# Uniforms de texturas PBR
	for uniform_name in StylizedTerrainServiceScript.TEXTURES.keys():
		var param_tex: Texture2D = mat.get_shader_parameter(uniform_name) as Texture2D
		assert_test(param_tex != null, "ShaderMaterial uniform '%s' vinculado corretamente" % uniform_name)

	# Uniforms de máscaras
	var base_ctrl: Texture2D = mat.get_shader_parameter("base_control") as Texture2D
	var detail_ctrl: Texture2D = mat.get_shader_parameter("detail_control") as Texture2D
	assert_test(base_ctrl != null, "ShaderMaterial uniform 'base_control' atribuído")
	assert_test(detail_ctrl != null, "ShaderMaterial uniform 'detail_control' atribuído")

	# Uniforms de parâmetros visuais
	var tiling: Vector2 = mat.get_shader_parameter("texture_tiling")
	var strength: float = float(mat.get_shader_parameter("details_strength"))
	var roughness: float = float(mat.get_shader_parameter("material_roughness"))
	assert_test(is_equal_approx(tiling.x, 12.0) and is_equal_approx(tiling.y, 12.0), "Repetição UV (texture_tiling) configurada para (12.0, 12.0)")
	assert_test(is_equal_approx(strength, 0.75), "details_strength configurado para 0.75")
	assert_test(is_equal_approx(roughness, 0.96), "material_roughness configurado para 0.96 (evita reflexos plásticos)")

	# Validação de cache do material
	var cached_mat: ShaderMaterial = StylizedTerrainServiceScript.get_material_for_zone("town", Vector2(12.0, 12.0))
	assert_test(cached_mat == mat, "Reaproveitamento de ShaderMaterial cacheado para a mesma região e tiling")


func _test_04_mesh_geometry_and_properties() -> void:
	print("\n--- 4. GEOMETRIA DA MALHA, BOUNDS E PROPRIEDADES DE SOMBRA ---")

	var terrain_node: MeshInstance3D = StylizedTerrainServiceScript.create_terrain_mesh_instance(Vector2(52.0, 52.0))
	assert_test(terrain_node != null, "Instância de MeshInstance3D do terreno criada")
	assert_test(terrain_node.name == "Terrain_Continuous_Grass_Dirt", "Nome do nó é 'Terrain_Continuous_Grass_Dirt'")
	assert_test(is_equal_approx(terrain_node.position.y, 0.001), "Posição Y do terreno é 0.001 (ligeiramente acima do plano físico Y=0.0 para evitar Z-fighting)")
	assert_test(terrain_node.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "cast_shadow é OFF (recebe sombras sem gerar artefatos em si mesmo)")

	var plane_mesh: PlaneMesh = terrain_node.mesh as PlaneMesh
	assert_test(plane_mesh != null, "Geometria da malha é PlaneMesh")
	assert_test(is_equal_approx(plane_mesh.size.x, 52.0) and is_equal_approx(plane_mesh.size.y, 52.0), "Tamanho da malha é 52x52m cobrindo toda a arena jogável")
	assert_test(plane_mesh.subdivide_width >= 8 and plane_mesh.subdivide_depth >= 8, "Subdivisões adequadas para sombreamento suave (>= 8x8)")


func _test_05_arena_art_integration() -> void:
	print("\n--- 5. INTEGRAÇÃO AO ARENAART & REMOÇÃO DE TUFOS BLOCO-A-BLOCO ---")

	var arena: Node3D = ArenaArtScript.new()
	var default_zones: Dictionary = CampaignZoneDefScript.build_default_campaign_zones()

	# Teste em zona de campanha (ex: town)
	var town_zone_res: Resource = default_zones["town"] as Resource
	arena.rebuild_campaign_zone(town_zone_res)

	var terrain_town: MeshInstance3D = arena.get_node_or_null("Terrain_Continuous_Grass_Dirt") as MeshInstance3D
	assert_test(terrain_town != null, "ArenaArt instancia 'Terrain_Continuous_Grass_Dirt' na campanha")
	assert_test(terrain_town != null and terrain_town.material_override is ShaderMaterial, "Material do terreno na campanha é ShaderMaterial estilizado")

	# Teste de transição para outra zona (ex: zone_1_road)
	var road_zone_res: Resource = default_zones["zone_1_road"] as Resource
	arena.rebuild_campaign_zone(road_zone_res)
	var terrain_road: MeshInstance3D = arena.get_node_or_null("Terrain_Continuous_Grass_Dirt") as MeshInstance3D
	assert_test(terrain_road != null, "ArenaArt reconstrói terreno suavemente ao trocar para 'zone_1_road'")

	# Teste no Lobby da Torre
	arena.rebuild_tower_arena()
	var terrain_lobby: MeshInstance3D = arena.get_node_or_null("Terrain_Continuous_Grass_Dirt") as MeshInstance3D
	assert_test(terrain_lobby != null, "ArenaArt instancia terreno estilizado no Lobby")

	# Verificação da desativação de tufos de grama antigos grosseiros
	var old_grass_tufts: Node = arena.get_node_or_null("GrassTuftsMultiMesh")
	assert_test(old_grass_tufts == null, "GrassTuftsMultiMesh provisório antigo está 100% desativado (sem cubos flutuantes)")

	arena.free()


func _test_06_physics_decoupling_and_collision() -> void:
	print("\n--- 6. DESACOPLAMENTO DA FÍSICA & INTEGRIDADE DE COLISÃO ---")

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	assert_test(main_scene != null, "Cena 'scenes/main.tscn' existe e é carregável")

	var main_instance: Node = main_scene.instantiate()
	var ground_node: StaticBody3D = main_instance.get_node_or_null("Ground") as StaticBody3D
	assert_test(ground_node != null, "Nó 'Ground' (StaticBody3D) existe na raiz da arena")

	var collision_shape: CollisionShape3D = ground_node.get_node_or_null("GroundCollision") as CollisionShape3D
	assert_test(collision_shape != null, "Nó 'GroundCollision' ativo para colisão física do personagem e inimigos")

	var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
	assert_test(box_shape != null, "Forma física é BoxShape3D")
	assert_test(is_equal_approx(box_shape.size.x, 52.0) and is_equal_approx(box_shape.size.z, 52.0), "Extensão da física é 52x52m compatível com a arena")
	# Topo da colisão física: position.y (-0.2) + size.y * 0.5 (0.2) = 0.0
	var top_y: float = collision_shape.position.y + (box_shape.size.y * 0.5)
	assert_test(is_equal_approx(top_y, 0.0), "Plano físico de colisão está exatamente em Y=0.0 (personagem caminha perfeitamente alinhado)")

	main_instance.free()


func _print_summary() -> void:
	print("\n=================================================================")
	print("RESULTADO QA TERRENO ESTILIZADO: %d/%d PASSARAM (%d FALHAS)" % [passed_tests, total_tests, failed_tests])
	print("=================================================================")
	if failed_tests == 0:
		print(">> TODOS OS REQUISITOS DO TERRENO ESTILIZADO FORAM APROVADOS! <<\n")
	else:
		printerr(">> HOUVE FALHAS NA VALIDAÇÃO DO TERRENO! <<\n")
