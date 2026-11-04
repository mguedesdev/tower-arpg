extends Node3D
class_name ARPGGameController
## Controlador Central Exclusivo do Modo ARPG (Campanha Dark Fantasy, estilo Diablo 2 / Path of Exile).
## Totalmente desacoplado do Infinity Tower: sem auto-ataque, sem lobby da torre, sem cartas de sobrevivente.

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const WOLF_SCENE: PackedScene = preload("res://scenes/enemies/wolf.tscn")
const WOLF_MODEL_PATH: String = "res://assets/models/wolf.glb"
const BOSS_SCENE: PackedScene = preload("res://scenes/enemies/executioner_boss.tscn")
const BOSS_MODEL_PATH: String = "res://assets/models/skeleton_boss.glb"
const MALAKOR_SCENE: PackedScene = preload("res://scenes/enemies/boss_malakor.tscn")
const MALAKOR_MODEL_PATH: String = "res://assets/models/boss_malakor.glb"

const RUN_PROGRESSION_SCRIPT: Script = preload("res://core/progression/run_progression_service.gd")
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
@onready var camera: Camera3D = $Camera
@onready var enemies_root: Node3D = $Enemies
@onready var arena_art: Node3D = $ArenaArt
@onready var title_text_label: Label = $HUD/TitlePlate/TitleText
@onready var subtitle_text_label: Label = $HUD/TitlePlate/Subtitle
@onready var zone_info_label: Label = $HUD/Info/ZoneLabel
var health_label: Label = null
var kills_label: Label = null
@onready var status_label: Label = $HUD/StatusLabel

var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var kills: int = 0
var enemies_left: int = 0
var game_over: bool = false
var area_level: int = 1

var run_progression: RunProgressionService
var skill_bar_hud: SkillBarHUD
var town_npc_modal: TownNpcModal
var inventory_modal: InventoryEquipmentModal

var backpack: SpatialInventoryGrid = SpatialInventoryGrid.new(10, 5)
var stash_grid: SpatialInventoryGrid = SpatialInventoryGrid.new(10, 6)
var equipment: CharacterEquipment = CharacterEquipment.new()

var _ground_items_root: Node3D
var _campaign_props_root: Node3D
var _active_interactables: Array[TownInteractable3D] = []
var _active_portals: Array[ZonePortal3D] = []
var campaign_zones: Dictionary = {}
var unlocked_zones: Array[String] = ["town", "zone_1_road"]
var current_zone_id: String = "town"

var _wolf_model_available: bool = false
var _boss_model_available: bool = false
var _malakor_model_available: bool = false
var _malakor_spawned: bool = false
var _pause_menu: PanelContainer
var _status_timer: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	rng.randomize()
	_wolf_model_available = ResourceLoader.exists(WOLF_MODEL_PATH)
	_boss_model_available = ResourceLoader.exists(BOSS_MODEL_PATH)
	_malakor_model_available = ResourceLoader.exists(MALAKOR_MODEL_PATH)
	VFX_EFFECT_SCRIPT.warm_up_caches()
	_warm_up_models()

	_ground_items_root = Node3D.new()
	_ground_items_root.name = "GroundItems"
	add_child(_ground_items_root)

	_campaign_props_root = Node3D.new()
	_campaign_props_root.name = "CampaignInteractiveProps"
	add_child(_campaign_props_root)

	campaign_zones = CAMPAIGN_ZONE_DEF_SCRIPT.build_default_campaign_zones()

	# Configuração de Progressão ARPG cadenciada (50 XP nível 2, sem cartas de sobrevivente)
	run_progression = RUN_PROGRESSION_SCRIPT.new() as RunProgressionService
	add_child(run_progression)
	var arpg_bal := ProgressionBalance.new()
	arpg_bal.first_level_xp = 50
	arpg_bal.xp_linear_growth = 35
	arpg_bal.xp_quadratic_growth = 10
	arpg_bal.enemy_xp = 3
	run_progression.balance = arpg_bal
	run_progression.reset_run()
	run_progression.level_gained.connect(_on_level_gained)
	run_progression.progress_changed.connect(_on_arpg_progress_changed)

	# HUD de Experiência Minimalista ARPG (estilo Albion - barra fina no rodapé)
	_build_arpg_xp_hud()

	# Barra de Habilidades Ativas (WASD + LMB ataque básico + RMB/1/2/3/4)
	skill_bar_hud = SKILL_BAR_HUD_SCRIPT.new() as SkillBarHUD
	$HUD.add_child(skill_bar_hud)
	if player != null and player.skill_controller != null:
		skill_bar_hud.bind_controller(player.skill_controller)
		player.skill_controller.set_enabled(true)
	skill_bar_hud.visible = true

	# Modal de NPCs e Waypoints da Vila
	town_npc_modal = TOWN_NPC_MODAL_SCRIPT.new() as TownNpcModal
	$HUD.add_child(town_npc_modal)
	town_npc_modal.waypoint_travel_requested.connect(_on_waypoint_travel_requested)
	town_npc_modal.respec_build_requested.connect(_on_town_respec_build_requested)
	town_npc_modal.identify_items_requested.connect(_on_town_identify_items_requested)
	town_npc_modal.add_to_group("blocking_modal")

	# Modal de Inventário em Grade Espacial 10x5 + Equipamento (Paperdoll) + Atributos
	inventory_modal = INV_MODAL_SCRIPT.new() as InventoryEquipmentModal
	$HUD.add_child(inventory_modal)
	inventory_modal.bind_context(backpack, equipment, player.stats)
	inventory_modal.add_to_group("blocking_modal")
	_grant_starter_items()

	# Menu de Pausa / Retornar ao Launcher
	_build_pause_menu()

	# Configura o Jogador
	player.set_lobby_mode(false)
	if player.attack_controller != null:
		player.attack_controller.auto_attack = false
	player.health_changed.connect(_on_health_changed)
	player.died.connect(_on_player_died)
	_on_health_changed(player.health, player.max_health)

	if camera != null and camera.has_method("set_lobby_mode"):
		camera.set_lobby_mode(false, true)

	# Inicia diretamente na Vila Segura
	_load_campaign_zone("town")


func _process(delta: float) -> void:
	if not game_over:
		_update_campaign_world(delta)


func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		return
	if town_npc_modal != null and town_npc_modal.visible:
		return
	if inventory_modal != null and inventory_modal.visible:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			# 1. Pega item caído no chão próximo (prioridade ao loot)
			if _pickup_nearest_ground_item():
				get_viewport().set_input_as_handled()
				return
			# 2. Interage com NPC / Baú / Waypoint da Vila
			for station in _active_interactables:
				if is_instance_valid(station) and station.is_player_in_range():
					station.trigger_interaction()
					get_viewport().set_input_as_handled()
					return
		elif event.keycode == KEY_ESCAPE:
			_toggle_pause_menu()
			get_viewport().set_input_as_handled()


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
	if _malakor_model_available:
		var m = SkinnedCache.instantiate_optimized(MALAKOR_MODEL_PATH)
		if m != null: m.free()


func _build_pause_menu() -> void:
	_pause_menu = PanelContainer.new()
	_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_menu.visible = false
	_pause_menu.custom_minimum_size = Vector2(360, 260)
	_pause_menu.anchors_preset = Control.PRESET_CENTER
	_pause_menu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_pause_menu.grow_vertical = Control.GROW_DIRECTION_BOTH

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.05, 0.96)
	style.border_color = Color(0.65, 0.50, 0.22, 0.90)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_radius_bottom_right = 10
	_pause_menu.add_theme_stylebox_override("panel", style)

	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", 16)
	_pause_menu.add_child(vb)

	var title := Label.new()
	title.text = "ARPG: JOGO PAUSADO"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	vb.add_child(title)

	var btn_resume := Button.new()
	btn_resume.text = "CONTINUAR EXPLORAÇÃO"
	btn_resume.custom_minimum_size = Vector2(280, 42)
	btn_resume.pressed.connect(_toggle_pause_menu)
	vb.add_child(btn_resume)

	var btn_launcher := Button.new()
	btn_launcher.text = "VOLTAR AO MENU PRINCIPAL (LAUNCHER)"
	btn_launcher.custom_minimum_size = Vector2(280, 42)
	btn_launcher.pressed.connect(return_to_launcher)
	vb.add_child(btn_launcher)

	$HUD.add_child(_pause_menu)


func _toggle_pause_menu() -> void:
	if _pause_menu == null:
		return
	var is_open: bool = not _pause_menu.visible
	_pause_menu.visible = is_open
	get_tree().paused = is_open


func return_to_launcher() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/launcher.tscn")


# ===============================================================
# CARREGAMENTO DE ZONAS & CAMPANHA
# ===============================================================
func _clear_campaign_props() -> void:
	_active_interactables.clear()
	_active_portals.clear()
	_clear_ground_items()
	if _campaign_props_root != null:
		for child in _campaign_props_root.get_children():
			child.queue_free()


func _clear_ground_items() -> void:
	if _ground_items_root != null:
		for child in _ground_items_root.get_children():
			child.queue_free()


func _load_campaign_zone(zone_id: String, custom_spawn: Variant = null) -> void:
	if not campaign_zones.has(zone_id):
		return
	var zone_def: CampaignZoneDefinition = campaign_zones[zone_id] as CampaignZoneDefinition
	current_zone_id = zone_id
	_malakor_spawned = false
	area_level = maxi(1, zone_def.area_level)
	if not unlocked_zones.has(zone_id):
		unlocked_zones.append(zone_id)
	if not zone_def.next_zone_id.is_empty() and not unlocked_zones.has(zone_def.next_zone_id):
		unlocked_zones.append(zone_def.next_zone_id)

	for child in enemies_root.get_children():
		child.queue_free()
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

	# Waypoint Ancestral (presente na Vila e nas Zonas)
	_spawn_town_station("waypoint", "✦ Waypoint Ancestral", "[E] Teleportar entre Zonas", zone_def.waypoint_pos, 0.0)

	if zone_def.is_safe_town:
		player.health = player.max_health
		_on_health_changed(player.health, player.max_health)
		enemies_left = 0
		if zone_info_label != null:
			zone_info_label.text = "Zona: Vila Segura"
		status_label.text = "Vila Segura: aproxime-se dos Mercadores/Baú e aperte [E], ou saia pelo Portão Norte!"

		# Os 4 Interagíveis solicitados: Baú, Vendedor Físico, Vendedor Mágico e Sábio de Identificar/Reset
		_spawn_town_station("stash", "📦 Baú Pessoal (Stash)", "[E] Abrir Baú", Vector3(-5.8, 0.0, -3.5), 25.0)
		_spawn_town_station("vendor_physical", "⚒ Ferreiro (Itens Físicos)", "[E] Negociar Armas & Armaduras", Vector3(-7.4, 0.0, 3.2), 65.0)
		_spawn_town_station("vendor_magic", "🔮 Arcanista (Itens Mágicos)", "[E] Negociar Relíquias Mágicas", Vector3(7.4, 0.0, -3.2), -55.0)
		_spawn_town_station("identifier_respec", "📜 Sábio (Identificar & Resetar)", "[E] Identificar Itens / Resetar Build", Vector3(-2.6, 0.0, -5.2), 15.0)

		# Portão Norte saindo da Vila para a Zona 1
		_spawn_zone_gate(zone_def.zone_id, zone_def.next_zone_id, zone_def.next_zone_label, zone_def.next_gate_pos, false)
	else:
		if not zone_def.prev_zone_id.is_empty():
			_spawn_zone_gate(zone_def.zone_id, zone_def.prev_zone_id, zone_def.prev_zone_label, zone_def.prev_gate_pos, true)
		if not zone_def.next_zone_id.is_empty():
			_spawn_zone_gate(zone_def.zone_id, zone_def.next_zone_id, zone_def.next_zone_label, zone_def.next_gate_pos, false)

		_spawn_campaign_packs(zone_def)
		if zone_info_label != null:
			zone_info_label.text = "Inimigos na Zona: %d" % enemies_left
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

	var near_item: GroundItem3D = _get_nearest_ground_item(3.5)
	if _ground_items_root != null:
		for child in _ground_items_root.get_children():
			if child is GroundItem3D and is_instance_valid(child) and not child.is_picked:
				child.set_in_pickup_range(child == near_item)

	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0 and status_label != null:
			status_label.text = ""
	elif near_item != null and (town_npc_modal == null or not town_npc_modal.visible):
		status_label.text = "✦ Pressione [E] para coletar: %s" % near_item.item.get_display_name()
	elif near_station != null and (town_npc_modal == null or not town_npc_modal.visible):
		status_label.text = "%s — Pressione [E] para interagir" % near_station.station_title
	elif status_label != null and (status_label.text.begins_with("✦ Pressione [E]") or status_label.text.ends_with("Pressione [E] para interagir")):
		status_label.text = ""

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
		spawn_pos = target_def.next_gate_pos + Vector3(0.0, 0.0, 2.8)
	elif target_def.prev_zone_id == origin_zone_id:
		spawn_pos = target_def.prev_gate_pos + Vector3(0.0, 0.0, -2.8)
	_load_campaign_zone(target_zone_id, spawn_pos)


func _on_enemy_died(_xp_mult: int = 1, enemy: TowerEnemy = null) -> void:
	if not game_over:
		var xp_val: int = 3
		if is_instance_valid(enemy):
			if enemy.is_mini_boss:
				xp_val = 28
			elif enemy.xp_reward_multiplier > 1:
				xp_val = 6
		run_progression.grant_xp(xp_val)

	if is_instance_valid(enemy):
		_maybe_drop_loot_at(enemy.global_position, enemy.is_mini_boss)

	kills += 1
	enemies_left = maxi(enemies_left - 1, 0)
	if kills_label != null:
		kills_label.text = "Abates: %d" % kills
	if zone_info_label != null:
		zone_info_label.text = "Inimigos na Zona: %d" % enemies_left
	if enemies_left == 0 and not game_over:
		if current_zone_id == "zone_3_crypt" and not _malakor_spawned:
			_spawn_zone_boss_malakor()
		else:
			status_label.text = "Zona purificada! Siga pelo Portão Norte ou use o Waypoint."
			_status_timer = 5.0


func _spawn_zone_boss_malakor() -> void:
	_malakor_spawned = true
	enemies_left = 1
	var boss: TowerEnemy = MALAKOR_SCENE.instantiate() as TowerEnemy
	boss.aggro_radius = 18.0
	boss.set_target(player)
	var spawn_pos: Vector3 = Vector3(0.0, 0.0, -4.5)
	enemies_root.add_child(boss)
	boss.global_position = spawn_pos
	var scene_root: Node3D = self as Node3D
	VFX_SPAWNER.fire_burst(scene_root, spawn_pos + Vector3.UP * 0.8, 2.0)
	VFX_SPAWNER.spin(scene_root, spawn_pos + Vector3.UP * 0.4, 2.4)
	boss.died.connect(func() -> void:
		_on_enemy_died(10, boss)
		if status_label != null:
			status_label.text = "✦ VITÓRIA! MALAKOR FOI DESTRUÍDO! O CAMINHO PARA A NOVA ÁREA ESTÁ ABERTO!"
			_status_timer = 8.0
	)
	if zone_info_label != null:
		zone_info_label.text = "CHEFE: Malakor (Cripta)"
	if status_label != null:
		status_label.text = "☠ A TERRA TREME... MALAKOR, O CEIFADOR DE ALMAS DESPERTOU!"
		_status_timer = 6.0


func _maybe_drop_loot_at(pos: Vector3, is_boss: bool = false) -> void:
	if not is_instance_valid(_ground_items_root):
		return
	var chance: float = 0.95 if is_boss else 0.42
	if randf() > chance:
		return
	var count: int = randi_range(2, 3) if is_boss else 1
	for i in range(count):
		var ilvl: int = maxi(1, area_level)
		var force_r: int = -1
		if is_boss and i == 0:
			force_r = ItemInstance.ItemRarity.RARE
		var item: ItemInstance = ItemDatabase.generate_loot(ilvl, force_r)
		var ground_drop: GroundItem3D = GROUND_ITEM_SCRIPT.new() as GroundItem3D
		_ground_items_root.add_child(ground_drop)
		var spread := Vector3(randf_range(-0.6, 0.6), 0.0, randf_range(-0.6, 0.6))
		ground_drop.setup_drop(item, pos + spread)


func _on_level_gained(new_lvl: int) -> void:
	# Progressão ARPG: Sem cartas de sobrevivente interrompendo!
	# Ganho passivo automático de atributos por nível e restauração total de vida
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


func _get_nearest_ground_item(max_dist: float = 3.5) -> GroundItem3D:
	if _ground_items_root == null or player == null:
		return null
	var p_pos: Vector3 = player.global_position
	var nearest: GroundItem3D = null
	var min_d: float = max_dist
	for child in _ground_items_root.get_children():
		if child is GroundItem3D and not child.is_picked and is_instance_valid(child):
			var d: float = p_pos.distance_to(child.global_position)
			if d < min_d:
				min_d = d
				nearest = child
	return nearest


func _pickup_nearest_ground_item() -> bool:
	var item: GroundItem3D = _get_nearest_ground_item(3.5)
	if item != null:
		return item.attempt_pickup(player)
	return false


func _grant_starter_items() -> void:
	if backpack == null:
		return
	backpack.clear()
	var player_stats: CharacterStats = player.stats if player != null else null
	var sword = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "sword_steel")
	if equipment != null and sword != null:
		equipment.equip_item(sword, ItemDefinition.EquipmentSlot.MAIN_HAND, player_stats)

	var chest = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "chest_plate")
	if equipment != null and chest != null:
		equipment.equip_item(chest, ItemDefinition.EquipmentSlot.CHEST, player_stats)

	var boots = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "boots_plate")
	if equipment != null and boots != null:
		equipment.equip_item(boots, ItemDefinition.EquipmentSlot.BOOTS, player_stats)

	var dagger = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "dagger_sharp")
	backpack.auto_add_item(dagger)

	var ring = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.MAGIC, "ring_ruby")
	backpack.auto_add_item(ring)

	var pot = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "potion_health")
	backpack.auto_add_item(pot)

	if inventory_modal != null:
		inventory_modal._refresh_all()


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


func _on_town_respec_build_requested() -> void:
	# Reinicia atributos base e vida ao resetar build no sábio
	player.stats.set_base_stat(CharacterStats.STAT_MAX_HEALTH, 100.0)
	player.stats.set_base_stat(CharacterStats.STAT_DAMAGE, 14.0)
	player.stats.set_base_stat(CharacterStats.STAT_STRENGTH, 20.0)
	player.stats.set_base_stat(CharacterStats.STAT_AGILITY, 14.0)
	player.stats.set_base_stat(CharacterStats.STAT_INTELLIGENCE, 10.0)
	player.max_health = player.stats.get_max_health()
	player.health = player.max_health
	_on_health_changed(player.health, player.max_health)
	status_label.text = "✦ O Sábio purificou suas bênçãos: Atributos resetados para os valores base!"
	if inventory_modal != null and inventory_modal.visible:
		inventory_modal._refresh_stats_view()


func notify_item_pickup(item: ItemInstance) -> void:
	if status_label != null:
		status_label.text = "✦ %s coletado! Pressione [I] para ver na Mochila." % item.get_display_name()
		_status_timer = 3.5


func notify_inventory_full() -> void:
	if status_label != null:
		status_label.text = "⚠ MOCHILA CHEIA! Abra o Inventário [I] para organizar ou descartar itens."
		_status_timer = 4.0


func _on_health_changed(current: int, maximum: int) -> void:
	if health_label != null:
		health_label.text = "Vida: %d / %d" % [current, maximum]


func _on_player_died() -> void:
	if game_over:
		return
	game_over = true
	if player != null and player.skill_controller != null:
		player.skill_controller.set_enabled(false)
	if skill_bar_hud != null:
		skill_bar_hud.visible = false
	status_label.text = "☠ VOCÊ CAIU EM COMBATE! Pressione [R] para renascer na Vila ou [ESC] para o Menu."


func _input(event: InputEvent) -> void:
	if game_over and event is InputEventKey and event.pressed and event.keycode == KEY_R:
		game_over = false
		player.alive = true
		player.health = player.max_health
		_on_health_changed(player.health, player.max_health)
		if player.skill_controller != null:
			player.skill_controller.set_enabled(true)
		if skill_bar_hud != null:
			skill_bar_hud.visible = true
		_load_campaign_zone("town")


# ===============================================================
# HUD DE EXPERIÊNCIA & NÍVEL DO MODO ARPG (SEM WAVES OU ABATES)
# ===============================================================
var _arpg_xp_bar: ProgressBar
var _arpg_xp_label: Label

func _build_arpg_xp_hud() -> void:
	var xp_container := PanelContainer.new()
	xp_container.name = "ARPG_XpHUD"
	xp_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xp_container.anchors_preset = Control.PRESET_BOTTOM_WIDE
	xp_container.offset_top = -22.0
	xp_container.offset_bottom = -6.0
	xp_container.offset_left = 320.0
	xp_container.offset_right = -320.0
	xp_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	xp_container.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.07, 0.85)
	style.border_color = Color(0.65, 0.52, 0.22, 0.70)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	xp_container.add_theme_stylebox_override("panel", style)

	_arpg_xp_bar = ProgressBar.new()
	_arpg_xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arpg_xp_bar.show_percentage = false
	_arpg_xp_bar.anchors_preset = Control.PRESET_FULL_RECT
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.85, 0.68, 0.22, 0.90)
	fill_style.set_corner_radius_all(3)
	var bg_bar := StyleBoxFlat.new()
	bg_bar.bg_color = Color(0.06, 0.08, 0.10, 0.60)
	_arpg_xp_bar.add_theme_stylebox_override("fill", fill_style)
	_arpg_xp_bar.add_theme_stylebox_override("background", bg_bar)
	xp_container.add_child(_arpg_xp_bar)

	_arpg_xp_label = Label.new()
	_arpg_xp_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arpg_xp_label.anchors_preset = Control.PRESET_FULL_RECT
	_arpg_xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arpg_xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_arpg_xp_label.add_theme_font_size_override("font_size", 11)
	_arpg_xp_label.add_theme_color_override("font_color", Color(0.95, 0.92, 0.82))
	xp_container.add_child(_arpg_xp_label)

	$HUD.add_child(xp_container)
	_refresh_arpg_xp_hud()

func _on_arpg_progress_changed(level: int, current_xp: int, xp_required: int) -> void:
	_update_arpg_xp_display(level, current_xp, xp_required)

func _refresh_arpg_xp_hud() -> void:
	if run_progression == null or _arpg_xp_bar == null:
		return
	var state = run_progression.state
	var balance = run_progression.balance
	var lvl: int = state.level if state != null else 1
	var cur_xp: int = state.xp if state != null else 0
	var req_xp: int = balance.xp_to_next_level(lvl) if balance != null else 50
	_update_arpg_xp_display(lvl, cur_xp, req_xp)

func _update_arpg_xp_display(lvl: int, cur_xp: int, req_xp: int) -> void:
	if _arpg_xp_bar == null or _arpg_xp_label == null:
		return
	_arpg_xp_bar.max_value = float(maxi(1, req_xp))
	_arpg_xp_bar.value = float(cur_xp)
	var pct: float = (float(cur_xp) / float(maxi(1, req_xp))) * 100.0
	_arpg_xp_label.text = "✦ Nível %d  •  %d / %d XP (%.1f%%)" % [lvl, cur_xp, req_xp, pct]
