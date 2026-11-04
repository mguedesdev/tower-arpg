extends Resource
class_name EnemyDefinition
## Definição orientada a dados/objetos para qualquer tipo de inimigo (Esqueleto, Lobo, Mini-Boss, etc.).
## Permite criar novos inimigos apenas configurando atributos, modelo 3D e altura/largura da barra de vida.

@export var enemy_id: String = "skeleton"
@export var display_name: String = "Esqueleto"
@export var model_path: String = "res://assets/models/skeleton_enemy.glb"
@export var base_max_health: int = 32
@export var base_movement_speed: float = 2.3
@export var base_touch_damage: int = 8
@export var health_bar_height: float = 1.92
@export var health_bar_width_scale: float = 1.0
@export var visual_scale: float = 1.0
@export var visual_yaw_degrees: float = 0.0
@export var visual_offset_y: float = 0.0
@export var walk_stride_meters: float = 1.55
@export var xp_reward_multiplier: int = 1
@export var is_mini_boss: bool = false
