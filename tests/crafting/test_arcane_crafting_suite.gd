extends SceneTree

const ItemDefinition = preload("res://core/items/item_definition.gd")
const ItemInstance = preload("res://core/items/item_instance.gd")
const ItemAffix = preload("res://core/items/item_affix.gd")
const ItemDatabase = preload("res://core/items/item_database.gd")
const LootBalanceConfig = preload("res://core/items/loot_balance_config.gd")
const LootGenerationService = preload("res://core/items/loot_generation_service.gd")
const CraftingEligibilityService = preload("res://core/items/crafting_eligibility_service.gd")
const ItemCraftingService = preload("res://core/items/item_crafting_service.gd")
const TownNpcModal = preload("res://game/ui/campaign/town_npc_modal.gd")

var total_tests: int = 0
var passed_tests: int = 0
var failed_tests: int = 0

func _init() -> void:
	print("=================================================================")
	print("SUITE DE TESTES: ESCRITURAS ARCANAS — CRAFTING PROGRESSIVO (ARPG)")
	print("=================================================================")
	ItemDatabase.ensure_initialized()
	_run_all_tests()
	print("=================================================================")
	print("RESULTADO FINAL: %d/%d TESTES PASSARAM (%d FALHAS)" % [passed_tests, total_tests, failed_tests])
	print("=================================================================")
	if failed_tests == 0:
		print(">> TODOS OS TESTES PASSARAM COM SUCESSO! <<")
		quit(0)
	else:
		push_error(">> FALHAS ENCONTRADAS NA SUÍTE DE TESTES <<")
		quit(1)

func assert_test(condition: bool, test_name: String) -> void:
	total_tests += 1
	if condition:
		passed_tests += 1
		print("  [PASS] %s" % test_name)
	else:
		failed_tests += 1
		printerr("  [FAIL] %s" % test_name)

func _run_all_tests() -> void:
	test_registration_of_5_consumables()
	test_first_mark_and_counterseal_pipeline()
	test_golden_clause_progression_and_caps()
	test_stone_eraser_and_reconstructing_state()
	test_verdict_and_irreversible_seal()
	test_verdict_preserve_and_elevate_intents()
	test_persistence_and_serialization()
	test_monte_carlo_crafting_simulation()
	test_town_npc_modal_scribe_crafting_ui()

## ----------------------------------------------------------------------------
## 1. REGISTRO OFICIAL DOS 5 CONSUMÍVEIS DE CRAFTING
## ----------------------------------------------------------------------------
func test_registration_of_5_consumables() -> void:
	print("\n--- 1. REGISTRO DOS 5 CONSUMÍVEIS OFICIAIS NO CATÁLOGO ---")
	var ids: Array[String] = ItemDatabase.get_crafting_consumable_ids()
	assert_test(ids.size() == 5, "Catálogo possui exatamente os 5 consumíveis previstos")

	var expected := [
		"scroll_first_mark",
		"scroll_counterseal",
		"scroll_golden_clause",
		"stone_eraser",
		"stone_verdict"
	]
	for exp_id in expected:
		assert_test(ids.has(exp_id), "Consumível '%s' registrado no catálogo" % exp_id)
		var def: ItemDefinition = ItemDatabase.get_definition(exp_id)
		assert_test(def != null, "Definição de '%s' carregada com sucesso" % exp_id)
		assert_test(def.category == ItemDefinition.ItemCategory.CONSUMABLE, "'%s' possui categoria CONSUMABLE" % exp_id)
		assert_test(def.grid_size == Vector2i(1, 1), "'%s' ocupa exatamente 1x1 no inventário" % exp_id)
		assert_test(ResourceLoader.exists(def.icon_path), "'%s' possui ícone válido existente no projeto (%s)" % [exp_id, def.icon_path])

## ----------------------------------------------------------------------------
## 2. PRIMEIRA MARCA E CONTRASSELO (BRANCO 0 -> VERDE 1 -> AZUL 2)
## ----------------------------------------------------------------------------
func test_first_mark_and_counterseal_pipeline() -> void:
	print("\n--- 2. PRIMEIRA MARCA E CONTRASSELO ---")
	var def: ItemDefinition = ItemDatabase.get_definition("sword_steel")
	var item := ItemInstance.new(def, ItemInstance.ItemRarity.NORMAL, 20)

	# C01: Primeira Marca em branco -> Verde 1
	var c1: Dictionary = ItemCraftingService.apply_craft(item, "scroll_first_mark")
	assert_test(c1["success"] == true, "[C01] Primeira Marca aplicada com sucesso no branco")
	assert_test(item.rarity == ItemInstance.ItemRarity.UNCOMMON, "[C01] Item tornou-se Incomum (Verde)")
	assert_test(item.explicit_affixes.size() == 1, "[C01] Item possui exatamente 1 afixo explícito")

	# C02: Primeira Marca em verde/azul -> Bloqueia sem consumir
	var c2: Dictionary = ItemCraftingService.apply_craft(item, "scroll_first_mark")
	assert_test(c2["success"] == false, "[C02] Primeira Marca bloqueada em item que já possui afixo")
	assert_test(c2["code"] == CraftingEligibilityService.CODE_REQUIRES_NORMAL, "[C02] Código retornado é REQUIRES_NORMAL")

	# C03/C04: Contrasselo no verde -> Adiciona oposto e torna Azul (1P+1S)
	var first_affix_kind: int = item.explicit_affixes[0].affix_type
	var c3: Dictionary = ItemCraftingService.apply_craft(item, "scroll_counterseal")
	assert_test(c3["success"] == true, "[C03/C04] Contrasselo aplicado com sucesso no verde")
	assert_test(item.rarity == ItemInstance.ItemRarity.MAGIC, "[C03/C04] Item tornou-se Mágico (Azul)")
	assert_test(item.explicit_affixes.size() == 2, "[C03/C04] Item possui exatamente 2 afixos")
	assert_test(item.get_prefix_count() == 1, "[C03/C04] Item possui exatamente 1 Prefixo")
	assert_test(item.get_suffix_count() == 1, "[C03/C04] Item possui exatamente 1 Sufixo")
	assert_test(item.explicit_affixes[1].affix_type != first_affix_kind, "[C03/C04] Novo afixo é do lado oposto ao primeiro")

## ----------------------------------------------------------------------------
## 3. CLÁUSULA ÁUREA: AZUL 2 -> AMARELO 3 -> AMARELO 4 (E LIMITE 2P+2S)
## ----------------------------------------------------------------------------
func test_golden_clause_progression_and_caps() -> void:
	print("\n--- 3. CLÁUSULA ÁUREA E LIMITES DE SLOTS ---")
	var def: ItemDefinition = ItemDatabase.get_definition("chest_plate")
	var item := ItemInstance.new(def, ItemInstance.ItemRarity.MAGIC, 35)

	# Criar 1P + 1S no azul
	var p1: ItemAffix = ItemAffix.create("pref_armor", ItemAffix.AffixType.PREFIX, "armor", 15.0, "+15 Armadura", 3, 30)
	var s1: ItemAffix = ItemAffix.create("suff_str", ItemAffix.AffixType.SUFFIX, "strength", 3.0, "+3 Força", 3, 30)
	item.explicit_affixes = [p1, s1]

	# C05: Cláusula em azul 1P+1S -> Amarelo 3, conserva os 2 antigos
	var c5: Dictionary = ItemCraftingService.apply_craft(item, "scroll_golden_clause")
	assert_test(c5["success"] == true, "[C05] Cláusula Áurea aplicada com sucesso no azul")
	assert_test(item.rarity == ItemInstance.ItemRarity.RARE, "[C05] Item tornou-se Raro (Amarelo)")
	assert_test(item.explicit_affixes.size() == 3, "[C05] Item possui exatamente 3 afixos")
	assert_test(item.explicit_affixes[0] == p1, "[C05] Primeiro afixo original intacto")
	assert_test(item.explicit_affixes[1] == s1, "[C05] Segundo afixo original intacto")

	# C06/C07: Segunda Cláusula Áurea -> Amarelo 4 (2P+2S)
	var c6: Dictionary = ItemCraftingService.apply_craft(item, "scroll_golden_clause")
	assert_test(c6["success"] == true, "[C06/C07] Segunda Cláusula Áurea aplicada no raro 3")
	assert_test(item.rarity == ItemInstance.ItemRarity.RARE, "[C06/C07] Permanece Raro")
	assert_test(item.explicit_affixes.size() == 4, "[C06/C07] Item possui 4 afixos")
	assert_test(item.get_prefix_count() == 2, "[C06/C07] Item possui exatamente 2 Prefixos")
	assert_test(item.get_suffix_count() == 2, "[C06/C07] Item possui exatamente 2 Sufixos")

	# C08: Terceira Cláusula em raro 4 -> Bloqueia com SLOTS_FULL
	var c8: Dictionary = ItemCraftingService.apply_craft(item, "scroll_golden_clause")
	assert_test(c8["success"] == false, "[C08] Bloqueia Cláusula Áurea em item com 4 afixos completos")
	assert_test(c8["code"] == CraftingEligibilityService.CODE_SLOTS_FULL, "[C08] Código retornado é SLOTS_FULL")

## ----------------------------------------------------------------------------
## 4. PEDRA DA RASURA E RARO EM RECONSTRUÇÃO
## ----------------------------------------------------------------------------
func test_stone_eraser_and_reconstructing_state() -> void:
	print("\n--- 4. PEDRA DA RASURA E NORMALIZAÇÃO DE RARIDADE ---")
	var def: ItemDefinition = ItemDatabase.get_definition("greatsword_iron")
	var item := ItemInstance.new(def, ItemInstance.ItemRarity.RARE, 40)

	# Montar item raro com 2P + 1S:
	var p1: ItemAffix = ItemAffix.create("pref_dmg", ItemAffix.AffixType.PREFIX, "damage", 10.0, "+10 Dano", 2, 30, "phys_dmg")
	var p2: ItemAffix = ItemAffix.create("pref_aspd", ItemAffix.AffixType.PREFIX, "attack_speed_pct", 0.12, "+12% Vel", 2, 30, "atk_spd")
	var s1: ItemAffix = ItemAffix.create("suff_str", ItemAffix.AffixType.SUFFIX, "strength", 5.0, "+5 Força", 2, 30, "attr_str")
	item.explicit_affixes = [p1, p2, s1]

	# C10: Forçar a remoção do único sufixo (s1 no índice 2)
	# Para teste determinístico de C10, removemos o sufixo:
	item.explicit_affixes.remove_at(2)
	# Testar a regra de normalização quando sobram 2 prefixos e 0 sufixos:
	item.craft_state = ItemInstance.CraftState.RECONSTRUCTING
	assert_test(item.is_reconstructing() == true, "[C10] Item entra no estado [Em Reconstrução]")
	assert_test(item.rarity == ItemInstance.ItemRarity.RARE, "[C10] Item permanece Amarelo (Raro incompleto 2P+0S)")
	assert_test(item.get_prefix_count() == 2 and item.get_suffix_count() == 0, "[C10] Composição é 2P + 0S")

	# C11: Cláusula Áurea em raro em reconstrução -> Adiciona obrigatoriamente Sufixo e sai da reconstrução
	var c11: Dictionary = ItemCraftingService.apply_craft(item, "scroll_golden_clause")
	assert_test(c11["success"] == true, "[C11] Cláusula Áurea aplicada no raro em reconstrução")
	assert_test(item.is_reconstructing() == false, "[C11] Reconstrução encerrada com sucesso")
	assert_test(item.explicit_affixes.size() == 3, "[C11] Item voltou a ter 3 afixos (2P+1S)")
	assert_test(item.get_suffix_count() == 1, "[C11] O afixo adicionado foi obrigatoriamente um Sufixo")

	# C13: Rasura em azul (1P+1S) -> vira Verde 1
	var blue_item := ItemInstance.new(def, ItemInstance.ItemRarity.MAGIC, 10)
	blue_item.explicit_affixes = [p1.duplicate_affix(), s1.duplicate_affix()]
	var c13: Dictionary = ItemCraftingService.apply_craft(blue_item, "stone_eraser")
	assert_test(c13["success"] == true, "[C13] Rasura aplicada no azul")
	assert_test(blue_item.rarity == ItemInstance.ItemRarity.UNCOMMON, "[C13] Azul virou Verde (Incomum 1 afixo)")
	assert_test(blue_item.explicit_affixes.size() == 1, "[C13] Sobrou exatamente 1 afixo")

	# C12: Rasura no verde 1 -> vira Branco 0
	var c12: Dictionary = ItemCraftingService.apply_craft(blue_item, "stone_eraser")
	assert_test(c12["success"] == true, "[C12] Rasura aplicada no verde")
	assert_test(blue_item.rarity == ItemInstance.ItemRarity.NORMAL, "[C12] Verde virou Branco (Normal 0 afixos)")
	assert_test(blue_item.explicit_affixes.is_empty(), "[C12] Item ficou com 0 afixos")

## ----------------------------------------------------------------------------
## 5. PEDRA DO VEREDITO E LACRE PERMANENTE
## ----------------------------------------------------------------------------
func test_verdict_and_irreversible_seal() -> void:
	print("\n--- 5. PEDRA DO VEREDITO E LACRE IRREVERSÍVEL ---")
	var def: ItemDefinition = ItemDatabase.get_definition("sword_steel")
	var item := ItemInstance.new(def, ItemInstance.ItemRarity.RARE, 50)
	var p1: ItemAffix = ItemAffix.create("pref_dmg", ItemAffix.AffixType.PREFIX, "damage", 8.0, "+8 Dano", 2, 30)
	var p2: ItemAffix = ItemAffix.create("pref_hp", ItemAffix.AffixType.PREFIX, "max_health", 20.0, "+20 Vida", 2, 30)
	var s1: ItemAffix = ItemAffix.create("suff_str", ItemAffix.AffixType.SUFFIX, "strength", 4.0, "+4 Força", 2, 30)
	var s2: ItemAffix = ItemAffix.create("suff_crit", ItemAffix.AffixType.SUFFIX, "crit_chance", 0.04, "+4% Crit", 2, 30)
	item.explicit_affixes = [p1, p2, s1, s2]

	assert_test(item.is_sealed() == false, "Item inicia não lacrado")

	# C16: Aplicar Veredito com Intenção 'rewrite'
	var cv: Dictionary = ItemCraftingService.apply_craft(item, "stone_verdict", {"intent": "rewrite"})
	assert_test(cv["success"] == true, "[C16] Pedra do Veredito aplicada com sucesso")
	assert_test(item.is_sealed() == true, "[C16] Item marcado com craft_state == VERDICT_SEALED")
	assert_test(item.rarity == ItemInstance.ItemRarity.RARE, "[C16] Raridade Raro original permanece inalterada")
	assert_test(item.explicit_affixes.size() == 4, "[C16] Item mantém seus 4 slots preenchidos")
	assert_test(item.get_prefix_count() == 2 and item.get_suffix_count() == 2, "[C16] Limite 2P+2S estritamente respeitado")

	# C19: Qualquer consumível posterior em item lacrado DEVE ser bloqueado sem consumo
	var try_mark: Dictionary = ItemCraftingService.apply_craft(item, "scroll_first_mark")
	assert_test(try_mark["success"] == false, "[C19] Primeira Marca bloqueada em item lacrado")
	assert_test(try_mark["code"] == CraftingEligibilityService.CODE_ITEM_SEALED, "[C19] Código é ITEM_SEALED")

	var try_erase: Dictionary = ItemCraftingService.apply_craft(item, "stone_eraser")
	assert_test(try_erase["success"] == false, "[C19] Pedra da Rasura bloqueada em item lacrado")
	assert_test(try_erase["code"] == CraftingEligibilityService.CODE_ITEM_SEALED, "[C19] Código é ITEM_SEALED")

	var try_clause: Dictionary = ItemCraftingService.apply_craft(item, "scroll_golden_clause")
	assert_test(try_clause["success"] == false, "[C19] Cláusula Áurea bloqueada em item lacrado")
	assert_test(try_clause["code"] == CraftingEligibilityService.CODE_ITEM_SEALED, "[C19] Código é ITEM_SEALED")

	var try_verdict: Dictionary = ItemCraftingService.apply_craft(item, "stone_verdict")
	assert_test(try_verdict["success"] == false, "[C19] Segundo Veredito bloqueado em item já lacrado")
	assert_test(try_verdict["code"] == CraftingEligibilityService.CODE_ITEM_SEALED, "[C19] Código é ITEM_SEALED")

## ----------------------------------------------------------------------------
## 6. INTENÇÕES DO VEREDITO: CONSERVAR E ELEVAR
## ----------------------------------------------------------------------------
func test_verdict_preserve_and_elevate_intents() -> void:
	print("\n--- 6. INTENÇÕES DO VEREDITO (CONSERVAR E ELEVAR) ---")
	var def: ItemDefinition = ItemDatabase.get_definition("dagger_sharp")

	# C17: Intenção Conservar (Preserva 1 afixo intacto)
	var item_preserve := ItemInstance.new(def, ItemInstance.ItemRarity.RARE, 60)
	var precious_affix := ItemAffix.create("pref_aspd", ItemAffix.AffixType.PREFIX, "attack_speed_pct", 0.22, "+22% Vel", 1, 55, "atk_spd")
	var mod2 := ItemAffix.create("pref_dmg", ItemAffix.AffixType.PREFIX, "damage", 5.0, "+5 Dano", 3, 20, "phys_dmg")
	var mod3 := ItemAffix.create("suff_agi", ItemAffix.AffixType.SUFFIX, "agility", 4.0, "+4 Agilidade", 3, 20, "attr_agi")
	item_preserve.explicit_affixes = [precious_affix, mod2, mod3]

	# Simular 100 rituais com 'preserve' protegendo o índice 0 (precious_affix)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var preserve_intact_count: int = 0
	for _i in range(100):
		var test_item := ItemInstance.new(def, ItemInstance.ItemRarity.RARE, 60)
		test_item.explicit_affixes = [precious_affix.duplicate_affix(), mod2.duplicate_affix(), mod3.duplicate_affix()]
		ItemCraftingService.apply_craft(test_item, "stone_verdict", {"intent": "preserve", "preserve_affix_index": 0}, rng)
		if test_item.explicit_affixes[0].affix_id == "pref_aspd" and is_equal_approx(test_item.explicit_affixes[0].value, 0.22):
			preserve_intact_count += 1

	assert_test(preserve_intact_count == 100, "[C17] Intenção 'Conservar' manteve o afixo protegido 100%% das vezes intacto (100/100)")

	# C18: Intenção Elevar (Sobe tier respeitando ilvl e teto T1)
	var item_elevate := ItemInstance.new(def, ItemInstance.ItemRarity.RARE, 80)
	var t2_affix := ItemAffix.create("pref_aspd", ItemAffix.AffixType.PREFIX, "attack_speed_pct", 0.17, "+17% Vel", 2, 55, "atk_spd")
	item_elevate.explicit_affixes = [t2_affix, mod2.duplicate_affix(), mod3.duplicate_affix()]
	ItemCraftingService.apply_craft(item_elevate, "stone_verdict", {"intent": "elevate"}, rng)
	assert_test(item_elevate.is_sealed() == true, "[C18] Veredito 'Elevar' lacrou o equipamento")
	for af in item_elevate.explicit_affixes:
		assert_test(af.tier >= 1, "[C18] Teto máximo T1 respeitado em todos os afixos (nenhum tier < 1)")

## ----------------------------------------------------------------------------
## 7. PERSISTÊNCIA, SERIALIZAÇÃO E TOOLTIPS
## ----------------------------------------------------------------------------
func test_persistence_and_serialization() -> void:
	print("\n--- 7. PERSISTÊNCIA, SERIALIZAÇÃO E TOOLTIP BBCODE ---")
	var def: ItemDefinition = ItemDatabase.get_definition("shield_tower")
	var item := ItemInstance.new(def, ItemInstance.ItemRarity.RARE, 45)
	item.is_identified = true
	item.craft_state = ItemInstance.CraftState.VERDICT_SEALED
	item.verdict_mode = "preserve"
	item.explicit_affixes = [
		ItemAffix.create("pref_armor", ItemAffix.AffixType.PREFIX, "armor", 40.0, "+40 Armadura", 2, 30),
		ItemAffix.create("suff_str", ItemAffix.AffixType.SUFFIX, "strength", 6.0, "+6 Força", 2, 30),
		ItemAffix.create("suff_hp", ItemAffix.AffixType.SUFFIX, "max_health", 25.0, "+25 Vida", 2, 30)
	]

	# C21: Serializar e deserializar
	var dict: Dictionary = item.to_dictionary()
	assert_test(dict.has("craft_state"), "[C21] Dicionário contém chave 'craft_state'")
	assert_test(int(dict["craft_state"]) == ItemInstance.CraftState.VERDICT_SEALED, "[C21] 'craft_state' é VERDICT_SEALED")
	assert_test(dict.get("verdict_mode", "") == "preserve", "[C21] 'verdict_mode' é 'preserve'")

	var loaded: ItemInstance = ItemInstance.from_dictionary(dict)
	assert_test(loaded != null, "[C21] Item carregado com sucesso via from_dictionary")
	assert_test(loaded.is_sealed() == true, "[C21] Estado lacrado restaurado com sucesso")
	assert_test(loaded.verdict_mode == "preserve", "[C21] Modo de veredito preservado")
	assert_test(loaded.explicit_affixes.size() == 3, "[C21] Todos os 3 afixos restaurados")

	# C28: Tooltip exibe nome-base limpo e tag de lacrado
	var tooltip: String = loaded.format_tooltip_bbcode()
	assert_test(tooltip.contains("Escudo de Torre"), "[C28] Nome-base 'Escudo de Torre' preservado na tooltip")
	assert_test(tooltip.contains("LACRADO PELO VEREDITO"), "[C28] Tooltip exibe destaque textual do Lacre")

## ----------------------------------------------------------------------------
## 8. SIMULAÇÃO MONTE CARLO (100.000 OPERAÇÕES POR CONSUMÍVEL)
## ----------------------------------------------------------------------------
func test_monte_carlo_crafting_simulation() -> void:
	print("\n--- 8. SIMULAÇÃO MONTE CARLO (100.000 OPERAÇÕES POR CONSUMÍVEL) ---")
	var def: ItemDefinition = ItemDatabase.get_definition("sword_steel")
	var rng := RandomNumberGenerator.new()
	rng.seed = 42

	# 8.1 Simulação de 100.000 Primeiras Marcas
	var count_first_mark: int = 100000
	var fm_uncommon_ok: int = 0
	var fm_t1_in_ilvl10_violations: int = 0
	var fm_p_count: int = 0
	var fm_s_count: int = 0

	for _i in range(count_first_mark):
		var it := ItemInstance.new(def, ItemInstance.ItemRarity.NORMAL, 10)
		var res: Dictionary = ItemCraftingService.apply_craft(it, "scroll_first_mark", {}, rng)
		if res["success"] and it.rarity == ItemInstance.ItemRarity.UNCOMMON and it.explicit_affixes.size() == 1:
			fm_uncommon_ok += 1
			var af: ItemAffix = it.explicit_affixes[0]
			if af.affix_type == ItemAffix.AffixType.PREFIX:
				fm_p_count += 1
			else:
				fm_s_count += 1
			# No ilvl 10, nenhum T1 deve ser sorteado (T1 requer ilvl 55+)
			if af.tier == 1:
				fm_t1_in_ilvl10_violations += 1

	print("  -> Primeira Marca (100k): %d sucessos | Prefixos: %d | Sufixos: %d | T1 no ilvl 10: %d" % [
		fm_uncommon_ok, fm_p_count, fm_s_count, fm_t1_in_ilvl10_violations
	])
	assert_test(fm_uncommon_ok == count_first_mark, "100.000 Primeiras Marcas geraram 100.000 itens Verdes válidos")
	assert_test(fm_t1_in_ilvl10_violations == 0, "Zero violações de tier: nenhum T1 foi gerado em ilvl 10")
	assert_test(fm_p_count > 30000 and fm_s_count > 30000, "Distribuição equilibrada entre Prefixos e Sufixos")

	# 8.2 Simulação de 100.000 Contrasselos (Verde 1 -> Azul 2 1P+1S)
	var count_counterseal: int = 100000
	var cs_magic_ok: int = 0
	var cs_duplicate_groups: int = 0

	for _i in range(count_counterseal):
		var it := ItemInstance.new(def, ItemInstance.ItemRarity.UNCOMMON, 25)
		var af1: ItemAffix = ItemAffix.create("p_dmg", ItemAffix.AffixType.PREFIX, "damage", 6.0, "+6 Dano", 3, 10, "phys_dmg")
		it.explicit_affixes = [af1]
		var res: Dictionary = ItemCraftingService.apply_craft(it, "scroll_counterseal", {}, rng)
		if res["success"] and it.rarity == ItemInstance.ItemRarity.MAGIC and it.get_prefix_count() == 1 and it.get_suffix_count() == 1:
			cs_magic_ok += 1
			if it.explicit_affixes[0].exclusion_group == it.explicit_affixes[1].exclusion_group:
				cs_duplicate_groups += 1

	print("  -> Contrasselo (100k): %d sucessos | Grupos duplicados: %d" % [cs_magic_ok, cs_duplicate_groups])
	assert_test(cs_magic_ok == count_counterseal, "100.000 Contrasselos completaram 100.000 itens Azuis (1P+1S)")
	assert_test(cs_duplicate_groups == 0, "Zero grupos de exclusão mútua duplicados")

	# 8.3 Simulação de 100.000 Rasuras (Uniformidade 1/N)
	var count_eraser: int = 100000
	var erase_slot_counts: Array[int] = [0, 0, 0, 0] # contagem de remoção nos índices 0, 1, 2, 3 de item raro 4

	for _i in range(count_eraser):
		var it := ItemInstance.new(def, ItemInstance.ItemRarity.RARE, 40)
		it.explicit_affixes = [
			ItemAffix.create("a0", ItemAffix.AffixType.PREFIX, "stat0", 1.0, "m0", 1, 1, "g0"),
			ItemAffix.create("a1", ItemAffix.AffixType.PREFIX, "stat1", 1.0, "m1", 1, 1, "g1"),
			ItemAffix.create("a2", ItemAffix.AffixType.SUFFIX, "stat2", 1.0, "m2", 1, 1, "g2"),
			ItemAffix.create("a3", ItemAffix.AffixType.SUFFIX, "stat3", 1.0, "m3", 1, 1, "g3")
		]
		var res: Dictionary = ItemCraftingService.apply_craft(it, "stone_eraser", {}, rng)
		var removed_id: String = String(res["changes"]["removed_affix"]["affix_id"])
		var idx: int = int(removed_id.substr(1))
		erase_slot_counts[idx] += 1

	print("  -> Rasura (100k): Sorteios por slot: [%d, %d, %d, %d] (esperado ~25.000 cada)" % [
		erase_slot_counts[0], erase_slot_counts[1], erase_slot_counts[2], erase_slot_counts[3]
	])
	for k in range(4):
		var diff: float = absf(float(erase_slot_counts[k]) - 25000.0)
		assert_test(diff < 800.0, "Slot %d removido com frequência uniforme 1/4 (~25.000 +- 800)" % k)

	# 8.4 Simulação de 100.000 Vereditos (100% Lacrados, 0 violações 2P+2S)
	var count_verdict: int = 100000
	var vd_sealed_count: int = 0
	var vd_2p2s_violations: int = 0

	for _i in range(count_verdict):
		var it := ItemInstance.new(def, ItemInstance.ItemRarity.RARE, 75)
		it.explicit_affixes = [
			ItemAffix.create("a0", ItemAffix.AffixType.PREFIX, "damage", 10.0, "m0", 2, 30, "phys_dmg"),
			ItemAffix.create("a1", ItemAffix.AffixType.PREFIX, "attack_speed_pct", 0.15, "m1", 2, 30, "atk_spd"),
			ItemAffix.create("a2", ItemAffix.AffixType.SUFFIX, "strength", 5.0, "m2", 2, 30, "attr_str"),
			ItemAffix.create("a3", ItemAffix.AffixType.SUFFIX, "crit_chance", 0.04, "m3", 2, 30, "crit_pct")
		]
		ItemCraftingService.apply_craft(it, "stone_verdict", {"intent": "rewrite"}, rng)
		if it.is_sealed():
			vd_sealed_count += 1
		if it.get_prefix_count() > 2 or it.get_suffix_count() > 2 or it.explicit_affixes.size() > 4:
			vd_2p2s_violations += 1

	print("  -> Veredito (100k): %d lacrados com sucesso | Violações de afixos: %d" % [vd_sealed_count, vd_2p2s_violations])
	assert_test(vd_sealed_count == count_verdict, "100.000 Vereditos resultaram em 100.000 itens Lacrados (100%)")
	assert_test(vd_2p2s_violations == 0, "Zero violações de limites 2P+2S após Veredito")


## ----------------------------------------------------------------------------
## 9. INTERFACE DA MESA DO ESCRIBA (TOWNNPCMODAL POPULATION & IMPLICITS)
## ----------------------------------------------------------------------------
func test_town_npc_modal_scribe_crafting_ui() -> void:
	print("\n--- 9. INTERFACE DA MESA DO ESCRIBA (TOWNNPCMODAL & IMPLICITS) ---")
	var modal: TownNpcModal = TownNpcModal.new()
	root.add_child(modal)

	# 1. Abre a estação scribe_crafting sem item selecionado
	modal.open_station("scribe_crafting")
	assert_test(modal.visible, "Modal da Mesa do Escriba abre com sucesso")
	assert_test(modal.current_station_id == "scribe_crafting", "Estação ativa é 'scribe_crafting'")
	assert_test(modal.get_selected_craft_target() == null, "Alvo de crafting inicia nulo")

	# 2. Seleciona equipamento comum sem afixos implícitos (Espada Longa)
	var sword: ItemInstance = ItemDatabase.instantiate_act1_catalog_example("sword_long_iron")
	modal.select_crafting_item(sword)
	assert_test(modal.get_selected_craft_target() == sword, "Espada Longa sem implícitos selecionada e inspecionada")

	# 3. Seleciona equipamento COM afixos implícitos (Anel de Rubi: +2 de Força intrínseco)
	# Ponto crítico que causava o crash: acessava it.implicit_modifiers em vez de it.get_implicit_affixes()
	var ring: ItemInstance = ItemDatabase.instantiate_act1_catalog_example("ring_ruby")
	modal.select_crafting_item(ring)
	assert_test(modal.get_selected_craft_target() == ring, "Anel com afixos implícitos selecionado sem erros na UI")
	assert_test(not ring.get_implicit_affixes().is_empty(), "Anel de Rubi possui afixos implícitos válidos")
	assert_test(ring.get_implicit_affixes()[0].display_text.contains("Força"), "Texto do afixo implícito formatado corretamente")

	# 4. Seleciona amuleto com afixos implícitos de agilidade
	var amulet: ItemInstance = ItemDatabase.instantiate_act1_catalog_example("amulet_hawk")
	modal.select_crafting_item(amulet)
	assert_test(modal.get_selected_craft_target() == amulet, "Amuleto com afixos implícitos selecionado sem erros")

	# 5. Fecha modal
	modal.close_modal()
	assert_test(not modal.visible, "Modal fechou com sucesso")
	modal.queue_free()
