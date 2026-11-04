"""Gera a v0.13, preserva um .blend editavel e exporta GLB otimizado.

Use: Blender > Scripting > Open (arquivo EXTERNO) > Run Script.
Pasta esperada: <projeto>/assets/blender/GERAR_E_EXPORTAR_ESQUELETO_INIMIGO.py
Saida: <projeto>/assets/models/skeleton_enemy.glb
        <projeto>/assets/blender/Esqueleto_Inimigo_v013.blend

Nao execute num .blend com trabalho ainda nao salvo: o gerador limpa a cena.
"""

import bpy
from pathlib import Path

THIS_SCRIPT = 'GERAR_E_EXPORTAR_ESQUELETO_INIMIGO.py'
GENERATOR_SCRIPT = 'CRIAR_ESQUELETO_DARKFANTASY_V013.py'


def find_script_path():
    space = getattr(bpy.context, 'space_data', None)
    text = getattr(space, 'text', None)
    if text and text.filepath:
        p = Path(bpy.path.abspath(text.filepath)).resolve()
        if p.name == THIS_SCRIPT:
            return p
    for candidate in bpy.data.texts:
        if candidate.name == THIS_SCRIPT and candidate.filepath:
            return Path(bpy.path.abspath(candidate.filepath)).resolve()
    raise RuntimeError('Abra GERAR_E_EXPORTAR_ESQUELETO_INIMIGO.py com Scripting > Open antes de executar.')


def export():
    script_path = find_script_path()
    modeler = script_path.parent / GENERATOR_SCRIPT
    if not modeler.is_file():
        raise FileNotFoundError('Script de modelagem ausente: %s' % modeler)
    project = script_path.parent.parent.parent
    output = project / 'assets' / 'models' / 'skeleton_enemy.glb'
    blend = project / 'assets' / 'blender' / 'Esqueleto_Inimigo_v013.blend'
    output.parent.mkdir(parents=True, exist_ok=True)

    namespace = {'__name__': '__main__', '__file__': str(modeler)}
    exec(compile(modeler.read_text(encoding='utf-8'), str(modeler), 'exec'), namespace)

    root = bpy.data.objects.get('SkeletonEnemy')
    if root is None:
        raise RuntimeError('SkeletonEnemy nao foi criado pelo script de modelagem.')

    # Armazenamos o arquivo fonte antes das duplicatas de exportacao.
    bpy.ops.wm.save_as_mainfile(filepath=str(blend))
    bpy.context.view_layer.update()

    # O personagem tem dezenas de partes editaveis. Para o Godot,
    # duplicamos e unimos por material, reduzindo draw calls/nos.
    export_collection = bpy.data.collections.new('_TEMP_EXPORT')
    bpy.context.scene.collection.children.link(export_collection)
    buckets = {}
    for obj in root.children_recursive:
        if obj.type != 'MESH':
            continue
        duplicate = obj.copy()
        duplicate.data = obj.data.copy()
        export_collection.objects.link(duplicate)
        duplicate.parent = None
        duplicate.matrix_world = obj.matrix_world.copy()
        material_key = duplicate.data.materials[0].name if len(duplicate.data.materials) else 'Bone'
        # Uma malha com faces de materiais mistos nao pode ser agrupada
        # com um unico material sem perder detalhes. Fica independente.
        if len(duplicate.data.materials) > 1:
            material_key = duplicate.name
        buckets.setdefault(material_key, []).append(duplicate)

    export_objects = []
    for key, objects in buckets.items():
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        merged = bpy.context.view_layer.objects.active
        merged.name = 'Skeleton_' + key.replace('.', '_')
        export_objects.append(merged)

    bpy.ops.object.select_all(action='DESELECT')
    for obj in export_objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = export_objects[0]

    bpy.ops.export_scene.gltf(
        filepath=str(output),
        export_format='GLB',
        use_selection=True,
        export_yup=True,
        export_lights=False,
        export_cameras=False,
        export_animations=False,
        export_materials='EXPORT',
    )

    # Apagar apenas duplicatas temporarias; a fonte permanece editavel.
    for obj in list(export_collection.objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(export_collection)

    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    print('Exportacao concluida: ' + str(output))
    print('Fonte editavel salva em: ' + str(blend))
    print('GLB carregado automaticamente no Godot via scenes/enemy.tscn da v0.12.')


if __name__ == '__main__':
    export()
