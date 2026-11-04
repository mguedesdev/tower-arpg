extends RefCounted
class_name RunProgressionState
## Estado exclusivo de UMA tentativa. Não compartilhar como Resource entre personagens.

var level: int = 1
var xp: int = 0
var total_xp: int = 0
var pending_upgrade_choices: int = 0

var class_id: String = "warrior"
var available_ability_ids: Array[String] = ["warrior_strike"]
var acquired_upgrades: Dictionary = {}
var acquired_exclusivity_groups: Dictionary = {}
var excluded_upgrade_ids: Array[String] = []
var active_tags: Array[String] = ["melee", "physical", "strike", "stab"]
var meta_unlocks: Array[String] = []
var upgrade_history: Array[String] = []


func reset() -> void:
	level = 1
	xp = 0
	total_xp = 0
	pending_upgrade_choices = 0
	class_id = "warrior"
	available_ability_ids = ["warrior_strike"]
	acquired_upgrades.clear()
	acquired_exclusivity_groups.clear()
	excluded_upgrade_ids.clear()
	active_tags = ["melee", "physical", "strike", "stab"]
	meta_unlocks.clear()
	upgrade_history.clear()


func configure_for_class(p_class_id: String, p_ability_ids: Array[String], p_initial_tags: Array[String], p_meta_unlocks: Array[String] = []) -> void:
	reset()
	class_id = p_class_id
	available_ability_ids = p_ability_ids.duplicate()
	active_tags = p_initial_tags.duplicate()
	meta_unlocks = p_meta_unlocks.duplicate()


func get_upgrade_rank(upgrade_id: String) -> int:
	return int(acquired_upgrades.get(upgrade_id, 0))


func has_upgrade(upgrade_id: String) -> bool:
	return get_upgrade_rank(upgrade_id) > 0


func has_tag(tag: String) -> bool:
	return active_tags.has(tag)


func add_tag(tag: String) -> void:
	if not tag.is_empty() and not active_tags.has(tag):
		active_tags.append(tag)


func has_chosen_any_transformation() -> bool:
	return acquired_exclusivity_groups.has("warrior_strike_primary_form") or has_tag("transformed")


func record_upgrade_choice(
	upgrade_id: String,
	exclusivity_group: String = "",
	newly_excluded: PackedStringArray = PackedStringArray(),
	granted_tags: PackedStringArray = PackedStringArray()
) -> void:
	if upgrade_id.is_empty():
		return
	var next_rank: int = get_upgrade_rank(upgrade_id) + 1
	acquired_upgrades[upgrade_id] = next_rank
	upgrade_history.append(upgrade_id)
	if not exclusivity_group.is_empty():
		acquired_exclusivity_groups[exclusivity_group] = upgrade_id
	for ex_id in newly_excluded:
		var ex_str: String = String(ex_id)
		if not ex_str.is_empty() and not excluded_upgrade_ids.has(ex_str):
			excluded_upgrade_ids.append(ex_str)
	for tag in granted_tags:
		add_tag(String(tag))
