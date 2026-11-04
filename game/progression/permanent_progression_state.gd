extends RefCounted
class_name PermanentProgressionState
## Estado persistente entre partidas (Moeda permanente, nós adquiridos e desbloqueios).

const CURRENT_SCHEMA_VERSION: int = 1

var schema_version: int = CURRENT_SCHEMA_VERSION
var profile_id: String = "default_profile"
var currency_name: String = "Essência"
var essence: int = 0
var total_essence_earned: int = 0
var unlocked_talents: Dictionary = {}
var meta_unlocks: Array[String] = []


func reset_all() -> void:
	schema_version = CURRENT_SCHEMA_VERSION
	essence = 0
	total_essence_earned = 0
	unlocked_talents.clear()
	meta_unlocks.clear()


func get_talent_rank(talent_id: String) -> int:
	return int(unlocked_talents.get(talent_id, 0))


func is_talent_unlocked(talent_id: String) -> bool:
	return get_talent_rank(talent_id) > 0


func to_dictionary() -> Dictionary:
	return {
		"schema_version": schema_version,
		"profile_id": profile_id,
		"currency_name": currency_name,
		"essence": maxi(0, essence),
		"total_essence_earned": maxi(0, total_essence_earned),
		"unlocked_talents": unlocked_talents.duplicate(true),
		"meta_unlocks": meta_unlocks.duplicate(),
	}
