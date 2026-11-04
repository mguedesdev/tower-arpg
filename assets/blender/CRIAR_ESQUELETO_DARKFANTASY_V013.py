"""SkeletonEnemy v0.16 — Guerreiro Esqueleto Dark-Fantasy (Diablo 2 / PoE 2 / Grim Dawn).

Inclui anatomia óssea esculpida + Ombreiras de Ferro Oxidado com Espinhos,
Tiara/Elmo Quebrado da Cripta, Cutelo Ancestral na mão direita e Broquel de Ferro no braço esquerdo.
Eixo Blender: +Z cima, +Y frente, +X direita.
"""

import bpy
from math import cos, sin, pi, radians
from mathutils import Vector

GAME_SCALE = 0.40       # ~4.55 unidades de modelagem -> 1.82 m no Godot
SKULL_SCALE = 1.0
EYE_GLOW = 2.6
CLOTH_COLOR = (0.34, 0.09, 0.11)


def build_skeleton_model(is_boss=False):
    if bpy.context.object and bpy.context.object.mode != 'OBJECT':
        bpy.ops.object.mode_set(mode='OBJECT')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

    for block in list(bpy.data.meshes):
        if block.users == 0:
            bpy.data.meshes.remove(block)
    for block in list(bpy.data.materials):
        if block.users == 0:
            bpy.data.materials.remove(block)

    main_collection = bpy.data.collections.get('SKELETON_SOURCE')
    if main_collection is None:
        main_collection = bpy.data.collections.new('SKELETON_SOURCE')
        bpy.context.scene.collection.children.link(main_collection)

    root = bpy.data.objects.new('SkeletonEnemy', None)
    main_collection.objects.link(root)
    root.empty_display_type = 'PLAIN_AXES'
    root.empty_display_size = 0.15

    def material(name, rgb, roughness=0.92, metallic=0.0, emission=0.0):
        mat = bpy.data.materials.new(name)
        mat.use_nodes = True
        mat.diffuse_color = (*rgb, 1.0)
        shader = mat.node_tree.nodes.get('Principled BSDF')
        if shader:
            shader.inputs['Base Color'].default_value = (*rgb, 1.0)
            shader.inputs['Roughness'].default_value = roughness
            if 'Metallic' in shader.inputs:
                shader.inputs['Metallic'].default_value = metallic
            if emission:
                if 'Emission Color' in shader.inputs:
                    shader.inputs['Emission Color'].default_value = (*rgb, 1.0)
                elif 'Emission' in shader.inputs:
                    shader.inputs['Emission'].default_value = (*rgb, 1.0)
                if 'Emission Strength' in shader.inputs:
                    shader.inputs['Emission Strength'].default_value = emission
        return mat

    if is_boss:
        IVORY = material('01_Bone_Ivory', (0.56, 0.50, 0.42), 0.88)
        BONE_LIGHT = material('02_Bone_Light', (0.72, 0.65, 0.54), 0.85)
        BONE_SHADOW = material('03_Bone_Shadow', (0.35, 0.31, 0.26), 0.92)
        SOCKET = material('04_Socket_Dark', (0.05, 0.04, 0.04), 0.95)
        EYES = material('05_Eye_Glow', (1.0, 0.24, 0.08), 0.25, 0.0, 4.2)
        CLOTH = material('06_Cloth_Faded', (0.45, 0.07, 0.09), 0.90)
        LEATHER = material('07_Leather', (0.16, 0.10, 0.08), 0.88)
        BRONZE = material('08_Bronze', (0.68, 0.48, 0.22), 0.42, 0.82)
        IRON_DARK = material('09_Dark_Iron', (0.14, 0.15, 0.18), 0.48, 0.85)
        STEEL_EDGE = material('10_Steel_Edge', (0.58, 0.61, 0.66), 0.35, 0.90)
        RUNE_FIRE = material('11_Rune_Fire', (1.0, 0.32, 0.08), 0.25, 0.0, 3.8)
    else:
        IVORY = material('01_Bone_Ivory', (0.73, 0.68, 0.58), 0.90)
        BONE_LIGHT = material('02_Bone_Light', (0.86, 0.80, 0.68), 0.88)
        BONE_SHADOW = material('03_Bone_Shadow', (0.48, 0.44, 0.37), 0.94)
        SOCKET = material('04_Socket_Dark', (0.06, 0.07, 0.07), 0.95)
        EYES = material('05_Eye_Glow', (0.34, 0.95, 0.56), 0.30, 0.0, EYE_GLOW)
        CLOTH = material('06_Cloth_Faded', CLOTH_COLOR, 0.92)
        LEATHER = material('07_Leather', (0.19, 0.13, 0.11), 0.88)
        BRONZE = material('08_Bronze', (0.52, 0.37, 0.20), 0.50, 0.75)
        IRON_DARK = material('09_Dark_Iron', (0.20, 0.22, 0.25), 0.52, 0.82)
        STEEL_EDGE = material('10_Steel_Edge', (0.52, 0.55, 0.60), 0.38, 0.88)
        RUNE_FIRE = EYES

    def register(obj):
        for collection in tuple(obj.users_collection):
            collection.objects.unlink(obj)
        main_collection.objects.link(obj)
        obj.parent = root
        if obj.type == 'MESH':
            for poly in obj.data.polygons:
                poly.use_smooth = False
        return obj

    def mesh_object(name, vertices, faces, mat, material_indices=None, secondary_material=None):
        mesh = bpy.data.meshes.new(name + '_Mesh')
        mesh.from_pydata(vertices, [], faces)
        mesh.update()
        obj = bpy.data.objects.new(name, mesh)
        main_collection.objects.link(obj)
        obj.parent = root
        mesh.materials.append(mat)
        if secondary_material is not None:
            mesh.materials.append(secondary_material)
        if material_indices:
            for p, mi in zip(mesh.polygons, material_indices):
                p.material_index = mi
        for p in mesh.polygons:
            p.use_smooth = False
        return obj

    def ico(name, position, radius, mat, subdivision=1, scale=None):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivision, radius=radius, location=position)
        obj = bpy.context.object
        obj.name = name
        obj.data.materials.append(mat)
        if scale is not None:
            obj.scale = scale
        return register(obj)

    def bevel_box(name, pos, size, mat, bevel=0.0, rotation=None):
        bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
        obj = bpy.context.object
        obj.name = name
        obj.dimensions = size
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        if bevel:
            mod = obj.modifiers.new('SingleEdge_Facets', 'BEVEL')
            mod.width = bevel
            mod.segments = 1
            bpy.context.view_layer.objects.active = obj
            bpy.ops.object.modifier_apply(modifier=mod.name)
        if rotation is not None:
            obj.rotation_euler = rotation
        obj.data.materials.append(mat)
        return register(obj)

    def poly_xz(name, points, front_y, back_y, mat):
        n = len(points)
        v = [(x, front_y, z) for x, z in points] + [(x, back_y, z) for x, z in points]
        signed_area = sum(
            points[i][0] * points[(i + 1) % n][1]
            - points[(i + 1) % n][0] * points[i][1]
            for i in range(n)
        )
        front_order = list(range(n)) if signed_area < 0 else list(reversed(range(n)))
        back_order = list(reversed(front_order))
        faces = [tuple(front_order), tuple(n + i for i in back_order)]
        for i in range(n):
            j = (i + 1) % n
            if signed_area < 0:
                faces.append((i, n + i, n + j, j))
            else:
                faces.append((i, j, n + j, n + i))
        return mesh_object(name, v, faces, mat)

    def poly_yz(name, points_yz, left_x, right_x, mat):
        """Prisma definido por contorno 2D (y, z) e espessura em X (ótimo para lâminas!)."""
        n = len(points_yz)
        v = [(right_x, y, z) for y, z in points_yz] + [(left_x, y, z) for y, z in points_yz]
        signed_area = sum(
            points_yz[i][0] * points_yz[(i + 1) % n][1]
            - points_yz[(i + 1) % n][0] * points_yz[i][1]
            for i in range(n)
        )
        right_order = list(range(n)) if signed_area > 0 else list(reversed(range(n)))
        left_order = list(reversed(right_order))
        faces = [tuple(right_order), tuple(n + i for i in left_order)]
        for i in range(n):
            j = (i + 1) % n
            if signed_area > 0:
                faces.append((i, n + i, n + j, j))
            else:
                faces.append((i, j, n + j, n + i))
        return mesh_object(name, v, faces, mat)

    def faceted_profile(name, rings, segments, mat, alternate=None):
        v = []
        for z, rx, ry, cy in rings:
            for i in range(segments):
                a = 2.0 * pi * i / segments
                v.append((SKULL_SCALE * rx * cos(a), cy + SKULL_SCALE * ry * sin(a), z))
        faces = [tuple(reversed(range(segments)))]
        mi = [0]
        for r in range(len(rings) - 1):
            for i in range(segments):
                j = (i + 1) % segments
                faces.append((r * segments + i,
                              r * segments + j,
                              (r + 1) * segments + j,
                              (r + 1) * segments + i))
                mi.append(1 if alternate is not None and (i + r * 2) % 9 == 0 else 0)
        faces.append(tuple((len(rings) - 1) * segments + i for i in range(segments)))
        mi.append(0)
        return mesh_object(name, v, faces, mat, mi, alternate)

    def bone_tube(name, points, radii, mat, sides=6):
        assert len(points) == len(radii) and len(points) >= 2
        path = [Vector(p) for p in points]
        verts = []
        for i, center in enumerate(path):
            tangent = (path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)]).normalized()
            ref = Vector((0.0, 0.0, 1.0)) if abs(tangent.z) < 0.85 else Vector((0.0, 1.0, 0.0))
            side = tangent.cross(ref).normalized()
            other = tangent.cross(side).normalized()
            for j in range(sides):
                a = 2.0 * pi * j / sides
                p = center + (side * cos(a) + other * sin(a)) * radii[i]
                verts.append(tuple(p))
        faces = [tuple(reversed(range(sides)))]
        for ring in range(len(path) - 1):
            for j in range(sides):
                k = (j + 1) % sides
                faces.append((ring * sides + j,
                              ring * sides + k,
                              (ring + 1) * sides + k,
                              (ring + 1) * sides + j))
        faces.append(tuple((len(path) - 1) * sides + j for j in range(sides)))
        return mesh_object(name, verts, faces, mat)

    # ===============================================================
    # 3. CRANIO EXPRESSIVO + COROA / ELMO DARK-FANTASY
    # ===============================================================
    faceted_profile('Head_Skull', [
        (3.58, 0.22, 0.25, -0.02),
        (3.70, 0.34, 0.34, -0.01),
        (3.86, 0.46, 0.40, 0.00),
        (4.08, 0.50, 0.43, 0.00),
        (4.30, 0.45, 0.39, -0.01),
        (4.48, 0.27, 0.27, -0.03),
        (4.54, 0.10, 0.10, -0.03),
    ], 10, IVORY, BONE_LIGHT)

    # Tiara / Coroa de Ferro na testa do crânio ('Head_*' vincula ao osso 'head')
    faceted_profile('Head_HelmBand', [
        (4.18, 0.52, 0.46, 0.01),
        (4.32, 0.49, 0.44, 0.00),
    ], 10, BRONZE if is_boss else IRON_DARK)

    # Crista frontal e pontas da coroa
    poly_xz('Head_HelmCrest', [
        (-0.14, 4.18), (0.0, 4.58 if is_boss else 4.46), (0.14, 4.18)
    ], 0.48, 0.41, BRONZE)

    if is_boss:
        # Chifres Abissais Curvos do Mini-Boss Carrasco Profanado!
        for side, label in [(-1, 'L'), (1, 'R')]:
            bone_tube('Head_BossHorn_' + label, [
                (side * 0.44, 0.05, 4.24),
                (side * 0.72, 0.12, 4.48),
                (side * 0.88, 0.28, 4.82),
                (side * 0.76, 0.42, 5.12),
            ], [0.11, 0.085, 0.055, 0.015], IRON_DARK, 6)
            poly_xz('Head_CrownSpike_' + label, [
                (side * 0.22, 4.26), (side * 0.30, 4.62), (side * 0.38, 4.26)
            ], 0.42, 0.35, BRONZE)

    for side, label in [(-1, 'L'), (1, 'R')]:
        x = side * 0.225
        poly_xz('EyeSocket_' + label, [
            (x - 0.15, 4.12), (x - 0.10, 4.24),
            (x + 0.14, 4.19), (x + 0.16, 4.04),
            (x + 0.06, 3.91), (x - 0.13, 3.95),
        ], 0.434, 0.406, SOCKET)
        poly_xz('EyeGlow_' + label, [
            (x - 0.065, 4.11), (x + 0.065, 4.11),
            (x + 0.045, 4.00), (x - 0.065, 4.01),
        ], 0.448, 0.430, EYES)
        bone_tube('Brow_' + label,
                  [(x - 0.16, 0.43, 4.235), (x, 0.48, 4.225), (x + 0.18, 0.395, 4.17)],
                  [0.055, 0.072, 0.042], BONE_LIGHT, 5)
        ico('Cheek_' + label, (side * 0.36, 0.33, 3.80), 0.175, BONE_LIGHT, 1,
            (1.20, 0.60, 0.56))

    poly_xz('NoseHole', [(-0.065, 3.93), (0.065, 3.93), (0, 3.80)],
            0.451, 0.425, SOCKET)

    bone_tube('JawLine_L', [(-0.31, 0.30, 3.77), (-0.29, 0.32, 3.63), (-0.17, 0.35, 3.57)],
              [0.077, 0.071, 0.061], BONE_LIGHT, 5)
    bone_tube('JawLine_R', [(0.31, 0.30, 3.77), (0.29, 0.32, 3.63), (0.17, 0.35, 3.57)],
              [0.077, 0.071, 0.061], BONE_LIGHT, 5)
    bone_tube('Jaw_Chin', [(-0.17, 0.35, 3.57), (0, 0.39, 3.54), (0.17, 0.35, 3.57)],
              [0.07, 0.095, 0.07], IVORY, 5)
    poly_xz('MouthGap', [(-0.17, 3.66), (0.17, 3.66), (0.14, 3.61), (-0.14, 3.61)],
            0.420, 0.408, SOCKET)
    for idx, xx in enumerate([-0.13, -0.043, 0.043, 0.13]):
        bevel_box('UpperTooth_%d' % idx, (xx, 0.449, 3.68), (0.056, 0.065, 0.095),
                  BONE_LIGHT, 0.009)

    # ===============================================================
    # 4. PESCOCO / COLUNA / OMBROS / COSTELAS
    # ===============================================================
    for n, z in enumerate([3.26, 3.39, 3.50]):
        ico('NeckVertebra_%d' % n, (0, -0.04, z), 0.095, BONE_LIGHT, 1, (1.0, 0.78, 0.72))
    bone_tube('NeckStem', [(0, -0.06, 3.03), (0, -0.03, 3.30), (0, -0.02, 3.56)],
              [0.11, 0.08, 0.095], IVORY, 7)

    for n, z in enumerate([1.92, 2.12, 2.33, 2.54, 2.72, 2.91]):
        ico('Spine_%d' % n, (0, -0.15, z), 0.095, BONE_SHADOW if n % 2 else IVORY,
            1, (1.05, 0.90, 0.83))
    bone_tube('Sternum', [(0, 0.21, 2.13), (0, 0.28, 2.46), (0, 0.24, 2.85)],
              [0.08, 0.13, 0.10], BONE_LIGHT, 5)

    if is_boss:
        # Coração / Runa Profana ardendo dentro da caixa torácica do Boss!
        ico('Spine_BossHeart', (0, 0.08, 2.54), 0.22, RUNE_FIRE, 1, (0.95, 0.85, 1.15))

    for side, label in [(-1, 'L'), (1, 'R')]:
        bone_tube('Clavicle_' + label,
                  [(side * 0.07, 0.02, 2.96),
                   (side * 0.38, 0.03, 2.99),
                   (side * 0.68, -0.015, 2.93)],
                  [0.075, 0.087, 0.095], BONE_LIGHT, 6)
        ico('ShoulderJoint_' + label, (side * 0.67, 0.00, 2.91), 0.13,
            IVORY, 1, (1.0, 0.88, 0.93))

        # Ombreiras Góticas de Ferro Oxidado ('ShoulderJoint_*' vincula a 'upper_arm.L/R')
        pauldron_scale = 1.28 if is_boss else 1.0
        ico('ShoulderJoint_Pauldron_' + label,
            (side * 0.74, 0.01, 2.98),
            0.26 * pauldron_scale,
            IRON_DARK, 1, (1.15, 0.95, 0.72))
        bone_tube('ShoulderJoint_Spike_' + label, [
            (side * 0.78, 0.01, 3.06),
            (side * 0.98 * pauldron_scale, 0.01, 3.38 * pauldron_scale),
        ], [0.065 * pauldron_scale, 0.012], BRONZE if is_boss else STEEL_EDGE, 5)

    for rib, (z, width, front) in enumerate([
        (2.79, 0.43, 0.38),
        (2.59, 0.51, 0.43),
        (2.39, 0.50, 0.42),
        (2.19, 0.42, 0.36),
    ]):
        for side, label in [(-1, 'L'), (1, 'R')]:
            path = [
                (side * 0.07, -0.11, z + 0.025),
                (side * (width * 0.73), 0.02, z + 0.05),
                (side * width, 0.20, z + 0.01),
                (side * (width * 0.75), front, z - 0.07),
                (side * 0.12, front - 0.05, z - 0.06),
            ]
            bone_tube('Rib_%d_%s' % (rib, label), path,
                      [0.050, 0.068, 0.083, 0.070, 0.038],
                      BONE_LIGHT if rib in (0, 2) else IVORY, 5)

    # ===============================================================
    # 6. BACIA + TECIDO DE GUERRA (WARCLOTH)
    # ===============================================================
    for side, label in [(-1, 'L'), (1, 'R')]:
        bone_tube('PelvisWing_' + label,
                  [(0, -0.05, 1.83), (side * 0.34, -0.03, 1.78),
                   (side * 0.46, 0.02, 1.57), (side * 0.24, 0.00, 1.46)],
                  [0.11, 0.17, 0.16, 0.10], IVORY, 6)
        ico('HipJoint_' + label, (side * 0.25, 0.0, 1.47), 0.14,
            BONE_LIGHT, 1, (1.08, 0.92, 1.00))

    # ===============================================================
    # 7. BRACOS, PERNAS, ARMA E ESCUDO
    # ===============================================================
    for side, label in [(-1, 'L'), (1, 'R')]:
        bone_tube('UpperArm_' + label,
                  [(side * 0.70, 0, 2.82), (side * 0.79, 0, 2.49),
                   (side * 0.86, 0.015, 2.17)],
                  [0.11, 0.15, 0.095], IVORY, 7)
        ico('Elbow_' + label, (side * 0.86, 0.018, 2.15), 0.108,
            BONE_LIGHT, 1, (1, 0.85, 0.88))
        bone_tube('Forearm_' + label,
                  [(side * 0.87, 0.03, 2.10),
                   (side * 0.93, 0.04, 1.80),
                   (side * 0.98, 0.07, 1.49)],
                  [0.104, 0.119, 0.069], BONE_LIGHT, 7)
        ico('Wrist_' + label, (side * 0.98, 0.07, 1.46), 0.081,
            BONE_SHADOW, 1)
        ico('Palm_' + label, (side * 1.00, 0.075, 1.30), 0.13,
            IVORY, 1, (0.73, 0.63, 1.0))
        for finger in (-1, 1):
            fx = side * 1.0 + finger * 0.057
            bone_tube('Finger_%s_%d' % (label, finger),
                      [(fx, 0.075, 1.22), (fx, 0.09, 1.10)],
                      [0.038, 0.022], BONE_LIGHT, 5)

        bone_tube('Thigh_' + label,
                  [(side * 0.25, 0, 1.43), (side * 0.30, -0.015, 1.13),
                   (side * 0.31, -0.035, 0.86)],
                  [0.15, 0.16, 0.105], IVORY, 7)
        ico('Knee_' + label, (side * 0.31, 0.03, 0.83), 0.125,
            BONE_LIGHT, 1, (1.0, 0.82, 0.89))
        bone_tube('Shin_' + label,
                  [(side * 0.31, -0.03, 0.80), (side * 0.32, -0.02, 0.48),
                   (side * 0.33, -0.02, 0.20)],
                  [0.115, 0.121, 0.075], IVORY, 7)
        ico('Ankle_' + label, (side * 0.33, 0.0, 0.18), 0.078,
            BONE_SHADOW, 1)
        bone_tube('Foot_' + label,
                  [(side * 0.33, -0.02, 0.18), (side * 0.33, 0.18, 0.12),
                   (side * 0.33, 0.35, 0.105)],
                  [0.105, 0.15, 0.115], BONE_LIGHT, 6)
        for toe in (-1, 0, 1):
            tx = side * 0.33 + toe * 0.09
            bone_tube('Toe_%s_%d' % (label, toe),
                      [(tx, 0.27, 0.095), (tx + toe * 0.015, 0.43, 0.077)],
                      [0.060, 0.025], BONE_LIGHT, 5)

    # ===============================================================
    # 7B. ARMAMENTO DARK-FANTASY (Cutelo / Machado em hand.R e Broquel em forearm.L)
    # ===============================================================
    # Na pose de repouso (braço pendurado ao lado do corpo), a palma direita está em (1.00, 0.075, 1.30).
    # Construímos a arma apontando para +Y (frente), para que quando o braço levantar/girar, a lâmina corte à frente!
    if is_boss:
        # Grande Machado de Carrasco do Abismo (Executioner Great-Axe) em 'Palm_R_*' (osso hand.R)
        bone_tube('Palm_R_AxeShaft', [
            (1.00, -0.45, 1.15),
            (1.00,  0.10, 1.25),
            (1.00,  1.25, 1.48),
            (1.00,  1.95, 1.62),
        ], [0.065, 0.058, 0.062, 0.075], LEATHER, 6)
        # Lâmina colossal curva do Machado
        poly_yz('Palm_R_AxeBlade', [
            (1.15, 1.45),
            (1.88, 1.60),
            (2.05, 0.92),
            (1.62, 0.65),
            (1.05, 0.95),
        ], 0.96, 1.04, STEEL_EDGE)
        # Gume incandescente rúnico do Boss
        poly_yz('Palm_R_AxeRuneEdge', [
            (2.05, 0.92),
            (1.62, 0.65),
            (1.05, 0.95),
            (1.12, 1.06),
            (1.60, 0.80),
            (1.94, 1.02),
        ], 0.95, 1.05, RUNE_FIRE)
        # Espigão traseiro do Machado
        poly_yz('Palm_R_AxeBackSpike', [
            (1.30, 1.50),
            (1.55, 2.02),
            (1.72, 1.56),
        ], 0.97, 1.03, BRONZE)
    else:
        # Cutelo / Cimitarra Serrilhada da Cripta (Ancient Crypt Cleaver) em 'Palm_R_*' (osso hand.R)
        bone_tube('Palm_R_SwordGrip', [
            (1.00, -0.22, 1.22),
            (1.00,  0.26, 1.26),
        ], [0.058, 0.052], LEATHER, 6)
        bevel_box('Palm_R_SwordGuard', (1.00, 0.28, 1.26), (0.14, 0.08, 0.42), BRONZE, 0.015)
        poly_yz('Palm_R_CleaverBlade', [
            (0.30, 1.18),
            (1.10, 1.14),
            (1.62, 1.24),
            (1.48, 1.48),
            (0.95, 1.40),
            (0.30, 1.34),
        ], 0.975, 1.025, STEEL_EDGE)

    # Broquel de Ferro Cravejado no antebraço esquerdo ('Forearm_L_*' vincula a 'forearm.L')
    shield_rad = 0.56 if is_boss else 0.44
    ico('Forearm_L_BucklerPlate', (-1.08, 0.16, 1.72), shield_rad, IRON_DARK, 1, (0.22, 1.0, 1.08))
    ico('Forearm_L_BucklerBoss', (-1.16, 0.18, 1.72), shield_rad * 0.42, BRONZE, 1, (0.55, 0.85, 0.85))
    bone_tube('Forearm_L_BucklerSpike', [
        (-1.18, 0.18, 1.72),
        (-1.42 if is_boss else -1.34, 0.20, 1.72),
    ], [0.06, 0.012], STEEL_EDGE, 5)

    # ===============================================================
    # 8. CINTO, FIVELA E MANTOS DE GUERRA
    # ===============================================================
    bevel_box('Belt', (0, 0.02, 1.74), (0.96, 0.29, 0.19), LEATHER, 0.055)
    bevel_box('Buckle', (0, 0.192, 1.74), (0.26, 0.06, 0.20), BRONZE, 0.025)

    poly_xz('ClothFront', [
        (-0.40, 1.68), (0.41, 1.68), (0.42, 1.04),
        (0.25, 1.18), (0.05, 0.94), (-0.18, 1.14), (-0.41, 1.02),
    ], 0.19, 0.05, CLOTH)
    poly_xz('ClothLeft', [
        (-0.49, 1.68), (-0.28, 1.68), (-0.28, 1.18), (-0.51, 1.12),
    ], 0.02, -0.095, CLOTH)
    poly_xz('ClothRight', [
        (0.30, 1.68), (0.51, 1.68), (0.53, 1.12), (0.30, 1.20),
    ], 0.02, -0.095, CLOTH)

    if is_boss:
        # Capa Traseira Despedaçada do Carrasco Profanado (vinculada a 'Spine_*')
        poly_xz('Spine_BossCape', [
            (-0.62, 2.92), (0.62, 2.92),
            (0.78, 1.15), (0.38, 1.38), (0.0, 0.95), (-0.42, 1.35), (-0.78, 1.12),
        ], -0.18, -0.26, CLOTH)

    # ===============================================================
    # 9. ESCALA DE JOGO: ALTURA ~1.8, PLANTA DOS PES EM Z=0
    # ===============================================================
    root.scale = (GAME_SCALE,) * 3
    bpy.context.view_layer.update()

    bpy.ops.object.select_all(action='DESELECT')
    root.select_set(True)
    bpy.context.view_layer.objects.active = root

    mesh_count = sum(1 for obj in root.children_recursive if obj.type == 'MESH')
    print('SkeletonEnemy v0.16 (%s) gerado: %d malhas.' % ('BOSS' if is_boss else 'WARRIOR', mesh_count))
    return root


if __name__ == '__main__':
    build_skeleton_model(is_boss=False)
