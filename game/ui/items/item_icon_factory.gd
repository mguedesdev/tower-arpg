@warning_ignore("integer_division")
extends RefCounted
class_name ItemIconFactory
## Fábrica de ícones para o inventário espacial ARPG.
## • Se o arquivo de imagem PNG/WEBP existir em disco, carrega imediatamente.
## • Se não existir, desenha proceduralmente um ícone estilizado com a proporção exata do slot (1x1, 2x2, 2x3, 2x4).

static var _cache: Dictionary = {}
static var _image_cache: Dictionary = {}
const CELL_PX: int = 32


static func get_icon_for_item(item: ItemInstance, for_paperdoll: bool = false) -> Texture2D:
	if item == null or item.definition == null:
		return null
	var def: ItemDefinition = item.definition
	if for_paperdoll:
		# No Paperdoll (ex: Mão Principal), armas/itens deitados (x > y, exceto Cinto) ficam automaticamente EM PÉ!
		var force_rot_for_upright: bool = (
			def.grid_size.x > def.grid_size.y
			and def.category != ItemDefinition.ItemCategory.BELT
		)
		return get_icon(def, force_rot_for_upright)
	return get_icon(def, item.is_rotated)


static func get_icon(def: ItemDefinition, rotated: bool = false) -> Texture2D:
	if def == null:
		return null
	var key: String = def.base_id + ("__rot" if rotated else "")
	if _cache.has(key):
		return _cache[key] as Texture2D

	var base_img: Image = _get_base_image(def)
	if base_img == null:
		return null

	var final_img: Image = base_img
	if rotated:
		final_img = base_img.duplicate() as Image
		final_img.rotate_90(CLOCKWISE)

	var tex: Texture2D = ImageTexture.create_from_image(final_img)
	_cache[key] = tex
	return tex


static func _get_base_image(def: ItemDefinition) -> Image:
	if _image_cache.has(def.base_id):
		return _image_cache[def.base_id] as Image

	var loaded_img: Image = null
	if not def.icon_path.is_empty():
		var abs_path: String = ProjectSettings.globalize_path(def.icon_path)
		if FileAccess.file_exists(abs_path):
			var file_img := Image.load_from_file(abs_path)
			if file_img != null and not file_img.is_empty():
				loaded_img = file_img
		elif ResourceLoader.exists(def.icon_path):
			var res_tex: Texture2D = load(def.icon_path) as Texture2D
			if res_tex != null:
				loaded_img = res_tex.get_image()

	if loaded_img == null:
		loaded_img = _generate_procedural_image(def)

	_image_cache[def.base_id] = loaded_img
	return loaded_img


static func _generate_procedural_icon(def: ItemDefinition) -> Texture2D:
	return ImageTexture.create_from_image(_generate_procedural_image(def))


static func _generate_procedural_image(def: ItemDefinition) -> Image:
	var w: int = maxi(1, def.grid_size.x) * CELL_PX
	var h: int = maxi(1, def.grid_size.y) * CELL_PX
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.08, 0.07, 0.09, 0.95))

	var border_color := Color(0.35, 0.30, 0.25, 0.9)
	var accent_color := Color(0.85, 0.72, 0.45)
	var steel_color := Color(0.75, 0.80, 0.88)
	var dark_steel := Color(0.40, 0.44, 0.50)

	# Borda sutil de 1px
	for x in range(w):
		img.set_pixel(x, 0, border_color)
		img.set_pixel(x, h - 1, border_color)
	for y in range(h):
		img.set_pixel(0, y, border_color)
		img.set_pixel(w - 1, y, border_color)

	# Desenha silhueta temática conforme categoria
	match def.category:
		ItemDefinition.ItemCategory.WEAPON_2H: # Espada Montante 2H (3x2)
			_draw_greatsword(img, w, h, steel_color, accent_color)
		ItemDefinition.ItemCategory.WEAPON_1H:
			if def.grid_size.x == 1 and def.grid_size.y <= 3: # Adaga (1x3)
				_draw_dagger(img, w, h, steel_color, accent_color)
			else: # Espada Longa 1H (1x4)
				_draw_sword(img, w, h, steel_color, accent_color)
		ItemDefinition.ItemCategory.SHIELD:
			_draw_shield(img, w, h, dark_steel, accent_color)
		ItemDefinition.ItemCategory.CHEST:
			_draw_chestplate(img, w, h, steel_color, accent_color)
		ItemDefinition.ItemCategory.HELMET:
			_draw_helmet(img, w, h, steel_color, accent_color)
		ItemDefinition.ItemCategory.BOOTS:
			_draw_boots(img, w, h, dark_steel, accent_color)
		ItemDefinition.ItemCategory.GLOVES:
			_draw_gloves(img, w, h, dark_steel, accent_color)
		ItemDefinition.ItemCategory.BELT:
			_draw_belt(img, w, h, Color(0.55, 0.35, 0.20), accent_color)
		ItemDefinition.ItemCategory.RING:
			_draw_ring(img, w, h, accent_color, Color(0.95, 0.25, 0.25))
		ItemDefinition.ItemCategory.AMULET:
			_draw_amulet(img, w, h, accent_color, Color(0.25, 0.85, 0.95))
		ItemDefinition.ItemCategory.CONSUMABLE:
			_draw_potion(img, w, h, Color(0.95, 0.20, 0.20))
		_:
			_draw_generic_box(img, w, h, accent_color)

	return img


static func _draw_greatsword(img: Image, w: int, h: int, steel: Color, gold: Color) -> void:
	var cx: int = w / 2
	# Lâmina longa e larga
	for y in range(8, h - 22):
		var thick: int = 3 if y > 14 else 2
		for x in range(cx - thick, cx + thick + 1):
			img.set_pixel(x, y, steel)
		# Linha de corte central brilhante
		img.set_pixel(cx, y, steel.lightened(0.25))
	# Ponta
	img.set_pixel(cx, 6, steel)
	img.set_pixel(cx, 7, steel)
	# Guarda cruzada dourada larga
	var guard_y: int = h - 22
	for x in range(cx - 14, cx + 15):
		img.set_pixel(x, guard_y, gold)
		img.set_pixel(x, guard_y + 1, gold)
	# Cabo e Pomo
	for y in range(guard_y + 2, h - 8):
		img.set_pixel(cx, y, Color(0.4, 0.25, 0.15))
		img.set_pixel(cx - 1, y, Color(0.3, 0.2, 0.1))
	for x in range(cx - 2, cx + 3):
		for y in range(h - 8, h - 5):
			img.set_pixel(x, y, gold)


static func _draw_sword(img: Image, w: int, h: int, steel: Color, gold: Color) -> void:
	var cx: int = w / 2
	for y in range(6, h - 18):
		for x in range(cx - 2, cx + 3):
			if x >= 0 and x < w:
				img.set_pixel(x, y, steel)
		if cx >= 0 and cx < w:
			img.set_pixel(cx, y, steel.lightened(0.25))
	var guard_y: int = h - 18
	for x in range(cx - 7, cx + 8):
		if x >= 0 and x < w:
			img.set_pixel(x, guard_y, gold)
	for y in range(guard_y + 1, h - 6):
		if cx >= 0 and cx < w:
			img.set_pixel(cx, y, Color(0.4, 0.25, 0.15))
	if cx >= 0 and cx < w:
		img.set_pixel(cx, h - 5, gold)


static func _draw_dagger(img: Image, w: int, h: int, steel: Color, gold: Color) -> void:
	var cx: int = w / 2
	for y in range(8, h - 14):
		for x in range(cx - 1, cx + 2):
			if x >= 0 and x < w:
				img.set_pixel(x, y, steel)
	if cx >= 0 and cx < w:
		img.set_pixel(cx, 6, steel)
	var gy: int = h - 14
	for x in range(cx - 5, cx + 6):
		if x >= 0 and x < w:
			img.set_pixel(x, gy, gold)
	for y in range(gy + 1, h - 6):
		if cx >= 0 and cx < w:
			img.set_pixel(cx, y, Color(0.4, 0.25, 0.15))


static func _draw_gloves(img: Image, w: int, h: int, col: Color, gold: Color) -> void:
	# Par de manoplas blindadas distintas e largas (2x2)
	for y in range(12, h - 10):
		# Luva esquerda
		for x in range(8, w / 2 - 4):
			img.set_pixel(x, y, col)
		# Luva direita
		for x in range(w / 2 + 4, w - 8):
			img.set_pixel(x, y, col)
	# Articulações douradas
	for x in range(10, w / 2 - 6):
		img.set_pixel(x, h / 2, gold)
	for x in range(w / 2 + 6, w - 10):
		img.set_pixel(x, h / 2, gold)


static func _draw_shield(img: Image, w: int, h: int, base_col: Color, trim_col: Color) -> void:
	var cx: int = w / 2
	var cy: int = h / 2
	var rad_x: int = w / 2 - 6
	var rad_y: int = h / 2 - 6
	for y in range(6, h - 6):
		for x in range(6, w - 6):
			var dx: float = float(x - cx) / float(rad_x)
			var dy: float = float(y - cy) / float(rad_y)
			if dx * dx + dy * dy <= 1.0:
				img.set_pixel(x, y, base_col)
	# Cruz Dourada no meio
	for y in range(10, h - 10):
		img.set_pixel(cx, y, trim_col)
		img.set_pixel(cx + 1, y, trim_col)
	for x in range(10, w - 10):
		img.set_pixel(x, cy, trim_col)
		img.set_pixel(x, cy + 1, trim_col)


static func _draw_chestplate(img: Image, w: int, h: int, steel: Color, gold: Color) -> void:
	var cx: int = w / 2
	for y in range(10, h - 10):
		var span: int = int(float(w / 2 - 8) * (1.0 - absf(float(y - h / 2) / float(h / 2)) * 0.35))
		for x in range(cx - span, cx + span):
			img.set_pixel(x, y, steel)
	# Reforço peitoral dourado
	for x in range(cx - 12, cx + 13):
		img.set_pixel(x, h / 3, gold)


static func _draw_helmet(img: Image, w: int, h: int, steel: Color, gold: Color) -> void:
	var cx: int = w / 2
	var cy: int = h / 2
	for y in range(12, h - 12):
		for x in range(12, w - 12):
			img.set_pixel(x, y, steel)
	# Viseira em T
	for x in range(16, w - 16):
		img.set_pixel(x, cy, Color(0.1, 0.1, 0.12))
	for y in range(cy, h - 14):
		img.set_pixel(cx, y, Color(0.1, 0.1, 0.12))
	# Crista
	for y in range(6, 12):
		img.set_pixel(cx, y, gold)


static func _draw_boots(img: Image, w: int, h: int, col: Color, gold: Color) -> void:
	for y in range(14, h - 10):
		for x in range(10, w / 2 - 2):
			img.set_pixel(x, y, col)
		for x in range(w / 2 + 2, w - 10):
			img.set_pixel(x, y, col)
	for x in range(8, w - 8):
		img.set_pixel(x, h - 10, gold)


static func _draw_belt(img: Image, w: int, h: int, col: Color, gold: Color) -> void:
	var cy: int = h / 2
	for y in range(cy - 4, cy + 5):
		for x in range(4, w - 4):
			img.set_pixel(x, y, col)
	var cx: int = w / 2
	for y in range(cy - 6, cy + 7):
		for x in range(cx - 5, cx + 6):
			img.set_pixel(x, y, gold)


static func _draw_ring(img: Image, w: int, h: int, gold: Color, gem: Color) -> void:
	var cx: int = w / 2
	var cy: int = h / 2
	var r: float = float(mini(w, h)) * 0.35
	for y in range(h):
		for x in range(w):
			var d: float = sqrt(pow(float(x - cx), 2) + pow(float(y - cy), 2))
			if absf(d - r) < 2.2:
				img.set_pixel(x, y, gold)
	# Gema no topo
	for y in range(cy - int(r) - 2, cy - int(r) + 3):
		for x in range(cx - 2, cx + 3):
			if x >= 0 and x < w and y >= 0 and y < h:
				img.set_pixel(x, y, gem)


static func _draw_amulet(img: Image, w: int, h: int, gold: Color, gem: Color) -> void:
	var cx: int = w / 2
	for y in range(4, h - 8):
		var spread: int = int(float(y - 4) * 0.4)
		if cx - spread >= 0 and cx + spread < w:
			img.set_pixel(cx - spread, y, gold)
			img.set_pixel(cx + spread, y, gold)
	# Pingente
	for y in range(h - 10, h - 3):
		for x in range(cx - 3, cx + 4):
			img.set_pixel(x, y, gem)


static func _draw_potion(img: Image, w: int, h: int, liquid: Color) -> void:
	var cx: int = w / 2
	for y in range(6, 12):
		img.set_pixel(cx, y, Color(0.7, 0.5, 0.3))
	for y in range(12, h - 6):
		var span: int = int(float(w / 2 - 4) * sin(float(y - 12) / float(h - 18) * PI))
		for x in range(cx - span, cx + span + 1):
			img.set_pixel(x, y, liquid)


static func _draw_generic_box(img: Image, w: int, h: int, col: Color) -> void:
	for y in range(4, h - 4):
		for x in range(4, w - 4):
			img.set_pixel(x, y, col.darkened(0.4))
