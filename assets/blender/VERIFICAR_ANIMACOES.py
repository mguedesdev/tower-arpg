"""Rodar no Blender com Knight_Rig ja criado. Nao apaga nem altera modelos.

Edite CLIP para walk-loop, attack ou idle-loop e pressione Run Script.
Este programa silencia NLA temporariamente para mostrar APENAS o clip escolhido.
Restaure a configuracao de NLA depois, se estiver editando um .blend manualmente.
"""
import bpy
import math

CLIP = "walk-loop"
TEST_BONES = {
    "walk-loop": ("thigh.L", 1, 13),
    "attack": ("upper_arm.R", 1, 9),
    "idle-loop": ("spine", 1, 25),
}

def main():
    rig = bpy.data.objects.get("Knight_Rig")
    if rig is None or rig.type != "ARMATURE":
        raise RuntimeError("Knight_Rig ausente. Gere o personagem + rig primeiro.")
    action = bpy.data.actions.get(CLIP)
    if action is None:
        raise RuntimeError(f"Action '{CLIP}' nao existe. O script de animacao nao foi executado.")
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    rig.animation_data_create()
    for track in rig.animation_data.nla_tracks:
        track.mute = True
    rig.animation_data.action = action
    if hasattr(rig.animation_data, "action_slot") and hasattr(action, "slots") and len(action.slots):
        rig.animation_data.action_slot = action.slots[0]
    bpy.context.scene.render.fps = 24
    start, end = {
        "walk-loop": (1,25), "attack": (1,17), "idle-loop": (1,49)
    }[CLIP]
    bpy.context.scene.frame_start = start
    bpy.context.scene.frame_end = end
    bone_name, frame_a, frame_b = TEST_BONES[CLIP]
    bone = rig.pose.bones.get(bone_name)
    if bone is None:
        raise RuntimeError(f"Rig nao contem osso esperado: {bone_name}")
    bpy.context.scene.frame_set(frame_a)
    q1 = bone.matrix.to_quaternion().copy()
    bpy.context.scene.frame_set(frame_b)
    q2 = bone.matrix.to_quaternion().copy()
    diff = q1.rotation_difference(q2).angle
    bpy.context.scene.frame_set(start)
    bpy.ops.object.select_all(action='DESELECT')
    rig.select_set(True)
    bpy.context.view_layer.objects.active = rig
    print("=== TESTE DE ANIMACAO BLENDER ===")
    print("Action:", action.name)
    print("Timeline:", start, "a", end, "(24 FPS)")
    print("Osso:", bone_name, "variacao:", round(math.degrees(diff), 2), "graus")
    if diff < 0.05:
        print("FALHA: quase nenhuma movimentacao foi avaliada entre os frames de teste.")
    else:
        print("OK: Blender avalia movimento neste osso.")
    print("Pressione Play na Timeline e assista ao ciclo COMPLETO.")

main()
