extends RefCounted
class_name HudInputHelper

## Helper central de InputMap e rótulos de teclas da HUD Modular
## Registra ações padrão se não existirem e extrai textos limpos para as keyplates

const ACTION_SKILL_PREFIX := "hud_skill_"
const ACTION_POTION_PREFIX := "hud_potion_"

const DEFAULT_SKILL_KEYS: Array = [
	MOUSE_BUTTON_LEFT,   # Slot 0: LMB
	MOUSE_BUTTON_RIGHT,  # Slot 1: RMB
	KEY_Q,               # Slot 2: Q
	KEY_E,               # Slot 3: E
	KEY_R,               # Slot 4: R
	KEY_F                # Slot 5: F
]

const DEFAULT_SKILL_FALLBACKS: Array[String] = ["LMB", "RMB", "Q", "E", "R", "F"]
const DEFAULT_POTION_KEYS: Array = [KEY_1, KEY_2]
const DEFAULT_POTION_FALLBACKS: Array[String] = ["1", "2"]


static func ensure_default_actions() -> void:
	for i in range(DEFAULT_SKILL_KEYS.size()):
		var action_name: String = "%s%d" % [ACTION_SKILL_PREFIX, i + 1]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			if i < 2:
				var ev_m := InputEventMouseButton.new()
				ev_m.button_index = DEFAULT_SKILL_KEYS[i] as MouseButton
				InputMap.action_add_event(action_name, ev_m)
			else:
				var ev_k := InputEventKey.new()
				ev_k.physical_keycode = DEFAULT_SKILL_KEYS[i] as Key
				InputMap.action_add_event(action_name, ev_k)

	for i in range(DEFAULT_POTION_KEYS.size()):
		var action_name: String = "%s%d" % [ACTION_POTION_PREFIX, i + 1]
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
			var ev_k := InputEventKey.new()
			ev_k.physical_keycode = DEFAULT_POTION_KEYS[i] as Key
			InputMap.action_add_event(action_name, ev_k)


static func get_skill_action_label(slot_idx: int) -> String:
	ensure_default_actions()
	var action_name: String = "%s%d" % [ACTION_SKILL_PREFIX, slot_idx + 1]
	var fallback: String = DEFAULT_SKILL_FALLBACKS[slot_idx] if slot_idx < DEFAULT_SKILL_FALLBACKS.size() else "?"
	return get_action_label(action_name, fallback)


static func get_potion_action_label(slot_idx: int) -> String:
	ensure_default_actions()
	var action_name: String = "%s%d" % [ACTION_POTION_PREFIX, slot_idx + 1]
	var fallback: String = DEFAULT_POTION_FALLBACKS[slot_idx] if slot_idx < DEFAULT_POTION_FALLBACKS.size() else "?"
	return get_action_label(action_name, fallback)


static func get_action_label(action_name: String, fallback: String) -> String:
	if not InputMap.has_action(action_name):
		return fallback
	var events := InputMap.action_get_events(action_name)
	if events.is_empty():
		return fallback
	for ev in events:
		if ev is InputEventMouseButton:
			var mb := ev as InputEventMouseButton
			match mb.button_index:
				MOUSE_BUTTON_LEFT:
					return "LMB"
				MOUSE_BUTTON_RIGHT:
					return "RMB"
				MOUSE_BUTTON_MIDDLE:
					return "MMB"
				MOUSE_BUTTON_WHEEL_UP:
					return "WU"
				MOUSE_BUTTON_WHEEL_DOWN:
					return "WD"
				MOUSE_BUTTON_XBUTTON1:
					return "M4"
				MOUSE_BUTTON_XBUTTON2:
					return "M5"
				_:
					return "M%d" % mb.button_index
		elif ev is InputEventKey:
			var k := ev as InputEventKey
			var code: int = k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
			if code != KEY_NONE:
				var s: String = OS.get_keycode_string(code).to_upper()
				if s.length() > 4:
					s = s.substr(0, 4)
				return s
	return fallback
