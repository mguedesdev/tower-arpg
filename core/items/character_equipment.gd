extends RefCounted
class_name CharacterEquipment
## Gerenciador de Equipamento (Paperdoll) do Cavaleiro / Personagem.
## Gerencia slots de armadura, armas 1H/2H, anéis e aplica modificadores nos atributos.

signal equipment_changed(slot: ItemDefinition.EquipmentSlot, item: ItemInstance)

var equipped: Dictionary = {}           ## EquipmentSlot -> ItemInstance
var _active_modifiers: Array[StatModifier] = []


func _init() -> void:
	equipped.clear()


func get_equipped_item(slot: ItemDefinition.EquipmentSlot) -> ItemInstance:
	return equipped.get(slot, null) as ItemInstance


func is_slot_valid_for_item(slot: ItemDefinition.EquipmentSlot, item: ItemInstance) -> bool:
	if item == null or item.definition == null:
		return false
	var def: ItemDefinition = item.definition
	if def.equip_slot == ItemDefinition.EquipmentSlot.RING_1:
		return slot == ItemDefinition.EquipmentSlot.RING_1 or slot == ItemDefinition.EquipmentSlot.RING_2
	if def.category == ItemDefinition.ItemCategory.SHIELD:
		return slot == ItemDefinition.EquipmentSlot.OFF_HAND
	return def.equip_slot == slot


func can_equip(item: ItemInstance, slot: ItemDefinition.EquipmentSlot, stats: CharacterStats) -> bool:
	if not is_slot_valid_for_item(slot, item):
		return false
	if stats != null and not item.meets_requirements(stats):
		return false
	return true


func get_displaced_items_for_equip(item: ItemInstance, slot: ItemDefinition.EquipmentSlot) -> Array[ItemInstance]:
	## Retorna todos os itens atualmente equipados que serão desalojados ao equipar `item` em `slot`.
	## Exemplo:
	## - Equipar Escudo (OFF_HAND) usando Espada 2H (MAIN_HAND) desaloja a Espada 2H.
	## - Equipar Espada 2H (MAIN_HAND) usando Espada 1H + Escudo desaloja AMBOS (Espada 1H e Escudo).
	var displaced: Array[ItemInstance] = []
	if item == null or item.definition == null:
		return displaced

	var current_in_slot: ItemInstance = get_equipped_item(slot)
	if current_in_slot != null and current_in_slot != item:
		displaced.append(current_in_slot)

	if slot == ItemDefinition.EquipmentSlot.MAIN_HAND and item.definition.is_two_handed():
		var off_item: ItemInstance = get_equipped_item(ItemDefinition.EquipmentSlot.OFF_HAND)
		if off_item != null and off_item != item and not displaced.has(off_item):
			displaced.append(off_item)
	elif slot == ItemDefinition.EquipmentSlot.OFF_HAND:
		var main_item: ItemInstance = get_equipped_item(ItemDefinition.EquipmentSlot.MAIN_HAND)
		if main_item != null and main_item.definition != null and main_item.definition.is_two_handed() and not displaced.has(main_item):
			displaced.append(main_item)

	return displaced


func equip_item_and_get_displaced(item: ItemInstance, slot: ItemDefinition.EquipmentSlot, stats: CharacterStats) -> Array[ItemInstance]:
	var displaced: Array[ItemInstance] = []
	if not can_equip(item, slot, stats):
		return displaced

	var previous: ItemInstance = get_equipped_item(slot)
	if previous != null:
		previous.equipped_slot = ItemDefinition.EquipmentSlot.NONE
		displaced.append(previous)

	# Se for arma de duas mãos (2H) na Mão Principal, remove o escudo/item da Mão Secundária
	if slot == ItemDefinition.EquipmentSlot.MAIN_HAND and item.definition.is_two_handed():
		var off_removed: ItemInstance = unequip_item(ItemDefinition.EquipmentSlot.OFF_HAND)
		if off_removed != null and not displaced.has(off_removed):
			displaced.append(off_removed)

	# Se estiver equipando na mão secundária, verifica se não está usando arma 2H
	if slot == ItemDefinition.EquipmentSlot.OFF_HAND:
		var main_hand: ItemInstance = get_equipped_item(ItemDefinition.EquipmentSlot.MAIN_HAND)
		if main_hand != null and main_hand.definition.is_two_handed():
			var main_removed: ItemInstance = unequip_item(ItemDefinition.EquipmentSlot.MAIN_HAND)
			if main_removed != null and not displaced.has(main_removed):
				displaced.append(main_removed)

	equipped[slot] = item
	item.equipped_slot = slot
	equipment_changed.emit(slot, item)

	if stats != null:
		sync_to_character_stats(stats)

	return displaced


func equip_item(item: ItemInstance, slot: ItemDefinition.EquipmentSlot, stats: CharacterStats) -> ItemInstance:
	var displaced: Array[ItemInstance] = equip_item_and_get_displaced(item, slot, stats)
	return displaced[0] if not displaced.is_empty() else null


func try_equip_from_inventory(
	item: ItemInstance,
	slot: ItemDefinition.EquipmentSlot,
	inv: SpatialInventoryGrid,
	stats: CharacterStats,
	preferred_pos: Vector2i = Vector2i(-1, -1)
) -> Dictionary:
	## Executa a troca transacional e atômica entre o Inventário Espacial e o Paperdoll:
	## 1. Verifica validade de slot e atributos.
	## 2. Identifica todos os itens equipados que serão desalojados (1H, 2H, Escudo ou ambos).
	## 3. Libera temporariamente o espaço do novo item na mochila e verifica se TODOS os itens
	##    desalojados cabem na mochila (incluindo rotação automática 3x2 <-> 2x3).
	## 4. Se não houver espaço suficiente na mochila, faz rollback completo e bloqueia a troca!
	if item == null or item.definition == null:
		return {"ok": false, "reason": "invalid_item", "displaced": []}
	if not is_slot_valid_for_item(slot, item):
		return {"ok": false, "reason": "invalid_slot", "displaced": []}
	if stats != null and not item.meets_requirements(stats):
		return {"ok": false, "reason": "requirements", "displaced": []}

	var displaced: Array[ItemInstance] = get_displaced_items_for_equip(item, slot)
	var was_in_inv: bool = (inv != null and inv.items.has(item))
	var orig_pos: Vector2i = item.grid_position if was_in_inv else preferred_pos
	var orig_rot: bool = item.is_rotated

	if was_in_inv:
		inv.remove_item(item)

	if inv != null and not displaced.is_empty():
		var fit_ok: bool = inv.try_place_items_transactionally(displaced, orig_pos)
		if not fit_ok:
			# Rollback: devolve o item candidato exatamente para sua posição e orientação originais na mochila
			if was_in_inv:
				item.is_rotated = orig_rot
				inv.place_item(item, orig_pos)
			return {"ok": false, "reason": "no_space", "displaced": displaced}

	# Todos os itens desalojados já foram acomodados com sucesso na mochila! Efetiva o equip:
	equip_item_and_get_displaced(item, slot, stats)
	return {"ok": true, "reason": "", "displaced": displaced}


func unequip_item(slot: ItemDefinition.EquipmentSlot, stats: CharacterStats = null) -> ItemInstance:
	if not equipped.has(slot):
		return null
	var old_item: ItemInstance = equipped[slot]
	equipped.erase(slot)
	if old_item != null:
		old_item.equipped_slot = ItemDefinition.EquipmentSlot.NONE
	equipment_changed.emit(slot, null)

	if stats != null:
		sync_to_character_stats(stats)
	return old_item


func sync_to_character_stats(stats: CharacterStats) -> void:
	if stats == null:
		return

	stats.remove_modifiers_by_source("equipment")
	stats.remove_modifiers_by_source("implicit")
	stats.remove_modifiers_by_source("affix")
	_active_modifiers.clear()

	# Aplica bônus de cada item equipado (Base + Intrínsecos + Afixos Explícitos, sem duplicar!)
	for slot_key in equipped.keys():
		var item: ItemInstance = equipped[slot_key] as ItemInstance
		if item == null or item.definition == null:
			continue
		var def: ItemDefinition = item.definition
		var slot_tag: String = str(int(slot_key))

		# Armadura base + afixos de armadura já consolidados em get_total_armor()
		var total_armor: int = item.get_total_armor()
		if total_armor > 0:
			var mod := StatModifier.new("equip_" + slot_tag + "_" + def.base_id + "_armor", &"armor", StatModifier.Op.FLAT, float(total_armor), "equipment")
			stats.add_modifier(mod)
			_active_modifiers.append(mod)

		# Dano base da arma + afixos de dano já consolidados em get_damage_range()
		var dmg_range: Vector2i = item.get_damage_range()
		if dmg_range.y > 0:
			var avg_dmg: float = float(dmg_range.x + dmg_range.y) * 0.5
			var mod := StatModifier.new("equip_" + slot_tag + "_" + def.base_id + "_dmg", &"damage", StatModifier.Op.FLAT, avg_dmg, "equipment")
			stats.add_modifier(mod)
			_active_modifiers.append(mod)

		# Vida base
		if def.base_health > 0:
			var mod := StatModifier.new("equip_" + slot_tag + "_" + def.base_id + "_hp", &"max_health", StatModifier.Op.FLAT, float(def.base_health), "equipment")
			stats.add_modifier(mod)
			_active_modifiers.append(mod)

		# Propriedades Intrínsecas (implícitas fixas da definição, ex: Anel de Rubi +2 Força, Safira +2 Int, Colar +2 Agi)
		var imp_idx: int = 0
		for imp in def.implicit_affixes:
			if imp == null or imp.stat_key.is_empty():
				continue
			if imp.stat_key == "armor" or imp.stat_key == "damage":
				continue
			var stat_name := StringName(imp.stat_key)
			var mod := StatModifier.new("imp_" + slot_tag + "_%d_%s" % [imp_idx, imp.affix_id], stat_name, StatModifier.Op.FLAT, imp.value, "implicit")
			stats.add_modifier(mod)
			_active_modifiers.append(mod)
			imp_idx += 1

		# Modificadores Explícitos (Prefixos, Sufixos ou Propriedades Especiais Únicas)
		var af_idx: int = 0
		for affix in item.explicit_affixes:
			if affix == null or affix.stat_key.is_empty():
				continue
			if affix.stat_key == "armor" or affix.stat_key == "damage":
				continue
			if affix.stat_key == "attack_speed_pct":
				var mod_spd := StatModifier.new("affix_" + slot_tag + "_%d_%s" % [af_idx, affix.affix_id], &"attack_speed", StatModifier.Op.PERCENT_ADD, affix.value, "affix")
				stats.add_modifier(mod_spd)
				_active_modifiers.append(mod_spd)
				af_idx += 1
				continue
			var stat_name := StringName(affix.stat_key)
			var mod := StatModifier.new("affix_" + slot_tag + "_%d_%s" % [af_idx, affix.affix_id], stat_name, StatModifier.Op.FLAT, affix.value, "affix")
			stats.add_modifier(mod)
			_active_modifiers.append(mod)
			af_idx += 1
