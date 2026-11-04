extends Node3D
class_name TowerGameController
## Controlador Central Exclusivo do Modo INFINITY TOWER (A Torre do Santuário / Sobrevivência por Ondas).
## Totalmente desacoplado do ARPG: com auto-ataque, lobby da torre, escolhas por cartas e árvore de essência.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const WOLF_SCENE: PackedScene = preload("res://scenes/enemies/wolf.tscn")
const WOLF_MODEL_PATH: String = "res://assets/models/wolf.glb"
const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/executioner_boss.tscn")
const BOSS_MODEL_PATH: String = "res://assets/models/skeleton_boss.glb"

const RUN_PROGRESSION_SCRIPT: Script = preload("res://core/progression/run_progression_service.gd")
const PERMANENT_PROGRESSION_SCRIPT: Script = preload("res://game/progression/permanent_progression_service.gd")
const RUN_XP_HUD_SCRIPT: Script = preload("res://game/ui/progression/run_xp_hud.gd")
const LEVEL_UP_MODAL_SCRIPT: Script = preload("res://game/ui/progression/level_up_modal.gd")
const RUN_RESULT_MODAL_SCRIPT: Script = preload("res://game/ui/progression/run_result_modal.gd")
const TALENT_TREE_MODAL_SCRIPT: Script = preload("res://game/ui/progression/talent_tree_modal.gd")
const SANCTUARY_LOBBY_SCRIPT: Script = preload("res://game/ui/progression/sanctuary_lobby_hud.gd")
const VFX_EFFECT_SCRIPT: Script = preload("res://scripts/vfx/tower_vfx_effect.gd")
const VFX_SPAWNER = preload("res://scripts/vfx/tower_vfx_spawner.gd")
const SkinnedCache = preload("res://core/utilities/skinned_model_cache.gd")

@onready var player: TowerPlayer = $Player
@onready var attack: TowerAttackController = $Player/AttackController
@onready var camera: Camera3D = $Camera
@onready var enemies_root: Node3D = $Enemies
@onready var wave_label: Label = $HUD/Info/WaveLabel
@onready var health_label: Label = $HUD/Info/HealthLabel
@onready var form_label: Label = $HUD/Info/FormLabel
@onready var kills_label: Label = $HUD/Info/KillsLabel
@onready var status_label: Label = $HUD/StatusLabel
@onready var arena_art: Node3D = $ArenaArt
@onready var title_text_label: Label = $HUD/TitlePlate/TitleText
@onready var subtitle_text_label: Label = $HUD/TitlePlate/Subtitle

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var current_wave: int = 0
var waves_completed: int = 0
var enemies_left: int = 0
var kills: int = 0
var game_over: bool = false
var in_lobby: bool = true

var run_progression: RunProgressionService
var permanent_progression: PermanentProgressionService
var reward_calculator: RunRewardCalculator = RunRewardCalculator.new()
var current_run_summary: RunSummaryState

var xp_hud: RunXpHUD
var level_up_modal: LevelUpModal
var run_result_modal: RunResultModal
var talent_tree_modal: TalentTreeModal
var lobby_hud: SanctuaryLobbyHUD

var _initial_player_position: Vector3 = Vector3.ZERO
var _pending_wave_spawns: Array[Dictionary] = []
var _wolf_model_available: bool = false
var _boss_model_available: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_initial_player_position = player.global_position
	rng.randomize()
	_wolf_model_available = ResourceLoader.exists(WOLF_MODEL_PATH)
	_boss_model_available = ResourceLoader.exists(BOSS_MODEL_PATH)
	VFX_EFFECT_SCRIPT.warm_up_caches()
	_warm_up_models()

	permanent_progression = PERMANENT_PROGRESSION_SCRIPT.new() as PermanentProgressionService
	add_child(permanent_progression)
	permanent_progression.load_from_disk()

	run_progression = RUN_PROGRESSION_SCRIPT.new() as RunProgressionService
	add_child(run_progression)

	xp_hud = RUN_XP_HUD_SCRIPT.new() as RunXpHUD
	$HUD.add_child(xp_hud)
	xp_hud.attach_progression(run_progression)

	level_up_modal = LEVEL_UP_MODAL_SCRIPT.new() as LevelUpModal
	$HUD.add_child(level_up_modal)
	level_up_modal.upgrade_chosen.connect(_on_upgrade_chosen)

	run_result_modal = RUN_RESULT_MODAL_SCRIPT.new() as RunResultModal
	$HUD.add_child(run_result_modal)
	run_result_modal.open_talent_tree_requested.connect(_on_open_talent_tree_from_results)
	run_result_modal.restart_run_requested.connect(_start_new_run)

	talent_tree_modal = TALENT_TREE_MODAL_SCRIPT.new() as TalentTreeModal
	$HUD.add_child(talent_tree_modal)
	talent_tree_modal.bind_service(permanent_progression)
	talent_tree_modal.start_new_run_requested.connect(_start_new_run)
	talent_tree_modal.return_to_lobby_requested.connect(_enter_sanctuary_lobby)

	lobby_hud = SANCTUARY_LOBBY_SCRIPT.new() as SanctuaryLobbyHUD
	$HUD.add_child(lobby_hud)
	lobby_hud.bind_context(permanent_progression, run_progression, player, attack)
	lobby_hud.start_battle_requested.connect(_start_new_run)
	lobby_hud.open_talent_tree_requested.connect(_on_open_talent_tree_from_lobby)
	lobby_hud.preview_attack_requested.connect(_on_lobby_preview_attack)
	lobby_hud.rotate_character_requested.connect(_on_lobby_rotate_character)

	# Adiciona botão de voltar ao Launcher no lobby
	var btn_launcher := Button.new()
	btn_launcher.text = "⬅ MENU PRINCIPAL (LAUNCHER)"
	btn_launcher.custom_minimum_size = Vector2(220, 36)
	btn_launcher.position = Vector2(26, 120)
	btn_launcher.pressed.connect(return_to_launcher)
	$HUD.add_child(btn_launcher)

	level_up_modal.add_to_group("blocking_modal")
	run_result_modal.add_to_group("blocking_modal")
	talent_tree_modal.add_to_group("blocking_modal")
	lobby_hud.add_to_group("blocking_modal")

	run_progression.choices_changed.connect(_on_choices_changed)

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	attack.form_changed.connect(_on_form_changed)

	_enter_sanctuary_lobby()


func _process(_delta: float) -> void:
	if game_over and Input.is_action_just_pressed("restart"):
		_start_new_run()
		return
	if not game_over and not _pending_wave_spawns.is_empty():
		var count_this_frame: int = mini(3, _pending_wave_spawns.size())
		for _i in range(count_this_frame):
			var spec: Dictionary = _pending_wave_spawns.pop_front()
			_spawn_single_enemy(spec)


func _unhandled_input(event: InputEvent) -> void:
	if in_lobby and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		return_to_launcher()


func return_to_launcher() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/launcher.tscn")


func _warm_up_models() -> void:
	if ResourceLoader.exists("res://assets/models/skeleton_enemy.glb"):
		var m = SkinnedCache.instantiate_optimized("res://assets/models/skeleton_enemy.glb")
		if m != null: m.free()
	if _wolf_model_available:
		var m = SkinnedCache.instantiate_optimized(WOLF_MODEL_PATH)
		if m != null: m.free()
	if _boss_model_available:
		var m = SkinnedCache.instantiate_optimized(BOSS_MODEL_PATH)
		if m != null: m.free()


func _enter_sanctuary_lobby() -> void:
	in_lobby = true
	game_over = false
	get_tree().paused = false
	if arena_art != null and arena_art.has_method("rebuild_tower_arena"):
		arena_art.call("rebuild_tower_arena")
	if title_text_label != null:
		title_text_label.text = "ALTAR PROFANADO"
	if subtitle_text_label != null:
		subtitle_text_label.text = "DARK FANTASY / SPAWN ALTAR"
	if level_up_modal != null:
		level_up_modal.hide_modal()
	if run_result_modal != null:
		run_result_modal.hide_modal()
	if talent_tree_modal != null:
		talent_tree_modal.hide_lobby()
	if xp_hud != null:
		xp_hud.visible = false
	if lobby_hud != null:
		lobby_hud.visible = true

	for child in enemies_root.get_children():
		child.queue_free()
	_pending_wave_spawns.clear()

	current_wave = 0
	waves_completed = 0
	enemies_left = 0
	kills = 0
	current_run_summary = null

	player.global_position = Vector3(0.0, 0.02, 0.0)
	player.set_lobby_mode(true)
	if camera != null and camera.has_method("set_lobby_mode"):
		camera.set_lobby_mode(true, true)

	player.configure_character(player.character_definition)
	attack.ability_state.setup_from_definition(attack.ability_state.definition)
	run_progression.reset_run()
	var cid: String = player.character_definition.class_id if player.character_definition != null else "warrior"
	permanent_progression.apply_to_run(cid, player.stats, null, attack.ability_state)
	run_progression.bind_runtime_targets(
		player.stats,
		attack.ability_state,
		cid,
		permanent_progression.get_meta_unlocks_for_class(cid)
	)
	attack.sync_from_ability_state()
	attack.auto_attack = false
	if player != null and player.skill_controller != null:
		player.skill_controller.set_enabled(false)
	if lobby_hud != null:
		lobby_hud.refresh_lobby()


func _on_open_talent_tree_from_lobby() -> void:
	if lobby_hud != null:
		lobby_hud.visible = false
	if talent_tree_modal != null:
		talent_tree_modal.open_lobby()


func _on_lobby_preview_attack(form_idx: int) -> void:
	if not in_lobby or player == null:
		return
	player.play_attack_animation(form_idx)
	var forward: Vector3 = player.visual.global_basis.z if player.visual != null else Vector3.BACK
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		forward = Vector3.BACK
	forward = forward.normalized()
	var origin: Vector3 = player.global_position + Vector3.UP * 0.8
	match form_idx:
		1: VFX_SPAWNER.arc(self, origin, forward, 1.0)
		2: VFX_SPAWNER.spin(self, origin, 1.0)
		3: VFX_SPAWNER.stab(self, origin, forward, 1.45)
		_: VFX_SPAWNER.stab(self, origin, forward, 1.0)


func _on_lobby_rotate_character(delta_deg: float) -> void:
	if player != null:
		player.lobby_yaw_degrees = wrapf(player.lobby_yaw_degrees + delta_deg, -180.0, 180.0)


func _start_new_run() -> void:
	in_lobby = false
	get_tree().paused = false
	if arena_art != null and arena_art.has_method("rebuild_tower_arena"):
		arena_art.call("rebuild_tower_arena")
	if title_text_label != null:
		title_text_label.text = "A TORRE — MODO WAVES"
	if subtitle_text_label != null:
		subtitle_text_label.text = "SOBREVIVÊNCIA POR ONDAS"
	if lobby_hud != null:
		lobby_hud.visible = false
	if xp_hud != null:
		xp_hud.visible = true
	if level_up_modal != null:
		level_up_modal.hide_modal()
	if run_result_modal != null:
		run_result_modal.hide_modal()
	if talent_tree_modal != null:
		talent_tree_modal.hide_lobby()

	for child in enemies_root.get_children():
		child.queue_free()
	_pending_wave_spawns.clear()

	current_wave = 0
	waves_completed = 0
	enemies_left = 0
	kills = 0
	game_over = false
	current_run_summary = null
	kills_label.text = "Abates: 0"

	if xp_hud != null:
		xp_hud.set("_dead", false)

	player.set_lobby_mode(false)
	player.global_position = _initial_player_position
	player.velocity = Vector3.ZERO
	if camera != null and camera.has_method("set_lobby_mode"):
		camera.set_lobby_mode(false, false)
	player.configure_character(player.character_definition)
	attack.ability_state.setup_from_definition(attack.ability_state.definition)

	run_progression.balance = preload("res://content/progression/balance_dev.tres")
	run_progression.reset_run()
	permanent_progression.apply_to_run(
		player.character_definition.class_id if player.character_definition != null else "warrior",
		player.stats,
		run_progression,
		attack.ability_state
	)
	attack.sync_from_ability_state()
	attack.auto_attack = true
	if player != null and player.skill_controller != null:
		player.skill_controller.set_enabled(false)

	_on_health_changed(player.health, player.max_health)
	_on_form_changed(attack.form_label())
	status_label.text = "WASD/setas: mover | Derrote inimigos para evoluir sua habilidade!"
	_start_wave()

	if run_progression.state.pending_upgrade_choices > 0:
		_present_next_level_up_choice()


func _start_wave() -> void:
	if game_over:
		return
	current_wave += 1
	enemies_left = mini(3 + current_wave * 2, 21)
	wave_label.text = "Wave: %d" % current_wave
	var spawn_count: int = enemies_left
	var wolf_count: int = 0
	if current_wave >= 2 and _wolf_model_available:
		var growth: int = 1 + int(float(current_wave - 2) / 3.0)
		wolf_count = mini(growth, maxi(1, int(float(spawn_count) / 4.0)))

	var boss_count: int = 0
	if current_wave >= 2 and _boss_model_available:
		boss_count = 2 if current_wave >= 6 else 1

	_pending_wave_spawns.clear()
	for index in range(spawn_count):
		var angle: float = TAU * float(index) / float(spawn_count) + rng.randf_range(-0.25, 0.25)
		var radius: float = rng.randf_range(8.0, 11.5)
		var is_boss_spawn: bool = index < boss_count
		var is_wolf_spawn: bool = (not is_boss_spawn) and (index < boss_count + wolf_count)
		var spec: Dictionary = {
			"is_boss": is_boss_spawn,
			"is_wolf": is_wolf_spawn,
			"angle": angle,
			"radius": radius,
			"wave": current_wave,
		}
		if index < 4:
			_spawn_single_enemy(spec)
		else:
			_pending_wave_spawns.append(spec)
	if boss_count > 0:
		status_label.text = "Wave %d — ☠ MINI-BOSS: O Carrasco Profanado surgiu!" % current_wave
	else:
		status_label.text = "Wave %d — elimine os inimigos!" % current_wave


func _spawn_single_enemy(spec: Dictionary) -> void:
	if game_over or not is_instance_valid(enemies_root):
		return
	var is_boss: bool = bool(spec.get("is_boss", false))
	var is_wolf: bool = bool(spec.get("is_wolf", false))
	var wave_num: int = int(spec.get("wave", current_wave))
	var angle: float = float(spec.get("angle", 0.0))
	var radius: float = float(spec.get("radius", 9.5))
	var enemy_scene: PackedScene = ENEMY_SCENE
	if is_boss:
		enemy_scene = BOSS_SCENE
	elif is_wolf:
		enemy_scene = WOLF_SCENE
	var enemy: TowerEnemy = enemy_scene.instantiate() as TowerEnemy
	var hp_per_wave: int = 18 if is_boss else 7
	enemy.maximum_health += (wave_num - 1) * hp_per_wave
	enemy.movement_speed += minf(float(wave_num - 1) * 0.05, 0.7)
	enemy.set_target(player)
	enemies_root.add_child(enemy)
	enemy.global_position = player.global_position + Vector3(cos(angle) * radius, 0, sin(angle) * radius)
	enemy.died.connect(func() -> void:
		_on_enemy_died(maxi(1, enemy.xp_reward_multiplier), enemy)
	)


func _on_enemy_died(xp_mult: int = 1, _enemy: TowerEnemy = null) -> void:
	if not game_over:
		for _i in range(maxi(1, xp_mult)):
			run_progression.grant_enemy_kill_xp()
	kills += 1
	enemies_left = maxi(enemies_left - 1, 0)
	kills_label.text = "Abates: %d" % kills
	if enemies_left == 0 and not game_over:
		waves_completed += 1
		status_label.text = "Wave concluida! Proxima em instantes..."
		get_tree().create_timer(1.6, false).timeout.connect(_start_wave)


func _on_choices_changed(pending: int) -> void:
	if game_over:
		return
	if in_lobby and pending > 0:
		in_lobby = false
		if lobby_hud != null:
			lobby_hud.visible = false
		if xp_hud != null:
			xp_hud.visible = true
	if pending > 0 and (level_up_modal != null and not level_up_modal.visible):
		_present_next_level_up_choice()


func _present_next_level_up_choice() -> void:
	if game_over or run_progression == null:
		return
	if run_progression.state.pending_upgrade_choices <= 0:
		if level_up_modal != null:
			level_up_modal.hide_modal()
		get_tree().paused = false
		return

	var offers: Array[ProgressionUpgradeDefinition] = run_progression.get_or_generate_current_offers(3)
	if offers.is_empty():
		run_progression.resolve_one_upgrade_choice()
		if level_up_modal != null:
			level_up_modal.hide_modal()
		get_tree().paused = false
		return

	get_tree().paused = true
	level_up_modal.present_offers(offers, run_progression.state, player.stats)


func _on_upgrade_chosen(upgrade: ProgressionUpgradeDefinition) -> void:
	if run_progression == null or upgrade == null:
		return
	var applied: bool = run_progression.apply_upgrade_choice(upgrade, player.stats, attack.ability_state)
	if applied:
		attack.sync_from_ability_state()
		_on_health_changed(player.health, player.max_health)
		_on_form_changed(attack.form_label())
	if run_progression.state.pending_upgrade_choices > 0 and not game_over:
		_present_next_level_up_choice()
	else:
		level_up_modal.hide_modal()
		if not game_over:
			get_tree().paused = false


func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	if level_up_modal != null:
		level_up_modal.hide_modal()

	current_run_summary = _build_run_summary(false)
	reward_calculator.grant_reward_once(current_run_summary, permanent_progression)

	status_label.text = "VOCE MORREU | Wave %d | +%d Essencia" % [current_wave, current_run_summary.essence_rewarded]
	get_tree().paused = true
	if run_result_modal != null:
		run_result_modal.show_summary(current_run_summary, permanent_progression.state.essence)


func _on_open_talent_tree_from_results() -> void:
	if run_result_modal != null:
		run_result_modal.hide_modal()
	_enter_sanctuary_lobby()


func _build_run_summary(is_victory: bool) -> RunSummaryState:
	var summary := RunSummaryState.new()
	summary.class_id = run_progression.state.class_id
	summary.wave_reached = maxi(1, current_wave)
	summary.waves_completed = maxi(0, waves_completed)
	summary.enemies_defeated = maxi(0, kills)
	summary.run_level_reached = run_progression.state.level
	summary.total_xp_earned = run_progression.state.total_xp
	summary.victory = is_victory
	summary.active_ability_name = attack.form_label()
	summary.acquired_upgrade_ids = run_progression.state.upgrade_history.duplicate()

	var title_counts: Dictionary = {}
	for upg_id in run_progression.state.upgrade_history:
		var title: String = upg_id
		for def in run_progression.upgrade_pool:
			if def != null and def.id == upg_id:
				title = def.title
				break
		title_counts[title] = int(title_counts.get(title, 0)) + 1
	for title_key in title_counts.keys():
		var cnt: int = int(title_counts[title_key])
		if cnt > 1:
			summary.acquired_upgrade_titles.append("%s (x%d)" % [String(title_key), cnt])
		else:
			summary.acquired_upgrade_titles.append(String(title_key))
	return summary


func _on_health_changed(current: int, maximum: int) -> void:
	health_label.text = "Vida: %d / %d" % [current, maximum]


func _on_form_changed(value: String) -> void:
	form_label.text = "Ataque: " + value
