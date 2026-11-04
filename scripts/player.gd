extends CharacterBody3D
class_name TowerPlayer

signal health_changed(current: int, maximum: int)
signal died

@export var move_speed: float = 6.2
# Movimento responsivo de action RPG: acelera rapidamente e freia ainda mais rapido.
# Valores em unidades/segundo ao quadrado; ajustaveis no Inspetor.
@export_range(5.0, 160.0, 1.0) var move_acceleration: float = 55.0
@export_range(5.0, 160.0, 1.0) var move_deceleration: float = 85.0
@export_range(5.0, 200.0, 1.0) var reverse_acceleration: float = 105.0
@export_range(0.01, 0.5, 0.01) var movement_stop_threshold: float = 0.12
# Acopla ritmo da caminhada ao deslocamento real; ataque continua em velocidade normal.
@export_range(0.4, 1.0, 0.05) var minimum_walk_animation_speed: float = 0.65
@export_range(1.0, 8.0, 0.05) var walk_stride_meters: float = 5.15
# A movimentacao nao gira o corpo quando existe um alvo de combate.
# Angulos em graus/segundo: virada suave, sem teleportar a rotacao.
@export_range(90.0, 720.0, 10.0) var movement_turn_degrees: float = 380.0
@export_range(90.0, 720.0, 10.0) var combat_turn_degrees: float = 540.0
@export_range(0.1, 0.8, 0.05) var attack_facing_hold: float = 0.22
@export var gravity_strength: float = 23.0
@export var max_health: int = 100

# O arquivo GLB e carregado automaticamente na execucao, sem editar a cena.
# Se nao existir, mantemos o personagem de teste.
const KNIGHT_MODEL_PATH: String = "res://assets/models/knight.glb"
const DEFAULT_CLASS_PATH: String = "res://content/classes/warrior_class.tres"
const SkinnedCache = preload("res://core/utilities/skinned_model_cache.gd")
const OverheadHUDScript = preload("res://core/combat/player_overhead_hud_3d.gd")
@export_range(0.1, 4.0, 0.05) var knight_visual_scale: float = 1.0
@export_range(-180.0, 180.0, 5.0) var knight_yaw_degrees: float = 0.0
@export var character_definition: CharacterDefinition

@onready var visual: Node3D = $Visual
@onready var attack_controller: Node = $AttackController
@onready var skill_controller: PlayerSkillController = get_node_or_null("SkillController") as PlayerSkillController
var overhead_hud: PlayerOverheadHUD3D

var stats: CharacterStats = CharacterStats.new()
var health: int = 100
var alive: bool = true
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var locomotion_blend: float = 0.0
var attacking_animation: bool = false
var combat_target: Node3D = null
var facing_hold_remaining: float = 0.0
var _has_pierce_shot: bool = false
var _stab_shot_node: AnimationNodeOneShot = null
var _arc_shot_node: AnimationNodeOneShot = null
var _pierce_shot_node: AnimationNodeOneShot = null
var _visual_bank_angle: float = 0.0
var _visual_pitch_angle: float = 0.0
var _attack_lunge_timer: float = 0.0
var _attack_lunge_duration: float = 0.22
var _attack_lunge_distance: float = 0.0
var _last_move_dir: Vector3 = Vector3.ZERO
var _last_real_speed: float = 0.0
var in_lobby_mode: bool = false
var lobby_yaw_degrees: float = 36.0
## Modo Campanha ARPG: direção de perseguição ao mob clicado (WASD sempre tem prioridade).
var chase_direction: Vector3 = Vector3.ZERO
## Trava o movimento enquanto executa um golpe/skill (cast lock).
var cast_lock_remaining: float = 0.0


## Retorna true se o jogador está apertando WASD/setas neste frame.
func has_manual_move_input() -> bool:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down").length_squared() > 0.01


## Vira o Cavaleiro na hora para a direção da mira/alvo (resposta instantânea estilo PoE 2).
func face_towards(direction: Vector3, hold_time: float = 0.30) -> void:
	var flat: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat.length_squared() < 0.0001 or visual == null:
		return
	visual.rotation.y = atan2(flat.x, flat.z)
	facing_hold_remaining = maxf(facing_hold_remaining, hold_time)

func set_lobby_mode(enabled: bool) -> void:
	in_lobby_mode = enabled
	chase_direction = Vector3.ZERO
	cast_lock_remaining = 0.0
	if skill_controller != null:
		skill_controller.set_enabled(not enabled)
	if overhead_hud != null:
		overhead_hud.visible = not enabled
	if enabled:
		velocity = Vector3.ZERO
		combat_target = null
		if visual != null:
			visual.rotation.y = deg_to_rad(lobby_yaw_degrees)
			visual.rotation.x = 0.0
			visual.rotation.z = 0.0

func _ready() -> void:
	motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	floor_stop_on_slope = true
	floor_constant_speed = true
	floor_snap_length = 0.25
	floor_max_angle = deg_to_rad(45.0)
	wall_min_slide_angle = deg_to_rad(15.0)
	if skill_controller == null:
		skill_controller = get_node_or_null("SkillController") as PlayerSkillController
		if skill_controller == null:
			var sc_script: Script = load("res://scripts/player_skill_controller.gd") as Script
			if sc_script != null:
				skill_controller = sc_script.new() as PlayerSkillController
				skill_controller.name = "SkillController"
				add_child(skill_controller)
	_register_input_actions()
	if character_definition == null and ResourceLoader.exists(DEFAULT_CLASS_PATH):
		character_definition = load(DEFAULT_CLASS_PATH) as CharacterDefinition
	_initialize_stats()
	_load_real_knight_if_available()
	animation_player = visual.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if animation_player != null:
		_configure_imported_animations()
		if not _setup_animation_tree():
			# Fallback para modelos antigos sem tracks suficientes para o overlay.
			animation_player.animation_finished.connect(_on_animation_finished)
			_play_model_animation("idle-loop")
	overhead_hud = OverheadHUDScript.new() as PlayerOverheadHUD3D
	overhead_hud.name = "PlayerOverheadHUD"
	overhead_hud.position = Vector3(0.0, 2.15, 0.0)
	add_child(overhead_hud)
	overhead_hud.update_health(health, max_health)
	health_changed.connect(func(cur: int, max_hp: int):
		if overhead_hud != null:
			overhead_hud.update_health(cur, max_hp)
	)

	health_changed.emit(health, max_health)


func _initialize_stats() -> void:
	if stats == null:
		stats = CharacterStats.new()
	if not stats.stats_changed.is_connected(_on_stats_changed):
		stats.stats_changed.connect(_on_stats_changed)
	if not stats.health_changed.is_connected(_on_internal_health_changed):
		stats.health_changed.connect(_on_internal_health_changed)
	if character_definition != null:
		stats.configure_from_definition(character_definition)
	else:
		stats.set_base_stat(CharacterStats.STAT_MAX_HEALTH, float(max_health))
		stats.set_base_stat(CharacterStats.STAT_MOVE_SPEED, move_speed)
		stats.set_current_health(max_health)
	_sync_from_stats()


func configure_character(new_definition: CharacterDefinition) -> void:
	character_definition = new_definition
	alive = true
	_initialize_stats()


func _sync_from_stats() -> void:
	if stats == null:
		return
	move_speed = stats.get_move_speed()
	max_health = stats.get_max_health()
	health = stats.current_health


func _on_stats_changed() -> void:
	_sync_from_stats()


func _on_internal_health_changed(current_hp: int, maximum_hp: int) -> void:
	health = current_hp
	max_health = maximum_hp
	health_changed.emit(health, max_health)

func _load_real_knight_if_available() -> void:
	if not ResourceLoader.exists(KNIGHT_MODEL_PATH):
		print("Knight: GLB ainda nao encontrado; usando placeholder.")
		return
	var model: Node3D = SkinnedCache.instantiate_optimized(KNIGHT_MODEL_PATH)
	if model == null:
		push_warning("Knight: cena importada nao tem raiz Node3D.")
		return
	model.name = "KnightImported"
	visual.add_child(model)
	model.scale = Vector3.ONE * knight_visual_scale
	model.rotation.y = deg_to_rad(knight_yaw_degrees)
	var placeholder: Node3D = visual.get_node_or_null("PlaceholderKnight") as Node3D
	if placeholder != null:
		placeholder.visible = false

# Os nomes -loop do Blender ajudam na importacao, mas o runtime tambem garante o loop.
# No rig atual: walk = 24 frames @24 FPS (1s), idle = 48 frames (2s).
# Se um export antigo tiver clipe de 15s com movimento apenas no inicio, limitamos
# a duracao para nao deixar o personagem deslizar enquanto os ossos ficam parados.
func _configure_imported_animations() -> void:
	if animation_player == null:
		return
	var walk_name: String = _find_animation_name("walk-loop")
	var idle_name: String = _find_animation_name("idle-loop")
	var attack_names: Array[String] = [
		_find_animation_name("attack_stab"),
		_find_animation_name("attack_arc"),
		_find_animation_name("attack_spin"),
		_find_animation_name("attack_pierce"),
		_find_animation_name("attack")
	]
	for clip_key in animation_player.get_animation_list():
		var clip_name: String = String(clip_key)
		var clip: Animation = animation_player.get_animation(clip_key)
		if clip == null:
			continue
		if clip_name == walk_name:
			clip.loop_mode = Animation.LOOP_LINEAR
			if clip.length > 1.35:
				push_warning("Walk importado com duracao %.2fs; limitando a 1.0s." % clip.length)
				clip.length = 1.0
		elif clip_name == idle_name:
			clip.loop_mode = Animation.LOOP_LINEAR
			if clip.length > 2.5:
				push_warning("Idle importado com duracao %.2fs; limitando a 2.0s." % clip.length)
				clip.length = 2.0
		elif clip_name in attack_names:
			clip.loop_mode = Animation.LOOP_NONE
		print("Clip importado: %s (%.2fs, loop=%d)" % [clip_name, clip.length, clip.loop_mode])
	print("Animacoes de ataque: estocada=%s | meia-lua=%s | giro=%s" % [
		attack_names[0], attack_names[1], attack_names[2]
	])

func _physics_process(delta: float) -> void:
	if not alive:
		return
	if stats != null:
		stats.tick_temporary_modifiers(delta)

	# Input.get_vector ja limita as diagonais e respeita a intensidade do analogico.
	# Nao normalizar o resultado: isso faria um toque leve no controle virar 100%.
	var input_axis: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var desired_direction: Vector3 = _camera_relative_direction(input_axis)
	if input_axis.length_squared() > 0.0001:
		cast_lock_remaining = 0.0
		chase_direction = Vector3.ZERO
	else:
		if chase_direction.length_squared() > 0.0001:
			desired_direction = Vector3(chase_direction.x, 0.0, chase_direction.z).limit_length(1.0)
		cast_lock_remaining = maxf(cast_lock_remaining - delta, 0.0)
		if cast_lock_remaining > 0.0:
			desired_direction = Vector3.ZERO
	var target_horizontal_velocity: Vector2 = Vector2(desired_direction.x, desired_direction.z) * move_speed
	var current_horizontal_velocity: Vector2 = Vector2(velocity.x, velocity.z)

	# Inercia curta, nao escorregadia. Inverter direcao deve ser mais rapido do
	# que uma curva longa, mas sem trocar a velocidade instantaneamente.
	var acceleration: float = move_deceleration
	if target_horizontal_velocity.length_squared() > 0.0001:
		acceleration = move_acceleration
		if current_horizontal_velocity.length_squared() > 0.0001 and current_horizontal_velocity.dot(target_horizontal_velocity) < 0.0:
			acceleration = reverse_acceleration

	current_horizontal_velocity = current_horizontal_velocity.move_toward(
		target_horizontal_velocity, acceleration * delta
	)
	if target_horizontal_velocity.is_zero_approx() and current_horizontal_velocity.length() < movement_stop_threshold:
		current_horizontal_velocity = Vector2.ZERO

	if in_lobby_mode:
		velocity = Vector3.ZERO
		_last_move_dir = Vector3.ZERO
		_last_real_speed = 0.0
		facing_hold_remaining = maxf(facing_hold_remaining - delta, 0.0)
		visual.rotation.y = lerp_angle(visual.rotation.y, deg_to_rad(lobby_yaw_degrees), clampf(delta * 8.0, 0.0, 1.0))
		visual.rotation.x = 0.0
		visual.rotation.z = 0.0
		visual.position = Vector3.ZERO
		if animation_tree != null or not attacking_animation:
			_update_locomotion_animation(0.0, delta)
		return

	velocity.x = current_horizontal_velocity.x
	velocity.z = current_horizontal_velocity.y
	if is_on_floor():
		velocity.y = -0.05
	else:
		velocity.y -= gravity_strength * delta

	move_and_slide()

	# Usar deslocamento real impede walk parado quando a colisao bloqueia o corpo.
	var real_motion: Vector3 = get_real_velocity()
	real_motion.y = 0.0
	var real_speed: float = real_motion.length()

	_last_move_dir = real_motion if real_speed > movement_stop_threshold else desired_direction
	_last_real_speed = real_speed
	facing_hold_remaining = maxf(facing_hold_remaining - delta, 0.0)
	_update_visual_facing(_last_move_dir, delta, _last_real_speed)
	visual.position = Vector3.ZERO
	if animation_tree != null or not attacking_animation:
		_update_locomotion_animation(real_speed, delta)


func _camera_relative_direction(input_axis: Vector2) -> Vector3:
	if input_axis.length_squared() < 0.0001:
		return Vector3.ZERO

	var direction: Vector3 = Vector3(input_axis.x, 0.0, input_axis.y)
	var active_camera: Camera3D = get_viewport().get_camera_3d()
	if active_camera != null:
		var right: Vector3 = active_camera.global_basis.x
		var forward: Vector3 = -active_camera.global_basis.z
		right.y = 0.0
		forward.y = 0.0
		if right.length_squared() > 0.0001 and forward.length_squared() > 0.0001:
			direction = right.normalized() * input_axis.x - forward.normalized() * input_axis.y

	# Limitamos apenas valores acima de 1: joystick parcial continua parcial.
	return direction.limit_length(1.0)


# Camada base: Idle/Walk toca continuamente, inclusive durante o ataque.
# Camada superior: OneShot do golpe modifica so torso/cabeca/bracos/espada.
# Blender exportou 'walk' e 'idle', sem '-loop'. A chave real sempre vence.
func _find_animation_name(requested: String) -> String:
	if animation_player == null:
		return ""
	var aliases: Array[String] = [requested]
	if requested.ends_with("-loop"):
		aliases.append(requested.trim_suffix("-loop"))
	# Primeiro procura o nome exato; so depois usa o alias importado.
	for alias in aliases:
		for clip_key in animation_player.get_animation_list():
			var text_name: String = String(clip_key)
			if text_name == alias or text_name.ends_with("/" + alias) or text_name.ends_with("|" + alias):
				return text_name
	return ""


# Cria uma camada de ataque de tronco (estocada/meia-lua/perfuracao),
# preservando a locomocao das pernas. O giro usa corpo inteiro.
func _upper_body_oneshot(clip: Animation) -> AnimationNodeOneShot:
	var shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	shot.fadein_time = 0.04
	shot.fadeout_time = 0.10
	shot.filter_enabled = true
	var allowed_bones: Array[String] = [
		"spine", "head", "cape", "upper_arm.l", "upper_arm.r",
		"forearm.l", "forearm.r", "hand.l", "hand.r", "sword.r"
	]
	var matches: int = 0
	for index in range(clip.get_track_count()):
		var path: NodePath = clip.track_get_path(index)
		var path_lower: String = String(path).to_lower()
		var subname: String = ""
		if path.get_subname_count() > 0:
			subname = String(path.get_subname(0)).to_lower()
		for bone in allowed_bones:
			if subname == bone or path_lower.ends_with(":" + bone) or path_lower.contains(":" + bone + ":"):
				shot.set_filter_path(path, true)
				matches += 1
				break
	if matches == 0:
		push_warning("Nenhuma trilha superior encontrada em %s (verifique o GLB)." % clip.resource_name)
	return shot


func _setup_animation_tree() -> bool:
	var idle_name: String = _find_animation_name("idle-loop")
	var walk_name: String = _find_animation_name("walk-loop")
	var stab_name: String = _find_animation_name("attack_stab")
	var arc_name: String = _find_animation_name("attack_arc")
	var spin_name: String = _find_animation_name("attack_spin")
	var pierce_name: String = _find_animation_name("attack_pierce")
	if pierce_name.is_empty():
		pierce_name = stab_name
	if idle_name.is_empty() or walk_name.is_empty() or stab_name.is_empty() or arc_name.is_empty() or spin_name.is_empty():
		push_error("Knight v0.8.1: clipes ausentes para o jogo. Idle=%s Walk=%s Stab=%s Arc=%s Spin=%s. Confira o GLB da v0.8 no laboratorio F6." % [idle_name, walk_name, stab_name, arc_name, spin_name])
		return false

	var stab_clip: Animation = animation_player.get_animation(stab_name)
	var arc_clip: Animation = animation_player.get_animation(arc_name)
	var spin_clip: Animation = animation_player.get_animation(spin_name)
	var pierce_clip: Animation = animation_player.get_animation(pierce_name)
	if stab_clip == null or arc_clip == null or spin_clip == null:
		push_error("Knight v0.8.1: AnimationPlayer nao disponibilizou os tres golpes.")
		return false

	var root: AnimationNodeBlendTree = AnimationNodeBlendTree.new()
	var idle_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	idle_node.animation = StringName(idle_name)
	var walk_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	walk_node.animation = StringName(walk_name)
	var stab_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	stab_node.animation = StringName(stab_name)
	var arc_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	arc_node.animation = StringName(arc_name)
	var spin_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	spin_node.animation = StringName(spin_name)
	var pierce_node: AnimationNodeAnimation = AnimationNodeAnimation.new()
	pierce_node.animation = StringName(pierce_name)

	var walk_speed_node: AnimationNodeTimeScale = AnimationNodeTimeScale.new()
	var locomotion_node: AnimationNodeBlend2 = AnimationNodeBlend2.new()
	var stab_shot: AnimationNodeOneShot = _upper_body_oneshot(stab_clip)
	var arc_shot: AnimationNodeOneShot = _upper_body_oneshot(arc_clip)
	var pierce_shot: AnimationNodeOneShot = _upper_body_oneshot(pierce_clip if pierce_clip != null else stab_clip)
	_stab_shot_node = stab_shot
	_arc_shot_node = arc_shot
	_pierce_shot_node = pierce_shot
	var spin_shot: AnimationNodeOneShot = AnimationNodeOneShot.new()
	spin_shot.fadein_time = 0.04
	spin_shot.fadeout_time = 0.12
	# O giro anima o quadril e pernas; nao aplicar filtro de tronco!
	spin_shot.filter_enabled = false

	root.add_node("Idle", idle_node)
	root.add_node("Walk", walk_node)
	root.add_node("WalkRate", walk_speed_node)
	root.add_node("Locomotion", locomotion_node)
	root.add_node("Stab", stab_node)
	root.add_node("Arc", arc_node)
	root.add_node("Spin", spin_node)
	root.add_node("Pierce", pierce_node)
	root.add_node("StabShot", stab_shot)
	root.add_node("ArcShot", arc_shot)
	root.add_node("SpinShot", spin_shot)
	root.add_node("PierceShot", pierce_shot)

	root.connect_node("WalkRate", 0, "Walk")
	root.connect_node("Locomotion", 0, "Idle")
	root.connect_node("Locomotion", 1, "WalkRate")
	root.connect_node("StabShot", 0, "Locomotion")
	root.connect_node("StabShot", 1, "Stab")
	root.connect_node("ArcShot", 0, "StabShot")
	root.connect_node("ArcShot", 1, "Arc")
	root.connect_node("PierceShot", 0, "ArcShot")
	root.connect_node("PierceShot", 1, "Pierce")
	root.connect_node("SpinShot", 0, "PierceShot")
	root.connect_node("SpinShot", 1, "Spin")
	root.connect_node("output", 0, "SpinShot")
	_has_pierce_shot = true

	animation_player.stop()
	var tree: AnimationTree = AnimationTree.new()
	tree.name = "KnightAnimationTree"
	visual.add_child(tree)
	tree.anim_player = tree.get_path_to(animation_player)
	tree.tree_root = root
	tree.active = true
	tree.set("parameters/Locomotion/blend_amount", 0.0)
	tree.set("parameters/WalkRate/scale", 1.0)
	animation_tree = tree
	print("Knight v1.0: locomocao + estocada + meia-lua + giro + perfuracao ligados no gameplay.")
	return true

func _update_locomotion_animation(real_speed: float, delta: float) -> void:
	if animation_player == null:
		return
	if animation_tree != null:
		var ratio: float = clampf(real_speed / maxf(move_speed, 0.01), 0.0, 1.35)
		var target_blend: float = clampf(ratio * 2.1, 0.0, 1.0)
		var blend_rate: float = 18.0 if target_blend > locomotion_blend else 14.0
		locomotion_blend = move_toward(locomotion_blend, target_blend, delta * blend_rate)
		animation_tree.set("parameters/Locomotion/blend_amount", locomotion_blend)
		# Sincroniza a cadência das passadas (em ritmo natural ~1.2x) e inverte se andar de costas no meio do ataque!
		var stride_scale: float = clampf(real_speed / maxf(walk_stride_meters, 0.25), minimum_walk_animation_speed, 1.35)
		var facing_forward: Vector3 = visual.global_basis.z
		facing_forward.y = 0.0
		if _last_move_dir.length_squared() > 0.01 and facing_forward.length_squared() > 0.01:
			if facing_forward.normalized().dot(_last_move_dir.normalized()) < -0.20:
				stride_scale = -stride_scale
		animation_tree.set("parameters/WalkRate/scale", stride_scale)
		return

	# Compatibilidade caso o usuario ainda esteja com GLB antigo.
	if real_speed >= movement_stop_threshold:
		if _play_model_animation("walk-loop"):
			var stride_scale: float = real_speed / maxf(walk_stride_meters, 0.25)
			animation_player.speed_scale = clampf(stride_scale, minimum_walk_animation_speed, 1.35)
	else:
		if _play_model_animation("idle-loop"):
			animation_player.speed_scale = 1.0


# O AttackController escolhe o alvo; somente o Player controla a rotacao.
func set_combat_target(target: Node3D) -> void:
	combat_target = target

func _update_visual_facing(move_direction: Vector3, delta: float, real_speed: float = 0.0) -> void:
	var speed_ratio: float = clampf(real_speed / maxf(move_speed, 0.01), 0.0, 1.25)
	var target_pitch: float = deg_to_rad(3.2) * speed_ratio
	_visual_pitch_angle = move_toward(_visual_pitch_angle, target_pitch, delta * deg_to_rad(28.0))
	visual.rotation.x = _visual_pitch_angle

	# O golpe conserva a orientacao durante os frames iniciais de impacto.
	if facing_hold_remaining > 0.0:
		_visual_bank_angle = move_toward(_visual_bank_angle, 0.0, delta * deg_to_rad(45.0))
		visual.rotation.z = _visual_bank_angle
		return

	var desired_direction: Vector3 = Vector3.ZERO
	var turn_rate: float = movement_turn_degrees
	if is_instance_valid(combat_target) and not combat_target.is_queued_for_deletion():
		desired_direction = combat_target.global_position - global_position
		desired_direction.y = 0.0
		turn_rate = combat_turn_degrees
	elif move_direction.length_squared() > 0.01:
		desired_direction = move_direction

	if desired_direction.length_squared() < 0.0001:
		_visual_bank_angle = move_toward(_visual_bank_angle, 0.0, delta * deg_to_rad(45.0))
		visual.rotation.z = _visual_bank_angle
		return

	var desired_yaw: float = atan2(desired_direction.x, desired_direction.z)
	var remaining: float = wrapf(desired_yaw - visual.rotation.y, -PI, PI)
	var maximum_step: float = deg_to_rad(turn_rate) * delta
	visual.rotation.y = wrapf(
		visual.rotation.y + clampf(remaining, -maximum_step, maximum_step),
		-PI, PI
	)
	var target_bank: float = clampf(-remaining * 0.22 * speed_ratio, deg_to_rad(-8.5), deg_to_rad(8.5))
	_visual_bank_angle = move_toward(_visual_bank_angle, target_bank, delta * deg_to_rad(55.0))
	visual.rotation.z = _visual_bank_angle


func _update_attack_lunge_visual(delta: float) -> void:
	if _attack_lunge_timer <= 0.0:
		if visual.position.length_squared() > 0.00001:
			visual.position = visual.position.move_toward(Vector3.ZERO, delta * 2.5)
		return
	_attack_lunge_timer = maxf(0.0, _attack_lunge_timer - delta)
	var progress: float = 1.0 - (_attack_lunge_timer / maxf(0.01, _attack_lunge_duration))
	# Curva rápida de avanço no impacto (pico em 35% do golpe) e retorno suave.
	var envelope: float = sin(clampf(progress, 0.0, 1.0) * PI)
	var forward_dir: Vector3 = Vector3(sin(visual.rotation.y), 0.0, cos(visual.rotation.y))
	visual.position = forward_dir * (_attack_lunge_distance * envelope)


func is_facing_direction(direction: Vector3, tolerance_degrees: float) -> bool:
	var flat_direction: Vector3 = direction
	flat_direction.y = 0.0
	if flat_direction.length_squared() < 0.0001:
		return true
	var forward: Vector3 = visual.global_basis.z
	forward.y = 0.0
	return forward.normalized().dot(flat_direction.normalized()) >= cos(deg_to_rad(tolerance_degrees))

# Form = 0 estocada, 1 meia-lua, 2 giro, 3 perfuracao (mesma ordem do AttackController).
# A locomocao continua nas pernas para estocada, meia-lua e perfuracao.
func play_attack_animation(form: int = 0) -> void:
	facing_hold_remaining = attack_facing_hold
	var clip_name: String = "attack_stab"
	_attack_lunge_duration = 0.22
	_attack_lunge_distance = 0.14
	match form:
		1:
			clip_name = "attack_arc"
			_attack_lunge_duration = 0.25
			_attack_lunge_distance = 0.11
		2:
			clip_name = "attack_spin"
			_attack_lunge_duration = 0.28
			_attack_lunge_distance = 0.06
		3:
			clip_name = "attack_pierce"
			_attack_lunge_duration = 0.28
			_attack_lunge_distance = 0.24
		_:
			clip_name = "attack_stab"
	_attack_lunge_timer = _attack_lunge_duration

	if animation_tree != null:
		# Se o jogador estiver parado/quase parado, usa o golpe FULL-BODY (com passo, bacia e joelhos).
		# Se estiver correndo, ativa o filtro de tronco para manter as pernas na animação de corrida!
		var use_upper_filter: bool = locomotion_blend > 0.25
		if _stab_shot_node != null:
			_stab_shot_node.filter_enabled = use_upper_filter
		if _arc_shot_node != null:
			_arc_shot_node.filter_enabled = use_upper_filter
		if _pierce_shot_node != null:
			_pierce_shot_node.filter_enabled = use_upper_filter

		# Cancela golpes que estejam terminando para nao sobrepor ataques.
		animation_tree.set("parameters/StabShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		animation_tree.set("parameters/ArcShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		animation_tree.set("parameters/SpinShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		if _has_pierce_shot:
			animation_tree.set("parameters/PierceShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		match form:
			1:
				animation_tree.set("parameters/ArcShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			2:
				animation_tree.set("parameters/SpinShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			3:
				if _has_pierce_shot:
					animation_tree.set("parameters/PierceShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
				else:
					animation_tree.set("parameters/StabShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
			_:
				animation_tree.set("parameters/StabShot/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)
		return

	# Diagnostico/fallback: sem AnimationTree, reproduz o clip correspondente.
	# O fallback nao mantem walk em paralelo; a v0.8.1 deve usar a arvore acima.
	if animation_player != null:
		animation_player.speed_scale = 1.0
	if _play_model_animation(clip_name, true):
		attacking_animation = true
	elif _play_model_animation("attack", true):
		push_warning("Knight: golpe %s indisponivel. Reproduzindo ataque antigo." % clip_name)
		attacking_animation = true

func _play_model_animation(clip_name: String, restart: bool = false) -> bool:
	if animation_player == null:
		return false
	var match_name: String = _find_animation_name(clip_name)
	if match_name.is_empty():
		return false
	if restart or animation_player.current_animation != match_name or not animation_player.is_playing():
		animation_player.play(match_name, 0.12)
	return true

func _on_animation_finished(animation_name: StringName) -> void:
	if String(animation_name).ends_with("attack"):
		attacking_animation = false

func take_damage(amount: int) -> void:
	if not alive:
		return
	if stats != null:
		stats.apply_damage(amount)
		health = stats.current_health
		max_health = stats.get_max_health()
	else:
		health = maxi(health - amount, 0)
		health_changed.emit(health, max_health)
	var dmg_script = load("res://core/combat/floating_damage_number_3d.gd")
	if dmg_script != null and get_parent() != null:
		var dmg_num = dmg_script.new()
		get_parent().add_child(dmg_num)
		dmg_num.setup(amount, false, true, global_position)
	if health == 0:
		alive = false
		velocity = Vector3.ZERO
		died.emit()

func _register_input_actions() -> void:
	# Mantemos os controles centralizados em ações para permitir joystick mobile posteriormente.
	var bindings: Dictionary = {
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP],
		"move_down": [KEY_S, KEY_DOWN],
		"form_stab": [KEY_1],
		"form_arc": [KEY_2],
		"form_spin": [KEY_3],
		"restart": [KEY_R]
	}
	for action_name in bindings:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
		if InputMap.action_get_events(action_name).size() > 0:
			continue
		for physical_code in bindings[action_name]:
			var event: InputEventKey = InputEventKey.new()
			event.physical_keycode = physical_code
			InputMap.action_add_event(action_name, event)
