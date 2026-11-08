extends SceneTree

func _init() -> void:
	call_deferred("_render_all_profiles")

func _render_all_profiles() -> void:
	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)
	
	var zones_to_capture := [
		{"id": "zone_1_road", "name": "Cena A — Floresta Natural (Exterior)", "file": "lighting_scene_a_forest.png"},
		{"id": "zone_3_crypt", "name": "Cena B — Masmorra (Interior)", "file": "lighting_scene_b_dungeon.png"},
		{"id": "zone_4_mines", "name": "Cena C — Floresta Mágica (Temático)", "file": "lighting_scene_c_mystic.png"}
	]
	
	for item in zones_to_capture:
		var z_id: String = item["id"]
		var out_file: String = item["file"]
		print("\n--- RENDERIZANDO: ", item["name"], " (", z_id, ") ---")
		
		var game_scene: PackedScene = load("res://scenes/arpg/arpg_game.tscn")
		var game: Node3D = game_scene.instantiate() as Node3D
		root_vp.add_child(game)
		
		# Aguarda inicializacao
		for f in range(6):
			await process_frame
			
		# Carrega a zona correspondente
		if game.has_method("load_zone"):
			game.call("load_zone", z_id)
		
		# Aguarda propagacao de mesh e luzes
		for f in range(10):
			await process_frame
			
		var tex := root_vp.get_texture()
		var img := tex.get_image()
		var out_path := "C:/Users/mathh/.gemini/antigravity/brain/449434f6-2437-4244-9cef-d5bd6928f462/" + out_file
		img.save_png(out_path)
		print("Salvo com sucesso em: ", out_path)
		
		game.queue_free()
		for f in range(3):
			await process_frame

	print("\n=== TODAS AS 3 CENAS CAPTURADAS COM SUCESSO! ===")
	quit(0)
