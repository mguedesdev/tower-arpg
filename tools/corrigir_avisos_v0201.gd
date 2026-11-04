@tool
extends EditorScript
## Hotfix v0.20.1: correcoes localizadas sem substituir scripts inteiros.
## Execute no Editor do Godot: FileSystem > botao direito neste arquivo > Run.
## Os originais ficam em res://docs/backups_v0201/ com extensao .bak.

const PATCHES: Dictionary = {
    "res://scripts/arena_art.gd": [
        ["func _material(name: String, color:", "func _material(material_label: String, color:"],
        ["mat.resource_name = name", "mat.resource_name = material_label"],
        ["func _mesh_instance(name: String, mesh: Mesh, mat: Material, position: Vector3 = Vector3.ZERO)", "func _mesh_instance(mesh_label: String, mesh: Mesh, mat: Material, spawn_position: Vector3 = Vector3.ZERO)"],
        ["node.name = name", "node.name = mesh_label"],
        ["node.position = position", "node.position = spawn_position"],
        ["func _box(position: Vector3, size: Vector3", "func _box(spawn_position: Vector3, size: Vector3"],
        ["_material(\"mat_box\", color, roughness), position)", "_material(\"mat_box\", color, roughness), spawn_position)"],
        ["func _cylinder(position: Vector3, radius:", "func _cylinder(spawn_position: Vector3, radius:"],
        ["_material(\"mat_cyl\", color, roughness), position)", "_material(\"mat_cyl\", color, roughness), spawn_position)"],
        ["int(indices.size() / 3)", "int(float(indices.size()) / 3.0)"],
    ],
    "res://scripts/enemy.gd": [
        ["var name: String = full_name.get_slice", "var clip_label: String = full_name.get_slice"],
        ["name = name.get_slice(\"|\", name.get_slice_count(\"|\") - 1)", "clip_label = clip_label.get_slice(\"|\", clip_label.get_slice_count(\"|\") - 1)"],
        ["if name.to_lower() == String(wanted):", "if clip_label.to_lower() == String(wanted):"],
    ],
    "res://scripts/player.gd": [
        ["func _play_model_animation(name: String, restart: bool = false)", "func _play_model_animation(clip_name: String, restart: bool = false)"],
        ["var match_name: String = _find_animation_name(name)", "var match_name: String = _find_animation_name(clip_name)"],
    ],
    "res://scripts/wolf_enemy.gd": [
        ["func _on_wolf_animation_finished(name: StringName)", "func _on_wolf_animation_finished(finished_clip: StringName)"],
        ["if name != _attack_animation:", "if finished_clip != _attack_animation:"],
    ],
}

func _run() -> void:
    var changed_files: int = 0
    var skipped_files: int = 0
    for source_path in PATCHES.keys():
        if not FileAccess.file_exists(source_path):
            print("[v0.20.1] Ausente (ignorado): ", source_path)
            skipped_files += 1
            continue

        var original_text: String = FileAccess.get_file_as_string(source_path)
        if original_text.is_empty():
            push_warning("[v0.20.1] Arquivo vazio/inacessivel (ignorado): " + source_path)
            skipped_files += 1
            continue

        var result_text: String = original_text
        var replacements: Array = PATCHES[source_path]
        var changes: int = 0
        var unknown_patterns: int = 0
        for replacement in replacements:
            var old_text: String = replacement[0]
            var new_text: String = replacement[1]
            if result_text.contains(old_text):
                result_text = result_text.replace(old_text, new_text)
                changes += 1
            elif not result_text.contains(new_text):
                unknown_patterns += 1

        # Protege os scripts se a versao local nao corresponder ao codigo auditado.
        if unknown_patterns > 0:
            push_warning("[v0.20.1] Ignorado por divergencia de versao (%d padroes): %s" % [unknown_patterns, source_path])
            skipped_files += 1
            continue
        if changes == 0:
            print("[v0.20.1] Ja corrigido: ", source_path)
            continue

        var relative_path: String = source_path.trim_prefix("res://")
        var backup_path: String = "res://docs/backups_v0201/" + relative_path + ".bak"
        var backup_folder: String = backup_path.get_base_dir()
        var err_dir: Error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(backup_folder))
        if err_dir != OK:
            push_error("[v0.20.1] Nao consegui criar backup para: " + source_path)
            skipped_files += 1
            continue
        if FileAccess.file_exists(backup_path):
            # Nao sobrescreve backup da primeira execucao.
            push_warning("[v0.20.1] Backup preexistente: " + backup_path + ". Ignorando por seguranca.")
            skipped_files += 1
            continue
        var backup_file: FileAccess = FileAccess.open(backup_path, FileAccess.WRITE)
        if backup_file == null:
            push_error("[v0.20.1] Falha ao abrir backup: " + backup_path)
            skipped_files += 1
            continue
        backup_file.store_string(original_text)
        backup_file.close()

        var output_file: FileAccess = FileAccess.open(source_path, FileAccess.WRITE)
        if output_file == null:
            push_error("[v0.20.1] Falha ao editar: " + source_path + ". Original salvo em " + backup_path)
            skipped_files += 1
            continue
        output_file.store_string(result_text)
        output_file.close()
        changed_files += 1
        print("[v0.20.1] Corrigido: ", source_path, " (", changes, " alteracoes)")

    print("[v0.20.1] FIM. Arquivos corrigidos: %d. Ignorados: %d." % [changed_files, skipped_files])
    print("[v0.20.1] Feche/reabra o projeto no Godot e limpe o painel Output para verificar novos avisos.")
