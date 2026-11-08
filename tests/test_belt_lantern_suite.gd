extends SceneTree

## Suíte Completa de Testes e Validação: Iluminação Circular do Personagem (ARPG Low-Poly)
## Valida o novo sistema simplificado:
## • Luz radial pura (OmniLight3D) em volta do personagem.
## • Sem modelo 3D de lanterna, sem nós de malha anexados.
## • Projeção circular suave de 360° ao redor do herói (raio ~8.0m).
## • Ativação automática em ambientes escuros (noite, criptas, masmorras).
## • Centralização estável no corpo do herói, acompanhando deslocamento e ataques.

func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("==================================================================================")
	print("  SUÍTE DE TESTES: ILUMINAÇÃO CIRCULAR DO PERSONAGEM — ARPG LOW-POLY             ")
	print("==================================================================================")

	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)

	var main_scene: PackedScene = load("res://scenes/main.tscn")
	assert(main_scene != null, "scenes/main.tscn deve existir e ser carregável")

	var root_node: Node3D = main_scene.instantiate() as Node3D
	root_vp.add_child(root_node)

	# Aguarda frames de inicialização de _ready()
	for _i in range(5):
		await process_frame

	var player: TowerPlayer = root_node.get_node_or_null("Player") as TowerPlayer
	var day_night: DayNightCycleHUD = root_node.get("day_night_hud") as DayNightCycleHUD

	assert(player != null, "Player deve existir")
	assert(day_night != null, "DayNightCycleHUD deve existir")

	var player_light: BeltLantern3D = player.belt_lantern
	assert(player_light != null, "Luz do personagem deve estar instanciada no Player")
	assert(player_light._omni_light != null, "OmniLight3D da luz do personagem deve existir")

	# -------------------------------------------------------------------------
	# CENÁRIO 1: Sem modelo 3D (ausência total de malhas de lanterna)
	# -------------------------------------------------------------------------
	print("[Cenário 1] Verificação: zero modelos 3D / sem malha na luz...")
	var meshes: Array[Node] = player_light.find_children("", "MeshInstance3D", true, false)
	assert(meshes.is_empty(), "Não deve existir nenhuma malha 3D (Cylinder/Box/Hook) na luz do personagem")
	print("  -> OK: Luz é pura (OmniLight3D), sem objetos 3D pendurados no corpo.")

	# -------------------------------------------------------------------------
	# CENÁRIO 2: Dia claro ensolarado
	# -------------------------------------------------------------------------
	print("[Cenário 2] Dia claro ensolarado na vila...")
	day_night.set_time_of_day(0.50) # Meio-dia
	player_light.set_zone_context("town")

	for _i in range(15):
		await process_frame

	assert(player_light.current_light_energy < 0.05, "Durante o dia ensolarado, a luz do personagem permanece apagada")
	assert(player_light._omni_light.light_energy < 0.05, "OmniLight3D desligada sob o sol")
	print("  -> OK: Sob sol de meio-dia, a luz circular do herói permanece apagada.")

	# -------------------------------------------------------------------------
	# CENÁRIO 3: Transição para a noite (Círculo de luz acende suavemente)
	# -------------------------------------------------------------------------
	print("[Cenário 3] Transição para a noite...")
	day_night.set_time_of_day(0.95) # Noite plena

	for _i in range(50):
		await process_frame
		if player_light.current_light_energy > 0.60:
			break

	assert(player_light.is_night_time == true, "Luz deve reconhecer fase noturna")
	assert(player_light.is_lantern_lit() == true, "Luz deve acender durante a noite")
	assert(player_light.current_light_energy > 0.60, "Energia da luz deve subir para o patamar ativo (> 0.60)")
	assert(player_light._omni_light.light_energy > 0.60, "OmniLight3D deve emitir iluminação ativa")
	assert(player_light._omni_light.light_color == BeltLantern3D.DEFAULT_AMBER_COLOR, "Cor da luz deve ser âmbar quente medieval")
	print("  -> OK: Luz acendeu suavemente à noite com cor âmbar quente.")

	# -------------------------------------------------------------------------
	# CENÁRIO 4: Centralização estável (360° sem wobble de animação de quadril)
	# -------------------------------------------------------------------------
	print("[Cenário 4] Centralização no herói (posição Vector3(0, 1.0, 0))...")
	assert(player_light.get_parent() == player, "Luz do personagem deve estar fixada diretamente na raiz do Player")
	assert(is_equal_approx(player_light.position.x, 0.0), "Posição X deve ser 0.0 (centralizada)")
	assert(is_equal_approx(player_light.position.z, 0.0), "Posição Z deve ser 0.0 (centralizada)")
	assert(player_light.position.y >= 0.8, "Altura Y deve estar em torno de 1.0m (torso/peito)")
	print("  -> OK: Luz perfeitamente centralizada a 1.0m de altura, produzindo círculo perfeito no chão.")

	# -------------------------------------------------------------------------
	# CENÁRIO 5: Entrada em Masmorra/Cripta Escura durante o Dia
	# -------------------------------------------------------------------------
	print("[Cenário 5] Entrada em Cripta/Masmorra ('zone_3_crypt') durante o dia...")
	day_night.set_time_of_day(0.50) # Meio-dia no relógio
	player_light.set_zone_context("zone_3_crypt") # Ambiente escuro subterrâneo

	for _i in range(50):
		await process_frame
		if player_light.current_light_energy > 0.70:
			break

	assert(player_light.is_dark_zone == true, "Deve identificar zona como ambiente escuro")
	assert(player_light.is_lantern_lit() == true, "Luz deve acender na Cripta mesmo com sol no relógio!")
	assert(player_light._omni_light.light_energy > 0.60, "OmniLight ativa na cripta")
	print("  -> OK: Luz acende automaticamente em masmorras/criptas mesmo com sol lá fora.")

	# -------------------------------------------------------------------------
	# CENÁRIO 6: Retorno da Masmorra para área externa clara
	# -------------------------------------------------------------------------
	print("[Cenário 6] Retornar da Cripta para a Vila externa de dia...")
	player_light.set_zone_context("town")
	day_night.set_zone_context("town")

	for _i in range(60):
		await process_frame
		if player_light.current_light_energy < 0.05:
			break

	assert(player_light.is_dark_zone == false, "Não é mais zona escura")
	assert(player_light.current_light_energy < 0.05, "Luz apaga suavemente ao voltar para a luz solar")
	print("  -> OK: Luz apaga suavemente ao retornar para a luz externa natural.")

	# -------------------------------------------------------------------------
	# CENÁRIO 7: Movimento do Jogador e Ataques de Combate
	# -------------------------------------------------------------------------
	print("[Cenário 7] Movimentação e ataques de combate...")
	player_light.set_zone_context("zone_3_crypt")
	for _i in range(30):
		await process_frame

	var initial_pos: Vector3 = player_light.global_position
	player.global_position += Vector3(4.0, 0.0, 3.0)
	player.call("play_attack_animation", 0)

	for _i in range(10):
		await process_frame

	var moved_pos: Vector3 = player_light.global_position
	assert(not moved_pos.is_equal_approx(initial_pos), "Luz acompanha o deslocamento do jogador")
	print("  -> OK: Círculo de luz acompanha deslocamento e golpes com estabilidade.")

	# -------------------------------------------------------------------------
	# CENÁRIO 8: Parâmetros Luminosos de Círculo Limpo
	# -------------------------------------------------------------------------
	print("[Cenário 8] Validação dos parâmetros luminosos (alcance, atenuação e sem auto-oclusão)...")
	var omni: OmniLight3D = player_light._omni_light
	assert(omni.omni_range >= 7.0 and omni.omni_range <= 10.0, "Alcance do círculo entre 7.0m e 10.0m (atual: %.1fm)" % omni.omni_range)
	assert(omni.omni_attenuation >= 0.8 and omni.omni_attenuation <= 1.2, "Atenuação radial suave (atual: %.2f)" % omni.omni_attenuation)
	assert(omni.shadow_enabled == false, "Sombras desativadas na OmniLight para garantir círculo puro e limpo sem auto-sombras do corpo")
	print("  -> OK: Parâmetros ópticos aprovados para projeção circular nítida.")

	print("==================================================================================")
	print("  TODOS OS 8 CENÁRIOS DA ILUMINAÇÃO CIRCULAR PASSARAM COM SUCESSO!                ")
	print("==================================================================================")
	quit(0)
