import bpy
import math

RIG_NAME = "Wolf_Rig"
ANIMATION_NAMES = ("idle-loop", "walk-loop", "attack")
AXES = {"x": 0, "y": 1, "z": 2}

PARTS_TO_BONES = {
    # Tronco
    "Chest": "spine",
    "Mane_Spikes_Front": "spine",
    "Mane_Mid": "spine",
    "Underbelly": "spine",
    "Waist": "hips",
    "Hips": "hips",
    "Neck": "neck",
    # Cabeça
    "Head": "head",
    "Brow_Ridge": "head",
    "Muzzle_Upper": "head",
    "Nose": "head",
    "Eye_L": "head",
    "Eye_R": "head",
    "Ear_L": "head",
    "Ear_R": "head",
    "Ear_Inner_L": "head",
    "Ear_Inner_R": "head",
    "Fang_Upper_L": "head",
    "Fang_Upper_R": "head",
    # Mandíbula / Boca
    "Jaw_Mesh": "jaw",
    "Fang_Lower_L": "jaw",
    "Fang_Lower_R": "jaw",
    # Pata Dianteira Esquerda
    "Front_Shoulder_L": "front_shoulder.L",
    "Front_Upper_L": "front_upper.L",
    "Front_Shin_L": "front_shin.L",
    "Front_Paw_L": "front_paw.L",
    "Front_Claws_L": "front_paw.L",
    # Pata Dianteira Direita
    "Front_Shoulder_R": "front_shoulder.R",
    "Front_Upper_R": "front_upper.R",
    "Front_Shin_R": "front_shin.R",
    "Front_Paw_R": "front_paw.R",
    "Front_Claws_R": "front_paw.R",
    # Pata Traseira Esquerda
    "Back_Thigh_L": "back_thigh.L",
    "Back_Shin_L": "back_shin.L",
    "Back_Paw_L": "back_paw.L",
    "Back_Claws_L": "back_paw.L",
    # Pata Traseira Direita
    "Back_Thigh_R": "back_thigh.R",
    "Back_Shin_R": "back_shin.R",
    "Back_Paw_R": "back_paw.R",
    "Back_Claws_R": "back_paw.R",
    # Cauda
    "Tail_Base": "tail_1",
    "Tail_Mid": "tail_2",
    "Tail_Tip": "tail_3",
}


def is_descendant(obj, ancestor):
    current = obj
    while current is not None:
        if current == ancestor:
            return True
        current = current.parent
    return False


def remove_old_rig(root):
    old = bpy.data.objects.get(RIG_NAME)
    for obj in list(bpy.data.objects):
        if obj.type != "MESH" or not is_descendant(obj, root):
            continue
        for mod in list(obj.modifiers):
            if mod.type == "ARMATURE" and (old is None or mod.object == old):
                obj.modifiers.remove(mod)
        for group in list(obj.vertex_groups):
            obj.vertex_groups.remove(group)
        if old is not None and obj.parent == old:
            world = obj.matrix_world.copy()
            obj.parent = root
            obj.matrix_world = world
    if old and is_descendant(old, root):
        bpy.data.objects.remove(old)
    for action in list(bpy.data.actions):
        if action.name.split(".")[0] in ANIMATION_NAMES and action.users == 0:
            bpy.data.actions.remove(action)


def build_armature(root):
    bpy.ops.object.armature_add(location=(0, 0, 0))
    armature = bpy.context.active_object
    armature.name = RIG_NAME
    armature.data.name = "Wolf_Armature"
    armature.parent = root
    armature.show_in_front = True

    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones = armature.data.edit_bones
    for bone in list(edit_bones):
        edit_bones.remove(bone)

    # Pivôs 1:1 com a malha esculpida (Frente = +Y, Cima = +Z)
    bones_tree = [
        ("hips", (0.0, -0.44, 0.56), (0.0, -0.05, 0.58), None),
        ("spine", (0.0, -0.05, 0.58), (0.0, 0.34, 0.64), "hips"),
        ("neck", (0.0, 0.34, 0.64), (0.0, 0.52, 0.75), "spine"),
        ("head", (0.0, 0.52, 0.75), (0.0, 0.94, 0.72), "neck"),
        ("jaw", (0.0, 0.55, 0.67), (0.0, 0.86, 0.63), "head"),
        ("tail_1", (0.0, -0.55, 0.58), (0.0, -0.75, 0.48), "hips"),
        ("tail_2", (0.0, -0.75, 0.48), (0.0, -0.95, 0.37), "tail_1"),
        ("tail_3", (0.0, -0.95, 0.37), (0.0, -1.14, 0.32), "tail_2"),
    ]

    for side, sx in (("L", -1.0), ("R", 1.0)):
        bones_tree += [
            ("front_shoulder." + side, (sx * 0.21, 0.27, 0.61), (sx * 0.21, 0.27, 0.55), "spine"),
            ("front_upper." + side, (sx * 0.21, 0.27, 0.55), (sx * 0.20, 0.21, 0.33), "front_shoulder." + side),
            ("front_shin." + side, (sx * 0.20, 0.21, 0.33), (sx * 0.19, 0.26, 0.10), "front_upper." + side),
            ("front_paw." + side, (sx * 0.19, 0.26, 0.10), (sx * 0.19, 0.38, 0.02), "front_shin." + side),
            ("back_thigh." + side, (sx * 0.18, -0.40, 0.55), (sx * 0.19, -0.31, 0.34), "hips"),
            ("back_shin." + side, (sx * 0.19, -0.31, 0.34), (sx * 0.18, -0.40, 0.08), "back_thigh." + side),
            ("back_paw." + side, (sx * 0.18, -0.40, 0.08), (sx * 0.18, -0.28, 0.02), "back_shin." + side),
        ]

    for name, head, tail, parent in bones_tree:
        bone = edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        bone.roll = 0.0
        if parent:
            bone.parent = edit_bones[parent]

    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def bind_parts(armature):
    root = bpy.data.objects.get("Wolf")
    unmatched = []
    bound = 0
    for obj in list(bpy.data.objects):
        if obj.type != "MESH" or not is_descendant(obj, root):
            continue
        bone_name = PARTS_TO_BONES.get(obj.name)
        if bone_name is None or bone_name not in armature.data.bones:
            unmatched.append(obj.name)
            continue
        world = obj.matrix_world.copy()
        obj.parent = armature
        obj.matrix_world = world
        group = obj.vertex_groups.new(name=bone_name)
        group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        modifier = obj.modifiers.new("Armature", "ARMATURE")
        modifier.object = armature
        bound += 1
    print("Pecas vinculadas ao rig:", bound)
    return unmatched


def reset_pose(armature):
    for pb in armature.pose.bones:
        pb.rotation_mode = "XYZ"
        pb.rotation_euler = (0.0, 0.0, 0.0)
        pb.location = (0.0, 0.0, 0.0)


def start_action(armature, name):
    reset_pose(armature)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    if armature.animation_data is None:
        armature.animation_data_create()
    armature.animation_data.action = action
    return action


def key_all_bones(armature, frame):
    for pb in armature.pose.bones:
        pb.keyframe_insert("rotation_euler", frame=frame)
    hips = armature.pose.bones.get("hips")
    if hips:
        hips.keyframe_insert("location", frame=frame)


def create_animations(armature):
    # ==================== 1. IDLE-LOOP (60 frames = 2.46s @ 24fps) ====================
    # Respiração predatória, faro atento, mandíbula arfando e cauda ondulando
    start_action(armature, "idle-loop")
    total_idle = 60
    for f in range(1, total_idle + 1):
        u = (f - 1) / float(total_idle - 1)
        ang = u * 2.0 * math.pi
        ang2 = u * 4.0 * math.pi
        reset_pose(armature)

        pbs = armature.pose.bones
        pbs["hips"].location = (0.0, 0.0, -0.015 * math.sin(ang2))
        pbs["hips"].rotation_euler = (0.025 * math.sin(ang2), 0.0, 0.018 * math.sin(ang))
        pbs["spine"].rotation_euler = (0.045 * math.sin(ang2), 0.02 * math.cos(ang), -0.02 * math.sin(ang))
        pbs["neck"].rotation_euler = (-0.05 * math.sin(ang2), 0.0, 0.045 * math.sin(ang))
        pbs["head"].rotation_euler = (-0.03 * math.cos(ang2), -0.035 * math.sin(ang), 0.06 * math.sin(ang))
        pbs["jaw"].rotation_euler = (0.05 + 0.05 * math.sin(ang2), 0.0, 0.0)

        # Cauda com onda defasada (efeito chicote orgânico)
        pbs["tail_1"].rotation_euler = (-0.04 * math.sin(ang2), 0.0, 0.16 * math.sin(ang))
        pbs["tail_2"].rotation_euler = (-0.05 * math.cos(ang2), 0.0, 0.24 * math.sin(ang - 0.65))
        pbs["tail_3"].rotation_euler = (0.0, 0.0, 0.30 * math.sin(ang - 1.30))

        # Compensação sutil nas patas
        for side in ("L", "R"):
            pbs[f"front_upper.{side}"].rotation_euler = (-0.03 * math.sin(ang2), 0.0, 0.0)
            pbs[f"front_shin.{side}"].rotation_euler = (0.03 * math.sin(ang2), 0.0, 0.0)

        key_all_bones(armature, f)

    # ==================== 2. WALK-LOOP (28 frames = 1.125s @ 24fps) ====================
    # Trote quadrúpede diagonal anti-deslizamento:
    # Pares diagonais: (Front.L + Back.R) em fase 0.0, (Front.R + Back.L) em fase 0.5
    # Stance phase linear no chão + Swing phase com elevação de joelho/jarrete!
    start_action(armature, "walk-loop")
    total_walk = 28

    def leg_gait(phase, is_front=True):
        """
        phase em [0, 1):
          - [0.0 .. 0.55]: Stance (pata apoiada no chão varrendo de + frente para - trás em velocidade linear)
          - [0.55 .. 1.0]: Swing (pata levanta, dobra canela/pata e avança rápido para frente)
        No rig do lobo, rotation_euler.x > 0 gira o membro para TRÁS (-Y),
        e rotation_euler.x < 0 gira o membro para FRENTE (+Y).
        """
        p = phase % 1.0
        amp = 0.46 if is_front else 0.42
        if p < 0.55:
            # Stance: avança linearmente de -amp (frente) até +amp (trás)
            s = p / 0.55
            upper_x = -amp + (2.0 * amp) * s
            # Flexão leve de absorção de impacto no meio do apoio
            shin_x = -0.10 * math.sin(s * math.pi) if is_front else 0.12 * math.sin(s * math.pi)
            paw_x = -(upper_x + shin_x) * 0.65
        else:
            # Swing: retorna de +amp (trás) para -amp (frente) dobrando a articulação para levantar do chão
            w = (p - 0.55) / 0.45
            smooth_w = w * w * (3.0 - 2.0 * w)
            upper_x = amp - (2.0 * amp) * smooth_w
            lift = math.sin(w * math.pi)
            shin_x = (0.48 * lift) if is_front else (-0.42 * lift)
            paw_x = (0.32 * lift) if is_front else (0.35 * lift)
        return upper_x, shin_x, paw_x

    for f in range(1, total_walk + 1):
        u = (f - 1) / float(total_walk - 1)
        ang = u * 2.0 * math.pi
        ang2 = u * 4.0 * math.pi
        reset_pose(armature)
        pbs = armature.pose.bones

        # Pares diagonais de trote lupino
        fl_u, fl_s, fl_p = leg_gait(u, is_front=True)
        br_u, br_s, br_p = leg_gait((u + 0.06) % 1.0, is_front=False)
        fr_u, fr_s, fr_p = leg_gait((u + 0.50) % 1.0, is_front=True)
        bl_u, bl_s, bl_p = leg_gait((u + 0.56) % 1.0, is_front=False)

        pbs["front_shoulder.L"].rotation_euler = (fl_u * 0.18, 0.0, 0.0)
        pbs["front_upper.L"].rotation_euler = (fl_u, 0.0, 0.0)
        pbs["front_shin.L"].rotation_euler = (fl_s, 0.0, 0.0)
        pbs["front_paw.L"].rotation_euler = (fl_p, 0.0, 0.0)

        pbs["front_shoulder.R"].rotation_euler = (fr_u * 0.18, 0.0, 0.0)
        pbs["front_upper.R"].rotation_euler = (fr_u, 0.0, 0.0)
        pbs["front_shin.R"].rotation_euler = (fr_s, 0.0, 0.0)
        pbs["front_paw.R"].rotation_euler = (fr_p, 0.0, 0.0)

        pbs["back_thigh.L"].rotation_euler = (bl_u, 0.0, 0.0)
        pbs["back_shin.L"].rotation_euler = (bl_s, 0.0, 0.0)
        pbs["back_paw.L"].rotation_euler = (bl_p, 0.0, 0.0)

        pbs["back_thigh.R"].rotation_euler = (br_u, 0.0, 0.0)
        pbs["back_shin.R"].rotation_euler = (br_s, 0.0, 0.0)
        pbs["back_paw.R"].rotation_euler = (br_p, 0.0, 0.0)

        # Dinâmica de coluna, quadril e cabeça (2 ciclos verticais por passada completa)
        pbs["hips"].location = (0.0, 0.015 * math.sin(ang2), 0.028 * math.cos(ang2))
        pbs["hips"].rotation_euler = (0.05 * math.sin(ang2), 0.055 * math.sin(ang), 0.04 * math.cos(ang))
        pbs["spine"].rotation_euler = (-0.06 * math.sin(ang2), -0.065 * math.sin(ang), -0.045 * math.cos(ang))
        pbs["neck"].rotation_euler = (0.07 * math.cos(ang2) - 0.06, 0.0, 0.03 * math.cos(ang))
        pbs["head"].rotation_euler = (-0.05 * math.cos(ang2) + 0.05, 0.0, -0.025 * math.cos(ang))
        pbs["jaw"].rotation_euler = (0.06 + 0.04 * math.sin(ang2), 0.0, 0.0)

        # Cauda estabilizando o trote
        pbs["tail_1"].rotation_euler = (0.08 * math.sin(ang2), 0.0, 0.22 * math.sin(ang))
        pbs["tail_2"].rotation_euler = (0.10 * math.cos(ang2), 0.0, 0.34 * math.sin(ang - 0.7))
        pbs["tail_3"].rotation_euler = (0.0, 0.0, 0.42 * math.sin(ang - 1.3))

        key_all_bones(armature, f)

    # ==================== 3. ATTACK (28 frames = 1.125s @ 24fps) ====================
    # F1..F8: Agacha e abre a bocarra (Windup)
    # F8..F13: Salto explosivo para frente com garras estendidas (Lunge)
    # F13..F18: Mordida violenta no alvo + patada (Snap)
    # F18..F28: Pouso e recuperação (Recovery)
    start_action(armature, "attack")
    total_atk = 28

    def smooth(t):
        t = max(0.0, min(1.0, t))
        return t * t * (3.0 - 2.0 * t)

    for f in range(1, total_atk + 1):
        reset_pose(armature)
        pbs = armature.pose.bones

        if f <= 8:
            t = smooth((f - 1) / 7.0)
            hips_y = -0.14 * t
            hips_z = -0.09 * t
            spine_x = -0.22 * t
            neck_x = -0.18 * t
            head_x = 0.22 * t
            jaw_x = 0.18 * t
            f_up = 0.32 * t
            f_sh = -0.35 * t
            b_th = -0.38 * t
            b_sh = 0.35 * t
            tail_x = 0.25 * t
        elif f <= 13:
            t = smooth((f - 8) / 5.0)
            hips_y = -0.14 + (0.42 - (-0.14)) * t
            hips_z = -0.09 + (0.18 - (-0.09)) * t
            spine_x = -0.22 + (0.30 - (-0.22)) * t
            neck_x = -0.18 + (0.24 - (-0.18)) * t
            head_x = 0.22 + (0.18 - 0.22) * t
            jaw_x = 0.18 + (0.62 - 0.18) * t  # Bocarra escancarada no salto!
            f_up = 0.32 + (-0.68 - 0.32) * t   # Patas dianteiras lançadas para frente!
            f_sh = -0.35 + (0.20 - (-0.35)) * t
            b_th = -0.38 + (0.52 - (-0.38)) * t  # Impulso traseiro!
            b_sh = 0.35 + (-0.25 - 0.35) * t
            tail_x = 0.25 + (-0.32 - 0.25) * t
        elif f <= 18:
            t = smooth((f - 13) / 5.0)
            hips_y = 0.42 + (0.22 - 0.42) * t
            hips_z = 0.18 + (-0.03 - 0.18) * t
            spine_x = 0.30 + (-0.08 - 0.30) * t
            neck_x = 0.24 + (-0.14 - 0.24) * t
            head_x = 0.18 + (-0.26 - 0.18) * t
            jaw_x = 0.62 + (-0.04 - 0.62) * t  # SNAP! Mandíbula fecha com impacto!
            f_up = -0.68 + (0.12 - (-0.68)) * t
            f_sh = 0.20 + (0.10 - 0.20) * t
            b_th = 0.52 + (-0.10 - 0.52) * t
            b_sh = -0.25 + (0.08 - (-0.25)) * t
            tail_x = -0.32 + (0.10 - (-0.32)) * t
        else:
            t = smooth((f - 18) / 10.0)
            hips_y = 0.22 * (1.0 - t)
            hips_z = -0.03 * (1.0 - t)
            spine_x = -0.08 * (1.0 - t)
            neck_x = -0.14 * (1.0 - t)
            head_x = -0.26 * (1.0 - t)
            jaw_x = -0.04 * (1.0 - t)
            f_up = 0.12 * (1.0 - t)
            f_sh = 0.10 * (1.0 - t)
            b_th = -0.10 * (1.0 - t)
            b_sh = 0.08 * (1.0 - t)
            tail_x = 0.10 * (1.0 - t)

        pbs["hips"].location = (0.0, hips_y, hips_z)
        pbs["spine"].rotation_euler = (spine_x, 0.0, 0.0)
        pbs["neck"].rotation_euler = (neck_x, 0.0, 0.0)
        pbs["head"].rotation_euler = (head_x, 0.0, 0.0)
        pbs["jaw"].rotation_euler = (jaw_x, 0.0, 0.0)

        for side in ("L", "R"):
            pbs[f"front_upper.{side}"].rotation_euler = (f_up, 0.0, 0.0)
            pbs[f"front_shin.{side}"].rotation_euler = (f_sh, 0.0, 0.0)
            pbs[f"back_thigh.{side}"].rotation_euler = (b_th, 0.0, 0.0)
            pbs[f"back_shin.{side}"].rotation_euler = (b_sh, 0.0, 0.0)

        pbs["tail_1"].rotation_euler = (tail_x, 0.0, 0.0)
        pbs["tail_2"].rotation_euler = (tail_x * 0.8, 0.0, 0.0)

        key_all_bones(armature, f)


def rig_wolf():
    root = bpy.data.objects.get("Wolf")
    if root is None:
        raise RuntimeError("Execute low_poly_wolf.py primeiro!")
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    remove_old_rig(root)
    armature = build_armature(root)
    unmatched = bind_parts(armature)
    create_animations(armature)
    bpy.context.scene.frame_set(1)
    print(f"Rig do Lobo finalizado: {len(armature.data.bones)} ossos configurados.")
    if unmatched:
        raise RuntimeError("Pecas do lobo sem bone: " + ", ".join(unmatched))


if __name__ == "__main__":
    rig_wolf()
