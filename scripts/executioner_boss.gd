extends "res://scripts/enemy.gd"
class_name TowerExecutionerBoss

# Mini-Boss de Wave (O Carrasco Profanado).
# Herda toda a arquitetura orientada a objetos de TowerEnemy + EnemyDefinition + EnemyHealthBar3D.

const DEFAULT_BOSS_DEF_PATH: String = "res://content/enemies/executioner_boss.tres"


func _get_default_definition_path() -> String:
	return DEFAULT_BOSS_DEF_PATH
