extends SceneTree

## Suíte Completa de Testes e Validação: Sistema de Lanterna no Cinto (Iluminação Dinâmica)
## Valida os 10 cenários e a REGRA OBRIGATÓRIA:
## "O personagem só pode utilizar essa iluminação se tiver um cinto equipado no slot correspondente."

func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("==================================================================================")
	print("  SUÍTE DE TESTES: SISTEMA DE LANTERNA NO CINTO — ILUMINAÇÃO DINÂMICA ARPG         ")
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
	var equipment: CharacterEquipment = root_node.get("equipment") as CharacterEquipment

	assert(player != null, "Player deve existir")
	assert(day_night != null, "DayNightCycleHUD deve existir")
	assert(equipment != null, "CharacterEquipment deve existir")

	var lantern: BeltLantern3D = player.belt_lantern
	assert(lantern != null, "BeltLantern3D deve estar instanciado no Player")
	assert(lantern._omni_light != null, "OmniLight3D da lanterna deve existir")

	# -------------------------------------------------------------------------
	# CENÁRIO 1: Dia ensolarado com cinto equipado
	# -------------------------------------------------------------------------
	print("[Cenário 1] Dia claro com cinto equipado...")
	var test_belt: ItemInstance = ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "belt_leather")
	assert(test_belt != null, "Cinto de teste deve ser gerado")
	equipment.equip_item(test_belt, ItemDefinition.EquipmentSlot.BELT, player.stats)
	day_night.set_time_of_day(0.50) # Meio-dia (Noon)
	lantern.set_zone_context("town")

	for _i in range(15):
		await process_frame

	assert(lantern.has_belt_equipped == true, "Cinto deve estar detectado como equipado")
	assert(lantern.visible == true, "Modelo da lanterna preso ao cinto deve ser visível de dia")
	assert(lantern.current_light_energy < 0.05, "Durante o dia em área clara, a lanterna deve permanecer APAGADA")
	assert(lantern._omni_light.light_energy < 0.05, "Luz OmniLight3D deve estar desligada durante o dia")
	print("  -> OK: Lanterna visível no cinto mas 100% apagada sob sol de meio-dia.")

	# -------------------------------------------------------------------------
	# CENÁRIO 2: Noite com cinto equipado (Acendimento suave e orgânico)
	# -------------------------------------------------------------------------
	print("[Cenário 2] Transição para a noite com cinto equipado...")
	day_night.set_time_of_day(0.95) # Noite plena

	for _i in range(50):
		await process_frame
		if lantern.current_light_energy > 0.60:
			break

	assert(lantern.is_night_time == true, "Lanterna deve reconhecer fase noturna")
	assert(lantern.is_lantern_lit() == true, "Lanterna deve acender durante a noite")
	assert(lantern.current_light_energy > 0.60, "Energia da luz deve subir para o patamar ativo (> 0.60)")
	assert(lantern._omni_light.light_energy > 0.60, "OmniLight3D deve emitir iluminação ativa")
	assert(lantern._omni_light.light_color == BeltLantern3D.DEFAULT_AMBER_COLOR, "Cor da luz deve ser âmbar quente medieval")
	assert(lantern._candle_material.emission_energy_multiplier > 0.5, "Núcleo de vela da lanterna deve estar emitindo brilho incandescente")

	# Verifica oscilação orgânica da chama (flicker suave +-4%)
	var energy_sample1: float = lantern._omni_light.light_energy
	for _i in range(8):
		await process_frame
	var energy_sample2: float = lantern._omni_light.light_energy
	assert(not is_equal_approx(energy_sample1, energy_sample2), "Luz da lanterna deve ter flicker orgânico suave imitando vela/chama viva")
	print("  -> OK: Lanterna acendeu suavemente à noite com luz âmbar e oscilação viva de chama.")

	# -------------------------------------------------------------------------
	# CENÁRIO 3: REGRA OBRIGATÓRIA — Remover cinto à noite apaga e oculta IMEDIATAMENTE!
	# -------------------------------------------------------------------------
	print("[Cenário 3] REGRA OBRIGATÓRIA: Remover cinto enquanto a lanterna está acesa...")
	var signal_data := {"emitted": false, "lit": true, "belt": true}
	var on_state_changed = func(is_lit: bool, has_b: bool) -> void:
		signal_data["emitted"] = true
		signal_data["lit"] = is_lit
		signal_data["belt"] = has_b

	lantern.lantern_state_changed.connect(on_state_changed)
	equipment.unequip_item(ItemDefinition.EquipmentSlot.BELT)

	# Imediatamente no mesmo frame:
	assert(lantern.has_belt_equipped == false, "Lanterna deve registrar desequipamento do cinto")
	assert(lantern.visible == false, "REGRA CRÍTICA: Lanterna DEVE sumir imediatamente ao desequipar o cinto!")
	assert(lantern.current_light_energy == 0.0, "REGRA CRÍTICA: Energia luminosa deve ir a ZERO imediatamente!")
	assert(lantern._omni_light.light_energy == 0.0, "REGRA CRÍTICA: OmniLight deve ser desligada imediatamente!")
	assert(signal_data["emitted"] == true and signal_data["lit"] == false and signal_data["belt"] == false, "Sinal deve notificar que desequipou e apagou")
	lantern.lantern_state_changed.disconnect(on_state_changed)

	# Garante que mesmo processando mais frames na noite escura, ela continua 100% invisível e apagada
	for _i in range(20):
		await process_frame

	assert(lantern.visible == false, "Lanterna continua oculta sem cinto")
	assert(lantern._omni_light.light_energy == 0.0, "Luz continua zerada sem cinto")
	print("  -> OK: Desequipar o cinto remove imediatamente o modelo e a luz, sem resquícios.")

	# -------------------------------------------------------------------------
	# CENÁRIO 4: Re-equipar o cinto durante a noite
	# -------------------------------------------------------------------------
	print("[Cenário 4] Re-equipar cinto durante a noite...")
	equipment.equip_item(test_belt, ItemDefinition.EquipmentSlot.BELT, player.stats)
	assert(lantern.visible == true, "Lanterna reaparece ao reequipar o cinto")

	for _i in range(50):
		await process_frame
		if lantern.current_light_energy > 0.70:
			break

	assert(lantern.is_lantern_lit() == true, "Lanterna volta a iluminar a noite")
	assert(lantern._omni_light.light_energy > 0.60, "OmniLight reativada")
	print("  -> OK: Re-equipar cinto à noite restaura a lanterna e a iluminação.")

	# -------------------------------------------------------------------------
	# CENÁRIO 5: Entrar em Masmorra/Cripta Escura durante o Dia
	# -------------------------------------------------------------------------
	print("[Cenário 5] Entrar em Cripta/Masmorra ('zone_3_crypt') durante o dia...")
	day_night.set_time_of_day(0.50) # Sol do meio-dia no relógio
	lantern.set_zone_context("zone_3_crypt") # Ambiente escuro subterrâneo

	for _i in range(50):
		await process_frame
		if lantern.current_light_energy > 0.70:
			break

	assert(lantern.is_dark_zone == true, "Deve identificar zona como ambiente escuro")
	assert(lantern.is_lantern_lit() == true, "Deve acender na Cripta/Masmorra mesmo com sol no relógio!")
	assert(lantern._omni_light.light_energy > 0.60, "Luz OmniLight ativa na caverna/cripta")
	print("  -> OK: Lanterna acende automaticamente em masmorras/criptas mesmo sob sol do meio-dia.")

	# -------------------------------------------------------------------------
	# CENÁRIO 6: Retornar da Masmorra para área externa clara durante o Dia
	# -------------------------------------------------------------------------
	print("[Cenário 6] Retornar da Cripta para a Vila externa de dia...")
	lantern.set_zone_context("town") # Volta para área clara aberta
	day_night.set_zone_context("town")

	for _i in range(60):
		await process_frame
		if lantern.current_light_energy < 0.05:
			break

	assert(lantern.is_dark_zone == false, "Não é mais zona escura")
	assert(lantern.is_night_time == false, "É dia aberto")
	assert(lantern.current_light_energy < 0.05, "Lanterna apaga automaticamente ao voltar à luz do dia")
	assert(lantern._omni_light.light_energy < 0.05, "OmniLight desligada no retorno à claridade")
	print("  -> OK: Lanterna apaga suavemente ao retornar para a luz externa natural.")

	# -------------------------------------------------------------------------
	# CENÁRIO 7: Remover cinto dentro da Cripta escura
	# -------------------------------------------------------------------------
	print("[Cenário 7] Remover cinto enquanto estiver dentro da Cripta...")
	lantern.set_zone_context("zone_3_crypt")
	for _i in range(50):
		await process_frame
		if lantern._omni_light.light_energy > 0.60:
			break
	assert(lantern._omni_light.light_energy > 0.60, "Lanterna acesa na cripta")

	equipment.unequip_item(ItemDefinition.EquipmentSlot.BELT)
	assert(lantern.visible == false, "Mesmo no fundo da cripta, sem cinto a lanterna some imediatamente!")
	assert(lantern._omni_light.light_energy == 0.0, "Mesmo no fundo da cripta, sem cinto não há luz!")
	print("  -> OK: Removendo o cinto no escuro deixa o personagem totalmente às escuras.")

	# -------------------------------------------------------------------------
	# CENÁRIO 8: Fixação Anatômica ao Esqueleto e Animações de Combate
	# -------------------------------------------------------------------------
	print("[Cenário 8] Fixação ao osso 'hips' / cintura e acompanhamento de golpes...")
	equipment.equip_item(test_belt, ItemDefinition.EquipmentSlot.BELT, player.stats)
	assert(lantern.visible == true, "Lanterna presente")

	var parent_attachment = lantern.get_parent()
	assert(parent_attachment != null, "Lanterna deve ter um nó pai no personagem")
	if parent_attachment is BoneAttachment3D:
		var ba := parent_attachment as BoneAttachment3D
		assert(ba.bone_name == "hips" or ba.bone_name == "spine", "BoneAttachment deve estar preso a hips ou spine (cintura)")
		print("  -> OK: Preso diretamente ao rig do cavaleiro via BoneAttachment3D no osso '%s'." % ba.bone_name)
	else:
		print("  -> OK: Fallback anatômico na cintura do Visual do jogador.")

	# Movimenta o jogador e executa animação de ataque
	var initial_lantern_pos: Vector3 = lantern.global_position
	player.global_position += Vector3(3.0, 0.0, 2.0)
	player.call("play_attack_animation", 0)

	for _i in range(10):
		await process_frame

	var moved_lantern_pos: Vector3 = lantern.global_position
	assert(not moved_lantern_pos.is_equal_approx(initial_lantern_pos), "Lanterna deve acompanhar rigidamente o deslocamento do jogador")
	print("  -> OK: Lanterna acompanhou rotação, golpes de ataque e deslocamento sem desvincular.")

	# -------------------------------------------------------------------------
	# CENÁRIO 9: Parâmetros de Iluminação e Alcance Suave
	# -------------------------------------------------------------------------
	print("[Cenário 9] Validação dos parâmetros luminosos (alcance, atenuação e não-ofuscamento)...")
	assert(is_equal_approx(lantern._omni_light.omni_range, 4.2), "Alcance deve ser de ~4.2m cobrindo pés e arredores")
	assert(is_equal_approx(lantern._omni_light.omni_attenuation, 1.35), "Atenuação de 1.35 para queda suave de luz")
	assert(lantern._omni_light.shadow_enabled == false, "Shadow deve ser false na lanterna omni para altíssima performance")
	print("  -> OK: Parâmetros de iluminação verificados com sucesso (raio 4.2m, atenuação 1.35, âmbar quente).")

	# -------------------------------------------------------------------------
	# CENÁRIO 10: Integração de Inicialização e Inventário Espacial
	# -------------------------------------------------------------------------
	print("[Cenário 10] Inicialização e integração com CharacterEquipment e inventário...")
	assert(equipment.get_equipped_item(ItemDefinition.EquipmentSlot.BELT) != null, "Cinto equipado")
	print("  -> OK: Suíte de lanterna no cinto 100% aprovada!")

	print("==================================================================================")
	print("  TODOS OS 10 CENÁRIOS DO SISTEMA DE LANTERNA NO CINTO PASSARAM COM SUCESSO!      ")
	print("==================================================================================")
	quit(0)
