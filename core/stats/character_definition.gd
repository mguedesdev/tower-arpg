extends Resource
class_name CharacterDefinition
## Dados estáticos da classe do personagem: atributos iniciais, habilidade inicial e identidade.

@export var class_id: String = "warrior"
@export var display_name: String = "Guerreiro"
@export_multiline var description: String = "Combatente corpo a corpo versátil, mestre em golpes de espada e posturas de impacto."
@export var base_max_health: int = 100
@export var base_damage: int = 14
@export var base_attack_speed: float = 1.0
@export var base_move_speed: float = 5.5
@export var base_crit_chance: float = 0.05
@export var base_crit_damage: float = 1.5
@export var base_cooldown_reduction: float = 0.0
@export var base_armor: float = 0.0
@export var base_area_scale: float = 1.0
@export var starting_ability: AbilityDefinition
