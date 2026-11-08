extends Node
## Gerenciador Central de Carregamento Assíncrono e Transição de Cenas/Regiões (Godot 4).
## Unifica todo o ciclo de vida de carregamento do ARPG:
## 1. Inicialização do jogo (Launcher -> ARPG).
## 2. Troca de regiões por Portais.
## 3. Teleporte por Waypoints.
## 4. Retorno ao jogo / Carregamento de partida salva.
## 5. Pré-compilação e aquecimento de shaders e pipelines gráficos antes de liberar o jogador.

signal transition_started(destination_id: String)
signal transition_progress(step_name: String, progress: float)
signal transition_completed(destination_id: String)
signal transition_failed(destination_id: String, error_message: String)

const LoadingScreenScript = preload("res://core/loading/loading_screen.gd")
const PipelineWarmupServiceScript = preload("res://core/loading/pipeline_warmup_service.gd")

static var instance: Node = null

var _screen: CanvasLayer = null
var _is_transitioning: bool = false
var _current_zone_id: String = ""
var _last_error: String = ""


static func get_instance() -> Node:
	if instance != null and is_instance_valid(instance):
		return instance

	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		var found = tree.root.get_node_or_null("LoadingManager")
		if found != null:
			instance = found
			return instance
		var script_res = load("res://core/loading/loading_manager.gd")
		var new_mgr = script_res.new()
		new_mgr.name = "LoadingManager"
		tree.root.add_child(new_mgr)
		instance = new_mgr
		return instance

	return null


func _enter_tree() -> void:
	if instance == null or not is_instance_valid(instance):
		instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS

	if _screen == null:
		_screen = LoadingScreenScript.new()
		_screen.name = "UniversalLoadingScreen"
		add_child(_screen)


func _exit_tree() -> void:
	if instance == self:
		instance = null


func is_loading() -> bool:
	return _is_transitioning or (_screen != null and _screen.is_active())


## Mapeia o caminho da ilustração regional oficial do mapa de Velen
static func get_zone_icon_path(zone_id: String) -> String:
	match zone_id:
		"town":
			return "res://assets/ui/world_map/01_vila_de_velen.png"
		"zone_1_road":
			return "res://assets/ui/world_map/02_floresta_de_arath.png"
		"zone_2_woods":
			return "res://assets/ui/world_map/03_ruinas_antigas.png"
		"zone_4_mines":
			return "res://assets/ui/world_map/04_minas_de_karpon.png"
		"zone_3_crypt":
			return "res://assets/ui/world_map/05_cripta_do_carrasco.png"
		"zone_6_hills":
			return "res://assets/ui/world_map/06_colinas_sombrias.png"
		"zone_7_plateau":
			return "res://assets/ui/world_map/07_planalto_esquecido.png"
		"zone_8_rift":
			return "res://assets/ui/world_map/08_fenda_abissal.png"
		_:
			return ""


## ============================================================================
## 1. TRANSIÇÃO DE CENAS PRINCIPAIS (LAUNCHER -> JOGO / GAME OVER -> MENU)
## ============================================================================
func transition_to_scene(
	scene_path: String,
	zone_title: String = "DARK FANTASY ARPG",
	zone_subtitle: String = "Carregando recursos...",
	icon_path: String = "",
	on_ready: Callable = Callable()
) -> void:
	if _is_transitioning:
		push_warning("LoadingManager: Solicitação de transição ignorada — já existe um carregamento em andamento.")
		return

	if not ResourceLoader.exists(scene_path):
		_handle_error(scene_path, "Arquivo de cena não encontrado: %s" % scene_path)
		return

	_is_transitioning = true
	transition_started.emit(scene_path)

	# 1. Configura UI e executa Fade In
	_screen.setup_destination(zone_title, zone_subtitle, icon_path)
	await _screen.fade_in(0.20)
	_screen.set_step("Iniciando carregamento...", 0.05)

	# Aguarda 2 frames para garantir que a tela de loading foi desenhada no display
	await get_tree().process_frame
	await get_tree().process_frame

	# 2. Carregamento Assíncrono via ResourceLoader threaded
	_screen.set_step("Carregando arquivos da cena...", 0.15)
	var err: Error = ResourceLoader.load_threaded_request(scene_path, "", true)
	if err != OK:
		_handle_error(scene_path, "Falha ao iniciar carregamento assíncrono (código %d)" % err)
		return

	var progress_arr: Array = []
	var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(scene_path, progress_arr)

	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		var p_val: float = progress_arr[0] if not progress_arr.is_empty() else 0.0
		var display_p: float = 0.15 + (p_val * 0.55) # 15% a 70%
		_screen.set_step("Carregando recursos (%d%%)..." % int(p_val * 100.0), display_p)
		transition_progress.emit("Carregando recursos", display_p)
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(scene_path, progress_arr)

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		_handle_error(scene_path, "Falha ao completar carregamento assíncrono de %s" % scene_path)
		return

	# 3. Resgate seguro do PackedScene já carregado
	var packed_scene: PackedScene = ResourceLoader.load_threaded_get(scene_path) as PackedScene
	if packed_scene == null:
		_handle_error(scene_path, "Recurso carregado não é um PackedScene válido.")
		return

	_screen.set_step("Instanciando cena e sistemas...", 0.75)
	transition_progress.emit("Instanciando cena", 0.75)
	await get_tree().process_frame

	get_tree().change_scene_to_packed(packed_scene)

	# Aguarda 2 frames para a cena ativa inicializar seu _ready()
	await get_tree().process_frame
	await get_tree().process_frame

	# 4. Pré-aquecimento de Shaders e Pipelines Gráficos
	_screen.set_step("Compilando pipelines gráficos e shaders...", 0.88)
	transition_progress.emit("Compilando shaders", 0.88)
	await PipelineWarmupServiceScript.warm_up_pipelines(get_tree(), "")

	# 5. Finalização
	_screen.set_step("Mundo pronto!", 1.00)
	transition_progress.emit("Concluído", 1.00)
	await get_tree().process_frame

	if on_ready.is_valid():
		on_ready.call()

	await _screen.fade_out(0.25)
	_is_transitioning = false
	transition_completed.emit(scene_path)


## ============================================================================
## 2. TRANSIÇÃO DE REGIÕES IN-GAME (VILA -> FLORESTA -> RUÍNAS / WAYPOINTS / PORTAIS)
## ============================================================================
func transition_to_region(
	game_controller: Node,
	target_zone_id: String,
	custom_spawn: Variant = null,
	on_ready: Callable = Callable()
) -> void:
	if _is_transitioning:
		push_warning("LoadingManager: Solicitação de troca de região ignorada — transição em andamento.")
		return

	if game_controller == null or not is_instance_valid(game_controller):
		_handle_error(target_zone_id, "Controlador de jogo inválido fornecido para transição.")
		return

	var campaign_zones: Dictionary = game_controller.get("campaign_zones") as Dictionary
	if campaign_zones == null or not campaign_zones.has(target_zone_id):
		_handle_error(target_zone_id, "Região de destino não cadastrada: %s" % target_zone_id)
		return

	var zone_def: CampaignZoneDefinition = campaign_zones[target_zone_id] as CampaignZoneDefinition
	if zone_def == null:
		_handle_error(target_zone_id, "Definição de região corrompida ou nula para: %s" % target_zone_id)
		return

	_is_transitioning = true
	transition_started.emit(target_zone_id)

	# 1. Bloqueia comandos do jogador para garantir integridade física e de combate
	var player = game_controller.get("player")
	if player != null and is_instance_valid(player):
		player.set("input_enabled", false)
		player.set("velocity", Vector3.ZERO)

	# 2. Exibe a tela de loading com arte da zona
	var icon_path: String = get_zone_icon_path(target_zone_id)
	_screen.setup_destination(zone_def.title, zone_def.subtitle, icon_path)
	await _screen.fade_in(0.20)
	_screen.set_step("Iniciando transição de região...", 0.10)

	# Renderiza 2 frames antes de qualquer processamento mais pesado
	await get_tree().process_frame
	await get_tree().process_frame

	# 3. Limpeza de entidades anteriores e atualização de metadados
	_screen.set_step("Limpando entidades e preparando metadados...", 0.30)
	transition_progress.emit("Preparando metadados", 0.30)
	game_controller.set("current_zone_id", target_zone_id)
	game_controller.set("area_level", maxi(1, zone_def.area_level))

	var unlocked_zones: Array = game_controller.get("unlocked_zones") as Array
	if unlocked_zones != null:
		if not unlocked_zones.has(target_zone_id):
			unlocked_zones.append(target_zone_id)
		if not zone_def.next_zone_id.is_empty() and not unlocked_zones.has(zone_def.next_zone_id):
			unlocked_zones.append(zone_def.next_zone_id)

	# Limpa inimigos da região anterior
	var enemies_root: Node = game_controller.get("enemies_root")
	if enemies_root != null and is_instance_valid(enemies_root):
		for child in enemies_root.get_children():
			child.queue_free()

	if game_controller.has_method("_clear_campaign_props"):
		game_controller.call("_clear_campaign_props")

	var boss_hud = game_controller.get("boss_health_bar_hud")
	if boss_hud != null and is_instance_valid(boss_hud) and boss_hud.has_method("hide_bar"):
		boss_hud.hide_bar()

	await get_tree().process_frame

	# 4. Construção do Terreno Contínuo e Ambientação MegaKit
	_screen.set_step("Construindo terreno e ambientação estilizada...", 0.55)
	transition_progress.emit("Construindo terreno", 0.55)
	var arena_art = game_controller.get("arena_art")
	if arena_art != null and is_instance_valid(arena_art) and arena_art.has_method("rebuild_campaign_zone"):
		arena_art.call("rebuild_campaign_zone", zone_def)

	# Aplica o perfil de iluminação e sombras calibrado (Albion Style)
	var world_light_script = game_controller.get("WorldLightingServiceScript")
	if world_light_script != null and world_light_script.has_method("apply_lighting_profile"):
		world_light_script.call("apply_lighting_profile", game_controller, target_zone_id)

	# Atualiza cabeçalhos da HUD
	var title_lbl = game_controller.get("title_text_label")
	if title_lbl != null and is_instance_valid(title_lbl):
		title_lbl.text = zone_def.title.to_upper()
	var sub_lbl = game_controller.get("subtitle_text_label")
	if sub_lbl != null and is_instance_valid(sub_lbl):
		sub_lbl.text = zone_def.subtitle

	await get_tree().process_frame

	# 5. Pré-aquecimento de Shaders e Pipelines Gráficos
	_screen.set_step("Compilando pipelines gráficos e materiais...", 0.78)
	transition_progress.emit("Compilando shaders", 0.78)
	await PipelineWarmupServiceScript.warm_up_pipelines(get_tree(), target_zone_id)

	# 6. Spawns de Gameplay: Waypoint, Portais, Mercadores ou Packs de Monstros
	_screen.set_step("Posicionando herói, portais e monstros...", 0.90)
	transition_progress.emit("Spawning entidades", 0.90)

	var spawn_pos: Vector3 = (custom_spawn as Vector3) if custom_spawn is Vector3 else zone_def.default_spawn_pos
	if player != null and is_instance_valid(player):
		player.global_position = spawn_pos + Vector3(0.0, 0.05, 0.0)
		player.velocity = Vector3.ZERO
		player.set("chase_direction", Vector3.ZERO)

	# Waypoint presente em todas as regiões
	if game_controller.has_method("_spawn_town_station"):
		game_controller.call("_spawn_town_station", "waypoint", "✦ Waypoint Ancestral", "[Clique] Teleportar entre Zonas", zone_def.waypoint_pos, 0.0)

	var zone_info_lbl = game_controller.get("zone_info_label")
	var status_lbl = game_controller.get("status_label")

	if zone_def.is_safe_town:
		if player != null and is_instance_valid(player):
			player.health = player.max_health
			if game_controller.has_method("_on_health_changed"):
				game_controller.call("_on_health_changed", player.health, player.max_health)
		game_controller.set("enemies_left", 0)

		if zone_info_lbl != null and is_instance_valid(zone_info_lbl):
			zone_info_lbl.text = "Zona: Vila Segura"
		if status_lbl != null and is_instance_valid(status_lbl):
			status_lbl.text = "Vila Segura: aproxime-se dos Mercadores/Baú e clique neles, ou saia pelo Portão Norte!"

		if game_controller.has_method("_spawn_town_station"):
			game_controller.call("_spawn_town_station", "stash", "📦 Baú Pessoal (Stash)", "[Clique] Abrir Baú", Vector3(-5.8, 0.0, -3.5), 25.0)
			game_controller.call("_spawn_town_station", "vendor_physical", "⚒ Ferreiro (Itens Físicos)", "[Clique] Negociar Armas & Armaduras", Vector3(-7.4, 0.0, 3.2), 65.0)
			game_controller.call("_spawn_town_station", "vendor_magic", "🔮 Arcanista (Itens Mágicos)", "[Clique] Negociar Relíquias Mágicas", Vector3(7.4, 0.0, -3.2), -55.0)
			game_controller.call("_spawn_town_station", "identifier_respec", "📜 Sábio (Identificar & Resetar)", "[Clique] Identificar Itens / Resetar Build", Vector3(-2.6, 0.0, -5.2), 15.0)
			game_controller.call("_spawn_town_station", "scribe_crafting", "✒️ Mesa do Escriba (Escrituras Arcanas)", "[Clique] Inscrever & Fabricar Itens", Vector3(2.6, 0.0, -5.2), -15.0)

		if game_controller.has_method("_spawn_zone_gate"):
			game_controller.call("_spawn_zone_gate", zone_def.zone_id, zone_def.next_zone_id, zone_def.next_zone_label, zone_def.next_gate_pos, false)
	else:
		if game_controller.has_method("_spawn_zone_gate"):
			if not zone_def.prev_zone_id.is_empty():
				game_controller.call("_spawn_zone_gate", zone_def.zone_id, zone_def.prev_zone_id, zone_def.prev_zone_label, zone_def.prev_gate_pos, true)
			if not zone_def.next_zone_id.is_empty():
				game_controller.call("_spawn_zone_gate", zone_def.zone_id, zone_def.next_zone_id, zone_def.next_zone_label, zone_def.next_gate_pos, false)

		if game_controller.has_method("_spawn_campaign_packs"):
			game_controller.call("_spawn_campaign_packs", zone_def)

		var enemies_count: int = int(game_controller.get("enemies_left"))
		if zone_info_lbl != null and is_instance_valid(zone_info_lbl):
			zone_info_lbl.text = "Inimigos na Zona: %d" % enemies_count
		if status_lbl != null and is_instance_valid(status_lbl):
			status_lbl.text = "%s — Siga pela estrada, elimine os packs e alcance o Portão Norte!" % zone_def.title

	# 7. Finalização e Liberação Suave do Jogador
	_screen.set_step("Mundo pronto!", 1.00)
	transition_progress.emit("Concluído", 1.00)
	await get_tree().process_frame

	if on_ready.is_valid():
		on_ready.call()

	await _screen.fade_out(0.25)

	if player != null and is_instance_valid(player):
		player.set("input_enabled", true)

	_is_transitioning = false
	transition_completed.emit(target_zone_id)


## ============================================================================
## 3. TRATAMENTO DE ERROS E RECUPERAÇÃO SEGURA
## ============================================================================
func _handle_error(destination: String, error_msg: String) -> void:
	_last_error = error_msg
	push_error("LoadingManager [ERRO]: %s" % error_msg)
	transition_failed.emit(destination, error_msg)

	if _screen != null and _screen.is_active():
		_screen.set_step("Erro no carregamento: %s" % error_msg, 1.0, false)
		# Aguarda brevemente para feedback visual e fade out seguro
		var timer := get_tree().create_timer(1.2)
		await timer.timeout
		await _screen.fade_out(0.20)

	_is_transitioning = false


func get_last_error() -> String:
	return _last_error
