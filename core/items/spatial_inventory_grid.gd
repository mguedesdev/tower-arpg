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
	var size: Vector2i = item.definition.grid_size
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
	if not can_place_at(item, top_left):
		return false

	# Se o item já estava no grid, limpa suas células anteriores
	if items.has(item):
		_clear_item_from_cells(item)
	else:
		items.append(item)

	var size: Vector2i = item.definition.grid_size
	item.grid_position = top_left
	for y in range(top_left.y, top_left.y + size.y):
		for x in range(top_left.x, top_left.x + size.x):
			_grid[y][x] = item

	grid_changed.emit()
	return true


func remove_item(item: ItemInstance) -> bool:
	if item == null or not items.has(item):
		return false
	_clear_item_from_cells(item)
	items.erase(item)
	item.grid_position = Vector2i(-1, -1)
	grid_changed.emit()
	return true


func _clear_item_from_cells(item: ItemInstance) -> void:
	if item == null or item.grid_position.x < 0:
		return
	var pos: Vector2i = item.grid_position
	var size: Vector2i = item.definition.grid_size
	for y in range(maxi(0, pos.y), mini(rows, pos.y + size.y)):
		for x in range(maxi(0, pos.x), mini(columns, pos.x + size.x)):
			if _grid[y][x] == item:
				_grid[y][x] = null


func find_free_spot_for(item: ItemInstance) -> Vector2i:
	if item == null or item.definition == null:
		return Vector2i(-1, -1)
	var size: Vector2i = item.definition.grid_size
	# Varre o grid de cima para baixo, da esquerda para a direita (estilo Diablo)
	for y in range(rows - size.y + 1):
		for x in range(columns - size.x + 1):
			var test_pos := Vector2i(x, y)
			if can_place_at(item, test_pos):
				return test_pos
	return Vector2i(-1, -1)


func auto_add_item(item: ItemInstance) -> bool:
	var spot: Vector2i = find_free_spot_for(item)
	if spot.x < 0:
		return false # Mochila cheia para o tamanho do item
	return place_item(item, spot)


func get_overlapping_items(item: ItemInstance, top_left: Vector2i) -> Array[ItemInstance]:
	## Retorna todos os itens que seriam sobrepostos (útil para troca/swap na UI).
	var overlapped: Array[ItemInstance] = []
	if item == null or item.definition == null:
		return overlapped
	var size: Vector2i = item.definition.grid_size
	if top_left.x < 0 or top_left.y < 0 or top_left.x + size.x > columns or top_left.y + size.y > rows:
		return overlapped

	for y in range(top_left.y, top_left.y + size.y):
		for x in range(top_left.x, top_left.x + size.x):
			var exist: ItemInstance = _grid[y][x] as ItemInstance
			if exist != null and exist != item and not overlapped.has(exist):
				overlapped.append(exist)
	return overlapped
