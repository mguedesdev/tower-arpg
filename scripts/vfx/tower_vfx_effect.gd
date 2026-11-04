extends Node3D
## VFX geometrico temporario otimizado (Zero alocacoes de ArrayMesh/StandardMaterial3D em combate).
## Nunca causa dano, nao cria hitbox e nao altera gameplay.
## Efeitos: estocada, arco, giro, faíscas, fogo e garras.

const MAX_SIMULTANEOUS: int = 24
const SHARD_COUNT: int = 7
const FADE_STEPS: int = 6

enum Kind { STAB, ARC, SPIN, IMPACT, FIRE, CLAWS }

@export var kind: Kind = Kind.STAB
@export_range(0.1, 2.5, 0.05) var intensity: float = 1.0

static var _cached_meshes: Dictionary = {}
static var _shared_fade_materials: Array[StandardMaterial3D] = []

var _elapsed: float = 0.0
var _duration: float = 0.25
var _geometry: Node3D
var _mesh_instance: MeshInstance3D


static func warm_up_caches() -> void:
	_ensure_fade_materials()
	for k in [Kind.STAB, Kind.ARC, Kind.SPIN, Kind.IMPACT, Kind.FIRE, Kind.CLAWS]:
		_get_or_build_cached_mesh(k)


static func _ensure_fade_materials() -> void:
	if not _shared_fade_materials.is_empty():
		return
	for i in range(FADE_STEPS):
		var alpha: float = float(i + 1) / float(FADE_STEPS)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.vertex_color_use_as_albedo = true
		mat.vertex_color_is_srgb = true
		mat.albedo_color = Color(1.0, 1.0, 1.0, alpha)
		_shared_fade_materials.append(mat)


static func get_fade_material(fade_ratio: float) -> StandardMaterial3D:
	_ensure_fade_materials()
	var idx: int = clampi(int(ceilf(clampf(fade_ratio, 0.01, 1.0) * float(FADE_STEPS))) - 1, 0, FADE_STEPS - 1)
	return _shared_fade_materials[idx]


func _ready() -> void:
	if get_tree().get_nodes_in_group("combat_vfx").size() >= MAX_SIMULTANEOUS:
		queue_free()
		return
	add_to_group("combat_vfx")
	_ensure_fade_materials()

	match kind:
		Kind.STAB:
			_duration = 0.20
		Kind.ARC:
			_duration = 0.24
		Kind.SPIN:
			_duration = 0.30
		Kind.IMPACT:
			_duration = 0.22
		Kind.FIRE:
			_duration = 0.32
		Kind.CLAWS:
			_duration = 0.21

	_geometry = Node3D.new()
	_geometry.name = "Geometry"
	add_child(_geometry)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "VfxCombinedMesh"
	_mesh_instance.mesh = _get_or_build_cached_mesh(kind)
	_mesh_instance.material_override = get_fade_material(1.0)
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geometry.add_child(_mesh_instance)


func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= _duration:
		queue_free()
		return

	var progress: float = clampf(_elapsed / _duration, 0.0, 1.0)
	var fade: float = pow(1.0 - progress, 1.4) * clampf(intensity, 0.2, 1.5)

	match kind:
		Kind.STAB:
			_geometry.scale = Vector3(lerpf(0.58, 1.03, progress), 1.0, lerpf(0.45, 1.28, progress))
		Kind.ARC:
			_geometry.scale = Vector3.ONE * lerpf(0.73, 1.07, progress)
			_geometry.rotation.y = lerpf(-0.28, 0.22, progress)
		Kind.SPIN:
			_geometry.scale = Vector3.ONE * lerpf(0.68, 1.11, progress)
			_geometry.rotation.y = progress * PI * 0.8
		Kind.IMPACT, Kind.FIRE:
			var expand: float = lerpf(0.32, 1.38, progress)
			_geometry.scale = Vector3(expand, lerpf(0.45, 1.15, progress), expand)
			_geometry.position.y = progress * 0.35
			_geometry.rotation.y = progress * 1.4
		Kind.CLAWS:
			_geometry.scale = Vector3.ONE * lerpf(0.62, 1.18, progress)
			_geometry.position = Vector3(0.0, progress * 0.22, progress * 0.15)

	if _mesh_instance != null:
		var target_mat: StandardMaterial3D = get_fade_material(fade)
		if _mesh_instance.material_override != target_mat:
			_mesh_instance.material_override = target_mat


static func _get_or_build_cached_mesh(effect_kind: int) -> ArrayMesh:
	if _cached_meshes.has(effect_kind):
		return _cached_meshes[effect_kind] as ArrayMesh

	var verts := PackedVector3Array()
	var colors := PackedColorArray()

	match effect_kind:
		Kind.STAB:
			_append_colored_quad(verts, colors, Vector3(-0.23, 0.0, 0.15), Vector3(0.23, 0.0, 0.15), Vector3(0.14, 0.0, 1.45), Vector3(-0.14, 0.0, 1.45), Color(0.53, 0.88, 1.0, 0.44))
			_append_colored_tri(verts, colors, Vector3(-0.14, 0.0, 1.45), Vector3(0.14, 0.0, 1.45), Vector3(0.0, 0.0, 2.45), Color(0.53, 0.88, 1.0, 0.44))
			_append_colored_tri(verts, colors, Vector3(-0.07, 0.015, 0.50), Vector3(0.07, 0.015, 0.50), Vector3(0.0, 0.015, 2.35), Color(0.95, 0.98, 1.0, 0.86))
		Kind.ARC:
			_append_arc(verts, colors, -PI * 0.39, PI * 0.78, 1.12, 0.68, 18, true, Color(0.20, 0.73, 0.98, 0.53))
			_append_arc(verts, colors, -PI * 0.39, PI * 0.78, 1.67, 0.08, 18, true, Color(0.85, 0.98, 1.0, 0.82))
		Kind.SPIN:
			_append_arc(verts, colors, -PI, TAU, 1.12, 0.60, 28, false, Color(0.20, 0.73, 0.98, 0.53))
			_append_arc(verts, colors, -PI, TAU, 1.78, 0.08, 28, false, Color(0.85, 0.98, 1.0, 0.82))
		Kind.IMPACT:
			_append_shards(verts, colors, false)
		Kind.FIRE:
			_append_shards(verts, colors, true)
		Kind.CLAWS:
			for i in range(3):
				var lateral: float = (float(i) - 1.0) * 0.27
				_append_colored_tri(
					verts, colors,
					Vector3(lateral - 0.36, 0.58, 0.0),
					Vector3(lateral - 0.25, 0.63, 0.0),
					Vector3(lateral + 0.29, -0.40, 0.0),
					Color(0.95, 0.21, 0.24, 0.68)
				)
				_append_colored_tri(
					verts, colors,
					Vector3(lateral - 0.30, 0.50, 0.015),
					Vector3(lateral - 0.27, 0.53, 0.015),
					Vector3(lateral + 0.22, -0.30, 0.015),
					Color(1.0, 0.69, 0.58, 0.72)
				)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_cached_meshes[effect_kind] = result
	return result


static func _append_colored_tri(verts: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	verts.append(a)
	verts.append(b)
	verts.append(c)
	colors.append(col)
	colors.append(col)
	colors.append(col)


static func _append_colored_quad(verts: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color) -> void:
	_append_colored_tri(verts, colors, a, b, c, col)
	_append_colored_tri(verts, colors, a, c, d, col)


static func _append_arc(verts: PackedVector3Array, colors: PackedColorArray, start_angle: float, sweep: float, inner_radius: float, band: float, segments: int, tapered: bool, col: Color) -> void:
	for segment in range(segments):
		var t0: float = float(segment) / float(segments)
		var t1: float = float(segment + 1) / float(segments)
		var angle0: float = start_angle + t0 * sweep
		var angle1: float = start_angle + t1 * sweep
		var envelope0: float = maxf(0.035, pow(sin(PI * t0), 0.7)) if tapered else 1.0
		var envelope1: float = maxf(0.035, pow(sin(PI * t1), 0.7)) if tapered else 1.0
		var inner0 := Vector3(sin(angle0) * inner_radius, 0.0, cos(angle0) * inner_radius)
		var inner1 := Vector3(sin(angle1) * inner_radius, 0.0, cos(angle1) * inner_radius)
		var outer0_radius: float = inner_radius + band * envelope0
		var outer1_radius: float = inner_radius + band * envelope1
		var outer0 := Vector3(sin(angle0) * outer0_radius, 0.0, cos(angle0) * outer0_radius)
		var outer1 := Vector3(sin(angle1) * outer1_radius, 0.0, cos(angle1) * outer1_radius)
		_append_colored_quad(verts, colors, inner0, outer0, outer1, inner1, col)


static func _append_shards(verts: PackedVector3Array, colors: PackedColorArray, is_fire: bool) -> void:
	var base_color: Color = Color(1.0, 0.46, 0.12, 0.85) if is_fire else Color(0.89, 0.94, 1.0, 0.85)
	var count: int = SHARD_COUNT + (2 if is_fire else 0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 774 + (188 if is_fire else 47)
	for i in range(count):
		var angle: float = TAU * float(i) / float(count) + rng.randf_range(-0.15, 0.15)
		var dist: float = rng.randf_range(0.45, 0.85)
		var height: float = rng.randf_range(0.08, 0.42)
		var center := Vector3(cos(angle) * dist, height, sin(angle) * dist)
		var tangent := Vector3(-sin(angle), 0.0, cos(angle)) * 0.09
		var tip := center + Vector3(cos(angle) * 0.18, 0.18, sin(angle) * 0.18)
		_append_colored_tri(verts, colors, center - tangent, center + tangent, tip, base_color)
