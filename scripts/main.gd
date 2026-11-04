extends Node3D

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
# Novo inimigo: sera usado somente quando wolf.glb existir.
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
const CAMPAIGN_ZONE_DEF_SCRIPT = preload("res://game/campaign/campaign_zone_definition.gd")
const TOWN_INTERACTABLE_SCRIPT = preload("res://game/campaign/town_interactable_3d.gd")
const ZONE_PORTAL_SCRIPT = preload("res://game/campaign/zone_portal_3d.gd")
const TOWN_NPC_MODAL_SCRIPT: Script = preload("res://game/ui/campaign/town_npc_modal.gd")
const SKILL_BAR_HUD_SCRIPT: Script = preload("res://game/ui/campaign/skill_bar_hud.gd")
const ITEM_DEF_SCRIPT = preload("res://core/items/item_definition.gd")
const ITEM_INST_SCRIPT = preload("res://core/items/item_instance.gd")
const ITEM_DB_SCRIPT = preload("res://core/items/item_database.gd")
const SPATIAL_INV_SCRIPT = preload("res://core/items/spatial_inventory_grid.gd")
const CHAR_EQUIP_SCRIPT = preload("res://core/items/character_equipment.gd")
const INV_MODAL_SCRIPT: Script = preload("res://game/ui/items/inventory_equipment_modal.gd")
const GROUND_ITEM_SCRIPT: Script = preload("res://game/items/ground_item_3d.gd")
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

var run_progression: RunProgressionService
var permanent_progression: PermanentProgressionService
var reward_calculator: RunRewardCalculator = RunRewardCalculator.new()
var current_run_summary: RunSummaryState

var xp_hud: RunXpHUD
var level_up_modal: LevelUpModal
var run_result_modal: RunResultModal
var talent_tree_modal: TalentTreeModal
var lobby_hud: SanctuaryLobbyHUD
var town_npc_modal: TownNpcModal
var skill_bar_hud: SkillBarHUD
var inventory_modal: InventoryEquipmentModal
var backpack: SpatialInventoryGrid = SpatialInventoryGrid.new(10, 5)
var stash_grid: SpatialInventoryGrid = SpatialInventoryGrid.new(10, 6)
var equipment: CharacterEquipment = CharacterEquipment.new()
var _ground_items_root: Node3D
var in_lobby: bool = true
var is_campaign_mode: bool = false
var current_zone_id: String = "town"
var campaign_zones: Dictionary = {}
var unlocked_zones: Array[String] = ["town", "zone_1_road"]
var _campaign_props_root: Node3D
var _active_interactables: Array[TownInteractable3D] = []
var _active_portals: Array[ZonePortal3D] = []
var _initial_player_position: Vector3 = Vector3.ZERO
var _pending_wave_spawns: Array[Dictionary] = []
var _wolf_model_available: bool = false
var _boss_model_available: bool = false
var _warm_vfx: MeshInstance3D = null
var _warm_vfx_frames: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_initial_player_position = player.global_position
	rng.randomize()
	_wolf_model_available = ResourceLoader.exists(WOLF_MODEL_PATH)
	_boss_model_available = ResourceLoader.exists(BOSS_MODEL_PATH)
	VFX_EFFECT_SCRIPT.warm_up_caches()
	_warm_up_combat_shaders_and_models()

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
	lobby_hud.start_campaign_requested.connect(_start_campaign_mode)
	lobby_hud.open_talent_tree_requested.connect(_on_open_talent_tree_from_lobby)
	lobby_hud.preview_attack_requested.connect(_on_lobby_preview_attack)
	lobby_hud.rotate_character_requested.connect(_on_lobby_rotate_character)

	town_npc_modal = TOWN_NPC_MODAL_SCRIPT.new() as TownNpcModal
	$HUD.add_child(town_npc_modal)
	town_npc_modal.waypoint_travel_requested.connect(_on_waypoint_travel_requested)
	town_npc_modal.respec_build_requested.connect(_on_town_respec_build_requested)
	town_npc_modal.identify_items_requested.connect(_on_town_identify_items_requested)

	level_up_modal.add_to_group("blocking_modal")
	run_result_modal.add_to_group("blocking_modal")
	talent_tree_modal.add_to_group("blocking_modal")
	town_npc_modal.add_to_group("blocking_modal")
	lobby_hud.add_to_group("blocking_modal")

	skill_bar_hud = SKILL_BAR_HUD_SCRIPT.new() as SkillBarHUD
	$HUD.add_child(skill_bar_hud)
	if player != null and player.skill_controller != null:
		skill_bar_hud.bind_controller(player.skill_controller)
	skill_bar_hud.visible = false

	_ground_items_root = Node3D.new()
	_ground_items_root.name = "GroundItems"
	add_child(_ground_items_root)

	inventory_modal = INV_MODAL_SCRIPT.new() as InventoryEquipmentModal
	$HUD.add_child(inventory_modal)
	inventory_modal.bind_context(backpack, equipment, player.stats)
	_grant_starter_items()

	_campaign_props_root = Node3D.new()
	_campaign_props_root.name = "CampaignInteractiveProps"
	add_child(_campaign_props_root)
	campaign_zones = CAMPAIGN_ZONE_DEF_SCRIPT.build_default_campaign_zones()

	run_progression.choices_changed.connect(_on_choices_changed)
	run_progression.level_gained.connect(_on_level_gained)

	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	attack.form_changed.connect(_on_form_changed)

	_enter_sanctuary_lobby()


func _process(delta: float) -> void:
	if _warm_vfx != null:
		_warm_vfx_frames += 1
		if _warm_vfx_frames >= 2:
			if is_instance_valid(_warm_vfx):
				_warm_vfx.queue_free()
			_warm_vfx = null
	if game_over and Input.is_action_just_pressed("restart"):
		if is_campaign_mode:
			_start_campaign_mode()
		else:
			_start_new_run()
		return
	if not game_over and not _pending_wave_spawns.is_empty():
		var count_this_frame: int = mini(3, _pending_wave_spawns.size())
		for _i in range(count_this_frame):
			var spec: Dictionary = _pending_wave_spawns.pop_front()
			_spawn_single_enemy(spec)
	if is_campaign_mode and not in_lobby and not game_over:
		_update_campaign_world(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not is_campaign_mode or in_lobby or game_over:
		return
	if town_npc_modal != null and town_npc_modal.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			for station in _active_interactables:
				if is_instance_valid(station) and station.is_player_in_range():
					station.trigger_interaction()
					get_viewport().set_input_as_handled()
					return


func _warm_up_combat_shaders_and_models() -> void:
	# Pre-carrega e unifica a malha do esqueleto/lobo no cache e compila shaders OpenGL no 1º frame.
	if ResourceLoader.exists("res://assets/models/skeleton_enemy.glb"):
		var warm_skel: Node3D = SkinnedCache.instantiate_optimized("res://assets/models/skeleton_enemy.glb")
		if warm_skel != null:
			warm_skel.free()
	if _wolf_model_available:
		var warm_wolf: Node3D = SkinnedCache.instantiate_optimized(WOLF_MODEL_PATH)
		if warm_wolf != null:
			warm_wolf.free()
	if _boss_model_available:
		var warm_boss: Node3D = SkinnedCache.instantiate_optimized(BOSS_MODEL_PATH)
		if warm_boss != null:
			warm_boss.free()
	_warm_vfx = MeshInstance3D.new()
	_warm_vfx.mesh = VFX_EFFECT_SCRIPT._get_or_build_cached_mesh(0)
	_warm_vfx.material_override = VFX_EFFECT_SCRIPT.get_fade_material(1.0)
	_warm_vfx.material_overlay = SkinnedCache.get_hit_flash_material(1.0, 0.22)
	_warm_vfx.scale = Vector3.ONE * 0.001
	_warm_vfx.position = _initial_player_position + Vector3(0.0, 0.05, 0.0)
	add_child(_warm_vfx)


func _enter_sanctuary_lobby() -> void:
	in_lobby = true
	is_campaign_mode = false
	game_over = false
	get_tree().paused = false
	_clear_campaign_props()
	if arena_art != null and arena_art.has_method("rebuild_tower_arena"):
		arena_art.call("rebuild_tower_arena")
	if title_text_label != null:
		title_text_label.text = "ALTAR PROFANADO"
	if subtitle_text_label != null:
		subtitle_text_label.text = "DARK FANTASY / SPAWN ALTAR"
	if town_npc_modal != null:
		town_npc_modal.close_modal()
	if inventory_modal != null:
		inventory_modal.close_inventory()
	_clear_ground_items()
	if level_up_modal != null:
		level_up_modal.hide_modal()
	if run_result_modal != null:
		run_result_modal.hide_modal()
	if talent_tree_modal != null:
		talent_tree_modal.hide_lobby()
	if xp_hud != null:
		xp_hud.visible = false
	if skill_bar_hud != null:
		skill_bar_hud.visible = false
	if player != null and player.skill_controller != null:
		player.skill_controller.set_enabled(false)
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

	# Posiciona o Cavaleiro em cima do medalhao central do Altar (nivelado com o piso)!
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
	if skill_bar_hud != null:
		skill_bar_hud.visible = false
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
		1:
			VFX_SPAWNER.arc(self, origin, forward, 1.0)
		2:
			VFX_SPAWNER.spin(self, origin, 1.0)
		3:
			VFX_SPAWNER.stab(self, origin, forward, 1.45)
		_:
			VFX_SPAWNER.stab(self, origin, forward, 1.0)


func _on_lobby_rotate_character(delta_deg: float) -> void:
	if player != null:
		player.lobby_yaw_degrees = wrapf(player.lobby_yaw_degrees + delta_deg, -180.0, 180.0)


func _start_new_run() -> void:
	in_lobby = false
	is_campaign_mode = false
	get_tree().paused = false
	_clear_campaign_props()
	if arena_art != null and arena_art.has_method("rebuild_tower_arena"):
		arena_art.call("rebuild_tower_arena")
	if title_text_label != null:
		title_text_label.text = "A TORRE — MODO WAVES"
	if subtitle_text_label != null:
		subtitle_text_label.text = "SOBREVIVÊNCIA POR ONDAS"
	if town_npc_modal != null:
		town_npc_modal.close_modal()
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
	attack.auto_attack = false
	if player != null and player.skill_controller != null:
		player.skill_controller.set_enabled(true)
	if skill_bar_hud != null:
		skill_bar_hud.visible = true
		skill_bar_hud.refresh_slots()

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
	# 1 lobo a partir da wave 2; aumenta devagar conforme as waves.
	# Se o GLB ainda nao foi gerado, 100% dos spawns continuam esqueletos.
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


func _on_enemy_died(xp_mult: int = 1, enemy: TowerEnemy = null) -> void:
	if not game_over:
		if is_campaign_mode:
			var xp_val: int = 3
			if is_instance_valid(enemy):
				if enemy.is_mini_boss:
					xp_val = 28
				elif enemy.xp_reward_multiplier > 1:
					xp_val = 6
			run_progression.grant_xp(xp_val)
		else:
			for _i in range(maxi(1, xp_mult)):
				run_progression.grant_enemy_kill_xp()
	if is_instance_valid(enemy):
		_maybe_drop_loot_at(enemy.global_position, enemy.is_mini_boss)
	kills += 1
	enemies_left = maxi(enemies_left - 1, 0)
	kills_label.text = "Abates: %d" % kills
	if is_campaign_mode:
		wave_label.text = "Inimigos na Zona: %d" % enemies_left
		if enemies_left == 0 and not game_over:
			waves_completed += 1
			status_label.text = "Zona purificada! Siga pelo Portão Norte ou use o Waypoint."
		return
	if enemies_left == 0 and not game_over:
		waves_completed += 1
		status_label.text = "Wave concluida! Proxima em instantes..."
		get_tree().create_timer(1.6, false).timeout.connect(_start_wave)


func _maybe_drop_loot_at(pos: Vector3, is_boss: bool = false) -> void:
	if not is_instance_valid(_ground_items_root):
		return
	var chance: float = 0.95 if is_boss else 0.42
	if randf() > chance:
		return
	var count: int = randi_range(2, 3) if is_boss else 1
	for i in range(count):
		var ilvl: int = maxi(1, current_wave)
		var force_r: int = -1
		if is_boss and i == 0:
			force_r = ItemInstance.ItemRarity.RARE
		var item: ItemInstance = ItemDatabase.generate_loot(ilvl, force_r)
		var ground_drop: GroundItem3D = GROUND_ITEM_SCRIPT.new() as GroundItem3D
		_ground_items_root.add_child(ground_drop)
		var spread := Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
		ground_drop.setup_drop(item, pos + spread)


func _grant_starter_items() -> void:
	if backpack == null:
		return
	backpack.clear()
	# Dá ao jogador alguns itens de partida com tamanhos diferentes para testar o grid:
	# 1. Espada Longa 1H (2x3)
	var sword: ItemInstance = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "sword_steel")
	backpack.auto_add_item(sword)

	# 2. Peitoral de Placas (2x3)
	var chest: ItemInstance = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "chest_plate")
	backpack.auto_add_item(chest)

	# 3. Elmo de Ferro (2x2)
	var helm: ItemInstance = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "helm_iron")
	backpack.auto_add_item(helm)

	# 4. Botas de Placa (2x2)
	var boots: ItemInstance = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "boots_plate")
	backpack.auto_add_item(boots)

	# 5. Adaga (2x2)
	var dagger: ItemInstance = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "dagger_sharp")
	backpack.auto_add_item(dagger)

	# 6. Espada Montante 2H (2x4) Mágica Não-Identificada
	var greatsword: ItemInstance = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.MAGIC, "greatsword_iron")
	greatsword.is_identified = false
	backpack.auto_add_item(greatsword)

	# 7. Anel de Rubi (1x1) (+Força)
	var ring: ItemInstance = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.MAGIC, "ring_ruby")
	backpack.auto_add_item(ring)

	# 8. Amuleto (1x1) (+Agilidade)
	var amulet: ItemInstance = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.MAGIC, "amulet_hawk")
	backpack.auto_add_item(amulet)

	# 9. Poção de Vida (1x1)
	var pot: ItemInstance = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "potion_health")
	backpack.auto_add_item(pot)


func _clear_ground_items() -> void:
	if _ground_items_root != null:
		for child in _ground_items_root.get_children():
			child.queue_free()


func notify_item_pickup(item: ItemInstance) -> void:
	if status_label != null:
		status_label.text = "✦ %s coletado! Pressione [I] para ver na Mochila." % item.get_display_name()


func notify_inventory_full() -> void:
	if status_label != null:
		status_label.text = "⚠ MOCHILA CHEIA! Abra o Inventário [I] para organizar ou descartar itens."


func _on_town_identify_items_requested() -> void:
	var count: int = 0
	for it in backpack.items:
		if not it.is_identified:
			it.identify()
			count += 1
	if count > 0:
		status_label.text = "✦ O Sábio identificou %d item(ns) na sua mochila!" % count
	else:
		status_label.text = "✦ Todos os itens na mochila já estão identificados."
	if inventory_modal != null:
		inventory_modal._refresh_all()


# ===============================================================
# MODO CAMPANHA ARPG (VILA + ZONAS CONECTADAS + NPCs + WAYPOINTS)
# ===============================================================
func _clear_campaign_props() -> void:
	_active_interactables.clear()
	_active_portals.clear()
	_clear_ground_items()
	if _campaign_props_root != null:
		for child in _campaign_props_root.get_children():
			child.queue_free()


func _start_campaign_mode() -> void:
	in_lobby = false
	is_campaign_mode = true
	game_over = false
	get_tree().paused = false
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
	if town_npc_modal != null:
		town_npc_modal.close_modal()

	current_wave = 1
	waves_completed = 0
	enemies_left = 0
	kills = 0
	current_run_summary = null
	kills_label.text = "Abates: 0"
	unlocked_zones = ["town", "zone_1_road"]

	if xp_hud != null:
		xp_hud.set("_dead", false)

	player.set_lobby_mode(false)
	if camera != null and camera.has_method("set_lobby_mode"):
		camera.set_lobby_mode(false, false)
	player.configure_character(player.character_definition)
	attack.ability_state.setup_from_definition(attack.ability_state.definition)

	var arpg_bal := ProgressionBalance.new()
	arpg_bal.first_level_xp = 50
	arpg_bal.xp_linear_growth = 35
	arpg_bal.xp_quadratic_growth = 10
	arpg_bal.enemy_xp = 3
	run_progression.balance = arpg_bal
	run_progression.reset_run()
	permanent_progression.apply_to_run(
		player.character_definition.class_id if player.character_definition != null else "warrior",
		player.stats,
		run_progression,
		attack.ability_state
	)
	attack.sync_from_ability_state()
	attack.auto_attack = false
	if player != null and player.skill_controller != null:
		player.skill_controller.set_enabled(true)
	if skill_bar_hud != null:
		skill_bar_hud.visible = true
		skill_bar_hud.refresh_slots()
	_on_health_changed(player.health, player.max_health)
	_on_form_changed(attack.form_label())

	_load_campaign_zone("town")


func _load_campaign_zone(zone_id: String, custom_spawn: Variant = null) -> void:
	if not campaign_zones.has(zone_id):
		return
	var zone_def: CampaignZoneDefinition = campaign_zones[zone_id] as CampaignZoneDefinition
	current_zone_id = zone_id
	current_wave = maxi(1, zone_def.area_level)
	if not unlocked_zones.has(zone_id):
		unlocked_zones.append(zone_id)
	if not zone_def.next_zone_id.is_empty() and not unlocked_zones.has(zone_def.next_zone_id):
		unlocked_zones.append(zone_def.next_zone_id)

	for child in enemies_root.get_children():
		child.queue_free()
	_pending_wave_spawns.clear()
	_clear_campaign_props()

	if arena_art != null and arena_art.has_method("rebuild_campaign_zone"):
		arena_art.call("rebuild_campaign_zone", zone_def)

	if title_text_label != null:
		title_text_label.text = zone_def.title.to_upper()
	if subtitle_text_label != null:
		subtitle_text_label.text = zone_def.subtitle

	var spawn_pos: Vector3 = custom_spawn if custom_spawn is Vector3 else zone_def.default_spawn_pos
	player.global_position = spawn_pos + Vector3(0.0, 0.05, 0.0)
	player.velocity = Vector3.ZERO

	# Waypoint Ancestral (presente na Vila e em todas as Zonas)
	_spawn_town_station("waypoint", "✦ Waypoint Ancestral", "[E] Teleportar entre Zonas", zone_def.waypoint_pos, 0.0)

	if zone_def.is_safe_town:
		# Restaura a vida ao entrar na Vila segura
		player.health = player.max_health
		_on_health_changed(player.health, player.max_health)
		enemies_left = 0
		wave_label.text = "Zona: Vila Segura"
		status_label.text = "Vila: aproxime-se do Baú/Mercadores e aperte [E], ou saia pelo Portão Norte!"

		# Os 4 Interagíveis da Vila solicitados: Baú, Vendedor Físico, Vendedor Mágico e Identificador/Reset
		_spawn_town_station("stash", "📦 Baú Pessoal (Stash)", "[E] Abrir Baú", Vector3(-5.8, 0.0, -3.5), 25.0)
		_spawn_town_station("vendor_physical", "⚒ Ferreiro (Itens Físicos)", "[E] Negociar Armas & Armaduras", Vector3(-7.4, 0.0, 3.2), 65.0)
		_spawn_town_station("vendor_magic", "🔮 Arcanista (Itens Mágicos)", "[E] Negociar Relíquias Mágicas", Vector3(7.4, 0.0, -3.2), -55.0)
		_spawn_town_station("identifier_respec", "📜 Sábio (Identificar & Resetar Build)", "[E] Identificar Itens / Resetar Build", Vector3(-2.6, 0.0, -5.2), 15.0)

		# Portão Norte saindo da Vila para a Zona 1 (Estrada Profanada)
		_spawn_zone_gate(zone_def.zone_id, zone_def.next_zone_id, zone_def.next_zone_label, zone_def.next_gate_pos, false)
	else:
		# Portão Sul (Retorno) e Portão Norte (Avanço)
		if not zone_def.prev_zone_id.is_empty():
			_spawn_zone_gate(zone_def.zone_id, zone_def.prev_zone_id, zone_def.prev_zone_label, zone_def.prev_gate_pos, true)
		if not zone_def.next_zone_id.is_empty():
			_spawn_zone_gate(zone_def.zone_id, zone_def.next_zone_id, zone_def.next_zone_label, zone_def.next_gate_pos, false)

		_spawn_campaign_packs(zone_def)
		wave_label.text = "Inimigos na Zona: %d" % enemies_left
		status_label.text = "%s — Siga pela estrada, elimine os packs e alcance o Portão Norte!" % zone_def.title


func _spawn_town_station(id_val: String, title_val: String, sub_val: String, pos: Vector3, yaw_deg: float) -> void:
	var station: TownInteractable3D = TOWN_INTERACTABLE_SCRIPT.new() as TownInteractable3D
	_campaign_props_root.add_child(station)
	station.configure(id_val, title_val, sub_val, pos, yaw_deg)
	station.interaction_requested.connect(_on_town_station_interacted)
	_active_interactables.append(station)


func _spawn_zone_gate(from_id: String, to_id: String, label_txt: String, pos: Vector3, is_return: bool) -> void:
	var gate: ZonePortal3D = ZONE_PORTAL_SCRIPT.new() as ZonePortal3D
	_campaign_props_root.add_child(gate)
	gate.configure(from_id, to_id, label_txt, pos, is_return)
	gate.zone_transition_requested.connect(_on_zone_gate_crossed)
	_active_portals.append(gate)


func _spawn_campaign_packs(zone_def: CampaignZoneDefinition) -> void:
	enemies_left = 0
	var lvl: int = maxi(1, zone_def.area_level)
	for pack in zone_def.monster_packs:
		var center: Vector3 = pack.get("center", Vector3.ZERO)
		var skel_cnt: int = int(pack.get("skeletons", 0))
		var wolf_cnt: int = int(pack.get("wolves", 0)) if _wolf_model_available else 0
		var boss_cnt: int = int(pack.get("boss", 0)) if _boss_model_available else 0
		var spread: float = float(pack.get("spread", 2.6))
		var total_in_pack: int = skel_cnt + wolf_cnt + boss_cnt
		for idx in range(total_in_pack):
			var is_boss: bool = idx < boss_cnt
			var is_wolf: bool = (not is_boss) and (idx < boss_cnt + wolf_cnt)
			var ang: float = TAU * float(idx) / float(maxi(1, total_in_pack)) + rng.randf_range(-0.3, 0.3)
			var rad: float = 0.4 if is_boss else rng.randf_range(0.8, spread)
			var pos: Vector3 = center + Vector3(cos(ang) * rad, 0.0, sin(ang) * rad)

			var scene_to_use: PackedScene = ENEMY_SCENE
			if is_boss:
				scene_to_use = BOSS_SCENE
			elif is_wolf:
				scene_to_use = WOLF_SCENE
			var enemy: TowerEnemy = scene_to_use.instantiate() as TowerEnemy
			enemy.aggro_radius = 10.5
			var hp_bonus: int = 20 if is_boss else 8
			enemy.maximum_health += (lvl - 1) * hp_bonus
			enemy.movement_speed += minf(float(lvl - 1) * 0.06, 0.6)
			enemy.set_target(player)
			enemies_root.add_child(enemy)
			enemy.global_position = pos
			enemy.died.connect(func() -> void:
				_on_enemy_died(maxi(1, enemy.xp_reward_multiplier), enemy)
			)
			enemies_left += 1


func _update_campaign_world(delta: float) -> void:
	if player == null or not player.alive:
		return
	var p_pos: Vector3 = player.global_position
	var near_station: TownInteractable3D = null
	for station in _active_interactables:
		if is_instance_valid(station):
			if station.update_proximity(p_pos, delta) and near_station == null:
				near_station = station

	if near_station != null and (town_npc_modal == null or not town_npc_modal.visible):
		status_label.text = "%s — Pressione [E] para interagir" % near_station.station_title

	for gate in _active_portals:
		if is_instance_valid(gate):
			if gate.check_player_crossing(p_pos, delta):
				return


func _on_town_station_interacted(station_id: String, _station_title: String) -> void:
	if town_npc_modal != null:
		town_npc_modal.open_station(station_id, unlocked_zones, current_zone_id)


func _on_waypoint_travel_requested(dest_zone_id: String) -> void:
	if not campaign_zones.has(dest_zone_id):
		return
	var zdef: CampaignZoneDefinition = campaign_zones[dest_zone_id] as CampaignZoneDefinition
	_load_campaign_zone(dest_zone_id, zdef.waypoint_pos + Vector3(0.0, 0.0, 1.8))


func _on_zone_gate_crossed(target_zone_id: String, origin_zone_id: String) -> void:
	if not campaign_zones.has(target_zone_id):
		return
	var target_def: CampaignZoneDefinition = campaign_zones[target_zone_id] as CampaignZoneDefinition
	var spawn_pos: Vector3 = target_def.default_spawn_pos
	if target_def.next_zone_id == origin_zone_id:
		# Voltou pelo portão norte da zona anterior -> nasce perto do portão norte!
		spawn_pos = target_def.next_gate_pos + Vector3(0.0, 0.0, 2.8)
	elif target_def.prev_zone_id == origin_zone_id:
		# Avançou para a próxima zona -> nasce perto do portão sul!
		spawn_pos = target_def.prev_gate_pos + Vector3(0.0, 0.0, -2.8)
	_load_campaign_zone(target_zone_id, spawn_pos)


func _on_town_respec_build_requested() -> void:
	if permanent_progression != null:
		permanent_progression.respec_all()
	player.configure_character(player.character_definition)
	attack.ability_state.setup_from_definition(attack.ability_state.definition)
	run_progression.reset_run()
	var cid: String = player.character_definition.class_id if player.character_definition != null else "warrior"
	permanent_progression.apply_to_run(cid, player.stats, run_progression, attack.ability_state)
	attack.sync_from_ability_state()
	attack.auto_attack = false
	if player != null and player.skill_controller != null:
		player.skill_controller.set_enabled(true)
	if skill_bar_hud != null:
		skill_bar_hud.visible = true
		skill_bar_hud.refresh_slots()
	player.health = player.max_health
	_on_health_changed(player.health, player.max_health)
	_on_form_changed(attack.form_label())


func _on_choices_changed(pending: int) -> void:
	if game_over or is_campaign_mode:
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
	if game_over or is_campaign_mode or run_progression == null:
		return
	if run_progression.state.pending_upgrade_choices <= 0:
		if level_up_modal != null:
			level_up_modal.hide_modal()
		get_tree().paused = false
		return

	var offers: Array[ProgressionUpgradeDefinition] = run_progression.get_or_generate_current_offers(3)
	if offers.is_empty():
		# Caso extremo: pool esgotado (todas as opções possíveis já maximizadas).
		run_progression.resolve_one_upgrade_choice()
		if level_up_modal != null:
			level_up_modal.hide_modal()
		get_tree().paused = false
		return

	get_tree().paused = true
	level_up_modal.present_offers(offers, run_progression.state, player.stats)


func _on_level_gained(new_lvl: int) -> void:
	if is_campaign_mode:
		# Modo ARPG: Sem pop-up de cartas no meio da tela (estilo PoE/Diablo 2)!
		# O personagem recebe atributos base passivos automáticos (+12 HP, +2 STR, +1 AGI, +1 DANO) e recupera a vida
		if player != null and player.stats != null:
			player.stats.set_base_stat(CharacterStats.STAT_MAX_HEALTH, player.stats.get_base_stat(CharacterStats.STAT_MAX_HEALTH) + 12.0)
			player.stats.set_base_stat(CharacterStats.STAT_STRENGTH, player.stats.get_base_stat(CharacterStats.STAT_STRENGTH) + 2.0)
			player.stats.set_base_stat(CharacterStats.STAT_AGILITY, player.stats.get_base_stat(CharacterStats.STAT_AGILITY) + 1.0)
			player.stats.set_base_stat(CharacterStats.STAT_DAMAGE, player.stats.get_base_stat(CharacterStats.STAT_DAMAGE) + 1.0)
			player.max_health = player.stats.get_max_health()
			player.health = player.max_health
			_on_health_changed(player.health, player.max_health)
		if run_progression != null and run_progression.state != null:
			run_progression.state.pending_upgrade_choices = 0
		if status_label != null:
			status_label.text = "✦ NÍVEL %d ALCANÇADO! (+12 Vida Máxima, +2 Força, +1 Agilidade, +1 Dano)" % new_lvl
		if inventory_modal != null and inventory_modal.visible:
			inventory_modal._refresh_stats_view()


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
	if player != null and player.skill_controller != null:
		player.skill_controller.set_enabled(false)
	if skill_bar_hud != null:
		skill_bar_hud.visible = false
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
