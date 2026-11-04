extends Node
class_name TowerAttackController

signal form_changed(label: String)
signal attack_hit(target: Node3D)

enum Form { STAB = 0, ARC = 1, SPIN = 2, PIERCE = 3 }

const DEFAULT_ABILITY_PATH: String = "res://content/abilities/warrior_strike.tres"
const VFX = preload("res://scripts/vfx/tower_vfx_spawner.gd")

@export var auto_attack: bool = true
@export var allow_debug_form_keys: bool = false
@export var damage: int = 14
# O alvo e mantido, mesmo que o jogador ande para o lado (strafe).
@export_range(2.0, 12.0, 0.5) var detection_radius: float = 4.5
@export_range(2.0, 15.0, 0.5) var release_radius: float = 6.0
@export_range(0.2, 1.0, 0.05) var retarget_ratio: float = 0.6
@export_range(5.0, 60.0, 1.0) var attack_alignment_degrees: float = 12.0

@onready var character: TowerPlayer = get_parent() as TowerPlayer
@onready var visual: Node3D = character.get_node_or_null("Visual") as Node3D if character != null else null
@onready var attack_visual: MeshInstance3D = visual.get_node_or_null("AttackVisual") as MeshInstance3D if visual != null else null

var active_form: Form = Form.STAB
var ability_state: AbilityRuntimeState
var attack_remaining: float = 0.0
var flash_remaining: float = 0.0
var current_target: TowerEnemy = null
var _echo_pending_timer: float = 0.0
var _echo_pending_ratio: float = 0.0
var _attack_material: StandardMaterial3D


func _init() -> void:
	var default_def: AbilityDefinition = null
	if ResourceLoader.exists(DEFAULT_ABILITY_PATH):
		default_def = load(DEFAULT_ABILITY_PATH) as AbilityDefinition
	ability_state = AbilityRuntimeState.new(default_def)


func _ready() -> void:
	_attack_material = StandardMaterial3D.new()
	_attack_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_attack_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_attack_material.albedo_color = Color(1.0, 0.48, 0.13, 0.52)
	_attack_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if attack_visual != null:
		attack_visual.material_override = _attack_material
	sync_from_ability_state()


func bind_ability_state(new_state: AbilityRuntimeState) -> void:
	ability_state = new_state if new_state != null else AbilityRuntimeState.new()
	sync_from_ability_state()


func sync_from_ability_state() -> void:
	if ability_state != null:
		active_form = clampi(ability_state.active_behavior, 0, 3) as Form
	_update_visual_tint()
	_rebuild_effect()
	form_changed.emit(form_label())


func _update_visual_tint() -> void:
	if _attack_material == null:
		return
	if ability_state != null and ability_state.has_special_modifier("burn"):
		_attack_material.albedo_color = Color(1.0, 0.34, 0.10, 0.62)
	elif active_form == Form.PIERCE:
		_attack_material.albedo_color = Color(0.55, 0.88, 0.96, 0.54)
	elif active_form == Form.ARC:
		_attack_material.albedo_color = Color(0.45, 0.76, 1.0, 0.52)
	elif active_form == Form.SPIN:
		_attack_material.albedo_color = Color(0.95, 0.76, 0.32, 0.54)
	else:
		_attack_material.albedo_color = Color(1.0, 0.48, 0.13, 0.52)


func _physics_process(delta: float) -> void:
	if character == null or not character.alive:
		if attack_visual != null:
			attack_visual.visible = false
		if character != null:
			character.set_combat_target(null)
		_echo_pending_timer = 0.0
		return

	if allow_debug_form_keys:
		if Input.is_action_just_pressed("form_stab"):
			set_form(Form.STAB)
		elif Input.is_action_just_pressed("form_arc"):
			set_form(Form.ARC)
		elif Input.is_action_just_pressed("form_spin"):
			set_form(Form.SPIN)

	if _echo_pending_timer > 0.0:
		_echo_pending_timer -= delta
		if _echo_pending_timer <= 0.0:
			var ratio: float = _echo_pending_ratio
			_echo_pending_ratio = 0.0
			_execute_attack(true, ratio)

	attack_remaining = maxf(attack_remaining - delta, 0.0)
	flash_remaining = maxf(flash_remaining - delta, 0.0)
	if attack_visual != null:
		attack_visual.visible = flash_remaining > 0.0

	if not auto_attack:
		current_target = null
		character.set_combat_target(null)
		return

	_update_combat_target()
	if current_target == null:
		character.set_combat_target(null)
		return

	var direction_to_target: Vector3 = current_target.global_position - character.global_position
	direction_to_target.y = 0.0
	var active_radius: float = _radius()
	if direction_to_target.length_squared() > active_radius * active_radius:
		character.set_combat_target(null)
		return

	# So trava a rotacao no alvo quando o golpe estiver prestes a sair (ultimos 0.18s do cooldown).
	# Assim o cavaleiro olha para onde esta andando entre os ataques e nao desliza de lado/costas!
	if attack_remaining > 0.18:
		character.set_combat_target(null)
		return

	character.set_combat_target(current_target)
	if attack_remaining > 0.0:
		return

	# Primeiro vira de verdade; somente depois aplica o golpe.
	# Giro 360 nao depende da orientacao do corpo para atingir inimigos.
	if active_form != Form.SPIN and not character.is_facing_direction(direction_to_target, attack_alignment_degrees):
		return
	_execute_attack(false, 1.0)


# Recebe Variant para nao forcar o Godot a converter um objeto ja destruido
# para TowerEnemy ANTES de validarmos a existencia da instancia.
func _is_valid_enemy(enemy: Variant) -> bool:
	if not is_instance_valid(enemy):
		return false
	if not (enemy is TowerEnemy):
		return false
	var valid_enemy: TowerEnemy = enemy as TowerEnemy
	return valid_enemy.alive and not valid_enemy.is_queued_for_deletion()


func _update_combat_target() -> void:
	var effective_detect: float = maxf(detection_radius, _radius() + 1.2)
	var effective_release: float = maxf(release_radius, effective_detect + 1.5)
	var current_distance_squared: float = INF
	if _is_valid_enemy(current_target):
		current_distance_squared = character.global_position.distance_squared_to(current_target.global_position)
		if current_distance_squared > effective_release * effective_release:
			current_target = null
	else:
		current_target = null

	var nearest: TowerEnemy = null
	var nearest_distance_squared: float = effective_detect * effective_detect
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not _is_valid_enemy(candidate):
			continue
		var enemy: TowerEnemy = candidate as TowerEnemy
		var distance_squared: float = character.global_position.distance_squared_to(enemy.global_position)
		if distance_squared < nearest_distance_squared:
			nearest_distance_squared = distance_squared
			nearest = enemy

	if current_target == null:
		current_target = nearest
	elif nearest != null and nearest != current_target:
		# Evita mudancas constantes de alvo quando varios mobs estao proximos.
		if nearest_distance_squared < current_distance_squared * retarget_ratio:
			current_target = nearest


func set_form(new_form: Form) -> void:
	active_form = new_form
	if ability_state != null:
		match new_form:
			Form.ARC:
				ability_state.apply_transformation("debug_arc", AbilityDefinition.Behavior.ARC, "Meia-lua", {"radius": 2.45, "half_angle": PI * 0.5, "cooldown": 0.95, "max_targets": 6})
			Form.SPIN:
				ability_state.apply_transformation("debug_spin", AbilityDefinition.Behavior.SPIN, "Giro 360", {"radius": 2.25, "half_angle": PI, "cooldown": 1.15, "max_targets": 10})
			Form.PIERCE:
				ability_state.apply_transformation("debug_pierce", AbilityDefinition.Behavior.PIERCE, "Perfuração", {"radius": 4.4, "half_angle": 0.22, "corridor_width": 1.05, "cooldown": 0.78, "max_targets": 8})
			_:
				ability_state.setup_from_definition(ability_state.definition)
	_update_visual_tint()
	_rebuild_effect()
	form_changed.emit(form_label())


func form_label() -> String:
	if ability_state != null and not ability_state.active_display_name.is_empty():
		return ability_state.active_display_name
	match active_form:
		Form.ARC:
			return "Meia-lua"
		Form.SPIN:
			return "Giro 360"
		Form.PIERCE:
			return "Perfuração"
		_:
			return "Estocada"


func _get_character_stats() -> CharacterStats:
	if character != null and character.get("stats") != null:
		return character.stats
	return null


func _radius() -> float:
	if ability_state != null and ability_state.active_behavior == int(active_form):
		return ability_state.get_effective_radius(_get_character_stats())
	match active_form:
		Form.ARC:
			return 2.35
		Form.SPIN:
			return 2.05
		Form.PIERCE:
			return 4.4
		_:
			return 2.7


func _half_angle() -> float:
	if ability_state != null and ability_state.active_behavior == int(active_form) and ability_state.behavior_half_angle_override > 0.0:
		return ability_state.get_effective_half_angle()
	match active_form:
		Form.ARC:
			return PI * 0.5
		Form.SPIN:
			return PI
		Form.PIERCE:
			return 0.22
		_:
			return 0.28


func _corridor_width() -> float:
	if ability_state != null:
		return ability_state.get_effective_corridor_width(_get_character_stats())
	return 1.0


func _cooldown() -> float:
	if ability_state != null and ability_state.active_behavior == int(active_form):
		return ability_state.get_effective_cooldown(_get_character_stats())
	match active_form:
		Form.ARC:
			return 1.05
		Form.SPIN:
			return 1.3
		Form.PIERCE:
			return 0.78
		_:
			return 0.8


func get_effective_attack_damage(damage_scale: float = 1.0) -> int:
	var base_dmg: int = damage
	var stats: CharacterStats = _get_character_stats()
	if ability_state != null and stats != null:
		base_dmg = ability_state.get_effective_damage(stats)
	elif stats != null:
		base_dmg = stats.get_damage()
	return maxi(1, roundi(float(base_dmg) * maxf(0.1, damage_scale)))


func is_offset_inside_active_geometry(offset: Vector3, forward: Vector3) -> bool:
	var flat_offset: Vector3 = Vector3(offset.x, 0.0, offset.z)
	var distance: float = flat_offset.length()
	var max_rad: float = _radius()
	if distance > max_rad or distance < 0.001:
		return false

	var flat_forward: Vector3 = Vector3(forward.x, 0.0, forward.z).normalized()
	if flat_forward.length_squared() < 0.0001:
		flat_forward = Vector3.BACK

	match active_form:
		Form.SPIN:
			return true
		Form.PIERCE:
			# Geometria linear de Perfuração: feixe retangular longo à frente que atravessa múltiplos alvos.
			var forward_proj: float = flat_forward.dot(flat_offset)
			if forward_proj < -0.10 or forward_proj > max_rad:
				return false
			var right_vec: Vector3 = Vector3(flat_forward.z, 0.0, -flat_forward.x)
			var lateral_dist: float = absf(right_vec.dot(flat_offset))
			return lateral_dist <= (_corridor_width() * 0.55)
		_:
			var cosine_threshold: float = cos(_half_angle())
			return flat_forward.dot(flat_offset / distance) >= cosine_threshold


func _execute_attack(is_secondary_echo: bool = false, damage_scale: float = 1.0) -> int:
	if not is_secondary_echo:
		attack_remaining = _cooldown()
	flash_remaining = 0.16
	if attack_visual != null:
		attack_visual.visible = true

	var anim_form: int = int(active_form)
	if active_form == Form.PIERCE:
		anim_form = 0 # Perfuração utiliza a animação de estocada/lança frontal.
	if character != null and not is_secondary_echo:
		character.play_attack_animation(anim_form)

	var forward: Vector3 = visual.global_basis.z if visual != null else Vector3.BACK
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.BACK
	forward = forward.normalized()

	var world_vfx_root: Node3D = get_tree().current_scene as Node3D if is_inside_tree() else null
	if world_vfx_root != null and character != null:
		var world_vfx_origin: Vector3 = character.global_position + Vector3.UP * 0.8
		var vfx_scale: float = 0.78 if is_secondary_echo else 1.0
		match active_form:
			Form.STAB:
				VFX.stab(world_vfx_root, world_vfx_origin, forward, vfx_scale)
			Form.PIERCE:
				VFX.stab(world_vfx_root, world_vfx_origin, forward, vfx_scale * 1.45)
			Form.ARC:
				VFX.arc(world_vfx_root, world_vfx_origin, forward, vfx_scale)
			Form.SPIN:
				VFX.spin(world_vfx_root, world_vfx_origin, vfx_scale)

	var hit_candidates: Array[TowerEnemy] = []
	if is_inside_tree() and character != null:
		for candidate in get_tree().get_nodes_in_group("enemies"):
			if not _is_valid_enemy(candidate):
				continue
			var enemy: TowerEnemy = candidate as TowerEnemy
			var offset: Vector3 = enemy.global_position - character.global_position
			if is_offset_inside_active_geometry(offset, forward):
				hit_candidates.append(enemy)

	# Ordena pelos mais próximos para respeitar o limite de alvos de forma determinística.
	if character != null and hit_candidates.size() > 1:
		var origin_pos: Vector3 = character.global_position
		hit_candidates.sort_custom(func(a: TowerEnemy, b: TowerEnemy) -> bool:
			return origin_pos.distance_squared_to(a.global_position) < origin_pos.distance_squared_to(b.global_position)
		)

	var max_targets: int = ability_state.get_effective_max_targets() if ability_state != null else 6
	var hit_count: int = 0
	var strike_damage: int = get_effective_attack_damage(damage_scale)
	var allow_secondary: bool = ability_state != null and ability_state.can_trigger_secondary_effects(is_secondary_echo)

	for enemy in hit_candidates:
		if hit_count >= max_targets:
			break
		if not _is_valid_enemy(enemy):
			continue
		var enemy_hit_point: Vector3 = enemy.global_position + Vector3.UP * 0.7
		enemy.take_damage(strike_damage)
		hit_count += 1
		if world_vfx_root != null and hit_count <= 3:
			VFX.impact(world_vfx_root, enemy_hit_point, 0.6)
		if allow_secondary and ability_state.has_special_modifier("burn"):
			var burn_data: Dictionary = ability_state.get_special_modifier("burn")
			var burn_dps: float = float(burn_data.get("dps", 6.0))
			var burn_dur: float = float(burn_data.get("duration", 3.0))
			if _is_valid_enemy(enemy):
				enemy.apply_burn(burn_dps, burn_dur)
			if world_vfx_root != null and hit_count <= 3:
				VFX.fire_burst(world_vfx_root, enemy_hit_point, 0.7)
		attack_hit.emit(enemy)

	# Eco de ataque: somente ataques primários podem agendar um eco (nunca recursivo).
	if allow_secondary and ability_state.has_special_modifier("echo"):
		var echo_data: Dictionary = ability_state.get_special_modifier("echo")
		_echo_pending_timer = maxf(0.08, float(echo_data.get("delay", 0.20)))
		_echo_pending_ratio = clampf(float(echo_data.get("damage_ratio", 0.55)), 0.1, 1.0)

	return hit_count


func _rebuild_effect() -> void:
	if attack_visual == null:
		return
	var vertices: PackedVector3Array = PackedVector3Array()
	var rad: float = _radius()
	if active_form == Form.PIERCE:
		var half_w: float = _corridor_width() * 0.5
		var body_len: float = maxf(0.4, rad * 0.82)
		# Retângulo longo + ponta de lança para deixar a leitura visual de Perfuração clara no chão.
		vertices.append(Vector3(-half_w, 0, 0))
		vertices.append(Vector3(half_w, 0, 0))
		vertices.append(Vector3(half_w, 0, body_len))
		vertices.append(Vector3(-half_w, 0, 0))
		vertices.append(Vector3(half_w, 0, body_len))
		vertices.append(Vector3(-half_w, 0, body_len))
		vertices.append(Vector3(-half_w * 1.15, 0, body_len))
		vertices.append(Vector3(half_w * 1.15, 0, body_len))
		vertices.append(Vector3(0, 0, rad))
	else:
		var start_angle: float = -_half_angle()
		var full_angle: float = _half_angle() * 2.0
		var segments: int = 32 if active_form == Form.SPIN else 18
		for index in range(segments):
			var angle_a: float = start_angle + full_angle * float(index) / float(segments)
			var angle_b: float = start_angle + full_angle * float(index + 1) / float(segments)
			vertices.append(Vector3(0, 0, 0))
			vertices.append(Vector3(sin(angle_a) * rad, 0, cos(angle_a) * rad))
			vertices.append(Vector3(sin(angle_b) * rad, 0, cos(angle_b) * rad))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	attack_visual.mesh = mesh
