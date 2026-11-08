extends SceneTree

const ARTIFACT_DIR: String = "C:/Users/mathh/.gemini/antigravity/brain/449434f6-2437-4244-9cef-d5bd6928f462"

func _init() -> void:
	print("Iniciando captura de telas do terreno estilizado...")
	_capture_process()

func _capture_process() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)

	# Aguarda frames para que _ready() execute completamente
	for i in range(3):
		await process_frame

	# Inicia campanha na Vila de Velen
	if main_node.has_method("_start_campaign_mode"):
		main_node.call("_start_campaign_mode")

	var day_night = main_node.get("day_night_hud")
	var vp := root.get_viewport()

	# Aguarda 10 frames para estabilização de shader e texturas
	for i in range(12):
		await process_frame

	# 1. Captura Vila de Velen ao Meio-Dia (Luz Solar e Sombras Nítidas)
	if day_night != null and day_night.has_method("set_time_of_day"):
		day_night.call("set_time_of_day", 0.50)
	for i in range(8):
		await process_frame

	var img1 := vp.get_texture().get_image()
	if img1 != null:
		var path1 := "%s/terrain_preview_town_day.png" % ARTIFACT_DIR
		img1.save_png(path1)
		print("Screenshot 1 salva: %s" % path1)

	# 2. Captura Vila de Velen à Noite (Luz Omni do Personagem e Luar)
	if day_night != null and day_night.has_method("set_time_of_day"):
		day_night.call("set_time_of_day", 0.0)
	for i in range(8):
		await process_frame

	var img2 := vp.get_texture().get_image()
	if img2 != null:
		var path2 := "%s/terrain_preview_town_night.png" % ARTIFACT_DIR
		img2.save_png(path2)
		print("Screenshot 2 salva: %s" % path2)

	# 3. Captura Zona 1 (Estrada Profanada) mostrando a Trilha Orgânica Curva
	if main_node.has_method("_load_campaign_zone"):
		main_node.call("_load_campaign_zone", "zone_1_road")
	if day_night != null and day_night.has_method("set_time_of_day"):
		day_night.call("set_time_of_day", 0.50)
	for i in range(10):
		await process_frame

	var img3 := vp.get_texture().get_image()
	if img3 != null:
		var path3 := "%s/terrain_preview_road_day.png" % ARTIFACT_DIR
		img3.save_png(path3)
		print("Screenshot 3 salva: %s" % path3)

	print("Captura concluída com sucesso!")
	quit(0)
