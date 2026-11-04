extends "res://scripts/enemy.gd"
class_name TowerWolfEnemy

# Variante isolada do inimigo existente. Herda vida, dano de contato,
# perseguicao, morte, XP (via signal died), colisao, barra de vida 3D e flash de dano.
# Graças à arquitetura orientada a objetos (TowerEnemy + EnemyDefinition),
# o Lobo só precisa apontar para sua definição padrão!

const DEFAULT_WOLF_DEF_PATH: String = "res://content/enemies/wolf_enemy.tres"


func _get_default_definition_path() -> String:
	return DEFAULT_WOLF_DEF_PATH
