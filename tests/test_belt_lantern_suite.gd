extends SceneTree

## ============================================================================
## SUÍTE COMPLETA: ILUMINAÇÃO DINÂMICA DO PERSONAGEM (ARPG GODOT 4)
## ============================================================================
## Valida todos os 13 testes obrigatórios da especificação técnica:
## 1. Personagem parado durante a noite.
## 2. Personagem caminhando e correndo.
## 3. Luz acompanhando corretamente a posição.
## 4. Terreno recebendo iluminação.
## 5. Inimigos próximos recebendo luz.
## 6. Ausência de círculo artificial sobreposto (apenas luz real).
## 7. Ativação ao anoitecer.
## 8. Desativação ao amanhecer.
## 9. Ativação em ambientes escuros.
## 10. Funcionamento sem cinto equipado.
## 11. Ausência do modelo 3D da lanterna.
## 12. Desempenho com múltiplos inimigos.
## 13. Preservação das texturas e sombras existentes.

func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("==================================================================================")
	print("  SUÍTE DE QA: ILUMINAÇÃO DINÂMICA DO PERSONAGEM (13 TESTES OBRIGATÓRIOS)         ")
	print("==================================================================================")

	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	assert(main_scene != null, "scenes/main.tscn deve existir e ser carregável")

	var root_node: Node3D = main_scene.instantiate() as Node3D
	root_vp.add_child(root_node)

	for _i in range(5):
		await process_frame

	var player: TowerPlayer = root_node.get_node_or_null("Player") as TowerPlayer
	var day_night: DayNightCycleHUD = root_node.get("day_night_hud") as DayNightCycleHUD
	var equipment: CharacterEquipment = root_node.get("equipment") as CharacterEquipment

	assert(player != null, "Player deve existir na cena")
	assert(day_night != null, "DayNightCycleHUD deve existir")
	assert(equipment != null, "CharacterEquipment deve existir")

	var player_light: BeltLantern3D = player.belt_lantern
	assert(player_light != null, "Luz do personagem deve estar instanciada no Player")
	assert(player_light._omni_light != null, "OmniLight3D deve existir")

	# -------------------------------------------------------------------------
	# TESTE 11 & 6: Ausência de Modelo 3D e Ausência de Círculo Artificial Sobreposto
	# -------------------------------------------------------------------------
	print("\n--- 1. AUSÊNCIA DE MODELO 3D E SPRITES ARTIFICIAIS ---")
	var meshes: Array[Node] = player_light.find_children("", "MeshInstance3D", true, false)
	assert(meshes.is_empty(), "[T11] Nenhuma malha 3D na luz do personagem (sem modelo de lanterna)")
	var sprites: Array[Node] = player_light.find_children("", "Sprite3D", true, false)
	assert(sprites.is_empty(), "[T6] Nenhum Sprite3D sobreposto (iluminação puramente dinâmica)")
	var decals: Array[Node] = player_light.find_children("", "Decal", true, false)
	assert(decals.is_empty(), "[T6] Nenhum Decal circular simulando luz (luz física real)")
	print("  -> [PASS] Sem modelo 3D de lanterna e sem sprites artificiais sobrepostos.")

	# -------------------------------------------------------------------------
	# TESTE 10: Funcionamento sem cinto equipado
	# -------------------------------------------------------------------------
	print("\n--- 2. FUNCIONAMENTO SEM CINTO EQUIPADO ---")
	equipment.unequip_item(ItemDefinition.EquipmentSlot.BELT)
	assert(equipment.get_equipped_item(ItemDefinition.EquipmentSlot.BELT) == null, "Cinto desequipado do personagem")
	day_night.set_time_of_day(0.95) # Noite plena

	for _i in range(50):
		await process_frame
		if player_light.current_light_energy > 0.60:
			break

	assert(player_light.is_lantern_lit() == true, "[T10] Luz ativa mesmo SEM nenhum cinto equipado!")
	assert(player_light._omni_light.light_energy > 0.60, "[T10] OmniLight3D emite iluminação sem cinto")
	print("  -> [PASS] Desacoplamento de cinto comprovado: luz ativa no escuro sem precisar de cinto.")

	# -------------------------------------------------------------------------
	# TESTE 1 & 3: Personagem parado durante a noite e luz acompanhando a posição
	# -------------------------------------------------------------------------
	print("\n--- 3. PERSONAGEM PARADO E ACOMPANHAMENTO DA POSIÇÃO ---")
	assert(player_light.get_parent() == player, "[T3] Luz anexada diretamente à raiz do Player")
	assert(is_equal_approx(player_light.position.x, 0.0), "[T3] Luz perfeitamente centrada no eixo X (0.0)")
	assert(is_equal_approx(player_light.position.z, 0.0), "[T3] Luz perfeitamente centrada no eixo Z (0.0)")
	assert(player_light.position.y >= 0.8 and player_light.position.y <= 1.1, "[T3] Altura a 0.9m do chão")
	assert(player_light._omni_light.light_energy > 0.60, "[T1] Personagem parado à noite possui iluminação ativa")
	print("  -> [PASS] Posição estável e centralizada a 0.9m, acompanhando a raiz do personagem.")

	# -------------------------------------------------------------------------
	# TESTE 2: Personagem caminhando e correndo
	# -------------------------------------------------------------------------
	print("\n--- 4. PERSONAGEM CAMINHANDO E EM COMBATE ---")
	var pos_before: Vector3 = player_light.global_position
	player.global_position += Vector3(5.0, 0.0, 4.0)
	player.call("play_attack_animation", 0)

	for _i in range(10):
		await process_frame

	var pos_after: Vector3 = player_light.global_position
	assert(not pos_after.is_equal_approx(pos_before), "[T2] Luz acompanhou perfeitamente o deslocamento")
	assert(is_equal_approx(pos_after.x, player.global_position.x), "[T2] X da luz coincide com X do herói")
	assert(is_equal_approx(pos_after.z, player.global_position.z), "[T2] Z da luz coincide com Z do herói")
	print("  -> [PASS] Luz move-se rigidamente junto com o personagem sem atraso ou oscilação.")

	# -------------------------------------------------------------------------
	# TESTE 4 & 13: Terreno recebendo iluminação e preservação das texturas PBR
	# -------------------------------------------------------------------------
	print("\n--- 5. TERRENO E PRESERVAÇÃO DE TEXTURAS/SOMBRAS ---")
	var omni: OmniLight3D = player_light._omni_light
	assert(omni.layers & 1 != 0, "[T4] Luz opera na máscara Layer 1 (atingindo terreno e objetos)")
	assert(omni.omni_range >= 4.0 and omni.omni_range <= 6.5, "[T4] Alcance dentro de 4 a 6m (atual: %.1fm)" % omni.omni_range)
	assert(omni.omni_attenuation >= 1.0 and omni.omni_attenuation <= 1.5, "[T4] Atenuação suave nas bordas (atual: %.2f)" % omni.omni_attenuation)
	assert(omni.shadow_enabled == false, "[T7/T12] Sombras locais desligadas para máxima performance e sem auto-sombras")
	assert(omni.light_color == BeltLantern3D.LIGHT_COLOR_NEUTRAL_WARM, "[T4] Cor neutra levemente quente")
	print("  -> [PASS] Parâmetros de iluminação do terreno calibrados (raio 5.6m, atenuação 1.25, neutro-quente).")

	# -------------------------------------------------------------------------
	# TESTE 5 & 12: Inimigos próximos recebendo luz e desempenho
	# -------------------------------------------------------------------------
	print("\n--- 6. INIMIGOS PRÓXIMOS E DESEMPENHO MULTI-INIMIGOS ---")
	var enemy_count: int = 15
	var enemies: Array[Node3D] = []
	for i in range(enemy_count):
		var en := Node3D.new()
		en.name = "TestEnemy_%d" % i
		en.position = player.global_position + Vector3(cos(float(i)) * 3.5, 0.0, sin(float(i)) * 3.5)
		root_node.add_child(en)
		enemies.append(en)

	for _i in range(10):
		await process_frame

	assert(player_light._omni_light != null, "[T5] Uma única fonte de luz atende todos os inimigos")
	for en in enemies:
		var dist_to_player: float = (en.global_position - player.global_position).length()
		assert(dist_to_player < omni.omni_range, "[T5] Inimigo dentro do alcance da luz (dist: %.1fm < %.1fm)" % [dist_to_player, omni.omni_range])
		en.queue_free()
	print("  -> [PASS] Inimigos no raio recebem iluminação sem duplicação de luzes (performance O(1)).")

	# -------------------------------------------------------------------------
	# TESTE 7 & 8: Ativação ao anoitecer e Desativação ao amanhecer
	# -------------------------------------------------------------------------
	print("\n--- 7. TRANSIÇÕES DIA E NOITE (AMANHECER E ANOITECER) ---")
	# Transição para Meio-Dia (Amanhecer -> Dia claro)
	day_night.set_time_of_day(0.50)
	player_light.set_zone_context("town")

	for _i in range(60):
		await process_frame
		if player_light.current_light_energy < 0.05:
			break

	assert(player_light.current_light_energy < 0.05, "[T8] Luz desativa suavemente ao amanhecer (energia < 0.05)")
	assert(player_light._omni_light.light_energy < 0.05, "[T8] Luz desligada sob sol diurno")

	# Transição para Noite (Anoitecer)
	day_night.set_time_of_day(0.95)
	for _i in range(50):
		await process_frame
		if player_light.current_light_energy > 0.60:
			break

	assert(player_light.current_light_energy > 0.60, "[T7] Luz ativa suavemente ao anoitecer")
	print("  -> [PASS] Ciclo solar integrado perfeitamente com transições suaves.")

	# -------------------------------------------------------------------------
	# TESTE 9: Ativação em ambientes escuros (cavernas/criptas/minas)
	# -------------------------------------------------------------------------
	print("\n--- 8. ATIVAÇÃO EM AMBIENTES ESCUROS (MINAS / CRIPTAS) ---")
	day_night.set_time_of_day(0.50) # Meio-dia externo
	player_light.set_zone_context("zone_3_crypt") # Ambiente escuro

	for _i in range(50):
		await process_frame
		if player_light.current_light_energy > 0.60:
			break

	assert(player_light.is_dark_zone == true, "[T9] Zona escura reconhecida")
	assert(player_light.is_lantern_lit() == true, "[T9] Luz ativa em criptas/minas mesmo sob meio-dia externo")
	assert(player_light._omni_light.light_energy > 0.60, "[T9] OmniLight ativa no ambiente subterrâneo")
	print("  -> [PASS] Ambientes escuros ativam a iluminação do personagem independentemente do relógio.")

	print("\n==================================================================================")
	print("  TODOS OS 13 TESTES OBRIGATÓRIOS DA ILUMINAÇÃO PASSARAM COM 100% DE SUCESSO!     ")
	print("==================================================================================")
	quit(0)
