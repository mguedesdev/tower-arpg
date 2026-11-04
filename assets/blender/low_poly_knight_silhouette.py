"""Cavaleiro Estilizado Dark-Fantasy Low-Poly V1.2 (Silhueta Heroica em V).

Modelagem orgânica facetada por anéis poligonais (lofting), juntas esféricas
nas articulações, elmo Barbute/Crusader com viseira em T profunda, olhos
brilhantes, crista dourada e penacho escarlate, peitoral quilhado 3D com
emblema solar em alto-relevo, ombreiras aladas em camadas, escarcelas,
manoplas, grevas anatômicas, escudo Heater curvado e espada longa em diamante.
"""
import bpy
import bmesh
from math import cos, sin, pi, radians
from mathutils import Vector


def clear_scene():
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    for material in list(bpy.data.materials):
        bpy.data.materials.remove(material)


def make_material(name, color, roughness=0.72, emit=0.0):
    material = bpy.data.materials.new(name)
    if not material.node_tree:
        material.use_nodes = True
    bsdf = material.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    if emit > 0.0 and "Emission Color" in bsdf.inputs:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    material.diffuse_color = (*color, 1.0)
    return material


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
    mesh.materials.append(material)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    return obj


def add_loft(parent, name, rings, segments, material, phase_offset=0.0):
    """Cria uma malha facetada low-poly a partir de anéis (cx, cy, z, rx, ry)."""
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


def add_limb_tube(parent, name, path_points, radii_xy, segments, material):
    """Tubo anatômico afilado ao longo de uma curva 3D [(x,y,z), ...] com raios [(rx,ry), ...]."""
    pts = [Vector(p) for p in path_points]
    verts = []
    for i, center in enumerate(pts):
        tangent = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
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


def add_ico_joint(parent, name, location, scale_xyz, material, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=0.5, location=location)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale_xyz
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    obj.parent = parent
    return obj


def add_curved_plate(parent, name, profile_xz, front_y_fn, thickness, material):
    """Cria uma placa de armadura 3D com curvatura orgânica em Y."""
    n = len(profile_xz)
    front_verts = []
    back_verts = []
    for x, z in profile_xz:
        fy = front_y_fn(x, z)
        front_verts.append((x, fy, z))
        back_verts.append((x, fy + thickness, z))
    verts = front_verts + back_verts
    faces = [tuple(range(n)), tuple(reversed(range(n, 2 * n)))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return _finalize_mesh_obj(parent, name, verts, faces, material)


def build_knight():
    clear_scene()

    # Paleta Dark-Fantasy Heroica de alto contraste
    steel_dark = make_material("Steel_Dark", (0.24, 0.26, 0.32), roughness=0.50)
    steel = make_material("Steel", (0.48, 0.51, 0.58), roughness=0.42)
    steel_light = make_material("Steel_Light", (0.68, 0.71, 0.78), roughness=0.35)
    blade_steel = make_material("Blade", (0.82, 0.85, 0.92), roughness=0.26)
    gold = make_material("Gold", (0.92, 0.65, 0.20), roughness=0.38)
    cloth_dark = make_material("Cloth", (0.15, 0.13, 0.17), roughness=0.88)
    leather = make_material("Leather", (0.28, 0.16, 0.10), roughness=0.82)
    crimson = make_material("Red", (0.66, 0.09, 0.11), roughness=0.76)
    cape_crimson = make_material("Cape_Red", (0.50, 0.06, 0.08), roughness=0.82)
    visor_dark = make_material("Visor_Shadow", (0.02, 0.02, 0.03), roughness=0.95)
    eye_glow = make_material("Eyes", (0.98, 0.76, 0.24), roughness=0.20, emit=2.0)

    bpy.ops.object.empty_add(type="PLAIN_AXES", location=(0, 0, 0))
    root = bpy.context.active_object
    root.name = "Knight"
    root.scale = (0.33, 0.33, 0.33)

    # ==================== 1. TRONCO, PEITORAL QUILHADO & GORGET (spine) ====================
    add_loft(root, "Body", [
        (0.0, 0.00, 2.55, 0.42, 0.27),
        (0.0, 0.00, 2.85, 0.47, 0.30),
        (0.0, -0.01, 3.20, 0.58, 0.35),
        (0.0, -0.01, 3.60, 0.65, 0.37),
        (0.0, 0.00, 3.88, 0.52, 0.30),
    ], 10, cloth_dark, phase_offset=pi / 10.0)

    # Couraça (Breastplate) esculpida em V com quilha frontal pronunciada
    add_loft(root, "Breastplate", [
        (0.0, -0.02, 2.82, 0.45, 0.31),
        (0.0, -0.05, 3.08, 0.55, 0.38),
        (0.0, -0.07, 3.44, 0.67, 0.43),
        (0.0, -0.04, 3.76, 0.62, 0.37),
        (0.0, 0.00, 3.92, 0.46, 0.29),
    ], 8, steel, phase_offset=0.0)

    # Emblema solar dourado em alto-relevo na frente do peitoral
    star_pts = [
        (0.0, 3.70), (0.07, 3.49), (0.26, 3.44), (0.08, 3.36),
        (0.0, 3.12), (-0.08, 3.36), (-0.26, 3.44), (-0.07, 3.49),
    ]
    add_curved_plate(
        root, "Chest_Star", star_pts,
        lambda x, z: -0.53 + 0.14 * abs(x), 0.06, gold
    )

    add_loft(root, "Neck", [
        (0.0, 0.0, 3.82, 0.34, 0.30),
        (0.0, 0.0, 4.02, 0.28, 0.26),
        (0.0, 0.0, 4.18, 0.25, 0.24),
    ], 8, steel_dark)

    add_loft(root, "Scarf", [
        (0.0, -0.02, 3.80, 0.49, 0.36),
        (0.0, -0.03, 3.98, 0.41, 0.33),
        (0.0, -0.01, 4.12, 0.34, 0.29),
    ], 8, crimson, phase_offset=pi / 8.0)

    # ==================== 2. QUADRIL, CINTO, ESCARCELAS & TABARDO (hips) ====================
    add_loft(root, "Waist_Guard", [
        (0.0, 0.00, 2.12, 0.54, 0.34),
        (0.0, -0.01, 2.42, 0.48, 0.32),
        (0.0, -0.02, 2.72, 0.45, 0.30),
    ], 8, steel_dark)

    tabard_pts = [(-0.27, 2.68), (0.27, 2.68), (0.33, 1.88), (0.0, 1.66), (-0.33, 1.88)]
    add_curved_plate(
        root, "Waist_Trim", tabard_pts,
        lambda x, z: -0.35 + 0.06 * abs(x) - 0.03 * (2.68 - z), 0.06, crimson
    )

    add_loft(root, "Belt", [
        (0.0, -0.01, 2.60, 0.50, 0.34),
        (0.0, -0.01, 2.76, 0.49, 0.34),
    ], 10, leather)

    buckle_pts = [(-0.17, 2.79), (0.17, 2.79), (0.20, 2.68), (0.17, 2.57), (-0.17, 2.57), (-0.20, 2.68)]
    add_curved_plate(root, "Buckle", buckle_pts, lambda x, z: -0.38, 0.05, gold)
    center_pts = [(-0.09, 2.74), (0.09, 2.74), (0.09, 2.62), (-0.09, 2.62)]
    add_curved_plate(root, "Buckle_Center", center_pts, lambda x, z: -0.40, 0.04, crimson)

    # ==================== 3. ELMO CRUSADER / BARBUTE FACETADO & PENACHO (head) ====================
    add_loft(root, "Head", [
        (0.0, 0.02, 4.06, 0.31, 0.32),
        (0.0, -0.04, 4.24, 0.39, 0.41),
        (0.0, -0.06, 4.54, 0.43, 0.44),
        (0.0, -0.03, 4.84, 0.41, 0.42),
        (0.0, 0.00, 5.08, 0.32, 0.35),
        (0.0, 0.02, 5.22, 0.14, 0.18),
    ], 10, steel_light, phase_offset=pi / 10.0)

    # Fenda em T da viseira projetada à frente do casco para leitura nítida
    visor_pts = [
        (-0.33, 4.68), (0.0, 4.62), (0.33, 4.68),
        (0.28, 4.51), (0.065, 4.50), (0.05, 4.18),
        (-0.05, 4.18), (-0.065, 4.50), (-0.28, 4.51),
    ]
    add_curved_plate(
        root, "Hair_Base", visor_pts,
        lambda x, z: -0.52 + 0.24 * (x * x), 0.07, visor_dark
    )

    # Crista central dourada no topo do elmo descendo até o nariz da viseira
    crest_pts = [
        (0.0, -0.51, 4.58), (0.0, -0.45, 4.86), (0.0, -0.18, 5.22),
        (0.0, 0.18, 5.26), (0.0, 0.42, 4.92),
    ]
    add_limb_tube(
        root, "Hair_Strand_Center", crest_pts,
        [(0.045, 0.05), (0.06, 0.08), (0.07, 0.12), (0.065, 0.11), (0.05, 0.07)],
        6, gold
    )

    # Penacho escarlate volumoso caindo atrás do elmo
    plume_main = [
        (0.0, 0.08, 5.24), (0.0, 0.38, 5.42), (0.0, 0.72, 5.18),
        (0.0, 0.90, 4.74), (0.0, 0.84, 4.30),
    ]
    add_limb_tube(
        root, "Hair_Back", plume_main,
        [(0.07, 0.07), (0.16, 0.20), (0.19, 0.24), (0.14, 0.18), (0.06, 0.08)],
        8, crimson
    )
    plume_top = [
        (0.0, 0.14, 5.28), (0.0, 0.48, 5.52), (0.0, 0.82, 5.28),
    ]
    add_limb_tube(
        root, "Hair_Spike_Left", plume_top,
        [(0.05, 0.05), (0.12, 0.15), (0.05, 0.06)],
        6, cape_crimson
    )

    for side, sx in (("L", 1), ("R", -1)):
        eye_pts = [
            (sx * 0.08, 4.61), (sx * 0.24, 4.64),
            (sx * 0.21, 4.55), (sx * 0.09, 4.55),
        ]
        add_curved_plate(
            root, "Eye_" + side, eye_pts,
            lambda x, z: -0.528 + 0.24 * (x * x), 0.03, eye_glow
        )
        brow_pts = [
            (sx * 0.03, -0.52, 4.64),
            (sx * 0.19, -0.49, 4.70),
            (sx * 0.34, -0.38, 4.64),
        ]
        add_limb_tube(
            root, "Eyebrow_" + side, brow_pts,
            [(0.048, 0.048), (0.052, 0.052), (0.042, 0.042)],
            6, gold
        )
        # Protetores de mandíbula/bochecha facetados
        add_ico_joint(root, "Ear_" + side, (sx * 0.36, -0.16, 4.36), (0.16, 0.28, 0.28), steel_dark)

    # ==================== 4. CAPA DRAPEADA EM 3D (cape) ====================
    cape_outline = [
        (-0.52, 3.92), (0.52, 3.92),
        (0.74, 2.75), (0.94, 1.12),
        (0.50, 0.88), (0.0, 0.72), (-0.50, 0.88),
        (-0.94, 1.12), (-0.74, 2.75),
    ]
    add_curved_plate(
        root, "Cape", cape_outline,
        lambda x, z: 0.30 + 0.11 * (1.0 - min(1.0, abs(x))) + 0.04 * (3.92 - z) * 0.25,
        0.075, cape_crimson
    )

    # ==================== 5. MEMBROS ARTICULADOS & ARMADURAS (L / R) ====================
    for side, sx in (("L", 1), ("R", -1)):
        add_limb_tube(
            root, "Thigh_" + side,
            [(sx * 0.37, 0.00, 2.32), (sx * 0.37, -0.01, 1.82), (sx * 0.37, 0.00, 1.30)],
            [(0.24, 0.25), (0.22, 0.23), (0.18, 0.19)],
            8, steel_dark
        )

        add_ico_joint(root, "Knee_Guard_" + side, (sx * 0.37, -0.14, 1.32), (0.42, 0.38, 0.44), steel_light)
        add_loft(root, "Knee_Band_" + side, [
            (sx * 0.37, -0.01, 1.18, 0.20, 0.21),
            (sx * 0.37, -0.01, 1.42, 0.21, 0.22),
        ], 8, gold)

        add_limb_tube(
            root, "Boot_Shaft_" + side,
            [(sx * 0.37, 0.00, 1.28), (sx * 0.37, 0.02, 0.82), (sx * 0.37, 0.00, 0.28)],
            [(0.19, 0.20), (0.21, 0.22), (0.15, 0.16)],
            8, steel
        )

        add_limb_tube(
            root, "Boot_Foot_" + side,
            [
                (sx * 0.37, 0.12, 0.22),
                (sx * 0.37, -0.08, 0.18),
                (sx * 0.37, -0.34, 0.14),
                (sx * 0.37, -0.54, 0.09),
            ],
            [(0.16, 0.18), (0.19, 0.18), (0.18, 0.14), (0.10, 0.08)],
            8, steel_light
        )

        add_limb_tube(
            root, "Upper_Arm_" + side,
            [(sx * 0.88, 0.00, 3.86), (sx * 0.92, -0.01, 3.45), (sx * 0.95, -0.02, 3.05)],
            [(0.20, 0.20), (0.18, 0.18), (0.16, 0.16)],
            8, cloth_dark
        )

        # Ombreira 3D robusta e imponente em camadas
        add_loft(root, "Pauldron_" + side, [
            (sx * 0.96, 0.00, 3.52, 0.37, 0.34),
            (sx * 0.92, 0.00, 3.82, 0.40, 0.37),
            (sx * 0.80, 0.00, 4.08, 0.31, 0.29),
            (sx * 0.66, 0.00, 4.18, 0.15, 0.17),
        ], 8, steel_light)

        add_loft(root, "Pauldron_Trim_" + side, [
            (sx * 0.97, 0.00, 3.49, 0.385, 0.355),
            (sx * 0.95, 0.00, 3.60, 0.390, 0.360),
        ], 8, gold)

        add_ico_joint(root, "Elbow_Band_" + side, (sx * 0.96, 0.02, 3.05), (0.38, 0.38, 0.36), gold)

        add_limb_tube(
            root, "Forearm_" + side,
            [(sx * 0.95, -0.02, 3.05), (sx * 1.02, -0.03, 2.78), (sx * 1.08, -0.04, 2.52)],
            [(0.17, 0.17), (0.18, 0.18), (0.14, 0.15)],
            8, steel
        )

        add_loft(root, "Wrist_Band_" + side, [
            (sx * 1.08, -0.04, 2.48, 0.16, 0.16),
            (sx * 1.07, -0.04, 2.58, 0.16, 0.16),
        ], 8, gold)

        add_ico_joint(root, "Hand_" + side, (sx * 1.09, -0.05, 2.35), (0.30, 0.34, 0.36), steel_dark)

    # ==================== 6. ESPADA LONGA EM SEÇÃO DE DIAMANTE (sword.R) ====================
    add_ico_joint(root, "Sword_Pommel", (-1.11, -0.13, 2.66), (0.22, 0.22, 0.22), gold)
    add_limb_tube(
        root, "Sword_Grip",
        [(-1.11, -0.13, 2.60), (-1.13, -0.13, 2.35), (-1.15, -0.14, 2.14)],
        [(0.065, 0.065), (0.075, 0.075), (0.07, 0.07)],
        8, leather
    )
    add_limb_tube(
        root, "Sword_Guard",
        [(-1.48, -0.14, 2.16), (-1.16, -0.14, 2.11), (-0.84, -0.14, 2.16)],
        [(0.05, 0.065), (0.095, 0.115), (0.05, 0.065)],
        6, gold
    )
    add_ico_joint(root, "Sword_Gem", (-1.16, -0.22, 2.11), (0.15, 0.10, 0.15), crimson)

    add_limb_tube(
        root, "Sword_Blade",
        [
            (-1.16, -0.14, 2.08),
            (-1.19, -0.14, 1.48),
            (-1.23, -0.14, 0.80),
            (-1.26, -0.14, 0.30),
            (-1.28, -0.14, 0.04),
        ],
        [(0.16, 0.048), (0.15, 0.042), (0.13, 0.036), (0.085, 0.026), (0.01, 0.008)],
        4, blade_steel
    )

    # ==================== 7. ESCUDO HEATER CURVADO EM 3D (forearm.L) ====================
    shield_outer = [
        (0.92, 3.28), (1.52, 3.48), (2.06, 3.16),
        (2.04, 2.16), (1.54, 1.40), (0.94, 2.14),
    ]
    add_curved_plate(
        root, "Shield_Rim", shield_outer,
        lambda x, z: -0.46 - 0.14 * (1.0 - ((x - 1.50) / 0.60) ** 2),
        0.10, gold
    )

    shield_inner = [
        (1.04, 3.16), (1.52, 3.34), (1.92, 3.08),
        (1.90, 2.22), (1.54, 1.62), (1.06, 2.20),
    ]
    add_curved_plate(
        root, "Shield_Face", shield_inner,
        lambda x, z: -0.49 - 0.14 * (1.0 - ((x - 1.50) / 0.60) ** 2),
        0.08, crimson
    )

    shield_emblem = [
        (1.52, 3.22), (1.58, 2.82), (1.80, 2.72), (1.58, 2.62),
        (1.52, 1.88), (1.46, 2.62), (1.24, 2.72), (1.46, 2.82),
    ]
    add_curved_plate(
        root, "Shield_Star", shield_emblem,
        lambda x, z: -0.52 - 0.14 * (1.0 - ((x - 1.50) / 0.60) ** 2),
        0.06, gold
    )

    # ==================== 8. ILUMINAÇÃO & CÂMERA DO BLENDER ====================
    lights = (
        ("Key_Light", (radians(50), 0, radians(-35)), 3.0),
        ("Fill_Light", (radians(55), 0, radians(40)), 1.2),
        ("Rim_Light", (radians(-50), 0, 0), 1.5),
    )
    for name, rotation, energy in lights:
        bpy.ops.object.light_add(type="SUN", rotation=rotation)
        light = bpy.context.active_object
        light.name = name
        light.data.energy = energy

    bpy.ops.object.camera_add(location=(0, -6, 0.9), rotation=(radians(90), 0, 0))
    camera = bpy.context.active_object
    camera.name = "Front_Camera"
    camera.data.type = "ORTHO"
    camera.data.ortho_scale = 2.6
    bpy.context.scene.camera = camera

    scene = bpy.context.scene
    if scene.world is None:
        scene.world = bpy.data.worlds.new("World")
    world = scene.world
    if not world.node_tree:
        world.use_nodes = True
    background = world.node_tree.nodes.get("Background")
    if background:
        background.inputs["Color"].default_value = (0.095, 0.085, 0.105, 1.0)
        background.inputs["Strength"].default_value = 0.6

    scene.render.resolution_x = 1024
    scene.render.resolution_y = 1024
    scene.render.filepath = "//knight_lowpoly.png"

    screen = bpy.context.screen
    if screen:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                area.spaces[0].shading.type = "MATERIAL"


build_knight()
