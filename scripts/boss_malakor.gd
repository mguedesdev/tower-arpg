extends "res://scripts/enemy.gd"
class_name BossMalakor

## Chefe Supremo do Mapa 3 (Cripta do Carrasco): Malakor, o Ceifador de Almas.
## Modelo 3D exclusivo com 4 animações fluidas, golpes colossais de cutelo ("machadada"),
## onda de choque e Fase 2 de Enrage ("Fúria das Sombras").

signal enrage_entered()

const DEFAULT_BOSS_DEF_PATH: String = "res://content/enemies/boss_malakor.tres"
const BOSS_HIT_RANGE: float = 3.2
const ATTACK_COOLDOWN_P1: float = 1.25
const ATTACK_COOLDOWN_P2: float = 0.85

var is_enraged: bool = false
var _attack_variant: int = 0
var _cleave_delayed_timer: float = 0.0
var _cleave_pending_impact: bool = false


func _get_default_definition_path() -> String:
	return DEFAULT_BOSS_DEF_PATH


func _ready() -> void:
	super._ready()
	# Malakor é o grande chefe do ato: alcance de golpe condizente com seu cutelo de 2.6m
	turn_speed = 6.2


func _physics_process(delta: float) -> void:
	# Processamento de impacto retardado do golpe (sincronizado com a descida do machado no frame 12-14)
	if _cleave_pending_impact:
		_cleave_delayed_timer -= delta
		if _cleave_delayed_timer <= 0.0:
			_execute_cleave_impact()
			_cleave_pending_impact = false

	# Se for o Boss Malakor, usamos alcance maior para seu cutelo colossal
	if not alive or target == null:
		return

	var towards: Vector3 = target.global_position - global_position
	towards.y = 0.0
	var distance: float = towards.length()

	# Checa transição de Fase 2 (Enrage abaixo de 50% de HP)
	if not is_enraged and health <= int(maximum_health * 0.50):
		_enter_enrage_mode()

	# Executa IA base
	hit_timer = maxf(hit_timer - delta, 0.0)
	if distance < BOSS_HIT_RANGE and hit_timer <= 0.0 and not _is_attacking:
		_start_boss_attack()


func _start_boss_attack() -> void:
	var cd: float = ATTACK_COOLDOWN_P2 if is_enraged else ATTACK_COOLDOWN_P1
	hit_timer = cd
	_is_attacking = true
	_cleave_pending_impact = true
	# O impacto do machado ocorre no frame 12 de 24 (@ 24fps = 0.50s)
	_cleave_delayed_timer = 0.48

	# Alterna entre Machadada Vertical Devastadora (attack) e Varredura Ampla (attack_sweep)
	_attack_variant = (_attack_variant + 1) % 3
	var clip: StringName = &"attack" if _attack_variant != 2 else &"attack_sweep"

	if _animation_player != null and _animation_player.has_animation(clip):
		_attack_animation = clip
		_animation_player.speed_scale = 1.25 if is_enraged else 1.05
		_animation_player.play(clip, 0.08)
	else:
		_play_contact_attack()


func _execute_cleave_impact() -> void:
	if not alive:
		return

	var vfx_root: Node3D = get_tree().current_scene as Node3D
	var forward: Vector3 = -visual.global_basis.z if visual != null else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() > 0.001:
		forward = forward.normalized()

	var impact_pos: Vector3 = global_position + forward * 1.8 + Vector3.UP * 0.08

	# VFX de Tremor e Explosão de Chamas Negras no ponto onde o cutelo crava no chão
	if vfx_root != null:
		VFX.fire_burst(vfx_root, impact_pos, 1.4)
		VFX.impact(vfx_root, impact_pos, 1.1)

	# Causa dano de corte em área cônica na frente do boss
	if is_instance_valid(target):
		var to_target: Vector3 = target.global_position - global_position
		to_target.y = 0.0
		var dist: float = to_target.length()
		if dist <= (BOSS_HIT_RANGE + 0.6):
			var dot: float = forward.dot(to_target.normalized())
			if dot >= 0.35: # Arco de ~140 graus na frente
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
