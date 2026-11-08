extends SceneTree
## SUÍTE DE TESTES AUTOMATIZADOS: INTERAÇÃO POR CLIQUE DO MOUSE & HOVER COM BORDA GROSSA
## Cobre:
## 1. Criação e ancoragem das placas 2D interativas (HUD) para NPCs, Baú e Waypoint.
## 2. Borda grossa (3px) no hover ("coloque uma borda grossa e talz a gente vai saber q ta com o mouse em cima").
## 3. Cursor em formato de mãozinha (CURSOR_POINTING_HAND) e filtro MOUSE_FILTER_STOP.
## 4. Clique do mouse direto (LMB) para interagir, prevenindo disparo de skills/ataques.
## 5. Movimento automático ao clicar de longe e abertura ao aproximar.
## 6. Portais de Zona (ZonePortal3D) com hover e clique idênticos.

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	call_deferred("_run_suite")


func _check(condition: bool, description: String) -> void:
	if condition:
		_passed += 1
		print("  [PASS] %s" % description)
	else:
		_failed += 1
		printerr("  [FAIL] %s" % description)


func _run_suite() -> void:
	print("\n=================================================================")
	print("SUÍTE DE QA: INTERAÇÃO COM NPCS, WAYPOINT E PORTAIS POR CLIQUE (GODOT 4)")
	print("=================================================================\n")

	# Prepara a cena de teste com CanvasLayer HUD e Camera3D
	var root_node := Node3D.new()
	root_node.name = "TestRoot"
	root.add_child(root_node)

	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUD"
	root_node.add_child(hud_layer)

	var camera := Camera3D.new()
	camera.name = "Camera3D"
	root_node.add_child(camera)
	camera.position = Vector3(0.0, 10.0, 10.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)

	await process_frame

	# ---------------------------------------------------------------
	# 1. ESTRUTURA E PLACA 2D INTERATIVA DO WAYPOINT E NPCS
	# ---------------------------------------------------------------
	print("--- 1. ESTRUTURA E PLACA 2D INTERATIVA DO WAYPOINT E NPCS ---")
	var waypoint := TownInteractable3D.new()
	root_node.add_child(waypoint)
	waypoint.configure("waypoint", "Waypoint Ancestral", "[Clique para Viajar]", Vector3(4.0, 0.0, 2.0), 0.0)
	await process_frame

	_check(waypoint._plate_panel != null, "Placa 2D do Waypoint criada no CanvasLayer HUD")
	_check(waypoint._plate_panel.is_inside_tree(), "Placa 2D do Waypoint inserida ativamente na árvore de cena")
	_check(waypoint._plate_panel.mouse_filter == Control.MOUSE_FILTER_STOP, "Placa possui MOUSE_FILTER_STOP para interceptar cliques antes da hotbar")
	_check(waypoint._plate_panel.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND, "Cursor configurado como mãozinha apontadora (CURSOR_POINTING_HAND)")
	_check(waypoint._plate_title_label.text.contains("Waypoint Ancestral"), "Título da placa exibe 'Waypoint Ancestral'")
	_check(waypoint._plate_prompt_label.text == "[Clique para Viajar]", "Prompt da placa exibe '[Clique para Viajar]'")

	# ---------------------------------------------------------------
	# 2. FEEDBACK VISUAL NO HOVER (BORDA GROSSA DE 3PX E BRILHO)
	# ---------------------------------------------------------------
	print("\n--- 2. FEEDBACK VISUAL NO HOVER (BORDA GROSSA DE 3PX E BRILHO) ---")
	_check(waypoint._plate_style.get_border_width(SIDE_TOP) == 1, "Estado normal possui borda padrão fina (1px)")
	_check(not waypoint._is_hovered, "Estado inicial _is_hovered é false")
	_check(TownInteractable3D.get_hovered_station() == null, "Nenhuma estação em hover inicialmente")

	# Simula mouse passando por cima (mouse_entered)
	waypoint._on_plate_mouse_entered()
	_check(waypoint._is_hovered, "Passar o mouse ativa _is_hovered = true")
	_check(TownInteractable3D.get_hovered_station() == waypoint, "TownInteractable3D.get_hovered_station() retorna a estação atual")
	_check(TownInteractable3D.is_any_station_hovered(), "TownInteractable3D.is_any_station_hovered() é true")
	_check(waypoint._plate_style.get_border_width(SIDE_TOP) == 3, "Borda superior expande para borda grossa (3px) no hover")
	_check(waypoint._plate_style.get_border_width(SIDE_BOTTOM) == 3, "Borda inferior expande para borda grossa (3px) no hover")
	_check(waypoint._plate_style.get_border_width(SIDE_LEFT) == 3, "Borda esquerda expande para borda grossa (3px) no hover")
	_check(waypoint._plate_style.get_border_width(SIDE_RIGHT) == 3, "Borda direita expande para borda grossa (3px) no hover")
	_check(waypoint._plate_panel.z_index == 16, "Placa sobe para z_index 16 em destaque absoluto")
	_check(waypoint._plate_title_label.get_theme_color("font_color") == Color.WHITE, "Título ilumina para branco nítido no hover")

	# Simula mouse saindo (mouse_exited)
	waypoint._on_plate_mouse_exited()
	_check(not waypoint._is_hovered, "Tirar o mouse desativa _is_hovered")
	_check(TownInteractable3D.get_hovered_station() == null, "Estação em hover é limpa")
	_check(waypoint._plate_style.get_border_width(SIDE_TOP) == 1, "Borda retorna para 1px suave quando o mouse sai")
	_check(waypoint._plate_panel.z_index == 4, "z_index retorna ao padrão de repouso (4)")

	# ---------------------------------------------------------------
	# 3. INTERAÇÃO POR CLIQUE DIRETO COM O MOUSE (LMB)
	# ---------------------------------------------------------------
	print("\n--- 3. INTERAÇÃO POR CLIQUE DIRETO COM O MOUSE (LMB) ---")
	var player_scene: PackedScene = load("res://scenes/player.tscn")
	var player_dummy: Node3D = player_scene.instantiate() as Node3D
	player_dummy.name = "player"
	player_dummy.position = Vector3(4.0, 0.0, 2.5) # Apenas 0.5m do Waypoint
	root_node.add_child(player_dummy)
	await process_frame

	var triggered_box: Array[String] = [""]
	var on_interacted := func(station_id: String, _title: String) -> void:
		triggered_box[0] = station_id
	waypoint.interaction_requested.connect(on_interacted)

	# Simula clique do mouse esquerdo na placa
	var click_event := InputEventMouseButton.new()
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	waypoint._on_plate_gui_input(click_event)

	_check(triggered_box[0] == "waypoint", "Clique esquerdo (LMB) na placa do Waypoint dispara interação imediata quando próximo")
	triggered_box[0] = ""

	# ---------------------------------------------------------------
	# 4. CLIQUE À DISTÂNCIA E NAVEGAÇÃO AUTOMÁTICA
	# ---------------------------------------------------------------
	print("\n--- 4. CLIQUE À DISTÂNCIA E NAVEGAÇÃO AUTOMÁTICA ---")
	player_dummy.position = Vector3(15.0, 0.0, 2.0) # 11 metros de distância
	player_dummy.chase_direction = Vector3.ZERO

	waypoint._on_plate_gui_input(click_event)
	_check(triggered_box[0] == "", "Clicar de longe NÃO dispara interação imediatamente")
	var chase: Vector3 = player_dummy.chase_direction
	_check(chase.length() > 0.0, "Clicar de longe ativa movimentação do jogador em direção à estação (chase_direction)")
	_check(chase.x < 0.0, "Direção de aproximação aponta corretamente para a estação (-X)")

	# Simula chegada do jogador à estação
	player_dummy.position = Vector3(4.5, 0.0, 2.0)
	waypoint._process(0.016)
	_check(triggered_box[0] == "waypoint", "Chegar ao alcance abre a janela do Waypoint automaticamente")
	_check(player_dummy.chase_direction == Vector3.ZERO, "Jogador para de andar ao chegar à estação")
	triggered_box[0] = ""

	# ---------------------------------------------------------------
	# 5. DIVERSIDADE DE ESTAÇÕES DA VILA (BAÚ, FERREIRO, ARCANISTA)
	# ---------------------------------------------------------------
	print("\n--- 5. DIVERSIDADE DE ESTAÇÕES DA VILA (BAÚ, FERREIRO, ARCANISTA) ---")
	var stash := TownInteractable3D.new()
	root_node.add_child(stash)
	stash.configure("stash", "Baú Pessoal", "[Clique] Abrir Baú", Vector3(-4.0, 0.0, 0.0), 0.0)
	await process_frame

	_check(stash._plate_title_label.text.contains("Baú Pessoal"), "Placa do Baú Pessoal possui ícone e título corretos")
	stash._on_plate_mouse_entered()
	_check(stash._plate_style.get_border_width(SIDE_TOP) == 3, "Baú Pessoal ganha borda grossa (3px) no hover")
	stash._on_plate_mouse_exited()
	_check(stash._plate_style.get_border_width(SIDE_TOP) == 1, "Baú Pessoal retorna à borda de 1px")

	var blacksmith := TownInteractable3D.new()
	root_node.add_child(blacksmith)
	blacksmith.configure("vendor_physical", "Ferreiro", "[Clique] Comerciar", Vector3(-2.0, 0.0, 4.0), 0.0)
	await process_frame

	_check(blacksmith._plate_title_label.text.contains("⚒"), "Ferreiro exibe martelos ⚒ no título da placa")
	blacksmith._on_plate_mouse_entered()
	_check(blacksmith._plate_style.get_border_width(SIDE_TOP) == 3, "Ferreiro ganha borda grossa (3px) no hover")
	blacksmith._on_plate_mouse_exited()

	# ---------------------------------------------------------------
	# 6. PORTAIS DE ZONA (ZONEPORTAL3D) COM PLACA E BORDA NO HOVER
	# ---------------------------------------------------------------
	print("\n--- 6. PORTAIS DE ZONA (ZONEPORTAL3D) COM PLACA E BORDA NO HOVER ---")
	var portal := ZonePortal3D.new()
	root_node.add_child(portal)
	portal.configure("town", "zone_1_road", "Estrada Profanada (Nv. 1)", Vector3(0.0, 0.0, 15.0), false)
	await process_frame

	_check(portal._plate_panel != null and portal._plate_panel.is_inside_tree(), "Portal de Zona cria placa 2D interativa na HUD")
	_check(portal._plate_title_label.text.contains("Estrada Profanada"), "Título do portal exibe destino 'Estrada Profanada'")
	_check(portal._plate_style.get_border_width(SIDE_TOP) == 1, "Portal possui borda normal fina (1px)")

	portal._on_portal_mouse_entered()
	_check(portal._is_hovered, "Passar o mouse no portal ativa hover")
	_check(ZonePortal3D.get_hovered_portal() == portal, "ZonePortal3D.get_hovered_portal() retorna o portal")
	_check(portal._plate_style.get_border_width(SIDE_TOP) == 3, "Portal ganha borda grossa (3px) no hover")

	portal._on_portal_mouse_exited()
	_check(not portal._is_hovered, "Tirar o mouse desativa hover do portal")
	_check(ZonePortal3D.get_hovered_portal() == null, "Portal em hover é limpo")
	_check(portal._plate_style.get_border_width(SIDE_TOP) == 1, "Portal retorna para borda de 1px")

	# Limpeza
	root_node.queue_free()

	# ---------------------------------------------------------------
	# RESULTADO FINAL
	# ---------------------------------------------------------------
	print("\n=================================================================")
	print("RESULTADO QA INTERAÇÃO E HOVER: %d PASSARAM | %d FALHARAM" % [_passed, _failed])
	print("=================================================================\n")

	if _failed == 0:
		print(">> TODOS OS REQUISITOS DE HOVER COM BORDA GROSSA E CLIQUE FORAM APROVADOS! <<\n")
		quit(0)
	else:
		push_error(">> FALHAS ENCONTRADAS NO QA DE INTERAÇÃO <<")
		quit(1)
