extends RefCounted
class_name SaveService
## Persistência local segura (user://) em JSON com schema_version, validação de tipos e cópia de recuperação (.bak).
## Nunca carrega Resources executáveis nem caminhos arbitrários de dados externos.

const DEFAULT_SAVE_PATH: String = "user://progression_save.json"

var save_path: String = DEFAULT_SAVE_PATH


func _init(custom_save_path: String = DEFAULT_SAVE_PATH) -> void:
	save_path = custom_save_path


func save_state(state: PermanentProgressionState) -> bool:
	if state == null:
		return false

	var payload: Dictionary = state.to_dictionary()
	var json_text: String = JSON.stringify(payload, "\t")
	if json_text.is_empty():
		push_error("SaveService: falha ao serializar estado permanente.")
		return false

	var tmp_path: String = save_path + ".tmp"
	var bak_path: String = save_path + ".bak"

	# 1. Escreve primeiro no arquivo temporário.
	var tmp_file: FileAccess = FileAccess.open(tmp_path, FileAccess.WRITE)
	if tmp_file == null:
		push_error("SaveService: não foi possível abrir arquivo temporário para escrita: " + tmp_path)
		return false
	tmp_file.store_string(json_text)
	tmp_file.flush()
	tmp_file.close()

	# 2. Confere se o arquivo temporário é válido antes de tocar no principal.
	var verify_text: String = FileAccess.get_file_as_string(tmp_path)
	if not _is_valid_json_payload(verify_text):
		push_error("SaveService: validação pós-escrita falhou no arquivo temporário.")
		return false

	# 3. Se já existe um save principal íntegro, atualiza o backup (.bak).
	if FileAccess.file_exists(save_path):
		var current_text: String = FileAccess.get_file_as_string(save_path)
		if _is_valid_json_payload(current_text):
			var bak_file: FileAccess = FileAccess.open(bak_path, FileAccess.WRITE)
			if bak_file != null:
				bak_file.store_string(current_text)
				bak_file.flush()
				bak_file.close()

	# 4. Grava o conteúdo validado no destino principal e remove o temporário.
	var main_file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if main_file == null:
		push_error("SaveService: falha ao gravar arquivo principal: " + save_path)
		return false
	main_file.store_string(verify_text)
	main_file.flush()
	main_file.close()

	if FileAccess.file_exists(tmp_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_path))
	return true


func load_state() -> PermanentProgressionState:
	var bak_path: String = save_path + ".bak"
	if FileAccess.file_exists(save_path):
		var raw_main: String = FileAccess.get_file_as_string(save_path)
		var parsed_main: PermanentProgressionState = _parse_and_validate(raw_main)
		if parsed_main != null:
			return parsed_main
		push_warning("SaveService: arquivo principal inválido/corrompido (%s). Tentando recuperar backup." % save_path)

	if FileAccess.file_exists(bak_path):
		var raw_bak: String = FileAccess.get_file_as_string(bak_path)
		var parsed_bak: PermanentProgressionState = _parse_and_validate(raw_bak)
		if parsed_bak != null:
			push_warning("SaveService: estado recuperado com sucesso a partir do backup (.bak).")
			save_state(parsed_bak)
			return parsed_bak
		push_warning("SaveService: backup também inválido. Inicializando estado limpo.")

	return PermanentProgressionState.new()


func delete_save_files() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var target: String = save_path + suffix
		if FileAccess.file_exists(target):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(target))


func _is_valid_json_payload(raw_text: String) -> bool:
	return _parse_and_validate(raw_text) != null


func _parse_and_validate(raw_text: String) -> PermanentProgressionState:
	if raw_text.strip_edges().is_empty():
		return null
	var json_parser := JSON.new()
	if json_parser.parse(raw_text) != OK:
		return null
	var parsed: Variant = json_parser.data
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	var data: Dictionary = parsed as Dictionary
	if not data.has("schema_version") or not data.has("essence") or not data.has("unlocked_talents"):
		return null

	var version_val: Variant = data["schema_version"]
	if typeof(version_val) != TYPE_INT and typeof(version_val) != TYPE_FLOAT:
		return null
	var schema_ver: int = int(version_val)
	if schema_ver < 1 or schema_ver > PermanentProgressionState.CURRENT_SCHEMA_VERSION:
		return null

	var essence_val: Variant = data["essence"]
	if typeof(essence_val) != TYPE_INT and typeof(essence_val) != TYPE_FLOAT:
		return null
	if int(essence_val) < 0:
		return null

	var talents_val: Variant = data["unlocked_talents"]
	if typeof(talents_val) != TYPE_DICTIONARY:
		return null

	var state := PermanentProgressionState.new()
	state.schema_version = schema_ver
	state.profile_id = String(data.get("profile_id", "default_profile"))
	state.currency_name = String(data.get("currency_name", "Essência"))
	state.essence = maxi(0, int(essence_val))
	state.total_essence_earned = maxi(state.essence, int(data.get("total_essence_earned", state.essence)))

	var raw_talents: Dictionary = talents_val as Dictionary
	for key in raw_talents.keys():
		var talent_id: String = String(key).strip_edges()
		var rank_val: Variant = raw_talents[key]
		if talent_id.is_empty():
			continue
		if typeof(rank_val) != TYPE_INT and typeof(rank_val) != TYPE_FLOAT:
			return null
		var rank_int: int = int(rank_val)
		if rank_int > 0:
			state.unlocked_talents[talent_id] = rank_int

	var raw_unlocks: Variant = data.get("meta_unlocks", [])
	if typeof(raw_unlocks) == TYPE_ARRAY:
		for item in raw_unlocks:
			var unlock_str: String = String(item).strip_edges()
			if not unlock_str.is_empty() and not state.meta_unlocks.has(unlock_str):
				state.meta_unlocks.append(unlock_str)

	return state
