extends RefCounted
class_name ItemDatabase
## Banco de dados de itens e gerador de Loot procedimental (Diablo 2 / PoE).

static var _catalog: Dictionary = {}


static func get_catalog() -> Dictionary:
	if _catalog.is_empty():
		_initialize_catalog()
	return _catalog


static func get_definition(base_id: String) -> ItemDefinition:
	var cat: Dictionary = get_catalog()
	return cat.get(base_id, null) as ItemDefinition


static func _initialize_catalog() -> void:
	# 1. Espada Montante 2H (2 colunas x 4 linhas - 4x2 grande e pesada)
	_register("greatsword_iron", "Espada Montante Pesada", ItemDefinition.ItemCategory.WEAPON_2H, ItemDefinition.EquipmentSlot.MAIN_HAND, Vector2i(2, 4), {
		"dmg_min": 28, "dmg_max": 42, "atk_spd": 0.85, "req_str": 24, "req_agi": 10, "gold": 65, "icon": "res://assets/items/greatsword.png"
	})

	# 2. Espada Longa 1H (1 coluna x 4 linhas - 4x1 fina e comprida)
	_register("sword_steel", "Espada Longa de Aço", ItemDefinition.ItemCategory.WEAPON_1H, ItemDefinition.EquipmentSlot.MAIN_HAND, Vector2i(1, 4), {
		"dmg_min": 16, "dmg_max": 24, "atk_spd": 1.10, "req_str": 16, "req_agi": 12, "gold": 40, "icon": "res://assets/items/sword.png"
	})

	# 3. Adaga Afiada (1 coluna x 3 linhas - 3x1 fina e compacta)
	_register("dagger_sharp", "Adaga de Aço", ItemDefinition.ItemCategory.WEAPON_1H, ItemDefinition.EquipmentSlot.MAIN_HAND, Vector2i(1, 3), {
		"dmg_min": 9, "dmg_max": 14, "atk_spd": 1.45, "req_str": 10, "req_agi": 18, "gold": 25, "icon": "res://assets/items/dagger.png"
	})

	# 4. Escudo de Torre (2 colunas x 4 linhas - 4x2)
	_register("shield_tower", "Escudo de Torre de Ferro", ItemDefinition.ItemCategory.SHIELD, ItemDefinition.EquipmentSlot.OFF_HAND, Vector2i(2, 4), {
		"armor": 32, "hp": 40, "req_str": 25, "gold": 55, "icon": "res://assets/items/tower_shield.png"
	})

	# 5. Escudo Redondo (2 colunas x 2 linhas - 2x2)
	_register("shield_round", "Escudo com Crista", ItemDefinition.ItemCategory.SHIELD, ItemDefinition.EquipmentSlot.OFF_HAND, Vector2i(2, 2), {
		"armor": 18, "hp": 20, "req_str": 14, "gold": 30, "icon": "res://assets/items/shield.png"
	})

	# 6. Peitoral de Placas (2 colunas x 4 linhas - 4x2 robusto)
	_register("chest_plate", "Peitoral de Placas de Aço", ItemDefinition.ItemCategory.CHEST, ItemDefinition.EquipmentSlot.CHEST, Vector2i(2, 4), {
		"armor": 35, "hp": 50, "req_str": 22, "gold": 70, "icon": "res://assets/items/chest.png"
	})

	# 7. Elmo de Ferro (2 colunas x 2 linhas - 4 slots)
	_register("helm_iron", "Elmo de Ferro Pesado", ItemDefinition.ItemCategory.HELMET, ItemDefinition.EquipmentSlot.HELMET, Vector2i(2, 2), {
		"armor": 16, "hp": 25, "req_str": 16, "gold": 35, "icon": "res://assets/items/helm.png"
	})

	# 8. Botas de Placa (2 colunas x 2 linhas - 4 slots)
	_register("boots_plate", "Grevas de Combate", ItemDefinition.ItemCategory.BOOTS, ItemDefinition.EquipmentSlot.BOOTS, Vector2i(2, 2), {
		"armor": 12, "spd_pct": 0.08, "req_str": 14, "gold": 30, "icon": "res://assets/items/boots.png"
	})

	# 9. Luvas de Malha (2 colunas x 2 linhas - mais largas, 4 slots)
	_register("gloves_chain", "Manoplas Reforçadas", ItemDefinition.ItemCategory.GLOVES, ItemDefinition.EquipmentSlot.GLOVES, Vector2i(2, 2), {
		"armor": 10, "req_str": 12, "gold": 25, "icon": "res://assets/items/gloves.png"
	})

	# 10. Cinto Reforçado (2 colunas x 1 linha - 2x1)
	_register("belt_leather", "Cinto de Couro Cravejado", ItemDefinition.ItemCategory.BELT, ItemDefinition.EquipmentSlot.BELT, Vector2i(2, 1), {
		"armor": 6, "hp": 18, "req_str": 10, "gold": 20, "icon": "res://assets/items/belt.png"
	})

	# 11. Anel de Rubi (1x1) - Concede Força para ajudar a cumprir requisitos!
	_register("ring_ruby", "Anel de Rubi Ancestral", ItemDefinition.ItemCategory.RING, ItemDefinition.EquipmentSlot.RING_1, Vector2i(1, 1), {
		"gold": 50, "icon": "res://assets/items/ring.png"
	})

	# 12. Amuleto de Olho de Falcão (1x1) - Concede Agilidade!
	_register("amulet_hawk", "Amuleto de Olho de Falcão", ItemDefinition.ItemCategory.AMULET, ItemDefinition.EquipmentSlot.AMULET, Vector2i(1, 1), {
		"gold": 60, "icon": "res://assets/items/amulet.png"
	})

	# 13. Poção de Vida (1x1)
	_register("potion_health", "Frasco de Vida Puro", ItemDefinition.ItemCategory.CONSUMABLE, ItemDefinition.EquipmentSlot.NONE, Vector2i(1, 1), {
		"hp": 60, "gold": 15, "icon": "res://assets/items/potion.png"
	})


static func _register(id: String, name: String, cat: ItemDefinition.ItemCategory, slot: ItemDefinition.EquipmentSlot, sz: Vector2i, props: Dictionary) -> void:
	var def := ItemDefinition.new()
	def.base_id = id
	def.display_name = name
	def.category = cat
	def.equip_slot = slot
	def.grid_size = sz
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
	_catalog[id] = def


## Gera uma instância de item com raridade e afixos aleatórios
static func generate_loot(ilvl: int = 1, force_rarity: int = -1, preferred_base_id: String = "") -> ItemInstance:
	var cat: Dictionary = get_catalog()
	var base_id: String = preferred_base_id
	if base_id.is_empty() or not cat.has(base_id):
		var keys: Array = cat.keys()
		base_id = String(keys[randi() % keys.size()])

	var def: ItemDefinition = cat[base_id] as ItemDefinition
	var rarity: ItemInstance.ItemRarity = ItemInstance.ItemRarity.NORMAL
	if force_rarity >= 0:
		rarity = force_rarity as ItemInstance.ItemRarity
	else:
		var roll: float = randf()
		if roll < 0.08:
			rarity = ItemInstance.ItemRarity.UNIQUE
		elif roll < 0.28:
			rarity = ItemInstance.ItemRarity.RARE
		elif roll < 0.60:
			rarity = ItemInstance.ItemRarity.MAGIC
		else:
			rarity = ItemInstance.ItemRarity.NORMAL

	var item := ItemInstance.new(def, rarity, ilvl)

	# Se for anel base ou amuleto, garante afixos de atributos primários
	if def.category == ItemDefinition.ItemCategory.RING:
		item.explicit_affixes.append(ItemAffix.create("str_base", ItemAffix.AffixType.PREFIX, "strength", 6.0 + float(ilvl * 2), "+%d de Força" % (6 + ilvl * 2)))
	elif def.category == ItemDefinition.ItemCategory.AMULET:
		item.explicit_affixes.append(ItemAffix.create("agi_base", ItemAffix.AffixType.PREFIX, "agility", 6.0 + float(ilvl * 2), "+%d de Agilidade" % (6 + ilvl * 2)))

	_roll_affixes(item, ilvl)
	return item


static func _roll_affixes(item: ItemInstance, ilvl: int) -> void:
	if item.rarity == ItemInstance.ItemRarity.NORMAL:
		return

	var count: int = 1
	match item.rarity:
		ItemInstance.ItemRarity.MAGIC:
			count = 1 if randf() < 0.6 else 2
		ItemInstance.ItemRarity.RARE:
			count = randi_range(3, 4)
		ItemInstance.ItemRarity.UNIQUE:
			count = 4

	var affix_pool: Array[Dictionary] = [
		{"stat": "max_health", "min": 15, "max": 40, "fmt": "+%d de Vida", "type": ItemAffix.AffixType.PREFIX, "name": "do Titã"},
		{"stat": "damage", "min": 4, "max": 12, "fmt": "+%d de Dano Físico", "type": ItemAffix.AffixType.PREFIX, "name": "Cruel"},
		{"stat": "armor", "min": 8, "max": 25, "fmt": "+%d de Armadura", "type": ItemAffix.AffixType.PREFIX, "name": "Impenetrável"},
		{"stat": "strength", "min": 4, "max": 10, "fmt": "+%d de Força", "type": ItemAffix.AffixType.SUFFIX, "name": "do Urso"},
		{"stat": "agility", "min": 4, "max": 10, "fmt": "+%d de Agilidade", "type": ItemAffix.AffixType.SUFFIX, "name": "do Guepardo"},
		{"stat": "crit_chance", "min": 0.03, "max": 0.08, "fmt": "+%d%% Chance de Crítico", "type": ItemAffix.AffixType.SUFFIX, "name": "da Precisão"}
	]

	affix_pool.shuffle()
	var chosen_names: Array[String] = []
	for i in range(mini(count, affix_pool.size())):
		var entry: Dictionary = affix_pool[i]
		var val: float = 0.0
		var text: String = ""
		if entry["stat"] == "crit_chance":
			val = randf_range(float(entry["min"]), float(entry["max"]))
			text = String(entry["fmt"]) % int(roundi(val * 100.0))
		else:
			val = float(randi_range(int(entry["min"]), int(entry["max"])) * ilvl)
			text = String(entry["fmt"]) % int(val)

		var affix := ItemAffix.create(
			"affix_%d" % i,
			entry["type"] as ItemAffix.AffixType,
			String(entry["stat"]),
			val,
			text
		)
		item.explicit_affixes.append(affix)
		chosen_names.append(String(entry["name"]))

	if item.rarity == ItemInstance.ItemRarity.MAGIC and not chosen_names.is_empty():
		item.custom_name = "%s %s" % [item.definition.display_name, chosen_names[0]]
	elif item.rarity == ItemInstance.ItemRarity.RARE:
		var rare_titles: Array[String] = ["Lâmina do Destino", "Coração de Ferro", "Muralha Antiga", "Sombra Voraz", "Presa Profanada"]
		item.custom_name = rare_titles[randi() % rare_titles.size()]
	elif item.rarity == ItemInstance.ItemRarity.UNIQUE:
		item.custom_name = "✦ " + item.definition.display_name + " Ancestral"


static func generate_blacksmith_stock(ilvl: int = 1) -> Array[ItemInstance]:
	var stock: Array[ItemInstance] = []
	var bases: Array[String] = [
		"greatsword_iron",
		"sword_steel",
		"shield_tower",
		"chest_plate",
		"helm_iron",
		"boots_plate",
	]
	for i in range(bases.size()):
		var rar: int = ItemInstance.ItemRarity.MAGIC if (i % 2 == 1) else ItemInstance.ItemRarity.NORMAL
		if i == 0 and randf() < 0.45:
			rar = ItemInstance.ItemRarity.RARE
		var it: ItemInstance = generate_loot(maxi(1, ilvl), rar, bases[i])
		it.identify()
		stock.append(it)
	var pot: ItemInstance = generate_loot(1, ItemInstance.ItemRarity.NORMAL, "potion_health")
	pot.identify()
	stock.append(pot)
	return stock


static func generate_arcanist_stock(ilvl: int = 1) -> Array[ItemInstance]:
	var stock: Array[ItemInstance] = []
	var bases: Array[String] = [
		"ring_ruby",
		"amulet_hawk",
		"dagger_sharp",
		"sword_steel",
		"gloves_chain",
		"belt_leather",
	]
	for i in range(bases.size()):
		var rar: int = ItemInstance.ItemRarity.RARE if (i < 2 or randf() < 0.4) else ItemInstance.ItemRarity.MAGIC
		var it: ItemInstance = generate_loot(maxi(1, ilvl), rar, bases[i])
		it.identify()
		stock.append(it)
	var pot: ItemInstance = generate_loot(1, ItemInstance.ItemRarity.NORMAL, "potion_health")
	pot.identify()
	stock.append(pot)
	return stock
