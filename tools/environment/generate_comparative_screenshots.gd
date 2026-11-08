extends SceneTree

const ARTIFACT_DIR := "C:/Users/mathh/.gemini/antigravity/brain/449434f6-2437-4244-9cef-d5bd6928f462/"

func _init() -> void:
	call_deferred("_generate_all_screenshots")

func _generate_all_screenshots() -> void:
	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)

	print("=== INICIANDO GERAÇÃO DOS 5 COMPARATIVOS OBRIGATÓRIOS ===")

	# 1. Comparativo 1: Problema Anterior
	_create_comparativo_1()

	# 2. Comparativo 2: Cena Neutra Calibrada
	await _create_comparativo_2()

	# 3. Comparativo 3: Floresta de Arath Final (In-Game)
	await _create_comparativo_3()

	# 4. Comparativo 4: Personagem sob Copa de Árvore (Dithered Fade Ativo)
	await _create_comparativo_4()

	# 5. Comparativo 5: Iluminação Local de Tocha (Masmorra / Santuário)
	await _create_comparativo_5()

	print("=== TODOS OS 5 COMPARATIVOS GERADOS COM SUCESSO! ===")
	quit(0)


func _create_comparativo_1() -> void:
	print(">>> [1/5] Gerando comparativo_1_problema_anterior.png...")
	var source_path := ARTIFACT_DIR + "lighting_scene_a_forest.png"
	var prev_broken := Image.load_from_file(source_path)
	if prev_broken == null:
		source_path = ARTIFACT_DIR + ".user_uploaded/media_1794144924318_cd81053a.jpg"
		prev_broken = Image.load_from_file(source_path)
	
	if prev_broken != null:
		var target_path := ARTIFACT_DIR + "comparativo_1_problema_anterior.png"
		prev_broken.save_png(target_path)
		print("    Salvo com sucesso: ", target_path)
	else:
		print("    Aviso: Arquivo base anterior não encontrado!")


func _create_comparativo_2() -> void:
	print(">>> [2/5] Gerando comparativo_2_cena_neutra_calibrada.png...")
	var root_vp := get_root()
	var stage := Node3D.new()
	stage.name = "StageCalibrated"
	root_vp.add_child(stage)

	# WorldEnvironment com perfil calibrado
	var w_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.56, 0.64)
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	w_env.environment = env
	stage.add_child(w_env)

	# Sol direcional
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 0.84
	sun.shadow_enabled = true
	sun.shadow_blur = 0.85
	sun.shadow_bias = 0.015
	sun.directional_shadow_max_distance = 36.0
	stage.add_child(sun)

	# Chão com os 4 materiais (Grama verde oliva natural, Terra suave, Pedra, Cinza 18%)
	var patches := [
		{"name": "Grama", "x": -4.5, "z": 0.0, "color": Color(0.32, 0.52, 0.22), "rough": 0.88},
		{"name": "Terra", "x": -1.5, "z": 0.0, "color": Color(0.48, 0.38, 0.28), "rough": 0.92},
		{"name": "Pedra", "x": 1.5, "z": 0.0, "color": Color(0.50, 0.50, 0.52), "rough": 0.82},
		{"name": "Cinza18", "x": 4.5, "z": 0.0, "color": Color(0.18, 0.18, 0.18), "rough": 0.90}
	]
	for p in patches:
		var patch := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(3.0, 8.0)
		patch.mesh = plane
		patch.position = Vector3(p["x"], 0.0, p["z"])
		patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var m := StandardMaterial3D.new()
		m.albedo_color = p["color"]
		m.roughness = p["rough"]
		m.metallic = 0.0
		m.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
		patch.set_surface_override_material(0, m)
		stage.add_child(patch)

	# Árvore (Tree.glb)
	var tree_scene := load("res://assets/nature_megakit/Tree.glb") as PackedScene
	if tree_scene:
		var tree_node: Node3D = tree_scene.instantiate() as Node3D
		tree_node.position = Vector3(-3.0, 0.0, -1.8)
		stage.add_child(tree_node)
		for mi in tree_node.find_children("", "MeshInstance3D", true, false):
			var m_inst := mi as MeshInstance3D
			m_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for s in range(m_inst.mesh.get_surface_count()):
				var orig = m_inst.mesh.surface_get_material(s)
				if orig is StandardMaterial3D:
					var sm := orig.duplicate() as StandardMaterial3D
					sm.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
					sm.roughness = 0.85
					m_inst.set_surface_override_material(s, sm)

	# Rocha Média (Rock Medium.glb)
	var rock_scene := load("res://assets/nature_megakit/Rock Medium.glb") as PackedScene
	if rock_scene:
		var rock_node: Node3D = rock_scene.instantiate() as Node3D
		rock_node.position = Vector3(1.8, 0.0, -1.5)
		stage.add_child(rock_node)
		for mi in rock_node.find_children("", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	# Knight com malha otimizada e materiais calibrados
	var knight_scene := load("res://assets/models/knight.glb") as PackedScene
	if knight_scene:
		var knight_node: Node3D = knight_scene.instantiate() as Node3D
		knight_node.position = Vector3(0.0, 0.0, 0.8)
		knight_node.rotation_degrees = Vector3(0.0, 180.0, 0.0)
		stage.add_child(knight_node)
		for mi in knight_node.find_children("", "MeshInstance3D", true, false):
			var k_mi := mi as MeshInstance3D
			k_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for s in range(k_mi.mesh.get_surface_count()):
				var km_orig = k_mi.mesh.surface_get_material(s)
				if km_orig is StandardMaterial3D:
					var k_sm := km_orig.duplicate() as StandardMaterial3D
					if k_sm.resource_name == "Steel_Light":
						k_sm.albedo_color = Color(0.58, 0.60, 0.64)
						k_sm.roughness = 0.50
					elif k_sm.resource_name == "Steel":
						k_sm.albedo_color = Color(0.46, 0.48, 0.52)
						k_sm.roughness = 0.55
					elif k_sm.resource_name == "Blade":
						k_sm.albedo_color = Color(0.64, 0.66, 0.70)
						k_sm.roughness = 0.40
					k_sm.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
					k_mi.set_surface_override_material(s, k_sm)

	# Câmera Isométrica
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 8.8
	cam.position = Vector3(6.2, 8.2, 6.2)
	stage.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.6, 0.0), Vector3.UP)

	for _f in range(6):
		await process_frame

	var img := root_vp.get_texture().get_image()
	img.save_png(ARTIFACT_DIR + "comparativo_2_cena_neutra_calibrada.png")
	print("    Salvo com sucesso: comparativo_2_cena_neutra_calibrada.png")

	stage.queue_free()
	for _f in range(2):
		await process_frame


func _create_comparativo_3() -> void:
	print(">>> [3/5] Gerando comparativo_3_floresta_arath_final.png...")
	var root_vp := get_root()
	var game_scene := load("res://scenes/arpg/arpg_game.tscn") as PackedScene
	var game: Node = game_scene.instantiate()
	root_vp.add_child(game)

	# Carrega a zona Floresta de Arath (zone_1_road)
	game.call("load_zone", "zone_1_road")

	for _f in range(16):
		await process_frame

	var img := root_vp.get_texture().get_image()
	img.save_png(ARTIFACT_DIR + "comparativo_3_floresta_arath_final.png")
	print("    Salvo com sucesso: comparativo_3_floresta_arath_final.png")

	game.queue_free()
	for _f in range(2):
		await process_frame


func _create_comparativo_4() -> void:
	print(">>> [4/5] Gerando comparativo_4_personagem_sob_arvore.png...")
	var root_vp := get_root()
	var stage := Node3D.new()
	stage.name = "StageTreeOcclusion"
	root_vp.add_child(stage)

	# Iluminação calibrada
	var w_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.56, 0.64)
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	w_env.environment = env
	stage.add_child(w_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.96, 0.90)
	sun.light_energy = 0.84
	sun.shadow_enabled = true
	sun.shadow_blur = 0.85
	sun.shadow_bias = 0.015
	sun.directional_shadow_max_distance = 36.0
	stage.add_child(sun)

	# Chão contínuo estilizado verde oliva
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 16.0)
	ground.mesh = plane
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.32, 0.50, 0.22)
	gm.roughness = 0.90
	gm.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	ground.set_surface_override_material(0, gm)
	stage.add_child(ground)

	# Árvore NatureProp3D posicionada exatamente entre a câmera e o jogador
	# Câmera está em (+5.8, +7.5, +5.8). Jogador está em (0, 0, 0).
	# A árvore fica em (+1.8, 0, +1.8) obstruindo a linha de visão.
	var tree_prop := NatureProp3D.new()
	tree_prop.configure("res://assets/nature_megakit/Tree.glb", NatureProp3D.PropCategory.TREE_NORMAL, Vector3(1.15, 1.15, 1.15))
	tree_prop.position = Vector3(1.8, 0.0, 1.8)
	stage.add_child(tree_prop)

	# Ativa Dithered Fade na copa da árvore obstrutora (fade_amount = 0.35)
	tree_prop.set_target_fade(0.35)
	tree_prop.apply_fade_step(10.0)

	# Jogador posicionado sob a sombra e copa da árvore
	var knight_scene := load("res://assets/models/knight.glb") as PackedScene
	if knight_scene:
		var knight_node: Node3D = knight_scene.instantiate() as Node3D
		knight_node.position = Vector3(0.0, 0.0, 0.0)
		knight_node.rotation_degrees = Vector3(0.0, 140.0, 0.0)
		stage.add_child(knight_node)
		for mi in knight_node.find_children("", "MeshInstance3D", true, false):
			var k_mi := mi as MeshInstance3D
			k_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for s in range(k_mi.mesh.get_surface_count()):
				var km_orig = k_mi.mesh.surface_get_material(s)
				if km_orig is StandardMaterial3D:
					var k_sm := km_orig.duplicate() as StandardMaterial3D
					if k_sm.resource_name == "Steel_Light":
						k_sm.albedo_color = Color(0.58, 0.60, 0.64)
						k_sm.roughness = 0.50
					elif k_sm.resource_name == "Steel":
						k_sm.albedo_color = Color(0.46, 0.48, 0.52)
						k_sm.roughness = 0.55
					k_sm.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
					k_mi.set_surface_override_material(s, k_sm)

	# Câmera Isométrica com foco no jogador
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.5
	cam.position = Vector3(5.6, 7.2, 5.6)
	stage.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0.4, 0.7, 0.4), Vector3.UP)

	for _f in range(6):
		await process_frame

	var img := root_vp.get_texture().get_image()
	img.save_png(ARTIFACT_DIR + "comparativo_4_personagem_sob_arvore.png")
	print("    Salvo com sucesso: comparativo_4_personagem_sob_arvore.png")

	stage.queue_free()
	for _f in range(2):
		await process_frame


func _create_comparativo_5() -> void:
	print(">>> [5/5] Gerando comparativo_5_tocha_local.png...")
	var root_vp := get_root()
	var stage := Node3D.new()
	stage.name = "StageTorchLight"
	root_vp.add_child(stage)

	# Perfil Masmorra (Interior)
	var w_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.04, 0.06)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.22, 0.25, 0.32)
	env.ambient_light_energy = 0.26
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	w_env.environment = env
	stage.add_child(w_env)

	# Chão de pedra de masmorra
	var floor_node := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16.0, 16.0)
	floor_node.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.26, 0.26, 0.28)
	fm.roughness = 0.85
	fm.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
	floor_node.set_surface_override_material(0, fm)
	stage.add_child(floor_node)

	# Tocha / Ponto de Luz Local quente estilizado (âmbar)
	var torch := OmniLight3D.new()
	torch.position = Vector3(1.5, 2.0, -1.0)
	torch.light_color = Color(1.0, 0.62, 0.22)
	torch.light_energy = 1.85
	torch.omni_range = 10.5
	torch.omni_attenuation = 1.30
	torch.shadow_enabled = true
	torch.shadow_blur = 1.0
	stage.add_child(torch)

	# Pilar de pedra próximo à tocha
	var pilar := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.55
	cyl.height = 3.5
	pilar.mesh = cyl
	pilar.position = Vector3(1.5, 1.75, -2.0)
	pilar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.32, 0.32, 0.34)
	pm.roughness = 0.88
	pilar.set_surface_override_material(0, pm)
	stage.add_child(pilar)

	# Jogador na área de iluminação da tocha
	var knight_scene := load("res://assets/models/knight.glb") as PackedScene
	if knight_scene:
		var knight_node: Node3D = knight_scene.instantiate() as Node3D
		knight_node.position = Vector3(0.0, 0.0, 0.0)
		knight_node.rotation_degrees = Vector3(0.0, 150.0, 0.0)
		stage.add_child(knight_node)
		for mi in knight_node.find_children("", "MeshInstance3D", true, false):
			var k_mi := mi as MeshInstance3D
			k_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			for s in range(k_mi.mesh.get_surface_count()):
				var km_orig = k_mi.mesh.surface_get_material(s)
				if km_orig is StandardMaterial3D:
					var k_sm := km_orig.duplicate() as StandardMaterial3D
					if k_sm.resource_name == "Steel_Light":
						k_sm.albedo_color = Color(0.58, 0.60, 0.64)
						k_sm.roughness = 0.50
					elif k_sm.resource_name == "Steel":
						k_sm.albedo_color = Color(0.46, 0.48, 0.52)
						k_sm.roughness = 0.55
					k_sm.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
					k_mi.set_surface_override_material(s, k_sm)

	# Câmera Isométrica
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.0
	cam.position = Vector3(5.2, 6.8, 5.2)
	stage.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0.6, 0.6, -0.4), Vector3.UP)

	for _f in range(6):
		await process_frame

	var img := root_vp.get_texture().get_image()
	img.save_png(ARTIFACT_DIR + "comparativo_5_tocha_local.png")
	print("    Salvo com sucesso: comparativo_5_tocha_local.png")

	stage.queue_free()
	for _f in range(2):
		await process_frame
