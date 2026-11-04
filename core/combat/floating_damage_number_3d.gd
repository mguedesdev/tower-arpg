extends Node3D
class_name FloatingDamageNumber3D
## Número de dano flutuante em 3D (estilo Albion Online / ARPG).
## Sobe suavemente e desaparece com fade out de 0.8s.

var _label: Label3D
var _lifetime: float = 0.85
var _elapsed: float = 0.0
var _velocity: Vector3 = Vector3(0.0, 1.6, 0.0)


func setup(damage: int, is_crit: bool, is_player_damage: bool, spawn_pos: Vector3) -> void:
	global_position = spawn_pos + Vector3(randf_range(-0.25, 0.25), 1.6 + randf_range(-0.1, 0.1), randf_range(-0.25, 0.25))

	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.render_priority = 30
	_label.outline_render_priority = 29
	_label.pixel_size = 0.0075
	_label.font_size = 36 if is_crit else 28
	_label.outline_size = 10 if is_crit else 8
	_label.outline_modulate = Color(0.01, 0.01, 0.02, 1.0)

	if is_player_damage:
		# Dano sofrido pelo herói (vermelho vivo como no Albion "-50")
		_label.modulate = Color(1.0, 0.25, 0.25, 1.0)
		_label.text = "-%d" % damage
	elif is_crit:
		# Dano crítico causado aos inimigos (amarelo/dourado brilhante)
		_label.modulate = Color(1.0, 0.95, 0.20, 1.0)
		_label.text = "✦ %d!" % damage
	else:
		# Dano normal causado aos inimigos (laranja/âmbar quente)
		_label.modulate = Color(1.0, 0.78, 0.35, 1.0)
		_label.text = "%d" % damage

	add_child(_label)


func _process(delta: float) -> void:
	_elapsed += delta
	position += _velocity * delta
	_velocity.y = maxf(0.3, _velocity.y - delta * 1.5)

	if _label != null:
		var alpha: float = clampf(1.0 - (_elapsed / _lifetime), 0.0, 1.0)
		_label.modulate.a = alpha

	if _elapsed >= _lifetime:
		queue_free()
