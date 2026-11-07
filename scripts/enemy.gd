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
const MonsterDifficultyServiceScript = preload("res://core/combat/monster_difficulty_service.gd")

@export var monster_level: int = 1
@export var monster_rank: int = LootBalanceConfig.MonsterClass.NORMAL
@export var combat_archetype: String = "melee"

var active_modifiers: Array[Dictionary] = []
var display_title: String = ""
var damage_reduction_pct: float = 0.0
var regen_pct_sec: float = 0.0
var regen_cooldown: float = 3.0
var _regen_cooldown_timer: float = 0.0
var burn_on_hit_ratio: float = 0.0
var burn_on_hit_duration: float = 0.0
var slow_on_hit_pct: float = 0.0
var slow_on_hit_duration: float = 0.0
var aura_radius: float = 0.0
var aura_dmg_mult: float = 1.0
var aura_spd_mult: float = 1.0
var _aura_timer: float = 0.0
var _commander_buff_time_left: float = 0.0
var _base_unbuffed_touch_damage: int = -1
var _base_unbuffed_speed: float = -1.0

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
@export var show_overhead_health_bar: bool = true
@export var custom_stop_distance: float = -1.0
@export var custom_hit_range: float = -1.0

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
	if not show_overhead_health_bar or health_bar != null:
		return
	health_bar = HealthBar3DScript.new() as EnemyHealthBar3D
	health_bar.name = "HealthBar3D"
	add_child(health_bar)
	health_bar.configure(health_bar_height, health_bar_width_scale)
	if monster_rank != LootBalanceConfig.MonsterClass.NORMAL:
		var r_cfg: Dictionary = MonsterDifficultyServiceScript.RANK_CONFIG.get(monster_rank, {})
		var r_color: Color = r_cfg.get("color", Color.WHITE)
		health_bar.configure_rank(monster_rank, display_title, r_color)
	health_bar.update_health(health, maximum_health, is_burning())
	if is_inside_tree():
		health_bar.align_to_camera(get_viewport())


func configure_difficulty(
	lvl: int,
	rank_val: int = LootBalanceConfig.MonsterClass.NORMAL,
	arch: String = "melee",
	forced_modifiers: Array = [],
	rng: RandomNumberGenerator = null
) -> void:
	monster_level = maxi(1, lvl)
	monster_rank = rank_val
	combat_archetype = arch

	if forced_modifiers.is_empty():
		if monster_rank == LootBalanceConfig.MonsterClass.MAGIC or monster_rank == LootBalanceConfig.MonsterClass.RARE or monster_rank == LootBalanceConfig.MonsterClass.HERO:
			active_modifiers = MonsterDifficultyServiceScript.roll_modifiers(monster_level, monster_rank, combat_archetype, ["undead"], rng)
		else:
			active_modifiers = []
	else:
		active_modifiers.clear()
		for fm in forced_modifiers:
			if fm is Dictionary:
				active_modifiers.append(fm)

	var ref_hp: int = enemy_definition.base_max_health if enemy_definition != null else maximum_health
	var ref_dmg: int = enemy_definition.base_touch_damage if enemy_definition != null else touch_damage
	var ref_spd: float = enemy_definition.base_movement_speed if enemy_definition != null else movement_speed

	var stats: Dictionary = MonsterDifficultyServiceScript.resolve_monster_stats(
		ref_hp, ref_dmg, ref_spd, monster_level, monster_rank, combat_archetype, active_modifiers
	)

	maximum_health = int(stats["max_health"])
	health = maximum_health
	touch_damage = int(stats["touch_damage"])
	movement_speed = float(stats["movement_speed"])
	damage_reduction_pct = float(stats["damage_reduction_pct"])
	regen_pct_sec = float(stats["regen_pct_sec"])
	regen_cooldown = float(stats["regen_cooldown"])
	burn_on_hit_ratio = float(stats["burn_ratio"])
	burn_on_hit_duration = float(stats["burn_duration"])
	slow_on_hit_pct = float(stats["slow_pct"])
	slow_on_hit_duration = float(stats["slow_duration"])
	aura_radius = float(stats["aura_radius"])
	aura_dmg_mult = float(stats["aura_dmg_mult"])
	aura_spd_mult = float(stats["aura_spd_mult"])
	xp_reward_multiplier = maxi(1, roundi(float(stats["xp_reward_mult"])))

	var base_name: String = enemy_definition.display_name if enemy_definition != null else "Inimigo"
	display_title = MonsterDifficultyServiceScript.build_monster_title(base_name, monster_rank, active_modifiers)

	if health_bar != null:
		health_bar.configure_rank(monster_rank, display_title, stats["rank_color"])
		health_bar.update_health(health, maximum_health, is_burning())

	if regen_pct_sec > 0.0 or aura_radius > 0.0:
		set_process(true)


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

	var stop_distance: float = custom_stop_distance if custom_stop_distance > 0.0 else (0.85 if is_mini_boss else 0.70)
	if distance > stop_distance and not _is_attacking:
		var motion: Vector3 = towards.normalized() * movement_speed
		velocity.x = motion.x
		velocity.z = motion.z
	else:
		velocity.x = 0.0
		velocity.z = 0.0

	# O boneco foi criado olhando para +Y no Blender -> frente local -Z no Godot.
	if towards.length_squared() > 0.0001:
		var desired_yaw: float = atan2(-towards.x, -towards.z)
		var turn_rate: float = turn_speed if not _is_attacking else turn_speed * 0.25
		visual.rotation.y = lerp_angle(
			visual.rotation.y, desired_yaw, clampf(turn_rate * delta, 0.0, 1.0)
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
	var hit_range: float = custom_hit_range if custom_hit_range > 0.0 else (1.38 if is_mini_boss else 1.15)
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
		if burn_on_hit_ratio > 0.0 and target.has_method("apply_burn"):
			var b_dps: float = float(touch_damage) * burn_on_hit_ratio
			target.call("apply_burn", b_dps, burn_on_hit_duration)
		if slow_on_hit_pct > 0.0 and target.has_method("apply_slow"):
			target.call("apply_slow", slow_on_hit_pct, slow_on_hit_duration)
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
	var mitigated: int = maxi(1, roundi(float(amount) * (1.0 - damage_reduction_pct)))
	_regen_cooldown_timer = regen_cooldown
	if regen_pct_sec > 0.0:
		set_process(true)
	health = maxi(0, health - mitigated)
	health_changed.emit(health, maximum_health)
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


func receive_commander_pulse(dmg_mult: float, spd_mult: float) -> void:
	if not alive:
		return
	if _base_unbuffed_touch_damage < 0:
		_base_unbuffed_touch_damage = touch_damage
		_base_unbuffed_speed = movement_speed
		touch_damage = roundi(float(touch_damage) * dmg_mult)
		movement_speed = movement_speed * spd_mult
	_commander_buff_time_left = 1.0
	set_process(true)


func _pulse_commander_aura() -> void:
	if not is_inside_tree() or aura_radius <= 0.0 or not alive:
		return
	var allies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	var rad_sq: float = aura_radius * aura_radius
	for ally in allies:
		if ally == self or not (ally is Node3D) or not is_instance_valid(ally):
			continue
		if not ally.get("alive"):
			continue
		var a3d: Node3D = ally as Node3D
		if global_position.distance_squared_to(a3d.global_position) <= rad_sq:
			if ally.has_method("receive_commander_pulse"):
				ally.call("receive_commander_pulse", aura_dmg_mult, aura_spd_mult)


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

	# Regeneracao passiva apos resfriamento de dano
	if regen_pct_sec > 0.0 and alive and health < maximum_health:
		if _regen_cooldown_timer > 0.0:
			_regen_cooldown_timer -= delta
		else:
			var heal_amount: float = float(maximum_health) * regen_pct_sec * delta
			var heal_int: int = maxi(1, roundi(heal_amount))
			health = mini(maximum_health, health + heal_int)
			health_changed.emit(health, maximum_health)
			if health_bar != null:
				health_bar.update_health(health, maximum_health, is_burning())

	# Aura de Comandante
	if aura_radius > 0.0 and alive and is_inside_tree():
		_aura_timer -= delta
		if _aura_timer <= 0.0:
			_aura_timer = 0.5
			_pulse_commander_aura()

	# Decaimento do buff recebido de comandante
	if _commander_buff_time_left > 0.0:
		_commander_buff_time_left -= delta
		if _commander_buff_time_left <= 0.0 and _base_unbuffed_touch_damage >= 0:
			touch_damage = _base_unbuffed_touch_damage
			movement_speed = _base_unbuffed_speed
			_base_unbuffed_touch_damage = -1
			_base_unbuffed_speed = -1.0

	var needs_process: bool = (
		_hit_flash_remaining > 0.0 or
		_burn_remaining > 0.0 or
		(regen_pct_sec > 0.0 and health < maximum_health) or
		(aura_radius > 0.0 and alive) or
		(_commander_buff_time_left > 0.0)
	)
	if not needs_process:
		set_process(false)
