extends RefCounted
class_name SpatialInventoryGrid
## Motor de inventário espacial 2D em grid (estilo Diablo 2 / Path of Exile).
## Gerencia posicionamento, colisão e encaixe de itens de tamanhos variados (1x1, 2x2, 2x3, 2x4).

signal grid_changed()

var columns: int = 10
var rows: int = 4
var _grid: Array = []                  ## Array bidimensional [y][x] com referências ao ItemInstance ou null
var items: Array[ItemInstance] = []


func _init(p_columns: int = 10, p_rows: int = 4) -> void:
	columns = p_columns
	rows = p_rows
	_reset_cells()


func _reset_cells() -> void:
	_grid.clear()
	for y in range(rows):
		var row: Array = []
		for x in range(columns):
			row.append(null)
		_grid.append(row)


func clear() -> void:
	items.clear()
	_reset_cells()
	grid_changed.emit()


func is_valid_cell(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < columns and pos.y >= 0 and pos.y < rows


func get_item_at(cell: Vector2i) -> ItemInstance:
	if not is_valid_cell(cell):
		return null
	return _grid[cell.y][cell.x] as ItemInstance


func can_place_at(item: ItemInstance, top_left: Vector2i, ignore_item: ItemInstance = null) -> bool:
	if item == null or item.definition == null:
		return false
	var size: Vector2i = item.get_grid_size()
	if top_left.x < 0 or top_left.y < 0:
		return false
	if top_left.x + size.x > columns or top_left.y + size.y > rows:
		return false

	for y in range(top_left.y, top_left.y + size.y):
		for x in range(top_left.x, top_left.x + size.x):
			var existing: ItemInstance = _grid[y][x] as ItemInstance
			if existing != null and existing != ignore_item:
				return false
	return true


func place_item(item: ItemInstance, top_left: Vector2i) -> bool:
	if not can_place_at(item, top_left, item):
		return false

	# Se o item já estava no grid, limpa suas células anteriores
	if items.has(item):
		_clear_item_from_cells(item)
	else:
		items.append(item)

	var size: Vector2i = item.get_grid_size()
	item.grid_position = top_left
	for y in range(top_left.y, top_left.y + size.y):
		for x in range(top_left.x, top_left.x + size.x):
			_grid[y][x] = item

	grid_changed.emit()
	return true


func rotate_item_in_place(item: ItemInstance) -> bool:
	if item == null or not items.has(item) or not item.can_rotate():
		return false
	var old_pos: Vector2i = item.grid_position
	_clear_item_from_cells(item)
	item.toggle_rotation()

	# Tenta encaixar na mesma posição ou com leve ajuste de borda
	var new_size: Vector2i = item.get_grid_size()
	var clamped_pos := Vector2i(
		clampi(old_pos.x, 0, maxi(0, columns - new_size.x)),
		clampi(old_pos.y, 0, maxi(0, rows - new_size.y))
	)
	var candidate_positions: Array[Vector2i] = [old_pos, clamped_pos]
	for cand in candidate_positions:
		if can_place_at(item, cand, item):
			item.grid_position = cand
			for y in range(cand.y, cand.y + new_size.y):
				for x in range(cand.x, cand.x + new_size.x):
					_grid[y][x] = item
			grid_changed.emit()
			return true

	# Reverte se colidir com outros itens adjacentes
	item.toggle_rotation()
	var orig_size: Vector2i = item.get_grid_size()
	for y in range(old_pos.y, old_pos.y + orig_size.y):
		for x in range(old_pos.x, old_pos.x + orig_size.x):
			_grid[y][x] = item
	return false


func remove_item(item: ItemInstance) -> bool:
	if item == null or not items.has(item):
		return false
	_clear_item_from_cells(item)
	items.erase(item)
	item.grid_position = Vector2i(-1, -1)
	grid_changed.emit()
	return true


func _clear_item_from_cells(item: ItemInstance) -> void:
	if item == null:
		return
	for y in range(rows):
		for x in range(columns):
			if _grid[y][x] == item:
				_grid[y][x] = null


func find_free_spot_for(item: ItemInstance) -> Vector2i:
	if item == null or item.definition == null:
		return Vector2i(-1, -1)
	var size: Vector2i = item.get_grid_size()
	# Varre o grid de cima para baixo, da esquerda para a direita (estilo Diablo)
	for y in range(rows - size.y + 1):
		for x in range(columns - size.x + 1):
			var test_pos := Vector2i(x, y)
			if can_place_at(item, test_pos):
				return test_pos
	return Vector2i(-1, -1)


func can_fit_item(item: ItemInstance) -> bool:
	if item == null or item.definition == null:
		return false
	if find_free_spot_for(item).x >= 0:
		return true
	if item.can_rotate():
		item.toggle_rotation()
		var spot: Vector2i = find_free_spot_for(item)
		item.toggle_rotation()
		if spot.x >= 0:
			return true
	return false


func auto_add_item(item: ItemInstance) -> bool:
	if item == null:
		return false
	var spot: Vector2i = find_free_spot_for(item)
	if spot.x >= 0:
		return place_item(item, spot)
	# Se não couber na orientação atual e puder girar, tenta girar automaticamente para caber!
	if item.can_rotate():
		item.toggle_rotation()
		spot = find_free_spot_for(item)
		if spot.x >= 0:
			return place_item(item, spot)
		item.toggle_rotation()
	return false # Mochila cheia para o tamanho do item


func try_place_items_transactionally(items_to_place: Array[ItemInstance], preferred_first_pos: Vector2i = Vector2i(-1, -1)) -> bool:
	## Tenta acomodar TODOS os itens da lista no grid (testando posição preferencial e rotações).
	## Se qualquer item não couber, desfaz (rollback) todas as alterações e restaura o estado exato anterior.
	if items_to_place.is_empty():
		return true

	# Snapshot do estado atual do grid e das rotações dos itens envolvidos
	var snapshot_grid: Array[Dictionary] = []
	for existing in items:
		if existing != null:
			snapshot_grid.append({
				"item": existing,
				"pos": existing.grid_position,
				"rot": existing.is_rotated,
			})
	var snapshot_incoming_rot: Dictionary = {}
	for incoming in items_to_place:
		if incoming != null:
			snapshot_incoming_rot[incoming] = incoming.is_rotated

	var all_placed: bool = true
	for idx in range(items_to_place.size()):
		var it: ItemInstance = items_to_place[idx]
		if it == null:
			continue
		var placed_this: bool = false
		if idx == 0 and preferred_first_pos.x >= 0 and preferred_first_pos.y >= 0:
			if can_place_at(it, preferred_first_pos):
				placed_this = place_item(it, preferred_first_pos)
			elif it.can_rotate():
				it.toggle_rotation()
				if can_place_at(it, preferred_first_pos):
					placed_this = place_item(it, preferred_first_pos)
				else:
					it.toggle_rotation()
		if not placed_this:
			placed_this = auto_add_item(it)
		if not placed_this:
			all_placed = false
			break

	if not all_placed:
		# Rollback atômico completo
		items.clear()
		_reset_cells()
		for incoming in snapshot_incoming_rot.keys():
			incoming.is_rotated = bool(snapshot_incoming_rot[incoming])
			incoming.grid_position = Vector2i(-1, -1)
		for entry in snapshot_grid:
			var ex_item: ItemInstance = entry["item"] as ItemInstance
			ex_item.is_rotated = bool(entry["rot"])
			place_item(ex_item, entry["pos"] as Vector2i)
		grid_changed.emit()
		return false

	return true


func get_overlapping_items(item: ItemInstance, top_left: Vector2i) -> Array[ItemInstance]:
	## Retorna todos os itens que seriam sobrepostos (útil para troca/swap na UI).
	var overlapped: Array[ItemInstance] = []
	if item == null or item.definition == null:
		return overlapped
	var size: Vector2i = item.get_grid_size()
	if top_left.x < 0 or top_left.y < 0 or top_left.x + size.x > columns or top_left.y + size.y > rows:
		return overlapped

	for y in range(top_left.y, top_left.y + size.y):
		for x in range(top_left.x, top_left.x + size.x):
			var exist: ItemInstance = _grid[y][x] as ItemInstance
			if exist != null and exist != item and not overlapped.has(exist):
				overlapped.append(exist)
	return overlapped
