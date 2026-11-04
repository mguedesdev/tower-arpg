"""
ESQUELETO INIMIGO — Dark Fantasy Low Poly, v0.1
Blender 4.x / 5.x (bpy)

Cria UM personagem inimigo humanoide low-poly, sem armature/rig e SEM animacoes.
Frente = -Y | Cima = +Z | Altura aprox. 2.10 unidades.
Nao modifica os arquivos do projeto Godot.

Executar no Blender: Scripting > Open > Run Script.
O script remove apenas uma colecao preexistente chamada ENEMY_SKELETON_LP
(para permitir executar novamente sem duplicar o esqueleto).
Salve como .blend quando aprovar o visual. Exportacao e rig ficam para depois.
"""

import bpy
import math
from mathutils import Vector

# --------------------------------------------------------------
# CONFIGURACAO
# --------------------------------------------------------------
CHARACTER_COLLECTION = "ENEMY_SKELETON_LP"
PREVIEW_COLLECTION = "SKELETON_PREVIEW_LIGHTS"
CREATE_PREVIEW = True
EYE_GLOW = True

# --------------------------------------------------------------
# FUNCOES
# --------------------------------------------------------------

def delete_collection(name):
    existing = bpy.data.collections.get(name)
    if existing is None:
        return
    for obj in list(existing.all_objects):
        bpy.data.objects.remove(obj, do_unlink=True)
    bpy.data.collections.remove(existing)


def make_collection(name):
    col = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(col)
    return col


def move_to_collection(obj, target):
    for c in list(obj.users_collection):
        c.objects.unlink(obj)
    target.objects.link(obj)


def create_material(name, color, roughness=0.9, metallic=0.0,
                    emission_strength=0.0):
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1.0)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = (*color, 1.0)
        bsdf.inputs["Roughness"].default_value = roughness
        bsdf.inputs["Metallic"].default_value = metallic
        if emission_strength > 0.0:
            name_emission = "Emission Color" if "Emission Color" in bsdf.inputs else "Emission"
            if name_emission in bsdf.inputs:
                bsdf.inputs[name_emission].default_value = (*color, 1.0)
            if "Emission Strength" in bsdf.inputs:
                bsdf.inputs["Emission Strength"].default_value = emission_strength
    return mat


def parent_mesh(obj, parent):
    """Mantem a posicao global. Todas as malhas continuam separadas e editaveis."""
    world = obj.matrix_world.copy()
    obj.parent = parent
    obj.matrix_world = world
    return obj


def finalize_mesh(obj, name, mat, collection, parent=None):
    obj.name = name
    move_to_collection(obj, collection)
    if len(obj.data.materials) == 0:
        obj.data.materials.append(mat)
    else:
        obj.data.materials[0] = mat
    if parent:
        parent_mesh(obj, parent)
    if obj.type == 'MESH':
        for polygon in obj.data.polygons:
            polygon.use_smooth = False
    return obj


def bone_joint(name, center, size, mat, collection, parent):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=center)
    obj = bpy.context.object
    obj.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finalize_mesh(obj, name, mat, collection, parent)


def box(name, position, dimensions, mat, collection, parent=None, bevel=0.0,
        rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=position)
    obj = bpy.context.object
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel > 0.0:
        m = obj.modifiers.new("Bevel_Facets", 'BEVEL')
        m.width = bevel
        m.segments = 1
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.modifier_apply(modifier=m.name)
    obj.rotation_euler = rotation
    return finalize_mesh(obj, name, mat, collection, parent)


def tapered_bone(name, p1, p2, radius1, radius2, mat, collection, parent,
                 vertices=8):
    p1, p2 = Vector(p1), Vector(p2)
    direction = p2 - p1
    if direction.length < 0.0001:
        return None
    center = (p1 + p2) * 0.5
    # Base do cone: origem p1; topo: destino p2.
    bpy.ops.mesh.primitive_cone_add(
        vertices=vertices,
        radius1=radius1,
        radius2=radius2,
        depth=direction.length,
        location=center
    )
    obj = bpy.context.object
    obj.rotation_mode = 'QUATERNION'
    obj.rotation_quaternion = Vector((0, 0, 1)).rotation_difference(direction)
    return finalize_mesh(obj, name, mat, collection, parent)


def poly_strip(name, verts, faces, mat, collection, parent):
    mesh = bpy.data.meshes.new(name + "_mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    collection.objects.link(obj)
    return finalize_mesh(obj, name, mat, collection, parent)


def connect(name, positions, radius, mat, collection, parent, end_radius=0.75):
    for i in range(len(positions) - 1):
        tapered_bone("%s_%02d" % (name, i + 1), positions[i], positions[i + 1],
                     radius, radius * end_radius, mat, collection, parent)


def segment_group(name, location, collection, root):
    node = bpy.data.objects.new(name, None)
    node.empty_display_type = 'SPHERE'
    node.empty_display_size = 0.065
    node.location = location
    collection.objects.link(node)
    parent_mesh(node, root)
    return node


# --------------------------------------------------------------
# CENA — REEXECUCAO SEGURA
# --------------------------------------------------------------
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')

delete_collection(CHARACTER_COLLECTION)
if CREATE_PREVIEW:
    delete_collection(PREVIEW_COLLECTION)

collection = make_collection(CHARACTER_COLLECTION)
root = bpy.data.objects.new("SKEL_ROOT__NO_RIG", None)
root.empty_display_type = 'CUBE'
root.empty_display_size = 0.12
collection.objects.link(root)

# Materiais em tons de osso antigo, ferro oxidado, couro podre e energia verde.
BONE = create_material("SKEL_Bone_Aged", (0.69, 0.64, 0.51))
BONE_LIGHT = create_material("SKEL_Bone_Highlight", (0.85, 0.79, 0.63))
BONE_DARK = create_material("SKEL_Bone_Shadow", (0.45, 0.42, 0.34))
SOCKET = create_material("SKEL_DeepSockets", (0.035, 0.045, 0.038))
EYES = create_material("SKEL_Spectral_Eyes", (0.30, 0.95, 0.57), emission_strength=2.4)
IRON = create_material("SKEL_Rusted_Iron", (0.27, 0.23, 0.19), metallic=0.48)
IRON_EDGE = create_material("SKEL_Iron_Edge", (0.38, 0.32, 0.26), metallic=0.52)
CLOTH = create_material("SKEL_Ragged_Cloth", (0.18, 0.17, 0.16))
CLOTH_EDGE = create_material("SKEL_Cloth_Dust", (0.27, 0.26, 0.22))
LEATHER = create_material("SKEL_Old_Leather", (0.19, 0.11, 0.08))
MOSS = create_material("SKEL_Moss", (0.15, 0.21, 0.14))

# grupos logicos de objetos para facilitar rig humanoide posterior
hip = segment_group("SKEL_GROUP_Pelvis", (0, 0, 0.86), collection, root)
torso = segment_group("SKEL_GROUP_Torso", (0, 0, 1.26), collection, root)
head = segment_group("SKEL_GROUP_Head", (0, 0, 1.76), collection, root)
arm_groups = {}
leg_groups = {}
for side in ("L", "R"):
    xsign = 1 if side == "L" else -1
    arm_groups[side] = segment_group("SKEL_GROUP_Arm_" + side,
                                     (xsign * 0.31, 0, 1.46), collection, root)
    leg_groups[side] = segment_group("SKEL_GROUP_Leg_" + side,
                                     (xsign * 0.17, 0, 0.85), collection, root)

# --------------------------------------------------------------
# CRANIO — frontal (-Y), cavidades e mandibula separadas
# --------------------------------------------------------------
bone_joint("Head_Cranium", (0, 0.0, 1.85), (0.238, 0.196, 0.253),
           BONE, collection, head)
bone_joint("Head_Forehead", (0, -0.084, 1.91), (0.206, 0.130, 0.157),
           BONE_LIGHT, collection, head)

for sx, side in ((-1, "R"), (1, "L")):
    bone_joint("EyeSocket_" + side, (sx * 0.100, -0.188, 1.84),
               (0.077, 0.023, 0.071), SOCKET, collection, head)
    if EYE_GLOW:
        bone_joint("EyeGlow_" + side, (sx * 0.100, -0.211, 1.845),
                   (0.028, 0.014, 0.027), EYES, collection, head)
    tapered_bone("Brow_" + side,
                 (sx * 0.035, -0.205, 1.919),
                 (sx * 0.174, -0.17, 1.937),
                 0.025, 0.018, BONE_LIGHT, collection, head, 6)
    bone_joint("Cheek_" + side, (sx * 0.175, -0.148, 1.748),
               (0.082, 0.054, 0.058), BONE, collection, head)

# Nariz: abertura triangular negra.
poly_strip("NoseCavity", [
    (-0.029, -0.210, 1.767), (0.029, -0.210, 1.767),
    (0.0, -0.223, 1.714)
], [(0, 1, 2)], SOCKET, collection, head)

# Maxilar e mandibula: leve fenda escura entre os dentes.
box("UpperJaw", (0, -0.127, 1.688), (0.254, 0.139, 0.088),
    BONE_LIGHT, collection, head, bevel=0.022)
box("MouthGap", (0, -0.205, 1.651), (0.195, 0.020, 0.033),
    SOCKET, collection, head)
box("LowerJaw", (0, -0.124, 1.621), (0.236, 0.116, 0.072),
    BONE, collection, head, bevel=0.018)
bone_joint("Chin", (0, -0.16, 1.586), (0.117, 0.080, 0.044),
           BONE, collection, head)
for i in range(4):
    x = -0.070 + i * 0.046
    box("ToothUpper_%02d" % i, (x, -0.211, 1.658),
        (0.028, 0.014, 0.039), BONE_LIGHT, collection, head)

# Vertebras cervicais.
for i in range(3):
    z = 1.55 - i * 0.065
    bone_joint("NeckVertebra_%02d" % i, (0, 0.013, z),
               (0.065, 0.058, 0.042), BONE, collection, torso)

# --------------------------------------------------------------
# TRONCO — caixa toracica aberta com costelas curvadas
# --------------------------------------------------------------
for i in range(8):
    z = 1.08 + i * 0.059
    bone_joint("SpineVertebra_%02d" % i, (0, 0.069, z),
               (0.066, 0.075, 0.048), BONE_DARK if i % 3 == 0 else BONE,
               collection, torso)

# Esterno no centro frente.
tapered_bone("Sternum", (0, -0.169, 1.08), (0, -0.164, 1.46),
             0.052, 0.047, BONE_LIGHT, collection, torso)
for side, sx in (("L", 1), ("R", -1)):
    connect("Clavicle_" + side, [
        (sx * 0.025, -0.03, 1.49),
        (sx * 0.185, -0.078, 1.515),
        (sx * 0.302, -0.025, 1.475)
    ], 0.036, BONE_LIGHT, collection, torso)

    for i, z in enumerate([1.40, 1.33, 1.26, 1.19]):
        widen = (1.0 - i * 0.04)
        connect("Rib_%s_%d" % (side, i + 1), [
            (sx * 0.078, 0.073, z + 0.025),
            (sx * 0.237 * widen, 0.055, z + 0.018),
            (sx * 0.302 * widen, -0.038, z - 0.008),
            (sx * 0.155 * widen, -0.154, z - 0.039),
            (sx * 0.058, -0.172, z - 0.044)
        ], 0.024, BONE, collection, torso, end_radius=0.84)

# Espinha terminando em pelvis, ossos ilíacos e sacro.
bone_joint("Sacrum", (0, 0.03, 0.88), (0.110, 0.078, 0.155),
           BONE, collection, hip)
for side, sx in (("L", 1), ("R", -1)):
    connect("HipCrest_" + side, [
        (sx * 0.045, 0.015, 0.96),
        (sx * 0.205, 0.008, 1.005),
        (sx * 0.270, -0.030, 0.905),
        (sx * 0.198, -0.079, 0.830),
        (sx * 0.063, -0.065, 0.805)
    ], 0.051, BONE_LIGHT, collection, hip)

# Tiras de tecido rasgado presas na cintura: assimetria e silhueta.
box("Belt", (0, -0.130, 0.95), (0.52, 0.11, 0.105),
    LEATHER, collection, hip, bevel=0.012)
box("Belt_Buckle", (0.045, -0.198, 0.952), (0.080, 0.025, 0.083),
    IRON_EDGE, collection, hip)
poly_strip("Loincloth_Front", [
    (-0.205, -0.180, 0.92), (0.145, -0.180, 0.92),
    (0.190, -0.215, 0.69), (0.083, -0.233, 0.48),
    (-0.014, -0.247, 0.56), (-0.122, -0.225, 0.47),
    (-0.226, -0.205, 0.67)
], [(0, 1, 2, 3, 4, 5, 6)], CLOTH, collection, hip)
poly_strip("Loincloth_Back", [
    (-0.17, 0.11, 0.93), (0.20, 0.11, 0.93),
    (0.18, 0.15, 0.59), (0.02, 0.14, 0.46),
    (-0.15, 0.13, 0.62)
], [(0, 1, 2, 3, 4)], CLOTH_EDGE, collection, hip)

# --------------------------------------------------------------
# BRACOS — postura A, juntas destacadas, dedos curtos
# --------------------------------------------------------------
for side, sx in (("L", 1), ("R", -1)):
    shoulder = (sx * 0.325, 0.000, 1.47)
    elbow = (sx * 0.485, -0.005, 1.193)
    wrist = (sx * 0.562, -0.068, 0.931)
    bone_joint("ShoulderJoint_" + side, shoulder,
               (0.086, 0.085, 0.079), BONE_LIGHT, collection, arm_groups[side])
    tapered_bone("Humerus_" + side, shoulder, elbow,
                 0.070, 0.056, BONE, collection, arm_groups[side])
    bone_joint("ElbowJoint_" + side, elbow,
               (0.068, 0.065, 0.074), BONE_LIGHT, collection, arm_groups[side])
    tapered_bone("Ulna_" + side, (elbow[0] - sx*0.026, -0.015, 1.175),
                 (wrist[0] - sx*0.025, -0.067, 0.960),
                 0.035, 0.029, BONE, collection, arm_groups[side])
    tapered_bone("Radius_" + side, (elbow[0] + sx*0.027, 0.010, 1.175),
                 (wrist[0] + sx*0.028, -0.067, 0.960),
                 0.034, 0.025, BONE, collection, arm_groups[side])
    bone_joint("WristJoint_" + side, wrist,
               (0.049, 0.049, 0.047), BONE_LIGHT, collection, arm_groups[side])
    box("Palm_" + side, (sx*0.575, -0.083, 0.844),
        (0.106, 0.079, 0.157), BONE, collection, arm_groups[side], bevel=0.012)
    for finger in range(3):
        fx = sx * (0.540 + finger*0.037)
        tapered_bone("Finger_%s_%d" % (side, finger),
                     (fx, -0.090, 0.775), (fx + sx*0.009, -0.103, 0.689 - abs(1-finger)*0.013),
                     0.016, 0.011, BONE_LIGHT, collection, arm_groups[side], vertices=6)

# Um ombro com placa de ferro deteriorada (silhueta assimetrica).
bone_joint("RustShoulderArmor", (-0.334, 0.004, 1.480),
           (0.123, 0.113, 0.082), IRON, collection, arm_groups["R"])
box("RustArmorEdge", (-0.368, -0.081, 1.489),
    (0.190, 0.040, 0.058), IRON_EDGE, collection, arm_groups["R"],
    bevel=0.012, rotation=(0.0, 0.0, -0.17))

# Braceletes de couro velho nas laterais, pouco contraste.
for side, sx in (("L", 1), ("R", -1)):
    box("WristBand_" + side,
        (sx * 0.556, -0.062, 0.971),
        (0.116, 0.112, 0.055), LEATHER, collection, arm_groups[side], bevel=0.008)

# --------------------------------------------------------------
# PERNAS — femur, joelho, tibia/fibula e dedos dos pes
# --------------------------------------------------------------
for side, sx in (("L", 1), ("R", -1)):
    hip_center = (sx * 0.174, -0.006, 0.835)
    knee = (sx * 0.197, -0.033, 0.469)
    ankle = (sx * 0.205, -0.040, 0.145)
    bone_joint("HipJoint_" + side, hip_center,
               (0.096, 0.088, 0.091), BONE_LIGHT, collection, leg_groups[side])
    tapered_bone("Femur_" + side, hip_center, knee,
                 0.079, 0.052, BONE, collection, leg_groups[side])
    bone_joint("KneeJoint_" + side, knee,
               (0.069, 0.080, 0.076), BONE_LIGHT, collection, leg_groups[side])
    bone_joint("Kneecap_" + side,
               (sx * 0.197, -0.110, 0.478),
               (0.064, 0.034, 0.059), BONE_LIGHT, collection, leg_groups[side])
    tapered_bone("Tibia_" + side,
                 (sx * 0.190, -0.038, 0.429), ankle,
                 0.052, 0.040, BONE, collection, leg_groups[side])
    tapered_bone("Fibula_" + side,
                 (sx * 0.237, 0.015, 0.426),
                 (sx * 0.243, -0.004, 0.154),
                 0.028, 0.020, BONE_DARK, collection, leg_groups[side])
    bone_joint("Ankle_" + side, ankle,
               (0.060, 0.063, 0.054), BONE_LIGHT, collection, leg_groups[side])
    tapered_bone("Foot_" + side,
                 ankle, (sx * 0.205, -0.224, 0.080),
                 0.070, 0.058, BONE, collection, leg_groups[side])
    for i in range(3):
        fx = sx * (0.164 + 0.040 * i)
        tapered_bone("Toe_%s_%d" % (side, i),
                     (fx, -0.198, 0.071), (fx, -0.319 + 0.01 * abs(i-1), 0.063),
                     0.021, 0.010, BONE_LIGHT, collection, leg_groups[side], vertices=6)

# Detalhes de musgo discretos, sem texturas de imagem nem densidade alta.
for i, pos in enumerate([
        (-0.22, 0.044, 1.33), (0.24, 0.055, 1.25),
        (-0.12, 0.100, 0.94), (0.18, 0.023, 0.72),
        (-0.18, 0.039, 0.37)]):
    bone_joint("Moss_%02d" % i, pos,
               (0.031, 0.022, 0.037), MOSS, collection, root)

# --------------------------------------------------------------
# PREVIEW NO BLENDER — camera e luzes FORA da colecao do inimigo
# --------------------------------------------------------------
if CREATE_PREVIEW:
    preview = make_collection(PREVIEW_COLLECTION)

    def aim_at(obj, target):
        direction = Vector(target) - obj.location
        obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

    bpy.ops.object.camera_add(location=(3.0, -5.2, 2.54))
    cam = bpy.context.object
    cam.name = "SKEL_PREVIEW_Camera"
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 2.85
    aim_at(cam, (0, 0, 1.12))
    move_to_collection(cam, preview)
    bpy.context.scene.camera = cam

    for name, pos, energy, size in [
        ("Key", (-3, -4, 4), 650, 4.0),
        ("Fill", (2, -2.5, 3), 320, 3.0),
        ("Rim", (0, 3, 4), 950, 2.6),
    ]:
        bpy.ops.object.light_add(type='AREA', location=pos)
        light = bpy.context.object
        light.name = "SKEL_PREVIEW_" + name
        light.data.energy = energy
        light.data.size = size
        aim_at(light, (0, 0, 1.05))
        move_to_collection(light, preview)

    world = bpy.context.scene.world
    if world is None:
        world = bpy.data.worlds.new("SKEL_Preview_World")
        bpy.context.scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    if bg:
        bg.inputs["Color"].default_value = (0.055, 0.060, 0.058, 1.0)
        bg.inputs["Strength"].default_value = 0.7

    scene = bpy.context.scene
    scene.render.resolution_x = 1100
    scene.render.resolution_y = 1100
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'

# Selecionar ROOT e mostrar frente no viewport.
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
bpy.context.view_layer.objects.active = root
for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D':
        try:
            area.spaces.active.region_3d.view_perspective = 'CAMERA'
        except AttributeError:
            pass

meshes = [obj for obj in collection.all_objects if obj.type == 'MESH']
triangles = sum(sum(max(0, len(poly.vertices) - 2) for poly in obj.data.polygons)
                for obj in meshes)
rigs = [obj.name for obj in collection.all_objects if obj.type == 'ARMATURE']
assert not rigs, "O inimigo deve ser apenas um modelo, sem armature."
print("[ESQUELETO V0.1] Criado no Blender: %d malhas / ~%d triangulos." % (len(meshes), triangles))
print("[ESQUELETO V0.1] Somente modelo; sem rig, sem animacoes.")
print("[ESQUELETO V0.1] Edite as pecas por grupo. Salve como .blend antes de fechar.")
