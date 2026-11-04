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
	_test_main_scene_inventory_integration()

	print("=== RESULTADO INVENTÁRIO ESPACIAL: %d PASSARAM | %d FALHARAM ===" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _test_spatial_grid_dimensions_and_collisions() -> void:
	var grid := SpatialInventoryGrid.new(10, 4)

	# 1. Espada Montante 2H (2x4)
	var sword_2h := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "greatsword_iron")
	_check(sword_2h.definition.grid_size == Vector2i(2, 4), "1. Montante 2H possui tamanho exato de 2x4 (4 de altura, 2 de largura)")

	# Encaixa no canto superior esquerdo (0, 0)
	_check(grid.can_place_at(sword_2h, Vector2i(0, 0)), "2. Montante 2x4 cabe no canto (0,0)")
	grid.place_item(sword_2h, Vector2i(0, 0))

	# Colisão: tentar colocar item que sobrepõe qualquer uma das 8 células (x=0..1, y=0..3) deve falhar
	var dagger := ItemDatabase.generate_loot(1, ItemInstance.ItemRarity.NORMAL, "dagger_sharp") # 2x2
	_check(not grid.can_place_at(dagger, Vector2i(1, 1)), "3. Colisão detectada: não permite colocar item em cima de células ocupadas")

	# Adjacente livre: colocar no (2, 0) deve funcionar
	_check(grid.can_place_at(dagger, Vector2i(2, 0)), "4. Permite colocar item em células adjacentes livres")
	grid.place_item(dagger, Vector2i(2, 0))

	# Limite da matriz: tentar colocar item fora das bordas (ex: 2x4 na posição x=9 ou y=2 em grade de 4 linhas)
	_check(not grid.can_place_at(sword_2h, Vector2i(9, 0)), "5a. Bloqueia item extrapolando colunas (x=9 para largura 2)")
	_check(not grid.can_place_at(sword_2h, Vector2i(4, 2)), "5b. Bloqueia item extrapolando linhas (y=2 para altura 4 em grade de 4 linhas)")

	# Remoção limpa todas as células ocupadas
	grid.remove_item(sword_2h)
	_check(grid.can_place_at(sword_2h, Vector2i(0, 0)), "6. Remoção de item libera perfeitamente as 8 células ocupadas no grid")


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
	var def_2x2: ItemDefinition = cat["helm_iron"]
	var def_2x3: ItemDefinition = cat["chest_plate"]
	var def_2x4: ItemDefinition = cat["greatsword_iron"]

	var tex_1x1 := ItemIconFactory.get_icon(def_1x1)
	var tex_2x2 := ItemIconFactory.get_icon(def_2x2)
	var tex_2x3 := ItemIconFactory.get_icon(def_2x3)
	var tex_2x4 := ItemIconFactory.get_icon(def_2x4)

	_check(tex_1x1 != null and tex_1x1.get_width() == 32 and tex_1x1.get_height() == 32, "14a. Ícone 1x1 gerado com 32x32 pixels")
	_check(tex_2x2 != null and tex_2x2.get_width() == 64 and tex_2x2.get_height() == 64, "14b. Ícone 2x2 gerado com 64x64 pixels")
	_check(tex_2x3 != null and tex_2x3.get_width() == 64 and tex_2x3.get_height() == 96, "14c. Ícone 2x3 gerado com 64x96 pixels")
	_check(tex_2x4 != null and tex_2x4.get_width() == 64 and tex_2x4.get_height() == 128, "14d. Ícone 2x4 (Montante) gerado com 64x128 pixels")


func _test_main_scene_inventory_integration() -> void:
	var main_node = MAIN_SCENE.instantiate()
	root.add_child(main_node)

	_check(main_node.backpack != null, "15. Mochila espacial (backpack 10x4) inicializada na Main")
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
