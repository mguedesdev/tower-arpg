extends Resource
class_name SkillDefinition
## Definição orientada a objetos de uma skill ativa do jogador (ARPG estilo Diablo 2 / Path of Exile 2).
## Cada classe (Guerreiro, Mago...) tem seu próprio conjunto de SkillDefinitions.
## O PlayerSkillController lê estes dados para mirar, perseguir o mob clicado, animar e aplicar dano.

enum Shape { CONE = 0, CIRCLE = 1, LINE = 2 }

@export var skill_id: String = "basic_stab"
@export var display_name: String = "Estocada"
@export_multiline var description: String = ""
@export var icon_path: String = "res://game/ui/icons/stab.png"
@export var is_basic_attack: bool = false

## Geometria do golpe
@export var shape: Shape = Shape.CONE
@export var hit_range: float = 2.6          ## Alcance (raio do cone/círculo ou comprimento da linha)
@export var half_angle_deg: float = 22.0    ## Abertura do cone (metade)
@export var line_width: float = 1.1         ## Largura do corredor (LINE)
@export var max_targets: int = 3

## Dano e ritmo
@export var damage_multiplier: float = 1.0
@export var base_cooldown: float = 0.62     ## Escala com Velocidade de Ataque e Redução de Recarga
@export var cast_lock: float = 0.34         ## Tempo em que o personagem fica "preso" executando o golpe
@export var mana_cost: int = 0              ## Custo de mana para conjurar

## Efeitos extras
@export var burn_dps: float = 0.0
@export var burn_duration: float = 0.0

## Visual: 0 estocada, 1 meia-lua, 2 giro, 3 perfuração (mesma ordem do TowerPlayer.play_attack_animation)
@export var animation_form: int = 0
@export var vfx_kind: String = "stab"       ## stab | arc | spin | pierce | ember
@export var accent_color: Color = Color(1.0, 0.62, 0.26)


func get_cooldown(stats: CharacterStats) -> float:
	var cd: float = base_cooldown
	if stats != null:
		var aspd: float = maxf(0.2, stats.get_attack_speed())
		cd = cd / aspd
		cd *= clampf(1.0 - stats.get_cooldown_reduction(), 0.35, 1.0)
	return maxf(0.12, cd)


func get_attack_reach() -> float:
	## Distância a partir da qual o personagem para de perseguir e golpeia.
	match shape:
		Shape.CIRCLE:
			return hit_range * 0.82
		Shape.LINE:
			return hit_range * 0.88
		_:
			return hit_range * 0.86


static func build_warrior_skills() -> Dictionary:
	var skills: Dictionary = {}

	var stab := SkillDefinition.new()
	stab.skill_id = "basic_stab"
	stab.display_name = "Estocada"
	stab.description = "Ataque básico. Golpe frontal rápido que perfura o inimigo à frente."
	stab.icon_path = "res://game/ui/icons/stab.png"
	stab.is_basic_attack = true
	stab.mana_cost = 0
	stab.shape = Shape.CONE
	stab.hit_range = 2.55
	stab.half_angle_deg = 26.0
	stab.max_targets = 2
	stab.damage_multiplier = 1.0
	stab.base_cooldown = 0.58
	stab.cast_lock = 0.0
	stab.animation_form = 0
	stab.vfx_kind = "stab"
	stab.accent_color = Color(1.0, 0.62, 0.26)
	skills[stab.skill_id] = stab

	var arc := SkillDefinition.new()
	arc.skill_id = "cleave_arc"
	arc.display_name = "Corte em Meia-Lua"
	arc.description = "Golpe pesado em arco amplo que atinge todos os inimigos à sua frente."
	arc.icon_path = "res://game/ui/icons/arc.png"
	arc.mana_cost = 6
	arc.shape = Shape.CONE
	arc.hit_range = 2.65
	arc.half_angle_deg = 82.0
	arc.max_targets = 8
	arc.damage_multiplier = 1.25
	arc.base_cooldown = 1.10
	arc.cast_lock = 0.0
	arc.animation_form = 1
	arc.vfx_kind = "arc"
	arc.accent_color = Color(0.48, 0.76, 1.0)
	skills[arc.skill_id] = arc

	var spin := SkillDefinition.new()
	spin.skill_id = "whirlwind_spin"
	spin.display_name = "Redemoinho de Aço"
	spin.description = "Giro de 360° que retalha todos os inimigos ao redor."
	spin.icon_path = "res://game/ui/icons/spin.png"
	spin.mana_cost = 14
	spin.shape = Shape.CIRCLE
	spin.hit_range = 2.45
	spin.max_targets = 12
	spin.damage_multiplier = 1.10
	spin.base_cooldown = 2.40
	spin.cast_lock = 0.0
	spin.animation_form = 2
	spin.vfx_kind = "spin"
	spin.accent_color = Color(0.96, 0.78, 0.34)
	skills[spin.skill_id] = spin

	var pierce := SkillDefinition.new()
	pierce.skill_id = "impale_pierce"
	pierce.display_name = "Lança Empaladora"
	pierce.description = "Investida perfurante de longo alcance que atravessa inimigos em linha reta."
	pierce.icon_path = "res://game/ui/icons/stab.png"
	pierce.mana_cost = 10
	pierce.shape = Shape.LINE
	pierce.hit_range = 4.8
	pierce.line_width = 1.15
	pierce.max_targets = 8
	pierce.damage_multiplier = 1.45
	pierce.base_cooldown = 1.80
	pierce.cast_lock = 0.0
	pierce.animation_form = 3
	pierce.vfx_kind = "pierce"
	pierce.accent_color = Color(0.56, 0.90, 0.98)
	skills[pierce.skill_id] = pierce

	var ember := SkillDefinition.new()
	ember.skill_id = "ember_strike"
	ember.display_name = "Golpe Incandescente"
	ember.description = "Estocada imbuída em brasas: explode no impacto e aplica Queimadura."
	ember.icon_path = "res://game/ui/icons/stab.png"
	ember.mana_cost = 12
	ember.shape = Shape.CONE
	ember.hit_range = 2.75
	ember.half_angle_deg = 40.0
	ember.max_targets = 4
	ember.damage_multiplier = 1.30
	ember.base_cooldown = 3.20
	ember.cast_lock = 0.0
	ember.burn_dps = 9.0
	ember.burn_duration = 3.5
	ember.animation_form = 0
	ember.vfx_kind = "ember"
	ember.accent_color = Color(1.0, 0.36, 0.10)
	skills[ember.skill_id] = ember

	return skills
