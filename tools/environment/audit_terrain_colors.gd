extends SceneTree

func _init() -> void:
	print("--- AUDIT TERRAIN TEXTURES COLORS ---")
	var textures := [
		"res://assets/terrain_v2/textures/01_grama_base.png",
		"res://assets/terrain_v2/textures/02_terra_base.png",
		"res://assets/terrain_v2/textures/03_pedra_base.png"
	]
	for path in textures:
		var t := load(path) as Texture2D
		if t:
			var img := t.get_image()
			if img.is_compressed():
				img.decompress()
			var sum := Color(0, 0, 0, 0)
			var count := 0
			for y in range(0, img.get_height(), 8):
				for x in range(0, img.get_width(), 8):
					sum += img.get_pixel(x, y)
					count += 1
			var avg: Color = sum / float(count)
			print(path.get_file(), " -> Avg RGB: ", avg, " (H: ", avg.h * 360.0, " S: ", avg.s, " V: ", avg.v, ")")
	quit(0)
