extends SceneTree

func _init() -> void:
	call_deferred("_run_render")

func _run_render() -> void:
	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)
	
	var scene := Node3D.new()
	root_vp.add_child(scene)
	
	# Iluminação Exterior Calibrada
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.light_energy = 0.84
	sun.shadow_enabled = true
	sun.shadow_blur = 0.85
	sun.shadow_bias = 0.015
	scene.add_child(sun)
	
	var w_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.16, 0.20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.50, 0.56, 0.64)
	env.ambient_light_energy = 0.36
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.92
	w_env.environment = env
	scene.add_child(w_env)
	
	# Chao
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(25.0, 25.0)
	ground.mesh = plane
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color(0.24, 0.32, 0.14) # Verde oliva
	g_mat.roughness = 0.95
	ground.material_override = g_mat
	scene.add_child(ground)
	
	# Heroi atras da arvore
	var knight_sc := load("res://assets/models/knight.glb") as PackedScene
	var knight := knight_sc.instantiate() as Node3D
	knight.position = Vector3(-1.0, 0.0, -1.0) # Posicionado atras da arvore na linha de visao
	scene.add_child(knight)
	
	# Arvore na frente do heroi
	var tree_sc := load("res://assets/nature_megakit/Tree.glb") as PackedScene
	var tree := tree_sc.instantiate() as Node3D
	tree.position = Vector3(0.5, 0.0, 0.5)
	scene.add_child(tree)
	
	# Carrega o shader de dither
	var shader = load("res://assets/shaders/nature_foliage_dither.gdshader") as Shader
	var foliage_mat := ShaderMaterial.new()
	foliage_mat.shader = shader
	var leaf_tex = load("res://assets/nature_megakit/Tree_Leaves_NormalTree_C.png") as Texture2D
	foliage_mat.set_shader_parameter("albedo_texture", leaf_tex)
	foliage_mat.set_shader_parameter("alpha_scissor_threshold", 0.50)
	foliage_mat.set_shader_parameter("foliage_tint", Color(0.95, 1.0, 0.92))
	
	# Configura copa com o shader dither e tronco com material opaco
	var canopy_meshes: Array[MeshInstance3D] = []
	for c in tree.find_children("", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		for s in range(mi.mesh.get_surface_count()):
			var orig = mi.mesh.surface_get_material(s)
			if orig is StandardMaterial3D and ("Leaf" in orig.resource_name or "Leaves" in orig.resource_name):
				mi.set_surface_override_material(s, foliage_mat)
				canopy_meshes.append(mi)
			else:
				# Tronco 100% opaco
				var tm := (orig as StandardMaterial3D).duplicate() as StandardMaterial3D
				tm.metallic = 0.0
				tm.roughness = 0.90
				mi.set_surface_override_material(s, tm)
				
	# Camera isometrica
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 7.5
	cam.position = Vector3(6.6, 8.8, 6.6)
	scene.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0.0, 1.0, 0.0), Vector3.UP)
	
	# 1. Captura Estado Sólido (fade_amount = 1.0)
	for m in canopy_meshes:
		m.set_instance_shader_parameter("fade_amount", 1.0)
	for f in range(5):
		await process_frame
	var img1 = root_vp.get_texture().get_image()
	img1.save_png("C:/Users/mathh/.gemini/antigravity/brain/449434f6-2437-4244-9cef-d5bd6928f462/tree_dither_solid.png")
	print("Salvo: tree_dither_solid.png")
	
	# 2. Captura Estado Faded (fade_amount = 0.35)
	for m in canopy_meshes:
		m.set_instance_shader_parameter("fade_amount", 0.35)
	for f in range(5):
		await process_frame
	var img2 = root_vp.get_texture().get_image()
	img2.save_png("C:/Users/mathh/.gemini/antigravity/brain/449434f6-2437-4244-9cef-d5bd6928f462/tree_dither_faded.png")
	print("Salvo: tree_dither_faded.png")
	
	scene.queue_free()
	quit(0)
