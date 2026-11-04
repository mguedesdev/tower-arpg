extends Resource
class_name ItemDefinition
## Definição estática e imutável de um item no catálogo ARPG.

enum ItemCategory {
	WEAPON_1H,
	WEAPON_2H,
	SHIELD,
	HELMET,
	CHEST,
	GLOVES,
	BOOTS,
	BELT,
	AMULET,
	RING,
	CONSUMABLE
}

enum EquipmentSlot {
	NONE,
	HELMET,
	CHEST,
	MAIN_HAND,
	OFF_HAND,
	GLOVES,
	BOOTS,
	BELT,
	AMULET,
	RING_1,
	RING_2
}

@export var base_id: String = ""
@export var display_name: String = ""
@export var category: ItemCategory = ItemCategory.WEAPON_1H
@export var equip_slot: EquipmentSlot = EquipmentSlot.MAIN_HAND
@export var grid_size: Vector2i = Vector2i(2, 3)     ## Largura x Altura no inventário (ex: 2x4 = 8 células)
@export var icon_path: String = ""

# Atributos Base
@export var base_damage_min: int = 0
@export var base_damage_max: int = 0
@export var base_attack_speed: float = 1.0
@export var base_armor: int = 0
@export var base_health: int = 0
@export var base_move_speed_pct: float = 0.0

# Requisitos de Atributos (Sem botões de ponto manual; atingidos por gear/nível)
@export var req_strength: int = 0
@export var req_agility: int = 0
@export var req_intelligence: int = 0
@export var req_level: int = 1

# Valor econômico
@export var base_gold_value: int = 10
@export var description: String = ""


func is_two_handed() -> bool:
	return category == ItemCategory.WEAPON_2H


func is_equippable() -> bool:
	return equip_slot != EquipmentSlot.NONE
