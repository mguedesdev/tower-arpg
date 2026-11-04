"""==============================================================================
GERADOR DE BOSS PARA O MAPA 3: MALAKOR, O CARRASCO DA CRIPTA
Inspirado em Dark Fantasy (Diablo 2, Dark Souls, Path of Exile, Elden Ring)
==============================================================================
Anatomia Temática Completa:
- Crânio Humanoide-Bestial com 4 Chifres de Ônix em arco demoníaco
- Caixa Torácica Aberta com Núcleo de Alma Aprisionada pulsando em Carmesim (Emission)
- Ombreiras monumentais pontiagudas de osso negro e ferro forjado
- Braço Esquerdo com Garra Bestial de 4 dedos (herança do lobo e fera sombria)
- Braço Direito empunhando o Cutelo Colossal de Carrasco (Executioner's Greatcleaver)
- Pernas pesadas blindadas com grevas pontiagudas
- Rig completo de 22 ossos
- 4 Animações completas em loops perfeitos:
    1. idle-loop   (48 frames = 2.0s @ 24fps)
    2. walk-loop   (24 frames = 1.0s @ 24fps)
    3. attack      (24 frames = 1.0s @ 24fps) - Clássico Golpe Descendente
    4. attack_sweep(24 frames = 1.0s @ 24fps) - Varredura Horizontal em Arco 180°
==============================================================================
"""

import bpy
import bmesh
import math
from math import cos, sin, pi, radians, sqrt
from mathutils import Vector, Matrix, Euler
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
OUTPUT_GLB = PROJECT_ROOT / "assets" / "models" / "boss_malakor.glb"
OUTPUT_BLEND = PROJECT_ROOT / "assets" / "blender" / "Boss_Malakor_v1_RIG.blend"

ROOT_NAME = "BossMalakor"
RIG_NAME = "BossMalakor_Rig"
FPS = 24


def clear_scene():
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in list(bpy.data.meshes):
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        if block.users == 0:
            bpy.data.materials.remove(block)
    for block in list(bpy.data.actions):
        if block.users == 0:
            bpy.data.actions.remove(block)
    for block in list(bpy.data.armatures):
        if block.users == 0:
            bpy.data.armatures.remove(block)


def make_material(name, color, roughness=0.75, metallic=0.0, emit_color=None, emit_power=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name=name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emit_color and emit_power > 0.0:
            if "Emission Color" in bsdf.inputs:
                bsdf.inputs["Emission Color"].default_value = (*emit_color, 1.0)
            elif "Emission" in bsdf.inputs:
                bsdf.inputs["Emission"].default_value = (*emit_color, 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emit_power
    mat.diffuse_color = (*color, 1.0)
    return mat


def _finalize_mesh_obj(parent, name, verts, faces, material):
    mesh = bpy.data.meshes.new(name + "_Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    for poly in mesh.polygons:
        poly.use_smooth = False
    mesh.materials.clear()
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    return obj


def add_loft(parent, name, rings, segments, material, phase_offset=0.0):
    """Cria uma malha facetada a partir de anéis (cx, cy, z, rx, ry)."""
    verts = []
    for cx, cy, z, rx, ry in rings:
        for i in range(segments):
            ang = 2.0 * pi * i / segments + phase_offset
            verts.append((cx + rx * cos(ang), cy + ry * sin(ang), z))
    faces = [tuple(reversed(range(segments)))]
    for r in range(len(rings) - 1):
        base = r * segments
        nxt = (r + 1) * segments
        for i in range(segments):
            j = (i + 1) % segments
            faces.append((base + i, base + j, nxt + j, nxt + i))
    top_base = (len(rings) - 1) * segments
    faces.append(tuple(top_base + i for i in range(segments)))
    return _finalize_mesh_obj(parent, name, verts, faces, material)


def add_tube_along_curve(parent, name, points, radii_xy, segments, material):
    """Tubo anatômico curvado low-poly."""
    pts = [Vector(p) for p in points]
    verts = []
    for i, center in enumerate(pts):
        tangent = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        if tangent.length_squared < 0.0001:
            tangent = Vector((0.0, 0.0, 1.0))
        ref = Vector((0.0, 1.0, 0.0)) if abs(tangent.y) < 0.85 else Vector((1.0, 0.0, 0.0))
        axis_u = tangent.cross(ref).normalized()
        axis_v = tangent.cross(axis_u).normalized()
        rx, ry = radii_xy[i]
        for s in range(segments):
            ang = 2.0 * pi * s / segments
            offset = axis_u * (rx * cos(ang)) + axis_v * (ry * sin(ang))
            verts.append(tuple(center + offset))
    faces = [tuple(reversed(range(segments)))]
    for r in range(len(pts) - 1):
        b0 = r * segments
        b1 = (r + 1) * segments
        for s in range(segments):
            sn = (s + 1) % segments
            faces.append((b0 + s, b0 + sn, b1 + sn, b1 + s))
    last = (len(pts) - 1) * segments
    faces.append(tuple(last + s for s in range(segments)))
    return _finalize_mesh_obj(parent, name, verts, faces, material)


def add_box(parent, name, center, size, material):
    """Cria paralelepípedo low-poly simples e nítido."""
    cx, cy, cz = center
    hx, hy, hz = size[0] * 0.5, size[1] * 0.5, size[2] * 0.5
    verts = [
        (cx - hx, cy - hy, cz - hz),
        (cx + hx, cy - hy, cz - hz),
        (cx + hx, cy + hy, cz - hz),
        (cx - hx, cy + hy, cz - hz),
        (cx - hx, cy - hy, cz + hz),
        (cx + hx, cy - hy, cz + hz),
        (cx + hx, cy + hy, cz + hz),
        (cx - hx, cy + hy, cz + hz),
    ]
    faces = [
        (0, 1, 2, 3), # Base inferior
        (7, 6, 5, 4), # Topo
        (0, 4, 5, 1), # Frente
        (1, 5, 6, 2), # Direita
        (2, 6, 7, 3), # Trás
        (3, 7, 4, 0), # Esquerda
    ]
    return _finalize_mesh_obj(parent, name, verts, faces, material)


def add_ico_sphere(parent, name, location, radius, material, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=radius, location=location)
    obj = bpy.context.active_object
    obj.name = name
    for poly in obj.data.polygons:
        poly.use_smooth = False
    obj.data.materials.clear()
    obj.data.materials.append(material)
    obj.parent = parent
    return obj


# ==============================================================================
# CONSTRUÇÃO DO CORPO DE MALAKOR
# ==============================================================================
PARTS_TO_BONES = {}

def build_malakor_meshes(root):
    # Paleta de Cores Dark Fantasy
    mat_bone = make_material("Mat_Malakor_Bone", (0.75, 0.70, 0.62), roughness=0.72)
    mat_dark_iron = make_material("Mat_Malakor_DarkIron", (0.16, 0.16, 0.20), roughness=0.45, metallic=0.78)
    mat_horn = make_material("Mat_Malakor_Horn", (0.07, 0.07, 0.09), roughness=0.35, metallic=0.15)
    mat_core = make_material("Mat_Malakor_SoulCore", (0.95, 0.12, 0.15), roughness=0.20, emit_color=(1.0, 0.10, 0.15), emit_power=5.5)
    mat_eyes = make_material("Mat_Malakor_EyeFlame", (1.0, 0.35, 0.05), roughness=0.15, emit_color=(1.0, 0.40, 0.08), emit_power=6.5)
    mat_steel = make_material("Mat_Malakor_BladeSteel", (0.60, 0.64, 0.70), roughness=0.25, metallic=0.88)
    mat_cloth = make_material("Mat_Malakor_Shroud", (0.11, 0.09, 0.13), roughness=0.92)

    # ---------------- 1. QUADRIL & CINTURA (hips) ----------------
    hips_rings = [
        (0.0, 0.0, 1.15, 0.36, 0.28),
        (0.0, 0.02, 1.30, 0.42, 0.32),
        (0.0, 0.02, 1.45, 0.38, 0.29),
    ]
    add_loft(root, "Hips_Mesh", hips_rings, 8, mat_dark_iron)
    PARTS_TO_BONES["Hips_Mesh"] = "hips"

    # Faixa frontal de carrasco (Loincloth)
    add_box(root, "Loincloth_Front", (0.0, 0.26, 1.05), (0.34, 0.04, 0.50), mat_cloth)
    PARTS_TO_BONES["Loincloth_Front"] = "hips"

    # ---------------- 2. COLUNA & TÓRAX (spine / chest) ----------------
    spine_rings = [
        (0.0, 0.02, 1.45, 0.36, 0.27),
        (0.0, 0.04, 1.62, 0.40, 0.30),
        (0.0, 0.05, 1.80, 0.45, 0.34),
    ]
    add_loft(root, "Spine_Mesh", spine_rings, 8, mat_bone)
    PARTS_TO_BONES["Spine_Mesh"] = "spine"

    # Espigões na coluna lombar
    for idx, z in enumerate([1.50, 1.62, 1.74]):
        sp_name = f"Spine_Spike_{idx}"
        add_box(root, sp_name, (0.0, -0.26, z), (0.08, 0.20, 0.08), mat_bone)
        PARTS_TO_BONES[sp_name] = "spine"

    # Tórax aberto imponente
    chest_rings = [
        (0.0, 0.05, 1.80, 0.46, 0.35),
        (0.0, 0.07, 2.00, 0.58, 0.42),
        (0.0, 0.08, 2.22, 0.52, 0.38),
    ]
    add_loft(root, "Chest_Mesh", chest_rings, 8, mat_bone)
    PARTS_TO_BONES["Chest_Mesh"] = "chest"

    # Placas peitorais de ferro forjado
    add_box(root, "Chest_Plate_L", (0.24, 0.28, 2.05), (0.24, 0.12, 0.32), mat_dark_iron)
    add_box(root, "Chest_Plate_R", (-0.24, 0.28, 2.05), (0.24, 0.12, 0.32), mat_dark_iron)
    PARTS_TO_BONES["Chest_Plate_L"] = "chest"
    PARTS_TO_BONES["Chest_Plate_R"] = "chest"

    # Núcleo de Alma Aprisionada (Soul Core) no peito
    add_ico_sphere(root, "Soul_Core_Orb", (0.0, 0.24, 2.02), 0.15, mat_core, subdivisions=1)
    PARTS_TO_BONES["Soul_Core_Orb"] = "chest"

    # Costelas arqueadas cobrindo parcialmente a orbe
    for i, (cz, rx) in enumerate([(1.94, 0.32), (2.04, 0.34), (2.14, 0.30)]):
        r_name_l = f"Rib_L_{i}"
        r_name_r = f"Rib_R_{i}"
        add_box(root, r_name_l, (rx * 0.55, 0.29, cz), (0.22, 0.06, 0.05), mat_bone)
        add_box(root, r_name_r, (-rx * 0.55, 0.29, cz), (0.22, 0.06, 0.05), mat_bone)
        PARTS_TO_BONES[r_name_l] = "chest"
        PARTS_TO_BONES[r_name_r] = "chest"

    # Espigões das costas do tórax
    for idx, z in enumerate([1.90, 2.06, 2.20]):
        sp_name = f"Chest_Spike_{idx}"
        add_box(root, sp_name, (0.0, -0.34, z), (0.10, 0.28, 0.09), mat_bone)
        PARTS_TO_BONES[sp_name] = "chest"

    # ---------------- 3. PESCOÇO & CABEÇA (neck / head / jaw) ----------------
    neck_rings = [
        (0.0, 0.07, 2.20, 0.22, 0.20),
        (0.0, 0.10, 2.38, 0.19, 0.18),
    ]
    add_loft(root, "Neck_Mesh", neck_rings, 6, mat_bone)
    PARTS_TO_BONES["Neck_Mesh"] = "neck"

    # Crânio Demoníaco Titânico
    skull_rings = [
        (0.0, 0.12, 2.38, 0.22, 0.24),
        (0.0, 0.16, 2.52, 0.28, 0.30),
        (0.0, 0.18, 2.68, 0.26, 0.26),
        (0.0, 0.16, 2.76, 0.18, 0.18),
    ]
    add_loft(root, "Head_Skull", skull_rings, 8, mat_bone)
    PARTS_TO_BONES["Head_Skull"] = "head"

    # Arcada Superior / Sobrancelhas de Ossos
    add_box(root, "Brow_Ridge", (0.0, 0.38, 2.56), (0.34, 0.12, 0.08), mat_dark_iron)
    PARTS_TO_BONES["Brow_Ridge"] = "head"

    # Órbitas com Olhos em Chamas (Emission)
    add_ico_sphere(root, "Eye_L", (0.11, 0.40, 2.53), 0.05, mat_eyes, subdivisions=1)
    add_ico_sphere(root, "Eye_R", (-0.11, 0.40, 2.53), 0.05, mat_eyes, subdivisions=1)
    PARTS_TO_BONES["Eye_L"] = "head"
    PARTS_TO_BONES["Eye_R"] = "head"

    # Mandíbula com Presas de Fera (Jaw)
    add_box(root, "Jaw_Base", (0.0, 0.32, 2.42), (0.24, 0.22, 0.09), mat_bone)
    add_box(root, "Fang_L", (0.09, 0.38, 2.48), (0.04, 0.04, 0.10), mat_horn)
    add_box(root, "Fang_R", (-0.09, 0.38, 2.48), (0.04, 0.04, 0.10), mat_horn)
    PARTS_TO_BONES["Jaw_Base"] = "jaw"
    PARTS_TO_BONES["Fang_L"] = "jaw"
    PARTS_TO_BONES["Fang_R"] = "jaw"

    # 4 CHIFRES DE ÔNYX:
    # 2 Chifres Principais (Main Horns) curvando para cima, fora e para trás
    horn_pts_l = [
        (0.18, 0.16, 2.68),
        (0.32, 0.12, 2.88),
        (0.42, -0.04, 3.08),
        (0.40, -0.22, 3.22),
        (0.32, -0.34, 3.28),
    ]
    horn_rad_l = [(0.09, 0.09), (0.08, 0.08), (0.06, 0.06), (0.04, 0.04), (0.015, 0.015)]
    add_tube_along_curve(root, "Main_Horn_L", horn_pts_l, horn_rad_l, 6, mat_horn)
    PARTS_TO_BONES["Main_Horn_L"] = "head"

    horn_pts_r = [(-x, y, z) for x, y, z in horn_pts_l]
    add_tube_along_curve(root, "Main_Horn_R", horn_pts_r, horn_rad_l, 6, mat_horn)
    PARTS_TO_BONES["Main_Horn_R"] = "head"

    # 2 Chifres Secundários laterais pontiagudos
    sub_pts_l = [
        (0.24, 0.22, 2.58),
        (0.42, 0.26, 2.64),
        (0.55, 0.22, 2.70),
    ]
    sub_rad = [(0.06, 0.06), (0.04, 0.04), (0.015, 0.015)]
    add_tube_along_curve(root, "Sub_Horn_L", sub_pts_l, sub_rad, 5, mat_horn)
    PARTS_TO_BONES["Sub_Horn_L"] = "head"

    sub_pts_r = [(-x, y, z) for x, y, z in sub_pts_l]
    add_tube_along_curve(root, "Sub_Horn_R", sub_pts_r, sub_rad, 5, mat_horn)
    PARTS_TO_BONES["Sub_Horn_R"] = "head"

    # Capuz/Manto de Carrasco na nuca
    hood_rings = [
        (0.0, -0.04, 2.70, 0.32, 0.28),
        (0.0, -0.08, 2.50, 0.36, 0.32),
        (0.0, -0.12, 2.26, 0.44, 0.36),
    ]
    add_loft(root, "Executioner_Shroud", hood_rings, 8, mat_cloth)
    PARTS_TO_BONES["Executioner_Shroud"] = "chest"

    # ---------------- 4. OMBROS & OMBREIRAS PONTENAGUDAS (shoulders) ----------------
    add_box(root, "Pauldron_L", (0.64, 0.06, 2.20), (0.34, 0.36, 0.30), mat_dark_iron)
    add_box(root, "Pauldron_Spike_L", (0.76, 0.06, 2.38), (0.12, 0.12, 0.26), mat_bone)
    PARTS_TO_BONES["Pauldron_L"] = "shoulder.L"
    PARTS_TO_BONES["Pauldron_Spike_L"] = "shoulder.L"

    add_box(root, "Pauldron_R", (-0.64, 0.06, 2.20), (0.34, 0.36, 0.30), mat_dark_iron)
    add_box(root, "Pauldron_Spike_R", (-0.76, 0.06, 2.38), (0.12, 0.12, 0.26), mat_bone)
    PARTS_TO_BONES["Pauldron_R"] = "shoulder.R"
    PARTS_TO_BONES["Pauldron_Spike_R"] = "shoulder.R"

    # ---------------- 5. BRAÇO ESQUERDO: GARRA BESTIAL (claw arm) ----------------
    arm_l_pts = [(0.60, 0.06, 2.10), (0.78, 0.04, 1.85), (0.90, 0.02, 1.65)]
    arm_l_rad = [(0.14, 0.14), (0.12, 0.12), (0.11, 0.11)]
    add_tube_along_curve(root, "UpperArm_L_Mesh", arm_l_pts, arm_l_rad, 6, mat_bone)
    PARTS_TO_BONES["UpperArm_L_Mesh"] = "upper_arm.L"

    fore_l_pts = [(0.90, 0.02, 1.65), (1.02, 0.10, 1.42), (1.10, 0.15, 1.20)]
    fore_l_rad = [(0.11, 0.11), (0.13, 0.13), (0.12, 0.12)]
    add_tube_along_curve(root, "Forearm_L_Mesh", fore_l_pts, fore_l_rad, 6, mat_dark_iron)
    PARTS_TO_BONES["Forearm_L_Mesh"] = "forearm.L"

    # Manopla e Palma da Garra
    add_box(root, "Hand_L_Palm", (1.12, 0.18, 1.12), (0.18, 0.16, 0.14), mat_bone)
    PARTS_TO_BONES["Hand_L_Palm"] = "hand.L"

    # 4 Garras Afiadas de Osso
    for c_i, (cx, cy) in enumerate([(-0.06, 0.06), (-0.02, 0.08), (0.03, 0.08), (0.07, 0.05)]):
        claw_pts = [
            (1.12 + cx, 0.18 + cy, 1.08),
            (1.15 + cx * 1.2, 0.26 + cy * 1.2, 0.98),
            (1.16 + cx * 1.4, 0.32 + cy * 1.4, 0.88),
        ]
        claw_rad = [(0.035, 0.035), (0.025, 0.025), (0.01, 0.01)]
        cl_name = f"Claw_L_{c_i}"
        add_tube_along_curve(root, cl_name, claw_pts, claw_rad, 4, mat_horn)
        PARTS_TO_BONES[cl_name] = "hand.L"

    # ---------------- 6. BRAÇO DIREITO & CUTELO COLOSSAL (greatcleaver) ----------------
    arm_r_pts = [(-0.60, 0.06, 2.10), (-0.76, 0.04, 1.85), (-0.88, 0.02, 1.65)]
    arm_r_rad = [(0.14, 0.14), (0.13, 0.13), (0.12, 0.12)]
    add_tube_along_curve(root, "UpperArm_R_Mesh", arm_r_pts, arm_r_rad, 6, mat_bone)
    PARTS_TO_BONES["UpperArm_R_Mesh"] = "upper_arm.R"

    fore_r_pts = [(-0.88, 0.02, 1.65), (-0.92, 0.12, 1.42), (-0.95, 0.18, 1.20)]
    fore_r_rad = [(0.12, 0.12), (0.13, 0.13), (0.12, 0.12)]
    add_tube_along_curve(root, "Forearm_R_Mesh", fore_r_pts, fore_r_rad, 6, mat_dark_iron)
    PARTS_TO_BONES["Forearm_R_Mesh"] = "forearm.R"

    # Manopla Segurando o Cutelo
    add_box(root, "Hand_R_Mesh", (-0.96, 0.22, 1.15), (0.18, 0.18, 0.18), mat_dark_iron)
    PARTS_TO_BONES["Hand_R_Mesh"] = "hand.R"

    # O CUTELO COLOSSAL DO CARRASCO (Executioner's Greatcleaver)
    # 1. Cabo de ferro forjado (2.6m de comprimento)
    haft_pts = [
        (-0.96, 0.22, 0.05),
        (-0.96, 0.22, 1.15),
        (-0.96, 0.22, 2.05),
        (-0.96, 0.22, 2.65),
    ]
    haft_rad = [(0.05, 0.05), (0.05, 0.05), (0.06, 0.06), (0.07, 0.07)]
    add_tube_along_curve(root, "Cleaver_Haft", haft_pts, haft_rad, 6, mat_dark_iron)
    PARTS_TO_BONES["Cleaver_Haft"] = "cleaver"

    # 2. Corpo do Cutelo / Bloco de Ferro
    add_box(root, "Cleaver_Core_Block", (-0.96, 0.44, 2.15), (0.10, 0.38, 0.95), mat_dark_iron)
    PARTS_TO_BONES["Cleaver_Core_Block"] = "cleaver"

    # 3. Lâmina Chanfrada de Aço e Dentes Serrilhados
    cleaver_rings = [
        (-0.96, 0.26, 1.68, 0.05, 0.06),
        (-0.96, 0.50, 1.85, 0.04, 0.24),
        (-0.96, 0.65, 2.20, 0.03, 0.38),
        (-0.96, 0.68, 2.58, 0.025, 0.36),
        (-0.96, 0.55, 2.70, 0.015, 0.18),
    ]
    add_loft(root, "Cleaver_Blade_Loft", cleaver_rings, 6, mat_steel)
    PARTS_TO_BONES["Cleaver_Blade_Loft"] = "cleaver"

    # 4. Espigões na contra-lâmina
    for idx, z in enumerate([1.90, 2.15, 2.40]):
        sp_name = f"Cleaver_Spike_{idx}"
        add_box(root, sp_name, (-0.96, -0.04, z), (0.08, 0.24, 0.08), mat_bone)
        PARTS_TO_BONES[sp_name] = "cleaver"

    # ---------------- 7. PERNAS & PÉS (thighs / shins / feet) ----------------
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        t_name = f"Thigh_{side}_Mesh"
        thigh_pts = [(sx * 0.32, -0.02, 1.25), (sx * 0.34, 0.02, 0.98), (sx * 0.35, 0.04, 0.70)]
        thigh_rad = [(0.15, 0.15), (0.14, 0.14), (0.13, 0.13)]
        add_tube_along_curve(root, t_name, thigh_pts, thigh_rad, 6, mat_bone)
        PARTS_TO_BONES[t_name] = f"thigh.{side}"

        # Joelheira com espigão de ferro
        k_name = f"Knee_{side}_Plate"
        add_box(root, k_name, (sx * 0.35, 0.18, 0.70), (0.18, 0.14, 0.20), mat_dark_iron)
        PARTS_TO_BONES[k_name] = f"thigh.{side}"

        # Canela / Greva
        s_name = f"Shin_{side}_Mesh"
        shin_pts = [(sx * 0.35, 0.04, 0.70), (sx * 0.35, -0.02, 0.44), (sx * 0.35, -0.05, 0.18)]
        shin_rad = [(0.13, 0.13), (0.12, 0.12), (0.11, 0.11)]
        add_tube_along_curve(root, s_name, shin_pts, shin_rad, 6, mat_dark_iron)
        PARTS_TO_BONES[s_name] = f"shin.{side}"

        # Bota Blindada de Carrasco
        f_name = f"Foot_{side}_Mesh"
        foot_rings = [
            (sx * 0.35, -0.06, 0.18, 0.14, 0.16),
            (sx * 0.35, 0.04, 0.10, 0.15, 0.22),
            (sx * 0.35, 0.16, 0.02, 0.14, 0.26),
        ]
        add_loft(root, f_name, foot_rings, 6, mat_dark_iron)
        PARTS_TO_BONES[f_name] = f"foot.{side}"


# ==============================================================================
# CONSTRUÇÃO DO ARMATURE (RIG)
# ==============================================================================
def build_armature(root):
    bpy.ops.object.armature_add(location=(0, 0, 0))
    armature = bpy.context.active_object
    armature.name = RIG_NAME
    armature.data.name = "BossMalakor_Armature"
    armature.parent = root
    armature.show_in_front = True

    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones = armature.data.edit_bones
    for bone in list(edit_bones):
        edit_bones.remove(bone)

    # Hierarquia de Ossos (22 bones essenciais com alinhamento perfeito)
    # Formato: (nome, head, tail, parent)
    bones_spec = [
        ("root", (0.0, 0.0, 0.0), (0.0, 0.0, 0.25), None),
        ("hips", (0.0, 0.0, 1.25), (0.0, 0.02, 1.45), "root"),
        ("spine", (0.0, 0.02, 1.45), (0.0, 0.05, 1.80), "hips"),
        ("chest", (0.0, 0.05, 1.80), (0.0, 0.08, 2.20), "spine"),
        ("neck", (0.0, 0.08, 2.20), (0.0, 0.12, 2.40), "chest"),
        ("head", (0.0, 0.12, 2.40), (0.0, 0.18, 2.76), "neck"),
        ("jaw", (0.0, 0.22, 2.40), (0.0, 0.35, 2.44), "head"),
    ]

    # Braços e Pernas Simétricos
    for side, sx in [("L", 1.0), ("R", -1.0)]:
        bones_spec += [
            (f"shoulder.{side}", (sx * 0.35, 0.08, 2.15), (sx * 0.60, 0.06, 2.10), "chest"),
            (f"upper_arm.{side}", (sx * 0.60, 0.06, 2.10), (sx * 0.90, 0.02, 1.65), f"shoulder.{side}"),
            (f"forearm.{side}", (sx * 0.90, 0.02, 1.65), (sx * 1.05, 0.15, 1.20), f"upper_arm.{side}"),
            (f"hand.{side}", (sx * 1.05, 0.15, 1.20), (sx * 1.15, 0.25, 1.02), f"forearm.{side}"),
            (f"thigh.{side}", (sx * 0.32, -0.02, 1.25), (sx * 0.35, 0.04, 0.70), "hips"),
            (f"shin.{side}", (sx * 0.35, 0.04, 0.70), (sx * 0.35, -0.05, 0.18), f"thigh.{side}"),
            (f"foot.{side}", (sx * 0.35, -0.05, 0.18), (sx * 0.35, 0.20, 0.02), f"shin.{side}"),
        ]

    # Osso do Cutelo Colossal (ancorado na mão direita)
    bones_spec.append(
        ("cleaver", (-0.96, 0.22, 1.15), (-0.96, 0.35, 2.45), "hand.R")
    )

    for name, head, tail, parent in bones_spec:
        bone = edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        bone.roll = 0.0
        if parent:
            bone.parent = edit_bones[parent]

    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def bind_meshes_to_rig(armature, root):
    """Vincula cada peça geométrica ao osso correspondente com vertex group 1.0 e Armature modifier."""
    bound_count = 0
    for child in list(root.children):
        if child.type != "MESH":
            continue
        bone_name = PARTS_TO_BONES.get(child.name)
        if bone_name is None or bone_name not in armature.data.bones:
            print(f"Alerta: Peça sem osso correspondente: {child.name}")
            continue

        world_mat = child.matrix_world.copy()
        child.parent = armature
        child.matrix_world = world_mat

        vg = child.vertex_groups.new(name=bone_name)
        vg.add(list(range(len(child.data.vertices))), 1.0, "REPLACE")

        mod = child.modifiers.new("Armature", "ARMATURE")
        mod.object = armature
        bound_count += 1

    print(f"Malhas vinculadas com sucesso ao Rig: {bound_count}")


# ==============================================================================
# CRIAÇÃO DAS ANIMAÇÕES (FRAME-A-FRAME COM SÍNTESE SUAVE)
# ==============================================================================
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
        if pb.name in ("root", "hips"):
            pb.keyframe_insert("location", frame=frame)


def smooth_step(edge0, edge1, x):
    t = max(0.0, min(1.0, (x - edge0) / max(0.0001, (edge1 - edge0))))
    return t * t * (3.0 - 2.0 * t)


def create_all_animations(armature):
    pbs = armature.pose.bones

    # ---------------- 1. IDLE-LOOP (48 frames / 2.0s @ 24fps) ----------------
    start_action(armature, "idle-loop")
    total_idle = 48
    for f in range(1, total_idle + 1):
        u = (f - 1) / float(total_idle - 1)
        ang = u * 2.0 * pi
        reset_pose(armature)

        # Respiração do tronco
        breath = sin(ang)
        if "hips" in pbs:
            pbs["hips"].location = (0.0, 0.0, breath * 0.02)
            pbs["hips"].rotation_euler = (radians(2.0 + breath * 1.5), 0.0, 0.0)
        if "spine" in pbs:
            pbs["spine"].rotation_euler = (radians(3.0 + breath * 2.0), radians(sin(ang * 0.5) * 1.5), 0.0)
        if "chest" in pbs:
            pbs["chest"].rotation_euler = (radians(-1.5 - breath * 2.5), 0.0, 0.0)
        if "head" in pbs:
            pbs["head"].rotation_euler = (radians(breath * 1.8), radians(cos(ang) * 2.5), 0.0)
        if "jaw" in pbs:
            pbs["jaw"].rotation_euler = (radians(max(0.0, breath * 4.0)), 0.0, 0.0)

        # Braço esquerdo (garra) pulsando
        if "upper_arm.L" in pbs:
            pbs["upper_arm.L"].rotation_euler = (radians(breath * 2.0), radians(-breath * 2.0), radians(breath * 2.0))
        if "forearm.L" in pbs:
            pbs["forearm.L"].rotation_euler = (radians(-20.0 + breath * 4.0), 0.0, 0.0)

        # Braço direito sustentando o Cutelo Colossal
        if "upper_arm.R" in pbs:
            pbs["upper_arm.R"].rotation_euler = (radians(-8.0 + breath * 1.5), radians(breath * 1.0), radians(-5.0))
        if "forearm.R" in pbs:
            pbs["forearm.R"].rotation_euler = (radians(-35.0 + breath * 2.0), 0.0, 0.0)
        if "cleaver" in pbs:
            pbs["cleaver"].rotation_euler = (radians(breath * 1.8), radians(breath * 1.2), 0.0)

        key_all_bones(armature, f)

    # ---------------- 2. WALK-LOOP (24 frames / 1.0s @ 24fps) ----------------
    start_action(armature, "walk-loop")
    total_walk = 24
    for f in range(1, total_walk + 1):
        u = (f - 1) / float(total_walk - 1)
        ang = u * 2.0 * pi
        reset_pose(armature)

        step_l = sin(ang)
        step_r = sin(ang + pi)
        bob = -abs(sin(ang * 2.0)) * 0.06

        if "hips" in pbs:
            pbs["hips"].location = (sin(ang) * 0.03, 0.0, bob)
            pbs["hips"].rotation_euler = (radians(5.0), radians(sin(ang) * 4.0), radians(-cos(ang) * 2.5))
        if "spine" in pbs:
            pbs["spine"].rotation_euler = (radians(3.0), radians(-sin(ang) * 3.5), 0.0)
        if "chest" in pbs:
            pbs["chest"].rotation_euler = (radians(-2.0), radians(-sin(ang) * 4.0), 0.0)
        if "head" in pbs:
            pbs["head"].rotation_euler = (radians(-sin(ang * 2.0) * 2.0), radians(sin(ang) * 2.0), 0.0)

        # Pernas
        if "thigh.L" in pbs:
            pbs["thigh.L"].rotation_euler = (radians(step_l * 28.0), 0.0, 0.0)
        if "shin.L" in pbs:
            knee_l = max(0.0, -step_l * 32.0) if step_l < 0.0 else max(0.0, sin(ang) * 12.0)
            pbs["shin.L"].rotation_euler = (radians(-knee_l), 0.0, 0.0)

        if "thigh.R" in pbs:
            pbs["thigh.R"].rotation_euler = (radians(step_r * 28.0), 0.0, 0.0)
        if "shin.R" in pbs:
            knee_r = max(0.0, -step_r * 32.0) if step_r < 0.0 else max(0.0, sin(ang + pi) * 12.0)
            pbs["shin.R"].rotation_euler = (radians(-knee_r), 0.0, 0.0)

        # Braços balançando ritmados com o cutelo
        if "upper_arm.L" in pbs:
            pbs["upper_arm.L"].rotation_euler = (radians(step_r * 20.0), 0.0, 0.0)
        if "forearm.L" in pbs:
            pbs["forearm.L"].rotation_euler = (radians(-25.0 + max(0.0, step_r * 15.0)), 0.0, 0.0)

        if "upper_arm.R" in pbs:
            pbs["upper_arm.R"].rotation_euler = (radians(step_l * 18.0), 0.0, 0.0)
        if "forearm.R" in pbs:
            pbs["forearm.R"].rotation_euler = (radians(-40.0 + max(0.0, step_l * 12.0)), 0.0, 0.0)
        if "cleaver" in pbs:
            pbs["cleaver"].rotation_euler = (radians(step_l * 14.0), 0.0, 0.0)

        key_all_bones(armature, f)

    # ---------------- 3. ATTACK (24 frames / 1.0s @ 24fps) — CLEAVE DESCENDENTE ----------------
    start_action(armature, "attack")
    total_atk = 24
    for f in range(1, total_atk + 1):
        reset_pose(armature)

        # Fases:
        # 1..8: Antecipação brutal (ergue o cutelo no alto, peito arqueia para trás)
        # 9..13: O IMPACTO devastador (corta o ar e crava no chão à frente)
        # 14..24: Recuperação de força e retorno à guarda
        if f <= 8:
            t = smooth_step(1, 8, f)
            if "hips" in pbs:
                pbs["hips"].rotation_euler = (radians(-8.0 * t), 0.0, 0.0)
            if "spine" in pbs:
                pbs["spine"].rotation_euler = (radians(-12.0 * t), radians(-6.0 * t), 0.0)
            if "chest" in pbs:
                pbs["chest"].rotation_euler = (radians(-15.0 * t), radians(-8.0 * t), 0.0)
            if "head" in pbs:
                pbs["head"].rotation_euler = (radians(14.0 * t), 0.0, 0.0)
            if "jaw" in pbs:
                pbs["jaw"].rotation_euler = (radians(18.0 * t), 0.0, 0.0) # rugido ao erguer
            if "upper_arm.R" in pbs:
                pbs["upper_arm.R"].rotation_euler = (radians(-110.0 * t), radians(15.0 * t), radians(-18.0 * t))
            if "forearm.R" in pbs:
                pbs["forearm.R"].rotation_euler = (radians(-85.0 * t), 0.0, 0.0)
            if "cleaver" in pbs:
                pbs["cleaver"].rotation_euler = (radians(-45.0 * t), 0.0, 0.0)
            # Garra esquerda abre para equilíbrio
            if "upper_arm.L" in pbs:
                pbs["upper_arm.L"].rotation_euler = (radians(20.0 * t), radians(-25.0 * t), radians(35.0 * t))
        elif f <= 13:
            t = (f - 8) / 5.0
            t_whip = t ** 2.5 # Descida violenta tipo chicote
            if "hips" in pbs:
                pbs["hips"].location = (0.0, 0.0, -0.08 * t_whip)
                pbs["hips"].rotation_euler = (radians(-8.0 + 26.0 * t_whip), 0.0, 0.0)
            if "spine" in pbs:
                pbs["spine"].rotation_euler = (radians(-12.0 + 35.0 * t_whip), 0.0, 0.0)
            if "chest" in pbs:
                pbs["chest"].rotation_euler = (radians(-15.0 + 40.0 * t_whip), 0.0, 0.0)
            if "head" in pbs:
                pbs["head"].rotation_euler = (radians(14.0 - 24.0 * t_whip), 0.0, 0.0)
            if "upper_arm.R" in pbs:
                pbs["upper_arm.R"].rotation_euler = (radians(-110.0 + 175.0 * t_whip), 0.0, 0.0)
            if "forearm.R" in pbs:
                pbs["forearm.R"].rotation_euler = (radians(-85.0 + 75.0 * t_whip), 0.0, 0.0)
            if "cleaver" in pbs:
                pbs["cleaver"].rotation_euler = (radians(-45.0 + 95.0 * t_whip), 0.0, 0.0)
        else:
            t = smooth_step(13, 24, f)
            # Retorna da estocada no chão para o repouso
            if "hips" in pbs:
                pbs["hips"].location = (0.0, 0.0, -0.08 * (1.0 - t))
                pbs["hips"].rotation_euler = (radians(18.0 * (1.0 - t)), 0.0, 0.0)
            if "spine" in pbs:
                pbs["spine"].rotation_euler = (radians(23.0 * (1.0 - t)), 0.0, 0.0)
            if "chest" in pbs:
                pbs["chest"].rotation_euler = (radians(25.0 * (1.0 - t)), 0.0, 0.0)
            if "head" in pbs:
                pbs["head"].rotation_euler = (radians(-10.0 * (1.0 - t)), 0.0, 0.0)
            if "upper_arm.R" in pbs:
                pbs["upper_arm.R"].rotation_euler = (radians(65.0 * (1.0 - t)), 0.0, 0.0)
            if "forearm.R" in pbs:
                pbs["forearm.R"].rotation_euler = (radians(-10.0 * (1.0 - t) - 35.0 * t), 0.0, 0.0)
            if "cleaver" in pbs:
                pbs["cleaver"].rotation_euler = (radians(50.0 * (1.0 - t)), 0.0, 0.0)

        key_all_bones(armature, f)

    # ---------------- 4. ATTACK_SWEEP (24 frames / 1.0s @ 24fps) — VARREDURA HORIZONTAL 180° ----------------
    start_action(armature, "attack_sweep")
    total_swp = 24
    for f in range(1, total_swp + 1):
        reset_pose(armature)

        # Fases:
        # 1..8: Carrega na direita girando 45°
        # 9..14: Corte horizontal amplo rasgando 180° em arco
        # 15..24: Inércia e retorno à guarda
        if f <= 8:
            t = smooth_step(1, 8, f)
            if "hips" in pbs:
                pbs["hips"].rotation_euler = (0.0, 0.0, radians(-25.0 * t))
            if "spine" in pbs:
                pbs["spine"].rotation_euler = (radians(4.0 * t), 0.0, radians(-35.0 * t))
            if "chest" in pbs:
                pbs["chest"].rotation_euler = (radians(6.0 * t), 0.0, radians(-40.0 * t))
            if "head" in pbs:
                pbs["head"].rotation_euler = (0.0, 0.0, radians(30.0 * t)) # Foco no alvo à frente
            if "upper_arm.R" in pbs:
                pbs["upper_arm.R"].rotation_euler = (radians(-20.0 * t), radians(45.0 * t), radians(-45.0 * t))
            if "forearm.R" in pbs:
                pbs["forearm.R"].rotation_euler = (radians(-65.0 * t), 0.0, 0.0)
            if "cleaver" in pbs:
                pbs["cleaver"].rotation_euler = (radians(-30.0 * t), radians(-20.0 * t), 0.0)
        elif f <= 14:
            t = (f - 8) / 6.0
            t_whip = t ** 2.2
            if "hips" in pbs:
                pbs["hips"].rotation_euler = (0.0, 0.0, radians(-25.0 + 55.0 * t_whip))
            if "spine" in pbs:
                pbs["spine"].rotation_euler = (radians(4.0), 0.0, radians(-35.0 + 80.0 * t_whip))
            if "chest" in pbs:
                pbs["chest"].rotation_euler = (radians(6.0), 0.0, radians(-40.0 + 95.0 * t_whip))
            if "upper_arm.R" in pbs:
                pbs["upper_arm.R"].rotation_euler = (radians(-20.0 + 40.0 * t_whip), radians(45.0 - 90.0 * t_whip), radians(-45.0 + 80.0 * t_whip))
            if "forearm.R" in pbs:
                pbs["forearm.R"].rotation_euler = (radians(-65.0 + 45.0 * t_whip), 0.0, 0.0)
            if "cleaver" in pbs:
                pbs["cleaver"].rotation_euler = (radians(-30.0 + 80.0 * t_whip), radians(-20.0 + 65.0 * t_whip), 0.0)
        else:
            t = smooth_step(14, 24, f)
            if "hips" in pbs:
                pbs["hips"].rotation_euler = (0.0, 0.0, radians(30.0 * (1.0 - t)))
            if "spine" in pbs:
                pbs["spine"].rotation_euler = (radians(4.0 * (1.0 - t)), 0.0, radians(45.0 * (1.0 - t)))
            if "chest" in pbs:
                pbs["chest"].rotation_euler = (radians(6.0 * (1.0 - t)), 0.0, radians(55.0 * (1.0 - t)))
            if "upper_arm.R" in pbs:
                pbs["upper_arm.R"].rotation_euler = (radians(20.0 * (1.0 - t)), radians(-45.0 * (1.0 - t)), radians(35.0 * (1.0 - t)))
            if "forearm.R" in pbs:
                pbs["forearm.R"].rotation_euler = (radians(-20.0 * (1.0 - t) - 35.0 * t), 0.0, 0.0)
            if "cleaver" in pbs:
                pbs["cleaver"].rotation_euler = (radians(50.0 * (1.0 - t)), radians(45.0 * (1.0 - t)), 0.0)

        key_all_bones(armature, f)


def setup_nla_tracks(armature):
    anim_data = armature.animation_data
    if anim_data is None:
        anim_data = armature.animation_data_create()
    for tr in list(anim_data.nla_tracks):
        anim_data.nla_tracks.remove(tr)

    actions = ["idle-loop", "walk-loop", "attack", "attack_sweep"]
    for act_name in actions:
        action = bpy.data.actions.get(act_name)
        if action is None:
            continue
        track = anim_data.nla_tracks.new()
        track.name = act_name
        strip = track.strips.new(act_name, 1, action)
        if hasattr(strip, "action_slot") and hasattr(action, "slots") and len(action.slots) > 0:
            strip.action_slot = action.slots[0]
        track.mute = True

    default_act = bpy.data.actions.get("idle-loop")
    if default_act:
        anim_data.action = default_act


# ==============================================================================
# PIPELINE PRINCIPAL DE EXECUÇÃO & EXPORTAÇÃO
# ==============================================================================
def main():
    print("=== INICIANDO CRIAÇÃO DE MALAKOR, O CARRASCO DA CRIPTA ===")
    clear_scene()

    # Cria Objeto Raiz
    root = bpy.data.objects.new(ROOT_NAME, None)
    bpy.context.collection.objects.link(root)

    # 1. Modelagem anatômica
    build_malakor_meshes(root)

    # 2. Armature Rig
    armature = build_armature(root)

    # 3. Skinning / Vinculação de Vertex Groups
    bind_meshes_to_rig(armature, root)

    # 4. Animações
    create_all_animations(armature)
    setup_nla_tracks(armature)

    # Salva arquivo .blend editável completo
    OUTPUT_BLEND.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT_BLEND))
    print(f"[OK] Arquivo Blender fonte salvo: {OUTPUT_BLEND}")

    # Exporta para GLB
    OUTPUT_GLB.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    armature.select_set(True)
    for ch in armature.children_recursive:
        if ch.type == "MESH":
            ch.select_set(True)
    bpy.context.view_layer.objects.active = armature

    kwargs = dict(
        filepath=str(OUTPUT_GLB),
        export_format="GLB",
        use_selection=True,
        export_yup=True,
        export_lights=False,
        export_cameras=False,
        export_animations=True,
        export_materials="EXPORT",
    )
    props = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    if "export_animation_mode" in props:
        kwargs["export_animation_mode"] = "NLA_TRACKS"
    elif "export_nla_strips" in props:
        kwargs["export_nla_strips"] = True

    bpy.ops.export_scene.gltf(**kwargs)
    print(f"[OK] Modelo 3D GLB exportado com sucesso: {OUTPUT_GLB}")
    print("=== BOSS MALAKOR CRIADO E EXPORTADO COM 100% DE SUCESSO! ===")


if __name__ == "__main__":
    main()
