extends SceneTree

const ARTIFACT_DIR: String = "C:/Users/mathh/.gemini/antigravity/brain/449434f6-2437-4244-9cef-d5bd6928f462"

func _init() -> void:
	print("Iniciando captura de telas da interação e hover dos NPCs/Waypoint...")
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

	# 1. Captura com placas em repouso
	var img1 := vp.get_texture().get_image()
	if img1 != null:
		var p1 := "%s/interaction_plates_normal.png" % ARTIFACT_DIR
		img1.save_png(p1)
		print("Screenshot 1 salva: %s" % p1)

	# 2. Ativa hover no Waypoint (Borda Grossa de 3px e Glow)
	var stations = main_node.get("_active_interactables")
	if stations != null:
		for st in stations:
			if st.station_id == "waypoint":
				st._on_plate_mouse_entered()
				break

	for i in range(10):
		await process_frame

	var img2 := vp.get_texture().get_image()
	if img2 != null:
		var p2 := "%s/interaction_waypoint_hover_thick_border.png" % ARTIFACT_DIR
		img2.save_png(p2)
		print("Screenshot 2 salva: %s" % p2)

	print("Capturas concluídas com sucesso!")
	quit(0)
