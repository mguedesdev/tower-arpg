extends RefCounted
class_name CharacterStats
## Sistema centralizado de atributos do personagem.
## Política de cálculo:
## 1. Valor-base
## 2. Bônus planos (FLAT)
## 3. Bônus percentuais aditivos (PERCENT_ADD)
## 4. Multiplicadores específicos (MULTIPLY)
## 5. Limites (min/max) e arredondamento final para atributos inteiros.

signal stats_changed
signal health_changed(current_hp: int, max_hp: int)
signal mana_changed(current_mana: int, max_mana: int)

const STAT_MAX_HEALTH: StringName = &"max_health"
const STAT_MAX_MANA: StringName = &"max_mana"
const STAT_MANA_REGEN: StringName = &"mana_regen"
const STAT_DAMAGE: StringName = &"damage"
const STAT_ATTACK_SPEED: StringName = &"attack_speed"
const STAT_MOVE_SPEED: StringName = &"move_speed"
const STAT_CRIT_CHANCE: StringName = &"crit_chance"
const STAT_CRIT_DAMAGE: StringName = &"crit_damage"
const STAT_COOLDOWN_REDUCTION: StringName = &"cooldown_reduction"
const STAT_ARMOR: StringName = &"armor"
const STAT_AREA_SCALE: StringName = &"area_scale"
const STAT_STRENGTH: StringName = &"strength"
const STAT_AGILITY: StringName = &"agility"
const STAT_INTELLIGENCE: StringName = &"intelligence"

const STAT_LIMITS: Dictionary = {
	&"max_health": {"min": 1.0, "max": 99999.0, "is_int": true},
	&"max_mana": {"min": 10.0, "max": 99999.0, "is_int": true},
	&"mana_regen": {"min": 0.0, "max": 200.0, "is_int": false},
	&"damage": {"min": 1.0, "max": 99999.0, "is_int": true},
	&"attack_speed": {"min": 0.2, "max": 5.0, "is_int": false},
	&"move_speed": {"min": 1.0, "max": 18.0, "is_int": false},
	&"crit_chance": {"min": 0.0, "max": 1.0, "is_int": false},
	&"crit_damage": {"min": 1.0, "max": 10.0, "is_int": false},
	&"cooldown_reduction": {"min": 0.0, "max": 0.75, "is_int": false},
	&"armor": {"min": -50.0, "max": 200.0, "is_int": false},
	&"area_scale": {"min": 0.3, "max": 4.0, "is_int": false},
	&"strength": {"min": 0.0, "max": 9999.0, "is_int": true},
	&"agility": {"min": 0.0, "max": 9999.0, "is_int": true},
	&"intelligence": {"min": 0.0, "max": 9999.0, "is_int": true},
}

var _base_values: Dictionary = {
	STAT_MAX_HEALTH: 100.0,
	STAT_MAX_MANA: 60.0,
	STAT_MANA_REGEN: 6.0,
	STAT_DAMAGE: 14.0,
	STAT_ATTACK_SPEED: 1.0,
	STAT_MOVE_SPEED: 5.5,
	STAT_CRIT_CHANCE: 0.05,
	STAT_CRIT_DAMAGE: 1.5,
	STAT_COOLDOWN_REDUCTION: 0.0,
	STAT_ARMOR: 0.0,
	STAT_AREA_SCALE: 1.0,
	STAT_STRENGTH: 20.0,
	STAT_AGILITY: 14.0,
	STAT_INTELLIGENCE: 10.0,
}

var _cached_values: Dictionary = {}
var _modifiers: Array[StatModifier] = []
var current_health: int = 100
var current_mana: int = 60
var _mana_accum: float = 0.0


func _init(initial_bases: Dictionary = {}) -> void:
	for key in initial_bases.keys():
		_base_values[StringName(key)] = float(initial_bases[key])
	_recalculate_all(false)
	current_health = get_max_health()
	current_mana = get_max_mana()


func configure_from_definition(definition: Resource) -> void:
	if definition == null:
		return
	_base_values[STAT_MAX_HEALTH] = float(definition.get("base_max_health") if definition.get("base_max_health") != null else 100)
	_base_values[STAT_MAX_MANA] = float(definition.get("base_max_mana") if definition.get("base_max_mana") != null else 60)
	_base_values[STAT_MANA_REGEN] = float(definition.get("base_mana_regen") if definition.get("base_mana_regen") != null else 6.0)
	_base_values[STAT_DAMAGE] = float(definition.get("base_damage") if definition.get("base_damage") != null else 14)
	_base_values[STAT_ATTACK_SPEED] = float(definition.get("base_attack_speed") if definition.get("base_attack_speed") != null else 1.0)
	_base_values[STAT_MOVE_SPEED] = float(definition.get("base_move_speed") if definition.get("base_move_speed") != null else 5.5)
	_base_values[STAT_CRIT_CHANCE] = float(definition.get("base_crit_chance") if definition.get("base_crit_chance") != null else 0.05)
	_base_values[STAT_CRIT_DAMAGE] = float(definition.get("base_crit_damage") if definition.get("base_crit_damage") != null else 1.5)
	_base_values[STAT_COOLDOWN_REDUCTION] = float(definition.get("base_cooldown_reduction") if definition.get("base_cooldown_reduction") != null else 0.0)
	_base_values[STAT_ARMOR] = float(definition.get("base_armor") if definition.get("base_armor") != null else 0.0)
	_base_values[STAT_AREA_SCALE] = float(definition.get("base_area_scale") if definition.get("base_area_scale") != null else 1.0)
	_modifiers.clear()
	_recalculate_all(false)
	current_health = get_max_health()
	current_mana = get_max_mana()
	stats_changed.emit()
	health_changed.emit(current_health, get_max_health())
	mana_changed.emit(current_mana, get_max_mana())


func set_base_stat(stat_name: StringName, value: float) -> void:
	var old_max_hp: int = get_max_health()
	_base_values[stat_name] = value
	_recalculate_all(true, old_max_hp)


func get_base_stat(stat_name: StringName) -> float:
	return float(_base_values.get(stat_name, 0.0))


func get_stat(stat_name: StringName) -> float:
	if not _cached_values.has(stat_name):
		_cached_values[stat_name] = _compute_stat(stat_name)
	return float(_cached_values[stat_name])


func get_max_health() -> int:
	return int(roundi(get_stat(STAT_MAX_HEALTH)))


func get_max_mana() -> int:
	return int(roundi(get_stat(STAT_MAX_MANA)))


func get_mana_regen() -> float:
	return get_stat(STAT_MANA_REGEN)


func get_damage() -> int:
	return int(roundi(get_stat(STAT_DAMAGE)))


func get_attack_speed() -> float:
	return get_stat(STAT_ATTACK_SPEED)


func get_move_speed() -> float:
	return get_stat(STAT_MOVE_SPEED)


func get_crit_chance() -> float:
	return get_stat(STAT_CRIT_CHANCE)


func get_crit_damage() -> float:
	return get_stat(STAT_CRIT_DAMAGE)


func get_cooldown_reduction() -> float:
	return get_stat(STAT_COOLDOWN_REDUCTION)


func get_armor() -> float:
	return get_stat(STAT_ARMOR)


func get_area_scale() -> float:
	return get_stat(STAT_AREA_SCALE)


func add_modifier(modifier: StatModifier) -> void:
	if modifier == null or modifier.stat_name == &"":
		return
	var old_max_hp: int = get_max_health()
	# Se já existir um modificador com o mesmo ID não-vazio, substitui para evitar duplicação acidental.
	if not modifier.id.is_empty():
		for i in range(_modifiers.size() - 1, -1, -1):
			if _modifiers[i].id == modifier.id:
				_modifiers.remove_at(i)
	_modifiers.append(modifier.duplicate_modifier())
	_recalculate_all(true, old_max_hp)


func remove_modifier_by_id(modifier_id: String) -> bool:
	if modifier_id.is_empty():
		return false
	var old_max_hp: int = get_max_health()
	var removed: bool = false
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i].id == modifier_id:
			_modifiers.remove_at(i)
			removed = true
	if removed:
		_recalculate_all(true, old_max_hp)
	return removed


func remove_modifiers_by_source(source_tag: String) -> int:
	if source_tag.is_empty():
		return 0
	var old_max_hp: int = get_max_health()
	var count: int = 0
	for i in range(_modifiers.size() - 1, -1, -1):
		if _modifiers[i].source_tag == source_tag:
			_modifiers.remove_at(i)
			count += 1
	if count > 0:
		_recalculate_all(true, old_max_hp)
	return count


func clear_all_modifiers() -> void:
	if _modifiers.is_empty():
		return
	var old_max_hp: int = get_max_health()
	_modifiers.clear()
	_recalculate_all(true, old_max_hp)


func get_modifiers() -> Array[StatModifier]:
	var result: Array[StatModifier] = []
	for mod in _modifiers:
		result.append(mod.duplicate_modifier())
	return result


func tick_temporary_modifiers(delta: float) -> void:
	if delta <= 0.0 or _modifiers.is_empty():
		return
	var old_max_hp: int = get_max_health()
	var expired_any: bool = false
	for i in range(_modifiers.size() - 1, -1, -1):
		var mod: StatModifier = _modifiers[i]
		if mod.is_temporary():
			mod.remaining_time -= delta
			if mod.remaining_time <= 0.0:
				_modifiers.remove_at(i)
				expired_any = true
	if expired_any:
		_recalculate_all(true, old_max_hp)


func set_current_health(new_hp: int) -> void:
	var max_hp: int = get_max_health()
	var clamped: int = clampi(new_hp, 0, max_hp)
	if clamped != current_health:
		current_health = clamped
		health_changed.emit(current_health, max_hp)


func apply_damage(raw_damage: int) -> int:
	if raw_damage <= 0 or current_health <= 0:
		return 0
	# Redução simples por armadura: cada ponto de armadura reduz dano plano em até 60% do golpe.
	var armor_value: float = get_armor()
	var mitigated: int = maxi(1, roundi(float(raw_damage) - armor_value * 0.25))
	if armor_value > 0.0:
		mitigated = maxi(int(ceil(float(raw_damage) * 0.25)), mitigated)
	current_health = maxi(0, current_health - mitigated)
	health_changed.emit(current_health, get_max_health())
	return mitigated


func heal(amount: int) -> int:
	if amount <= 0 or current_health <= 0:
		return 0
	var before: int = current_health
	current_health = mini(get_max_health(), current_health + amount)
	var healed: int = current_health - before
	if healed > 0:
		health_changed.emit(current_health, get_max_health())
	return healed


func apply_mana_cost(amount: int) -> bool:
	if amount <= 0:
		return true
	if current_mana < amount:
		return false
	current_mana = maxi(0, current_mana - amount)
	mana_changed.emit(current_mana, get_max_mana())
	return true


func restore_mana(amount: int) -> void:
	if amount <= 0:
		return
	current_mana = mini(get_max_mana(), current_mana + amount)
	mana_changed.emit(current_mana, get_max_mana())


func regenerate_mana(delta: float) -> void:
	var max_m: int = get_max_mana()
	if current_mana >= max_m:
		return
	var regen_rate: float = get_mana_regen()
	if regen_rate <= 0.0:
		return
	_mana_accum += regen_rate * delta
	if _mana_accum >= 1.0:
		var gain: int = int(_mana_accum)
		_mana_accum -= float(gain)
		current_mana = mini(max_m, current_mana + gain)
		mana_changed.emit(current_mana, max_m)


func _recalculate_all(emit_signals: bool, previous_max_hp: int = -1) -> void:
	var old_max: int = previous_max_hp if previous_max_hp > 0 else int(_cached_values.get(STAT_MAX_HEALTH, _base_values[STAT_MAX_HEALTH]))
	_cached_values.clear()
	for stat_key in _base_values.keys():
		_cached_values[stat_key] = _compute_stat(stat_key)
	var new_max: int = get_max_health()
	if new_max != old_max:
		_adjust_current_health_for_max_change(old_max, new_max)
	var new_max_m: int = get_max_mana()
	if current_mana > new_max_m:
		current_mana = new_max_m
	if emit_signals:
		stats_changed.emit()
		health_changed.emit(current_health, new_max)
		mana_changed.emit(current_mana, new_max_m)


func _adjust_current_health_for_max_change(old_max: int, new_max: int) -> void:
	if current_health <= 0:
		return
	if new_max > old_max:
		# Política do protótipo (Seção 7): preserva a quantidade de vida faltante quando o máximo aumenta.
		var missing_hp: int = maxi(0, old_max - current_health)
		current_health = clampi(new_max - missing_hp, 1, new_max)
	elif new_max < old_max:
		# Mudanças negativas respeitam os limites válidos de vida (nunca mata o jogador vivo nem excede new_max).
		current_health = clampi(current_health, 1, new_max)


func _compute_stat(stat_name: StringName) -> float:
	var base_val: float = float(_base_values.get(stat_name, 0.0))
	var flat_bonus: float = 0.0
	var percent_add: float = 0.0
	var mult_factor: float = 1.0

	for mod in _modifiers:
		if mod.stat_name != stat_name:
			continue
		match mod.op:
			StatModifier.Op.FLAT:
				flat_bonus += mod.value
			StatModifier.Op.PERCENT_ADD:
				percent_add += mod.value
			StatModifier.Op.MULTIPLY:
				mult_factor *= maxf(0.0, mod.value)

	var raw_value: float = (base_val + flat_bonus) * maxf(0.0, 1.0 + percent_add) * mult_factor
	if STAT_LIMITS.has(stat_name):
		var policy: Dictionary = STAT_LIMITS[stat_name]
		var clamped: float = clampf(raw_value, float(policy["min"]), float(policy["max"]))
		if bool(policy["is_int"]):
			return float(maxi(int(policy["min"]), roundi(clamped)))
		return clamped
	return raw_value
