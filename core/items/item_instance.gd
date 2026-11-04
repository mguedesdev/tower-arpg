extends RefCounted
class_name ItemInstance
## Instância de item real gerada no jogo com raridade, afixos e estado de identificação.

enum ItemRarity {
	NORMAL,   ## Branco
	MAGIC,    ## Azul (1-2 afixos)
	RARE,     ## Amarelo (3-5 afixos)
	UNIQUE    ## Dourado/Lendário (afixos fixos exclusivos)
}

const COLOR_NORMAL := Color(0.92, 0.92, 0.92)
const COLOR_MAGIC := Color(0.35, 0.65, 1.0)
const COLOR_RARE := Color(1.0, 0.88, 0.28)
const COLOR_UNIQUE := Color(0.98, 0.58, 0.16)

var uid: String = ""
var definition: ItemDefinition
var rarity: ItemRarity = ItemRarity.NORMAL
var item_level: int = 1
var is_identified: bool = true
var explicit_affixes: Array[ItemAffix] = []
var custom_name: String = ""

# Posição de inventário
var grid_position: Vector2i = Vector2i(-1, -1)
var equipped_slot: ItemDefinition.EquipmentSlot = ItemDefinition.EquipmentSlot.NONE


func _init(p_def: ItemDefinition = null, p_rarity: ItemRarity = ItemRarity.NORMAL, p_ilvl: int = 1) -> void:
	uid = "%d_%d" % [Time.get_ticks_msec(), randi()]
	definition = p_def
	rarity = p_rarity
	item_level = p_ilvl
	is_identified = (p_rarity == ItemRarity.NORMAL)


func get_display_name() -> String:
	if definition == null:
		return "Item Desconhecido"
	if not is_identified:
		match rarity:
			ItemRarity.MAGIC:
				return "Item Mágico Não-Identificado"
			ItemRarity.RARE:
				return "Item Raro Não-Identificado"
			ItemRarity.UNIQUE:
				return "Item Lendário Não-Identificado"
	if not custom_name.is_empty():
		return custom_name
	return definition.display_name


func get_rarity_color() -> Color:
	match rarity:
		ItemRarity.MAGIC:
			return COLOR_MAGIC
		ItemRarity.RARE:
			return COLOR_RARE
		ItemRarity.UNIQUE:
			return COLOR_UNIQUE
		_:
			return COLOR_NORMAL


func get_stat_bonus(stat_key: String) -> float:
	var total: float = 0.0
	for affix in explicit_affixes:
		if affix != null and affix.stat_key == stat_key:
			total += affix.value
	return total


func get_total_armor() -> int:
	if definition == null:
		return 0
	var base: int = definition.base_armor
	return base + roundi(get_stat_bonus("armor"))


func get_damage_range() -> Vector2i:
	if definition == null:
		return Vector2i.ZERO
	var bonus: int = roundi(get_stat_bonus("damage"))
	return Vector2i(definition.base_damage_min + bonus, definition.base_damage_max + bonus)


func meets_requirements(stats: CharacterStats) -> bool:
	if definition == null or stats == null:
		return true
	# Atributos no CharacterStats
	var str_val: int = int(roundi(stats.get_stat(&"strength") if stats.has_method("get_stat") else 0.0))
	var agi_val: int = int(roundi(stats.get_stat(&"agility") if stats.has_method("get_stat") else 0.0))
	var int_val: int = int(roundi(stats.get_stat(&"intelligence") if stats.has_method("get_stat") else 0.0))
	if str_val < definition.req_strength:
		return false
	if agi_val < definition.req_agility:
		return false
	if int_val < definition.req_intelligence:
		return false
	return true


func identify() -> void:
	is_identified = true
