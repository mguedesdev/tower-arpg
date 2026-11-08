extends SceneTree

func _init() -> void:
	print("--- AUDIT KNIGHT.GLB MATERIALS ---")
	var sc := load("res://assets/models/knight.glb") as PackedScene
	if sc:
		var inst := sc.instantiate()
		var meshes := inst.find_children("", "MeshInstance3D", true, false)
		print("Meshes found in knight.glb: ", meshes.size())
		var checked_mats := {}
		for mi in meshes:
			var m: Mesh = (mi as MeshInstance3D).mesh
			for s in range(m.get_surface_count()):
				var mat = (mi as MeshInstance3D).get_surface_override_material(s)
				if mat == null:
					mat = m.surface_get_material(s)
				if mat is StandardMaterial3D and not checked_mats.has(mat.resource_name):
					checked_mats[mat.resource_name] = true
					var sm := mat as StandardMaterial3D
					print("Material: ", mat.resource_name)
					print("  albedo_color: ", sm.albedo_color)
					print("  roughness: ", sm.roughness)
					print("  metallic: ", sm.metallic)
					print("  metallic_specular: ", sm.metallic_specular)
					print("  shading_mode: ", sm.shading_mode)
					print("  diffuse_mode: ", sm.diffuse_mode)
					print("  emission_enabled: ", sm.emission_enabled)
		inst.free()
	quit(0)
