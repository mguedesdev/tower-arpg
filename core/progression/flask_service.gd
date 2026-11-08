extends RefCounted
class_name FlaskService
## Serviço central e autoral para o sistema de Frascos Recarregáveis (Doc 08 / PoE2 Style).
## Gerencia concessão de cargas por abates, consumo, recuperação contínua (HoT/MoT) e refil em checkpoints/poços.

signal flask_charges_changed(flask_instance: ItemInstance, amount_added: int, current: int, max_cap: int)
signal flask_used(slot_index: int, flask_instance: ItemInstance, remaining_uses: int)
signal recovery_started(resource_type: String, total_amount: float, duration: float)
signal recovery_finished(resource_type: String)

# Tabela oficial de cargas por classificação de monstro (Doc 08 Seção 5.2)
const KILL_CHARGES_NORMAL: int = 1
const KILL_CHARGES_MAGIC: int = 3
const KILL_CHARGES_RARE: int = 7
const KILL_CHARGES_ELITE: int = 10
const KILL_CHARGES_BOSS: int = 20

# Estado ativo de recuperação ao longo do tempo (HoT / MoT)
var active_recoveries: Dictionary = {
	"life": {"remaining_amount": 0.0, "rate": 0.0, "remaining_time": 0.0},
	"mana": {"remaining_amount": 0.0, "rate": 0.0, "remaining_time": 0.0}
}


static func get_kill_charges(enemy_rank: int) -> int:
	match enemy_rank:
		0: # Normal (Branco)
			return KILL_CHARGES_NORMAL
		1: # Mágico (Azul)
			return KILL_CHARGES_MAGIC
		2: # Raro (Amarelo)
			return KILL_CHARGES_RARE
		3: # Herói / Elite (Roxo)
			return KILL_CHARGES_ELITE
		4: # Chefe (Vermelho)
			return KILL_CHARGES_BOSS
		_:
			return KILL_CHARGES_NORMAL


## Concede cargas por morte de inimigo válido aos frascos equipados.
## Cada frasco equipado recebe integralmente o ganho (independência mútua, Seção 5.1).
static func apply_kill_charges_to_flask(flask: ItemInstance, enemy_rank: int, threat_multiplier: float = 1.0) -> int:
	if flask == null or not flask.is_flask():
		return 0
	var base_reward: int = get_kill_charges(enemy_rank)
	var final_reward: int = maxi(0, int(round(float(base_reward) * threat_multiplier)))
	return flask.add_charges(final_reward)


## Inicia ou reinicia recuperação contínua (Seção 4: reinicia sem acumular do mesmo recurso)
func start_recovery(resource_type: String, amount: float, duration: float) -> void:
	if duration <= 0.0 or amount <= 0.0:
		return
	var rate: float = amount / duration
	active_recoveries[resource_type] = {
		"remaining_amount": amount,
		"rate": rate,
		"remaining_time": duration
	}
	recovery_started.emit(resource_type, amount, duration)


## Processa o avanço temporal das recuperações ativas (HoT/MoT)
## Retorna um Dictionary com os deltas aplicados: {"life": float, "mana": float}
func update_recovery(delta: float, current_hp: float, max_hp: float, current_mp: float, max_mp: float) -> Dictionary:
	var deltas: Dictionary = {"life": 0.0, "mana": 0.0}
	for res in ["life", "mana"]:
		var rec: Dictionary = active_recoveries[res]
		var rem_time: float = float(rec["remaining_time"])
		if rem_time <= 0.0:
			continue
		
		var cur_val: float = current_hp if res == "life" else current_mp
		var max_val: float = max_hp if res == "life" else max_mp
		
		# Se já atingiu o máximo, encerra antecipadamente (Seção 6)
		if cur_val >= max_val:
			active_recoveries[res]["remaining_time"] = 0.0
			active_recoveries[res]["remaining_amount"] = 0.0
			recovery_finished.emit(res)
			continue
		
		var step_time: float = minf(delta, rem_time)
		var step_gain: float = float(rec["rate"]) * step_time
		var cap_gain: float = minf(step_gain, max_val - cur_val)
		deltas[res] = cap_gain
		
		rec["remaining_time"] = rem_time - step_time
		rec["remaining_amount"] = maxf(0.0, float(rec["remaining_amount"]) - step_gain)
		
		if float(rec["remaining_time"]) <= 0.0 or float(rec["remaining_amount"]) <= 0.0:
			recovery_finished.emit(res)
	return deltas


## Cancela todas as recuperações ativas (ex.: transição de cena ou morte do personagem)
func clear_recoveries() -> void:
	for res in ["life", "mana"]:
		if float(active_recoveries[res]["remaining_time"]) > 0.0:
			recovery_finished.emit(res)
		active_recoveries[res] = {"remaining_amount": 0.0, "rate": 0.0, "remaining_time": 0.0}
