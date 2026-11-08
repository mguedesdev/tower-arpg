extends Resource
class_name ItemDefinition
## Definição estática e imutável de um item-base no catálogo ARPG (Ato 1).
## Separa claramente atributos base, propriedades intrínsecas (implícitas), requisitos,
## dimensões no grid (colunas x linhas) e arquétipos únicos curados.

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

const BODY_ARMOR = EquipmentSlot.CHEST

@export var base_id: String = ""
## Propriedade calculada / alias de compatibilidade para base_id (evita crash em acessos .id)
var id: String:
	get:
		return base_id
	set(val):
		base_id = val

@export var display_name: String = ""
@export var category: ItemCategory = ItemCategory.WEAPON_1H
@export var equip_slot: EquipmentSlot = EquipmentSlot.MAIN_HAND
@export var grid_size: Vector2i = Vector2i(2, 3)     ## Colunas (x) x Linhas (y) no inventário
@export var rotatable: bool = true                   ## Se permite rotação 90° no grid espacial
@export var icon_path: String = ""

# Nível do item-base no catálogo
@export var base_item_level: int = 1

# Atributos Base (persistem independentemente da raridade e não contam como modificadores)
@export var base_damage_min: int = 0
@export var base_damage_max: int = 0
@export var base_attack_speed: float = 1.0
@export var base_armor: int = 0
@export var base_health: int = 0
@export var base_move_speed_pct: float = 0.0

# Requisitos de Atributos e Nível
@export var req_strength: int = 0
@export var req_agility: int = 0
@export var req_intelligence: int = 0
@export var req_level: int = 1

# Valor econômico e descrição temática curta
@export var base_gold_value: int = 10
@export var description: String = ""
@export var suggested_source: String = "comum"

# Propriedades de Frasco Recarregável (Doc 08 / PoE2 Style)
@export var is_flask: bool = false
@export var flask_resource_type: String = "life" ## "life" ou "mana"
@export var flask_recovery_amount: float = 70.0  ## Pontos de vida/mana restaurados
@export var flask_recovery_duration: float = 3.0 ## Duração em segundos (recuperação contínua)
@export var flask_capacity: int = 60             ## Cargas máximas suportadas
@export var flask_cost_per_use: int = 10         ## Cargas consumidas por ativação

# Propriedades Intrínsecas / Implícitas fixas do item-base (não contam como afixos aleatórios)
var implicit_affixes: Array[ItemAffix] = []

# Propriedades Especiais Predefinidas para quando este item-base é gerado como Único (Vermelho)
var unique_fixed_affixes: Array[ItemAffix] = []

# Dados da instância-exemplo oficial do catálogo do Ato 1 (para validação e testes determinísticos)
var example_rarity_id: String = "normal"
var example_affixes: Array[ItemAffix] = []


func is_two_handed() -> bool:
	return category == ItemCategory.WEAPON_2H


func is_equippable() -> bool:
	return equip_slot != EquipmentSlot.NONE


static func get_category_name(cat: ItemCategory) -> String:
	match cat:
		ItemCategory.WEAPON_1H:
			return "Arma de Uma Mão"
		ItemCategory.WEAPON_2H:
			return "Arma de Duas Mãos"
		ItemCategory.SHIELD:
			return "Escudo"
		ItemCategory.HELMET:
			return "Elmo"
		ItemCategory.CHEST:
			return "Peitoral"
		ItemCategory.GLOVES:
			return "Luvas"
		ItemCategory.BOOTS:
			return "Botas"
		ItemCategory.BELT:
			return "Cinto"
		ItemCategory.AMULET:
			return "Amuleto"
		ItemCategory.RING:
			return "Anel"
		ItemCategory.CONSUMABLE:
			return "Consumível"
	return "Equipamento"

