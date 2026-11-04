# ==============================================================================
# BLENDER 4.x / 5.x PYTHON SCRIPT — SCULPTED DARK-FANTASY SHADOW WOLF (V2)
# Inspirado em Diablo 2 / Path of Exile 2 / Grim Dawn (Hound of the Abyss)
# ==============================================================================
# Sem caixas tipo Roblox! Toda a anatomia usa Ring Lofts orgânicos (add_loft),
# tubos anatômicos cônicos para os membros, juntas esféricas, crina dorsal de
# espinhos sombrios, olhos carmesim luminescentes, presas e garras de osso.
# Orientação canônica: Frente = +Y, Cima = +Z (exporta para -Z no Godot).
# ==============================================================================

import bpy
import bmesh
import math
from mathutils import Vector, Matrix


def clear_scene():
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for block in bpy.data.meshes:
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in bpy.data.materials:
        if block.users == 0:
            bpy.data.materials.remove(block)


def make_material(name, color, roughness=0.88, metallic=0.0, emission=None, emission_strength=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emission:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
            elif "Emission" in bsdf.inputs:
                bsdf.inputs["Emission"].default_value = (*emission, 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def finalize_mesh(obj, mat, parent=None):
    mesh = obj.data
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    mesh.materials.clear()
    mesh.materials.append(mat)
    if parent is not None:
        obj.parent = parent
    return obj


def add_loft(name, sections, mat, parent=None, segs=10, cap_start=True, cap_end=True, rot_offset=0.0):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()

    rings = []
    for sec in sections:
        cx, cy, cz, rx, rz = sec[0], sec[1], sec[2], sec[3], sec[4]
        pitch_deg = sec[5] if len(sec) > 5 else 0.0
        rot_mat = Matrix.Rotation(math.radians(pitch_deg), 3, 'X')
        center = Vector((cx, cy, cz))
        ring = []
        for i in range(segs):
            ang = (2.0 * math.pi * i / segs) + rot_offset
            local_pt = Vector((math.cos(ang) * rx, 0.0, math.sin(ang) * rz))
            world_pt = center + (rot_mat @ local_pt)
            ring.append(bm.verts.new(world_pt))
        rings.append(ring)

    for r_idx in range(len(rings) - 1):
        r0 = rings[r_idx]
        r1 = rings[r_idx + 1]
        for i in range(segs):
            ni = (i + 1) % segs
            bm.faces.new((r0[i], r0[ni], r1[ni], r1[i]))

    if cap_start and len(rings) > 0:
        bm.faces.new(list(reversed(rings[0])))
    if cap_end and len(rings) > 0:
        bm.faces.new(rings[-1])

    bm.to_mesh(mesh)
    bm.free()
    return finalize_mesh(obj, mat, parent)


def add_limb_tube(name, p_start, p_end, r_start, r_end, mat, parent=None, segs=8, mid_bulge=1.08, mid_offset=(0.0, 0.0, 0.0)):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()

    v0 = Vector(p_start)
    v1 = Vector(p_end)
    axis = (v1 - v0)
    tangent = axis.normalized()

    ref = Vector((0.0, 1.0, 0.0)) if abs(tangent.y) < 0.9 else Vector((1.0, 0.0, 0.0))
    binormal = tangent.cross(ref).normalized()
    normal = binormal.cross(tangent).normalized()

    steps = [
        (0.0, r_start * 0.96, Vector((0, 0, 0))),
        (0.38, (r_start * 0.65 + r_end * 0.35) * mid_bulge, Vector(mid_offset)),
        (0.75, (r_start * 0.25 + r_end * 0.75) * 0.98, Vector(mid_offset) * 0.4),
        (1.0, r_end, Vector((0, 0, 0))),
    ]

    rings = []
    for t, rad, offset in steps:
        center = v0.lerp(v1, t) + offset
        ring = []
        for i in range(segs):
            ang = 2.0 * math.pi * i / segs
            px = math.cos(ang) * rad * 0.88
            py = math.sin(ang) * rad * 1.12
            pt = center + binormal * px + normal * py
            ring.append(bm.verts.new(pt))
        rings.append(ring)

    for r_idx in range(len(rings) - 1):
        r0, r1 = rings[r_idx], rings[r_idx + 1]
        for i in range(segs):
            ni = (i + 1) % segs
            bm.faces.new((r0[i], r0[ni], r1[ni], r1[i]))

    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])

    bm.to_mesh(mesh)
    bm.free()
    return finalize_mesh(obj, mat, parent)


def add_ico_joint(name, location, scale_xyz, mat, parent=None, subdivisions=1):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdivisions, radius=1.0)
    for v in bm.verts:
        v.co.x *= scale_xyz[0]
        v.co.y *= scale_xyz[1]
        v.co.z *= scale_xyz[2]
        v.co += Vector(location)
    bm.to_mesh(mesh)
    bm.free()
    return finalize_mesh(obj, mat, parent)


def add_cone_spike(name, base_pos, tip_pos, rx, ry, mat, parent=None, segs=6):
    mesh = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    bm = bmesh.new()

    v_base = Vector(base_pos)
    v_tip = Vector(tip_pos)
    axis = (v_tip - v_base)
    tangent = axis.normalized()
    ref = Vector((0.0, 1.0, 0.0)) if abs(tangent.y) < 0.9 else Vector((1.0, 0.0, 0.0))
    b1 = tangent.cross(ref).normalized()
    b2 = b1.cross(tangent).normalized()

    ring_base = []
    ring_mid = []
    v_mid = v_base.lerp(v_tip, 0.55)
    for i in range(segs):
        ang = 2.0 * math.pi * i / segs
        p0 = v_base + b1 * (math.cos(ang) * rx) + b2 * (math.sin(ang) * ry)
        pm = v_mid + b1 * (math.cos(ang) * rx * 0.52) + b2 * (math.sin(ang) * ry * 0.52)
        ring_base.append(bm.verts.new(p0))
        ring_mid.append(bm.verts.new(pm))
    tip_v = bm.verts.new(v_tip)

    for i in range(segs):
        ni = (i + 1) % segs
        bm.faces.new((ring_base[i], ring_base[ni], ring_mid[ni], ring_mid[i]))
        bm.faces.new((ring_mid[i], ring_mid[ni], tip_v))
    bm.faces.new(list(reversed(ring_base)))

    bm.to_mesh(mesh)
    bm.free()
    return finalize_mesh(obj, mat, parent)


def join_into_named(name, objs, parent):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    res = bpy.context.active_object
    res.name = name
    res.data.name = name + "_Mesh"
    res.parent = parent
    return res


def build_wolf():
    clear_scene()

    # Objeto Raiz Empty "Wolf" em escala 1:1 (compatível com GERAR_E_EXPORTAR_LOBO.py)
    root = bpy.data.objects.new("Wolf", None)
    bpy.context.collection.objects.link(root)
    root.location = (0.0, 0.0, 0.0)

    # Paleta Dark-Fantasy (Grim Dawn / Path of Exile 2 Dire Wolf)
    mat_dark_fur = make_material("Wolf_Fur_Dark", (0.11, 0.12, 0.15), roughness=0.90)
    mat_mid_fur = make_material("Wolf_Fur_Mid", (0.19, 0.21, 0.26), roughness=0.88)
    mat_under_fur = make_material("Wolf_Fur_Under", (0.31, 0.32, 0.36), roughness=0.86)
    mat_mane = make_material("Wolf_Shadow_Mane", (0.06, 0.06, 0.08), roughness=0.92)
    mat_bone = make_material("Wolf_Bone_Claw", (0.76, 0.71, 0.60), roughness=0.65)
    mat_nose = make_material("Wolf_Nose", (0.04, 0.04, 0.05), roughness=0.45)
    mat_scar = make_material("Wolf_Crimson_Scar", (0.42, 0.08, 0.09), roughness=0.75)
    mat_eye = make_material(
        "Wolf_Eye_Glow",
        (1.0, 0.16, 0.12),
        roughness=0.20,
        emission=(1.0, 0.14, 0.10),
        emission_strength=3.6,
    )

    # 1. QUADRIL E CINTURA (vinculados ao osso 'hips')
    add_loft(
        "Hips",
        [
            (0.0, -0.58, 0.56, 0.11, 0.11, -12.0),
            (0.0, -0.44, 0.58, 0.19, 0.17, -6.0),
            (0.0, -0.25, 0.56, 0.165, 0.155, -2.0),
        ],
        mat_mid_fur,
        parent=root,
        segs=10,
    )
    waist_parts = [
        add_loft(
            "Waist_Core",
            [
                (0.0, -0.28, 0.56, 0.16, 0.15, -2.0),
                (0.0, -0.14, 0.57, 0.17, 0.16, 2.0),
                (0.0, -0.02, 0.58, 0.21, 0.20, 4.0),
            ],
            mat_mid_fur,
            parent=root,
            segs=10,
        ),
        add_cone_spike("Spine_Rear_1", (0.0, -0.12, 0.72), (0.0, -0.26, 0.83), 0.032, 0.042, mat_mane, parent=root),
        add_cone_spike("Spine_Rear_2", (0.0, -0.30, 0.69), (0.0, -0.44, 0.78), 0.028, 0.036, mat_mane, parent=root),
    ]
    join_into_named("Waist", waist_parts, root)

    # 2. CAIXA TORÁCICA, VENTRE E JUBA DORSAL (vinculados ao osso 'spine')
    add_loft(
        "Chest",
        [
            (0.0, -0.06, 0.58, 0.21, 0.20, 4.0),
            (0.0,  0.14, 0.60, 0.265, 0.255, 7.0),
            (0.0,  0.32, 0.63, 0.25, 0.24, 12.0),
            (0.0,  0.42, 0.66, 0.19, 0.19, 16.0),
        ],
        mat_mid_fur,
        parent=root,
        segs=10,
    )
    add_loft(
        "Underbelly",
        [
            (0.0, -0.36, 0.44, 0.11, 0.055, -4.0),
            (0.0, -0.12, 0.43, 0.12, 0.06, 0.0),
            (0.0,  0.14, 0.40, 0.175, 0.08, 5.0),
            (0.0,  0.34, 0.45, 0.14, 0.07, 14.0),
        ],
        mat_under_fur,
        parent=root,
        segs=8,
    )
    mane_mid_parts = [
        add_loft(
            "Mane_Mantle",
            [
                (0.0, -0.06, 0.75, 0.15, 0.08, -8.0),
                (0.0,  0.14, 0.81, 0.25, 0.13, 0.0),
                (0.0,  0.32, 0.84, 0.24, 0.14, 12.0),
            ],
            mat_dark_fur,
            parent=root,
            segs=8,
        ),
        add_cone_spike("Mane_Tuft_L1", (-0.21, 0.22, 0.72), (-0.33, 0.06, 0.78), 0.065, 0.085, mat_dark_fur, parent=root),
        add_cone_spike("Mane_Tuft_R1", ( 0.21, 0.22, 0.72), ( 0.33, 0.06, 0.78), 0.065, 0.085, mat_dark_fur, parent=root),
    ]
    join_into_named("Mane_Mid", mane_mid_parts, root)

    mane_spikes_parts = [
        add_cone_spike("Dorsal_Spine_1", (0.0, 0.36, 0.84), (0.0, 0.20, 0.98), 0.042, 0.055, mat_mane, parent=root),
        add_cone_spike("Dorsal_Spine_2", (0.0, 0.20, 0.82), (0.0, 0.04, 0.96), 0.045, 0.060, mat_mane, parent=root),
        add_cone_spike("Dorsal_Spine_3", (0.0, 0.04, 0.78), (0.0, -0.10, 0.90), 0.038, 0.050, mat_mane, parent=root),
    ]
    join_into_named("Mane_Spikes_Front", mane_spikes_parts, root)

    # 3. PESCOÇO E CABEÇA ESCULPIDA (vinculados a 'neck', 'head' e 'jaw')
    neck_parts = [
        add_loft(
            "Neck_Core",
            [
                (0.0, 0.34, 0.64, 0.21, 0.20, 14.0),
                (0.0, 0.46, 0.71, 0.175, 0.17, 22.0),
                (0.0, 0.54, 0.76, 0.15, 0.145, 26.0),
            ],
            mat_dark_fur,
            parent=root,
            segs=8,
        ),
        add_cone_spike("Neck_Tuft_L", (-0.18, 0.42, 0.75), (-0.29, 0.26, 0.83), 0.055, 0.075, mat_dark_fur, parent=root),
        add_cone_spike("Neck_Tuft_R", ( 0.18, 0.42, 0.75), ( 0.29, 0.26, 0.83), 0.055, 0.075, mat_dark_fur, parent=root),
    ]
    join_into_named("Neck", neck_parts, root)

    add_loft(
        "Head",
        [
            (0.0, 0.47, 0.76, 0.155, 0.135, 10.0),
            (0.0, 0.57, 0.78, 0.175, 0.148, 6.0),
            (0.0, 0.67, 0.76, 0.135, 0.118, 4.0),
        ],
        mat_mid_fur,
        parent=root,
        segs=8,
    )
    add_loft(
        "Muzzle_Upper",
        [
            (0.0, 0.65, 0.75, 0.125, 0.105, 4.0),
            (0.0, 0.79, 0.72, 0.088, 0.078, 2.0),
            (0.0, 0.92, 0.70, 0.062, 0.058, 0.0),
        ],
        mat_mid_fur,
        parent=root,
        segs=8,
    )
    add_ico_joint("Nose", (0.0, 0.94, 0.715), (0.044, 0.038, 0.034), mat_nose, parent=root, subdivisions=1)

    brow_parts = [
        add_cone_spike("Brow_L", (-0.05, 0.68, 0.81), (-0.15, 0.60, 0.84), 0.035, 0.028, mat_dark_fur, parent=root),
        add_cone_spike("Brow_R", ( 0.05, 0.68, 0.81), ( 0.15, 0.60, 0.84), 0.035, 0.028, mat_dark_fur, parent=root),
    ]
    join_into_named("Brow_Ridge", brow_parts, root)

    for side, sx in (("L", -1.0), ("R", 1.0)):
        add_ico_joint(f"Eye_{side}", (sx * 0.105, 0.675, 0.775), (0.026, 0.032, 0.022), mat_eye, parent=root, subdivisions=1)
        add_cone_spike(f"Ear_{side}", (sx * 0.12, 0.51, 0.84), (sx * 0.18, 0.37, 1.05), 0.055, 0.042, mat_dark_fur, parent=root)
        add_cone_spike(f"Ear_Inner_{side}", (sx * 0.125, 0.525, 0.85), (sx * 0.17, 0.40, 1.01), 0.030, 0.022, mat_scar, parent=root, segs=5)
        add_cone_spike(f"Fang_Upper_{side}", (sx * 0.048, 0.84, 0.69), (sx * 0.044, 0.85, 0.620), 0.015, 0.015, mat_bone, parent=root, segs=5)

    # Mandíbula articulada ('jaw')
    add_loft(
        "Jaw_Mesh",
        [
            (0.0, 0.55, 0.67, 0.115, 0.058, -8.0),
            (0.0, 0.69, 0.64, 0.085, 0.048, -6.0),
            (0.0, 0.86, 0.63, 0.052, 0.036, -4.0),
        ],
        mat_under_fur,
        parent=root,
        segs=8,
    )
    for side, sx in (("L", -1.0), ("R", 1.0)):
        add_cone_spike(f"Fang_Lower_{side}", (sx * 0.038, 0.81, 0.64), (sx * 0.036, 0.82, 0.695), 0.013, 0.013, mat_bone, parent=root, segs=5)

    # 4. CAUDA ARTICULADA EM 3 SEGMENTOS ('tail_1', 'tail_2', 'tail_3')
    add_loft(
        "Tail_Base",
        [
            (0.0, -0.55, 0.58, 0.075, 0.075, -16.0),
            (0.0, -0.66, 0.54, 0.090, 0.086, -24.0),
            (0.0, -0.76, 0.48, 0.098, 0.092, -26.0),
        ],
        mat_dark_fur,
        parent=root,
        segs=8,
    )
    add_loft(
        "Tail_Mid",
        [
            (0.0, -0.74, 0.49, 0.095, 0.090, -26.0),
            (0.0, -0.86, 0.42, 0.104, 0.094, -22.0),
            (0.0, -0.96, 0.37, 0.082, 0.076, -14.0),
        ],
        mat_dark_fur,
        parent=root,
        segs=8,
    )
    add_loft(
        "Tail_Tip",
        [
            (0.0, -0.94, 0.38, 0.080, 0.074, -14.0),
            (0.0, -1.04, 0.34, 0.055, 0.050, -6.0),
            (0.0, -1.14, 0.32, 0.018, 0.018, 0.0),
        ],
        mat_mane,
        parent=root,
        segs=8,
    )

    # 5. PERNAS DIANTEIRAS E TRASEIRAS ANATÔMICAS
    for side, sx in (("L", -1.0), ("R", 1.0)):
        p_shoulder = (sx * 0.21, 0.27, 0.56)
        p_elbow    = (sx * 0.20, 0.21, 0.33)
        p_wrist    = (sx * 0.19, 0.26, 0.10)

        add_ico_joint(f"Front_Shoulder_{side}", (sx * 0.22, 0.27, 0.58), (0.085, 0.11, 0.12), mat_dark_fur, parent=root)

        upper_parts = [
            add_limb_tube(
                f"Front_UpperTube_{side}",
                p_shoulder, p_elbow,
                0.082, 0.058, mat_mid_fur, parent=root, segs=8, mid_bulge=1.12, mid_offset=(sx * 0.01, -0.015, 0.0)
            ),
            add_ico_joint(f"Front_Elbow_{side}", p_elbow, (0.055, 0.062, 0.055), mat_dark_fur, parent=root),
        ]
        join_into_named(f"Front_Upper_{side}", upper_parts, root)

        add_limb_tube(
            f"Front_Shin_{side}",
            p_elbow, p_wrist,
            0.056, 0.042, mat_dark_fur, parent=root, segs=8, mid_bulge=1.05
        )
        add_loft(
            f"Front_Paw_{side}",
            [
                (sx * 0.19, 0.23, 0.055, 0.050, 0.042, 0.0),
                (sx * 0.19, 0.31, 0.045, 0.062, 0.040, 0.0),
                (sx * 0.19, 0.37, 0.026, 0.048, 0.025, 0.0),
            ],
            mat_dark_fur,
            parent=root,
            segs=8,
        )
        f_claws = []
        for c_idx, cx_off in enumerate((-0.026, 0.0, 0.026)):
            f_claws.append(
                add_cone_spike(
                    f"FClaw_{side}_{c_idx}",
                    (sx * 0.19 + cx_off, 0.36, 0.030),
                    (sx * 0.19 + cx_off * 1.1, 0.425, 0.010),
                    0.012, 0.010, mat_bone, parent=root, segs=5
                )
            )
        join_into_named(f"Front_Claws_{side}", f_claws, root)

        # Perna Traseira Digitígrada
        p_hip    = (sx * 0.18, -0.40, 0.55)
        p_stifle = (sx * 0.19, -0.31, 0.34)
        p_hock   = (sx * 0.18, -0.46, 0.18)

        thigh_parts = [
            add_ico_joint(f"Back_Haunch_{side}", (sx * 0.19, -0.40, 0.56), (0.095, 0.13, 0.13), mat_mid_fur, parent=root),
            add_limb_tube(
                f"Back_ThighTube_{side}",
                p_hip, p_stifle,
                0.095, 0.062, mat_mid_fur, parent=root, segs=8, mid_bulge=1.16, mid_offset=(sx * 0.015, 0.02, 0.0)
            ),
            add_ico_joint(f"Back_Knee_{side}", p_stifle, (0.056, 0.062, 0.056), mat_dark_fur, parent=root),
        ]
        join_into_named(f"Back_Thigh_{side}", thigh_parts, root)

        shin_parts = [
            add_limb_tube(
                f"Back_ShinTube_{side}",
                p_stifle, p_hock,
                0.058, 0.044, mat_dark_fur, parent=root, segs=8, mid_bulge=1.06
            ),
            add_ico_joint(f"Back_Hock_{side}", p_hock, (0.044, 0.050, 0.044), mat_dark_fur, parent=root),
            add_limb_tube(
                f"Back_Meta_{side}",
                p_hock, (sx * 0.18, -0.39, 0.06),
                0.042, 0.038, mat_dark_fur, parent=root, segs=8, mid_bulge=1.02
            ),
        ]
        join_into_named(f"Back_Shin_{side}", shin_parts, root)

        add_loft(
            f"Back_Paw_{side}",
            [
                (sx * 0.18, -0.43, 0.052, 0.048, 0.040, 0.0),
                (sx * 0.18, -0.35, 0.042, 0.058, 0.038, 0.0),
                (sx * 0.18, -0.29, 0.025, 0.044, 0.024, 0.0),
            ],
            mat_dark_fur,
            parent=root,
            segs=8,
        )
        b_claws = []
        for c_idx, cx_off in enumerate((-0.024, 0.0, 0.024)):
            b_claws.append(
                add_cone_spike(
                    f"BClaw_{side}_{c_idx}",
                    (sx * 0.18 + cx_off, -0.30, 0.028),
                    (sx * 0.18 + cx_off * 1.1, -0.24, 0.010),
                    0.011, 0.009, mat_bone, parent=root, segs=5
                )
            )
        join_into_named(f"Back_Claws_{side}", b_claws, root)

    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    bpy.context.view_layer.objects.active = root
    mesh_count = sum(1 for o in bpy.data.objects if o.type == 'MESH' and o.parent == root)
    print(f"[OK] Lobo das Sombras Dark-Fantasy V2 gerado com {mesh_count} pecas esculpidas.")
    return root


if __name__ == "__main__":
    build_wolf()
