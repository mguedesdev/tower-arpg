"""Blender 4.x / 5.x: gera o cavaleiro, rig e exporta GLB no projeto Godot.

Uso: Blender > Scripting > Open este arquivo no projeto > Run Script.
IMPORTANTE: os scripts base serao executados; eles APAGAM a cena atual.
"""

import bpy
import os
from pathlib import Path


def localizar_este_arquivo():
    # Scripting > Open conserva filepath no datablock de texto.
    ctx = getattr(bpy.context, "space_data", None)
    current = getattr(ctx, "text", None)
    if current and current.filepath:
        result = Path(bpy.path.abspath(current.filepath)).resolve()
        if result.is_file() and result.name == "GERAR_E_EXPORTAR_CAVALEIRO.py":
            return result
    candidate = globals().get("__file__")
    if candidate:
        result = Path(candidate).resolve()
        if result.is_file():
            return result
    for textblock in bpy.data.texts:
        if textblock.name == "GERAR_E_EXPORTAR_CAVALEIRO.py" and textblock.filepath:
            return Path(bpy.path.abspath(textblock.filepath)).resolve()
    raise RuntimeError(
        "Abra este script atraves do botao Open no Blender > Scripting "
        "(nao copie e cole em um texto novo), depois Run Script."
    )


def executar_script(path):
    if not path.is_file():
        raise FileNotFoundError(f"Arquivo nao encontrado: {path}")
    code = path.read_text(encoding="utf-8")
    exec(compile(code, str(path), "exec"), {"__name__": "__main__"})


def preparar_animacoes(armature):
    names = ("idle-loop", "walk-loop", "attack", "attack_stab", "attack_arc", "attack_spin", "attack_pierce")
    actions = []
    for name in names:
        action = bpy.data.actions.get(name)
        if action is None:
            raise RuntimeError(f"Rig nao criou a animacao obrigatoria: {name}")
        actions.append(action)

    if armature.animation_data is None:
        armature.animation_data_create()
    anim_data = armature.animation_data

    # Cada Action fica ligada ao esqueleto por sua propria NLA Track.
    # O exportador glTF exporta Actions ativas/guardadas em NLA.
    for track in list(anim_data.nla_tracks):
        anim_data.nla_tracks.remove(track)
    anim_data.action = None

    for action in actions:
        track = anim_data.nla_tracks.new()
        track.name = action.name
        strip = track.strips.new(action.name, 1, action)
        if hasattr(strip, "action_slot") and hasattr(action, "slots") and len(action.slots) > 0:
            strip.action_slot = action.slots[0]
        # Tracks desligadas na cena; elas continuam registradas para exportacao.
        track.mute = True

    anim_data.action = actions[0]
    if hasattr(anim_data, "action_slot") and hasattr(actions[0], "slots") and len(actions[0].slots) > 0:
        anim_data.action_slot = actions[0].slots[0]

    return names


def exportar_glb(target):
    # Exportacao de TODOS os objetos necessarios, mas sem luzes/camera.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in bpy.data.objects:
        if obj.type in {"MESH", "ARMATURE"} or obj.name == "Knight":
            obj.select_set(True)
    rig = bpy.data.objects.get("Knight_Rig")
    bpy.context.view_layer.objects.active = rig

    props = bpy.ops.export_scene.gltf.get_rna_type().properties
    kwargs = dict(filepath=str(target), export_format="GLB", use_selection=True)
    if "export_animations" in props:
        kwargs["export_animations"] = True
    if "export_animation_mode" in props:
        kwargs["export_animation_mode"] = "ACTIONS"
    elif "export_nla_strips" in props:
        kwargs["export_nla_strips"] = True
    if "export_frame_range" in props:
        kwargs["export_frame_range"] = False
    if "export_force_sampling" in props:
        kwargs["export_force_sampling"] = True

    outcome = bpy.ops.export_scene.gltf(**kwargs)
    if "FINISHED" not in outcome or not target.exists():
        raise RuntimeError("Exportacao glTF nao terminou com sucesso")
    return target.stat().st_size


def main():
    source = localizar_este_arquivo()
    scripts_dir = source.parent
    project_dir = scripts_dir.parent.parent

    # Verificar todas as dependencias ANTES de apagar a cena do Blender.
    dependencies = ("low_poly_knight_silhouette.py", "rig_knight_v3.py", "rig_knight_v4_animation.py", "CRIAR_3_ANIMACOES_ATAQUE.py")
    missing = [name for name in dependencies if not (scripts_dir / name).is_file()]
    if missing:
        raise FileNotFoundError(
            "Faltam scripts na pasta assets/blender: " + ", ".join(missing) +
            "\nExtraia a atualizacao corrigida NA RAIZ do projeto Godot "
            "(a mesma pasta que contem project.godot)."
        )
    if not (project_dir / "project.godot").is_file():
        raise RuntimeError(
            "O exportador nao esta dentro de um projeto Godot.\n"
            f"Pasta atual: {scripts_dir}\n"
            "Copie assets/blender para a raiz do projeto (junto de project.godot), "
            "abra o script desse caminho no Blender e execute novamente."
        )

    target = project_dir / "assets" / "models" / "knight.glb"
    print("\n=== CAVALEIRO GODOT ===")
    print("Arquivos:", scripts_dir)
    print("Destino:", target)

    executar_script(scripts_dir / "low_poly_knight_silhouette.py")
    executar_script(scripts_dir / "rig_knight_v3.py")
    # Atualiza as animacoes sem reconstruir o esqueleto ou a modelagem.
    executar_script(scripts_dir / "rig_knight_v4_animation.py")
    executar_script(scripts_dir / "CRIAR_3_ANIMACOES_ATAQUE.py")

    rig = bpy.data.objects.get("Knight_Rig")
    if rig is None:
        raise RuntimeError("Knight_Rig nao encontrado apos executar o rig v3")
    preparar_animacoes(rig)

    # Verificacoes simples, antes da exportacao.
    bone_count = len(rig.data.bones)
    if bone_count < 10:
        raise RuntimeError("Rig com poucos ossos: confira o script v3")
    empty_meshes = [o.name for o in bpy.data.objects if o.type == "MESH" and not o.modifiers.get("Armature")]
    if empty_meshes:
        print("AVISO: meshes sem modificador de rig:", empty_meshes)

    target.parent.mkdir(parents=True, exist_ok=True)
    bpy.context.scene.frame_set(1)
    size = exportar_glb(target)
    blend_target = scripts_dir / "Cavaleiro_v1_0_Animado.blend"
    try:
        bpy.ops.wm.save_as_mainfile(filepath=str(blend_target))
    except Exception as exc:
        print("Aviso ao salvar .blend editavel:", exc)
    print("\nSUCESSO: Arquivo GLB exportado:", target)
    print("Tamanho: %.1f KB | Ossos: %d" % (size / 1024, bone_count))
    print("Acoes esperadas: idle-loop, walk-loop, attack (legado), attack_stab, attack_arc, attack_spin, attack_pierce")
    print("Agora abra o Godot e rode a cena: o placeholder sera trocado automaticamente.")
    print("Arquivo Blender editavel salvo em:", blend_target)


main()
