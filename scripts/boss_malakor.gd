extends "res://scripts/enemy.gd"
class_name BossMalakor

## Chefe Supremo do Mapa 3 (Cripta do Carrasco): Malakor, o Ceifador de Almas.
## Modelo 3D exclusivo com 4 animações fluidas, golpes colossais de cutelo ("machadada"),
## onda de choque e Fase 2 de Enrage ("Fúria das Sombras").

signal enrage_entered()

const DEFAULT_BOSS_DEF_PATH: String = "res://content/enemies/boss_malakor.tres"

var is_enraged: bool = false
var _attack_variant: int = 0
var _cleave_delayed_timer: float = 0.0
var _cleave_pending_impact: bool = false


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
	if _cleave_pending_impact:
		_cleave_delayed_timer -= delta
		if _cleave_delayed_timer <= 0.0:
			_execute_cleave_impact()
			_cleave_pending_impact = false

	if not is_enraged and alive and health <= int(maximum_health * 0.50):
		_enter_enrage_mode()

	# Executa toda a movimentação, colisão, perseguição e rotação base do TowerEnemy
	super._physics_process(delta)


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
