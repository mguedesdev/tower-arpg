"""Ataques V1.2 — Síntese Contínua Frame-a-Frame com Easing Não-Linear, Hit-Stop,
Overshoot Elástico, Empunhadura Real da Espada e Footwork de Corpo Inteiro.

Corrige também a postura base e o arco da lâmina:
  - A pose de guarda inicial/final mantém a espada erguida à frente (casando 100% com o novo idle-loop).
  - Nos golpes horizontais (attack_arc e attack_spin), a espada corta na altura do peito
    em vez de apontar para o chão.
"""

import math
from math import sin, cos, pi, radians
import bpy

RIG = "Knight_Rig"
FPS = 24
NAMES = ("attack_stab", "attack_arc", "attack_spin", "attack_pierce")


def _smoothstep(a, b, x):
    if x <= a:
        return 0.0
    if x >= b:
        return 1.0
    t = (x - a) / (b - a)
    return t * t * (3.0 - 2.0 * t)


def _whip_step(a, b, x):
    if x <= a:
        return 0.0
    if x >= b:
        return 1.0
    t = (x - a) / (b - a)
    return 1.0 - (1.0 - t) ** 2.8


def _lerp3(v0, v1, w):
    return (
        v0[0] + (v1[0] - v0[0]) * w,
        v0[1] + (v1[1] - v0[1]) * w,
        v0[2] + (v1[2] - v0[2]) * w,
    )


def _eval_stage_pose(frame, t_wind, t_hit, t_hold, t_end, p_guard, p_wind, p_hit, p_over):
    if frame <= t_wind:
        w = _smoothstep(1.0, t_wind, float(frame))
        return {k: _lerp3(p_guard[k], p_wind[k], w) for k in p_guard}
    elif frame <= t_hit:
        w = _whip_step(t_wind, t_hit, float(frame))
        return {k: _lerp3(p_wind[k], p_hit[k], w) for k in p_guard}
    elif frame <= t_hold:
        w = _smoothstep(t_hit, t_hold, float(frame))
        return {k: _lerp3(p_hit[k], p_over[k], w) for k in p_guard}
    else:
        w = _smoothstep(t_hold, t_end, float(frame))
        spring = min(1.0, max(0.0, w + 0.06 * sin(pi * w)))
        return {k: _lerp3(p_over[k], p_guard[k], spring) for k in p_guard}


# Pose base de guarda de combate (em graus), casando com o frame 1 do novo idle-loop!
GUARD_DEG = {
    "hips": (2.3, -8.5, 0.8),
    "spine": (4.0, 9.5, -0.8),
    "head": (-3.0, -3.5, 0.4),
    "upper_arm.L": (-20.0, -9.0, 7.5),
    "forearm.L": (-43.0, 10.0, 0.0),
    "hand.L": (-5.0, 0.0, 0.0),
    "upper_arm.R": (7.0, 16.0, 13.0),
    "forearm.R": (-54.0, 0.0, 0.0),
    "hand.R": (-20.5, 6.0, 4.5),
    "sword.R": (-54.0, 7.0, 4.5),
    "thigh.L": (-9.2, 0.0, 0.0),
    "shin.L": (17.2, 0.0, 0.0),
    "foot.L": (-8.0, 0.0, 0.0),
    "thigh.R": (5.7, 0.0, 0.0),
    "shin.R": (12.6, 0.0, 0.0),
    "foot.R": (-18.3, 0.0, 0.0),
    "cape": (5.5, 1.0, -1.5),
    "hips_loc": (0.0, -0.025, 0.0),
}


def _make_stab_eval():
    # Estocada Rápida (frames 1..16): puxa a guarda ao ombro e dispara na horizontal (-90° total X)
    wind = dict(GUARD_DEG, **{
        "hips": (-4.0, -24.0, -3.0),
        "hips_loc": (0.0, -0.07, 0.0),
        "spine": (-14.0, -28.0, -6.0),
        "head": (5.0, 18.0, 3.0),
        "upper_arm.R": (46.0, -14.0, -26.0),
        "forearm.R": (-88.0, 0.0, -14.0),
        "hand.R": (-26.0, 0.0, -8.0),
        "sword.R": (-38.0, 0.0, 0.0),
        "upper_arm.L": (-34.0, -18.0, 15.0),
        "forearm.L": (-72.0, 16.0, 0.0),
        "hand.L": (-12.0, 0.0, 0.0),
        "thigh.L": (-24.0, 0.0, 0.0),
        "shin.L": (42.0, 0.0, 0.0),
        "foot.L": (-18.0, 0.0, 0.0),
        "thigh.R": (16.0, 0.0, 0.0),
        "shin.R": (28.0, 0.0, 0.0),
        "foot.R": (-44.0, 0.0, 0.0),
        "cape": (4.0, -12.0, 6.0),
    })
    hit = dict(GUARD_DEG, **{
        "hips": (10.0, 22.0, 4.0),
        "hips_loc": (0.0, -0.10, 0.0),
        "spine": (20.0, 30.0, 7.0),
        "head": (-9.0, -15.0, -3.0),
        "upper_arm.R": (-84.0, 10.0, 16.0),
        "forearm.R": (-6.0, 0.0, 0.0),
        "hand.R": (6.0, 0.0, 0.0),
        "sword.R": (-76.0, 0.0, 0.0),
        "upper_arm.L": (20.0, 12.0, -16.0),
        "forearm.L": (-46.0, 0.0, 0.0),
        "hand.L": (-5.0, 0.0, 0.0),
        "thigh.L": (22.0, 0.0, 0.0),
        "shin.L": (14.0, 0.0, 0.0),
        "foot.L": (-36.0, 0.0, 0.0),
        "thigh.R": (-32.0, 0.0, 0.0),
        "shin.R": (54.0, 0.0, 0.0),
        "foot.R": (-22.0, 0.0, 0.0),
        "cape": (38.0, 14.0, -10.0),
    })
    over = dict(hit, **{
        "hips": (12.0, 25.0, 5.0),
        "hips_loc": (0.0, -0.11, 0.0),
        "spine": (23.0, 34.0, 8.0),
        "upper_arm.R": (-90.0, 12.0, 18.0),
        "forearm.R": (-3.0, 0.0, 0.0),
        "sword.R": (-82.0, 0.0, 0.0),
        "cape": (45.0, 18.0, -12.0),
    })
    return lambda f: _eval_stage_pose(f, 4.0, 7.0, 9.5, 16.0, GUARD_DEG, wind, hit, over)


def _make_arc_eval():
    # Corte Horizontal em Meia-Lua (frames 1..20): lâmina erguida na altura do peito varrendo 115°
    wind = dict(GUARD_DEG, **{
        "hips": (-5.0, -32.0, -4.0),
        "hips_loc": (0.0, -0.08, 0.0),
        "spine": (-10.0, -48.0, -8.0),
        "head": (4.0, 26.0, 4.0),
        "upper_arm.R": (-18.0, -34.0, -52.0),
        "forearm.R": (-68.0, 0.0, -18.0),
        "hand.R": (-28.0, 0.0, -14.0),
        "sword.R": (-58.0, 0.0, -24.0),
        "upper_arm.L": (-32.0, -20.0, 14.0),
        "forearm.L": (-72.0, 14.0, 0.0),
        "hand.L": (-10.0, 0.0, 0.0),
        "thigh.L": (-22.0, 0.0, 0.0),
        "shin.L": (40.0, 0.0, 0.0),
        "foot.L": (-18.0, 0.0, 0.0),
        "thigh.R": (14.0, 0.0, 0.0),
        "shin.R": (26.0, 0.0, 0.0),
        "foot.R": (-40.0, 0.0, 0.0),
        "cape": (14.0, -24.0, 12.0),
    })
    hit = dict(GUARD_DEG, **{
        "hips": (9.0, 34.0, 5.0),
        "hips_loc": (0.0, -0.10, 0.0),
        "spine": (15.0, 48.0, 8.0),
        "head": (-6.0, -20.0, -3.0),
        "upper_arm.R": (-64.0, 28.0, 46.0),
        "forearm.R": (-18.0, 0.0, 12.0),
        "hand.R": (-12.0, 0.0, 22.0),
        "sword.R": (-68.0, 0.0, 38.0),
        "upper_arm.L": (16.0, 14.0, -18.0),
        "forearm.L": (-48.0, 0.0, 0.0),
        "hand.L": (-6.0, 0.0, 0.0),
        "thigh.L": (-28.0, 0.0, 0.0),
        "shin.L": (48.0, 0.0, 0.0),
        "foot.L": (-20.0, 0.0, 0.0),
        "thigh.R": (20.0, 0.0, 0.0),
        "shin.R": (18.0, 0.0, 0.0),
        "foot.R": (-38.0, 0.0, 0.0),
        "cape": (40.0, 28.0, -16.0),
    })
    over = dict(hit, **{
        "hips": (11.0, 40.0, 6.0),
        "hips_loc": (0.0, -0.11, 0.0),
        "spine": (17.0, 58.0, 10.0),
        "head": (-7.0, -26.0, -4.0),
        "upper_arm.R": (-58.0, 38.0, 58.0),
        "forearm.R": (-14.0, 0.0, 16.0),
        "hand.R": (-8.0, 0.0, 26.0),
        "sword.R": (-64.0, 0.0, 46.0),
        "cape": (48.0, 38.0, -22.0),
    })
    return lambda f: _eval_stage_pose(f, 5.5, 9.0, 12.5, 20.0, GUARD_DEG, wind, hit, over)


def _make_pierce_eval():
    # Lança Perfurante / Estocada Pesada (frames 1..20)
    wind = dict(GUARD_DEG, **{
        "hips": (-8.0, -34.0, -5.0),
        "hips_loc": (0.0, -0.10, 0.0),
        "spine": (-18.0, -38.0, -9.0),
        "head": (7.0, 24.0, 4.0),
        "upper_arm.R": (58.0, -20.0, -34.0),
        "forearm.R": (-96.0, 0.0, -18.0),
        "hand.R": (-32.0, 0.0, -12.0),
        "sword.R": (-42.0, 0.0, 0.0),
        "upper_arm.L": (-42.0, -24.0, 20.0),
        "forearm.L": (-78.0, 18.0, 0.0),
        "hand.L": (-14.0, 0.0, 0.0),
        "thigh.L": (-32.0, 0.0, 0.0),
        "shin.L": (56.0, 0.0, 0.0),
        "foot.L": (-24.0, 0.0, 0.0),
        "thigh.R": (22.0, 0.0, 0.0),
        "shin.R": (36.0, 0.0, 0.0),
        "foot.R": (-58.0, 0.0, 0.0),
        "cape": (2.0, -18.0, 10.0),
    })
    hit = dict(GUARD_DEG, **{
        "hips": (14.0, 30.0, 6.0),
        "hips_loc": (0.0, -0.13, 0.0),
        "spine": (25.0, 40.0, 10.0),
        "head": (-12.0, -22.0, -4.0),
        "upper_arm.R": (-93.0, 14.0, 20.0),
        "forearm.R": (-3.0, 0.0, 0.0),
        "hand.R": (9.0, 0.0, 0.0),
        "sword.R": (-84.0, 0.0, 0.0),
        "upper_arm.L": (30.0, 18.0, -24.0),
        "forearm.L": (-36.0, 0.0, 0.0),
        "hand.L": (-4.0, 0.0, 0.0),
        "thigh.L": (28.0, 0.0, 0.0),
        "shin.L": (12.0, 0.0, 0.0),
        "foot.L": (-40.0, 0.0, 0.0),
        "thigh.R": (-38.0, 0.0, 0.0),
        "shin.R": (64.0, 0.0, 0.0),
        "foot.R": (-26.0, 0.0, 0.0),
        "cape": (48.0, 20.0, -14.0),
    })
    over = dict(hit, **{
        "hips": (16.0, 33.0, 7.0),
        "hips_loc": (0.0, -0.14, 0.0),
        "spine": (27.0, 42.0, 11.0),
        "upper_arm.R": (-96.0, 15.0, 22.0),
        "forearm.R": (-1.5, 0.0, 0.0),
        "sword.R": (-88.0, 0.0, 0.0),
        "cape": (54.0, 24.0, -16.0),
    })
    return lambda f: _eval_stage_pose(f, 6.0, 9.0, 13.0, 20.0, GUARD_DEG, wind, hit, over)


def _make_spin_eval():
    # Giro Completo 360° (frames 1..24): braço e espada abertos na horizontal varrendo 360°!
    def eval_spin(frame):
        f = float(frame)
        if f <= 5.0:
            w = _smoothstep(1.0, 5.0, f)
            yaw = -8.5 - 30.5 * w
            spin_intensity = 0.25 * w
            crouch = -0.025 - 0.12 * w
        elif f <= 18.0:
            w = _smoothstep(5.0, 18.0, f)
            yaw = -39.0 + 405.0 * (w ** 0.90)
            spin_intensity = sin(pi * w)
            crouch = -0.145 + 0.22 * sin(pi * w)
        else:
            w = _smoothstep(18.0, 24.0, f)
            yaw = 366.0 + (351.5 - 366.0) * w
            spin_intensity = (1.0 - w) * 0.25
            crouch = -0.09 * (1.0 - w) - 0.025 * w

        pose = dict(GUARD_DEG)
        pose["hips"] = (
            2.3 + 7.0 * spin_intensity,
            yaw,
            4.0 * sin(2.0 * pi * (f - 1.0) / 23.0),
        )
        pose["hips_loc"] = (0.0, crouch, 0.0)
        pose["spine"] = (
            4.0 + 13.0 * spin_intensity,
            9.5 + 12.0 * spin_intensity,
            0.0,
        )
        pose["head"] = (-3.0 - 4.0 * spin_intensity, -3.5 - 6.0 * spin_intensity, 0.0)
        # Braço e espada estendidos na horizontal durante o redemoinho!
        pose["upper_arm.R"] = (
            10.5 - 82.0 * spin_intensity,
            5.7 + 16.0 * spin_intensity,
            -9.5 - 44.0 * spin_intensity,
        )
        pose["forearm.R"] = (-48.0 + 36.0 * spin_intensity, 0.0, 0.0)
        pose["hand.R"] = (-18.5 + 14.0 * spin_intensity, 0.0, 3.5 + 18.0 * spin_intensity)
        pose["sword.R"] = (-50.0 - 28.0 * spin_intensity, 0.0, 24.0 * spin_intensity)
        pose["upper_arm.L"] = (
            -20.0 - 14.0 * spin_intensity,
            -9.0 + 18.0 * spin_intensity,
            7.5 + 16.0 * spin_intensity,
        )
        pose["forearm.L"] = (-43.0 - 18.0 * spin_intensity, 10.0, 0.0)
        pose["thigh.L"] = (-9.2 - 18.0 * spin_intensity, 0.0, 0.0)
        pose["shin.L"] = (17.2 + 28.0 * spin_intensity, 0.0, 0.0)
        pose["foot.L"] = (-8.0 - 12.0 * spin_intensity, 0.0, 0.0)
        pose["thigh.R"] = (5.7 + 14.0 * spin_intensity, 0.0, 0.0)
        pose["shin.R"] = (12.6 + 24.0 * spin_intensity, 0.0, 0.0)
        pose["foot.R"] = (-18.3 - 20.0 * spin_intensity, 0.0, 0.0)
        pose["cape"] = (
            5.5 + 50.0 * spin_intensity,
            26.0 * spin_intensity,
            -18.0 * spin_intensity,
        )
        return pose

    return eval_spin


def _remove_previous_action(armature, name):
    old = bpy.data.actions.get(name)
    if old is None:
        return
    animation_data = armature.animation_data
    if animation_data is not None:
        if animation_data.action == old:
            animation_data.action = None
        for track in list(animation_data.nla_tracks):
            for strip in list(track.strips):
                if strip.action == old:
                    track.strips.remove(strip)
            if len(track.strips) == 0:
                animation_data.nla_tracks.remove(track)
    bpy.data.actions.remove(old)


def _set_neutral_pose(armature):
    for bone in armature.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.location = (0.0, 0.0, 0.0)


def _bake_attack_action(armature, name, duration, eval_fn, impact_frame):
    _remove_previous_action(armature, name)
    _set_neutral_pose(armature)
    armature.animation_data_create()
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    armature.animation_data.action = action
    if hasattr(armature.animation_data, "action_slot") and hasattr(action, "slots") and len(action.slots):
        armature.animation_data.action_slot = action.slots[0]

    for frame in range(1, duration + 1):
        pose_deg = eval_fn(frame)
        for bone_name, bone in armature.pose.bones.items():
            deg = pose_deg.get(bone_name, (0.0, 0.0, 0.0))
            bone.rotation_euler = (radians(deg[0]), radians(deg[1]), radians(deg[2]))
            bone.keyframe_insert(data_path="rotation_euler", frame=frame, group=bone_name)
        hips_bone = armature.pose.bones.get("hips")
        if hips_bone is not None:
            loc = pose_deg.get("hips_loc", (0.0, 0.0, 0.0))
            hips_bone.location = tuple(loc)
            hips_bone.keyframe_insert(data_path="location", frame=frame, group="hips")

    action["frame_start_design"] = 1
    action["frame_end_design"] = duration
    action["impact_frame_design"] = impact_frame
    action["full_body_design"] = True
    return action


def main():
    rig = bpy.data.objects.get(RIG)
    if rig is None or rig.type != "ARMATURE":
        raise RuntimeError("Knight_Rig nao encontrado. Primeiro gere o cavaleiro e o rig v3.")

    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.context.scene.render.fps = FPS

    actions = [
        _bake_attack_action(rig, "attack_stab", 16, _make_stab_eval(), 7),
        _bake_attack_action(rig, "attack_arc", 20, _make_arc_eval(), 9),
        _bake_attack_action(rig, "attack_spin", 24, _make_spin_eval(), 13),
        _bake_attack_action(rig, "attack_pierce", 20, _make_pierce_eval(), 9),
    ]

    idle = bpy.data.actions.get("idle-loop")
    if idle is not None:
        rig.animation_data.action = idle
        if hasattr(rig.animation_data, "action_slot") and len(idle.slots):
            rig.animation_data.action_slot = idle.slots[0]
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 49
    bpy.context.scene.frame_set(1)
    print("\n=== ATAQUES V1.2 (CURVAS CONTÍNUAS + EMPUNHADURA CORRIGIDA) CRIADOS ===")
    for action, duration in zip(actions, (16, 20, 24, 20)):
        print("%s: frames 1-%d (24 fps), %.2f segundos" % (
            action.name, duration, (duration - 1) / FPS))


main()
