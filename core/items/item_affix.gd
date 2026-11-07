extends RefCounted
class_name ItemAffix
## Modificador de equipamento em ARPG:
## • PREFIX: modificador primário ofensivo/defensivo (ex.: +Dano Físico, +Armadura, +Vida Máxima).
## • SUFFIX: modificador secundário de atributo/utilidade (ex.: +Força, +Agilidade, +Inteligência, +Chance de Crítico, +Vel. Movimento).
## • IMPLICIT: propriedade intrínseca fixa do item-base (ex.: +2 de Força no Anel de Rubi). Não conta no limite de afixos aleatórios.
## • UNIQUE_FIXED: propriedade especial curada/fixa exclusiva de um item Único (Vermelho).

enum AffixType {
	PREFIX,
	SUFFIX,
	IMPLICIT,
	UNIQUE_FIXED
}

var affix_id: String = ""
var affix_type: AffixType = AffixType.PREFIX
var stat_key: String = ""           ## ex: "damage", "armor", "max_health", "strength", "agility", "intelligence", "crit_chance", "move_speed"
var exclusion_group: String = ""    ## Impede dois afixos da mesma família no mesmo item
var value: float = 0.0
var min_value: float = 0.0
var max_value: float = 0.0
var display_text: String = ""
var tier: int = 1
var min_ilvl: int = 1


static func create(
	p_id: String,
	p_type: AffixType,
	p_stat: String,
	p_val: float,
	p_text: String,
	p_tier: int = 1,
	p_min_ilvl: int = 1,
	p_exclusion_group: String = "",
	p_min_val: float = 0.0,
	p_max_val: float = 0.0
) -> ItemAffix:
	var a := ItemAffix.new()
	a.affix_id = p_id
	a.affix_type = p_type
	a.stat_key = p_stat
	a.exclusion_group = p_exclusion_group if not p_exclusion_group.is_empty() else p_stat
	a.value = p_val
	a.min_value = p_min_val if p_min_val != 0.0 else p_val
	a.max_value = p_max_val if p_max_val != 0.0 else p_val
	a.display_text = p_text
	a.tier = p_tier
	a.min_ilvl = p_min_ilvl
	return a


func duplicate_affix() -> ItemAffix:
	return ItemAffix.create(
		affix_id,
		affix_type,
		stat_key,
		value,
		display_text,
		tier,
		min_ilvl,
		exclusion_group,
		min_value,
		max_value
	)
