extends RefCounted
class_name StatModifier
## Representa uma modificação individual sobre um atributo do personagem.
## Nunca compartilhe a mesma instância mutável entre personagens distintos.

enum Op {
	FLAT = 0,
	PERCENT_ADD = 1,
	MULTIPLY = 2,
}

var id: String = ""
var source_tag: String = ""
var stat_name: StringName = &""
var op: int = Op.FLAT
var value: float = 0.0
var duration: float = -1.0
var remaining_time: float = -1.0


func _init(
	p_id: String = "",
	p_stat_name: StringName = &"",
	p_op: int = Op.FLAT,
	p_value: float = 0.0,
	p_source_tag: String = "generic",
	p_duration: float = -1.0
) -> void:
	id = p_id
	stat_name = p_stat_name
	op = p_op
	value = p_value
	source_tag = p_source_tag
	duration = p_duration
	remaining_time = p_duration


func is_temporary() -> bool:
	return duration > 0.0


func duplicate_modifier() -> StatModifier:
	var copy := StatModifier.new(id, stat_name, op, value, source_tag, duration)
	copy.remaining_time = remaining_time
	return copy
