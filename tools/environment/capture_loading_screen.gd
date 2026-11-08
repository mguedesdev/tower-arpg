extends SceneTree

const ARTIFACT_DIR := "C:/Users/mathh/.gemini/antigravity/brain/449434f6-2437-4244-9cef-d5bd6928f462/"
const LoadingScreenScript = preload("res://core/loading/loading_screen.gd")

func _init() -> void:
	call_deferred("_render_preview")

func _render_preview() -> void:
	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)

	var screen = LoadingScreenScript.new()
	root_vp.add_child(screen)

	screen.setup_destination(
		"2. FLORESTA DE ARATH",
		"Nível 3 – 6 • Ponte antiga e bosque ribeirinho tomado por mortos-vivos",
		"res://assets/ui/world_map/02_floresta_de_arath.png"
	)
	screen.fade_in(0.0)
	screen.set_step("Preparando terreno e ambientação estilizada...", 0.45)

	# Força atualização visual da barra
	for _f in range(12):
		await process_frame

	var img := root_vp.get_texture().get_image()
	var out_path := ARTIFACT_DIR + "loading_screen_preview.png"
	img.save_png(out_path)
	print("Preview da tela de loading salvo em: ", out_path)

	screen.queue_free()
	for _f in range(2):
		await process_frame
	quit(0)
