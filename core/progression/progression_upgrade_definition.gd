extends Resource
class_name ProgressionUpgradeDefinition
## Definição estática e editável de uma evolução de partida (Atributo, Habilidade, Transformação ou Modificador Especial).

enum Category {
	STAT_UPGRADE = 0,
	ABILITY_UPGRADE = 1,
	ABILITY_TRANSFORMATION = 2,
	SPECIAL_MODIFIER = 3,
}

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var preview_comparison: String = ""
@export var category: int = Category.STAT_UPGRADE
@export var icon_key: String = "stab"

@export var target_class_id: String = "warrior"
@export var target_ability_id: String = ""
@export_range(1, 20, 1) var max_rank: int = 1
@export_range(0.1, 100.0, 0.5) var weight: float = 10.0
@export_range(1, 99, 1) var min_run_level: int = 1

@export var required_upgrade_ids: PackedStringArray = PackedStringArray()
@export var required_tags: PackedStringArray = PackedStringArray()
@export var excluded_upgrade_ids: PackedStringArray = PackedStringArray()
@export var exclusivity_group: String = ""
@export var requires_meta_unlock_id: String = ""
@export var granted_tags: PackedStringArray = PackedStringArray()

## Lista de dicionários: [{"stat": "damage", "op": 1, "value": 0.20}]
@export var stat_modifiers_data: Array[Dictionary] = []

## Se >= 0, substitui o comportamento da habilidade-alvo (0=STAB, 1=ARC, 2=SPIN, 3=PIERCE).
@export var ability_behavior_override: int = -1
@export var ability_display_name_override: String = ""
@export var ability_transformation_params: Dictionary = {}

## Deltas de melhoria da habilidade: {"area_multiplier_add": 0.20, "cooldown_multiplier_factor": 0.90, "extra_targets": 1}
@export var ability_upgrade_deltas: Dictionary = {}

## Modificador especial: "burn", "echo", etc.
@export var special_effect_id: String = ""
@export var special_effect_params: Dictionary = {}


func category_label() -> String:
	match category:
		Category.STAT_UPGRADE:
			return "ATRIBUTO"
		Category.ABILITY_UPGRADE:
			return "MELHORIA DE HABILIDADE"
		Category.ABILITY_TRANSFORMATION:
			return "TRANSFORMAÇÃO"
		Category.SPECIAL_MODIFIER:
			return "MODIFICADOR ESPECIAL"
		_:
			return "EVOLUÇÃO"
