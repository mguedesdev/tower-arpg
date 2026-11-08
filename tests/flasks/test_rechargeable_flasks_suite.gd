extends SceneTree
## ============================================================================
## SUÍTE DE QA: SISTEMA DE FRASCOS RECARREGÁVEIS (DOC 08 / POE 2 STYLE)
## ============================================================================

const FlaskServiceScript = preload("res://core/progression/flask_service.gd")
const HealthGlobeHUDScript = preload("res://game/ui/campaign/health_globe_hud.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0


func _init() -> void:
	print("\n=================================================================")
	print("SUÍTE DE QA: FRASCOS RECARREGÁVEIS & COMBATE (DOC 08 ARPG GODOT 4)")
	print("=================================================================\n")
	_run_all_tests()
	_print_summary()
	quit(0 if failed_tests == 0 else 1)


func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % test_name)


func _run_all_tests() -> void:
	ItemDatabase.ensure_initialized()

	_test_01_catalog_and_assets()
	_test_02_flask_instance_charges_and_uses()
	_test_03_kill_charge_rewards_by_rank()
	_test_04_dual_flask_independence()
	_test_05_continuous_recovery_hot_mot()
	_test_06_hud_slots_and_restrictions()
	_test_07_well_and_checkpoint_refill()
	_test_08_serialization_and_save()
	_test_09_tooltips_and_formatting()


func _test_01_catalog_and_assets() -> void:
	print("--- 1. CATÁLOGO DAS 6 BASES E ASSETS DE ARTE (DOC 08 SEÇÃO 3) ---")

	var bases: Array[Dictionary] = [
		{"id": "flask_life_small", "res": "life", "lvl": 1, "rec": 70.0, "dur": 3.0, "cap": 60, "cost": 10, "uses": 6},
		{"id": "flask_life_medium", "res": "life", "lvl": 8, "rec": 160.0, "dur": 4.0, "cap": 70, "cost": 10, "uses": 7},
		{"id": "flask_life_large", "res": "life", "lvl": 18, "rec": 320.0, "dur": 4.0, "cap": 80, "cost": 10, "uses": 8},
		{"id": "flask_mana_small", "res": "mana", "lvl": 1, "rec": 55.0, "dur": 2.5, "cap": 60, "cost": 10, "uses": 6},
		{"id": "flask_mana_medium", "res": "mana", "lvl": 8, "rec": 125.0, "dur": 3.0, "cap": 70, "cost": 10, "uses": 7},
		{"id": "flask_mana_large", "res": "mana", "lvl": 18, "rec": 240.0, "dur": 3.5, "cap": 80, "cost": 10, "uses": 8},
	]

	for b in bases:
		var id: String = String(b["id"])
		var def: ItemDefinition = ItemDatabase.get_definition(id)
		assert_test(def != null, "Item-base '%s' registrado no ItemDatabase" % id)
		if def != null:
			assert_test(def.is_flask == true, "'%s' possui flag is_flask = true" % id)
			assert_test(def.flask_resource_type == String(b["res"]), "'%s' tipo de recurso é %s" % [id, b["res"]])
			assert_test(def.req_level == int(b["lvl"]), "'%s' requer nível %d" % [id, b["lvl"]])
			assert_test(is_equal_approx(def.flask_recovery_amount, float(b["rec"])), "'%s' recuperação é %.1f" % [id, b["rec"]])
			assert_test(is_equal_approx(def.flask_recovery_duration, float(b["dur"])), "'%s' duração é %.1fs" % [id, b["dur"]])
			assert_test(def.flask_capacity == int(b["cap"]), "'%s' capacidade é %d" % [id, b["cap"]])
			assert_test(def.flask_cost_per_use == int(b["cost"]), "'%s' custo por uso é %d" % [id, b["cost"]])
			assert_test(def.grid_size == Vector2i(1, 1), "'%s' ocupa 1x1 no inventário espacial" % id)

			# Carregamento de textura
			var tex: Texture2D = ItemIconFactory.get_icon(def)
			assert_test(tex != null, "'%s' ícone PNG carregado com sucesso pela fábrica" % id)


func _test_02_flask_instance_charges_and_uses() -> void:
	print("\n--- 2. CARGAS, CONSUMO NÃO-DESTRUTIVO E USOS DISPONÍVEIS ---")

	var def_life: ItemDefinition = ItemDatabase.get_definition("flask_life_small")
	var inst := ItemInstance.new(def_life)

	assert_test(inst.is_flask() == true, "Instância reconhece ser um frasco")
	assert_test(inst.get_flask_capacity() == 60, "Capacidade máxima inicial é 60")
	assert_test(inst.get_current_charges() == 60, "Inicia 100% carregado com 60 cargas")
	assert_test(inst.get_available_uses() == 6, "Usos disponíveis cheios: floor(60 / 10) = 6")

	# Consome 1 uso
	var consumed1: bool = inst.consume_use()
	assert_test(consumed1 == true, "Primeiro uso consumido com sucesso")
	assert_test(inst.get_current_charges() == 50, "Cargas restantes: 50 / 60")
	assert_test(inst.get_available_uses() == 5, "Usos disponíveis restantes: 5")

	# Simula cargas fracionadas/intermediárias (ex: 37 cargas)
	inst.current_charges = 37
	assert_test(inst.get_available_uses() == 3, "37 cargas com custo 10 = 3 usos disponíveis")

	# Consome 3 vezes
	assert_test(inst.consume_use() == true, "Uso 1/3 com 37 cargas -> 27")
	assert_test(inst.consume_use() == true, "Uso 2/3 com 27 cargas -> 17")
	assert_test(inst.consume_use() == true, "Uso 3/3 com 17 cargas -> 7")
	assert_test(inst.get_current_charges() == 7, "Cargas residuais: 7 / 60")
	assert_test(inst.get_available_uses() == 0, "Sem usos inteiros disponíveis (7 < 10)")

	# Tentativa de consumir com cargas insuficientes deve falhar sem efeito colateral
	var failed_use: bool = inst.consume_use()
	assert_test(failed_use == false, "Consumo rejeitado com segurança quando cargas < custo")
	assert_test(inst.get_current_charges() == 7, "Cargas inalteradas após falha")


func _test_03_kill_charge_rewards_by_rank() -> void:
	print("\n--- 3. REABASTECIMENTO POR ABATES CONFORME CLASSIFICAÇÃO (DOC 08 SEÇÃO 5.2) ---")

	var def_life: ItemDefinition = ItemDatabase.get_definition("flask_life_small")
	var flask := ItemInstance.new(def_life)
	flask.current_charges = 0 # Esvazia para testar acréscimos

	# Normal (Branco): +1
	var g_norm: int = FlaskServiceScript.apply_kill_charges_to_flask(flask, 0)
	assert_test(g_norm == 1, "Abate de monstro Normal concede exatamente +1 carga")
	assert_test(flask.get_current_charges() == 1, "Frasco agora tem 1 carga")

	# Mágico (Azul): +3
	var g_mag: int = FlaskServiceScript.apply_kill_charges_to_flask(flask, 1)
	assert_test(g_mag == 3, "Abate de monstro Mágico concede exatamente +3 cargas")
	assert_test(flask.get_current_charges() == 4, "Frasco agora tem 4 cargas (1 + 3)")

	# Raro (Amarelo): +7
	var g_rare: int = FlaskServiceScript.apply_kill_charges_to_flask(flask, 2)
	assert_test(g_rare == 7, "Abate de monstro Raro concede exatamente +7 cargas")
	assert_test(flask.get_current_charges() == 11, "Frasco agora tem 11 cargas (4 + 7)")
	assert_test(flask.get_available_uses() == 1, "Alcançou 1 uso disponível (11 >= 10)")

	# Herói / Elite (Roxo): +10
	var g_elite: int = FlaskServiceScript.apply_kill_charges_to_flask(flask, 3)
	assert_test(g_elite == 10, "Abate de monstro Herói/Elite concede exatamente +10 cargas")
	assert_test(flask.get_current_charges() == 21, "Frasco agora tem 21 cargas (11 + 10)")

	# Chefe (Vermelho): +20
	var g_boss: int = FlaskServiceScript.apply_kill_charges_to_flask(flask, 4)
	assert_test(g_boss == 20, "Abate de Chefe concede exatamente +20 cargas")
	assert_test(flask.get_current_charges() == 41, "Frasco agora tem 41 cargas (21 + 20)")

	# Teto de capacidade (clamp)
	flask.current_charges = 58
	var g_overflow: int = FlaskServiceScript.apply_kill_charges_to_flask(flask, 2) # +7
	assert_test(g_overflow == 2, "Ganho limitado pelo teto de capacidade (ganhou +2 de +7)")
	assert_test(flask.get_current_charges() == 60, "Capacidade travada estritamente no teto (60/60)")


func _test_04_dual_flask_independence() -> void:
	print("\n--- 4. INDEPENDÊNCIA MÚTUA DOS FRASCOS EQUIPADOS (DOC 08 SEÇÃO 5.1) ---")

	var hud := HealthGlobeHUDScript.new() as HealthGlobeHUD
	var f_life := ItemInstance.new(ItemDatabase.get_definition("flask_life_small"))
	var f_mana := ItemInstance.new(ItemDatabase.get_definition("flask_mana_small"))

	f_life.current_charges = 20
	f_mana.current_charges = 15

	hud.equip_flask(0, f_life)
	hud.equip_flask(1, f_mana)

	# Abate de um monstro Raro (+7 cargas)
	hud.on_enemy_killed(2)

	assert_test(f_life.get_current_charges() == 27, "Frasco de Vida recebeu +7 integralmente (20 -> 27)")
	assert_test(f_mana.get_current_charges() == 22, "Frasco de Mana recebeu +7 integralmente (15 -> 22)")
	assert_test(f_life.get_available_uses() == 2, "Vida possui 2 usos (27 cargas)")
	assert_test(f_mana.get_available_uses() == 2, "Mana possui 2 usos (22 cargas)")

	hud.queue_free()


func _test_05_continuous_recovery_hot_mot() -> void:
	print("\n--- 5. RECUPERAÇÃO CONTÍNUA (HOT / MOT) E REGRAS TEMPORAIS ---")

	var svc: RefCounted = FlaskServiceScript.new()

	# Frasco de Vida Pequeno: 70 HP em 3.0s = ~23.33 HP/s
	svc.start_recovery("life", 70.0, 3.0)
	assert_test(svc.active_recoveries["life"]["remaining_time"] == 3.0, "HoT de Vida iniciado com 3.0s")
	assert_test(is_equal_approx(svc.active_recoveries["life"]["rate"], 70.0 / 3.0), "Taxa de restauração calculada com precisão")

	# Avança 1 segundo (vida 30 / 100)
	var gains1: Dictionary = svc.update_recovery(1.0, 30.0, 100.0, 50.0, 100.0)
	var hp_gain1: float = float(gains1.get("life", 0.0))
	assert_test(is_equal_approx(hp_gain1, 70.0 / 3.0), "Avanço de 1s concedeu ~23.33 HP")

	# Regra de não-acumulação (Doc 08 Seção 4): nova ativação reinicia e descarta o restante
	svc.start_recovery("life", 70.0, 3.0)
	assert_test(svc.active_recoveries["life"]["remaining_time"] == 3.0, "Segunda ativação reiniciou a duração para 3.0s")
	assert_test(is_equal_approx(svc.active_recoveries["life"]["remaining_amount"], 70.0), "Descartou restante anterior e restaurou quota de 70")

	# Coexistência de Vida e Mana simultaneamente
	svc.start_recovery("mana", 55.0, 2.5)
	var gains2: Dictionary = svc.update_recovery(0.5, 50.0, 100.0, 20.0, 100.0)
	assert_test(float(gains2.get("life", 0.0)) > 0.0, "Vida regenerando em paralelo")
	assert_test(float(gains2.get("mana", 0.0)) > 0.0, "Mana regenerando em paralelo")

	# Término antecipado ao encher recurso (anti-cura futura, Seção 6)
	svc.start_recovery("life", 70.0, 3.0)
	var gains_full: Dictionary = svc.update_recovery(0.5, 100.0, 100.0, 20.0, 100.0)
	assert_test(float(gains_full.get("life", 0.0)) == 0.0, "Nenhum ganho quando vida já está 100%")
	assert_test(float(svc.active_recoveries["life"]["remaining_time"]) == 0.0, "HoT encerrado imediatamente sem efeito zumbi")


func _test_06_hud_slots_and_restrictions() -> void:
	print("\n--- 6. RESTRIÇÕES DE EQUIPAR, ATIVAÇÃO E ESTADO DA HUD ---")

	var hud := HealthGlobeHUDScript.new() as HealthGlobeHUD
	var dummy_player := TowerPlayer.new()
	dummy_player.health = 60
	dummy_player.max_health = 100
	dummy_player.mana = 30
	dummy_player.max_mana = 100
	hud.bind_context(null, dummy_player)
	hud.update_health(60, 100)

	var f_life := ItemInstance.new(ItemDatabase.get_definition("flask_life_small"))
	var f_mana := ItemInstance.new(ItemDatabase.get_definition("flask_mana_small"))

	# Slot 0 aceita Vida, rejeita Mana
	assert_test(hud.equip_flask(0, f_mana) == false, "Slot 0 rejeita frasco de Mana")
	assert_test(hud.equip_flask(0, f_life) == true, "Slot 0 aceita frasco de Vida")

	# Slot 1 aceita Mana, rejeita Vida
	assert_test(hud.equip_flask(1, f_life) == false, "Slot 1 rejeita frasco de Vida")
	assert_test(hud.equip_flask(1, f_mana) == true, "Slot 1 aceita frasco de Mana")

	# Bloqueio de duplicidade na mesma instância
	assert_test(hud.equip_flask(1, f_life) == false, "Mesma instância não pode ser duplicada em dois slots")

	# Consumo com sucesso
	var used_life: bool = hud.use_potion(0)
	assert_test(used_life == true, "Frasco de Vida ativado com sucesso")
	assert_test(f_life.get_current_charges() == 50, "Cargas reduzidas de 60 para 50")
	assert_test(hud.potion_cooldowns[0] > 0.0, "Cooldown iniciado no slot 0")

	# Bloqueio de ativação com recurso 100% cheio (Doc 08 Seção 4)
	dummy_player.health = 100
	hud.update_health(100, 100)
	hud.potion_cooldowns[0] = 0.0
	var used_full: bool = hud.use_potion(0)
	assert_test(used_full == false, "Uso rejeitado quando vida já está cheia (100/100)")
	assert_test(f_life.get_current_charges() == 50, "Cargas preservadas sem gasto inútil")

	# Bloqueio quando sem cargas
	f_life.current_charges = 5
	dummy_player.health = 40
	hud.update_health(40, 100)
	var used_empty: bool = hud.use_potion(0)
	assert_test(used_empty == false, "Uso rejeitado quando cargas insuficientes (5 < 10)")

	hud.queue_free()
	dummy_player.queue_free()


func _test_07_well_and_checkpoint_refill() -> void:
	print("\n--- 7. REFIL COMPLETO NO POÇO / CHECKPOINT (DOC 08 SEÇÃO 8.1) ---")

	var hud := HealthGlobeHUDScript.new() as HealthGlobeHUD
	var f_life := ItemInstance.new(ItemDatabase.get_definition("flask_life_large"))
	var f_mana := ItemInstance.new(ItemDatabase.get_definition("flask_mana_large"))

	f_life.current_charges = 12
	f_mana.current_charges = 8

	hud.equip_flask(0, f_life)
	hud.equip_flask(1, f_mana)

	hud.refill_all_flasks()

	assert_test(f_life.get_current_charges() == 80, "Frasco de Vida Grande recarregado para 80/80")
	assert_test(f_mana.get_current_charges() == 80, "Frasco de Mana Grande recarregado para 80/80")
	assert_test(f_life.get_available_uses() == 8, "Vida Grande agora possui 8 usos cheios")
	assert_test(f_mana.get_available_uses() == 8, "Mana Grande agora possui 8 usos cheios")

	hud.queue_free()


func _test_08_serialization_and_save() -> void:
	print("\n--- 8. SERIALIZAÇÃO E PERSISTÊNCIA NO SAVE (DOC 08 SEÇÃO 10.1) ---")

	var f_orig := ItemInstance.new(ItemDatabase.get_definition("flask_life_medium"))
	f_orig.current_charges = 43

	var dict: Dictionary = f_orig.to_dictionary()
	assert_test(dict.has("current_charges"), "Dicionário serializado contém 'current_charges'")
	assert_test(int(dict["current_charges"]) == 43, "Valor de cargas gravado com fidelidade (43)")

	var f_restored := ItemInstance.from_dictionary(dict)
	assert_test(f_restored != null, "Instância desserializada com sucesso")
	assert_test(f_restored.is_flask() == true, "Mantém identificação como frasco")
	assert_test(f_restored.get_current_charges() == 43, "Cargas restauradas com exatidão (43)")
	assert_test(f_restored.get_flask_capacity() == 70, "Capacidade máxima preservada (70)")
	assert_test(f_restored.get_available_uses() == 4, "Usos disponíveis calculados com perfeição (4)")


func _test_09_tooltips_and_formatting() -> void:
	print("\n--- 9. TOOLTIPS E FORMATAÇÃO VISUAL (DOC 08 SEÇÃO 9) ---")

	var f_inst := ItemInstance.new(ItemDatabase.get_definition("flask_life_small"))
	f_inst.current_charges = 37

	var tt: String = f_inst.format_tooltip_bbcode()
	assert_test(tt.contains("Frasco de Vida Pequeno"), "Tooltip contém o nome do frasco")
	assert_test(tt.contains("Restaura"), "Tooltip descreve restauração")
	assert_test(tt.contains("70 de Vida"), "Tooltip informa 70 de Vida")
	assert_test(tt.contains("3.0 s"), "Tooltip informa duração de 3.0s")
	assert_test(tt.contains("37 / 60"), "Tooltip exibe cargas '37 / 60'")
	assert_test(tt.contains("10"), "Tooltip informa consumo de 10 cargas")
	assert_test(tt.contains("3"), "Tooltip informa 3 usos disponíveis")
	assert_test(not tt.contains("x37 garrafas"), "Não confunde cargas com garrafas físicas")


func _print_summary() -> void:
	print("\n=================================================================")
	print("RESULTADO QA FRASCOS RECARREGÁVEIS: %d/%d PASSARAM (%d FALHAS)" % [passed_tests, total_tests, failed_tests])
	print("=================================================================")
	if failed_tests == 0:
		print(">> TODOS OS REQUISITOS DO DOCUMENTO 08 FORAM APROVADOS! <<\n")
	else:
		printerr(">> ATENÇÃO: HOUVE FALHAS NA VALIDAÇÃO DE FRASCOS! <<\n")
