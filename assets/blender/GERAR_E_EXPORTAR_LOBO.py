"""
Gerador revisado v0.19: lobo low poly do material enviado pelo usuario.
Gera modelo, rig e animacoes num Blender NOVO; salva .blend editavel;
exporta GLB SOMENTE se os tres clipes e o skin passarem na validacao.
NAO altera arquivos de outros personagens.
"""

import bpy
import json
import os
import shutil
import struct
import tempfile
from pathlib import Path

EXPECTED_CLIPS = {
    "idle-loop": (2.15, 2.75),
    "walk-loop": (1.00, 1.50),
    "attack": (0.95, 1.35),
}


def localizar_este_arquivo():
    current = getattr(getattr(bpy.context, "space_data", None), "text", None)
    if current and current.filepath:
        path = Path(bpy.path.abspath(current.filepath)).resolve()
        if path.name == "GERAR_E_EXPORTAR_LOBO.py" and path.is_file():
            return path
    candidate = globals().get("__file__")
    if candidate:
        path = Path(candidate).resolve()
        if path.name == "GERAR_E_EXPORTAR_LOBO.py" and path.is_file():
            return path
    for text_block in bpy.data.texts:
        if text_block.name == "GERAR_E_EXPORTAR_LOBO.py" and text_block.filepath:
            path = Path(bpy.path.abspath(text_block.filepath)).resolve()
            if path.is_file():
                return path
    raise RuntimeError("Use Blender > Scripting > Open para abrir este script antes de Run Script.")


def executar(path):
    source = path.read_text(encoding="utf-8")
    exec(compile(source, str(path), "exec"), {"__name__": "__main__", "__file__": str(path)})


def preparar_animacoes(rig):
    actions = []
    for clip in EXPECTED_CLIPS:
        action = bpy.data.actions.get(clip)
        if action is None:
            raise RuntimeError("Animacao nao criada: " + clip)
        actions.append(action)
    if rig.animation_data is None:
        rig.animation_data_create()
    animation_data = rig.animation_data
    for track in list(animation_data.nla_tracks):
        animation_data.nla_tracks.remove(track)
    animation_data.action = None
    # As Actions Sao a fonte oficial de exportacao. Tracks servem como
    # seguranca para Blender antigo e permitem revisao no NLA editor.
    for action in actions:
        track = animation_data.nla_tracks.new()
        track.name = action.name
        strip = track.strips.new(action.name, 1, action)
        if hasattr(strip, "action_slot") and hasattr(action, "slots") and len(action.slots) > 0:
            strip.action_slot = action.slots[0]
        track.mute = True
    animation_data.action = actions[0]


def descendente(obj, ancestor):
    cur = obj
    while cur is not None:
        if cur == ancestor:
            return True
        cur = cur.parent
    return False


def otimizar_malhas_para_exportacao(rig):
    # A versao .blend editavel e salva ANTES desta operacao.
    # Unir todas as pecas reduz a quantidade de objetos por mob no Godot.
    meshes = [obj for obj in bpy.data.objects if obj.type == 'MESH' and descendente(obj, rig)]
    if len(meshes) < 15:
        raise RuntimeError("Rig tem poucas pecas; confira o script de modelagem e o bind.")
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    bpy.ops.object.join()
    combined = bpy.context.view_layer.objects.active
    combined.name = "Wolf_Mesh_Optimized"
    if len(combined.vertex_groups) < 12:
        raise RuntimeError("Grupos de vertices perdidos na uniao dos meshes.")
    if not any(mod.type == "ARMATURE" and mod.object == rig for mod in combined.modifiers):
        raise RuntimeError("Armature Modifier nao preservado na malha otimizada.")
    return combined


def exportar_glb(path, root, rig, mesh):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in (root, rig, mesh):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = rig
    props = bpy.ops.export_scene.gltf.get_rna_type().properties
    kwargs = {
        "filepath": str(path),
        "export_format": "GLB",
        "use_selection": True,
    }
    opts = {
        "export_animations": True,
        "export_animation_mode": "ACTIONS",
        "export_nla_strips": True,
        "export_frame_range": False,
        "export_force_sampling": True,
        "export_anim_slide_to_zero": True,
        "export_yup": True,
        "export_apply": False,
        "export_lights": False,
        "export_cameras": False,
        "export_skins": True,
        "export_materials": "EXPORT",
    }
    for key, value in opts.items():
        if key in props:
            kwargs[key] = value
    result = bpy.ops.export_scene.gltf(**kwargs)
    if "FINISHED" not in result or not path.exists():
        raise RuntimeError("Exportacao GLB falhou")


def validar_glb(path):
    data = path.read_bytes()
    if len(data) < 16384 or data[:4] != b"glTF":
        raise RuntimeError("Arquivo GLB vazio ou invalido")
    version, byte_length = struct.unpack_from("<II", data, 4)
    if version != 2 or byte_length != len(data):
        raise RuntimeError("Cabecalho GLB invalido")
    chunk_length, chunk_type = struct.unpack_from("<I4s", data, 12)
    if chunk_type != b"JSON":
        raise RuntimeError("GLB sem chunk JSON")
    meta = json.loads(data[20:20 + chunk_length].decode('utf-8').rstrip(' \x00'))
    if not meta.get("skins"):
        raise RuntimeError("GLB sem skin/rig: modelos nao vao animar")
    if not meta.get("meshes"):
        raise RuntimeError("GLB sem malha")

    clips = {anim.get("name", ""): anim for anim in meta.get("animations", [])}
    missing = set(EXPECTED_CLIPS) - set(clips)
    if missing:
        raise RuntimeError("Animacoes ausentes no GLB: " + ", ".join(sorted(missing)))

    accessors = meta.get("accessors", [])
    for name, (lower, upper) in EXPECTED_CLIPS.items():
        animation = clips[name]
        durations = []
        for sampler in animation.get("samplers", []):
            accessor = accessors[sampler["input"]]
            if "min" in accessor and "max" in accessor:
                durations.append(float(accessor["max"][0]) - float(accessor["min"][0]))
        duration = max(durations) if durations else 0.0
        if not (lower <= duration <= upper):
            raise RuntimeError(f"Animacao {name} com duracao inesperada {duration:.2f}s; esperado {lower:.2f}-{upper:.2f}s")
        print(f"[OK] {name}: {duration:.2f}s, {len(animation.get('channels', []))} canais")
    print("[OK] GLB contem skin, malhas e 3 animacoes com duracao coerente")


def main():
    this_file = localizar_este_arquivo()
    scripts = this_file.parent
    project = scripts.parent.parent
    for dependency in ("low_poly_wolf.py", "rig_wolf.py"):
        if not (scripts / dependency).is_file():
            raise FileNotFoundError(f"Nao encontrado: {scripts / dependency}")

    executar(scripts / "low_poly_wolf.py")
    executar(scripts / "rig_wolf.py")
    root = bpy.data.objects.get("Wolf")
    rig = bpy.data.objects.get("Wolf_Rig")
    if root is None or rig is None:
        raise RuntimeError("Modelo ou rig nao foram criados")
    preparar_animacoes(rig)
    bpy.context.scene.render.fps = 24
    bpy.context.scene.frame_set(1)

    # Save editavel antes de unir malhas; evita perder a organizacao por pecas.
    blend_path = project / "assets" / "blender" / "Lobo_v019_Editavel.blend"
    bpy.ops.wm.save_as_mainfile(filepath=str(blend_path))
    print("[OK] Fonte editavel salva:", blend_path)

    mesh = otimizar_malhas_para_exportacao(rig)
    target = project / "assets" / "models" / "wolf.glb"
    target.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="lobo_export_") as tmp:
        pending = Path(tmp) / "wolf.glb"
        exportar_glb(pending, root, rig, mesh)
        validar_glb(pending)
        # Nao substitui um GLB funcional se a exportacao/validacao falhar.
        shutil.copy2(str(pending), str(target))

    print("[OK] Exportado:", target)
    print("[OK] Resultado pronto para importacao no Godot (validar visualmente no jogo).")


if __name__ == "__main__":
    main()
