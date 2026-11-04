extends Resource
class_name AbilityDefinition
## Definição estática e imutável de uma habilidade.
## Nunca deve ser alterada diretamente em runtime durante a partida.

enum Behavior {
	STAB = 0,
	ARC = 1,
	SPIN = 2,
	PIERCE = 3,
}

@export var id: String = "warrior_strike"
@export var display_name: String = "Estocada"
@export_multiline var description: String = "Golpe frontal rápido de curto alcance."
@export var class_id: String = "warrior"
@export var base_behavior: int = Behavior.STAB
@export_range(0.1, 10.0, 0.05) var base_damage_multiplier: float = 1.0
@export_range(0.1, 10.0, 0.05) var base_cooldown: float = 0.8
@export_range(0.5, 12.0, 0.05) var base_radius: float = 2.7
@export_range(0.05, 3.1416, 0.01) var base_half_angle: float = 0.28
@export_range(0.2, 4.0, 0.05) var base_corridor_width: float = 0.95
@export_range(1, 30, 1) var base_max_targets: int = 2
@export var base_tags: PackedStringArray = PackedStringArray(["melee", "physical", "strike"])
