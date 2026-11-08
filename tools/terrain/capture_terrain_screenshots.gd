extends SceneTree

const ARTIFACT_DIR: String = "C:/Users/mathh/.gemini/antigravity/brain/449434f6-2437-4244-9cef-d5bd6928f462"

func _init() -> void:
	print("Iniciando captura de telas do terreno estilizado...")
	_capture_process()

func _capture_process() -> void:
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main_node: Node = main_scene.instantiate()
	root.add_child(main_node)

	for i in range(3):
		await process_frame

	if main_node.has_method("_start_campaign_mode"):
		main_node.call("_start_campaign_mode")

	var vp := root.get_viewport()

	for i in range(15):
		await process_frame

	# 1. Captura Vila de Velen com iluminação clara permanente
	var img1 := vp.get_texture().get_image()
	if img1 != null:
		var path1 := "%s/terrain_preview_town_day.png" % ARTIFACT_DIR
		img1.save_png(path1)
		print("Screenshot 1 salva: %s" % path1)

	# 2. Captura Zona 1 (Estrada Profanada) mostrando a Trilha Orgânica Curva
	if main_node.has_method("_load_campaign_zone"):
		main_node.call("_load_campaign_zone", "zone_1_road")
	for i in range(12):
		await process_frame

	var img2 := vp.get_texture().get_image()
	if img2 != null:
		var path2 := "%s/terrain_preview_road_day.png" % ARTIFACT_DIR
		img2.save_png(path2)
		print("Screenshot 2 salva: %s" % path2)

	print("Captura concluída com sucesso!")
	quit(0)
