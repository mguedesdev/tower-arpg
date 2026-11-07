extends SceneTree
## Teste Automatizado de Verificação da Separação dos Projetos (ARPG vs Infinity Tower + Launcher).
## Executar: Godot_v4.7.2-stable_win64_console.exe --headless --path "c:\Users\mathh\OneDrive\Documents\jogo" -s tests/test_project_separation_suite.gd

const LAUNCHER_SCENE: PackedScene = preload("res://scenes/launcher.tscn")
const ARPG_SCENE: PackedScene = preload("res://scenes/arpg/arpg_game.tscn")
const TOWER_SCENE: PackedScene = preload("res://scenes/tower/tower_game.tscn")

const LAUNCHER_SCRIPT: Script = preload("res://scripts/launcher.gd")
const ARPG_SCRIPT: Script = preload("res://scripts/arpg/arpg_game.gd")
const TOWER_SCRIPT: Script = preload("res://scripts/tower/tower_game.gd")

var _passed: int = 0
var _failed: int = 0


func _initialize() -> void:
	call_deferred("_run_all")


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("[OK] " + label)
	else:
		_failed += 1
		push_error("[FALHOU] " + label)


func _run_all() -> void:
	print("=== INICIANDO SUITE DE TESTES: SEPARAÇÃO DOS PROJETOS (ARPG & TOWER) ===")
	_test_launcher()
	_test_arpg_game_isolation()
	_test_tower_game_isolation()

	print("=== RESULTADO DA SEPARAÇÃO: %d PASSARAM | %d FALHARAM ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_launcher() -> void:
	var launcher = LAUNCHER_SCENE.instantiate()
	root.add_child(launcher)
	_check(launcher != null and launcher.get_script() == LAUNCHER_SCRIPT, "1. Launcher instancia corretamente como GameLauncherController")
	_check(launcher.btn_arpg != null, "2. Botão 'INICIAR MODO ARPG' presente no Launcher")
	_check(launcher.btn_tower != null, "3. Botão 'INICIAR INFINITY TOWER' presente no Launcher")
	launcher.queue_free()


func _test_arpg_game_isolation() -> void:
	var arpg = ARPG_SCENE.instantiate()
	root.add_child(arpg)
	_check(arpg != null and arpg.get_script() == ARPG_SCRIPT, "4. ARPGGame instancia exclusivamente como ARPGGameController")
	_check(arpg.current_zone_id == "town", "5. ARPG inicia diretamente na Vila Segura (town)")
	_check(arpg.backpack != null and arpg.equipment != null, "6. ARPG possui Mochila em grade espacial e Paperdoll de equipamentos")
	_check(arpg.skill_bar_hud != null and arpg.skill_bar_hud.visible, "7. ARPG exibe barra de skills ativas (LMB/RMB/1-4)")
	_check(arpg.get("level_up_modal") == null, "8. ARPG não possui nem instancia cartas de sobrevivente")
	_check(arpg.player.skill_controller != null and arpg.player.skill_controller.enabled, "9. Player do ARPG opera com PlayerSkillController ativo")

	# Teste de acoplamento lado a lado (Baú + Inventário) e economia dos NPCs
	arpg._on_town_station_interacted("stash", "Baú Pessoal")
	arpg._relayout_open_modals()
	_check(arpg.town_npc_modal.visible and arpg.inventory_modal.visible, "9a. Abrir Baú abre automaticamente o Inventário lado a lado")
	var first_item = arpg.backpack.items[0]
	arpg._on_inventory_context_action(first_item)
	_check(arpg.stash_grid.items.has(first_item), "9b. Clique direito na Mochila com Baú aberto guarda o item no Grid do Baú")

	arpg._on_town_station_interacted("vendor_physical", "Ferreiro")
	arpg._relayout_open_modals()
	var prev_gold: int = arpg.gold
	var sell_item = arpg.backpack.items[0]
	var expected_sell_val: int = sell_item.get_sell_value()
	arpg._on_inventory_context_action(sell_item)
	_check(arpg.gold == prev_gold + expected_sell_val, "9c. Clique direito na Mochila com Mercador aberto vende o item por Ouro")
	_check(arpg.town_npc_modal._buyback_items.size() == 1 and arpg.town_npc_modal._buyback_items[0]["price"] == expected_sell_val, "9d. Item vendido aparece na aba Recomprar exatamente pelo mesmo valor da venda")
	arpg.town_npc_modal._attempt_buyback_item(arpg.town_npc_modal._buyback_items[0])
	_check(arpg.backpack.items.has(sell_item) and arpg.gold == prev_gold and arpg.town_npc_modal._buyback_items.is_empty(), "9e. Recomprar devolve o item à Mochila pelo exato valor de venda")

	arpg.queue_free()


func _test_tower_game_isolation() -> void:
	var tower = TOWER_SCENE.instantiate()
	root.add_child(tower)
	_check(tower != null and tower.get_script() == TOWER_SCRIPT, "10. TowerGame instancia exclusivamente como TowerGameController")
	_check(tower.in_lobby, "11. Infinity Tower inicia no Altar do Santuário (Lobby)")
	_check(tower.level_up_modal != null, "12. Infinity Tower possui modal de 3 cartas de upgrade por wave")
	_check(tower.talent_tree_modal != null, "13. Infinity Tower possui árvore permanente de talentos e essência")
	_check(tower.lobby_hud != null and tower.lobby_hud.visible, "14. Infinity Tower exibe HUD do Altar no lobby")
	tower.queue_free()
