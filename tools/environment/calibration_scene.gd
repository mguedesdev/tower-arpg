extends SceneTree

# Cena Neutra de Calibracao de Iluminacao, Materiais e Sombras (Godot 4)
# Contem:
# - Superficie de grama
# - Superficie de terra
# - Superficie de pedra
# - Superficie cinza neutra (18% neutral gray / sRGB 0.5)
# - Uma arvore (Tree.glb ou Pine.glb)
# - Uma rocha (Rock Medium.glb)
# - O guerreiro (Player / knight.glb)

func _init() -> void:
	call_deferred("_run_calibration_tests")

func _run_calibration_tests() -> void:
	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)
	
	print("=== INICIANDO PROTOCOLO DE CALIBRAÇÃO (TESTES A A F) ===")
	
	# Executa os 6 testes isolados
	await _run_test("test_a_ambient_only", "Teste A — Somente Ambiente (Sem Sol)", {"sun": false, "ambient_nrg": 0.40, "tonemap": Environment.TONE_MAPPER_LINEAR})
	await _run_test("test_b_sun_only", "Teste B — Somente Sol (Sem Ambiente)", {"sun": true, "sun_nrg": 0.85, "ambient_nrg": 0.0, "tonemap": Environment.TONE_MAPPER_LINEAR})
	await _run_test("test_c_sun_and_ambient", "Teste C — Sol + Ambiente Equilibrado", {"sun": true, "sun_nrg": 0.85, "ambient_nrg": 0.35, "tonemap": Environment.TONE_MAPPER_LINEAR})
	await _run_test("test_d_tonemapping_filmic", "Teste D — Comparação Tonemapping Filmic", {"sun": true, "sun_nrg": 0.85, "ambient_nrg": 0.35, "tonemap": Environment.TONE_MAPPER_FILMIC})
	await _run_test("test_e_materials_calibrated", "Teste E — Materiais com Albedo e Foliage Corrigidos", {"sun": true, "sun_nrg": 0.85, "ambient_nrg": 0.35, "tonemap": Environment.TONE_MAPPER_FILMIC, "calibrated_mats": true})
	await _run_test("test_f_shadows_firm", "Teste F — Sombras Firmes com Silhueta Definida", {"sun": true, "sun_nrg": 0.85, "ambient_nrg": 0.35, "tonemap": Environment.TONE_MAPPER_FILMIC, "calibrated_mats": true, "firm_shadows": true})
	
	print("=== PROTOCOLO DE CALIBRAÇÃO CONCLUÍDO ===")
	quit(0)

func _run_test(test_id: String, test_name: String, params: Dictionary) -> void:
	print("\n>>> EXECUTANDO: ", test_name, " (", test_id, ")")
	var root_vp := get_root()
	
	var scene := Node3D.new()
	scene.name = "CalibrationStage"
	root_vp.add_child(scene)
	
	# 1. WorldEnvironment
	var w_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.16, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	# Ambiente neutro levemente azulado de céu natural
	env.ambient_light_color = Color(0.50, 0.56, 0.64)
	env.ambient_light_energy = float(params.get("ambient_nrg", 0.35))
	env.tonemap_mode = int(params.get("tonemap", Environment.TONE_MAPPER_FILMIC))
	env.tonemap_exposure = 0.95
	w_env.environment = env
	scene.add_child(w_env)
	
	# 2. Sun (DirectionalLight3D)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0) # Inclinado estilo Albion Online
	sun.light_color = Color(1.0, 0.97, 0.92) # Luz solar quente moderada
	var sun_active: bool = params.get("sun", true)
	sun.visible = sun_active
	sun.light_energy = float(params.get("sun_nrg", 0.85)) if sun_active else 0.0
	
	# Sombras
	sun.shadow_enabled = sun_active
	if params.get("firm_shadows", false):
		sun.shadow_blur = 0.8 # Sombra firme e definida como no Albion!
		sun.shadow_bias = 0.015
		sun.directional_shadow_max_distance = 35.0
	else:
		sun.shadow_blur = 1.25
		sun.shadow_bias = 0.03
		sun.directional_shadow_max_distance = 45.0
	scene.add_child(sun)
	
	# 3. Superfícies de Calibração lado a lado no chão
	# Cada patch mede 4m x 4m
	var patches := [
		{"name": "Grama", "x": -6.0, "z": 0.0, "type": "grass"},
		{"name": "Terra", "x": -2.0, "z": 0.0, "type": "dirt"},
		{"name": "Pedra", "x": 2.0, "z": 0.0, "type": "stone"},
		{"name": "CinzaNeutro", "x": 6.0, "z": 0.0, "type": "neutral_gray"}
	]
	
	var is_calibrated: bool = params.get("calibrated_mats", false)
	
	for p in patches:
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(3.8, 3.8)
		mi.mesh = plane
		mi.position = Vector3(p["x"], 0.0, p["z"])
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scene.add_child(mi)
		
		var mat := StandardMaterial3D.new()
		match p["type"]:
			"grass":
				if is_calibrated:
					# Grama verde oliva natural calibrada estilo Albion (menos amarelada e luminosa)
					mat.albedo_color = Color(0.24, 0.32, 0.14) # Oliva terroso equilibrado
				else:
					# Cor atual da textura 01_grama_base.png
					mat.albedo_color = Color(0.30, 0.35, 0.10) # Amarelada
				mat.roughness = 0.95
			"dirt":
				if is_calibrated:
					# Terra marrom suave (menos saturada e mais escura)
					mat.albedo_color = Color(0.38, 0.28, 0.20)
				else:
					# Cor atual de 02_terra_base.png
					mat.albedo_color = Color(0.54, 0.38, 0.25)
				mat.roughness = 0.95
			"stone":
				mat.albedo_color = Color(0.26, 0.29, 0.32)
				mat.roughness = 0.90
			"neutral_gray":
				mat.albedo_color = Color(0.50, 0.50, 0.50) # 50% sRGB cinza padrão de calibração
				mat.roughness = 1.0
		mi.material_override = mat
	
	# Chao de apoio geral
	var base_ground := MeshInstance3D.new()
	var bg_plane := PlaneMesh.new()
	bg_plane.size = Vector2(30.0, 30.0)
	base_ground.mesh = bg_plane
	base_ground.position = Vector3(0.0, -0.01, 0.0)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color(0.18, 0.22, 0.14)
	bg_mat.roughness = 0.95
	base_ground.material_override = bg_mat
	base_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.add_child(base_ground)
	
	# 4. Árvore (Tree.glb ou Pine.glb) posicionada para projetar sombra sobre a grama e terra
	var tree_scene := load("res://assets/nature_megakit/Tree.glb") as PackedScene
	if tree_scene:
		var tree_node: Node3D = tree_scene.instantiate() as Node3D
		tree_node.position = Vector3(-4.0, 0.0, -2.5)
		scene.add_child(tree_node)
		# Ajusta material de folha para não usar LAMBERT_WRAP se calibrado
		var tree_meshes := tree_node.find_children("", "MeshInstance3D", true, false)
		for tm in tree_meshes:
			var t_mi := tm as MeshInstance3D
			t_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if is_calibrated:
				for s in range(t_mi.mesh.get_surface_count()):
					var orig_m = t_mi.mesh.surface_get_material(s)
					if orig_m is StandardMaterial3D:
						var sm := orig_m.duplicate() as StandardMaterial3D
						sm.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY # Volume e sombras reais na copa!
						sm.roughness = 0.85
						sm.metallic = 0.0
						t_mi.set_surface_override_material(s, sm)
	
	# 5. Rocha Média
	var rock_scene := load("res://assets/nature_megakit/Rock Medium.glb") as PackedScene
	if rock_scene:
		var rock_node: Node3D = rock_scene.instantiate() as Node3D
		rock_node.position = Vector3(1.5, 0.0, -2.0)
		scene.add_child(rock_node)
		for rm in rock_node.find_children("", "MeshInstance3D", true, false):
			(rm as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	
	# 6. Guerreiro (Player / knight.glb)
	var knight_scene := load("res://assets/models/knight.glb") as PackedScene
	if knight_scene:
		var knight_node: Node3D = knight_scene.instantiate() as Node3D
		knight_node.position = Vector3(0.0, 0.0, 0.8)
		knight_node.rotation_degrees = Vector3(0.0, 180.0, 0.0) # De frente para a camera
		scene.add_child(knight_node)
		for km in knight_node.find_children("", "MeshInstance3D", true, false):
			var k_mi := km as MeshInstance3D
			k_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			if is_calibrated:
				# Calibrar armadura: Steel_Light com albedo menos estourado e roughness adequado
				for s in range(k_mi.mesh.get_surface_count()):
					var km_orig = k_mi.mesh.surface_get_material(s)
					if km_orig is StandardMaterial3D:
						var k_sm := km_orig.duplicate() as StandardMaterial3D
						if k_sm.resource_name == "Steel_Light":
							# Em vez de 0.86, usar 0.62 (aço polido sem estourar branco)
							k_sm.albedo_color = Color(0.62, 0.64, 0.68)
							k_sm.roughness = 0.50
						elif k_sm.resource_name == "Steel":
							k_sm.albedo_color = Color(0.52, 0.54, 0.58)
							k_sm.roughness = 0.55
						elif k_sm.resource_name == "Blade":
							k_sm.albedo_color = Color(0.70, 0.72, 0.76)
							k_sm.roughness = 0.40
						k_mi.set_surface_override_material(s, k_sm)

	# 7. Câmera Isométrica Idêntica à do Jogo
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 9.2
	cam.position = Vector3(6.6, 8.8, 6.6)
	scene.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0.0, 0.65, 0.0), Vector3.UP)
	
	# Aguarda frames para renderizacao completa
	for f in range(6):
		await process_frame
		
	var tex := root_vp.get_texture()
	var img := tex.get_image()
	var out_path := "C:/Users/mathh/.gemini/antigravity/brain/449434f6-2437-4244-9cef-d5bd6928f462/" + test_id + ".png"
	img.save_png(out_path)
	print("  Salvo print em: ", out_path)
	
	scene.queue_free()
	for f in range(2):
		await process_frame
