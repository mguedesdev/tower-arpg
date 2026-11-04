extends CharacterBody3D
class_name TowerEnemy

signal died
signal health_changed(current: int, maximum: int)

# Mantidos os atributos e a logica de contato das versoes anteriores.
@export var enemy_definition: EnemyDefinition
@export var movement_speed: float = 2.3
@export var maximum_health: int = 32
@export var touch_damage: int = 8

const SKELETON_MODEL_PATH: String = "res://assets/models/skeleton_enemy.glb"
const DEFAULT_ENEMY_DEF_PATH: String = "res://content/enemies/skeleton_enemy.tres"
const VFX = preload("res://scripts/vfx/tower_vfx_spawner.gd")
const SkinnedCache = preload("res://core/utilities/skinned_model_cache.gd")
const EnemyDefScript = preload("res://core/combat/enemy_definition.gd")
const HealthBar3DScript = preload("res://core/combat/enemy_health_bar_3d.gd")

@export_range(0.1, 4.0, 0.05) var visual_scale: float = 1.0
@export_range(-180.0, 180.0, 5.0) var visual_yaw_degrees: float = 0.0
@export_range(-3.0, 3.0, 0.01) var visual_offset_y: float = 0.0
@export_range(1.0, 18.0, 0.5) var turn_speed: float = 8.5
@export_range(0.8, 3.5, 0.05) var health_bar_height: float = 1.96
@export_range(0.4, 2.5, 0.05) var health_bar_width_scale: float = 1.0
@export_range(0.4, 4.0, 0.05) var walk_stride_meters: float = 1.50
@export var xp_reward_multiplier: int = 1
@export var is_mini_boss: bool = false
@export var aggro_radius: float = 999.0

# Flash de hit: leve, curto e aplicado somente no inimigo atingido.
@export_range(0.05, 0.45, 0.01) var hit_flash_opacity: float = 0.22
@export_range(0.05, 0.40, 0.01) var hit_flash_duration: float = 0.16

@onready var visual: Node3D = get_node_or_null("Visual") as Node3D

var target: TowerPlayer
var health: int
var hit_timer: float = 0.0
var alive: bool = true
var health_bar: EnemyHealthBar3D

var _animation_player: AnimationPlayer
var _walk_animation: StringName = &""
var _idle_animation: StringName = &""
var _attack_animation: StringName = &""
var _requested_animation: StringName = &""
var _is_attacking: bool = false
var _aggro_triggered: bool = false
var _hit_flash_remaining: float = 0.0
var _hit_flash_material: StandardMaterial3D
var _hit_meshes: Array[GeometryInstance3D] = []
var _previous_overlays: Array[Material] = []
var _burn_remaining: float = 0.0
var _burn_dps: float = 0.0
var _burn_tick_timer: float = 0.0


func _ready() -> void:
	_apply_definition_defaults()
	health = maximum_health
	add_to_group("enemies")
	_load_real_enemy_if_available()
	_cache_hit_meshes(visual)
	_setup_health_bar()
	set_process(false)


func _apply_definition_defaults() -> void:
	if enemy_definition == null and ResourceLoader.exists(_get_default_definition_path()):
		enemy_definition = load(_get_default_definition_path()) as EnemyDefinition
	if enemy_definition == null:
		return
	health_bar_height = enemy_definition.health_bar_height
	health_bar_width_scale = enemy_definition.health_bar_width_scale
	visual_scale = enemy_definition.visual_scale
	visual_yaw_degrees = enemy_definition.visual_yaw_degrees
	visual_offset_y = enemy_definition.visual_offset_y
	walk_stride_meters = enemy_definition.walk_stride_meters
	xp_reward_multiplier = enemy_definition.xp_reward_multiplier
	is_mini_boss = enemy_definition.is_mini_boss


func _get_default_definition_path() -> String:
	return DEFAULT_ENEMY_DEF_PATH


func _get_model_path() -> String:
	if enemy_definition != null and not enemy_definition.model_path.is_empty():
		return enemy_definition.model_path
	return SKELETON_MODEL_PATH


func _setup_health_bar() -> void:
	if health_bar != null:
		return
	health_bar = HealthBar3DScript.new() as EnemyHealthBar3D
	health_bar.name = "HealthBar3D"
	add_child(health_bar)
	health_bar.configure(health_bar_height, health_bar_width_scale)
	health_bar.update_health(health, maximum_health, is_burning())
	if is_inside_tree():
		health_bar.align_to_camera(get_viewport())


func _load_real_enemy_if_available() -> void:
	if visual == null:
		return
	var target_model_path: String = _get_model_path()
	if not ResourceLoader.exists(target_model_path):
		push_warning("Enemy: %s ausente. Mantendo placeholder." % target_model_path)
		return

	var model: Node3D = SkinnedCache.instantiate_optimized(target_model_path)
	if model == null:
		push_warning("Enemy: cena importada nao possui raiz Node3D.")
		return

	model.name = "SkeletonImported"
	visual.add_child(model)
	model.scale = Vector3.ONE * visual_scale
	model.position.y = visual_offset_y
	model.rotation.y = deg_to_rad(visual_yaw_degrees)

	var placeholder_body: Node3D = visual.get_node_or_null("Body") as Node3D
	var placeholder_eyes: Node3D = visual.get_node_or_null("Eyes") as Node3D
	if placeholder_body != null:
		placeholder_body.visible = false
	if placeholder_eyes != null:
		placeholder_eyes.visible = false

	_animation_player = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if _animation_player == null:
		push_warning("Enemy: modelo importado sem AnimationPlayer. O rig pode nao ter sido exportado.")
		return

	_idle_animation = _find_animation(&"idle")
	if _idle_animation == &"":
		_idle_animation = _find_animation(&"idle-loop")
	_walk_animation = _find_animation(&"walk")
	if _walk_animation == &"":
		_walk_animation = _find_animation(&"walk-loop")
	_attack_animation = _find_animation(&"attack")

	if _idle_animation != &"":
		var idle: Animation = _animation_player.get_animation(_idle_animation)
		if idle != null:
			idle.loop_mode = Animation.LOOP_LINEAR
	else:
		push_warning("Enemy: animacao 'idle' ausente no GLB.")

	if _walk_animation != &"":
		var walk: Animation = _animation_player.get_animation(_walk_animation)
		if walk != null:
			walk.loop_mode = Animation.LOOP_LINEAR
			if walk.length > 1.50:
				push_warning("Enemy: walk com %.2f s acima do esperado." % walk.length)
	else:
		push_warning("Enemy: animacao 'walk' ausente no GLB.")

	if _attack_animation != &"":
		var atk: Animation = _animation_player.get_animation(_attack_animation)
		if atk != null:
			atk.loop_mode = Animation.LOOP_NONE
		if not _animation_player.animation_finished.is_connected(_on_enemy_animation_finished):
			_animation_player.animation_finished.connect(_on_enemy_animation_finished)

	_play_animation(_idle_animation)


func _find_animation(wanted: StringName) -> StringName:
	if _animation_player == null:
		return &""
	for key in _animation_player.get_animation_list():
		var full_name: String = String(key)
		var clip_label: String = full_name.get_slice("/", full_name.get_slice_count("/") - 1)
		clip_label = clip_label.get_slice("|", clip_label.get_slice_count("|") - 1)
		if clip_label.to_lower() == String(wanted):
			return key
	return &""


func _play_animation(clip: StringName) -> void:
	if _animation_player == null or clip == &"":
		return
	if _is_attacking and clip != _attack_animation:
		return
	if _requested_animation != clip or not _animation_player.is_playing():
		_requested_animation = clip
		_animation_player.play(clip, 0.14)


func set_target(new_target: TowerPlayer) -> void:
	target = new_target


func _physics_process(delta: float) -> void:
	if not alive:
		return
	if not is_instance_valid(target) or not target.alive:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_animation(_idle_animation)
		return

	var towards: Vector3 = target.global_position - global_position
	towards.y = 0.0
	var distance: float = towards.length()

	if not _aggro_triggered and distance <= aggro_radius:
		_aggro_triggered = true

	if not _aggro_triggered:
		velocity.x = 0.0
		velocity.z = 0.0
		_play_animation(_idle_animation)
		if health_bar != null and is_inside_tree():
			health_bar.align_to_camera(get_viewport())
		return

	var stop_distance: float = 0.85 if is_mini_boss else 0.70
	if distance > stop_distance:
		var motion: Vector3 = towards.normalized() * movement_speed
		velocity.x = motion.x
		velocity.z = motion.z
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# O boneco foi criado olhando para +Y no Blender -> frente local -Z no Godot.
	if towards.length_squared() > 0.0001:
		var desired_yaw: float = atan2(-towards.x, -towards.z)
		visual.rotation.y = lerp_angle(
			visual.rotation.y, desired_yaw, clampf(turn_speed * delta, 0.0, 1.0)
		)

	velocity.y = -0.1 if is_on_floor() else velocity.y - 20.0 * delta
	var before: Vector3 = global_position
	move_and_slide()

	var traveled: Vector3 = global_position - before
	traveled.y = 0.0
	var actually_moving: bool = traveled.length_squared() > 0.000025
	_play_animation(_walk_animation if actually_moving else _idle_animation)

	if _animation_player != null and not _is_attacking:
		if _walk_animation != &"" and _animation_player.current_animation == String(_walk_animation):
			var length: float = _animation_player.get_animation(_walk_animation).length
			_animation_player.speed_scale = clampf(
				movement_speed * length / maxf(walk_stride_meters, 0.25),
				0.80, 2.8
			)
		else:
			_animation_player.speed_scale = 1.0

	if health_bar != null and is_inside_tree():
		health_bar.align_to_camera(get_viewport())

	hit_timer = maxf(hit_timer - delta, 0.0)
	var hit_range: float = 1.38 if is_mini_boss else 1.15
	if distance < hit_range and hit_timer <= 0.0:
		hit_timer = 1.0
		target.take_damage(touch_damage)
		_play_contact_attack()


func _play_contact_attack() -> void:
	if is_inside_tree() and is_instance_valid(target):
		var vfx_root: Node3D = get_tree().current_scene as Node3D
		if vfx_root != null:
			var dir: Vector3 = (target.global_position - global_position)
			dir.y = 0.0
			var f_dir: Vector3 = dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD
			if is_mini_boss:
				VFX.arc(vfx_root, global_position + Vector3.UP * 0.95, f_dir, 0.92)
			else:
				VFX.claws(vfx_root, target.global_position + Vector3.UP * 0.80, f_dir, 0.72)
	if _animation_player == null or _attack_animation == &"":
		return
	_is_attacking = true
	_animation_player.speed_scale = 1.15 if not is_mini_boss else 0.95
	_animation_player.play(_attack_animation, 0.08)


func _on_enemy_animation_finished(finished_clip: StringName) -> void:
	if finished_clip != _attack_animation:
		return
	_is_attacking = false
	_requested_animation = &""
	_animation_player.speed_scale = 1.0
	_play_animation(_idle_animation)


func take_damage(amount: int) -> void:
	if not alive:
		return
	_aggro_triggered = true
	health = maxi(0, health - amount)
	health_changed.emit(health, maximum_health)
	var dmg_script = load("res://core/combat/floating_damage_number_3d.gd")
	if dmg_script != null and get_parent() != null:
		var dmg_num = dmg_script.new()
		get_parent().add_child(dmg_num)
		dmg_num.setup(amount, false, false, global_position)
	if health_bar != null:
		health_bar.update_health(health, maximum_health, is_burning())
	if health > 0:
		_begin_hit_flash()
	if health <= 0:
		alive = false
		_burn_remaining = 0.0
		remove_from_group("enemies")
		died.emit()
		queue_free()


func apply_burn(dps: float, duration: float) -> void:
	if not alive or dps <= 0.0 or duration <= 0.0:
		return
	_burn_dps = maxf(_burn_dps, dps)
	_burn_remaining = maxf(_burn_remaining, duration)
	if _burn_tick_timer <= 0.0:
		_burn_tick_timer = 0.5
	if health_bar != null:
		health_bar.update_health(health, maximum_health, true)
	set_process(true)


func is_burning() -> bool:
	return alive and _burn_remaining > 0.0


# ---- Efeito visual de dano: nao altera materiais originais do GLB. ----
func _cache_hit_meshes(node: Node) -> void:
	if node == null:
		return
	if node is MeshInstance3D:
		var mesh_node: GeometryInstance3D = node as GeometryInstance3D
		if mesh_node.is_visible_in_tree():
			_hit_meshes.append(mesh_node)
	for child in node.get_children():
		_cache_hit_meshes(child)


func _begin_hit_flash() -> void:
	if _hit_meshes.is_empty():
		return
	var flash_mat: StandardMaterial3D = SkinnedCache.get_hit_flash_material(1.0, hit_flash_opacity)
	if _hit_flash_remaining <= 0.0:
		_previous_overlays.clear()
		for geometry in _hit_meshes:
			_previous_overlays.append(geometry.material_overlay)
			geometry.material_overlay = flash_mat
	else:
		for geometry in _hit_meshes:
			if is_instance_valid(geometry):
				geometry.material_overlay = flash_mat
	_hit_flash_remaining = hit_flash_duration
	set_process(true)


func _process(delta: float) -> void:
	if _burn_remaining > 0.0 and alive:
		_burn_remaining = maxf(_burn_remaining - delta, 0.0)
		_burn_tick_timer -= delta
		if _burn_tick_timer <= 0.0:
			_burn_tick_timer = 0.5
			var tick_dmg: int = maxi(1, roundi(_burn_dps * 0.5))
			var vfx_root: Node3D = get_tree().current_scene as Node3D if is_inside_tree() else null
			var burn_pos: Vector3 = global_position + Vector3.UP * 0.65
			take_damage(tick_dmg)
			if vfx_root != null:
				VFX.fire_burst(vfx_root, burn_pos, 0.55)
			if not alive:
				return
		if _burn_remaining <= 0.0:
			_burn_dps = 0.0
			if health_bar != null:
				health_bar.update_health(health, maximum_health, false)

	if _hit_flash_remaining > 0.0:
		_hit_flash_remaining = maxf(_hit_flash_remaining - delta, 0.0)
		if _hit_flash_remaining > 0.0:
			var fade: float = _hit_flash_remaining / maxf(hit_flash_duration, 0.001)
			var step_mat: StandardMaterial3D = SkinnedCache.get_hit_flash_material(fade, hit_flash_opacity)
			for geometry in _hit_meshes:
				if is_instance_valid(geometry) and geometry.material_overlay != step_mat:
					geometry.material_overlay = step_mat
		else:
			for index in range(_hit_meshes.size()):
				if is_instance_valid(_hit_meshes[index]) and index < _previous_overlays.size():
					_hit_meshes[index].material_overlay = _previous_overlays[index]
			_previous_overlays.clear()

	if _hit_flash_remaining <= 0.0 and _burn_remaining <= 0.0:
		set_process(false)
