extends RefCounted
class_name RunSummaryState
## Estado consolidado do resultado de uma partida (Run).
## Inclui trava `reward_claimed` para impedir concessão duplicada de Essência.

var run_id: String = ""
var class_id: String = "warrior"
var waves_completed: int = 0
var wave_reached: int = 1
var enemies_defeated: int = 0
var bosses_defeated: int = 0
var special_objectives_completed: int = 0
var run_level_reached: int = 1
var total_xp_earned: int = 0
var difficulty_multiplier: float = 1.0
var victory: bool = false
var active_ability_name: String = "Estocada"
var acquired_upgrade_ids: Array[String] = []
var acquired_upgrade_titles: Array[String] = []

var essence_rewarded: int = 0
var reward_claimed: bool = false


func _init(p_run_id: String = "") -> void:
	if p_run_id.is_empty():
		run_id = "run_%d_%d" % [Time.get_ticks_msec(), randi()]
	else:
		run_id = p_run_id
