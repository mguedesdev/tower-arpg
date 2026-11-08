extends SceneTree

## Suíte de Testes Automatizados: Arquitetura de Iluminação e Sombras por Região (Godot 4)
## Valida estritamente a nova direção de arte inspirada nas referências visuais (estilo Albion Online):
## 1. Ausência permanente de ciclo Dia/Noite e sem lanterna de cinto no player.
## 2. Perfil 1 — Floresta Natural (Exterior): Sol moderado, sombras suaves e reconhecíveis, ambient fill legível.
## 3. Perfil 2 — Masmorra (Interior): Sol desativado, escuridão profunda, tochas âmbar suaves com sombras de contato.
## 4. Perfil 3 — Floresta Mágica (Temático): Luz mística, ambiente ciano/azul etéreo e santuário radiante.
## 5. Validação de troca dinâmica de perfil ao transitar entre regiões da Campanha.
## 6. Otimização de Sombras: Árvores/Rochas projetam sombras; folhagem rasteira/pedrinhas com sombras desativadas.
## 7. Performance e ausência de clarão/estouro de branco (tonemap filmic equilibrado).

func _init() -> void:
	call_deferred("_run_all")


func _run_all() -> void:
	print("==================================================================================")
	print("  SUÍTE DE AUDITORIA: ARQUITETURA DE ILUMINAÇÃO & SOMBRAS POR REGIÃO (ARPG GODOT 4)")
	print("==================================================================================")

	var root_vp := get_root()
	root_vp.size = Vector2i(1280, 720)

	var arpg_scene: PackedScene = load("res://scenes/arpg/arpg_game.tscn")
	assert(arpg_scene != null, "scenes/arpg/arpg_game.tscn deve existir e ser carregável")

	var game: Node3D = arpg_scene.instantiate() as Node3D
	root_vp.add_child(game)

	for _i in range(6):
		await process_frame

	var world_env: WorldEnvironment = game.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var sun: DirectionalLight3D = game.get_node_or_null("Sun") as DirectionalLight3D
	var player: Node3D = game.get_node_or_null("Player") as Node3D

	assert(world_env != null, "Nó WorldEnvironment deve estar presente na cena")
	assert(sun != null, "Nó Sun (DirectionalLight3D) deve estar presente na cena")
	assert(player != null, "Nó Player deve estar presente na cena")

	# -------------------------------------------------------------------------
	# CENÁRIO 1: Ausência de Ciclo Dia/Noite e Lanterna do Player
	# -------------------------------------------------------------------------
	print("\n--- 1. AUDITORIA: AUSÊNCIA DE CICLO DIA/NOITE E LANTERNA ---")
	var day_night = game.get("day_night_hud")
	assert(day_night == null, "DayNightCycleHUD NÃO deve existir no jogo")
	assert(player.get("belt_lantern") == null, "Player NÃO deve possuir lanterna de cinto")
	var omni_lights_in_player := player.find_children("", "OmniLight3D", true, false)
	assert(omni_lights_in_player.is_empty(), "Nenhuma luz radial presa ao jogador")
	print("[OK] Cenário 1: Dia/Noite e lanterna ausentes conforme diretriz permanente.")

	# -------------------------------------------------------------------------
	# CENÁRIO 2: Perfil 1 — Floresta Natural (Exterior) em zone_1_road
	# -------------------------------------------------------------------------
	print("\n--- 2. PERFIL 1: FLORESTA NATURAL (EXTERIOR) [zone_1_road] ---")
	game.call("load_zone", "zone_1_road")
	for _i in range(5):
		await process_frame

	assert(sun.visible == true, "Sol deve estar visível e ativo no exterior")
	assert(sun.light_energy >= 0.80 and sun.light_energy <= 1.05, "Intensidade solar moderada (0.80 - 1.05)")
	assert(sun.shadow_enabled == true, "Sombras ativadas no exterior para silhuetas reconhecíveis")
	assert(sun.shadow_blur >= 0.70 and sun.shadow_blur <= 1.8, "Sombras com bordas naturais e definidas (estilo Albion)")
	assert(world_env.environment.ambient_light_energy >= 0.30 and world_env.environment.ambient_light_energy <= 0.65, "Luz ambiente calibrada para terreno legível sob sombras de árvores sem estourar branco")
	assert(world_env.environment.tonemap_mode == Environment.TONE_MAPPER_FILMIC, "Tonemapping Filmic para evitar brancos estourados")
	print("[OK] Cenário 2: Perfil Exterior configurado com sol suave, sombras reconhecíveis e ambiente legível.")

	# -------------------------------------------------------------------------
	# CENÁRIO 3: Perfil 2 — Masmorra (Interior) em zone_3_crypt
	# -------------------------------------------------------------------------
	print("\n--- 3. PERFIL 2: MASMORRA (INTERIOR) [zone_3_crypt] ---")
	game.call("load_zone", "zone_3_crypt")
	for _i in range(5):
		await process_frame

	assert(sun.visible == false or sun.light_energy == 0.0, "Sol deve estar desativado na Masmorra")
	assert(world_env.environment.ambient_light_energy <= 0.38, "Escuridão predominante no interior (ambient_energy <= 0.38)")
	assert(world_env.environment.ambient_light_energy >= 0.10, "Cantos sombreados ainda legíveis (ambient_energy >= 0.10)")

	var local_lights_container: Node = game.get_node_or_null("RegionalLocalLights")
	assert(local_lights_container != null, "Container de luzes locais deve existir na masmorra")
	var torches := local_lights_container.find_children("", "OmniLight3D", true, false)
	assert(torches.size() >= 4, "Masmorra deve conter tochas/brazeiros distribuídos")
	for t in torches:
		var ol := t as OmniLight3D
		assert(ol.light_color.r > ol.light_color.b, "Tocha deve possuir cor âmbar/quente (r > b)")
		assert(ol.omni_attenuation > 1.0, "Atenuação suave e radial, sem borda dura circular")
	print("[OK] Cenário 3: Perfil Masmorra com ambiente sombrio, tochas quentes e atenuação gradual.")

	# -------------------------------------------------------------------------
	# CENÁRIO 4: Perfil 3 — Floresta Mágica (Temático) em zone_4_mines
	# -------------------------------------------------------------------------
	print("\n--- 4. PERFIL 3: FLORESTA MÁGICA / TEMÁTICO [zone_4_mines] ---")
	game.call("load_zone", "zone_4_mines")
	for _i in range(5):
		await process_frame

	var amb_col: Color = world_env.environment.ambient_light_color
	assert(amb_col.g > 0.35 and amb_col.b > 0.40, "Ambiente místico com tonalidade azul-esverdeada (ciano)")
	var mystic_container: Node = game.get_node_or_null("RegionalLocalLights")
	assert(mystic_container != null, "Luzes locais de santuário místico devem existir")
	var mystic_lights := mystic_container.find_children("", "OmniLight3D", true, false)
	assert(mystic_lights.size() > 0, "Pontos de luz etérea presentes")
	var ml: OmniLight3D = mystic_lights[0] as OmniLight3D
	assert(ml.light_color.b > ml.light_color.r, "Luz de santuário místico com tom ciano/azul predominante")
	print("[OK] Cenário 4: Perfil Mágico com tons azul-esverdeados e santuário radiante.")

	# -------------------------------------------------------------------------
	# CENÁRIO 5: Transição Dinâmica e Limpeza entre Perfis
	# -------------------------------------------------------------------------
	print("\n--- 5. TRANSIÇÃO DINÂMICA ENTRE ZONAS ---")
	game.call("load_zone", "town")
	for _i in range(5):
		await process_frame
	assert(sun.visible == true and sun.light_energy > 0.8, "Retorno à Vila ativa Perfil Exterior")
	var town_lights: Node = game.get_node_or_null("RegionalLocalLights")
	assert(town_lights == null or town_lights.get_child_count() == 0, "Tochas de masmorra removidas ao retornar à vila")
	print("[OK] Cenário 5: Transição entre perfis suave, determinística e sem vazamento de luzes.")

	# -------------------------------------------------------------------------
	# CENÁRIO 6: Otimização de Sombras em Modelos do MegaKit
	# -------------------------------------------------------------------------
	print("\n--- 6. OTIMIZAÇÃO DE SOMBRAS (ÁRVORES CAST / FOLHAGEM NO-CAST) ---")
	game.call("load_zone", "zone_1_road")
	for _i in range(6):
		await process_frame

	var arena_art: Node = game.get_node_or_null("ArenaArt")
	assert(arena_art != null, "ArenaArt deve existir")
	var props_root: Node = arena_art.get_node_or_null("MegaKitEnvironmentProps")
	assert(props_root != null, "MegaKitEnvironmentProps deve conter props da região")

	var trees_found := 0
	var foliage_found := 0

	for prop in props_root.get_children():
		if prop.has_method("_should_cast_shadow"):
			var cat = prop.get("category")
			var meshes := prop.find_children("", "MeshInstance3D", true, false)
			for m in meshes:
				var mi := m as MeshInstance3D
				if cat in [0, 1, 2, 3, 4]: # Árvores e Rocha Média
					assert(mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Árvores e rochas DEVEM projetar sombra")
					trees_found += 1
				else: # Grama, samambaias, flores, pedregulhos
					assert(mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Folhagem rasteira e pedrinhas NÃO devem projetar sombra (performance)")
					foliage_found += 1

	assert(trees_found > 0, "Pelo menos uma árvore projetando sombra")
	assert(foliage_found > 0, "Folhagem leve sem sombras verificada")
	print("[OK] Cenário 6: Sombras alocadas apenas em árvores (%d malhas) e dispensadas em folhagem rasteira (%d malhas)." % [trees_found, foliage_found])

	# -------------------------------------------------------------------------
	# CENÁRIO 7: Legibilidade do Terreno e Ausência de Clarão Cegante
	# -------------------------------------------------------------------------
	print("\n--- 7. LEGIBILIDADE DO TERRENO E AUSÊNCIA DE CLARÃO ---")
	var terrain: MeshInstance3D = arena_art.get_node_or_null("Terrain_Continuous_Grass_Dirt") as MeshInstance3D
	assert(terrain != null, "Terreno contínuo estilizado deve estar presente")
	assert(terrain.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Terreno recebe sombras mas não projeta")
	assert(world_env.environment.tonemap_exposure <= 1.0, "Exposição sob controle para evitar tela branca")
	print("[OK] Cenário 7: Terreno nítido com recepção de sombras sem clarão cegante.")

	# -------------------------------------------------------------------------
	# CONCLUSÃO
	# -------------------------------------------------------------------------
	print("\n==================================================================================")
	print("=== RESULTADO DA SUÍTE: 7/7 CENÁRIOS VALIDADOS COM 100% DE SUCESSO! ===")
	print(">> ARQUITETURA DE ILUMINAÇÃO E SOMBRAS POR REGIÃO APROVADA! <<\n")
	game.queue_free()
	quit(0)
