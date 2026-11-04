extends RefCounted
class_name UpgradeCatalog
## Carrega o catálogo padrão de evoluções editáveis (.tres) de content/progression/upgrades/.

const DEFAULT_UPGRADE_PATHS: Array[String] = [
	"res://content/progression/upgrades/trans_meia_lua.tres",
	"res://content/progression/upgrades/trans_perfuracao.tres",
	"res://content/progression/upgrades/trans_giro.tres",
	"res://content/progression/upgrades/stat_dano.tres",
	"res://content/progression/upgrades/stat_velocidade_ataque.tres",
	"res://content/progression/upgrades/mod_fogo.tres",
	"res://content/progression/upgrades/stat_vida_maxima.tres",
	"res://content/progression/upgrades/ability_alcance.tres",
	"res://content/progression/upgrades/mod_eco.tres",
]


static func load_default_pool() -> Array[ProgressionUpgradeDefinition]:
	var pool: Array[ProgressionUpgradeDefinition] = []
	for path in DEFAULT_UPGRADE_PATHS:
		if ResourceLoader.exists(path):
			var res: ProgressionUpgradeDefinition = load(path) as ProgressionUpgradeDefinition
			if res != null:
				pool.append(res)
	return pool
