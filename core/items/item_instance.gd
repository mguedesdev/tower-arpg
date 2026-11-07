extends RefCounted
class_name ItemInstance
## Instância de item real gerada no jogo com raridade, afixos e estado de identificação.

enum ItemRarity {
	NORMAL,   ## Branco
	MAGIC,    ## Azul (1-2 afixos)
	RARE,     ## Amarelo (3-5 afixos)
	UNIQUE    ## Dourado/Lendário (afixos fixos exclusivos)
}

const COLOR_NORMAL := Color(0.92, 0.92, 0.92)
const COLOR_MAGIC := Color(0.35, 0.65, 1.0)
const COLOR_RARE := Color(1.0, 0.88, 0.28)
const COLOR_UNIQUE := Color(0.98, 0.58, 0.16)

var uid: String = ""
var definition: ItemDefinition
var rarity: ItemRarity = ItemRarity.NORMAL
var item_level: int = 1
var is_identified: bool = true
var explicit_affixes: Array[ItemAffix] = []
var custom_name: String = ""

# Posição de inventário e orientação (deitado ↔ em pé)
var grid_position: Vector2i = Vector2i(-1, -1)
var is_rotated: bool = false
var equipped_slot: ItemDefinition.EquipmentSlot = ItemDefinition.EquipmentSlot.NONE


func get_grid_size() -> Vector2i:
	if definition == null:
		return Vector2i.ONE
	if is_rotated:
		return Vector2i(definition.grid_size.y, definition.grid_size.x)
	return definition.grid_size


func can_rotate() -> bool:
	if definition == null:
		return false
	return definition.grid_size.x != definition.grid_size.y


func toggle_rotation() -> bool:
	if not can_rotate():
		return false
	is_rotated = not is_rotated
	return true


func _init(p_def: ItemDefinition = null, p_rarity: ItemRarity = ItemRarity.NORMAL, p_ilvl: int = 1) -> void:
	uid = "%d_%d" % [Time.get_ticks_msec(), randi()]
	definition = p_def
	rarity = p_rarity
	item_level = p_ilvl
	is_identified = (p_rarity == ItemRarity.NORMAL)


func get_display_name() -> String:
	if definition == null:
		return "Item Desconhecido"
	if not is_identified:
		match rarity:
			ItemRarity.MAGIC:
				return "Item Mágico Não-Identificado"
			ItemRarity.RARE:
				return "Item Raro Não-Identificado"
			ItemRarity.UNIQUE:
				return "Item Lendário Não-Identificado"
	if not custom_name.is_empty():
		return custom_name
	return definition.display_name


func get_rarity_color() -> Color:
	match rarity:
		ItemRarity.MAGIC:
			return COLOR_MAGIC
		ItemRarity.RARE:
			return COLOR_RARE
		ItemRarity.UNIQUE:
			return COLOR_UNIQUE
		_:
			return COLOR_NORMAL


func get_stat_bonus(stat_key: String) -> float:
	var total: float = 0.0
	for affix in explicit_affixes:
		if affix != null and affix.stat_key == stat_key:
			total += affix.value
	return total


func get_total_armor() -> int:
	if definition == null:
		return 0
	var base: int = definition.base_armor
	return base + roundi(get_stat_bonus("armor"))


func get_damage_range() -> Vector2i:
	if definition == null:
		return Vector2i.ZERO
	var bonus: int = roundi(get_stat_bonus("damage"))
	return Vector2i(definition.base_damage_min + bonus, definition.base_damage_max + bonus)


func meets_requirements(stats: CharacterStats) -> bool:
	if definition == null or stats == null:
		return true
	# Atributos no CharacterStats
	var str_val: int = int(roundi(stats.get_stat(&"strength") if stats.has_method("get_stat") else 0.0))
	var agi_val: int = int(roundi(stats.get_stat(&"agility") if stats.has_method("get_stat") else 0.0))
	var int_val: int = int(roundi(stats.get_stat(&"intelligence") if stats.has_method("get_stat") else 0.0))
	if str_val < definition.req_strength:
		return false
	if agi_val < definition.req_agility:
		return false
	if int_val < definition.req_intelligence:
		return false
	return true


func identify() -> void:
	is_identified = true


func get_buy_price() -> int:
	if definition == null:
		return 10
	var rarity_mult: float = 1.0
	match rarity:
		ItemRarity.MAGIC:
			rarity_mult = 1.65
		ItemRarity.RARE:
			rarity_mult = 2.60
		ItemRarity.UNIQUE:
			rarity_mult = 4.50
	var base: float = float(maxi(10, definition.base_gold_value)) * rarity_mult
	var affix_bonus: int = explicit_affixes.size() * 14
	var lvl_bonus: int = maxi(0, item_level - 1) * 12
	return int(roundi(base)) + affix_bonus + lvl_bonus


func get_sell_value() -> int:
	return maxi(5, int(roundi(float(get_buy_price()) * 0.42)))


func get_total_stat_value(stat_key: String) -> float:
	if definition == null:
		return 0.0
	match stat_key:
		"avg_damage":
			var r: Vector2i = get_damage_range()
			return float(r.x + r.y) * 0.5
		"attack_speed":
			if definition.category == ItemDefinition.ItemCategory.WEAPON_1H or definition.category == ItemDefinition.ItemCategory.WEAPON_2H:
				return definition.base_attack_speed
			return 0.0
		"armor":
			return float(get_total_armor())
		"max_health":
			var base_hp: float = float(definition.base_health) if definition.category != ItemDefinition.ItemCategory.CONSUMABLE else 0.0
			return base_hp + get_stat_bonus("max_health")
		"move_speed_pct":
			return (definition.base_move_speed_pct * 100.0) + (get_stat_bonus("move_speed") * 100.0)
		"crit_chance":
			return get_stat_bonus("crit_chance") * 100.0
		_:
			return get_stat_bonus(stat_key)


static func _format_inline_diff(diff: float, is_float_2dec: bool = false, is_percent: bool = false) -> String:
	if absf(diff) < 0.005:
		return " [color=#8b939c](=)[/color]"
	var arrow: String = "▲" if diff > 0.0 else "▼"
	var col: String = "#4dff6b" if diff > 0.0 else "#ff4d4d"
	var sign_str: String = "+" if diff > 0.0 else ""
	if is_float_2dec:
		return " [color=%s][b]%s (%s%.2fx)[/b][/color]" % [col, arrow, sign_str, diff]
	elif is_percent:
		return " [color=%s][b]%s (%s%d%%)[/b][/color]" % [col, arrow, sign_str, int(roundi(diff))]
	else:
		return " [color=%s][b]%s (%s%d)[/b][/color]" % [col, arrow, sign_str, int(roundi(diff))]


func get_slot_display_name() -> String:
	if definition == null:
		return "Item"
	match definition.category:
		ItemDefinition.ItemCategory.WEAPON_1H:
			return "Arma de 1 Mão"
		ItemDefinition.ItemCategory.WEAPON_2H:
			return "Arma Pesada de 2 Mãos"
		ItemDefinition.ItemCategory.SHIELD:
			return "Escudo (Mão Secundária)"
		ItemDefinition.ItemCategory.HELMET:
			return "Elmo"
		ItemDefinition.ItemCategory.CHEST:
			return "Armadura Peitoral"
		ItemDefinition.ItemCategory.GLOVES:
			return "Manoplas / Luvas"
		ItemDefinition.ItemCategory.BOOTS:
			return "Grevas / Botas"
		ItemDefinition.ItemCategory.BELT:
			return "Cinto"
		ItemDefinition.ItemCategory.AMULET:
			return "Amuleto"
		ItemDefinition.ItemCategory.RING:
			return "Anel"
		ItemDefinition.ItemCategory.CONSUMABLE:
			return "Consumível"
	return "Equipamento"


func format_tooltip_bbcode(stats: CharacterStats = null, equipment: Object = null, action_hint: String = "", custom_price_line: String = "") -> String:
	if definition == null:
		return ""
	var r_col: String = get_rarity_color().to_html(false)
	var t: String = "[center][b][color=#%s]%s[/color][/b]\n" % [r_col, get_display_name()]
	t += "[color=#9a9284]%s (Nv. %d)[/color][/center]\n" % [get_slot_display_name(), item_level]

	if not is_identified:
		t += "[center][color=#ff5555][b]❓ Item Não-Identificado[/b]\nLeve ao Sábio na Vila para revelar seus poderes[/color][/center]\n"

	var is_self_equipped: bool = false
	var eq_item: ItemInstance = null
	var do_compare: bool = false

	if equipment != null and definition.is_equippable() and is_identified and equipment.has_method("get_equipped_item"):
		var slot_check: ItemDefinition.EquipmentSlot = definition.equip_slot
		var eq_in_primary: ItemInstance = equipment.call("get_equipped_item", slot_check) as ItemInstance
		var eq_in_ring2: ItemInstance = null
		if slot_check == ItemDefinition.EquipmentSlot.RING_1:
			eq_in_ring2 = equipment.call("get_equipped_item", ItemDefinition.EquipmentSlot.RING_2) as ItemInstance

		if equipped_slot != ItemDefinition.EquipmentSlot.NONE or eq_in_primary == self or eq_in_ring2 == self:
			is_self_equipped = true
		else:
			do_compare = true
			eq_item = eq_in_primary
			if slot_check == ItemDefinition.EquipmentSlot.RING_1 and eq_item == null and eq_in_ring2 != null:
				eq_item = eq_in_ring2

	if is_self_equipped:
		t += "[center][color=#4dff6b][ ✔ Equipado Atualmente ][/color][/center]\n"

	# 1. Linhas de Status Base (com setas ▲ verde / ▼ vermelha em cada linha!)
	if definition.category == ItemDefinition.ItemCategory.WEAPON_1H or definition.category == ItemDefinition.ItemCategory.WEAPON_2H:
		var dmg: Vector2i = get_damage_range()
		var line_dmg: String = "⚔ Dano: [color=#ffffff]%d - %d[/color]" % [dmg.x, dmg.y]
		if do_compare:
			var my_avg: float = float(dmg.x + dmg.y) * 0.5
			var eq_avg: float = eq_item.get_total_stat_value("avg_damage") if eq_item != null else 0.0
			line_dmg += _format_inline_diff(my_avg - eq_avg, false, false)
		t += line_dmg + "\n"

		var line_spd: String = "⚡ Vel. Ataque: [color=#ffffff]%.2fx[/color]" % definition.base_attack_speed
		if do_compare:
			var eq_spd: float = eq_item.get_total_stat_value("attack_speed") if (eq_item != null and eq_item.get_total_stat_value("attack_speed") > 0.0) else 1.0
			line_spd += _format_inline_diff(definition.base_attack_speed - eq_spd, true, false)
		t += line_spd + "\n"

	if get_total_armor() > 0:
		var arm: int = get_total_armor()
		var line_arm: String = "🛡️ Armadura: [color=#ffffff]%d[/color]" % arm
		if do_compare:
			var eq_arm: float = eq_item.get_total_stat_value("armor") if eq_item != null else 0.0
			line_arm += _format_inline_diff(float(arm) - eq_arm, false, false)
		t += line_arm + "\n"

	if definition.base_health > 0:
		if definition.category == ItemDefinition.ItemCategory.CONSUMABLE:
			t += "♥ Uso Imediato: [color=#4dff6b]Restaura +%d de Vida[/color]\n" % definition.base_health
		else:
			var line_hp: String = "♥ Vida Base: [color=#ffffff]+%d[/color]" % definition.base_health
			if do_compare:
				var eq_bhp: float = float(eq_item.definition.base_health) if (eq_item != null and eq_item.definition != null) else 0.0
				line_hp += _format_inline_diff(float(definition.base_health) - eq_bhp, false, false)
			t += line_hp + "\n"

	if definition.base_move_speed_pct > 0.0:
		var ms_pct: int = int(roundi(definition.base_move_speed_pct * 100.0))
		var line_ms: String = "👟 Vel. Movimento: [color=#ffffff]+%d%%[/color]" % ms_pct
		if do_compare:
			var eq_ms: float = (eq_item.definition.base_move_speed_pct * 100.0) if (eq_item != null and eq_item.definition != null) else 0.0
			line_ms += _format_inline_diff(float(ms_pct) - eq_ms, false, true)
		t += line_ms + "\n"

	# 2. Requisitos
	var req_text: String = ""
	if definition.req_strength > 0:
		var ok: bool = stats == null or stats.get_stat(&"strength") >= definition.req_strength
		var c: String = "#ffffff" if ok else "#ff4d4d"
		req_text += "Força: [color=%s]%d[/color]  " % [c, definition.req_strength]
	if definition.req_agility > 0:
		var ok: bool = stats == null or stats.get_stat(&"agility") >= definition.req_agility
		var c: String = "#ffffff" if ok else "#ff4d4d"
		req_text += "Agilidade: [color=%s]%d[/color]  " % [c, definition.req_agility]
	if definition.req_intelligence > 0:
		var ok: bool = stats == null or stats.get_stat(&"intelligence") >= definition.req_intelligence
		var c: String = "#ffffff" if ok else "#ff4d4d"
		req_text += "Inteligência: [color=%s]%d[/color]  " % [c, definition.req_intelligence]
	if not req_text.is_empty():
		t += "[color=#b3a898]Requer: " + req_text + "[/color]\n"

	# 3. Afixos Explícitos (com seta ▲ verde / ▼ vermelha em cada linha!)
	if is_identified and not explicit_affixes.is_empty():
		for af in explicit_affixes:
			if af == null:
				continue
			var af_line: String = "[color=#5dade2]• %s[/color]" % af.display_text
			if do_compare:
				if af.stat_key == "crit_chance":
					var my_c: float = af.value * 100.0
					var eq_c: float = (eq_item.get_stat_bonus("crit_chance") * 100.0) if eq_item != null else 0.0
					af_line += _format_inline_diff(my_c - eq_c, false, true)
				else:
					var eq_v: float = eq_item.get_stat_bonus(af.stat_key) if eq_item != null else 0.0
					af_line += _format_inline_diff(af.value - eq_v, false, false)
			t += af_line + "\n"

	# 4. Área Nova de Comparação Completa (O que GANHA em verde ▲ e o que PERDE em vermelho ▼)
	if do_compare:
		t += "[color=#5a5244]────────────────────────────[/color]\n"
		if eq_item != null:
			t += "[color=#c7bca8]Comparado ao [/color][b][color=#f2cb6f]Item Equipado:[/color][/b]\n"
		else:
			t += "[color=#c7bca8]Comparado a: [color=#8b939c]Slot Vazio[/color][/color]\n"

		var compare_defs: Array[Dictionary] = [
			{"key": "avg_damage", "label": "de Dano Médio", "float": false, "pct": false},
			{"key": "attack_speed", "label": "Vel. de Ataque", "float": true, "pct": false},
			{"key": "armor", "label": "de Armadura", "float": false, "pct": false},
			{"key": "max_health", "label": "de Vida Máxima", "float": false, "pct": false},
			{"key": "strength", "label": "de Força", "float": false, "pct": false},
			{"key": "agility", "label": "de Agilidade", "float": false, "pct": false},
			{"key": "intelligence", "label": "de Inteligência", "float": false, "pct": false},
			{"key": "crit_chance", "label": "Chance de Crítico", "float": false, "pct": true},
			{"key": "move_speed_pct", "label": "Vel. de Movimento", "float": false, "pct": true},
		]

		var gains: Array[String] = []
		var losses: Array[String] = []

		for cd in compare_defs:
			var k: String = String(cd["key"])
			if k == "attack_speed":
				var my_is_wep: bool = definition.category == ItemDefinition.ItemCategory.WEAPON_1H or definition.category == ItemDefinition.ItemCategory.WEAPON_2H
				var eq_is_wep: bool = eq_item != null and eq_item.definition != null and (eq_item.definition.category == ItemDefinition.ItemCategory.WEAPON_1H or eq_item.definition.category == ItemDefinition.ItemCategory.WEAPON_2H)
				if not my_is_wep and not eq_is_wep:
					continue
				var s_new: float = definition.base_attack_speed if my_is_wep else 1.0
				var s_old: float = eq_item.definition.base_attack_speed if eq_is_wep else 1.0
				var d_spd: float = s_new - s_old
				if d_spd > 0.005:
					gains.append("[color=#4dff6b]▲ Ganha +%.2fx %s[/color]" % [d_spd, String(cd["label"])])
				elif d_spd < -0.005:
					losses.append("[color=#ff4d4d]▼ Perde %.2fx %s[/color]" % [d_spd, String(cd["label"])])
				continue

			var v_new: float = get_total_stat_value(k)
			var v_old: float = eq_item.get_total_stat_value(k) if eq_item != null else 0.0
			var diff: float = v_new - v_old
			if absf(diff) < 0.05:
				continue
			var suffix: String = "%" if bool(cd["pct"]) else ""
			var diff_int: int = int(roundi(diff))
			if diff_int > 0:
				gains.append("[color=#4dff6b]▲ Ganha +%d%s %s[/color]" % [diff_int, suffix, String(cd["label"])])
			elif diff_int < 0:
				losses.append("[color=#ff4d4d]▼ Perde %d%s %s[/color]" % [diff_int, suffix, String(cd["label"])])

		if gains.is_empty() and losses.is_empty():
			t += "[color=#8b939c]  • Sem alteração líquida nos atributos[/color]\n"
		else:
			for g in gains:
				t += "  " + g + "\n"
			for l in losses:
				t += "  " + l + "\n"

	# 5. Rodapé de Preço e Ação Rápida
	t += "[color=#5a5244]────────────────────────────[/color]\n"
	if not custom_price_line.is_empty():
		t += custom_price_line + "\n"
	else:
		t += "🪙 Valor de Venda: [color=#f5d168]%d Ouro[/color]\n" % get_sell_value()
	if not action_hint.is_empty():
		t += "[color=#9ee0a8]%s[/color]" % action_hint

	return t
