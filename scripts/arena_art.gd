extends Node3D
## Cenario dark fantasy com altar de spawn, grama, terra, ruinas e props.
## Esta camada e puramente visual: nao altera colisao, player, waves ou combate.

const ARENA_SIZE: float = 52.0
const ARENA_RADIUS: float = 24.0
const SAFE_RADIUS: float = 6.5
const TERRAIN_STEPS: int = 104
const TEXTURE_WORLD_METERS: float = 5.0

const COLOR_SOIL_DARK: Color = Color(0.07, 0.06, 0.055)
const COLOR_SOIL: Color = Color(0.15, 0.11, 0.09)
const COLOR_DIRT: Color = Color(0.20, 0.16, 0.11)
const COLOR_GRASS_A: Color = Color(0.20, 0.28, 0.16)
const COLOR_GRASS_B: Color = Color(0.17, 0.24, 0.14)
const COLOR_GRASS_C: Color = Color(0.13, 0.20, 0.12)
const COLOR_MOSS: Color = Color(0.24, 0.31, 0.18)
const COLOR_STONE_DARK: Color = Color(0.11, 0.11, 0.13)
const COLOR_STONE: Color = Color(0.17, 0.17, 0.20)
const COLOR_STONE_LIGHT: Color = Color(0.24, 0.23, 0.26)
const COLOR_METAL_GOLD: Color = Color(0.76, 0.56, 0.26)
const COLOR_RUNE: Color = Color(0.96, 0.44, 0.14)
const COLOR_FLAME: Color = Color(1.0, 0.52, 0.14)
const COLOR_TREE: Color = Color(0.14, 0.11, 0.10)
const COLOR_LEAF_DARK: Color = Color(0.08, 0.10, 0.07)
const COLOR_ROCK: Color = Color(0.22, 0.23, 0.28)

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _name_id: int = 0
var _material_cache: Dictionary = {}
var _is_campaign_mode: bool = false
var _is_town_zone: bool = false

func _ready() -> void:
	rebuild_tower_arena()


func _clear_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()


func rebuild_tower_arena() -> void:
	_clear_children()
	_is_campaign_mode = false
	_is_town_zone = false
	rng.seed = 9042026
	_build_ground(90420)
	_build_altar()
	_build_perimeter_ring()
	_build_ruins()
	_build_dead_trees()
	_build_gravestones()
	_build_rocks()
	_build_grass_tufts()
	_build_braziers()


func rebuild_campaign_zone(zone_def: Resource) -> void:
	_clear_children()
	_is_campaign_mode = true
	_is_town_zone = bool(zone_def.get("is_safe_town")) if zone_def != null else false
	var t_seed: int = int(zone_def.get("terrain_seed")) if zone_def != null else 77701
	var z_id: String = String(zone_def.get("zone_id")) if zone_def != null else "town"
	rng.seed = t_seed
	_build_ground(t_seed)
	_build_perimeter_ring()
	if _is_town_zone:
		_build_town_encampment()
	else:
		_build_campaign_zone_props(z_id)
	_build_grass_tufts()

func _unique(base: String) -> String:
	_name_id += 1
	return "%s_%03d" % [base, _name_id]

func _material(material_label: String, color: Color, roughness: float = 1.0, unshaded: bool = false, emission_energy: float = 0.0) -> StandardMaterial3D:
	var cache_key: String = "%s_%.2f_%d_%.2f" % [color.to_html(), roughness, 1 if unshaded else 0, emission_energy]
	if _material_cache.has(cache_key):
		return _material_cache[cache_key] as StandardMaterial3D
	var mat := StandardMaterial3D.new()
	mat.resource_name = material_label
	mat.albedo_color = color
	mat.roughness = roughness
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission_energy > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission_energy
	_material_cache[cache_key] = mat
	return mat

func _mesh_instance(mesh_label: String, mesh: Mesh, mat: Material, spawn_position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = mesh_label
	node.mesh = mesh
	node.material_override = mat
	node.position = spawn_position
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func _box(spawn_position: Vector3, size: Vector3, color: Color, roughness: float = 1.0) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh_instance(_unique("Box"), mesh, _material("mat_box", color, roughness), spawn_position)

func _cylinder(spawn_position: Vector3, radius: float, height: float, color: Color, sides: int = 12, roughness: float = 1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return _mesh_instance(_unique("Cyl"), mesh, _material("mat_cyl", color, roughness), spawn_position)

func _ring_mesh(inner_radius: float, outer_radius: float, segments: int = 72) -> ArrayMesh:
	var vertices := PackedVector3Array()
	for i in range(segments):
		var a0: float = TAU * float(i) / float(segments)
		var a1: float = TAU * float(i + 1) / float(segments)
		var u0 := Vector3(cos(a0), 0.0, sin(a0))
		var u1 := Vector3(cos(a1), 0.0, sin(a1))
		vertices.append(u0 * inner_radius)
		vertices.append(u0 * outer_radius)
		vertices.append(u1 * outer_radius)
		vertices.append(u0 * inner_radius)
		vertices.append(u1 * outer_radius)
		vertices.append(u1 * inner_radius)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_ground(noise_seed: int = 90420) -> void:
	# Uma unica malha continua substitui os antigos 676 quadrados verdes.
	# Mantemos a colisao existente em main.tscn, pois esta etapa e SOMENTE visual.
	# O relevo e sutil e fica abaixo do piso fisico para evitar obstaculos falsos.
	_box(Vector3(0.0, -0.37, 0.0), Vector3(ARENA_SIZE + 6.0, 0.60, ARENA_SIZE + 6.0), COLOR_SOIL_DARK)

	var terrain_shader: Shader = load("res://assets/materials/terrain_ground.gdshader") as Shader
	var grass_texture: Texture2D = load("res://assets/textures/grass_dark_tile.png") as Texture2D
	var dirt_texture: Texture2D = load("res://assets/textures/soil_moist_tile.png") as Texture2D
	var blend_texture: Texture2D = load("res://assets/textures/terrain_blend_noise.png") as Texture2D
	if terrain_shader == null or grass_texture == null or dirt_texture == null or blend_texture == null:
		push_error("Terreno v0.16: shader ou texturas ausentes em res://assets/.")
		var fallback := _box(Vector3(0.0, -0.055, 0.0), Vector3(ARENA_SIZE, 0.08, ARENA_SIZE), COLOR_GRASS_B)
		fallback.name = "Ground_Fallback_Assets_Missing"
		return

	var material := ShaderMaterial.new()
	material.shader = terrain_shader
	material.set_shader_parameter("grass_tex", grass_texture)
	material.set_shader_parameter("dirt_tex", dirt_texture)
	material.set_shader_parameter("blend_noise_tex", blend_texture)

	# Noise apenas na construcao, nao ha calculo procedural por frame.
	var terrain_noise := FastNoiseLite.new()
	terrain_noise.seed = noise_seed
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.082
	terrain_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	terrain_noise.fractal_octaves = 3

	var detail_noise := FastNoiseLite.new()
	detail_noise.seed = 81873
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.37

	var relief_noise := FastNoiseLite.new()
	relief_noise.seed = 1129
	relief_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	relief_noise.frequency = 0.13

	var side: int = TERRAIN_STEPS + 1
	var spacing: float = ARENA_SIZE / float(TERRAIN_STEPS)
	var heights := PackedFloat32Array()
	heights.resize(side * side)
	var dirt_weights := PackedFloat32Array()
	dirt_weights.resize(side * side)

	for zi in range(side):
		for xi in range(side):
			var px: float = float(xi) * spacing - ARENA_SIZE * 0.5
			var pz: float = float(zi) * spacing - ARENA_SIZE * 0.5
			var radial: float = Vector2(px, pz).length()
			var broad: float = terrain_noise.get_noise_2d(px, pz)
			var detail: float = detail_noise.get_noise_2d(px, pz)
			var relief: float = relief_noise.get_noise_2d(px, pz)

			# Centro plano, bordas com uma ondulacao minima para preservar a jogabilidade.
			var relief_factor: float = smoothstep(10.0, 18.0, radial)
			var height: float = clampf(-0.030 + relief_factor * (relief * 0.042 + detail * 0.012), -0.075, -0.012)

			# Clareira do altar/vila e estrada sinuosa Norte-Sul (no modo Campanha ARPG)
			var altar_dirt: float = 1.0 - smoothstep(5.5, 9.0, radial + broad * 1.0)
			var curving_trail: float = pz - sin(px * 0.22) * 1.5
			var trail_width: float = absf(curving_trail) + broad * 0.35
			var dirt_trail: float = (1.0 - smoothstep(0.9, 2.2, trail_width)) * smoothstep(5.5, 9.5, absf(px)) * 0.84
			if _is_campaign_mode:
				var ns_road_center: float = sin(pz * 0.16) * (0.8 if _is_town_zone else 2.6)
				var ns_dist: float = absf(px - ns_road_center) + broad * 0.28
				var ns_road: float = 1.0 - smoothstep(1.6, 3.1, ns_dist)
				dirt_trail = maxf(dirt_trail, ns_road * 0.96)
				if _is_town_zone:
					altar_dirt = 1.0 - smoothstep(8.2, 11.8, radial + broad * 0.8)
			var dirt_patches: float = smoothstep(0.17, 0.65, broad * 0.88 + detail * 0.25 + 0.21) * 0.66
			var dirt_mask: float = clampf(maxf(altar_dirt * 0.95, maxf(dirt_trail, dirt_patches)), 0.0, 1.0)

			var idx: int = zi * side + xi
			heights[idx] = height
			dirt_weights[idx] = dirt_mask

	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	for zi in range(side):
		for xi in range(side):
			var px: float = float(xi) * spacing - ARENA_SIZE * 0.5
			var pz: float = float(zi) * spacing - ARENA_SIZE * 0.5
			var idx: int = zi * side + xi
			positions.append(Vector3(px, heights[idx], pz))
			uvs.append(Vector2(px / TEXTURE_WORLD_METERS, pz / TEXTURE_WORLD_METERS))
			# O canal vermelho da cor do vertice define a quantidade de terra.
			colors.append(Color(dirt_weights[idx], 0.0, 0.0, 1.0))

			var left_x: int = maxi(xi - 1, 0)
			var right_x: int = mini(xi + 1, TERRAIN_STEPS)
			var down_z: int = maxi(zi - 1, 0)
			var up_z: int = mini(zi + 1, TERRAIN_STEPS)
			var gradient_x: float = (heights[zi * side + left_x] - heights[zi * side + right_x]) / (maxi(right_x - left_x, 1) * spacing)
			var gradient_z: float = (heights[down_z * side + xi] - heights[up_z * side + xi]) / (maxi(up_z - down_z, 1) * spacing)
			normals.append(Vector3(gradient_x, 1.0, gradient_z).normalized())

	# Indices com winding para normais voltadas para cima.
	for zi in range(TERRAIN_STEPS):
		for xi in range(TERRAIN_STEPS):
			var a: int = zi * side + xi
			var b: int = a + 1
			var c: int = a + side
			var d: int = c + 1
			indices.append(a)
			indices.append(c)
			indices.append(b)
			indices.append(b)
			indices.append(c)
			indices.append(d)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var terrain_mesh := ArrayMesh.new()
	terrain_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var terrain_node := _mesh_instance("Terrain_Continuous_Grass_Dirt", terrain_mesh, material)
	terrain_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	print("Cenario v0.16: terreno continuo criado (%d vertices, %d triangulos)." % [positions.size(), int(float(indices.size()) / 3.0)])

func _build_altar() -> void:
	# Degraus baixos nivelados com o piso fisico (y ~ 0.0) para que o personagem
	# nunca fique afundado na pedra e todas as runas e aneis dourados fiquem visiveis no topo!
	_cylinder(Vector3(0.0, -0.050, 0.0), 4.85, 0.10, COLOR_STONE_DARK, 32, 0.96)
	_cylinder(Vector3(0.0, -0.042, 0.0), 4.05, 0.09, COLOR_STONE, 32, 0.95)
	_cylinder(Vector3(0.0, -0.034, 0.0), 3.15, 0.08, COLOR_STONE_LIGHT, 32, 0.92)
	_cylinder(Vector3(0.0, -0.026, 0.0), 2.55, 0.07, Color(0.41, 0.42, 0.46), 32, 0.88)
	_cylinder(Vector3(0.0, -0.018, 0.0), 0.96, 0.06, Color(0.34, 0.36, 0.42), 24, 0.85)

	var rune_mat := _material("rune_glow", COLOR_RUNE, 0.65, true, 0.8)
	rune_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var gold_mat := _material("gold_ring", COLOR_METAL_GOLD, 0.72, true, 0.15)
	gold_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_mesh_instance("AltarGoldOuter", _ring_mesh(3.02, 3.09, 72), gold_mat, Vector3(0.0, 0.012, 0.0))
	_mesh_instance("AltarRuneOuter", _ring_mesh(2.30, 2.38, 72), rune_mat, Vector3(0.0, 0.016, 0.0))
	_mesh_instance("AltarRuneInner", _ring_mesh(1.70, 1.77, 72), rune_mat, Vector3(0.0, 0.016, 0.0))
	_mesh_instance("AltarRuneCenter", _ring_mesh(0.84, 0.91, 48), gold_mat, Vector3(0.0, 0.018, 0.0))

	for i in range(12):
		var angle := TAU * float(i) / 12.0
		var tick := _box(Vector3(cos(angle) * 2.02, 0.018, sin(angle) * 2.02), Vector3(0.06, 0.012, 0.24), COLOR_METAL_GOLD)
		tick.rotation.y = -angle - PI * 0.5
		tick.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	# Luz quente de fogueira/santuario (estilo Diablo 2 / PoE 2 / Grim Dawn) iluminando a armadura do heroi!
	var shrine_light := OmniLight3D.new()
	shrine_light.name = "ShrineFireLight"
	shrine_light.position = Vector3(0.0, 2.25, 0.0)
	shrine_light.light_color = Color(1.0, 0.58, 0.24)
	shrine_light.light_energy = 1.55
	shrine_light.omni_range = 9.0
	shrine_light.omni_attenuation = 1.35
	add_child(shrine_light)

func _build_perimeter_ring() -> void:
	# Base escurecida ao redor da arena para dar contraste e clima.
	var edge_mat := _material("edge_shadow", Color(0.06, 0.055, 0.055), 1.0)
	_mesh_instance("EdgeRing", _ring_mesh(21.6, 26.5, 96), edge_mat, Vector3(0.0, -0.11, 0.0))

func _build_ruins() -> void:
	_ruin(Vector3(-14.0, 0.0, -13.5), 0.0)
	_ruin(Vector3(14.5, 0.0, -12.5), PI * 0.18)
	_ruin(Vector3(-15.5, 0.0, 12.0), -PI * 0.1)
	_ruin(Vector3(13.0, 0.0, 14.0), PI * 0.32)
	_broken_wall(Vector3(0.0, 0.0, -18.0), 0.0, 5.0)
	_broken_wall(Vector3(16.0, 0.0, 3.0), PI * 0.5, 4.5)
	_broken_wall(Vector3(-17.0, 0.0, 2.5), PI * 0.5, 4.8)

func _build_dead_trees() -> void:
	_dead_tree(Vector3(-9.5, 0.0, -17.0), 1.15, 0.1)
	_dead_tree(Vector3(10.5, 0.0, -16.5), 1.3, -0.2)
	_dead_tree(Vector3(-18.0, 0.0, -2.0), 1.0, 0.25)
	_dead_tree(Vector3(18.0, 0.0, 1.5), 1.1, -0.3)
	_dead_tree(Vector3(-12.5, 0.0, 16.0), 1.25, 0.18)
	_dead_tree(Vector3(11.5, 0.0, 16.2), 1.1, -0.12)

func _build_gravestones() -> void:
	_gravestone(Vector3(-6.0, 0.0, -15.0), 0.14)
	_gravestone(Vector3(-3.5, 0.0, -17.3), -0.1)
	_gravestone(Vector3(7.0, 0.0, -16.4), 0.2)
	_gravestone(Vector3(16.6, 0.0, -6.5), PI * 0.5)
	_gravestone(Vector3(-16.4, 0.0, 6.5), PI * 0.5)
	_gravestone(Vector3(4.0, 0.0, 17.4), 0.1)
	_gravestone(Vector3(-5.5, 0.0, 16.4), -0.2)

func _build_rocks() -> void:
	for pos in [
		Vector3(-13.0, 0.0, -8.0), Vector3(13.5, 0.0, -8.5), Vector3(-17.5, 0.0, 9.5),
		Vector3(16.5, 0.0, 10.0), Vector3(-3.0, 0.0, -20.0), Vector3(4.5, 0.0, 20.0),
		Vector3(-19.2, 0.0, -12.0), Vector3(18.5, 0.0, -13.5)
	]:
		_rock_cluster(pos)

func _build_grass_tufts() -> void:
	var transforms: Array[Transform3D] = []
	var colors: Array[Color] = []
	var palette: Array[Color] = [COLOR_GRASS_A, COLOR_GRASS_B, COLOR_MOSS]

	for i in range(130):
		var angle := rng.randf_range(0.0, TAU)
		var radius := rng.randf_range(4.5, ARENA_RADIUS - 1.5)
		var pos := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if pos.length() < SAFE_RADIUS + 0.8:
			continue
		var tuft_rot_y := rng.randf_range(-PI, PI)
		var tuft_basis := Basis.from_euler(Vector3(0.0, tuft_rot_y, 0.0))
		for b in range(3):
			var local_pos := Vector3(rng.randf_range(-0.08, 0.08), 0.17 + float(b) * 0.02, rng.randf_range(-0.08, 0.08))
			var blade_h := 0.34 + rng.randf_range(0.0, 0.16)
			var blade_rot := Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.65, 0.65), rng.randf_range(-0.22, 0.22))
			var blade_basis := tuft_basis * Basis.from_euler(blade_rot).scaled(Vector3(0.06, blade_h, 0.02))
			var world_pos := pos + tuft_basis * local_pos
			transforms.append(Transform3D(blade_basis, world_pos))
			colors.append(palette[b % 3])

	if transforms.is_empty():
		return

	var unit_box := BoxMesh.new()
	unit_box.size = Vector3.ONE
	var grass_mat := StandardMaterial3D.new()
	grass_mat.vertex_color_use_as_albedo = true
	grass_mat.vertex_color_is_srgb = true
	grass_mat.roughness = 1.0
	unit_box.material = grass_mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = unit_box
	mm.instance_count = transforms.size()
	for idx in range(transforms.size()):
		mm.set_instance_transform(idx, transforms[idx])
		mm.set_instance_color(idx, colors[idx])

	var mmi := MultiMeshInstance3D.new()
	mmi.name = "GrassTuftsMultiMesh"
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)

func _build_braziers() -> void:
	# Posicionados nas 4 diagonais do altar para emoldurar o personagem no Lobby e na batalha.
	var offsets := [
		Vector3(2.65, 0.0, 2.65), Vector3(-2.65, 0.0, 2.65),
		Vector3(2.65, 0.0, -2.65), Vector3(-2.65, 0.0, -2.65)
	]
	for pos in offsets:
		_brazier(pos)

func _ruin(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.name = _unique("Ruin")
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)

	_add_box_to(root, Vector3(-1.5, 1.25, 0.0), Vector3(0.9, 2.5, 0.9), COLOR_STONE)
	_add_box_to(root, Vector3(1.5, 1.05, 0.0), Vector3(0.9, 2.1, 0.9), COLOR_STONE)
	_add_box_to(root, Vector3(0.0, 2.35, 0.0), Vector3(4.1, 0.42, 0.9), COLOR_STONE_DARK)
	_add_box_to(root, Vector3(0.0, 0.16, 0.0), Vector3(4.5, 0.32, 1.4), COLOR_STONE_LIGHT)

func _broken_wall(pos: Vector3, rot_y: float, width: float) -> void:
	var wall := _box(pos + Vector3(0.0, 0.45, 0.0), Vector3(width, 0.95, 1.0), COLOR_STONE)
	wall.rotation.y = rot_y
	var broken := _box(pos + Vector3(width * 0.18, 1.05, 0.0), Vector3(width * 0.42, 0.48, 0.92), COLOR_STONE_LIGHT)
	broken.rotation.y = rot_y + 0.05

func _dead_tree(pos: Vector3, scale_factor: float, lean: float) -> void:
	var root := Node3D.new()
	root.name = _unique("Tree")
	root.position = pos
	root.rotation.y = rng.randf_range(-PI, PI)
	add_child(root)

	var trunk := _add_cylinder_to(root, Vector3(0.0, 1.2 * scale_factor, 0.0), 0.20 * scale_factor, 2.4 * scale_factor, COLOR_TREE, 7)
	trunk.rotation.z = lean
	for branch_data in [
		{ "pos": Vector3(0.28, 2.05, 0.0), "rot": Vector3(0.1, 0.0, 1.0), "size": Vector3(1.2, 0.12, 0.12) },
		{ "pos": Vector3(-0.22, 1.75, 0.0), "rot": Vector3(-0.1, 0.0, -0.85), "size": Vector3(0.95, 0.11, 0.11) },
		{ "pos": Vector3(0.0, 2.35, 0.16), "rot": Vector3(0.0, 0.3, 0.55), "size": Vector3(0.88, 0.10, 0.10) }
	]:
		var branch := _add_box_to(root, branch_data.pos * scale_factor, branch_data.size * scale_factor, COLOR_TREE)
		branch.rotation = branch_data.rot
	for i in range(3):
		var crown := _add_box_to(root, Vector3(rng.randf_range(-0.25, 0.25), 2.7 * scale_factor + rng.randf_range(-0.1, 0.1), rng.randf_range(-0.25, 0.25)), Vector3(0.42, 0.22, 0.42) * scale_factor, COLOR_LEAF_DARK)
		crown.rotation = Vector3(rng.randf_range(-0.4, 0.4), rng.randf_range(-1.0, 1.0), rng.randf_range(-0.4, 0.4))

func _gravestone(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.name = _unique("Grave")
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)
	_add_box_to(root, Vector3(0.0, 0.08, 0.0), Vector3(0.95, 0.16, 0.85), COLOR_SOIL)
	_add_box_to(root, Vector3(0.0, 0.46, 0.0), Vector3(0.52, 0.78, 0.14), COLOR_STONE_LIGHT)
	_add_box_to(root, Vector3(0.0, 0.83, 0.0), Vector3(0.44, 0.14, 0.14), COLOR_STONE)
	var moss := _add_box_to(root, Vector3(0.0, 0.72, 0.06), Vector3(0.26, 0.08, 0.03), COLOR_MOSS)
	moss.rotation.x = 0.28

func _rock_cluster(pos: Vector3) -> void:
	for i in range(3):
		var rock := _box(pos + Vector3(rng.randf_range(-0.35, 0.35), 0.20 + rng.randf_range(-0.05, 0.05), rng.randf_range(-0.35, 0.35)), Vector3(rng.randf_range(0.45, 0.95), rng.randf_range(0.30, 0.75), rng.randf_range(0.45, 0.95)), COLOR_ROCK)
		rock.rotation = Vector3(rng.randf_range(-0.25, 0.25), rng.randf_range(-1.3, 1.3), rng.randf_range(-0.25, 0.25))

func _grass_tuft(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = _unique("Tuft")
	root.position = pos
	root.rotation.y = rng.randf_range(-PI, PI)
	add_child(root)
	for i in range(3):
		var blade := _add_box_to(root, Vector3(rng.randf_range(-0.08, 0.08), 0.17 + float(i) * 0.02, rng.randf_range(-0.08, 0.08)), Vector3(0.06, 0.34 + rng.randf_range(0.0, 0.16), 0.02), [COLOR_GRASS_A, COLOR_GRASS_B, COLOR_MOSS][i % 3])
		blade.rotation = Vector3(rng.randf_range(-0.08, 0.08), rng.randf_range(-0.65, 0.65), rng.randf_range(-0.22, 0.22))

func _brazier(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = _unique("Brazier")
	root.position = pos
	add_child(root)
	_add_cylinder_to(root, Vector3(0.0, 0.18, 0.0), 0.42, 0.26, COLOR_STONE_DARK, 10)
	_add_cylinder_to(root, Vector3(0.0, 0.42, 0.0), 0.26, 0.16, COLOR_STONE_LIGHT, 10)
	_add_cylinder_to(root, Vector3(0.0, 0.72, 0.0), 0.14, 0.48, COLOR_METAL_GOLD, 8)
	var flame_bottom := CylinderMesh.new()
	flame_bottom.top_radius = 0.0
	flame_bottom.bottom_radius = 0.26
	flame_bottom.height = 0.42
	var flame_top := CylinderMesh.new()
	flame_top.top_radius = 0.0
	flame_top.bottom_radius = 0.18
	flame_top.height = 0.38
	var flame_mat := _material("ghost_fire", COLOR_FLAME, 0.2, true, 1.3)
	_mesh_instance(_unique("FlameBottom"), flame_bottom, flame_mat, pos + Vector3(0.0, 1.08, 0.0))
	_mesh_instance(_unique("FlameTop"), flame_top, flame_mat, pos + Vector3(0.0, 1.35, 0.0))

func _add_box_to(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.name = _unique("PartBox")
	node.mesh = mesh
	node.material_override = _material("part_box", color)
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node

func _add_cylinder_to(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, sides: int = 10) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	var node := MeshInstance3D.new()
	node.name = _unique("PartCyl")
	node.mesh = mesh
	node.material_override = _material("part_cyl", color)
	node.position = pos
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	return node


func _build_albion_stone_mandala_plaza(center_pos: Vector3 = Vector3.ZERO) -> void:
	# 1. Base Circular de lajotas de pedra azul-ardósia polidas (estilo praça de Albion)
	var slate_mat := _material("slate_floor", Color(0.12, 0.15, 0.20), 0.85)
	var slab := CylinderMesh.new()
	slab.top_radius = 6.4
	slab.bottom_radius = 6.5
	slab.height = 0.04
	slab.radial_segments = 48
	_mesh_instance("AlbionPlazaFloor", slab, slate_mat, center_pos + Vector3(0.0, 0.015, 0.0))

	# 2. Anéis concêntricos de pedra esculpida em tom mármore escuro e dourado rúnico
	var ring_stone_mat := _material("ring_stone", Color(0.20, 0.18, 0.24), 0.85)
	var gold_rune_mat := _material("gold_rune", Color(0.85, 0.70, 0.35), 0.60, false, 0.25)
	_mesh_instance("AlbionOuterRing", _ring_mesh(5.8, 6.3, 56), ring_stone_mat, center_pos + Vector3(0.0, 0.024, 0.0))
	_mesh_instance("AlbionMidRing", _ring_mesh(3.7, 4.1, 56), ring_stone_mat, center_pos + Vector3(0.0, 0.026, 0.0))
	_mesh_instance("AlbionInnerRing", _ring_mesh(1.6, 1.85, 40), gold_rune_mat, center_pos + Vector3(0.0, 0.028, 0.0))

	# 3. Padrão gótico de arcos e rosácea central (projeção de vitral catedralesco no chão do Albion)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0.012, 0.016, 0.028, 0.68)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.no_depth_test = true
	shadow_mat.render_priority = 6

	for i in range(8):
		var ang := float(i) * TAU / 8.0
		var ray_mesh := BoxMesh.new()
		ray_mesh.size = Vector3(0.12, 0.002, 4.2)
		var ray_node := MeshInstance3D.new()
		ray_node.name = _unique("RoseRay")
		ray_node.mesh = ray_mesh
		ray_node.material_override = shadow_mat
		ray_node.position = center_pos + Vector3(cos(ang) * 2.1, 0.032, sin(ang) * 2.1)
		ray_node.rotation.y = -ang + PI * 0.5
		ray_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ray_node)

		var arc_mesh := BoxMesh.new()
		arc_mesh.size = Vector3(1.25, 0.002, 0.12)
		var arc_node := MeshInstance3D.new()
		arc_node.name = _unique("RoseArc")
		arc_node.mesh = arc_mesh
		arc_node.material_override = shadow_mat
		arc_node.position = center_pos + Vector3(cos(ang + TAU / 16.0) * 3.5, 0.032, sin(ang + TAU / 16.0) * 3.5)
		arc_node.rotation.y = -ang - TAU / 16.0
		arc_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(arc_node)

func _build_town_encampment() -> void:
	_build_albion_stone_mandala_plaza(Vector3.ZERO)
	_build_albion_dungeon_props()
	# Fogueira Central do Acampamento dos Exilados (estilo Rogue Encampment - Diablo 2)
	_cylinder(Vector3(0.0, 0.04, 0.0), 1.45, 0.08, COLOR_STONE_DARK, 16)
	for i in range(10):
		var a := TAU * float(i) / 10.0
		_box(Vector3(cos(a) * 1.10, 0.14, sin(a) * 1.10), Vector3(0.36, 0.24, 0.28), COLOR_STONE_LIGHT)
	# Toras de lenha e braseiro central
	for i in range(4):
		var log_node := _box(Vector3(0.0, 0.18, 0.0), Vector3(1.25, 0.16, 0.18), COLOR_TREE)
		log_node.rotation.y = float(i) * PI * 0.25
		log_node.rotation.z = 0.18
	var fire_mat := _material("campfire_glow", COLOR_FLAME, 0.2, true, 2.0)
	var f1 := CylinderMesh.new()
	f1.top_radius = 0.0
	f1.bottom_radius = 0.52
	f1.height = 0.85
	_mesh_instance("CampfireFlameOuter", f1, fire_mat, Vector3(0.0, 0.52, 0.0))

	var camp_light := OmniLight3D.new()
	camp_light.name = "TownCampfireLight"
	camp_light.position = Vector3(0.0, 2.35, 0.0)
	camp_light.light_color = Color(1.0, 0.58, 0.22)
	camp_light.light_energy = 1.85
	camp_light.omni_range = 14.0
	add_child(camp_light)

	# Muralhas baixas do Acampamento com abertura larga no Portão Norte (Z = -16.5)
	_broken_wall(Vector3(-8.5, 0.0, -16.5), 0.0, 9.5)
	_broken_wall(Vector3(8.5, 0.0, -16.5), 0.0, 9.5)
	_broken_wall(Vector3(0.0, 0.0, 14.5), 0.0, 16.0)
	_broken_wall(Vector3(-13.5, 0.0, -1.0), PI * 0.5, 22.0)
	_broken_wall(Vector3(13.5, 0.0, -1.0), PI * 0.5, 22.0)

	# Braseiros iluminando a saída Norte e os cantos da Vila
	for b_pos in [
		Vector3(-3.2, 0.0, -13.5), Vector3(3.2, 0.0, -13.5),
		Vector3(-8.5, 0.0, -6.5), Vector3(8.5, 0.0, -6.5),
		Vector3(-8.5, 0.0, 6.5), Vector3(8.5, 0.0, 6.5),
	]:
		_brazier(b_pos)

	# Árvores secas ao fundo fora dos muros da Vila
	_dead_tree(Vector3(-16.5, 0.0, -18.0), 1.2, 0.12)
	_dead_tree(Vector3(16.5, 0.0, -18.0), 1.25, -0.15)
	_dead_tree(Vector3(-17.5, 0.0, 12.0), 1.15, 0.2)
	_dead_tree(Vector3(17.5, 0.0, 12.0), 1.1, -0.2)


func _build_campaign_zone_props(zone_id: String) -> void:
	# Braseiros de estrada guiando o caminho Sul -> Norte
	for z_step in [-14.0, -5.0, 5.0, 14.0]:
		var road_x: float = sin(z_step * 0.16) * 2.6
		_brazier(Vector3(road_x - 3.6, 0.0, z_step))
		_brazier(Vector3(road_x + 3.6, 0.0, z_step))

	_build_ruins()
	_build_rocks()
	_build_dead_trees()
	_build_gravestones()

	if zone_id == "zone_2_woods":
		# Floresta mais densa na Mata das Sombras
		for extra_tree in [
			Vector3(-11.0, 0.0, -7.0), Vector3(11.5, 0.0, -6.0),
			Vector3(-12.0, 0.0, 6.0), Vector3(12.5, 0.0, 8.0),
			Vector3(-6.5, 0.0, -15.5), Vector3(7.0, 0.0, 14.5),
		]:
			_dead_tree(extra_tree, 1.32, rng.randf_range(-0.22, 0.22))
	elif zone_id == "zone_3_crypt":
		# Altar profanado no covil do Carrasco + lápides extras
		_build_altar()
		for extra_grave in [
			Vector3(-8.5, 0.0, -10.5), Vector3(8.5, 0.0, -10.5),
			Vector3(-9.5, 0.0, -4.5), Vector3(9.5, 0.0, -4.5),
		]:
			_gravestone(extra_grave, rng.randf_range(-0.25, 0.25))

func _build_albion_dungeon_props() -> void:
	# 1. Barris de armas (barris de madeira com espadas/lanças dentro)
	for b_pos in [Vector3(-5.2, 0.0, -8.5), Vector3(6.5, 0.0, -7.2), Vector3(-6.8, 0.0, 7.8)]:
		_weapon_barrel(b_pos)

	# 2. Caixotes de madeira quebrados nos cantos
	for c_pos in [Vector3(-7.2, 0.0, -10.5), Vector3(8.2, 0.0, -11.0), Vector3(-8.5, 0.0, 9.5), Vector3(7.5, 0.0, 8.5)]:
		_wooden_crate(c_pos, rng.randf_range(-0.4, 0.4))

	# 3. Manchas de palha / feno espalhadas pelo chão de pedra
	for s_pos in [Vector3(-2.8, 0.0, -4.5), Vector3(3.5, 0.0, -3.8), Vector3(1.8, 0.0, 4.2), Vector3(-3.5, 0.0, 3.5)]:
		_straw_patch(s_pos)

	# 4. Brasão de armas entalhado nas pedras do piso (Escudo e Espada estilo Albion)
	_heraldic_floor_carving(Vector3(-4.8, 0.0, -1.5))


func _weapon_barrel(pos: Vector3) -> void:
	var root := Node3D.new()
	root.name = _unique("WeaponBarrel")
	root.position = pos
	add_child(root)

	var barrel_mat := _material("barrel_wood", Color(0.24, 0.16, 0.10), 0.85)
	var barrel := CylinderMesh.new()
	barrel.top_radius = 0.36
	barrel.bottom_radius = 0.34
	barrel.height = 0.78
	var b_node := MeshInstance3D.new()
	b_node.mesh = barrel
	b_node.material_override = barrel_mat
	b_node.position = Vector3(0.0, 0.39, 0.0)
	root.add_child(b_node)

	var rim_mat := _material("barrel_iron", Color(0.12, 0.12, 0.14), 0.5)
	var r1 := CylinderMesh.new()
	r1.top_radius = 0.37
	r1.bottom_radius = 0.37
	r1.height = 0.06
	var r1_node := MeshInstance3D.new()
	r1_node.mesh = r1
	r1_node.material_override = rim_mat
	r1_node.position = Vector3(0.0, 0.22, 0.0)
	root.add_child(r1_node)

	var r2_node := MeshInstance3D.new()
	r2_node.mesh = r1
	r2_node.material_override = rim_mat
	r2_node.position = Vector3(0.0, 0.56, 0.0)
	root.add_child(r2_node)

	var blade_mat := _material("steel_blade", Color(0.65, 0.70, 0.78), 0.25)
	for i in range(3):
		var ang := float(i) * TAU / 3.0 + 0.3
		var blade := BoxMesh.new()
		blade.size = Vector3(0.05, 0.85, 0.12)
		var bl_node := MeshInstance3D.new()
		bl_node.mesh = blade
		bl_node.material_override = blade_mat
		bl_node.position = Vector3(cos(ang) * 0.12, 0.82, sin(ang) * 0.12)
		bl_node.rotation.z = cos(ang) * 0.22
		bl_node.rotation.x = sin(ang) * 0.22
		root.add_child(bl_node)


func _wooden_crate(pos: Vector3, rot_y: float) -> void:
	var root := Node3D.new()
	root.name = _unique("WoodCrate")
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)

	var crate_mat := _material("crate_wood", Color(0.32, 0.22, 0.14), 0.9)
	var crate_mesh := BoxMesh.new()
	crate_mesh.size = Vector3(0.72, 0.70, 0.72)
	var c_node := MeshInstance3D.new()
	c_node.mesh = crate_mesh
	c_node.material_override = crate_mat
	c_node.position = Vector3(0.0, 0.35, 0.0)
	root.add_child(c_node)

	var plank_mat := _material("plank_wood", Color(0.22, 0.15, 0.10), 0.95)
	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(0.75, 0.08, 0.75)
	var p_node := MeshInstance3D.new()
	p_node.mesh = p_mesh
	p_node.material_override = plank_mat
	p_node.position = Vector3(0.0, 0.70, 0.0)
	root.add_child(p_node)


func _straw_patch(pos: Vector3) -> void:
	var straw_mat := StandardMaterial3D.new()
	straw_mat.albedo_color = Color(0.68, 0.58, 0.28, 0.75)
	straw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	straw_mat.roughness = 1.0

	var s_mesh := BoxMesh.new()
	s_mesh.size = Vector3(1.6, 0.015, 1.3)
	var node := MeshInstance3D.new()
	node.name = _unique("StrawPatch")
	node.mesh = s_mesh
	node.material_override = straw_mat
	node.position = pos + Vector3(0.0, 0.022, 0.0)
	node.rotation.y = rng.randf_range(-PI, PI)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _heraldic_floor_carving(pos: Vector3) -> void:
	var emblem_mat := StandardMaterial3D.new()
	emblem_mat.albedo_color = Color(0.08, 0.10, 0.14, 0.75)
	emblem_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	emblem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emblem_mat.no_depth_test = true
	emblem_mat.render_priority = 6

	var sword_blade := BoxMesh.new()
	sword_blade.size = Vector3(0.12, 0.002, 3.4)
	var sw_node := MeshInstance3D.new()
	sw_node.mesh = sword_blade
	sw_node.material_override = emblem_mat
	sw_node.position = pos + Vector3(0.0, 0.026, 0.0)
	sw_node.rotation.y = PI * 0.25
	sw_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sw_node)

	var guard := BoxMesh.new()
	guard.size = Vector3(0.85, 0.002, 0.10)
	var g_node := MeshInstance3D.new()
	g_node.mesh = guard
	g_node.material_override = emblem_mat
	g_node.position = pos + Vector3(-0.6, 0.027, -0.6)
	g_node.rotation.y = PI * 0.25
	g_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(g_node)
