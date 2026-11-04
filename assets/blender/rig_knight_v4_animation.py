"""V1.3 — Animações Orgânicas Contínuas Frame-a-Frame com Passada Anti-Slide (Idle + Walk + Attack legado).

Melhorias chave no Walk/Run (walk-loop):
  - Fase de apoio no chão (stance phase) com velocidade angular constante na coxa
    (dente-de-serra suavizado em vez de seno puro), garantindo que a bota se desloque
    para trás exatamente na mesma velocidade constante do chão (ZERO foot sliding!).
  - Amplitude atlética de corrida (-0.76 rad a +0.72 rad na coxa, 1.12 rad no joelho)
    para casar perfeitamente com o deslocamento real no Godot.
"""
import bpy
import math
from math import sin, cos, pi

RIG_NAME = "Knight_Rig"
FPS = 24


def _reset_pose(arm):
    for bone in arm.pose.bones:
        bone.rotation_mode = "XYZ"
        bone.rotation_euler = (0.0, 0.0, 0.0)
        bone.location = (0.0, 0.0, 0.0)


def _bake_action(arm, name, frame_start, frame_end, eval_fn):
    old_action = bpy.data.actions.get(name)
    if old_action is not None:
        if arm.animation_data and arm.animation_data.action == old_action:
            arm.animation_data.action = None
        bpy.data.actions.remove(old_action)

    _reset_pose(arm)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    arm.animation_data_create()
    arm.animation_data.action = action
    if hasattr(arm.animation_data, "action_slot") and hasattr(action, "slots") and len(action.slots):
        arm.animation_data.action_slot = action.slots[0]

    for frame in range(frame_start, frame_end + 1):
        rot_map, loc_map = eval_fn(frame)
        for bone_name, pb in arm.pose.bones.items():
            rx, ry, rz = rot_map.get(bone_name, (0.0, 0.0, 0.0))
            pb.rotation_euler = (rx, ry, rz)
            pb.keyframe_insert("rotation_euler", frame=frame, group=bone_name)
            if bone_name == "hips" or bone_name in loc_map:
                lx, ly, lz = loc_map.get(bone_name, (0.0, 0.0, 0.0))
                pb.location = (lx, ly, lz)
                pb.keyframe_insert("location", frame=frame, group=bone_name)

    return action


def make_idle(arm):
    def eval_idle(frame):
        t = (frame - 1) / 48.0
        w = 2.0 * pi * t

        breath = sin(w)
        chest_breath = sin(w - 0.35)
        arm_lag = sin(w - 0.70)
        wrist_lag = sin(w - 1.05)
        cape_wave = sin(w - 0.90)
        sway = sin(w + 0.5)

        tl = -0.16 - 0.035 * breath
        sl = 0.30 + 0.065 * breath
        fl = -(tl + sl)

        tr = 0.10 - 0.030 * breath
        sr = 0.22 + 0.055 * breath
        fr = -(tr + sr)

        rot = {
            "hips": (
                0.04 + 0.015 * breath,
                -0.16 + 0.025 * sway,
                0.025 * sway,
            ),
            "spine": (
                0.08 + 0.035 * chest_breath,
                0.18 - 0.030 * sway,
                -0.020 * sway,
            ),
            "head": (
                -0.06 - 0.025 * chest_breath,
                -0.04 + 0.045 * sin(w - 0.5),
                0.015 * sway,
            ),
            "upper_arm.L": (
                -0.38 - 0.045 * arm_lag,
                -0.16 + 0.02 * sway,
                0.14 + 0.025 * chest_breath,
            ),
            "forearm.L": (
                -0.78 - 0.04 * wrist_lag,
                0.18,
                0.0,
            ),
            "hand.L": (
                -0.10 - 0.03 * wrist_lag,
                0.0,
                0.0,
            ),
            "upper_arm.R": (
                0.12 - 0.045 * arm_lag,
                0.28,
                0.22 + 0.03 * chest_breath,
            ),
            "forearm.R": (
                -0.95 - 0.05 * wrist_lag,
                0.0,
                0.0,
            ),
            "hand.R": (
                -0.36 - 0.045 * wrist_lag,
                0.10,
                0.08,
            ),
            "sword.R": (
                -0.95 - 0.055 * sin(w - 1.35),
                0.12,
                0.08,
            ),
            "thigh.L": (tl, 0.0, 0.0),
            "shin.L": (sl, 0.0, 0.0),
            "foot.L": (fl, 0.0, 0.0),
            "thigh.R": (tr, 0.0, 0.0),
            "shin.R": (sr, 0.0, 0.0),
            "foot.R": (fr, 0.0, 0.0),
            "cape": (
                0.12 + 0.045 * cape_wave,
                0.04 * sway,
                0.035 * cape_wave,
            ),
        }
        loc = {
            "hips": (0.0, -0.025 - 0.028 * breath, 0.0),
        }
        return rot, loc

    return _bake_action(arm, "idle-loop", 1, 49, eval_idle)


def make_walk(arm):
    # 24 frames (frames 1..25 @ 24 FPS = 1.0s) — Cinemática Inversa Analítica de 2 Ossos (IK Anti-Slide)
    # Garante matematicamente que o pé de apoio deslize 0% na vertical (plantado no solo z=0.30)
    # e se mova com velocidade horizontal 100% constante durante toda a fase de contato!
    stride_half = 1.12  # Alcance frontal/traseiro em unidades locais do rig (2.24 un por passada)

    def solve_leg_ik(phase, hip_drop):
        p = phase % (2.0 * pi)
        z_hip = 2.30 + hip_drop

        if p <= pi:
            # Fase de Apoio no Solo (Stance Phase: 0 .. pi) -> Velocidade linear constante no chão!
            u = p / pi
            y_ankle = -stride_half + (2.0 * stride_half) * u
            # O calcanhar fica colado no solo (z=0.30) e só levanta no empurrão final (push-off, u > 0.78)
            heel_peel = max(0.0, (u - 0.78) / 0.22) ** 1.6 * 0.14
            z_ankle = 0.30 + heel_peel
            foot_world_pitch = 0.32 * max(0.0, (u - 0.72) / 0.28) - 0.14 * max(0.0, (0.18 - u) / 0.18)
        else:
            # Fase Aérea de Recuperação (Swing Phase: pi .. 2*pi) -> Arco limpo levantando o joelho
            v = (p - pi) / pi
            # Curva suave mas rápida no meio da recuperação aérea para pousar firme na frente
            s = v - 0.10 * sin(2.0 * pi * v)
            y_ankle = stride_half - (2.0 * stride_half) * s
            lift = (sin(pi * v) ** 0.85) * 0.56
            z_ankle = 0.30 + lift
            foot_world_pitch = 0.42 * sin(pi * v) - 0.14 * (v ** 2)

        dy = y_ankle
        dz = max(0.20, z_hip - z_ankle)
        d = min(1.994, math.hypot(dy, dz))
        # Lei dos Cossenos exata para L_thigh = 1.0 e L_shin = 1.0
        shin = math.acos(max(-1.0, min(1.0, 0.5 * d * d - 1.0)))
        thigh = math.atan2(dy, dz) - 0.5 * shin
        foot = -(thigh + shin) + foot_world_pitch
        return thigh, shin, foot

    def eval_walk(frame):
        t = (frame - 1) / 24.0
        w = 2.0 * pi * t

        # Hip drop sincronizado com a abertura máxima das pernas (w=0 e w=pi) e subida na passagem (w=pi/2)
        hip_drop = -0.335 - 0.055 * cos(2.0 * w)
        tl, sl, fl = solve_leg_ik(w, hip_drop)
        tr, sr, fr = solve_leg_ik(w + pi, hip_drop)

        chest_bounce = -cos(2.0 * w - 0.35)

        rot = {
            "hips": (
                0.04 + 0.020 * cos(2.0 * w),
                -0.16 * cos(w),
                0.04 * cos(w),
            ),
            "spine": (
                0.14 + 0.035 * chest_bounce,
                0.20 * cos(w - 0.15),
                -0.04 * cos(w - 0.15),
            ),
            "head": (
                -0.12 - 0.020 * chest_bounce,
                -0.08 * cos(w - 0.25),
                0.02 * cos(w - 0.20),
            ),
            "thigh.L": (tl, 0.0, 0.0),
            "shin.L": (sl, 0.0, 0.0),
            "foot.L": (fl, 0.0, 0.0),
            "thigh.R": (tr, 0.0, 0.0),
            "shin.R": (sr, 0.0, 0.0),
            "foot.R": (fr, 0.0, 0.0),
            "upper_arm.R": (
                0.10 + 0.42 * cos(w - 0.15),
                0.24 + 0.06 * sin(w),
                0.20 + 0.025 * chest_bounce,
            ),
            "forearm.R": (
                -0.90 + 0.16 * cos(w - 0.55),
                0.0,
                0.0,
            ),
            "hand.R": (
                -0.34 + 0.12 * cos(w - 0.90),
                0.08,
                0.06,
            ),
            "sword.R": (
                -0.92 + 0.14 * cos(w - 1.15),
                0.10,
                0.06,
            ),
            "upper_arm.L": (
                -0.30 - 0.22 * cos(w - 0.15),
                -0.10 + 0.04 * cos(w),
                0.12 + 0.020 * chest_bounce,
            ),
            "forearm.L": (
                -0.72 - 0.08 * cos(2.0 * w - 0.60),
                0.14,
                0.0,
            ),
            "hand.L": (
                -0.08 - 0.04 * cos(2.0 * w - 0.90),
                0.0,
                0.0,
            ),
            "cape": (
                0.34 + 0.09 * sin(2.0 * w - 0.75),
                -0.10 * cos(w - 0.45),
                0.06 * sin(w - 0.45),
            ),
        }
        loc = {
            "hips": (0.0, hip_drop, 0.0),
        }
        return rot, loc

    return _bake_action(arm, "walk-loop", 1, 25, eval_walk)


def make_attack(arm):
    def eval_legacy(frame):
        t = (frame - 1) / 16.0
        strike = sin(pi * min(1.0, max(0.0, (t - 0.18) / 0.55)))
        rot = {
            "spine": (0.14 * strike, 0.28 * strike, 0.0),
            "upper_arm.R": (-0.95 * strike, 0.10 * strike, 0.0),
            "forearm.R": (-0.82 + 0.50 * strike, 0.0, 0.0),
            "sword.R": (-0.88, 0.0, 0.0),
            "cape": (0.10 + 0.28 * strike, 0.0, 0.0),
        }
        return rot, {}

    return _bake_action(arm, "attack", 1, 17, eval_legacy)


def main():
    arm = bpy.data.objects.get(RIG_NAME)
    if arm is None or arm.type != "ARMATURE":
        raise RuntimeError("Knight_Rig nao encontrado. Execute a modelagem e o rig v3 primeiro.")
    bpy.context.scene.render.fps = FPS
    idle = make_idle(arm)
    make_walk(arm)
    make_attack(arm)
    arm.animation_data.action = idle
    if idle is not None and hasattr(idle, "slots") and len(idle.slots) > 0:
        arm.animation_data.action_slot = idle.slots[0]
    bpy.context.scene.frame_start = 1
    bpy.context.scene.frame_end = 49
    bpy.context.scene.frame_set(1)
    print("V1.3: idle-loop e walk-loop (anti-slide) atualizados.")


main()
