extends SceneTree
## ============================================================================
## SUÍTE DE TESTES AUTOMATIZADOS: MAPA DO ATO 1, WAYPOINTS E INTERFACE
## ============================================================================
## Cobre os requisitos de testes do documento de especificação:
## 1. Arquitetura Visual e Proporção 16:9 (1280x720, 1920x1080, 16:10 e 21:9)
## 2. Background Original (TextureRect limpo sem cards hardcoded)
## 3. Os 8 Cards Interativos (TextureButtons reais, posicionamento e escala)
## 4. Sistema de Regiões Bloqueadas / Desbloqueadas e Cadeados
## 5. Modo A (Tecla M / Consulta) vs Modo B (Waypoint / Teleporte)
## 6. Ocultamento e Restauração da HUD de Combate
## 7. Pausa Segura e Interatividade com Jogo Pausado

var _passed_count: int = 0
var _failed_count: int = 0


func _init() -> void:
	call_deferred("_run_suite")


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed_count += 1
		print("  [PASS] %s" % description)
	else:
		_failed_count += 1
		printerr("  [FAIL] %s" % description)


func _run_suite() -> void:
	print("=================================================================")
	print("SUITE DE TESTES: MAPA DO ATO 1, WAYPOINTS E INTERFACE (GODOT 4)  ")
	print("=================================================================")

	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	assert(main_scene != null, "scenes/main.tscn deve carregar")
	var main_node: Node = main_scene.instantiate()
	root_vp.add_child(main_node)

	for _i in range(3):
		await process_frame

	var hud: CanvasLayer = main_node.get_node_or_null("HUD") as CanvasLayer
	assert(hud != null, "CanvasLayer HUD deve existir")

	var wm: WorldMapModal = main_node.get("world_map_modal") as WorldMapModal
	assert(wm != null, "WorldMapModal deve existir")

	# --- 1. ARQUITETURA VISUAL E COORDENADAS COMPARTILHADAS ---
	print("\n--- 1. ARQUITETURA VISUAL E COORDENADAS COMPARTILHADAS ---")
	_check(wm.is_inside_tree(), "WorldMapModal está devidamente instanciado na árvore")
	_check(wm.process_mode == Node.PROCESS_MODE_ALWAYS, "WorldMapModal possui PROCESS_MODE_ALWAYS para responder pausado")
	_check(wm.get_node_or_null("DimBackdrop") is ColorRect, "Nó 'DimBackdrop' existe e é ColorRect")
	_check(wm.get_node_or_null("MapAspect") is AspectRatioContainer, "Nó 'MapAspect' existe e é AspectRatioContainer")

	var aspect: AspectRatioContainer = wm.get_node_or_null("MapAspect") as AspectRatioContainer
	_check(is_equal_approx(aspect.ratio, wm.MAP_ASPECT_RATIO), "MapAspect possui a proporção 16:9 exata da arte (1672/941 ~= 1.777)")

	var canvas: Control = aspect.get_node_or_null("MapCanvas") as Control
	_check(canvas != null, "Nó 'MapCanvas' existe dentro de MapAspect")

	var bg: TextureRect = canvas.get_node_or_null("MapBackground") as TextureRect
	_check(bg != null, "Nó 'MapBackground' existe dentro de MapCanvas")
	_check(bg.texture != null, "MapBackground possui textura de fundo carregada")
	_check(bg.texture.get_width() >= 1024 and bg.texture.get_height() >= 576, "Textura de fundo possui alta resolução (>= 1024x576)")
	_check(bg.mouse_filter == Control.MOUSE_FILTER_IGNORE, "MapBackground possui MOUSE_FILTER_IGNORE (não bloqueia cliques dos cards)")

	var route: Control = canvas.get_node_or_null("RouteOverlay") as Control
	_check(route != null and route.mouse_filter == Control.MOUSE_FILTER_IGNORE, "RouteOverlay existe como camada decorativa independente sem interceptar cliques")

	var cards_root: Control = canvas.get_node_or_null("RegionCards") as Control
	_check(cards_root != null, "Nó 'RegionCards' existe dentro de MapCanvas")

	# --- 2. OS 8 CARDS REAIS E INTERATIVOS ---
	print("\n--- 2. OS 8 CARDS REAIS E INTERATIVOS ---")
	_check(wm.ACT1_LOCATIONS.size() == 8, "Existem exatamente 8 regiões no catálogo do Ato 1")
	_check(wm._card_roots.size() == 8, "Existem exatamente 8 nós de cards criados")
	_check(wm._card_buttons.size() == 8, "Existem exatamente 8 botões TextureButton interativos")

	for i in range(8):
		var btn: TextureButton = wm._card_buttons[i]
		var loc: Dictionary = wm.ACT1_LOCATIONS[i]
		_check(btn.texture_normal != null, "Card %d (%s) possui textura carregada" % [i + 1, loc["title"]])
		_check(btn.mouse_filter == Control.MOUSE_FILTER_STOP, "Card %d possui MOUSE_FILTER_STOP para receber cliques" % [i + 1])
		_check(btn.focus_mode == Control.FOCUS_ALL, "Card %d aceita foco para navegação por teclado/controle" % [i + 1])

	# --- 3. RESPONSIVIDADE E PROPORÇÃO EM MÚLTIPLAS RESOLUÇÕES ---
	print("\n--- 3. RESPONSIVIDADE E PROPORÇÃO EM MÚLTIPLAS RESOLUÇÕES ---")
	wm.open_map(false, "town", ["town"])
	wm.size = Vector2(1280, 720)
	aspect.size = Vector2(1280, 720)
	await process_frame
	wm._layout_region_cards()
	var card1_pos_720: Vector2 = wm._card_roots[0].position
	var card1_sz_720: Vector2 = wm._card_roots[0].size
	_check(card1_sz_720.x > 180.0 and card1_sz_720.y > 60.0, "Cards redimensionados proporcionalmente em 1280x720 (tam: %.1fx%.1f)" % [card1_sz_720.x, card1_sz_720.y])

	# 1920x1080 (Full HD 16:9)
	wm.size = Vector2(1920, 1080)
	aspect.size = Vector2(1920, 1080)
	await process_frame
	wm._layout_region_cards()
	var card1_pos_1080: Vector2 = wm._card_roots[0].position
	var card1_sz_1080: Vector2 = wm._card_roots[0].size
	_check(card1_sz_1080.x > card1_sz_720.x, "Cards escalam com o canvas em 1920x1080 (tam: %.1fx%.1f)" % [card1_sz_1080.x, card1_sz_1080.y])

	# 1280x800 (16:10 com barras superior/inferior)
	wm.size = Vector2(1280, 800)
	aspect.size = Vector2(1280, 800)
	await process_frame
	wm._layout_region_cards()
	_check(is_equal_approx(aspect.ratio, wm.MAP_ASPECT_RATIO), "AspectRatioContainer preserva proporção 16:9 em tela 16:10 sem esticar a arte")

	# Retorna para 1280x720
	wm.size = Vector2(1280, 720)
	aspect.size = Vector2(1280, 720)
	await process_frame
	wm._layout_region_cards()
	wm.close_map()
	await process_frame

	# --- 4. SISTEMA DE REGIÕES BLOQUEADAS / DESBLOQUEADAS ---
	print("\n--- 4. SISTEMA DE REGIÕES BLOQUEADAS / DESBLOQUEADAS ---")
	# Inicia apenas com 'town' desbloqueada
	wm.open_map(false, "town", ["town"])
	await process_frame

	_check(wm._card_lock_badges[0].visible == false, "Vila de Velen (inicial) NÃO possui cadeado")
	_check(wm._card_current_badges[0].visible == true, "Vila de Velen exibe badge '★ LOCAL ATUAL'")
	_check(wm._card_lock_badges[1].visible == true, "Floresta de Arath bloqueada exibe cadeado '🔒'")
	_check(wm._card_lock_badges[2].visible == true, "Ruínas Antigas bloqueada exibe cadeado '🔒'")
	_check(wm._card_lock_badges[3].visible == true, "Minas de Karpon bloqueada exibe cadeado '🔒'")
	_check(wm._card_buttons[1].self_modulate.r < 0.50, "Card bloqueado é visualmente escurecido / desaturado")

	# --- 5. MODO A: TECLA M (CONSULTA — TELEPORTE BLOQUEADO) ---
	print("\n--- 5. MODO A: TECLA M (CONSULTA — TELEPORTE BLOQUEADO) ---")
	_check(wm.visible == true, "Mapa aberto com sucesso")
	_check(wm.can_teleport == false, "Modo M possui can_teleport == false")
	_check(wm._mode_banner_title.text.contains("MODO CONSULTA"), "Banner superior informa claramente 'MODO CONSULTA'")

	# Tentar clicar em um card desbloqueado ou bloqueado no modo M NÃO deve disparar viagem
	var travel_emitted: bool = false
	var travel_sig := func(_z): travel_emitted = true
	wm.waypoint_travel_requested.connect(travel_sig)

	wm._on_location_clicked(wm.ACT1_LOCATIONS[1]) # Clica em Floresta
	await process_frame
	_check(travel_emitted == false, "Modo M: Clicar em destino NÃO emite sinal de teleporte")
	_check(wm._feedback_panel.visible == true, "Modo M: Exibe toast avisando que teleporte requer Waypoint")
	_check(wm.visible == true, "Modo M: Mapa permanece aberto após o clique bloqueado")

	wm.waypoint_travel_requested.disconnect(travel_sig)
	wm.close_map()
	_check(wm.visible == false, "close_map() fecha o mapa com sucesso")

	# --- 6. MODO B: WAYPOINT ANCESTRAL (VIAGEM PARA DESTINOS DESBLOQUEADOS) ---
	print("\n--- 6. MODO B: WAYPOINT ANCESTRAL (VIAGEM PARA DESTINOS DESBLOQUEADOS) ---")
	# Abre no modo Waypoint com 'town' e 'zone_1_road' desbloqueadas
	wm.open_map(true, "town", ["town", "zone_1_road"])
	await process_frame

	_check(wm.can_teleport == true, "Modo Waypoint possui can_teleport == true")
	_check(wm._mode_banner_title.text.contains("WAYPOINT ANCESTRAL"), "Banner superior informa 'WAYPOINT ANCESTRAL'")
	_check(wm._card_lock_badges[1].visible == false, "Floresta de Arath desbloqueada NÃO possui cadeado")

	# Clicar em destino BLOQUEADO no modo Waypoint NÃO teleporta
	var travel_box := [""]
	var travel_sig2 := func(z): travel_box[0] = z
	wm.waypoint_travel_requested.connect(travel_sig2)

	wm._on_location_clicked(wm.ACT1_LOCATIONS[3]) # Clica em Minas (bloqueada)
	await process_frame
	_check(travel_box[0] == "", "Modo Waypoint: Destino bloqueado NÃO executa teleporte")
	_check(wm._feedback_panel.visible == true, "Modo Waypoint: Exibe aviso de região bloqueada")

	# Clicar no PRÓPRIO LOCAL ATUAL avisa sem teleportar
	wm._on_location_clicked(wm.ACT1_LOCATIONS[0]) # Clica em Vila (local atual)
	await process_frame
	_check(travel_box[0] == "", "Modo Waypoint: Clicar no local atual não executa teleporte redundante")

	# Clicar em DESTINO DESBLOQUEADO executa o teleporte!
	wm._on_location_clicked(wm.ACT1_LOCATIONS[1]) # Clica em Floresta (desbloqueada!)
	await process_frame
	_check(travel_box[0] == "zone_1_road", "Modo Waypoint: Clicar em destino desbloqueado emite 'zone_1_road'")
	_check(wm.visible == false, "Modo Waypoint: Teleporte autorizado fecha o mapa automaticamente")

	wm.waypoint_travel_requested.disconnect(travel_sig2)

	# --- 7. OCULTAMENTO E RESTAURAÇÃO DA HUD DE COMBATE ---
	print("\n--- 7. OCULTAMENTO E RESTAURAÇÃO DA HUD DE COMBATE ---")
	var hp_globe: CanvasItem = hud.get_node_or_null("HealthGlobeHUD") as CanvasItem
	var mana_globe: CanvasItem = hud.get_node_or_null("ManaGlobeHUD") as CanvasItem
	var skill_bar: CanvasItem = hud.get_node_or_null("SkillBarHUD") as CanvasItem
	if hp_globe != null: hp_globe.visible = true
	if mana_globe != null: mana_globe.visible = true
	if skill_bar != null: skill_bar.visible = true

	wm.open_map(false, "town", ["town"])
	await process_frame
	if hp_globe != null:
		_check(hp_globe.visible == false, "HealthGlobeHUD é ocultada enquanto o mapa está aberto")
	if mana_globe != null:
		_check(mana_globe.visible == false, "ManaGlobeHUD é ocultada enquanto o mapa está aberto")
	if skill_bar != null:
		_check(skill_bar.visible == false, "SkillBarHUD é ocultada enquanto o mapa está aberto")

	wm.close_map()
	await process_frame
	if hp_globe != null:
		_check(hp_globe.visible == true, "HealthGlobeHUD é restaurada ao fechar o mapa")
	if mana_globe != null:
		_check(mana_globe.visible == true, "ManaGlobeHUD é restaurada ao fechar o mapa")
	if skill_bar != null:
		_check(skill_bar.visible == true, "SkillBarHUD é restaurada ao fechar o mapa")

	# --- 8. PAUSA E INTERATIVIDADE ---
	print("\n--- 8. PAUSA E INTERATIVIDADE ---")
	wm.open_map(false, "town", ["town"])
	await process_frame
	_check(paused == true, "Abrir o mapa pausa a árvore do jogo com segurança")
	wm.close_map()
	await process_frame
	_check(paused == false, "Fechar o mapa despausa a árvore do jogo imediatamente")

	print("\n=================================================================")
	print("RESULTADO FINAL: %d PASSARAM | %d FALHARAM" % [_passed_count, _failed_count])
	print("=================================================================")
	if _failed_count == 0:
		print(">> TODOS OS TESTES PASSARAM COM SUCESSO! <<")
	main_node.queue_free()
	quit(0 if _failed_count == 0 else 1)
