import bpy
import math
from mathutils import Vector

# ============================================
# ESQUELETO INIMIGO DARK FANTASY - V012
# Sem arma e sem escudo.
# Com pescoco visivel e cabeca mais alta.
# Sem rig, sem animacoes.
# ============================================

# ---------- limpar cena ----------
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

# ---------- materiais ----------
def make_mat(name, color, rough=0.9, emission=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat

BONE = make_mat("Bone", (0.93, 0.92, 0.89), 0.92)
BONE_MID = make_mat("BoneMid", (0.82, 0.80, 0.76), 0.94)
BONE_DARK = make_mat("BoneDark", (0.69, 0.67, 0.63), 0.96)
EYE = make_mat("EyeGlow", (0.82, 1.0, 0.90), 0.12, 2.5)
SHADOW = make_mat("EyeSocket", (0.33, 0.38, 0.37), 1.0)
CLOTH = make_mat("Cloth", (0.69, 0.46, 0.48), 0.98)
BELT = make_mat("Belt", (0.88, 0.80, 0.77), 0.98)
BELT_DARK = make_mat("BeltDark", (0.24, 0.19, 0.19), 0.98)

# ---------- helpers ----------
def cube(name, loc, size, mat, rot=(0,0,0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = (size[0] * 0.5, size[1] * 0.5, size[2] * 0.5)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def cylinder(name, loc, radius, depth, mat, verts=8, rot=(0,0,0), scale=(1,1,1)):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def sphere(name, loc, radius, mat, seg=12, rings=8, scale=(1,1,1), rot=(0,0,0)):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=radius, location=loc, rotation=rot)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(mat)
    return obj


def set_parent(obj, parent):
    obj.parent = parent
    return obj


def look_at(obj, target=(0,0,1.7)):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat('-Z', 'Y').to_euler()

# ---------- root ----------
root = bpy.data.objects.new("SkeletonEnemy", None)
root.empty_display_type = 'PLAIN_AXES'
bpy.context.collection.objects.link(root)

# ---------- pelvis / belt / skirt ----------
pelvis = cube("Pelvis", (0, 0, 1.38), (0.78, 0.34, 0.42), BONE_DARK)
set_parent(pelvis, root)

belt = cube("Belt", (0, 0, 1.63), (0.98, 0.34, 0.22), BELT)
set_parent(belt, root)
strip = cube("BeltStrip", (0, 0, 1.64), (0.98, 0.10, 0.10), BELT_DARK)
set_parent(strip, root)
buckle = cube("Buckle", (0, 0.18, 1.63), (0.24, 0.08, 0.18), BELT)
set_parent(buckle, root)

cloth_main = cube("ClothMain", (0, 0.03, 1.15), (0.86, 0.12, 0.78), CLOTH, rot=(math.radians(2), 0, 0))
cloth_main.rotation_euler[0] = math.radians(45)
set_parent(cloth_main, root)
cloth_side_l = cube("ClothSideL", (-0.46, -0.01, 1.12), (0.26, 0.08, 0.55), CLOTH, rot=(math.radians(-6), 0, math.radians(8)))
cloth_side_l.rotation_euler[0] = math.radians(42)
set_parent(cloth_side_l, root)
cloth_side_r = cube("ClothSideR", (0.46, -0.01, 1.12), (0.26, 0.08, 0.55), CLOTH, rot=(math.radians(-6), 0, math.radians(-8)))
cloth_side_r.rotation_euler[0] = math.radians(42)
set_parent(cloth_side_r, root)

# ---------- spine / rib cage ----------
spine_low = cube("SpineLow", (0, 0, 1.90), (0.16, 0.14, 0.36), BONE_DARK)
spine_mid = cube("SpineMid", (0, 0, 2.28), (0.16, 0.14, 0.34), BONE_MID)
spine_high = cube("SpineHigh", (0, 0, 2.63), (0.16, 0.14, 0.26), BONE_DARK)
for obj in [spine_low, spine_mid, spine_high]:
    set_parent(obj, root)

sternum = cube("Sternum", (0, 0.02, 2.38), (0.22, 0.16, 0.82), BONE_MID)
set_parent(sternum, root)

# ribs simplificadas, 4 pares
rib_data = [
    (2.72, 0.34, 0.16, 0.18, 24),
    (2.52, 0.44, 0.15, 0.16, 18),
    (2.31, 0.50, 0.14, 0.15, 12),
    (2.12, 0.40, 0.13, 0.14, 8),
]
for side in (-1, 1):
    for idx, data in enumerate(rib_data):
        z, x, sy, sz, ang = data
        rib = cube(f"Rib_{side}_{idx}", (x * side, 0.0, z), (0.56, sy, sz), BONE)
        rib.rotation_euler[1] = math.radians(-ang * side)
        set_parent(rib, root)

# clavicles / shoulders
for side in (-1, 1):
    clav = cube(f"Clavicle_{side}", (0.48 * side, 0.0, 2.88), (0.36, 0.12, 0.12), BONE_DARK)
    clav.rotation_euler[1] = math.radians(-18 * side)
    set_parent(clav, root)

# ---------- neck + head ----------
# Pescoco bem visivel para tirar a cabeca de dentro do peito.
neck_low = cylinder("NeckLow", (0, 0, 3.02), 0.10, 0.24, BONE_MID, verts=8)
neck_mid = cylinder("NeckMid", (0, 0, 3.24), 0.09, 0.20, BONE_DARK, verts=8)
neck_high = cube("NeckHigh", (0, 0, 3.43), (0.20, 0.14, 0.12), BONE)
for obj in [neck_low, neck_mid, neck_high]:
    set_parent(obj, root)

head = sphere("Head", (0, 0.02, 4.05), 0.52, BONE, seg=12, rings=8, scale=(1.0, 0.94, 1.05))
set_parent(head, root)
# Cheek/jaw blocks for angular silhouette
brow_l = cube("BrowL", (-0.20, 0.27, 4.10), (0.22, 0.16, 0.10), BONE_DARK, rot=(0, math.radians(10), math.radians(8)))
brow_r = cube("BrowR", (0.20, 0.27, 4.10), (0.22, 0.16, 0.10), BONE_DARK, rot=(0, math.radians(-10), math.radians(-8)))
cheek_l = cube("CheekL", (-0.22, 0.20, 3.84), (0.14, 0.16, 0.18), BONE_DARK, rot=(0, 0, math.radians(22)))
cheek_r = cube("CheekR", (0.22, 0.20, 3.84), (0.14, 0.16, 0.18), BONE_DARK, rot=(0, 0, math.radians(-22)))
for obj in [brow_l, brow_r, cheek_l, cheek_r]:
    set_parent(obj, root)

nose = cube("Nose", (0, 0.30, 3.86), (0.12, 0.10, 0.10), SHADOW, rot=(math.radians(45), 0, 0))
set_parent(nose, root)

jaw = cube("Jaw", (0, 0.08, 3.58), (0.44, 0.24, 0.16), BONE_DARK)
jaw.rotation_euler[0] = math.radians(8)
set_parent(jaw, root)
for i, x in enumerate([-0.15, -0.05, 0.05, 0.15]):
    tooth = cube(f"Tooth_{i}", (x, 0.21, 3.60), (0.07, 0.04, 0.06), BONE)
    set_parent(tooth, root)

for side in (-1, 1):
    socket = cube(f"EyeSocket_{side}", (0.18 * side, 0.28, 4.00), (0.16, 0.15, 0.18), SHADOW)
    eye = cube(f"Eye_{side}", (0.18 * side, 0.35, 4.01), (0.09, 0.08, 0.08), EYE, rot=(0, 0, math.radians(45 * side)))
    set_parent(socket, root)
    set_parent(eye, root)

# ---------- arms (desarmado) ----------
for side in (-1, 1):
    upper = cylinder(f"UpperArm_{side}", (0.87 * side, 0.0, 2.54), 0.10, 0.95, BONE, verts=8)
    upper.rotation_euler[2] = math.radians(12 * side)
    upper.rotation_euler[1] = math.radians(4 * side)
    fore = cylinder(f"ForeArm_{side}", (0.96 * side, 0.0, 1.76), 0.09, 0.86, BONE_MID, verts=8)
    fore.rotation_euler[2] = math.radians(4 * side)
    hand = cube(f"Hand_{side}", (0.99 * side, 0.0, 1.17), (0.18, 0.12, 0.22), BONE)
    for obj in [upper, fore, hand]:
        set_parent(obj, root)

# ---------- legs ----------
for side in (-1, 1):
    thigh = cylinder(f"Thigh_{side}", (0.25 * side, 0.0, 0.88), 0.12, 1.08, BONE, verts=8)
    shin = cylinder(f"Shin_{side}", (0.25 * side, 0.0, -0.02), 0.11, 0.98, BONE_MID, verts=8)
    foot = cube(f"Foot_{side}", (0.27 * side, 0.12, -0.63), (0.34, 0.52, 0.18), BONE)
    foot.rotation_euler[0] = math.radians(-6)
    for obj in [thigh, shin, foot]:
        set_parent(obj, root)

# ---------- camera / lighting ----------
bpy.ops.object.camera_add(location=(0.0, -10.2, 2.5))
cam = bpy.context.object
cam.name = "Camera"
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 7.2
look_at(cam, (0,0,1.9))
bpy.context.scene.camera = cam

for location, energy, size in [((-3.5, -5.0, 6.0), 1050, 5.5), ((3.4, -2.6, 4.8), 540, 5.0), ((0.2, 3.8, 5.8), 620, 4.2)]:
    bpy.ops.object.light_add(type='AREA', location=location)
    light = bpy.context.object
    light.data.energy = energy
    light.data.size = size
    look_at(light, (0,0,2.0))

world = bpy.context.scene.world
world.use_nodes = True
bg = world.node_tree.nodes.get("Background")
bg.inputs["Color"].default_value = (0.11, 0.12, 0.14, 1.0)
bg.inputs["Strength"].default_value = 0.85

scene = bpy.context.scene
for engine in ('BLENDER_EEVEE_NEXT', 'BLENDER_EEVEE'):
    try:
        scene.render.engine = engine
        break
    except Exception:
        pass
scene.render.resolution_x = 1024
scene.render.resolution_y = 1024
scene.render.image_settings.file_format = 'PNG'
scene.render.filepath = "//skeleton_enemy_v012.png"

# select root
bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
bpy.context.view_layer.objects.active = root

print("Esqueleto dark fantasy v012 criado com sucesso.")
print("Sem arma, sem escudo, com pescoco visivel.")
