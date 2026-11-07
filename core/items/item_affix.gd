extends RefCounted
class_name ItemAffix
## Modificador de equipamento em ARPG:
## • PREFIX: modificador primário (ex.: +Dano Físico, +Velocidade de Ataque %, +Armadura, +Vida Máxima).
## • SUFFIX: modificador secundário (ex.: +Força, +Agilidade, +Inteligência, +Chance de Crítico).
## • IMPLICIT: propriedade intrínseca fixa do item-base (ex.: +2 de Força no Anel de Rubi). Não consome cota de afixos aleatórios.
## • UNIQUE_FIXED: propriedade especial curada/fixa exclusiva de um item Único (Vermelho).
##
## CONVENÇÃO OBRIGATÓRIA DE TIERS:
## • T1 é SEMPRE o melhor tier (mais forte, maior requisito de ilvl).
## • Números maiores (ex.: T5 ou T6) são os tiers mais fracos (disponíveis desde ilvl 1).

enum AffixType {
	PREFIX,
	SUFFIX,
	IMPLICIT,
	UNIQUE_FIXED
}

var affix_id: String = ""
var affix_type: AffixType = AffixType.PREFIX
var stat_key: String = ""           ## ex: "damage", "attack_speed_pct", "armor", "max_health", "strength", "agility", "intelligence", "crit_chance"
var exclusion_group: String = ""    ## Impede dois afixos da mesma família/grupo no mesmo item
var value: float = 0.0              ## Valor exato sorteado (ex: 0.23 para +23%, ou 8.0 para +8)
var min_value: float = 0.0
var max_value: float = 0.0
var display_text: String = ""
var tier: int = 1                   ## 1 = Melhor tier (T1); número maior (ex: T5/T6) = tier inicial mais fraco
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


func to_dictionary() -> Dictionary:
	return {
		"affix_id": affix_id,
		"kind": int(affix_type),
		"stat_id": stat_key,
		"tier": tier,
		"rolled_value": value,
		"min_ilvl": min_ilvl,
		"exclusive_group": exclusion_group,
		"min_value": min_value,
		"max_value": max_value,
		"display_text": display_text,
	}


static func from_dictionary(data: Dictionary) -> ItemAffix:
	if data.is_empty():
		return null
	var id_str: String = String(data.get("affix_id", data.get("id", "")))
	var tier_num: int = maxi(1, int(data.get("tier", 1)))
	var rolled_val: float = float(data.get("rolled_value", data.get("value", 0.0)))

	# Se a família existir no catálogo de famílias de afixos, reconstrói metadados e texto a partir do valor salvo (SEM re-sortear!)
	var fam: Dictionary = LootBalanceConfig.get_affix_family(id_str)
	if not fam.is_empty():
		var f_kind: AffixType = int(fam.get("kind", AffixType.PREFIX)) as AffixType
		var f_stat: String = String(fam.get("stat_id", ""))
		var f_group: String = String(fam.get("exclusive_group", f_stat))
		var step: float = float(fam.get("roll_step", 1.0))
		if step > 0.0:
			rolled_val = snappedf(rolled_val, step)
		var t_min_ilvl: int = int(data.get("min_ilvl", 1))
		var t_min_val: float = float(data.get("min_value", rolled_val))
		var t_max_val: float = float(data.get("max_value", rolled_val))
		for t_entry in fam.get("tiers", []):
			if int(t_entry.get("tier", 0)) == tier_num:
				t_min_ilvl = int(t_entry.get("min_ilvl", 1))
				t_min_val = float(t_entry.get("min_value", rolled_val))
				t_max_val = float(t_entry.get("max_value", rolled_val))
				break
		var text_str: String = LootBalanceConfig.format_affix_value_text(fam, rolled_val)
		return ItemAffix.create(
			id_str,
			f_kind,
			f_stat,
			rolled_val,
			text_str,
			tier_num,
			t_min_ilvl,
			f_group,
			t_min_val,
			t_max_val
		)

	# Fallback para saves antigos ou afixos customizados/únicos
	var raw_kind: int = int(data.get("kind", data.get("affix_type", AffixType.PREFIX)))
	var stat_str: String = String(data.get("stat_id", data.get("stat_key", "")))
	var group_str: String = String(data.get("exclusive_group", data.get("exclusion_group", stat_str)))
	var min_ilvl_val: int = maxi(1, int(data.get("min_ilvl", 1)))
	var min_v: float = float(data.get("min_value", rolled_val))
	var max_v: float = float(data.get("max_value", rolled_val))
	var txt: String = String(data.get("display_text", ""))
	if txt.is_empty() and not stat_str.is_empty():
		if stat_str == "crit_chance" or stat_str == "attack_speed_pct" or stat_str == "move_speed":
			txt = "+%d%% %s" % [int(roundi(rolled_val * 100.0)), stat_str]
		else:
			txt = "+%d %s" % [int(roundi(rolled_val)), stat_str]
	return ItemAffix.create(
		id_str,
		clampi(raw_kind, AffixType.PREFIX, AffixType.UNIQUE_FIXED) as AffixType,
		stat_str,
		rolled_val,
		txt,
		tier_num,
		min_ilvl_val,
		group_str,
		min_v,
		max_v
	)
