"""SkeletonEnemy v0.16 — Rig + Idle + Anti-Slide Walk + Cleave Attack + GLB Export.

Gera e exporta automaticamente:
  1. assets/models/skeleton_enemy.glb (Guerreiro Esqueleto Profanado com Cutelo & Broquel)
  2. assets/models/skeleton_boss.glb  (Mini-Boss Carrasco Profanado com Machado Abissal & Coroa de Chifres)

Todas as animações ('idle', 'walk', 'attack') são assadas quadro a quadro a 24 FPS.
Convenções: fonte Blender +Y = frente; +Z = cima. No Godot o GLB fica com frente em -Z.
"""

import bpy
import math
from math import radians
from mathutils import Vector, Quaternion
from pathlib import Path

SCRIPT_NAME = "RIGAR_E_EXPORTAR_ESQUELETO_INIMIGO.py"
ROOT_NAME = "SkeletonEnemy"
RIG_NAME = "Skeleton_Armature"
IDLE_NAME = "idle"
WALK_NAME = "walk"
ATTACK_NAME = "attack"
FPS = 24


def get_script_dir():
    candidate = globals().get("__file__")
    if candidate:
        maybe = Path(candidate).resolve()
        if maybe.is_file():
            return maybe.parent
    space = getattr(bpy.context, "space_data", None)
    text_data = getattr(space, "text", None)
    if text_data and text_data.filepath:
        maybe = Path(bpy.path.abspath(text_data.filepath)).resolve()
        if maybe.is_file():
            return maybe.parent
    for text_block in bpy.data.texts:
        if text_block.name == SCRIPT_NAME and text_block.filepath:
            return Path(bpy.path.abspath(text_block.filepath)).resolve().parent
    raise RuntimeError("Não foi possível localizar o diretório de scripts.")


def make_bones(root):
    data = bpy.data.armatures.new("Skeleton_ArmatureData")
    arm = bpy.data.objects.new(RIG_NAME, data)
    root.users_collection[0].objects.link(arm)
    arm.parent = root
    arm.location = (0.0, 0.0, 0.0)
    arm.rotation_euler = (0.0, 0.0, 0.0)
    arm.scale = (1.0, 1.0, 1.0)
    arm.show_in_front = True
    arm.display_type = "WIRE"
    bpy.ops.object.select_all(action='DESELECT')
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode='EDIT')

    bones = [
        ("root", (0, 0, 0.10), (0, 0, 0.35), None),
        ("hips", (0, 0, 1.43), (0, 0, 1.88), "root"),
        ("spine", (0, 0, 1.88), (0, 0, 2.97), "hips"),
        ("neck", (0, -0.03, 2.97), (0, -0.03, 3.55), "spine"),
        ("head", (0, -0.03, 3.55), (0, 0, 4.42), "neck"),
    ]
    for side, s in (("L", -1.0), ("R", 1.0)):
        bones.extend([
            ("upper_arm." + side, (s * 0.67, 0.0, 2.92), (s * 0.86, 0.018, 2.15), "spine"),
            ("forearm." + side, (s * 0.86, 0.018, 2.15), (s * 0.98, 0.07, 1.47), "upper_arm." + side),
            ("hand." + side, (s * 0.98, 0.07, 1.47), (s * 1.00, 0.09, 1.12), "forearm." + side),
            ("thigh." + side, (s * 0.25, 0.0, 1.47), (s * 0.31, 0.03, 0.83), "hips"),
            ("shin." + side, (s * 0.31, 0.03, 0.83), (s * 0.33, 0.0, 0.18), "thigh." + side),
            ("foot." + side, (s * 0.33, 0.0, 0.18), (s * 0.33, 0.36, 0.095), "shin." + side),
        ])

    ed = arm.data.edit_bones
    for name, start, end, parent in bones:
        bone = ed.new(name)
        bone.head = start
        bone.tail = end
        if parent:
            bone.parent = ed[parent]
            bone.use_connect = False
    bpy.ops.object.mode_set(mode='OBJECT')
    for pb in arm.pose.bones:
        pb.rotation_mode = 'QUATERNION'
    return arm


def bone_for_mesh(name):
    if name.startswith(("Head_", "EyeSocket_", "EyeGlow_", "Brow_", "Cheek_", "NoseHole", "Jaw", "MouthGap", "UpperTooth_")):
        return "head"
    if name.startswith(("NeckVertebra_", "NeckStem")):
        return "neck"
    if name.startswith(("Spine_", "Sternum", "Clavicle_", "Rib_")):
        return "spine"
    if name.startswith(("PelvisWing_", "HipJoint_", "Belt", "Buckle", "Cloth")):
        return "hips"
    for side in ('L', 'R'):
        suffix = '_' + side
        if name.startswith("ShoulderJoint" + suffix) or name.startswith("ShoulderJoint_Pauldron" + suffix) or name.startswith("ShoulderJoint_Spike" + suffix) or name.startswith("UpperArm" + suffix):
            return "upper_arm." + side
        if name.startswith(("Elbow" + suffix, "Forearm" + suffix, "Wrist" + suffix)):
            return "forearm." + side
        if name.startswith(("Palm" + suffix, "Finger" + suffix)):
            return "hand." + side
        if name.startswith("Thigh" + suffix):
            return "thigh." + side
        if name.startswith(("Knee" + suffix, "Shin" + suffix)):
            return "shin." + side
        if name.startswith(("Ankle" + suffix, "Foot" + suffix, "Toe" + suffix)):
            return "foot." + side
    return None


def bind_model(root, arm):
    parts = [o for o in root.children if o.type == 'MESH']
    unresolved = [obj.name for obj in parts if bone_for_mesh(obj.name) is None]
    if unresolved:
        raise RuntimeError("Pecas sem osso, abortando: " + ", ".join(unresolved))
    for obj in parts:
        bone_name = bone_for_mesh(obj.name)
        if bone_name not in arm.data.bones:
            raise RuntimeError("Osso ausente: " + bone_name)

        world_matrix = obj.matrix_world.copy()
        obj.parent = arm
        obj.matrix_world = world_matrix
        group = obj.vertex_groups.new(name=bone_name)
        group.add(list(range(len(obj.data.vertices))), 1.0, 'REPLACE')
        modifier = obj.modifiers.new("Skeleton_Rig", 'ARMATURE')
        modifier.object = arm
        modifier.use_deform_preserve_volume = False
    return len(parts)


def quat_from_world_axis(pb, ax, angle):
    rest = pb.bone.matrix_local.to_quaternion()
    delta = Quaternion(Vector(ax), radians(angle))
    return rest.inverted() @ delta @ rest


def build_pose(arm, angles, root_offset=(0.0, 0.0, 0.0)):
    for pb in arm.pose.bones:
        pb.rotation_quaternion = Quaternion((1.0, 0.0, 0.0, 0.0))
        pb.location = (0.0, 0.0, 0.0)
    for bone_name, moves in angles.items():
        pb = arm.pose.bones.get(bone_name)
        if pb is None:
            raise RuntimeError("Osso da animacao nao encontrado: " + bone_name)
        q = Quaternion((1.0, 0.0, 0.0, 0.0))
        for axis, degrees in moves:
            q = quat_from_world_axis(pb, axis, degrees) @ q
        pb.rotation_quaternion = q
    arm.pose.bones["root"].location = root_offset


def key_all_bones(arm, frame):
    for pb in arm.pose.bones:
        pb.keyframe_insert(data_path='rotation_quaternion', frame=frame)
    arm.pose.bones['root'].keyframe_insert(data_path='location', frame=frame)


def smoothstep(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3.0 - 2.0 * t)


def make_animations(arm):
    scene = bpy.context.scene
    scene.render.fps = FPS
    for act in list(bpy.data.actions):
        if act.name in (IDLE_NAME, WALK_NAME, ATTACK_NAME):
            bpy.data.actions.remove(act)
    if arm.animation_data is None:
        arm.animation_data_create()

    # ===============================================================
    # 1. IDLE (49 frames = 2.0s @ 24 FPS) — Postura de Guarda Guerreira
    # ===============================================================
    idle = bpy.data.actions.new(name=IDLE_NAME)
    idle.use_fake_user = True
    arm.animation_data.action = idle

    total_idle = 49
    for f in range(1, total_idle + 1):
        u = (f - 1) / float(total_idle - 1)
        ang = u * 2.0 * math.pi
        ang2 = u * 4.0 * math.pi

        breath = math.sin(ang2)
        sway = math.sin(ang)

        pose = {
            "hips": [((0, 0, 1), -8.0 + 2.0 * sway), ((0, 1, 0), 1.5 * sway)],
            "spine": [
                ((1, 0, 0), -8.0 + 2.2 * breath),
                ((0, 1, 0), -2.0 * sway),
                ((0, 0, 1), 10.0 - 3.0 * sway),
            ],
            "neck": [((1, 0, 0), 4.0 - 1.5 * breath)],
            "head": [
                ((1, 0, 0), 4.0 - 1.5 * breath),
                ((0, 0, 1), -6.0 + 5.5 * sway),
                ((0, 1, 0), 2.5 * math.cos(ang)),
            ],
            # Braço esquerdo segura o Broquel em guarda dianteira
            "upper_arm.L": [
                ((1, 0, 0), 28.0 + 2.5 * breath),
                ((0, 1, 0), -14.0),
                ((0, 0, 1), 18.0),
            ],
            "forearm.L": [
                ((1, 0, 0), 52.0 + 3.0 * breath),
                ((0, 0, 1), 24.0),
            ],
            "hand.L": [((1, 0, 0), -6.0)],
            # Braço direito segura o Cutelo / Machado pronto para o golpe
            "upper_arm.R": [
                ((1, 0, 0), -10.0 + 3.0 * sway),
                ((0, 1, 0), 14.0),
                ((0, 0, 1), -12.0),
            ],
            "forearm.R": [
                ((1, 0, 0), 42.0 - 3.5 * breath),
                ((0, 0, 1), -10.0),
            ],
            "hand.R": [((1, 0, 0), -10.0 + 2.5 * breath)],
            # Pernas firmes em base de combate
            "thigh.L": [((1, 0, 0), 8.0), ((0, 0, 1), 6.0)],
            "shin.L": [((1, 0, 0), -12.0)],
            "foot.L": [((1, 0, 0), 4.0)],
            "thigh.R": [((1, 0, 0), -8.0), ((0, 0, 1), -6.0)],
            "shin.R": [((1, 0, 0), -10.0)],
            "foot.R": [((1, 0, 0), 14.0)],
        }
        scene.frame_set(f)
        build_pose(arm, pose, (0.0, 0.0, -0.025 * breath))
        key_all_bones(arm, f)

    # ===============================================================
    # 2. WALK (25 frames = 1.0s @ 24 FPS) — Marcha Pesada Anti-Slide
    # ===============================================================
    walk = bpy.data.actions.new(name=WALK_NAME)
    walk.use_fake_user = True
    arm.animation_data.action = walk

    total_walk = 25

    def biped_leg(phase):
        """
        phase em [0, 1):
          - [0.0 .. 0.54]: Stance (pé plantado varrendo linearmente de +28° frente até -24° trás)
          - [0.54 .. 1.00]: Swing (joelho dobra -42° levantando o pé do chão e avança para +28°)
        """
        p = phase % 1.0
        if p < 0.54:
            s = p / 0.54
            thigh_x = 28.0 - 52.0 * s
            # Leve flexão de absorção de peso no meio do apoio
            shin_x = -8.0 - 10.0 * math.sin(s * math.pi)
            # Pé compensa o ângulo para manter a sola paralela ao chão no apoio
            foot_x = -(thigh_x + shin_x) * 0.55
        else:
            w = (p - 0.54) / 0.46
            sw = smoothstep(w)
            thigh_x = -24.0 + 52.0 * sw
            lift = math.sin(w * math.pi)
            shin_x = -8.0 - 38.0 * lift
            foot_x = -12.0 * lift + (1.0 - lift) * (-(thigh_x + shin_x) * 0.45)
        return thigh_x, shin_x, foot_x

    for f in range(1, total_walk + 1):
        u = (f - 1) / float(total_walk - 1)
        ang = u * 2.0 * math.pi
        ang2 = u * 4.0 * math.pi

        tl, sl, fl = biped_leg(u)
        tr, sr, fr = biped_leg((u + 0.5) % 1.0)
        stride_wave = math.cos(ang)       # +1 quando perna L está à frente, -1 quando R está à frente
        bounce = -0.045 * math.cos(ang2)  # Mais baixo na troca de passo, mais alto no meio do apoio

        pose = {
            "hips": [
                ((0, 0, 1), -7.0 * stride_wave),
                ((0, 1, 0), 3.5 * stride_wave),
            ],
            "spine": [
                ((1, 0, 0), -11.0 + 2.0 * math.sin(ang2)),
                ((0, 1, 0), -3.5 * stride_wave),
                ((0, 0, 1), 9.0 * stride_wave),
            ],
            "neck": [((1, 0, 0), 5.0)],
            "head": [
                ((1, 0, 0), 5.0 - 2.0 * math.sin(ang2)),
                ((0, 0, 1), -6.5 * stride_wave),
                ((0, 1, 0), 2.5 * stride_wave),
            ],
            # Braço do escudo (L) mantém guarda firme com oscilação pesada
            "upper_arm.L": [
                ((1, 0, 0), 24.0 - 12.0 * stride_wave),
                ((0, 1, 0), -14.0),
                ((0, 0, 1), 16.0),
            ],
            "forearm.L": [
                ((1, 0, 0), 48.0 + 6.0 * stride_wave),
                ((0, 0, 1), 22.0),
            ],
            "hand.L": [((1, 0, 0), -6.0)],
            # Braço da arma (R) balança em oposição à perna direita com peso de ferro
            "upper_arm.R": [
                ((1, 0, 0), -6.0 + 22.0 * stride_wave),
                ((0, 1, 0), 14.0),
                ((0, 0, 1), -10.0),
            ],
            "forearm.R": [
                ((1, 0, 0), 38.0 + 10.0 * stride_wave),
                ((0, 0, 1), -8.0),
            ],
            "hand.R": [((1, 0, 0), -12.0 + 6.0 * stride_wave)],
            "thigh.L": [((1, 0, 0), tl)],
            "shin.L": [((1, 0, 0), sl)],
            "foot.L": [((1, 0, 0), fl)],
            "thigh.R": [((1, 0, 0), tr)],
            "shin.R": [((1, 0, 0), sr)],
            "foot.R": [((1, 0, 0), fr)],
        }
        scene.frame_set(f)
        build_pose(arm, pose, (0.0, 0.0, bounce))
        key_all_bones(arm, f)

    # ===============================================================
    # 3. ATTACK (21 frames = 0.83s @ 24 FPS) — Golpe Brutal de Cutelo / Machado
    # ===============================================================
    attack = bpy.data.actions.new(name=ATTACK_NAME)
    attack.use_fake_user = True
    arm.animation_data.action = attack

    total_atk = 21
    for f in range(1, total_atk + 1):
        if f <= 7:
            # Windup: gira o tronco para a direita e ergue a lâmina acima da cabeça
            t = smoothstep((f - 1) / 6.0)
            spine_x = -8.0 + (10.0 - (-8.0)) * t
            spine_z = 10.0 + (-28.0 - 10.0) * t
            arm_r_x = -10.0 + (118.0 - (-10.0)) * t
            arm_r_y = 14.0 + (26.0 - 14.0) * t
            arm_r_z = -12.0 + (-24.0 - (-12.0)) * t
            fore_r_x = 42.0 + (34.0 - 42.0) * t
            hand_r_x = -10.0 + (18.0 - (-10.0)) * t
            arm_l_x = 28.0 + (10.0 - 28.0) * t
            hip_z = -0.04 * t
        elif f <= 12:
            # Slash / Cleave: desce a arma rasgando o ar à frente com rotação de tronco!
            t = smoothstep((f - 7) / 5.0)
            spine_x = 10.0 + (-22.0 - 10.0) * t
            spine_z = -28.0 + (32.0 - (-28.0)) * t
            arm_r_x = 118.0 + (16.0 - 118.0) * t
            arm_r_y = 26.0 + (-12.0 - 26.0) * t
            arm_r_z = -24.0 + (28.0 - (-24.0)) * t
            fore_r_x = 34.0 + (12.0 - 34.0) * t
            hand_r_x = 18.0 + (-32.0 - 18.0) * t
            arm_l_x = 10.0 + (36.0 - 10.0) * t
            hip_z = -0.04 + (-0.09 - (-0.04)) * t
        else:
            # Recovery: retorna à guarda de combate
            t = smoothstep((f - 12) / 9.0)
            spine_x = -22.0 + (-8.0 - (-22.0)) * t
            spine_z = 32.0 + (10.0 - 32.0) * t
            arm_r_x = 16.0 + (-10.0 - 16.0) * t
            arm_r_y = -12.0 + (14.0 - (-12.0)) * t
            arm_r_z = 28.0 + (-12.0 - 28.0) * t
            fore_r_x = 12.0 + (42.0 - 12.0) * t
            hand_r_x = -32.0 + (-10.0 - (-32.0)) * t
            arm_l_x = 36.0 + (28.0 - 36.0) * t
            hip_z = -0.09 * (1.0 - t)

        pose = {
            "hips": [((0, 0, 1), spine_z * 0.35)],
            "spine": [((1, 0, 0), spine_x), ((0, 0, 1), spine_z)],
            "neck": [((1, 0, 0), -spine_x * 0.35)],
            "head": [((1, 0, 0), -spine_x * 0.45), ((0, 0, 1), -spine_z * 0.55)],
            "upper_arm.L": [((1, 0, 0), arm_l_x), ((0, 1, 0), -14.0), ((0, 0, 1), 18.0)],
            "forearm.L": [((1, 0, 0), 52.0), ((0, 0, 1), 24.0)],
            "hand.L": [((1, 0, 0), -6.0)],
            "upper_arm.R": [((1, 0, 0), arm_r_x), ((0, 1, 0), arm_r_y), ((0, 0, 1), arm_r_z)],
            "forearm.R": [((1, 0, 0), fore_r_x), ((0, 0, 1), -10.0)],
            "hand.R": [((1, 0, 0), hand_r_x)],
            "thigh.L": [((1, 0, 0), 14.0), ((0, 0, 1), 6.0)],
            "shin.L": [((1, 0, 0), -18.0)],
            "foot.L": [((1, 0, 0), 4.0)],
            "thigh.R": [((1, 0, 0), -14.0), ((0, 0, 1), -6.0)],
            "shin.R": [((1, 0, 0), -14.0)],
            "foot.R": [((1, 0, 0), 22.0)],
        }
        scene.frame_set(f)
        build_pose(arm, pose, (0.0, 0.0, hip_z))
        key_all_bones(arm, f)

    # Trilhas NLA e Actions começando no frame 1 para exportação GLB limpa (1.0s exato no walk!)
    anim = arm.animation_data
    for trk in list(anim.nla_tracks):
        anim.nla_tracks.remove(trk)
    anim.action = None
    for action in (idle, walk, attack):
        track = anim.nla_tracks.new()
        track.name = action.name
        strip = track.strips.new(action.name, 1, action)
        if hasattr(strip, 'action_slot') and hasattr(action, 'slots') and len(action.slots) > 0:
            strip.action_slot = action.slots[0]
        track.mute = True
    anim.action = idle

    scene.frame_set(1)
    return [IDLE_NAME, WALK_NAME, ATTACK_NAME]


def export_gltf(root, arm, output):
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
    )
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
    exporter_props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    for k, v in opts.items():
        if k in exporter_props:
            kwargs[k] = v
    bpy.ops.export_scene.gltf(**kwargs)


def generate_and_export_variant(script_dir, is_boss=False):
    model_script = script_dir / "CRIAR_ESQUELETO_DARKFANTASY_V013.py"
    namespace = {"__name__": "__ imported__", "__file__": str(model_script)}
    exec(compile(model_script.read_text(encoding="utf-8"), str(model_script), "exec"), namespace)
    root = namespace["build_skeleton_model"](is_boss=is_boss)

    project = script_dir.parent.parent
    glb_name = 'skeleton_boss.glb' if is_boss else 'skeleton_enemy.glb'
    blend_name = 'Esqueleto_Boss_v016_RIG.blend' if is_boss else 'Esqueleto_Inimigo_v016_RIG.blend'
    output_glb = project / 'assets' / 'models' / glb_name
    output_blend = project / 'assets' / 'blender' / blend_name
    output_glb.parent.mkdir(parents=True, exist_ok=True)

    arm = make_bones(root)
    bpy.context.view_layer.update()
    bound_count = bind_model(root, arm)
    clips = make_animations(arm)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_blend))
    export_gltf(root, arm, output_glb)
    print(f"=== Skeleton v0.16 ({'BOSS' if is_boss else 'WARRIOR'}) ===")
    print("Ossos:", len(arm.data.bones), "| Pecas rigadas:", bound_count)
    print("Clipes:", clips)
    print("BLEND:", output_blend)
    print("GLB:", output_glb)


def main():
    script_dir = get_script_dir()
    generate_and_export_variant(script_dir, is_boss=False)
    generate_and_export_variant(script_dir, is_boss=True)


if __name__ == '__main__':
    main()
