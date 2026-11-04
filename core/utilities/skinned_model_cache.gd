extends RefCounted
class_name SkinnedModelCache
## Otimizador e cache em memória de PackedScene para modelos GLB (Esqueleto, Cavaleiro, Lobo).
## Unifica dezenas de MeshInstance3D filhos do mesmo Skeleton3D (80 no esqueleto, 57 no cavaleiro)
## em um ÚNICO MeshInstance3D com vertex colors e empacota em um PackedScene otimizado.
## Isso evita que o Godot sequer instancie as 80 malhas originais nos spawns seguintes
## e não mantém nenhum Node órfão fora da SceneTree.

static var _cached_scenes: Dictionary = {}
static var _shared_hit_flash_materials: Array[StandardMaterial3D] = []


static func instantiate_optimized(glb_path: String) -> Node3D:
	if not _cached_scenes.has(glb_path):
		if not ResourceLoader.exists(glb_path):
			return null
		var raw_packed: PackedScene = load(glb_path) as PackedScene
		if raw_packed == null:
			return null
		var prototype: Node3D = raw_packed.instantiate() as Node3D
		if prototype == null:
			return null
		prototype.scene_file_path = ""
		_optimize_hierarchy_in_place(prototype)
		_assign_owner_recursive(prototype, prototype)
		var optimized_packed := PackedScene.new()
		var err: Error = optimized_packed.pack(prototype)
		prototype.free()
		if err == OK:
			_cached_scenes[glb_path] = optimized_packed
		else:
			_cached_scenes[glb_path] = raw_packed

	var packed_to_use: PackedScene = _cached_scenes[glb_path] as PackedScene
	if packed_to_use == null:
		return null
	return packed_to_use.instantiate() as Node3D


static func _assign_owner_recursive(node: Node, root_owner: Node) -> void:
	for child in node.get_children():
		child.scene_file_path = ""
		child.owner = root_owner
		_assign_owner_recursive(child, root_owner)


static func get_hit_flash_material(fade_ratio: float, max_opacity: float = 0.22) -> StandardMaterial3D:
	if _shared_hit_flash_materials.is_empty():
		var steps: int = 4
		for i in range(steps):
			var alpha_factor: float = float(i + 1) / float(steps)
			var mat := StandardMaterial3D.new()
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mat.albedo_color = Color(1.0, 0.12, 0.14, max_opacity * alpha_factor)
			_shared_hit_flash_materials.append(mat)
	var idx: int = clampi(int(ceilf(clampf(fade_ratio, 0.01, 1.0) * float(_shared_hit_flash_materials.size()))) - 1, 0, _shared_hit_flash_materials.size() - 1)
	return _shared_hit_flash_materials[idx]


static func _optimize_hierarchy_in_place(root: Node3D) -> void:
	var skeletons: Array[Node] = root.find_children("*", "Skeleton3D", true, false)
	for skel_node in skeletons:
		var skeleton: Skeleton3D = skel_node as Skeleton3D
		if skeleton == null:
			continue
		_merge_skeleton_meshes(skeleton)


static func _merge_skeleton_meshes(skeleton: Skeleton3D) -> void:
	var candidates: Array[MeshInstance3D] = []
	var shared_skin: Skin = null

	for child in skeleton.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh != null and mi.skin != null and mi.transform.is_equal_approx(Transform3D.IDENTITY):
				if shared_skin == null:
					shared_skin = mi.skin
				if mi.skin == shared_skin:
					candidates.append(mi)

	if candidates.size() <= 1:
		return

	var body_verts := PackedVector3Array()
	var body_normals := PackedVector3Array()
	var body_colors := PackedColorArray()
	var body_bones := PackedInt32Array()
	var body_weights := PackedFloat32Array()
	var body_indices := PackedInt32Array()
	var roughness_sum: float = 0.0
	var roughness_count: int = 0

	var special_buckets: Dictionary = {}

	for mi in candidates:
		var mesh: Mesh = mi.mesh
		var surf_count: int = mesh.get_surface_count()
		for s in range(surf_count):
			var arrays: Array = mesh.surface_get_arrays(s)
			if arrays.size() <= Mesh.ARRAY_WEIGHTS:
				continue
			if arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_BONES] == null or arrays[Mesh.ARRAY_WEIGHTS] == null:
				continue
			var s_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var s_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL] if arrays[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
			var s_bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var s_weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var s_indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			var v_count: int = s_verts.size()
			if v_count == 0 or s_bones.size() != v_count * 4 or s_weights.size() != v_count * 4:
				continue

			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			var std_mat: StandardMaterial3D = mat as StandardMaterial3D

			var is_simple_opaque: bool = (
				std_mat != null
				and not std_mat.emission_enabled
				and std_mat.albedo_texture == null
				and std_mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED
			)

			if is_simple_opaque:
				var base_offset: int = body_verts.size()
				body_verts.append_array(s_verts)
				if s_normals.size() == v_count:
					body_normals.append_array(s_normals)
				else:
					for _i in range(v_count):
						body_normals.append(Vector3.UP)
				var col: Color = std_mat.albedo_color
				var col_arr := PackedColorArray()
				col_arr.resize(v_count)
				col_arr.fill(col)
				body_colors.append_array(col_arr)
				body_bones.append_array(s_bones)
				body_weights.append_array(s_weights)
				if s_indices.size() > 0:
					for idx in s_indices:
						body_indices.append(base_offset + idx)
				else:
					for idx in range(v_count):
						body_indices.append(base_offset + idx)
				roughness_sum += std_mat.roughness
				roughness_count += 1
			else:
				var key: Variant = mat
				if key == null:
					key = "default"
				if not special_buckets.has(key):
					special_buckets[key] = {
						"material": mat,
						"verts": PackedVector3Array(),
						"normals": PackedVector3Array(),
						"bones": PackedInt32Array(),
						"weights": PackedFloat32Array(),
						"indices": PackedInt32Array(),
					}
				var bucket: Dictionary = special_buckets[key]
				var b_verts: PackedVector3Array = bucket["verts"]
				var b_normals: PackedVector3Array = bucket["normals"]
				var b_bones: PackedInt32Array = bucket["bones"]
				var b_weights: PackedFloat32Array = bucket["weights"]
				var b_indices: PackedInt32Array = bucket["indices"]
				var b_offset: int = b_verts.size()
				b_verts.append_array(s_verts)
				if s_normals.size() == v_count:
					b_normals.append_array(s_normals)
				else:
					for _i in range(v_count):
						b_normals.append(Vector3.UP)
				b_bones.append_array(s_bones)
				b_weights.append_array(s_weights)
				if s_indices.size() > 0:
					for idx in s_indices:
						b_indices.append(b_offset + idx)
				else:
					for idx in range(v_count):
						b_indices.append(b_offset + idx)
				bucket["verts"] = b_verts
				bucket["normals"] = b_normals
				bucket["bones"] = b_bones
				bucket["weights"] = b_weights
				bucket["indices"] = b_indices

	var combined_mesh := ArrayMesh.new()
	if not body_verts.is_empty():
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = body_verts
		arr[Mesh.ARRAY_NORMAL] = body_normals
		arr[Mesh.ARRAY_COLOR] = body_colors
		arr[Mesh.ARRAY_BONES] = body_bones
		arr[Mesh.ARRAY_WEIGHTS] = body_weights
		arr[Mesh.ARRAY_INDEX] = body_indices
		var surf_idx: int = combined_mesh.get_surface_count()
		combined_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var body_mat := StandardMaterial3D.new()
		body_mat.vertex_color_use_as_albedo = true
		body_mat.vertex_color_is_srgb = true
		body_mat.roughness = (roughness_sum / float(roughness_count)) if roughness_count > 0 else 0.88
		combined_mesh.surface_set_material(surf_idx, body_mat)

	for key in special_buckets:
		var bucket: Dictionary = special_buckets[key]
		var b_verts: PackedVector3Array = bucket["verts"]
		if b_verts.is_empty():
			continue
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = b_verts
		arr[Mesh.ARRAY_NORMAL] = bucket["normals"]
		arr[Mesh.ARRAY_BONES] = bucket["bones"]
		arr[Mesh.ARRAY_WEIGHTS] = bucket["weights"]
		arr[Mesh.ARRAY_INDEX] = bucket["indices"]
		var surf_idx: int = combined_mesh.get_surface_count()
		combined_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		if bucket["material"] != null:
			combined_mesh.surface_set_material(surf_idx, bucket["material"])

	if combined_mesh.get_surface_count() == 0:
		return

	for mi in candidates:
		skeleton.remove_child(mi)
		mi.free()

	var combined_instance := MeshInstance3D.new()
	combined_instance.name = "CombinedSkinnedMesh"
	combined_instance.mesh = combined_mesh
	combined_instance.skin = shared_skin
	combined_instance.skeleton = NodePath("..")
	skeleton.add_child(combined_instance)
