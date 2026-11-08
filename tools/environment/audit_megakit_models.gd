@tool
extends SceneTree

func _init() -> void:
	print("\n=================================================================")
	print("AUDITORIA TÉCNICA E CATALOGAÇÃO: STYLIZED NATURE MEGAKIT (68 GLBs)")
	print("=================================================================\n")

	var dir := DirAccess.open("res://assets/nature_megakit")
	if dir == null:
		printerr("Falha ao abrir res://assets/nature_megakit")
		quit(1)
		return

	var files: Array[String] = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.ends_with(".glb"):
			files.append(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()
	files.sort()

	print("Total de arquivos GLB encontrados: %d\n" % files.size())

	var family_stats: Dictionary = {}
	var model_catalog: Array[Dictionary] = []

	for fname in files:
		var full_path := "res://assets/nature_megakit/%s" % fname
		var scene: PackedScene = load(full_path) as PackedScene
		if scene == null:
			printerr("ERRO ao carregar cena: %s" % fname)
			continue

		var root: Node = scene.instantiate()
		if root == null:
			printerr("ERRO ao instanciar cena: %s" % fname)
			continue

		var mesh_instances: Array[MeshInstance3D] = []
		_find_meshes(root, mesh_instances)

		var total_vertices: int = 0
		var total_triangles: int = 0
		var combined_aabb: AABB = AABB()
		var first_mesh: bool = true
		var materials_info: Array[String] = []

		for mi in mesh_instances:
			var m: Mesh = mi.mesh
			if m != null:
				for s in range(m.get_surface_count()):
					var arrays := m.surface_get_arrays(s)
					var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
					total_vertices += verts.size()
					var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
					if indices.size() > 0:
						total_triangles += indices.size() / 3
					else:
						total_triangles += verts.size() / 3

					var mat: Material = mi.get_surface_override_material(s)
					if mat == null:
						mat = m.surface_get_material(s)
					if mat != null:
						var mat_name := mat.resource_name
						if mat_name.is_empty():
							mat_name = mat.get_class()
						if not materials_info.has(mat_name):
							materials_info.append(mat_name)

				var aabb := mi.get_aabb()
				if first_mesh:
					combined_aabb = aabb
					first_mesh = false
				else:
					combined_aabb = combined_aabb.merge(aabb)

		var family := _detect_family(fname)
		if not family_stats.has(family):
			family_stats[family] = {
				"count": 0,
				"total_tris": 0,
				"min_tris": 999999,
				"max_tris": 0,
				"examples": []
			}
		var f_data: Dictionary = family_stats[family]
		f_data["count"] += 1
		f_data["total_tris"] += total_triangles
		f_data["min_tris"] = mini(f_data["min_tris"], total_triangles)
		f_data["max_tris"] = maxi(f_data["max_tris"], total_triangles)
		if f_data["examples"].size() < 3:
			f_data["examples"].append(fname)

		model_catalog.append({
			"file": fname,
			"family": family,
			"triangles": total_triangles,
			"vertices": total_vertices,
			"size": combined_aabb.size,
			"center": combined_aabb.get_center(),
			"min_y": combined_aabb.position.y,
			"max_y": combined_aabb.end.y,
			"materials": materials_info
		})

		root.queue_free()

	# Relatório por Família
	print("-----------------------------------------------------------------")
	print("%-18s | %-5s | %-12s | %-10s | %-10s" % ["Família", "Qtd", "Média Tris", "Min Tris", "Max Tris"])
	print("-----------------------------------------------------------------")
	for f in family_stats.keys():
		var fd: Dictionary = family_stats[f]
		var avg_tris: int = fd["total_tris"] / fd["count"]
		print("%-18s | %-5d | %-12d | %-10d | %-10d" % [f, fd["count"], avg_tris, fd["min_tris"], fd["max_tris"]])

	print("\n-----------------------------------------------------------------")
	print("AMOSTRAGEM DETALHADA DE ESCALAS, AABB E PROPORÇÃO:")
	print("-----------------------------------------------------------------")
	for item in model_catalog:
		# Imprime itens representativos
		if item["file"].ends_with(".glb") and not item["file"].contains("-") or item["triangles"] > 2000 or item["family"] in ["Trees", "Pines", "DeadTrees", "Rocks", "Paths"]:
			var sz: Vector3 = item["size"]
			print("%-32s [%-10s] Tris: %-5d | Tam: (%.2f, %.2f, %.2f)m | Y:[%.2f..%.2f]" % [
				item["file"], item["family"], item["triangles"], sz.x, sz.y, sz.z, item["min_y"], item["max_y"]
			])

	print("\nAUDITORIA DOS GLBs CONCLUÍDA COM SUCESSO!\n")
	quit(0)


func _find_meshes(node: Node, out_list: Array[MeshInstance3D]) -> void:
	if node is MeshInstance3D:
		out_list.append(node as MeshInstance3D)
	for child in node.get_children():
		_find_meshes(child, out_list)


func _detect_family(fname: String) -> String:
	var lower := fname.to_lower()
	if lower.begins_with("tree-") or lower == "tree.glb":
		return "Trees"
	if lower.begins_with("pine"):
		return "Pines"
	if lower.begins_with("twisted tree"):
		return "TwistedTrees"
	if lower.begins_with("dead tree"):
		return "DeadTrees"
	if lower.begins_with("bush"):
		return "Bushes"
	if lower.begins_with("fern"):
		return "Ferns"
	if lower.begins_with("clover"):
		return "Clovers"
	if lower.begins_with("grass wispy"):
		return "GrassWispy"
	if lower.begins_with("grass") or lower.begins_with("tall grass"):
		return "Grass"
	if lower.begins_with("flower single"):
		return "FlowerSingle"
	if lower.begins_with("flower group"):
		return "FlowerGroup"
	if lower.begins_with("flower petal"):
		return "FlowerPetal"
	if lower.begins_with("mushroom"):
		return "Mushrooms"
	if lower.begins_with("plant big"):
		return "PlantBig"
	if lower.begins_with("plant"):
		return "Plants"
	if lower.begins_with("pebble round"):
		return "PebblesRound"
	if lower.begins_with("pebble square"):
		return "PebblesSquare"
	if lower.begins_with("rock medium"):
		return "RocksMedium"
	if lower.begins_with("rock path"):
		return "Paths"
	return "Other"
