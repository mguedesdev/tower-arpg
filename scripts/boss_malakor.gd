extends "res://scripts/enemy.gd"
class_name BossMalakor

## Chefe Supremo do Mapa 3 (Cripta do Carrasco): Malakor, o Ceifador de Almas.
## Herda de TowerEnemy, com modelo 3D GLB esculpido em Blender, rig de 22 ossos,
## 4 animações fluidas (idle-loop, walk-loop, attack cleave, attack_sweep) e barra de vida de chefe.

const DEFAULT_BOSS_DEF_PATH: String = "res://content/enemies/boss_malakor.tres"


func _get_default_definition_path() -> String:
	return DEFAULT_BOSS_DEF_PATH
