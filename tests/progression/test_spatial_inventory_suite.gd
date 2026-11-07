extends SceneTree
## Suite de Testes do Sistema de Itens & Inventário Espacial em Grid (Diablo 2 / PoE)
## Executar: Godot_v4.7.2-stable_win64_console.exe --headless --path "c:\Users\mathh\OneDrive\Documents\jogo" --script res://tests/progression/test_spatial_inventory_suite.gd

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ITEM_DEF = preload("res://core/items/item_definition.gd")
const ITEM_INST = preload("res://core/items/item_instance.gd")
const ITEM_DB = preload("res://core/items/item_database.gd")
const SPATIAL_GRID = preload("res://core/items/spatial_inventory_grid.gd")
const CHAR_EQUIP = preload("res://core/items/character_equipment.gd")
const ICON_FACTORY = preload("res://game/ui/items/item_icon_factory.gd")

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
	print("=== INICIANDO SUITE DE TESTES: ITENS & INVENTÁRIO ESPACIAL (GRID ARPG) ===")
	_test_spatial_grid_dimensions_and_collisions()
	_test_equipment_paperdoll_and_2h_weapons()
	_test_stat_requirements_without_manual_points()
	_test_item_identification_and_rarity()
	_test_icon_procedural_generation_all_sizes()
	_test_tooltip_comparison_and_npc_stash()
	_test_main_scene_inventory_integration()

	print("=== RESULTADO INVENTÁRIO ESPACIAL: %d PASSARAM | %d FALHARAM ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_spatial_grid_dimensions_and_collisions() -> void:
	var grid := SpatialInventoryGrid.new(10, 4)

	# 1. Espada Montante 2H (3x2 deitada por padrão, gira para 2x3 em pé)
	var sword_2h := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "greatsword_iron")
	_check(sword_2h.definition.grid_size == Vector2i(3, 2), "1a. Montante 2H possui tamanho base exato de 3x2 (3 colunas x 2 linhas)")
	_check(sword_2h.get_grid_size() == Vector2i(3, 2), "1b. Montante 2H inicia deitada (3x2) no inventário")

	# Encaixa no canto superior esquerdo (0, 0)
	_check(grid.can_place_at(sword_2h, Vector2i(0, 0)), "2. Montante 3x2 cabe no canto (0,0)")
	grid.place_item(sword_2h, Vector2i(0, 0))

	# Colisão: tentar colocar item que sobrepõe qualquer uma das 6 células (x=0..2, y=0..1) deve falhar
	var dagger := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "dagger_sharp") # 1x3
	_check(not grid.can_place_at(dagger, Vector2i(2, 1)), "3. Colisão detectada: não permite colocar item em cima de células ocupadas")

	# Adjacente livre: colocar no (3, 0) deve funcionar
	_check(grid.can_place_at(dagger, Vector2i(3, 0)), "4. Permite colocar item em células adjacentes livres")
	grid.place_item(dagger, Vector2i(3, 0))

	# Limite da matriz: tentar colocar item 3x2 fora das bordas (ex: x=8 em grade de 10 colunas ou y=3 em grade de 4 linhas)
	_check(not grid.can_place_at(sword_2h, Vector2i(8, 0)), "5a. Bloqueia item extrapolando colunas (x=8 para largura 3)")
	_check(not grid.can_place_at(sword_2h, Vector2i(4, 3)), "5b. Bloqueia item extrapolando linhas (y=3 para altura 2 em grade de 4 linhas)")

	# Teste de Rotação (3x2 deitado -> 2x3 em pé) direto no grid
	var rotated_ok: bool = grid.rotate_item_in_place(sword_2h)
	_check(rotated_ok and sword_2h.is_rotated and sword_2h.get_grid_size() == Vector2i(2, 3), "5c. Rotação de item no grid altera tamanho de 3x2 (deitado) para 2x3 (em pé)")

	# Remoção limpa todas as células ocupadas
	grid.remove_item(sword_2h)
	_check(grid.can_place_at(sword_2h, Vector2i(0, 0)), "6. Remoção de item libera perfeitamente as células ocupadas no grid")


func _test_equipment_paperdoll_and_2h_weapons() -> void:
	var equip := CharacterEquipment.new()
	var stats := CharacterStats.new()
	stats.set_base_stat(CharacterStats.STAT_STRENGTH, 25.0) # Força suficiente para equipar 2H (req 24)

	var sword_1h := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "sword_steel")
	var shield := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "shield_round")
	var sword_2h := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "greatsword_iron")

	# Equipa espada 1H e escudo simultaneamente
	equip.equip_item(sword_1h, ItemDefinition.EquipmentSlot.MAIN_HAND, stats)
	equip.equip_item(shield, ItemDefinition.EquipmentSlot.OFF_HAND, stats)
	_check(equip.get_equipped_item(ItemDefinition.EquipmentSlot.MAIN_HAND) == sword_1h, "7a. Espada 1H equipada na Mão Principal")
	_check(equip.get_equipped_item(ItemDefinition.EquipmentSlot.OFF_HAND) == shield, "7b. Escudo equipado na Mão Secundária")

	# Ao equipar arma de duas mãos (2H), o escudo é desequipado automaticamente!
	equip.equip_item(sword_2h, ItemDefinition.EquipmentSlot.MAIN_HAND, stats)
	_check(equip.get_equipped_item(ItemDefinition.EquipmentSlot.MAIN_HAND) == sword_2h, "8a. Arma 2H substituiu espada na Mão Principal")
	_check(equip.get_equipped_item(ItemDefinition.EquipmentSlot.OFF_HAND) == null, "8b. Escudo foi automaticamente desequipado ao equipar arma 2H")


func _test_stat_requirements_without_manual_points() -> void:
	var equip := CharacterEquipment.new()
	var stats := CharacterStats.new()
	# Guerreiro base com Força 20
	stats.set_base_stat(CharacterStats.STAT_STRENGTH, 20.0)

	var heavy_plate := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "chest_plate")
	# Requer Força 22
	heavy_plate.definition.req_strength = 24

	# Com Força 20, não pode equipar
	_check(not equip.can_equip(heavy_plate, ItemDefinition.EquipmentSlot.CHEST, stats), "9. Bloqueia equipar item quando o personagem não tem os requisitos de atributo")

	# Equipa um anel que concede +6 de Força (o que eleva a Força total para 26)
	var ring := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.MAGIC, "ring_ruby")
	ring.explicit_affixes.clear()
	ring.explicit_affixes.append(ItemAffix.create("test_str", ItemAffix.AffixType.PREFIX, "strength", 6.0, "+6 de Força"))
	equip.equip_item(ring, ItemDefinition.EquipmentSlot.RING_1, stats)

	_check(int(roundi(stats.get_stat(&"strength"))) == 26, "10. Anel equipado concede +6 de Força elevando o total para 26")
	# Agora o peitoral de 24 Força PODE ser equipado!
	_check(equip.can_equip(heavy_plate, ItemDefinition.EquipmentSlot.CHEST, stats), "11. Com a Força do anel, o Peitoral Pesado cumpre os requisitos e pode ser equipado sem botões manuais")


func _test_item_identification_and_rarity() -> void:
	var rare_item := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.RARE)
	_check(not rare_item.is_identified, "12a. Item Raro dropa como Não-Identificado")
	_check(rare_item.get_display_name() == "Item Raro Não-Identificado", "12b. Nome oculto exibe 'Não-Identificado' antes de inspecionar")

	rare_item.identify()
	_check(rare_item.is_identified, "13a. Identificação revela o item")
	_check(rare_item.get_display_name() != "Item Raro Não-Identificado", "13b. Nome revelado com título épico procedimental")
	_check(rare_item.explicit_affixes.size() >= 3, "13c. Item Raro contém 3 ou mais afixos revelados")


func _test_icon_procedural_generation_all_sizes() -> void:
	var cat: Dictionary = ItemDatabase.get_catalog()
	var def_1x1: ItemDefinition = cat["ring_ruby"]
	var def_1x3: ItemDefinition = cat["dagger_sharp"]
	var def_1x4: ItemDefinition = cat["sword_steel"]
	var def_2x2: ItemDefinition = cat["helm_iron"]
	var def_2x4: ItemDefinition = cat["chest_plate"]

	var tex_1x1 := ItemIconFactory.get_icon(def_1x1)
	var tex_1x3 := ItemIconFactory.get_icon(def_1x3)
	var tex_1x4 := ItemIconFactory.get_icon(def_1x4)
	var tex_2x2 := ItemIconFactory.get_icon(def_2x2)
	var tex_2x4 := ItemIconFactory.get_icon(def_2x4)

	_check(tex_1x1 != null and tex_1x1.get_width() == 32 and tex_1x1.get_height() == 32, "14a. Ícone 1x1 (Anel) gerado com 32x32 pixels")
	_check(tex_1x3 != null and tex_1x3.get_width() == 32 and tex_1x3.get_height() == 96, "14b. Ícone 1x3 (Adaga fina) gerado com 32x96 pixels")
	_check(tex_1x4 != null and tex_1x4.get_width() == 32 and tex_1x4.get_height() == 128, "14c. Ícone 1x4 (Espada 1H) gerado com 32x128 pixels")
	_check(tex_2x2 != null and tex_2x2.get_width() == 64 and tex_2x2.get_height() == 64, "14d. Ícone 2x2 (Elmo/Luva/Bota) gerado com 64x64 pixels")
	_check(tex_2x4 != null and tex_2x4.get_width() == 64 and tex_2x4.get_height() == 128, "14e. Ícone 2x4 (Peitoral) gerado com 64x128 pixels")

	# Teste do novo sprite 3x2 da Espada de 2 Mãos (deitada no grid vs em pé quando girada ou equipada)
	var gs_item := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "greatsword_iron")
	var tex_gs_horiz := ItemIconFactory.get_icon_for_item(gs_item, false)
	var tex_gs_paperdoll := ItemIconFactory.get_icon_for_item(gs_item, true)
	gs_item.toggle_rotation()
	var tex_gs_rot := ItemIconFactory.get_icon_for_item(gs_item, false)
	_check(tex_gs_horiz != null and tex_gs_horiz.get_width() > tex_gs_horiz.get_height(), "14f. Sprite da Espada 2H 3x2 inicia deitado (largura > altura) no inventário")
	_check(tex_gs_rot != null and tex_gs_rot.get_height() > tex_gs_rot.get_width(), "14g. Sprite da Espada 2H fica em pé (altura > largura) ao girar no inventário")
	_check(tex_gs_paperdoll != null and tex_gs_paperdoll.get_height() > tex_gs_paperdoll.get_width(), "14h. Sprite da Espada 2H vai automaticamente em pé quando equipado no Paperdoll")


func _test_main_scene_inventory_integration() -> void:
	var main_node = MAIN_SCENE.instantiate()
	root.add_child(main_node)

	_check(main_node.backpack != null and main_node.backpack.columns == 10 and main_node.backpack.rows == 6, "15. Mochila espacial (backpack 10x6) inicializada na Main")
	_check(main_node.equipment != null, "16. Gerenciador de Equipamento (Paperdoll) inicializado")
	_check(main_node.inventory_modal != null, "17. Modal de Inventário & Paperdoll adicionado ao HUD")
	_check(main_node.backpack.items.size() >= 5, "18. Itens de partida foram distribuídos na mochila para teste imediato")

	# Teste de Toggle [I]
	_check(not main_node.inventory_modal.visible, "19a. Inventário inicia fechado")
	main_node.inventory_modal.open_inventory()
	_check(main_node.inventory_modal.visible, "19b. Inventário abre com open_inventory()")
	main_node.inventory_modal.close_inventory()
	_check(not main_node.inventory_modal.visible, "19c. Inventário fecha com close_inventory()")

	main_node.queue_free()


func _test_tooltip_comparison_and_npc_stash() -> void:
	var equip := CharacterEquipment.new()
	var stats := CharacterStats.new()
	stats.set_base_stat(CharacterStats.STAT_STRENGTH, 30.0)
	stats.set_base_stat(CharacterStats.STAT_AGILITY, 20.0)

	# Equipa uma espada 1H com +20 de Vida
	var equipped_sword := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.MAGIC, "sword_steel")
	equipped_sword.identify()
	equipped_sword.explicit_affixes.clear()
	equipped_sword.explicit_affixes.append(ItemAffix.create("hp_eq", ItemAffix.AffixType.PREFIX, "max_health", 20.0, "+20 de Vida"))
	equip.equip_item(equipped_sword, ItemDefinition.EquipmentSlot.MAIN_HAND, stats)

	# Inspeciona uma Espada Montante 2H com +8 de Força (maior dano, perde os +20 de Vida da espada equipada!)
	var candidate_2h := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.MAGIC, "greatsword_iron")
	candidate_2h.identify()
	candidate_2h.explicit_affixes.clear()
	candidate_2h.explicit_affixes.append(ItemAffix.create("str_new", ItemAffix.AffixType.SUFFIX, "strength", 8.0, "+8 de Força"))

	var bbcode: String = candidate_2h.format_tooltip_bbcode(stats, equip, "[Clique Direito: Equipar]")
	_check(bbcode.contains("▲") and bbcode.contains("#4dff6b"), "20a. Tooltip exibe seta verde ▲ nas linhas em que o item é superior")
	_check(bbcode.contains("▼") and bbcode.contains("#ff4d4d"), "20b. Tooltip exibe seta vermelha ▼ nas linhas/comparações em que perde status")
	_check(bbcode.contains("Ganha +8 de Força") and bbcode.contains("Perde -20 de Vida Máxima"), "20c. Área dedicada de comparação exibe ganhos (verde) e o atributo perdido que não existe no item novo (vermelho)")
