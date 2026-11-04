extends RefCounted
class_name ItemAffix
## Modificador aleatório (Afixo) de um item em ARPG (Prefixo ou Sufixo).

enum AffixType { PREFIX, SUFFIX }

var affix_id: String = ""
var affix_type: AffixType = AffixType.PREFIX
var stat_key: String = ""           ## ex: "damage", "armor", "max_health", "strength", "agility", "move_speed"
var value: float = 0.0
var display_text: String = ""


static func create(p_id: String, p_type: AffixType, p_stat: String, p_val: float, p_text: String) -> ItemAffix:
	var a := ItemAffix.new()
	a.affix_id = p_id
	a.affix_type = p_type
	a.stat_key = p_stat
	a.value = p_val
	a.display_text = p_text
	return a
