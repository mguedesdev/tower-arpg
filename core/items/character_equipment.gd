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


func equip_item(item: ItemInstance, slot: ItemDefinition.EquipmentSlot, stats: CharacterStats) -> ItemInstance:
	if not can_equip(item, slot, stats):
		return null

	var previous: ItemInstance = get_equipped_item(slot)
	if previous != null:
		previous.equipped_slot = ItemDefinition.EquipmentSlot.NONE

	# Se for arma de duas mãos (2H) na Mão Principal, remove o escudo/item da Mão Secundária
	var unequipped_offhand: ItemInstance = null
	if slot == ItemDefinition.EquipmentSlot.MAIN_HAND and item.definition.is_two_handed():
		unequipped_offhand = unequip_item(ItemDefinition.EquipmentSlot.OFF_HAND)

	# Se estiver equipando na mão secundária, verifica se não está usando arma 2H
	if slot == ItemDefinition.EquipmentSlot.OFF_HAND:
		var main_hand: ItemInstance = get_equipped_item(ItemDefinition.EquipmentSlot.MAIN_HAND)
		if main_hand != null and main_hand.definition.is_two_handed():
			unequip_item(ItemDefinition.EquipmentSlot.MAIN_HAND)

	equipped[slot] = item
	item.equipped_slot = slot
	equipment_changed.emit(slot, item)

	if stats != null:
		sync_to_character_stats(stats)

	return previous


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
	stats.remove_modifiers_by_source("affix")
	_active_modifiers.clear()

	# Aplica bônus de cada item equipado
	for slot_key in equipped.keys():
		var item: ItemInstance = equipped[slot_key] as ItemInstance
		if item == null or item.definition == null:
			continue
		var def: ItemDefinition = item.definition

		# Armadura base
		var total_armor: int = item.get_total_armor()
		if total_armor > 0:
			var mod := StatModifier.new("equip_" + def.base_id + "_armor", &"armor", StatModifier.Op.FLAT, float(total_armor), "equipment")
			stats.add_modifier(mod)
			_active_modifiers.append(mod)

		# Dano base da arma
		var dmg_range: Vector2i = item.get_damage_range()
		if dmg_range.y > 0:
			var avg_dmg: float = float(dmg_range.x + dmg_range.y) * 0.5
			var mod := StatModifier.new("equip_" + def.base_id + "_dmg", &"damage", StatModifier.Op.FLAT, avg_dmg, "equipment")
			stats.add_modifier(mod)
			_active_modifiers.append(mod)

		# Vida base
		if def.base_health > 0:
			var mod := StatModifier.new("equip_" + def.base_id + "_hp", &"max_health", StatModifier.Op.FLAT, float(def.base_health), "equipment")
			stats.add_modifier(mod)
			_active_modifiers.append(mod)

		# Afixos adicionais (ex: +Força, +Agilidade, +Vida, +Dano)
		for affix in item.explicit_affixes:
			if affix == null or affix.stat_key.is_empty():
				continue
			var stat_name := StringName(affix.stat_key)
			var mod := StatModifier.new("affix_" + affix.affix_id, stat_name, StatModifier.Op.FLAT, affix.value, "affix")
			stats.add_modifier(mod)
			_active_modifiers.append(mod)
