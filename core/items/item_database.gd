extends RefCounted
class_name ItemDatabase
## Banco de dados oficial de equipamentos do Ato 1 e fachada de geracao de loot progressivo.

const ACT1_EQUIPMENT_IDS: Array[String] = [
	"greatsword_iron",
	"sword_steel",
	"shield_round",
	"shield_tower",
	"chest_plate",
	"boots_plate",
	"gloves_chain",
	"ring_ruby",
	"ring_sapphire",
	"amulet_hawk",
	"belt_leather",
	"helm_iron",
	"dagger_sharp",
]

static var _catalog: Dictionary = {}


static func ensure_initialized() -> void:
	if _catalog.is_empty():
		_initialize_catalog()


static func get_catalog() -> Dictionary:
	ensure_initialized()
	return _catalog


static func get_act1_equipment_ids() -> Array[String]:
	ensure_initialized()
	return ACT1_EQUIPMENT_IDS.duplicate()


static func get_definition(base_id: String) -> ItemDefinition:
	var cat: Dictionary = get_catalog()
	return cat.get(base_id, null) as ItemDefinition


static func get_unique_eligible_definition(ilvl: int = 3, rng: RandomNumberGenerator = null) -> ItemDefinition:
	ensure_initialized()
	var eligible: Array[ItemDefinition] = []
	for item_id in ACT1_EQUIPMENT_IDS:
		var def: ItemDefinition = _catalog.get(item_id, null) as ItemDefinition
		if def != null and not def.unique_fixed_affixes.is_empty() and def.base_item_level <= ilvl:
			eligible.append(def)
	if eligible.is_empty():
		return _catalog.get("greatsword_iron", null) as ItemDefinition
	var idx: int = (rng.randi() % eligible.size()) if rng != null else (randi() % eligible.size())
	return eligible[idx]


static func _initialize_catalog() -> void:
	_catalog.clear()
	var C := ItemDefinition.ItemCategory
	var S := ItemDefinition.EquipmentSlot
	var A := ItemAffix.AffixType

	# 1. Espada Grande Runica Carmesim (3x2, rotacionavel, Arma 2 Maos)
	_register("greatsword_iron", "Espada Grande Rúnica Carmesim", C.WEAPON_2H, S.MAIN_HAND, Vector2i(3, 2), {
		"rotatable": true,
		"base_ilvl": 3, "req_lvl": 3, "req_str": 20,
		"dmg_min": 19, "dmg_max": 27, "atk_spd": 0.85,
		"gold": 90,
		"icon": "res://assets/items/greatsword.png",
		"desc": "Uma montante antiga marcada por fissuras que ainda ardem.",
		"source": "recompensa_unica_chefe_ou_evento",
		"example_rarity": "unique",
		"unique_fixed": [
			ItemAffix.create("uniq_gs_dmg", A.UNIQUE_FIXED, "damage", 5.0, "+5 de Dano", 1, 3),
			ItemAffix.create("uniq_gs_str", A.UNIQUE_FIXED, "strength", 2.0, "+2 de Força", 1, 3),
			ItemAffix.create("uniq_gs_hp", A.UNIQUE_FIXED, "max_health", 10.0, "+10 de Vida", 1, 3),
			ItemAffix.create("uniq_gs_crit", A.UNIQUE_FIXED, "crit_chance", 0.03, "+3% de Crítico", 1, 3),
		],
		"example_affixes": [
			ItemAffix.create("uniq_gs_dmg", A.UNIQUE_FIXED, "damage", 5.0, "+5 de Dano", 1, 3),
			ItemAffix.create("uniq_gs_str", A.UNIQUE_FIXED, "strength", 2.0, "+2 de Força", 1, 3),
			ItemAffix.create("uniq_gs_hp", A.UNIQUE_FIXED, "max_health", 10.0, "+10 de Vida", 1, 3),
			ItemAffix.create("uniq_gs_crit", A.UNIQUE_FIXED, "crit_chance", 0.03, "+3% de Crítico", 1, 3),
		]
	})

	# 2. Espada Longa de Ferro (2x1, rotacionavel, Arma 1 Mao)
	_register("sword_steel", "Espada Longa de Ferro", C.WEAPON_1H, S.MAIN_HAND, Vector2i(2, 1), {
		"rotatable": true,
		"base_ilvl": 1, "req_lvl": 1,
		"dmg_min": 8, "dmg_max": 12, "atk_spd": 1.10,
		"gold": 16,
		"icon": "res://assets/items/sword.png",
		"desc": "Lâmina equilibrada, confiável para os primeiros combates.",
		"source": "comum",
		"example_rarity": "normal",
		"example_affixes": []
	})

	# 3. Broquel do Vigia (2x2, nao rotacionavel, Escudo)
	_register("shield_round", "Broquel do Vigia", C.SHIELD, S.OFF_HAND, Vector2i(2, 2), {
		"rotatable": false,
		"base_ilvl": 1, "req_lvl": 1, "req_str": 8,
		"armor": 6, "hp": 8,
		"gold": 17,
		"icon": "res://assets/items/shield.png",
		"desc": "Escudo leve usado pelos guardas das estradas.",
		"source": "comum",
		"example_rarity": "uncommon",
		"example_affixes": [
			ItemAffix.create("ex_shround_agi", A.SUFFIX, "agility", 2.0, "+2 de Agilidade", 1, 1),
		]
	})

	# 4. Escudo de Torre do Exilio (2x4, rotacionavel, Escudo)
	_register("shield_tower", "Escudo de Torre do Exílio", C.SHIELD, S.OFF_HAND, Vector2i(2, 4), {
		"rotatable": true,
		"base_ilvl": 3, "req_lvl": 3, "req_str": 18,
		"armor": 14, "hp": 15,
		"gold": 45,
		"icon": "res://assets/items/tower_shield.png",
		"desc": "Um escudo pesado capaz de segurar uma linha inteira.",
		"source": "comum",
		"example_rarity": "rare",
		"example_affixes": [
			ItemAffix.create("ex_shtower_arm", A.PREFIX, "armor", 4.0, "+4 de Armadura", 1, 1),
			ItemAffix.create("ex_shtower_hp", A.PREFIX, "max_health", 12.0, "+12 de Vida", 1, 1),
			ItemAffix.create("ex_shtower_str", A.SUFFIX, "strength", 2.0, "+2 de Força", 1, 1),
		]
	})

	# 5. Peitoral de Placas do Exilado (2x3, rotacionavel, Peitoral)
	_register("chest_plate", "Peitoral de Placas do Exilado", C.CHEST, S.CHEST, Vector2i(2, 3), {
		"rotatable": true,
		"base_ilvl": 1, "req_lvl": 1, "req_str": 12,
		"armor": 11, "hp": 9,
		"gold": 28,
		"icon": "res://assets/items/chest.png",
		"desc": "Placas de aço gastas, reforçadas para sobreviver.",
		"source": "comum",
		"example_rarity": "magic",
		"example_affixes": [
			ItemAffix.create("ex_chest_arm", A.PREFIX, "armor", 3.0, "+3 de Armadura", 1, 1),
			ItemAffix.create("ex_chest_hp", A.PREFIX, "max_health", 8.0, "+8 de Vida", 1, 1),
		]
	})

	# 6. Botas de Placas do Recruta (2x2, nao rotacionavel, Botas)
	_register("boots_plate", "Botas de Placas do Recruta", C.BOOTS, S.BOOTS, Vector2i(2, 2), {
		"rotatable": false,
		"base_ilvl": 1, "req_lvl": 1, "req_str": 8,
		"armor": 4, "spd_pct": 0.02,
		"gold": 13,
		"icon": "res://assets/items/boots.png",
		"desc": "Botas resistentes para marchas pelo terreno hostil.",
		"source": "comum",
		"example_rarity": "normal",
		"example_affixes": []
	})

	# 7. Manoplas de Placas Leves (2x2, nao rotacionavel, Luvas)
	_register("gloves_chain", "Manoplas de Placas Leves", C.GLOVES, S.GLOVES, Vector2i(2, 2), {
		"rotatable": false,
		"base_ilvl": 1, "req_lvl": 1, "req_str": 8,
		"armor": 4,
		"gold": 12,
		"icon": "res://assets/items/gloves.png",
		"desc": "Manoplas articuladas que preservam a precisão.",
		"source": "comum",
		"example_rarity": "uncommon",
		"example_affixes": [
			ItemAffix.create("ex_gloves_agi", A.SUFFIX, "agility", 2.0, "+2 de Agilidade", 1, 1),
		]
	})

	# 8. Anel de Rubi (1x1, nao rotacionavel, Anel — +2 de Forca intrinseco)
	_register("ring_ruby", "Anel de Rubi", C.RING, S.RING_1, Vector2i(1, 1), {
		"rotatable": false,
		"base_ilvl": 2, "req_lvl": 2,
		"gold": 22,
		"icon": "res://assets/items/ring.png",
		"desc": "O rubi bruto aquece o sangue do portador.",
		"source": "comum",
		"implicits": [
			ItemAffix.create("imp_ring_ruby_str", A.IMPLICIT, "strength", 2.0, "+2 de Força (intrínseco)", 1, 1),
		],
		"example_rarity": "magic",
		"example_affixes": [
			ItemAffix.create("ex_ring_ruby_hp", A.PREFIX, "max_health", 6.0, "+6 de Vida", 1, 1),
			ItemAffix.create("ex_ring_ruby_crit", A.SUFFIX, "crit_chance", 0.02, "+2% de Crítico", 1, 1),
		]
	})

	# 9. Anel de Safira (1x1, nao rotacionavel, Anel — +2 de Inteligencia intrinseco)
	_register("ring_sapphire", "Anel de Safira", C.RING, S.RING_1, Vector2i(1, 1), {
		"rotatable": false,
		"base_ilvl": 2, "req_lvl": 2,
		"gold": 22,
		"icon": "res://assets/items/ring_sapphire.png",
		"desc": "A safira fria mantém a mente clara sob pressão.",
		"source": "comum",
		"implicits": [
			ItemAffix.create("imp_ring_sapphire_int", A.IMPLICIT, "intelligence", 2.0, "+2 de Inteligência (intrínseco)", 1, 1),
		],
		"example_rarity": "magic",
		"example_affixes": [
			ItemAffix.create("ex_ring_saph_hp", A.PREFIX, "max_health", 6.0, "+6 de Vida", 1, 1),
			ItemAffix.create("ex_ring_saph_agi", A.SUFFIX, "agility", 2.0, "+2 de Agilidade", 1, 1),
		]
	})

	# 10. Colar do Vigia Antigo (1x1, nao rotacionavel, Amuleto — +2 de Agilidade intrinseco)
	_register("amulet_hawk", "Colar do Vigia Antigo", C.AMULET, S.AMULET, Vector2i(1, 1), {
		"rotatable": false,
		"base_ilvl": 2, "req_lvl": 2,
		"gold": 33,
		"icon": "res://assets/items/amulet.png",
		"desc": "Um talismã usado pelos batedores de Velen.",
		"source": "comum",
		"implicits": [
			ItemAffix.create("imp_amulet_hawk_agi", A.IMPLICIT, "agility", 2.0, "+2 de Agilidade (intrínseco)", 1, 1),
		],
		"example_rarity": "rare",
		"example_affixes": [
			ItemAffix.create("ex_amu_str", A.SUFFIX, "strength", 2.0, "+2 de Força", 1, 1),
			ItemAffix.create("ex_amu_hp", A.PREFIX, "max_health", 8.0, "+8 de Vida", 1, 1),
			ItemAffix.create("ex_amu_crit", A.SUFFIX, "crit_chance", 0.02, "+2% de Crítico", 1, 1),
		]
	})

	# 11. Cinto de Couro Gasto (2x1, rotacionavel, Cinto)
	_register("belt_leather", "Cinto de Couro Gasto", C.BELT, S.BELT, Vector2i(2, 1), {
		"rotatable": true,
		"base_ilvl": 1, "req_lvl": 1,
		"armor": 2, "hp": 4,
		"gold": 9,
		"icon": "res://assets/items/belt.png",
		"desc": "Um cinto firme, feito para prender equipamento.",
		"source": "comum",
		"example_rarity": "normal",
		"example_affixes": []
	})

	# 12. Elmo de Placas do Recruta (2x2, nao rotacionavel, Elmo)
	_register("helm_iron", "Elmo de Placas do Recruta", C.HELMET, S.HELMET, Vector2i(2, 2), {
		"rotatable": false,
		"base_ilvl": 1, "req_lvl": 1, "req_str": 8,
		"armor": 5, "hp": 4,
		"gold": 14,
		"icon": "res://assets/items/helm.png",
		"desc": "Proteção simples para quem encara a primeira batalha.",
		"source": "comum",
		"example_rarity": "normal",
		"example_affixes": []
	})

	# 13. Adaga de Cacador (1x2, rotacionavel, Arma 1 Mao)
	_register("dagger_sharp", "Adaga de Caçador", C.WEAPON_1H, S.MAIN_HAND, Vector2i(1, 2), {
		"rotatable": true,
		"base_ilvl": 1, "req_lvl": 1, "req_agi": 8,
		"dmg_min": 5, "dmg_max": 8, "atk_spd": 1.45,
		"gold": 12,
		"icon": "res://assets/items/dagger.png",
		"desc": "Lâmina curta para ataques rápidos e precisos.",
		"source": "comum",
		"example_rarity": "uncommon",
		"example_affixes": [
			ItemAffix.create("ex_dagger_agi", A.SUFFIX, "agility", 2.0, "+2 de Agilidade", 1, 1),
		]
	})

	# Consumivel preservado para funcionamento de pocoes na campanha e lojas
	_register("potion_health", "Frasco de Vida Puro", C.CONSUMABLE, S.NONE, Vector2i(1, 1), {
		"rotatable": false,
		"base_ilvl": 1, "req_lvl": 1,
		"hp": 60,
		"gold": 15,
		"icon": "res://assets/items/potion.png",
		"desc": "Elixir alquímico puro que restaura o vigor vital instantaneamente.",
		"source": "comum",
		"example_rarity": "normal",
		"example_affixes": []
	})


static func _register(id: String, name: String, cat: ItemDefinition.ItemCategory, slot: ItemDefinition.EquipmentSlot, sz: Vector2i, props: Dictionary) -> void:
	var def := ItemDefinition.new()
	def.base_id = id
	def.display_name = name
	def.category = cat
	def.equip_slot = slot
	def.grid_size = sz
	def.rotatable = bool(props.get("rotatable", sz.x != sz.y))
	def.base_item_level = int(props.get("base_ilvl", 1))
	def.req_level = int(props.get("req_lvl", 1))
	def.base_damage_min = int(props.get("dmg_min", 0))
	def.base_damage_max = int(props.get("dmg_max", 0))
	def.base_attack_speed = float(props.get("atk_spd", 1.0))
	def.base_armor = int(props.get("armor", 0))
	def.base_health = int(props.get("hp", 0))
	def.base_move_speed_pct = float(props.get("spd_pct", 0.0))
	def.req_strength = int(props.get("req_str", 0))
	def.req_agility = int(props.get("req_agi", 0))
	def.req_intelligence = int(props.get("req_int", 0))
	def.base_gold_value = int(props.get("gold", 10))
	def.icon_path = String(props.get("icon", ""))
	def.description = String(props.get("desc", ""))
	def.suggested_source = String(props.get("source", "comum"))
	def.example_rarity_id = String(props.get("example_rarity", "normal"))

	if props.has("implicits"):
		for imp in props["implicits"]:
			if imp is ItemAffix:
				def.implicit_affixes.append(imp)
	if props.has("unique_fixed"):
		for u in props["unique_fixed"]:
			if u is ItemAffix:
				def.unique_fixed_affixes.append(u)
	if props.has("example_affixes"):
		for ex in props["example_affixes"]:
			if ex is ItemAffix:
				def.example_affixes.append(ex)

	_catalog[id] = def


## Instancia exatamente o item-exemplo de referencia do catalogo do Ato 1 (deterministico)
static func instantiate_act1_catalog_example(base_id: String) -> ItemInstance:
	var def: ItemDefinition = get_definition(base_id)
	if def == null:
		return null
	var r: ItemInstance.ItemRarity = ItemInstance.rarity_from_id(def.example_rarity_id)
	var inst := ItemInstance.new(def, r, def.base_item_level)
	inst.is_identified = true
	inst.custom_name = ""
	if r == ItemInstance.ItemRarity.UNIQUE:
		inst.unique_id = "unique_crimson_runic_greatsword"
		inst.unique_display_name = def.display_name
	for ex in def.example_affixes:
		if ex != null:
			inst.explicit_affixes.append(ex.duplicate_affix())
	return inst


## Retorna todas as 13 instancias-exemplo de equipamentos do catalogo do Ato 1
static func instantiate_all_act1_catalog_examples() -> Array[ItemInstance]:
	var list: Array[ItemInstance] = []
	for id in ACT1_EQUIPMENT_IDS:
		var inst: ItemInstance = instantiate_act1_catalog_example(id)
		if inst != null:
			list.append(inst)
	return list


## Gera uma instancia de item usando o pipeline progressivo do Ato 1
static func generate_loot(
	ilvl: int = 1,
	force_rarity: int = -1,
	preferred_base_id: String = "",
	monster_class: int = LootBalanceConfig.MonsterClass.NORMAL,
	rng: RandomNumberGenerator = null
) -> ItemInstance:
	var cat: Dictionary = get_catalog()
	var def: ItemDefinition = null

	if not preferred_base_id.is_empty() and cat.has(preferred_base_id):
		def = cat[preferred_base_id] as ItemDefinition
	else:
		def = LootGenerationService.stage3_select_valid_base_item(ilvl, monster_class, "act1", rng)

	if def == null:
		def = get_definition("sword_steel")

	if not def.is_equippable():
		var consumable_inst := ItemInstance.new(def, ItemInstance.ItemRarity.NORMAL, 1)
		consumable_inst.is_identified = true
		return consumable_inst

	var rarity: ItemInstance.ItemRarity = ItemInstance.ItemRarity.NORMAL
	if force_rarity >= 0:
		rarity = force_rarity as ItemInstance.ItemRarity
	else:
		rarity = LootGenerationService.stage4_roll_item_rarity(ilvl, monster_class, def, rng)

	var final_ilvl: int = LootGenerationService.stage5_determine_item_level(ilvl, monster_class, def)
	var item := ItemInstance.new(def, rarity, final_ilvl)
	item.custom_name = ""
	LootGenerationService.stage6_roll_affixes(item, rng)
	return item


static func generate_blacksmith_stock(ilvl: int = 1) -> Array[ItemInstance]:
	var stock: Array[ItemInstance] = []
	var blueprint: Array[Dictionary] = [
		{"id": "greatsword_iron", "rar": ItemInstance.ItemRarity.NORMAL, "tier": 2},
		{"id": "sword_steel",     "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 1},
		{"id": "shield_tower",    "rar": ItemInstance.ItemRarity.NORMAL, "tier": 2},
		{"id": "chest_plate",     "rar": ItemInstance.ItemRarity.RARE,   "tier": 2},
		{"id": "gloves_chain",    "rar": ItemInstance.ItemRarity.NORMAL, "tier": 1},
		{"id": "boots_plate",     "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 1},
		{"id": "helm_iron",       "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 2},
		{"id": "dagger_sharp",    "rar": ItemInstance.ItemRarity.NORMAL, "tier": 1},
		{"id": "shield_round",    "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 1},
		{"id": "belt_leather",    "rar": ItemInstance.ItemRarity.NORMAL, "tier": 1},
		{"id": "greatsword_iron", "rar": ItemInstance.ItemRarity.RARE,   "tier": 3},
		{"id": "chest_plate",     "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 2},
		{"id": "ring_ruby",       "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 2},
		{"id": "amulet_hawk",     "rar": ItemInstance.ItemRarity.NORMAL, "tier": 1},
		{"id": "potion_health",   "rar": ItemInstance.ItemRarity.NORMAL, "tier": 1},
	]
	for entry in blueprint:
		var tier_lvl: int = maxi(1, int(entry["tier"]) + maxi(0, ilvl - 1))
		var it: ItemInstance = generate_loot(tier_lvl, int(entry["rar"]), String(entry["id"]))
		it.identify()
		stock.append(it)
	return stock


static func generate_arcanist_stock(ilvl: int = 1) -> Array[ItemInstance]:
	var stock: Array[ItemInstance] = []
	var blueprint: Array[Dictionary] = [
		{"id": "ring_ruby",       "rar": ItemInstance.ItemRarity.RARE,   "tier": 2},
		{"id": "ring_sapphire",   "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 2},
		{"id": "amulet_hawk",     "rar": ItemInstance.ItemRarity.RARE,   "tier": 2},
		{"id": "dagger_sharp",    "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 2},
		{"id": "sword_steel",     "rar": ItemInstance.ItemRarity.RARE,   "tier": 2},
		{"id": "gloves_chain",    "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 1},
		{"id": "belt_leather",    "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 1},
		{"id": "helm_iron",       "rar": ItemInstance.ItemRarity.RARE,   "tier": 2},
		{"id": "greatsword_iron", "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 3},
		{"id": "shield_round",    "rar": ItemInstance.ItemRarity.RARE,   "tier": 2},
		{"id": "boots_plate",     "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 2},
		{"id": "ring_ruby",       "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 1},
		{"id": "amulet_hawk",     "rar": ItemInstance.ItemRarity.MAGIC,  "tier": 1},
		{"id": "chest_plate",     "rar": ItemInstance.ItemRarity.RARE,   "tier": 3},
		{"id": "potion_health",   "rar": ItemInstance.ItemRarity.NORMAL, "tier": 1},
	]
	for entry in blueprint:
		var tier_lvl: int = maxi(1, int(entry["tier"]) + maxi(0, ilvl - 1))
		var it: ItemInstance = generate_loot(tier_lvl, int(entry["rar"]), String(entry["id"]))
		it.identify()
		stock.append(it)
	return stock
