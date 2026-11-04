extends Resource
class_name TalentNodeDefinition
## Definição de um nó da árvore permanente de talentos (Metaprogressão).

enum NodeType {
	ATTRIBUTE = 0,
	SPECIALIZATION = 1,
	UNLOCK = 2,
	RULE_MODIFIER = 3,
}

@export var id: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
@export var preview_text: String = ""
@export var node_type: int = NodeType.ATTRIBUTE
@export_range(1, 9999, 1) var cost: int = 10
@export_range(1, 10, 1) var max_rank: int = 1
@export var target_class_id: String = ""

## Todos os IDs em `prerequisite_ids` devem estar desbloqueados.
@export var prerequisite_ids: PackedStringArray = PackedStringArray()
## Se preenchido, basta que PELO MENOS UM dos IDs em `any_prerequisite_ids` esteja desbloqueado.
@export var any_prerequisite_ids: PackedStringArray = PackedStringArray()

## Lista de modificadores de atributo por rank: [{"stat": "max_health", "op": 0, "value": 20.0}]
@export var stat_modifiers_data: Array[Dictionary] = []
## Identificadores liberados para o gerador de ofertas e habilidades (ex.: "unlock_spin", "pyromancy_boost").
@export var granted_meta_unlocks: PackedStringArray = PackedStringArray()
## Bônus de regra no começo da partida (ex.: XP inicial).
@export var starting_xp_bonus: int = 0
@export var ui_grid_pos: Vector2 = Vector2.ZERO


func type_label() -> String:
	match node_type:
		NodeType.ATTRIBUTE:
			return "ATRIBUTO"
		NodeType.SPECIALIZATION:
			return "ESPECIALIZAÇÃO"
		NodeType.UNLOCK:
			return "DESBLOQUEIO"
		NodeType.RULE_MODIFIER:
			return "MODIFICADOR DE PARTIDA"
		_:
			return "TALENTO"


static func build_default_tree() -> Array[TalentNodeDefinition]:
	var nodes: Array[TalentNodeDefinition] = []

	var n1 := TalentNodeDefinition.new()
	n1.id = "talent_vitality_root"
	n1.title = "Sangue Ancestral"
	n1.description = "Fortalece a constituição física ao entrar na Torre."
	n1.preview_text = "+20 Vida Máxima inicial por nível"
	n1.node_type = NodeType.ATTRIBUTE
	n1.cost = 8
	n1.max_rank = 2
	n1.stat_modifiers_data = [{"stat": "max_health", "op": 0, "value": 20.0}]
	n1.ui_grid_pos = Vector2(0, 0)
	nodes.append(n1)

	var n2 := TalentNodeDefinition.new()
	n2.id = "talent_warrior_might"
	n2.title = "Fúria do Guerreiro"
	n2.description = "Treinamento exclusivo do Guerreiro em golpes pesados."
	n2.preview_text = "+18% Dano Base (Exclusivo: Guerreiro)"
	n2.node_type = NodeType.ATTRIBUTE
	n2.cost = 12
	n2.max_rank = 2
	n2.target_class_id = "warrior"
	n2.prerequisite_ids = PackedStringArray(["talent_vitality_root"])
	n2.stat_modifiers_data = [{"stat": "damage", "op": 1, "value": 0.18}]
	n2.ui_grid_pos = Vector2(-1, 1)
	nodes.append(n2)

	var n3 := TalentNodeDefinition.new()
	n3.id = "talent_swift_reflexes"
	n3.title = "Reflexos de Aço"
	n3.description = "Especialização em cadência de combate e deslocamento ágil."
	n3.preview_text = "+15% Velocidade de Ataque e +8% Velocidade de Movimento"
	n3.node_type = NodeType.SPECIALIZATION
	n3.cost = 12
	n3.max_rank = 1
	n3.prerequisite_ids = PackedStringArray(["talent_vitality_root"])
	n3.stat_modifiers_data = [
		{"stat": "attack_speed", "op": 1, "value": 0.15},
		{"stat": "move_speed", "op": 1, "value": 0.08}
	]
	n3.ui_grid_pos = Vector2(1, 1)
	nodes.append(n3)

	var n4 := TalentNodeDefinition.new()
	n4.id = "talent_unlock_whirlwind"
	n4.title = "Segredo do Turbilhão"
	n4.description = "Desbloqueia a transformação avançada [Giro 360] nas ofertas de evolução após escolher Meia-lua."
	n4.preview_text = "Desbloqueia evolução: Transformação Giro 360"
	n4.node_type = NodeType.UNLOCK
	n4.cost = 18
	n4.max_rank = 1
	n4.target_class_id = "warrior"
	n4.prerequisite_ids = PackedStringArray(["talent_warrior_might"])
	n4.granted_meta_unlocks = PackedStringArray(["unlock_spin"])
	n4.ui_grid_pos = Vector2(-1, 2)
	nodes.append(n4)

	var n5 := TalentNodeDefinition.new()
	n5.id = "talent_pyromancy_spec"
	n5.title = "Cinzas Profanas"
	n5.description = "Aumenta a potência da Queimadura em +35% e torna a evolução Lâmina Ígnea mais frequente nas partidas."
	n5.preview_text = "+35% Dano de Queimadura e +60% Peso de Oferta"
	n5.node_type = NodeType.SPECIALIZATION
	n5.cost = 18
	n5.max_rank = 1
	n5.prerequisite_ids = PackedStringArray(["talent_swift_reflexes"])
	n5.granted_meta_unlocks = PackedStringArray(["pyromancy_boost"])
	n5.ui_grid_pos = Vector2(1, 2)
	nodes.append(n5)

	var n6 := TalentNodeDefinition.new()
	n6.id = "talent_veteran_herald"
	n6.title = "Brasão do Veterano"
	n6.description = "Altera o início da partida: você já começa com +8 XP acumulada e +12% de alcance/área em todos os golpes."
	n6.preview_text = "Início da Run: +8 XP Inicial e +12% Alcance/Área"
	n6.node_type = NodeType.RULE_MODIFIER
	n6.cost = 24
	n6.max_rank = 1
	n6.any_prerequisite_ids = PackedStringArray(["talent_unlock_whirlwind", "talent_pyromancy_spec"])
	n6.stat_modifiers_data = [{"stat": "area_scale", "op": 1, "value": 0.12}]
	n6.starting_xp_bonus = 8
	n6.ui_grid_pos = Vector2(0, 3)
	nodes.append(n6)

	return nodes
