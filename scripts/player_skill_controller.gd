extends Node
class_name PlayerSkillController
## Controlador de Combate Ativo ARPG (modo Campanha) — estilo Diablo 2 + Path of Exile 2.
##
## • Sem ataque automático: todo golpe sai por decisão do jogador.
## • 6 slots: [LMB] [RMB] [1] [2] [3] [4]. LMB já vem com o Ataque Básico (Estocada).
## • Máximo de 4 skills ativas + o ataque básico; o jogador escolhe o que fica em cada slot.
## • Clicou num mob longe → anda até ele e golpeia ao alcançar. Segurar o botão = continua atacando.
## • Clicou no chão vazio → golpeia no lugar, na direção do cursor.
## • WASD sempre tem prioridade e cancela a perseguição.

signal slots_changed
signal skill_cast(skill_id: String)
signal insufficient_mana(slot_index: int, cost: int)

const VFX = preload("res://scripts/vfx/tower_vfx_spawner.gd")
const SkillDefScript = preload("res://core/combat/skill_definition.gd")

const SLOT_LMB: int = 0
const SLOT_RMB: int = 1
const SLOT_1: int = 2
const SLOT_2: int = 3
const SLOT_3: int = 4
const SLOT_4: int = 5
const SLOT_COUNT: int = 6
const SLOT_LABELS: Array[String] = ["LMB", "RMB", "Q", "E", "R", "F"]
const MAX_ACTIVE_SKILLS: int = 4
const PICK_RADIUS_PX: float = 34.0

@export var enabled: bool = false

var character: TowerPlayer
var skills: Dictionary = {}                 ## skill_id -> SkillDefinition
var slots: Array[String] = ["", "", "", "", "", ""]
var _cooldowns: Dictionary = {}             ## skill_id -> segundos restantes
var _held: Array[bool] = [false, false, false, false, false, false]

# Ação pendente (perseguição ou golpe em andamento)
var _pending_slot: int = -1
var _pending_target: TowerEnemy = null
var _pending_ground_point: Vector3 = Vector3.ZERO
var _has_ground_point: bool = false


func _ready() -> void:
	character = get_parent() as TowerPlayer
	if skills.is_empty():
		load_class_skills(SkillDefScript.build_warrior_skills())


func load_class_skills(new_skills: Dictionary) -> void:
	skills = new_skills
	_cooldowns.clear()
	for sid in skills.keys():
		_cooldowns[sid] = 0.0
	reset_default_slots()


func reset_default_slots() -> void:
	# Ataque básico no Botão Esquerdo; as 4 skills nos números; RMB com o Corte em Meia-Lua.
	slots = ["basic_stab", "cleave_arc", "cleave_arc", "whirlwind_spin", "impale_pierce", "ember_strike"]
	for i in range(SLOT_COUNT):
		if not skills.has(slots[i]):
			slots[i] = ""
	slots_changed.emit()


func set_enabled(value: bool) -> void:
	enabled = value
	_cancel_pending()
	for i in range(SLOT_COUNT):
		_held[i] = false


## Lista das skills que podem ir para um slot (o básico + as skills ativas).
func get_assignable_skill_ids() -> Array[String]:
	var ids: Array[String] = []
	for sid in skills.keys():
		ids.append(String(sid))
	ids.sort_custom(func(a: String, b: String) -> bool:
		var da: SkillDefinition = skills[a]
		var db: SkillDefinition = skills[b]
		if da.is_basic_attack != db.is_basic_attack:
			return da.is_basic_attack
		return a < b
	)
	return ids


## Quantas skills NÃO-básicas diferentes estão equipadas (limite: 4).
func count_distinct_active_skills(ignore_slot: int = -1) -> int:
	var seen: Dictionary = {}
	for i in range(SLOT_COUNT):
		if i == ignore_slot:
			continue
		var sid: String = slots[i]
		if sid.is_empty() or not skills.has(sid):
			continue
		if (skills[sid] as SkillDefinition).is_basic_attack:
			continue
		seen[sid] = true
	return seen.size()


func can_assign(slot_index: int, skill_id: String) -> bool:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return false
	if skill_id.is_empty():
		return true
	if not skills.has(skill_id):
		return false
	var def: SkillDefinition = skills[skill_id]
	if def.is_basic_attack:
		return true
	# Já equipada em outro slot? Não aumenta a contagem.
	for i in range(SLOT_COUNT):
		if i != slot_index and slots[i] == skill_id:
			return true
	return count_distinct_active_skills(slot_index) < MAX_ACTIVE_SKILLS


func assign_slot(slot_index: int, skill_id: String) -> bool:
	if not can_assign(slot_index, skill_id):
		return false
	slots[slot_index] = skill_id
	slots_changed.emit()
	return true


func assign_skill_to_slot(slot_index: int, skill_id: String) -> bool:
	return assign_slot(slot_index, skill_id)


func get_slot_skill(slot_index: int) -> SkillDefinition:
	if slot_index < 0 or slot_index >= SLOT_COUNT:
		return null
	var sid: String = slots[slot_index]
	return skills.get(sid, null) as SkillDefinition


func get_cooldown_ratio(skill_id: String) -> float:
	if skill_id.is_empty() or not skills.has(skill_id):
		return 0.0
	var remaining: float = float(_cooldowns.get(skill_id, 0.0))
	if remaining <= 0.0:
		return 0.0
	var total: float = (skills[skill_id] as SkillDefinition).get_cooldown(_stats())
	return clampf(remaining / maxf(total, 0.01), 0.0, 1.0)


func get_cooldown_remaining(skill_id: String) -> float:
	return float(_cooldowns.get(skill_id, 0.0))


# ---------------------------------------------------------------
# ENTRADA
# ---------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not enabled or character == null or not character.alive or character.in_lobby_mode:
		return
	if _is_ui_blocking():
		return
	var slot_idx: int = -1
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if InputMap.has_action("hud_skill_1") and event.is_action("hud_skill_1"):
			slot_idx = SLOT_LMB
		elif InputMap.has_action("hud_skill_2") and event.is_action("hud_skill_2"):
			slot_idx = SLOT_RMB
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and TownInteractable3D.is_any_station_hovered():
				var st: TownInteractable3D = TownInteractable3D.get_hovered_station()
				if st != null:
					st._handle_interaction_click()
					get_viewport().set_input_as_handled()
					return
			if mb.pressed and ZonePortal3D.get_hovered_portal() != null:
				var pt: ZonePortal3D = ZonePortal3D.get_hovered_portal()
				if pt != null:
					pt._handle_transition_click()
					get_viewport().set_input_as_handled()
					return
			slot_idx = SLOT_LMB
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			slot_idx = SLOT_RMB
		if slot_idx >= 0:
			_held[slot_idx] = mb.pressed
			if mb.pressed:
				_begin_action(slot_idx)
				get_viewport().set_input_as_handled()
	elif event is InputEventKey:
		var key := event as InputEventKey
		if key.echo:
			return
		var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		if InputMap.has_action("hud_skill_3") and event.is_action("hud_skill_3"):
			slot_idx = SLOT_1
		elif InputMap.has_action("hud_skill_4") and event.is_action("hud_skill_4"):
			slot_idx = SLOT_2
		elif InputMap.has_action("hud_skill_5") and event.is_action("hud_skill_5"):
			slot_idx = SLOT_3
		elif InputMap.has_action("hud_skill_6") and event.is_action("hud_skill_6"):
			slot_idx = SLOT_4
		elif code == KEY_Q:
			slot_idx = SLOT_1
		elif code == KEY_E:
			slot_idx = SLOT_2
		elif code == KEY_R:
			slot_idx = SLOT_3
		elif code == KEY_F:
			slot_idx = SLOT_4
		if slot_idx >= 0:
			_held[slot_idx] = key.pressed
			if key.pressed:
				_begin_action(slot_idx)
				get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	# Soltar o botão do mouse ou tecla de skill sempre limpa o "segurar"
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		var mb := event as InputEventMouseButton
		if (InputMap.has_action("hud_skill_1") and event.is_action("hud_skill_1")) or mb.button_index == MOUSE_BUTTON_LEFT:
			_held[SLOT_LMB] = false
			if _pending_slot == SLOT_LMB:
				_cancel_pending()
		elif (InputMap.has_action("hud_skill_2") and event.is_action("hud_skill_2")) or mb.button_index == MOUSE_BUTTON_RIGHT:
			_held[SLOT_RMB] = false
			if _pending_slot == SLOT_RMB:
				_cancel_pending()
	elif event is InputEventKey and not (event as InputEventKey).pressed:
		var k := event as InputEventKey
		var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
		var rel_slot: int = -1
		if InputMap.has_action("hud_skill_3") and event.is_action("hud_skill_3"):
			rel_slot = SLOT_1
		elif InputMap.has_action("hud_skill_4") and event.is_action("hud_skill_4"):
			rel_slot = SLOT_2
		elif InputMap.has_action("hud_skill_5") and event.is_action("hud_skill_5"):
			rel_slot = SLOT_3
		elif InputMap.has_action("hud_skill_6") and event.is_action("hud_skill_6"):
			rel_slot = SLOT_4
		elif code == KEY_Q:
			rel_slot = SLOT_1
		elif code == KEY_E:
			rel_slot = SLOT_2
		elif code == KEY_R:
			rel_slot = SLOT_3
		elif code == KEY_F:
			rel_slot = SLOT_4
		if rel_slot >= 0:
			_held[rel_slot] = false
			if _pending_slot == rel_slot:
				_cancel_pending()


func _begin_action(slot_idx: int) -> void:
	var def: SkillDefinition = get_slot_skill(slot_idx)
	if def == null:
		return
	if def.mana_cost > 0 and character != null and character.mana < def.mana_cost:
		insufficient_mana.emit(slot_idx, def.mana_cost)
		return
	_pending_slot = slot_idx
	_pending_target = pick_enemy_under_cursor()
	_has_ground_point = false
	if _pending_target == null:
		var gp: Variant = get_cursor_ground_point()
		if gp is Vector3:
			_pending_ground_point = gp
			_has_ground_point = true


func _cancel_pending() -> void:
	_pending_slot = -1
	_pending_target = null
	_has_ground_point = false
	if character != null:
		character.chase_direction = Vector3.ZERO


# ---------------------------------------------------------------
# LOOP
# ---------------------------------------------------------------
func _physics_process(delta: float) -> void:
	for sid in _cooldowns.keys():
		var v: float = float(_cooldowns[sid])
		if v > 0.0:
			_cooldowns[sid] = maxf(v - delta, 0.0)

	if not enabled or character == null or not character.alive or character.in_lobby_mode:
		if character != null:
			character.chase_direction = Vector3.ZERO
		return

	# WASD assume o controle e cancela a perseguição automática.
	if character.has_manual_move_input():
		character.chase_direction = Vector3.ZERO
		_pending_target = null

	# Segurar o botão: re-dispara a ação continuamente (mantém o alvo se ainda vivo).
	if _pending_slot < 0:
		for i in range(SLOT_COUNT):
			if _held[i]:
				_begin_action(i)
				break

	if _pending_slot < 0:
		character.chase_direction = Vector3.ZERO
		return

	var def: SkillDefinition = get_slot_skill(_pending_slot)
	if def == null:
		_cancel_pending()
		return

	if _pending_target != null:
		if not _is_valid_enemy(_pending_target):
			var keep_slot: int = _pending_slot
			_cancel_pending()
			if keep_slot >= 0 and _held[keep_slot]:
				_begin_action(keep_slot)
			return
		var to_target: Vector3 = _pending_target.global_position - character.global_position
		to_target.y = 0.0
		if to_target.length() > def.get_attack_reach():
			# Anda até o mob clicado.
			character.chase_direction = to_target.normalized()
			return
		# Já está em alcance: se estiver em recarga ou no meio do golpe, não ataca ainda mas não trava
		if character.cast_lock_remaining > 0.0 or get_cooldown_remaining(def.skill_id) > 0.0:
			if not _held[_pending_slot]:
				_cancel_pending()
			return
		character.chase_direction = Vector3.ZERO
		_cast(def, to_target)
		_after_cast()
		return

	# Se for o botão primário (LMB) e clicou no chão: move o personagem (Click-to-Move estilo Albion/Diablo)
	if _pending_slot == SLOT_LMB and _pending_target == null and not character.has_manual_move_input():
		var dest: Variant = null
		if _held[SLOT_LMB]:
			dest = get_cursor_ground_point()
		if not (dest is Vector3) and _has_ground_point:
			dest = _pending_ground_point
		if dest is Vector3:
			var to_dest: Vector3 = (dest as Vector3) - character.global_position
			to_dest.y = 0.0
			if to_dest.length() > 0.35:
				character.chase_direction = to_dest.normalized()
			else:
				character.chase_direction = Vector3.ZERO
				_cancel_pending()
		else:
			character.chase_direction = Vector3.ZERO
			_cancel_pending()
		return

	# Sem alvo em slots de skill (RMB, 1, 2, 3, 4): golpeia na direção do cursor.
	character.chase_direction = Vector3.ZERO
	var cd_left: float = get_cooldown_remaining(def.skill_id)
	if character.cast_lock_remaining > 0.0 or cd_left > 0.0:
		# Buffer curto: só guarda o clique se a recarga estiver quase pronta.
		if not _held[_pending_slot] and cd_left > 0.25:
			_cancel_pending()
		return
	var aim_dir: Vector3 = Vector3.ZERO
	var live_point: Variant = get_cursor_ground_point()
	if live_point is Vector3:
		aim_dir = (live_point as Vector3) - character.global_position
	elif _has_ground_point:
		aim_dir = _pending_ground_point - character.global_position
	aim_dir.y = 0.0
	if aim_dir.length_squared() < 0.01 and character.visual != null:
		aim_dir = character.visual.global_basis.z
	_cast(def, aim_dir)
	_after_cast()


func _after_cast() -> void:
	var slot_used: int = _pending_slot
	var target_kept: TowerEnemy = _pending_target
	_pending_slot = -1
	_pending_target = null
	_has_ground_point = false
	# Se o jogador continua segurando, mantém o mesmo alvo para o próximo golpe.
	if slot_used >= 0 and _held[slot_used] and _is_valid_enemy(target_kept):
		_pending_slot = slot_used
		_pending_target = target_kept


# ---------------------------------------------------------------
# EXECUÇÃO DA SKILL
# ---------------------------------------------------------------
func cast_skill_now(skill_id: String, aim_direction: Vector3) -> int:
	## Uso direto (testes / IA): ignora recarga e executa a skill.
	if not skills.has(skill_id):
		return 0
	return _cast(skills[skill_id] as SkillDefinition, aim_direction)


func _cast(def: SkillDefinition, aim_direction: Vector3) -> int:
	if def.mana_cost > 0 and character != null:
		if not character.spend_mana(def.mana_cost):
			return 0

	var forward: Vector3 = Vector3(aim_direction.x, 0.0, aim_direction.z)
	if forward.length_squared() < 0.0001:
		forward = character.visual.global_basis.z if character.visual != null else Vector3.BACK
		forward.y = 0.0
	forward = forward.normalized()

	character.face_towards(forward, def.cast_lock + 0.08)
	character.cast_lock_remaining = def.cast_lock
	character.chase_direction = Vector3.ZERO
	character.play_attack_animation(def.animation_form)
	_cooldowns[def.skill_id] = def.get_cooldown(_stats())

	var vfx_root: Node3D = get_tree().current_scene as Node3D if is_inside_tree() else null
	var origin: Vector3 = character.global_position + Vector3.UP * 0.8
	if vfx_root != null:
		match def.vfx_kind:
			"arc":
				VFX.arc(vfx_root, origin, forward, 1.05)
			"spin":
				VFX.spin(vfx_root, origin, 1.1)
			"pierce":
				VFX.stab(vfx_root, origin, forward, 1.7)
			"ember":
				VFX.stab(vfx_root, origin, forward, 1.1)
				VFX.fire_burst(vfx_root, origin + forward * 1.6, 0.9)
			_:
				VFX.stab(vfx_root, origin, forward, 1.0)

	var hits: Array[TowerEnemy] = []
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not _is_valid_enemy(candidate):
			continue
		var enemy: TowerEnemy = candidate as TowerEnemy
		var offset: Vector3 = enemy.global_position - character.global_position
		if is_offset_inside_skill(def, offset, forward):
			hits.append(enemy)
	var origin_pos: Vector3 = character.global_position
	hits.sort_custom(func(a: TowerEnemy, b: TowerEnemy) -> bool:
		return origin_pos.distance_squared_to(a.global_position) < origin_pos.distance_squared_to(b.global_position)
	)

	var dmg: int = compute_skill_damage(def)
	var count: int = 0
	for enemy in hits:
		if count >= def.max_targets:
			break
		if not _is_valid_enemy(enemy):
			continue
		var hit_point: Vector3 = enemy.global_position + Vector3.UP * 0.7
		enemy.take_damage(dmg)
		if def.burn_dps > 0.0 and _is_valid_enemy(enemy):
			enemy.apply_burn(def.burn_dps, def.burn_duration)
		count += 1
		if vfx_root != null and count <= 3:
			VFX.impact(vfx_root, hit_point, 0.6)
			if def.burn_dps > 0.0:
				VFX.fire_burst(vfx_root, hit_point, 0.6)
	skill_cast.emit(def.skill_id)
	return count


func compute_skill_damage(def: SkillDefinition) -> int:
	var stats: CharacterStats = _stats()
	var base_dmg: float = float(stats.get_damage()) if stats != null else 14.0
	var dmg: float = base_dmg * def.damage_multiplier
	if stats != null and randf() < stats.get_crit_chance():
		dmg *= maxf(1.0, stats.get_crit_damage())
	return maxi(1, roundi(dmg))


static func is_offset_inside_skill(def: SkillDefinition, offset: Vector3, forward: Vector3) -> bool:
	var flat: Vector3 = Vector3(offset.x, 0.0, offset.z)
	var dist: float = flat.length()
	if dist > def.hit_range + 0.35:
		return false
	match def.shape:
		SkillDefinition.Shape.CIRCLE:
			return true
		SkillDefinition.Shape.LINE:
			var proj: float = forward.dot(flat)
			if proj < -0.25 or proj > def.hit_range + 0.35:
				return false
			var right: Vector3 = Vector3(forward.z, 0.0, -forward.x)
			return absf(right.dot(flat)) <= def.line_width * 0.6
		_:
			if dist < 0.6:
				return true
			return forward.dot(flat / dist) >= cos(deg_to_rad(def.half_angle_deg))


# ---------------------------------------------------------------
# MIRA COM O MOUSE
# ---------------------------------------------------------------
func get_cursor_ground_point() -> Variant:
	if not is_inside_tree():
		return null
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var ray_origin: Vector3 = cam.project_ray_origin(mouse)
	var ray_dir: Vector3 = cam.project_ray_normal(mouse)
	var plane_y: float = character.global_position.y if character != null else 0.0
	var plane := Plane(Vector3.UP, plane_y)
	return plane.intersects_ray(ray_origin, ray_dir)


func pick_enemy_under_cursor() -> TowerEnemy:
	## Seleção em espaço de tela (generosa e confortável mesmo com mobs em movimento).
	if not is_inside_tree():
		return null
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var best: TowerEnemy = null
	var best_d: float = PICK_RADIUS_PX
	for candidate in get_tree().get_nodes_in_group("enemies"):
		if not _is_valid_enemy(candidate):
			continue
		var enemy: TowerEnemy = candidate as TowerEnemy
		var probe_height: float = 1.15 if enemy.is_mini_boss else 0.75
		var probe: Vector3 = enemy.global_position + Vector3.UP * probe_height
		if cam.is_position_behind(probe):
			continue
		var screen: Vector2 = cam.unproject_position(probe)
		var radius_px: float = PICK_RADIUS_PX * (1.35 if enemy.is_mini_boss else 1.0)
		var d: float = screen.distance_to(mouse)
		if d < radius_px and d < best_d * (1.35 if enemy.is_mini_boss else 1.0):
			best_d = d
			best = enemy
	return best


func _is_ui_blocking() -> bool:
	if not is_inside_tree():
		return false
	for node in get_tree().get_nodes_in_group("blocking_modal"):
		if node is CanvasItem and (node as CanvasItem).is_visible_in_tree():
			return true
	return false


func _is_valid_enemy(enemy: Variant) -> bool:
	if not is_instance_valid(enemy) or not (enemy is TowerEnemy):
		return false
	var e: TowerEnemy = enemy as TowerEnemy
	return e.alive and not e.is_queued_for_deletion()


func _stats() -> CharacterStats:
	return character.stats if character != null else null
