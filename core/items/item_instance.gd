extends RefCounted
class_name ItemInstance
## Instância de item gerada no jogo com raridade, nível, propriedades intrínsecas (da definição)
## e modificadores explícitos (prefixos, sufixos ou propriedades especiais fixas de Único).

enum ItemRarity {
	NORMAL,    ## 0 - Branco (#E8E6E2): 0 modificadores aleatórios
	MAGIC,     ## 1 - Azul (#5596E6): 2 modificadores aleatórios
	RARE,      ## 2 - Amarelo (#EBC34D): 3–4 modificadores aleatórios
	UNIQUE,    ## 3 - Vermelho (#E45155): item único com propriedades especiais predefinidas
	UNCOMMON   ## 4 - Verde (#58BC76): 1 modificador aleatório (no final da enum para preservar índices serializados)
}

enum CraftState {
	NORMAL = 0,          ## 0 - Estado normal de crafting
	RECONSTRUCTING = 1,  ## 1 - Raro incompleto (ex.: 2P+0S após Rasura em 2P+1S) aguardando afixo complementar
	VERDICT_SEALED = 2   ## 2 - Lacrado permanentemente pelo Veredito (bloqueia todas as operações futuras)
}

const COLOR_NORMAL := Color("#E8E6E2")
const COLOR_UNCOMMON := Color("#58BC76")
const COLOR_MAGIC := Color("#5596E6")
const COLOR_RARE := Color("#EBC34D")
const COLOR_UNIQUE := Color("#E45155")

const CURRENT_SCHEMA_VERSION: int = 2
static var show_advanced_affix_tier_in_tooltip: bool = true

var uid: String = ""
var definition: ItemDefinition
var rarity: ItemRarity = ItemRarity.NORMAL
var item_level: int = 1
var is_identified: bool = true
var explicit_affixes: Array[ItemAffix] = []
var custom_name: String = ""
var unique_id: String = ""
var unique_display_name: String = ""

# Estado de Escrituras Arcanas / Crafting e Lacre do Veredito
var craft_state: CraftState = CraftState.NORMAL
var verdict_mode: String = ""
var craft_history: Array[Dictionary] = []

# Posição de inventário e orientação (deitado ↔ em pé)
var grid_position: Vector2i = Vector2i(-1, -1)
var is_rotated: bool = false
var equipped_slot: ItemDefinition.EquipmentSlot = ItemDefinition.EquipmentSlot.NONE


static func get_rarity_visual_order(r: ItemRarity) -> int:
	## Ordem lógica/visual crescente de raridade (independente do índice interno da enum):
	## 0 = Branco (NORMAL), 1 = Verde (UNCOMMON), 2 = Azul (MAGIC), 3 = Amarelo (RARE), 4 = Vermelho (UNIQUE)
	match r:
		ItemRarity.NORMAL:
			return 0
		ItemRarity.UNCOMMON:
			return 1
		ItemRarity.MAGIC:
			return 2
		ItemRarity.RARE:
			return 3
		ItemRarity.UNIQUE:
			return 4
	return 0


static func get_rarity_name_pt(r: ItemRarity) -> String:
	match r:
		ItemRarity.NORMAL:
			return "Normal"
		ItemRarity.UNCOMMON:
			return "Incomum"
		ItemRarity.MAGIC:
			return "Mágico"
		ItemRarity.RARE:
			return "Raro"
		ItemRarity.UNIQUE:
			return "Único"
	return "Normal"


static func get_rarity_name(r: ItemRarity) -> String:
	return get_rarity_name_pt(r)


static func rarity_from_id(rarity_id: String) -> ItemRarity:
	match rarity_id.to_lower().strip_edges():
		"uncommon", "verde", "incomum":
			return ItemRarity.UNCOMMON
		"magic", "azul", "magico", "mágico":
			return ItemRarity.MAGIC
		"rare", "amarelo", "raro":
			return ItemRarity.RARE
		"unique", "vermelho", "unico", "único":
			return ItemRarity.UNIQUE
		_:
			return ItemRarity.NORMAL


func get_grid_size() -> Vector2i:
	if definition == null:
		return Vector2i.ONE
	if is_rotated:
		return Vector2i(definition.grid_size.y, definition.grid_size.x)
	return definition.grid_size


func can_rotate() -> bool:
	if definition == null:
		return false
	if not definition.rotatable:
		return false
	return definition.grid_size.x != definition.grid_size.y


func is_sealed() -> bool:
	return craft_state == CraftState.VERDICT_SEALED


func is_reconstructing() -> bool:
	return craft_state == CraftState.RECONSTRUCTING


func add_craft_event(action_id: String, details: Dictionary = {}) -> void:
	var event := {
		"action": action_id,
		"timestamp": Time.get_ticks_msec(),
		"details": details
	}
	craft_history.append(event)
	if craft_history.size() > 20:
		craft_history.pop_front()


func toggle_rotation() -> bool:
	if not can_rotate():
		return false
	is_rotated = not is_rotated
	return true


func _init(p_def: ItemDefinition = null, p_rarity: ItemRarity = ItemRarity.NORMAL, p_ilvl: int = 1) -> void:
	uid = "%d_%d" % [Time.get_ticks_msec(), randi()]
	definition = p_def
	rarity = p_rarity
	item_level = maxi(1, p_ilvl)
	is_identified = (p_rarity == ItemRarity.NORMAL or p_rarity == ItemRarity.UNCOMMON)


func get_display_name() -> String:
	if definition == null:
		return "Item Desconhecido"
	if not is_identified:
		match rarity:
			ItemRarity.UNCOMMON:
				return "Item Incomum Não-Identificado"
			ItemRarity.MAGIC:
				return "Item Mágico Não-Identificado"
			ItemRarity.RARE:
				return "Item Raro Não-Identificado"
			ItemRarity.UNIQUE:
				return "Item Único Não-Identificado"
	# Regra do Ato 1: manter sempre o nome-base do equipamento (ou o nome próprio da definição Única), sem concatenar modificadores no nome!
	if rarity == ItemRarity.UNIQUE and not unique_display_name.is_empty():
		return unique_display_name
	return definition.display_name


func get_rarity_color() -> Color:
	match rarity:
		ItemRarity.UNCOMMON:
			return COLOR_UNCOMMON
		ItemRarity.MAGIC:
			return COLOR_MAGIC
		ItemRarity.RARE:
			return COLOR_RARE
		ItemRarity.UNIQUE:
			return COLOR_UNIQUE
		_:
			return COLOR_NORMAL


func get_implicit_affixes() -> Array[ItemAffix]:
	if definition == null:
		return []
	return definition.implicit_affixes


func get_implicit_stat_bonus(stat_key: String) -> float:
	if definition == null:
		return 0.0
	var total: float = 0.0
	for imp in definition.implicit_affixes:
		if imp != null and imp.stat_key == stat_key:
			total += imp.value
	return total


func get_explicit_stat_bonus(stat_key: String) -> float:
	var total: float = 0.0
	for affix in explicit_affixes:
		if affix != null and affix.stat_key == stat_key:
			total += affix.value
	return total


func get_stat_bonus(stat_key: String) -> float:
	## Retorna a soma de bônus intrínsecos (implícitos) + modificadores explícitos (prefixos/sufixos/únicos)
	## sem nunca duplicar propriedades intrínsecas.
	return get_implicit_stat_bonus(stat_key) + get_explicit_stat_bonus(stat_key)


func get_prefix_count() -> int:
	var c: int = 0
	for af in explicit_affixes:
		if af != null and af.affix_type == ItemAffix.AffixType.PREFIX:
			c += 1
	return c


func get_suffix_count() -> int:
	var c: int = 0
	for af in explicit_affixes:
		if af != null and af.affix_type == ItemAffix.AffixType.SUFFIX:
			c += 1
	return c


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
		ItemRarity.UNCOMMON:
			rarity_mult = 1.30
		ItemRarity.MAGIC:
			rarity_mult = 1.65
		ItemRarity.RARE:
			rarity_mult = 2.60
		ItemRarity.UNIQUE:
			rarity_mult = 4.50
	var base: float = float(maxi(9, definition.base_gold_value)) * rarity_mult
	var affix_bonus: int = explicit_affixes.size() * 12
	var lvl_bonus: int = maxi(0, item_level - 1) * 8
	return int(roundi(base)) + affix_bonus + lvl_bonus


func get_sell_value() -> int:
	return maxi(4, int(roundi(float(get_buy_price()) * 0.42)))


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
		"attack_speed_pct":
			return get_stat_bonus("attack_speed_pct") * 100.0
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
			return "Amuleto / Colar"
		ItemDefinition.ItemCategory.RING:
			return "Anel"
		ItemDefinition.ItemCategory.CONSUMABLE:
			return "Consumível"
	return "Equipamento"


func get_lore_description() -> String:
	if definition != null and not definition.description.is_empty():
		return definition.description
	if definition == null:
		return "Relíquia forjada nas profundezas de Velen."
	match definition.category:
		ItemDefinition.ItemCategory.WEAPON_2H:
			return "Uma montante antiga marcada por fissuras que ainda ardem."
		ItemDefinition.ItemCategory.WEAPON_1H:
			if definition.base_id.contains("dagger"):
				return "Lâmina curta para ataques rápidos e precisos."
			return "Lâmina equilibrada, confiável para os primeiros combates."
		ItemDefinition.ItemCategory.SHIELD:
			return "Um escudo resistente para aparar golpes e defender as muralhas."
		ItemDefinition.ItemCategory.CHEST:
			return "Placas de aço gastas, reforçadas para sobreviver."
		ItemDefinition.ItemCategory.HELMET:
			return "Proteção simples para quem encara a primeira batalha."
		ItemDefinition.ItemCategory.GLOVES:
			return "Manoplas articuladas que preservam a precisão."
		ItemDefinition.ItemCategory.BOOTS:
			return "Botas resistentes para marchas pelo terreno hostil."
		ItemDefinition.ItemCategory.BELT:
			return "Um cinto firme, feito para prender equipamento."
		ItemDefinition.ItemCategory.RING:
			return "A pedra preciosa fortalece o espírito do portador."
		ItemDefinition.ItemCategory.AMULET:
			return "Um talismã usado pelos batedores de Velen."
		ItemDefinition.ItemCategory.CONSUMABLE:
			return "Elixir alquímico puro que restaura o vigor vital instantaneamente."
	return "Equipamento temperado para enfrentar os horrores do Primeiro Ato."


func format_tooltip_bbcode(stats: CharacterStats = null, equipment: Object = null, action_hint: String = "", custom_price_line: String = "") -> String:
	if definition == null:
		return ""
	var r_col: String = get_rarity_color().to_html(false)
	var r_name: String = get_rarity_name_pt(rarity)
	var t: String = "[center][b][color=#%s]%s[/color][/b]\n" % [r_col, get_display_name()]
	t += "[color=#9a9284]%s • %s (Nv. %d)[/color][/center]\n" % [get_slot_display_name(), r_name, item_level]

	if is_sealed():
		t += "[center][color=#c084fc]✦ LACRADO PELO VEREDITO ✦[/color]\n[color=#b39ddb][i]Inscrição definitiva — não pode mais ser alterado[/i][/color][/center]\n"
	elif is_reconstructing():
		t += "[center][color=#f59e0b][i]✦ Em Reconstrução ✦\n(Requer Cláusula Áurea para novo afixo)[/i][/color][/center]\n"

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

	# 2. Requisitos (Nível, Força, Agilidade e Inteligência)
	var req_text: String = ""
	if definition.req_level > 1:
		req_text += "Nível: [color=#ffffff]%d[/color]  " % definition.req_level
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

	# 3. Propriedades Intrínsecas / Implícitas fixas (não contam como afixos aleatórios)
	if not definition.implicit_affixes.is_empty():
		t += "[color=#5a5244]────────────────────────────[/color]\n"
		for imp in definition.implicit_affixes:
			if imp == null:
				continue
			var imp_line: String = "[color=#e6d5a8]◆ %s[/color]" % imp.display_text
			if do_compare:
				var eq_imp_v: float = eq_item.get_stat_bonus(imp.stat_key) if eq_item != null else 0.0
				imp_line += _format_inline_diff(get_stat_bonus(imp.stat_key) - eq_imp_v, false, imp.stat_key == "crit_chance")
			t += imp_line + "\n"

	# 4. Modificadores Explícitos (Prefixos, Sufixos ou Propriedades Especiais Únicas)
	if is_identified and not explicit_affixes.is_empty():
		t += "[color=#5a5244]────────────────────────────[/color]\n"
		for af in explicit_affixes:
			if af == null:
				continue
			var af_color: String = "#e45155" if rarity == ItemRarity.UNIQUE else ("#58bc76" if rarity == ItemRarity.UNCOMMON else "#5dade2")
			var tier_tag: String = ""
			if show_advanced_affix_tier_in_tooltip and (af.affix_type == ItemAffix.AffixType.PREFIX or af.affix_type == ItemAffix.AffixType.SUFFIX) and af.tier >= 1:
				tier_tag = " [color=#8b939c][T%d][/color]" % af.tier
			var af_line: String = "[color=%s]• %s[/color]%s" % [af_color, af.display_text, tier_tag]
			if do_compare:
				if af.stat_key == "crit_chance" or af.stat_key == "attack_speed_pct" or af.stat_key == "move_speed":
					var my_c: float = get_stat_bonus(af.stat_key) * 100.0
					var eq_c: float = (eq_item.get_stat_bonus(af.stat_key) * 100.0) if eq_item != null else 0.0
					af_line += _format_inline_diff(my_c - eq_c, false, true)
				else:
					var my_v: float = get_stat_bonus(af.stat_key)
					var eq_v: float = eq_item.get_stat_bonus(af.stat_key) if eq_item != null else 0.0
					af_line += _format_inline_diff(my_v - eq_v, false, false)
			t += af_line + "\n"

	# 5. Descrição curta temática do item
	var lore_str: String = get_lore_description()
	if not lore_str.is_empty():
		t += "[color=#8d8272][i]\"%s\"[/i][/color]\n" % lore_str

	# 6. Área de Comparação Completa (O que GANHA em verde ▲ e o que PERDE em vermelho ▼)
	if do_compare:
		t += "[color=#5a5244]────────────────────────────[/color]\n"
		if eq_item != null:
			t += "[color=#c7bca8]Comparado ao [/color][b][color=#f2cb6f]Item Equipado:[/color][/b]\n"
		else:
			t += "[color=#c7bca8]Comparado a: [color=#8b939c]Slot Vazio[/color][/color]\n"

		var compare_defs: Array[Dictionary] = [
			{"key": "avg_damage", "label": "de Dano Médio", "float": false, "pct": false},
			{"key": "attack_speed", "label": "Vel. de Ataque Base", "float": true, "pct": false},
			{"key": "attack_speed_pct", "label": "Vel. de Ataque", "float": false, "pct": true},
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

	# 7. Rodapé de Preço e Ação Rápida
	t += "[color=#5a5244]────────────────────────────[/color]\n"
	if not custom_price_line.is_empty():
		t += custom_price_line + "\n"
	else:
		t += "🪙 Valor de Venda: [color=#f5d168]%d Ouro[/color]\n" % get_sell_value()
	if not action_hint.is_empty():
		t += "[color=#9ee0a8]%s[/color]" % action_hint

	return t


static func rarity_to_id(r: ItemRarity) -> String:
	match r:
		ItemRarity.UNCOMMON:
			return "uncommon"
		ItemRarity.MAGIC:
			return "magic"
		ItemRarity.RARE:
			return "rare"
		ItemRarity.UNIQUE:
			return "unique"
		_:
			return "normal"


func to_dictionary() -> Dictionary:
	var affixes_arr: Array[Dictionary] = []
	for af in explicit_affixes:
		if af != null:
			affixes_arr.append(af.to_dictionary())
	return {
		"schema_version": CURRENT_SCHEMA_VERSION,
		"uid": uid,
		"base_id": definition.base_id if definition != null else "",
		"ilvl": item_level,
		"rarity": rarity_to_id(rarity),
		"rarity_enum": int(rarity),
		"is_identified": is_identified,
		"unique_id": unique_id,
		"unique_display_name": unique_display_name,
		"grid_position": {"x": grid_position.x, "y": grid_position.y},
		"is_rotated": is_rotated,
		"equipped_slot": int(equipped_slot),
		"craft_state": int(craft_state),
		"verdict_mode": verdict_mode,
		"craft_history": craft_history,
		"explicit_affixes": affixes_arr,
	}


static func from_dictionary(data: Dictionary) -> ItemInstance:
	if data.is_empty():
		return null
	var base_id_str: String = String(data.get("base_id", ""))
	if base_id_str.is_empty():
		return null
	var def: ItemDefinition = ItemDatabase.get_definition(base_id_str)
	if def == null:
		return null

	var parsed_rarity: ItemRarity = ItemRarity.NORMAL
	if data.has("rarity_enum") and (typeof(data["rarity_enum"]) == TYPE_INT or typeof(data["rarity_enum"]) == TYPE_FLOAT):
		var enum_val: int = int(data["rarity_enum"])
		if enum_val >= ItemRarity.NORMAL and enum_val <= ItemRarity.UNCOMMON:
			parsed_rarity = enum_val as ItemRarity
	elif data.has("rarity"):
		var raw_r: Variant = data["rarity"]
		if typeof(raw_r) == TYPE_INT or typeof(raw_r) == TYPE_FLOAT:
			var r_int: int = int(raw_r)
			if r_int >= ItemRarity.NORMAL and r_int <= ItemRarity.UNCOMMON:
				parsed_rarity = r_int as ItemRarity
		else:
			parsed_rarity = rarity_from_id(String(raw_r))

	var parsed_ilvl: int = maxi(1, int(data.get("ilvl", data.get("item_level", def.base_item_level))))
	var inst := ItemInstance.new(def, parsed_rarity, parsed_ilvl)
	if data.has("uid") and not String(data["uid"]).is_empty():
		inst.uid = String(data["uid"])
	inst.is_identified = bool(data.get("is_identified", true))
	inst.unique_id = String(data.get("unique_id", ""))
	inst.unique_display_name = String(data.get("unique_display_name", ""))
	inst.is_rotated = bool(data.get("is_rotated", false))
	inst.equipped_slot = clampi(int(data.get("equipped_slot", ItemDefinition.EquipmentSlot.NONE)), ItemDefinition.EquipmentSlot.NONE, ItemDefinition.EquipmentSlot.RING_2) as ItemDefinition.EquipmentSlot
	inst.craft_state = clampi(int(data.get("craft_state", CraftState.NORMAL)), CraftState.NORMAL, CraftState.VERDICT_SEALED) as CraftState
	inst.verdict_mode = String(data.get("verdict_mode", ""))
	var raw_history: Variant = data.get("craft_history", [])
	if typeof(raw_history) == TYPE_ARRAY:
		inst.craft_history = (raw_history as Array).duplicate()

	if data.has("grid_position") and typeof(data["grid_position"]) == TYPE_DICTIONARY:
		var gp: Dictionary = data["grid_position"]
		inst.grid_position = Vector2i(int(gp.get("x", -1)), int(gp.get("y", -1)))

	inst.explicit_affixes.clear()
	var raw_affixes: Variant = data.get("explicit_affixes", [])
	if typeof(raw_affixes) == TYPE_ARRAY:
		for raw_af in raw_affixes:
			if typeof(raw_af) == TYPE_DICTIONARY:
				var af: ItemAffix = ItemAffix.from_dictionary(raw_af as Dictionary)
				if af != null:
					inst.explicit_affixes.append(af)
	elif parsed_rarity == ItemRarity.UNIQUE and inst.explicit_affixes.is_empty():
		LootGenerationService._apply_unique_fixed_affixes(inst)

	return inst
