"""Corrige as faixas NLA do inimigo v0.14 e reexporta os clips no Godot.

Execute este script com `Esqueleto_Inimigo_v014_RIG.blend` aberto.
Nao recria malhas, ossos nem animacoes; apenas reconfigura as faixas de exportacao.
Saida: Esqueleto_Inimigo_v015_RIG.blend + assets/models/skeleton_enemy.glb.
"""

import bpy
import json
import struct
from pathlib import Path

SCRIPT_NAME = "CORRIGIR_WALK_E_EXPORTAR_ESQUELETO_V015.py"
RIG_NAME = "Skeleton_Armature"
ROOT_NAME = "SkeletonEnemy"
FPS = 24
CLIPS = {"idle": (1, 49), "walk": (1, 25)}


def get_script_dir():
    space = getattr(bpy.context, "space_data", None)
    current = getattr(space, "text", None)
    if current is not None and current.filepath:
        path = Path(bpy.path.abspath(current.filepath)).resolve()
        if path.name == SCRIPT_NAME:
            return path.parent
    for block in bpy.data.texts:
        if block.name == SCRIPT_NAME and block.filepath:
            return Path(bpy.path.abspath(block.filepath)).resolve().parent
    raise RuntimeError("No Blender > Scripting, use Open para abrir este script em assets/blender.")


def get_action(name):
    action = bpy.data.actions.get(name)
    if action is None:
        raise RuntimeError(f"Action '{name}' nao encontrada. Abra Esqueleto_Inimigo_v014_RIG.blend.")
    return action


def reset_nla_strips(arm):
    anim = arm.animation_data
    if anim is None:
        raise RuntimeError("Rig sem animation_data. O arquivo v0.14 nao foi criado corretamente.")

    # Evita apagar trilhas criadas manualmente pelo usuario.
    unexpected = [t.name for t in anim.nla_tracks if t.name.lower() not in CLIPS]
    if unexpected:
        raise RuntimeError("Existem trilhas extras no rig: " + ", ".join(unexpected) + ". Faca backup e avalie antes de continuar.")

    anim.action = None
    for track in list(anim.nla_tracks):
        anim.nla_tracks.remove(track)

    for clip_name, (start_key, end_key) in CLIPS.items():
        action = get_action(clip_name)
        if hasattr(action, "slots") and len(action.slots) == 0:
            raise RuntimeError(f"Action '{clip_name}' nao possui Action Slot. Refaça o rig v0.14.")
        track = anim.nla_tracks.new()
        track.name = clip_name
        track.mute = False
        strip = track.strips.new(clip_name, start_key, action)
        if hasattr(strip, "action_slot") and hasattr(action, "slots") and action.slots:
            strip.action_slot = action.slots[0]
        strip.action_frame_start = float(start_key)
        strip.action_frame_end = float(end_key)
        strip.frame_start = float(start_key)
        strip.frame_end = float(end_key)
        strip.repeat = 1.0
        strip.blend_type = 'REPLACE'
        strip.extrapolation = 'NOTHING'
        print(f"NLA corrigido: {clip_name}: frames {strip.frame_start:.0f}-{strip.frame_end:.0f} "
              f"(duracao {(end_key-start_key)/FPS:.2f}s @ {FPS}fps)")


def export_glb(root, arm, output):
    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    arm.select_set(True)
    for child in arm.children_recursive:
        if child.type == 'MESH':
            child.select_set(True)
    bpy.context.view_layer.objects.active = arm

    kwargs = dict(
        filepath=str(output),
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_lights=False,
        export_cameras=False,
        export_animations=True,
        export_materials='EXPORT',
    )
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    if 'export_animation_mode' in props:
        kwargs['export_animation_mode'] = 'NLA_TRACKS'
    elif 'export_nla_strips' in props:
        kwargs['export_nla_strips'] = True
    else:
        raise RuntimeError("Exportador glTF sem suporte a NLA_TRACKS nesta versao do Blender.")
    bpy.ops.export_scene.gltf(**kwargs)


def inspect_glb_durations(path):
    # Verifica a duracao dos canais exportados no proprio GLB (sem depender do Godot).
    with open(path, 'rb') as file:
        header = file.read(12)
        if len(header) != 12:
            raise RuntimeError("GLB vazio ou incompleto.")
        magic, version, total_length = struct.unpack('<III', header)
        if magic != 0x46546C67 or version != 2:
            raise RuntimeError("GLB invalido.")
        chunk_len, chunk_type = struct.unpack('<II', file.read(8))
        if chunk_type != 0x4E4F534A:
            raise RuntimeError("GLB sem chunk JSON.")
        data = json.loads(file.read(chunk_len).decode('utf-8').rstrip(' \x00'))

    found = {}
    for animation in data.get('animations', []):
        name = animation.get('name', '').lower()
        min_time, max_time = float('inf'), float('-inf')
        for sampler in animation.get('samplers', []):
            accessor = data['accessors'][sampler['input']]
            if 'min' in accessor and 'max' in accessor:
                min_time = min(min_time, float(accessor['min'][0]))
                max_time = max(max_time, float(accessor['max'][0]))
        if max_time >= min_time:
            print(f"GLB animacao '{name}' -> {min_time:.3f} a {max_time:.3f}s")
            for expected in CLIPS:
                if name == expected or name.endswith('/'+expected) or name.endswith('|'+expected):
                    found[expected] = (min_time, max_time)

    for expected, limit in [('idle', 2.15), ('walk', 1.15)]:
        if expected not in found:
            raise RuntimeError(f"GLB nao contem a animacao '{expected}'. Confira o exportador. Nomes: {list(found)}")
        start, end = found[expected]
        if start > 0.10 or end > limit:
            raise RuntimeError(
                f"GLB gerado, mas a animacao '{expected}' continua longa ou atrasada "
                f"({start:.2f}s..{end:.2f}s). Envie esta mensagem para corrigirmos a exportacao."
            )


def main():
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    root = bpy.data.objects.get(ROOT_NAME)
    arm = bpy.data.objects.get(RIG_NAME)
    if root is None or arm is None or arm.type != 'ARMATURE':
        raise RuntimeError("Abra primeiro o arquivo Esqueleto_Inimigo_v014_RIG.blend com o rig ja pronto.")
    path = get_script_dir().parent.parent
    output_blend = path / 'assets' / 'blender' / 'Esqueleto_Inimigo_v015_RIG.blend'
    output_glb = path / 'assets' / 'models' / 'skeleton_enemy.glb'
    output_glb.parent.mkdir(parents=True, exist_ok=True)

    bpy.context.scene.render.fps = FPS
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 49
    reset_nla_strips(arm)
    bpy.context.scene.frame_set(1)
    export_glb(root, arm, output_glb)
    inspect_glb_durations(output_glb)
    # So salva o BLEND novo depois de confirmar que o GLB nao tem pausa no final.
    bpy.ops.wm.save_as_mainfile(filepath=str(output_blend))
    print("SUCESSO: idle ~2s; walk ~1s; ambos com inicio no frame 1.")
    print("GLB:", output_glb)
    print("BLEND:", output_blend)

if __name__ == '__main__':
    main()
