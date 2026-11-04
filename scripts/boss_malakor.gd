extends "res://scripts/enemy.gd"
class_name BossMalakor

## Chefe Supremo do Mapa 3 (Cripta do Carrasco): Malakor, o Ceifador de Almas.
## Possui habilidades mortais:
## 1. Machadada Descendente Frontal ("Cleave Devastador") com impacto de chamas e terra.
## 2. Arremesso de Cutelo Encorrentado ("Correntes do Carrasco"): arremessa o cutelo
##    giratório à distância e, se acertar, puxa o jogador violentamente para seus pés!
## 3. Fase 2 (Enrage / "Fúria das Sombras") abaixo de 50% de HP.

signal enrage_entered()

const DEFAULT_BOSS_DEF_PATH: String = "res://content/enemies/boss_malakor.tres"
const HOOK_SCRIPT: Script = preload("res://game/campaign/boss_cleaver_hook_3d.gd")

const HOOK_MIN_RANGE: float = 3.8
const HOOK_MAX_RANGE: float = 13.5
const HOOK_COOLDOWN_P1: float = 6.5
const HOOK_COOLDOWN_P2: float = 4.0

var is_enraged: bool = false
var _attack_variant: int = 0
var _cleave_delayed_timer: float = 0.0
var _cleave_pending_impact: bool = false

var _hook_cooldown_timer: float = 3.0
var _is_channeling_hook: bool = false
var _hook_windup_timer: float = 0.0
var _active_hook_projectile: Node3D = null


func _get_default_definition_path() -> String:
	return DEFAULT_BOSS_DEF_PATH


func _ready() -> void:
	show_overhead_health_bar = false
	custom_stop_distance = 2.3
	custom_hit_range = 3.2
	super._ready()
	# Garante a remoção da barra de vida da cabeça (o chefe usa exclusivamente a barra da HUD)
	if health_bar != null:
		health_bar.visible = false
		health_bar.queue_free()
		health_bar = null
	turn_speed = 7.2


func _physics_process(delta: float) -> void:
	if not alive:
		return

	# Impacto da machadada retardada
	if _cleave_pending_impact:
		_cleave_delayed_timer -= delta
		if _cleave_delayed_timer <= 0.0:
			_execute_cleave_impact()
			_cleave_pending_impact = false

	# Transição de Fase 2 (Enrage abaixo de 50% de HP)
	if not is_enraged and health <= int(maximum_health * 0.50):
		_enter_enrage_mode()

	# ---------------- CANALIZAÇÃO DO GANCHO DE CUTELO ----------------
	if _is_channeling_hook:
		velocity.x = 0.0
		velocity.z = 0.0
		# Gira rápido em direção ao alvo durante o windup
		if is_instance_valid(target):
			var towards_p: Vector3 = target.global_position - global_position
			towards_p.y = 0.0
			if towards_p.length_squared() > 0.001:
				var desired_yaw: float = atan2(-towards_p.x, -towards_p.z)
				visual.rotation.y = lerp_angle(visual.rotation.y, desired_yaw, clampf(turn_speed * 1.5 * delta, 0.0, 1.0))

		_hook_windup_timer -= delta
		if _hook_windup_timer <= 0.0:
			_is_channeling_hook = false
			_fire_cleaver_hook()
		move_and_slide()
		return

	# Recarga da skill de arremesso de cutelo
	_hook_cooldown_timer = maxf(_hook_cooldown_timer - delta, 0.0)
	if not _is_attacking and _hook_cooldown_timer <= 0.0 and is_instance_valid(target) and _active_hook_projectile == null:
		var dist_to_target: float = global_position.distance_to(target.global_position)
		if dist_to_target >= HOOK_MIN_RANGE and dist_to_target <= HOOK_MAX_RANGE:
			_start_hook_windup()
			return

	# Executa toda a movimentação, colisão, perseguição e rotação base do TowerEnemy
	super._physics_process(delta)


func _start_hook_windup() -> void:
	_is_channeling_hook = true
	_hook_windup_timer = 0.38
	_is_attacking = false
	velocity = Vector3.ZERO

	# Animação de erguer a lâmina para arremesso
	if _animation_player != null and _animation_player.has_animation(&"attack_sweep"):
		_animation_player.speed_scale = 1.35
		_animation_player.play(&"attack_sweep", 0.06)

	# Efeito de aviso prévio (telegraph) no chão / pés do boss
	var vfx_root: Node3D = get_tree().current_scene as Node3D
	if vfx_root != null:
		VFX.spin(vfx_root, global_position + Vector3.UP * 0.4, 1.8)


func _fire_cleaver_hook() -> void:
	if not alive or not is_instance_valid(target):
		return

	_hook_cooldown_timer = HOOK_COOLDOWN_P2 if is_enraged else HOOK_COOLDOWN_P1

	var forward: Vector3 = -visual.global_basis.z if visual != null else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		forward = forward.normalized()

	var spawn_origin: Vector3 = global_position + forward * 0.8 + Vector3.UP * 1.4

	# Instancia o projétil encorrentado
	var hook: Node3D = HOOK_SCRIPT.new() as Node3D
	var scene_root: Node3D = get_tree().current_scene as Node3D
	if scene_root != null:
		scene_root.add_child(hook)
	else:
		get_parent().add_child(hook)

	hook.global_position = spawn_origin
	hook.call("launch", self, target, forward)
	_active_hook_projectile = hook

	# Conecta para combo imediato ao acertar o jogador
	hook.hit_player.connect(_on_hook_successfully_hit_player)
	hook.finished.connect(func() -> void:
		_active_hook_projectile = null
	)

	# Efeito sonoro / visual de lançamento de aço
	if scene_root != null:
		VFX.fire_burst(scene_root, spawn_origin, 1.2)


func _on_hook_successfully_hit_player(_player_node: Node) -> void:
	# O jogador foi fisgado e está sendo arrastado para os pés do Boss!
	# Prepara a machadada devastadora imediata (combo clássico do Carrasco)
	hit_timer = 0.35 # Dá 0.35s para o player aterrissar antes do corte descer
	_is_attacking = false


func _play_contact_attack() -> void:
	_is_attacking = true
	_cleave_pending_impact = true
	_cleave_delayed_timer = 0.46
	hit_timer = 0.90 if is_enraged else 1.30

	_attack_variant = (_attack_variant + 1) % 3
	var clip: StringName = &"attack" if _attack_variant != 2 else &"attack_sweep"

	if _animation_player != null and _animation_player.has_animation(clip):
		_attack_animation = clip
		_animation_player.speed_scale = 1.25 if is_enraged else 1.05
		_animation_player.play(clip, 0.08)
	else:
		super._play_contact_attack()


func _execute_cleave_impact() -> void:
	if not alive:
		return

	var vfx_root: Node3D = get_tree().current_scene as Node3D
	var forward: Vector3 = -visual.global_basis.z if visual != null else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		forward = forward.normalized()

	var impact_pos: Vector3 = global_position + forward * 1.8 + Vector3.UP * 0.08

	if vfx_root != null:
		VFX.fire_burst(vfx_root, impact_pos, 1.4)
		VFX.impact(vfx_root, impact_pos, 1.1)

	if is_instance_valid(target):
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		var dist: float = to_target.length()
		if dist <= 3.8:
			var dot: float = forward.dot(to_target.normalized())
			if dot >= 0.25:
				var dmg: int = int(float(touch_damage) * (1.25 if is_enraged else 1.0))
				target.take_damage(dmg)


func _enter_enrage_mode() -> void:
	is_enraged = true
	movement_speed *= 1.22
	turn_speed *= 1.35
	enrage_entered.emit()

	var vfx_root: Node3D = get_tree().current_scene as Node3D
	if vfx_root != null:
		VFX.fire_burst(vfx_root, global_position + Vector3.UP * 1.5, 2.2)
		VFX.spin(vfx_root, global_position + Vector3.UP * 1.0, 2.5)
