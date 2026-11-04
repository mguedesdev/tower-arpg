"""Execute no Blender com o cavaleiro + rig abertos. Nao apaga objetos."""
import bpy

# Altere para "idle-loop" ou "attack" se quiser visualizar outra animacao.
ANIMACAO = "walk-loop"
FIM = {"walk-loop": 25, "idle-loop": 49, "attack": 30}

rig = bpy.data.objects.get("Knight_Rig")
action = bpy.data.actions.get(ANIMACAO)
if rig is None or action is None:
    raise RuntimeError("Gere primeiro o cavaleiro e o rig: nao encontrei Knight_Rig ou a Action.")
if rig.animation_data is None:
    rig.animation_data_create()
for track in rig.animation_data.nla_tracks:
    track.mute = True
rig.animation_data.action = action
if hasattr(rig.animation_data, "action_slot") and len(action.slots):
    rig.animation_data.action_slot = action.slots[0]
bpy.context.scene.render.fps = 24
bpy.context.scene.render.fps_base = 1.0
bpy.context.scene.frame_start = 1
bpy.context.scene.frame_end = FIM[ANIMACAO]
bpy.context.scene.frame_set(1)
print("Teste", ANIMACAO, "frame 1 a", FIM[ANIMACAO])
print("Use Play no timeline: WALK e IDLE devem repetir, ATTACK e executado uma vez no Godot.")
