"""
ESQUELETO DARK FANTASY 01 — MODELO LOW POLY PARA BLENDER
Inspirado na referencia visual aprovada pelo usuario.

- Apenas modelagem: NAO cria rig, animacoes nem exporta para Godot.
- Frente do personagem = -Y, Z para cima, pes no chao Z=0.
- Pecas rigaveis separadas e nomeadas; equipamentos em grupos proprios.
- Desenha o personagem em pose A discreta.

ATENCAO: elimina os objetos existentes da cena. Rodar em um arquivo novo.
Testado apenas em compilacao Python; e necessario validar no Blender.
"""

import bpy
import math
from mathutils import Vector

# CONFIGURACOES PRINCIPAIS
CHARACTER_SCALE = 0.88   # Altura aproximada da criatura: 1,9 m
SHOW_SWORD = True
SHOW_SHIELD = True
BUILD_PREVIEW = True      # Camera e luzes de visualizacao, fora do modelo

# ============================================================
# CENA / MATERIAIS
# ============================================================
if bpy.context.object and bpy.context.object.mode != 'OBJECT':
    bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def mat(name, rgba, roughness=0.86, emission=0.0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgba, 1.0)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgba, 1.0)
    bsdf.inputs['Roughness'].default_value = roughness
    if emission:
        # Principled BSDF de Blender 4.x/5.x
        emission_color = bsdf.inputs.get('Emission Color')
        emission_strength = bsdf.inputs.get('Emission Strength')
        if emission_color:
            emission_color.default_value = (*rgba, 1.0)
        if emission_strength:
            emission_strength.default_value = emission
    return m

BONE = mat('Skeleton | osso marfim', (0.76, 0.69, 0.56))
BONE_LIGHT = mat('Skeleton | luz no osso', (0.88, 0.79, 0.65))
BONE_SHADE = mat('Skeleton | osso sombra', (0.56, 0.50, 0.43))
CAVITY = mat('Skeleton | cavidade escura', (0.055, 0.075, 0.063), roughness=1)
EYE = mat('Skeleton | olhos verdes emissivos', (0.21, 0.95, 0.42), emission=2.1)
CLOTH = mat('Skeleton | tecido bordô', (0.26, 0.105, 0.10))
CLOTH_SHADE = mat('Skeleton | tecido sombra', (0.18, 0.065, 0.065))
LEATHER = mat('Skeleton | couro', (0.31, 0.20, 0.15))
IRON = mat('Skeleton | ferro gasto', (0.33, 0.36, 0.39), roughness=0.75)
IRON_EDGE = mat('Skeleton | metal iluminado', (0.53, 0.56, 0.57), roughness=0.62)
STEEL = mat('Skeleton | aço espada', (0.68, 0.72, 0.74), roughness=0.45)
WOOD = mat('Skeleton | madeira escura', (0.26, 0.18, 0.15))
WOOD_ALT = mat('Skeleton | madeira alternada', (0.34, 0.23, 0.18))
GOLD = mat('Skeleton | bronze antigo', (0.53, 0.41, 0.27), roughness=0.65)

# ============================================================
# ORGANIZACAO — grupos para rig futuro
# ============================================================
root = bpy.data.objects.new('SkeletonEnemy_01 | ROOT', None)
root.empty_display_type = 'ARROWS'
bpy.context.collection.objects.link(root)

def make_group(name, location=(0, 0, 0)):
    group = bpy.data.objects.new(name, None)
    group.empty_display_type = 'PLAIN_AXES'
    bpy.context.collection.objects.link(group)
    group.location = location
    group.parent = root
    return group

TORSO = make_group('00_Torso_Quadril')
HEAD = make_group('01_Cabeca')
ARM_R = make_group('02_Braco_Direito')
ARM_L = make_group('03_Braco_Esquerdo')
LEG_R = make_group('04_Perna_Direita')
LEG_L = make_group('05_Perna_Esquerda')
SWORD = make_group('06_Espada_Acoplar_Hand_R')
SHIELD = make_group('07_Escudo_Acoplar_Forearm_L')


def bind(obj, group):
    # Preserva coordenadas de mundo para nao deslocar objetos ao reparentear.
    world = obj.matrix_world.copy()
    obj.parent = group
    obj.matrix_world = world
    return obj


def flat(obj):
    for polygon in obj.data.polygons:
        polygon.use_smooth = False
    return obj


def bevel_apply(obj, width=0.02):
    if width <= 0:
        return obj
    bpy.context.view_layer.objects.active = obj
    modifier = obj.modifiers.new('Corte angular', 'BEVEL')
    modifier.width = width
    modifier.segments = 1
    if hasattr(modifier, 'affect'):
        modifier.affect = 'EDGES'
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return flat(obj)


def box(name, center, dimensions, material, group, bevel=0.0, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    obj.rotation_euler = rotation
    bevel_apply(obj, bevel)
    return bind(flat(obj), group)


def ico(name, center, scale, material, group, subdiv=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=1.0, location=center)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    return bind(flat(obj), group)


def mesh(name, vertices, faces, material, group):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj = bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    data.materials.append(material)
    flat(obj)
    return bind(obj, group)


def tube(name, points, radii, material, group, sides=7):
    """Osso low-poly ao longo de uma linha, com formas engrossadas nas extremidades."""
    assert len(points) == len(radii) and len(points) >= 2
    p = [Vector(v) for v in points]
    vertices = []
    for i, center in enumerate(p):
        tangent = (p[1] - p[0]) if i == 0 else (p[-1] - p[-2]) if i == len(p)-1 else (p[i+1] - p[i-1])
        tangent.normalize()
        ref = Vector((0, 1, 0))
        if abs(tangent.dot(ref)) > 0.93:
            ref = Vector((1, 0, 0))
        axis_u = tangent.cross(ref).normalized()
        axis_v = tangent.cross(axis_u).normalized()
        for j in range(sides):
            a = TAU * j / sides
            vertices.append(tuple(center + radii[i] * (math.cos(a)*axis_u + math.sin(a)*axis_v)))
    faces = [tuple(range(sides-1, -1, -1))]
    for k in range(len(p)-1):
        for j in range(sides):
            nj = (j + 1) % sides
            faces.append((k*sides+j, k*sides+nj, (k+1)*sides+nj, (k+1)*sides+j))
    faces.append(tuple((len(p)-1)*sides+j for j in range(sides)))
    return mesh(name, vertices, faces, material, group)


TAU = 2.0 * math.pi


def xz_prism(name, polygon, front_y, back_y, material, group):
    n = len(polygon)
    v = [(x, front_y, z) for (x, z) in polygon] + [(x, back_y, z) for (x, z) in polygon]
    f = [tuple(range(n-1, -1, -1)), tuple(range(n, 2*n))]
    for i in range(n):
        j = (i+1) % n
        f.append((i, j, n+j, n+i))
    return mesh(name, v, f, material, group)


# ============================================================
# CABECA — crânio grande, olhos fundos, mandíbula angular
# ============================================================
# Calota craniana facetada, ligeiramente maior do que a proporcao real.
rings = [
    (1.645, 0.17, 0.16, 0.025),
    (1.745, 0.29, 0.24, 0.000),
    (1.920, 0.315, 0.285, 0.000),
    (2.065, 0.265, 0.255, 0.015),
    (2.145, 0.125, 0.150, 0.020),
]
vert = []
segments = 10
for (z, rx, ry, cy) in rings:
    for j in range(segments):
        a = TAU * j / segments
        vert.append((math.cos(a) * rx, math.sin(a) * ry + cy, z))
face = [tuple(range(segments-1, -1, -1))]
for i in range(len(rings)-1):
    for j in range(segments):
        nj = (j+1) % segments
        face.append((i*segments+j, i*segments+nj, (i+1)*segments+nj, (i+1)*segments+j))
face.append(tuple((len(rings)-1)*segments+j for j in range(segments)))
mesh('Head_Cranio_Facetado', vert, face, BONE_LIGHT, HEAD)

# Rosto: órbitas profundas grandes e diagonais, visiveis na camera isometrica.
for side, sname in ((-1, 'R'), (1, 'L')):
    def mx(poly):
        return [(x * side, z) for x, z in poly]
    eye_shape = mx([(0.055, 1.897), (0.236, 1.914), (0.217, 1.776), (0.120, 1.742), (0.054, 1.802)])
    xz_prism('Head_Orbita_' + sname, eye_shape, -0.295, -0.260, CAVITY, HEAD)
    ico('Head_OlhoVerde_' + sname, (0.143*side, -0.316, 1.823), (0.058, 0.030, 0.046), EYE, HEAD, 1)
    # Sobrancelhas inclinadas e marcantes.
    tube('Head_Supercilio_' + sname,
         [(0.045*side, -0.292, 1.915), (0.133*side, -0.300, 1.943), (0.253*side, -0.235, 1.913)],
         [0.035, 0.048, 0.030], BONE_LIGHT, HEAD)
    # Maxilar angular, puxando a forma do cranio para a mandíbula.
    tube('Head_MacaDoRosto_' + sname,
         [(0.266*side, -0.205, 1.788), (0.207*side, -0.272, 1.711), (0.138*side, -0.285, 1.663)],
         [0.046, 0.055, 0.038], BONE, HEAD)
    tube('Head_LateralMandibula_' + sname,
         [(0.220*side, -0.178, 1.691), (0.200*side, -0.180, 1.579), (0.138*side, -0.215, 1.540)],
         [0.045, 0.040, 0.043], BONE_SHADE, HEAD)

xz_prism('Head_Nariz', [(-0.050, 1.748), (0.050, 1.748), (0.0, 1.689)], -0.324, -0.282, CAVITY, HEAD)
box('Head_Mandibula', (0, -0.238, 1.548), (0.36, 0.12, 0.10), BONE, HEAD, bevel=0.02)
box('Head_Boca', (0, -0.305, 1.635), (0.28, 0.015, 0.083), CAVITY, HEAD)
# Dentes em um unico bloco irregular por lado (sem microdetalhamento).
for side, sname in ((-1,'R'), (1,'L')):
    box('Head_Dentes_'+sname, (0.082*side, -0.318, 1.640), (0.11, 0.035, 0.052), BONE_LIGHT, HEAD)

# Pescoço curto de vértebras grandes.
tube('Neck_Cervical', [(0,0,1.49), (0,0,1.59), (0,0,1.67)], [0.055, 0.09, 0.06], BONE_SHADE, HEAD)

# ============================================================
# TRONCO — costelas geometricas bem legiveis (4 pares)
# ============================================================
tube('Torso_Coluna', [(0,0.09,0.91),(0,0.075,1.15),(0,0.045,1.42),(0,0.035,1.60)],
     [0.055,0.07,0.085,0.09], BONE_SHADE, TORSO)
box('Torso_Esterno', (0,-0.208,1.405), (0.155,0.095,0.385), BONE, TORSO, bevel=0.02)

for side, sname in ((-1,'R'),(1,'L')):
    # quatro costelas que abraçam o peito, mas sem emaranhado de pecas.
    for row in range(4):
        z = 1.550 - row * 0.110
        spread = 1.00 - row * 0.045
        tube('Rib_%s_%02d'%(sname,row+1),
             [(0.075*side,-0.175,z-0.035),
              (0.22*side*spread,-0.275,z+0.020),
              (0.41*side*spread,-0.230,z-0.010),
              (0.48*side*spread,0.015,z-0.105)],
             [0.038, 0.048, 0.044, 0.032],
             BONE_LIGHT if row%2==0 else BONE, TORSO, 6)
    tube('Clavicula_'+sname,
         [(0.07*side,-0.125,1.585),(0.28*side,-0.055,1.645),(0.48*side,0.020,1.620)],
         [0.043,0.058,0.047], BONE_LIGHT, TORSO)

# Pelve estreita, visivel acima do tecido.
for side,sname in ((-1,'R'),(1,'L')):
    tube('Pelvis_Asa_'+sname,
         [(0.06*side,0,1.01),(0.30*side,0,1.00),(0.34*side,-0.035,0.91)],
         [0.065,0.082,0.045], BONE_SHADE, TORSO)
box('Pelvis_Sacro', (0,0.025,0.98), (0.19,0.19,0.15), BONE, TORSO, bevel=0.02)

# ============================================================
# BRACOS — longos, simples e ligeiramente abertos (A-pose)
# ============================================================
for side, sname, group in ((-1,'R',ARM_R),(1,'L',ARM_L)):
    shoulder = Vector((0.485*side, 0.015, 1.610))
    elbow = Vector((0.670*side, -0.015, 1.265))
    wrist = Vector((0.735*side, -0.125, 0.945))
    ico('Arm_Ombro_'+sname, shoulder, (0.115,0.11,0.11), BONE, group)
    tube('Arm_Umero_'+sname,
         [shoulder, shoulder.lerp(elbow,0.25), shoulder.lerp(elbow,0.72), elbow],
         [0.095,0.077,0.065,0.082], BONE_LIGHT, group)
    ico('Arm_Cotovelo_'+sname, elbow, (0.075,0.09,0.073), BONE_SHADE, group)
    tube('Arm_Antabraco_'+sname,
         [elbow, elbow.lerp(wrist,0.30), elbow.lerp(wrist,0.75), wrist],
         [0.076,0.057,0.060,0.079], BONE, group)
    ico('Arm_Pulso_'+sname, wrist, (0.074,0.07,0.07), BONE_LIGHT, group)
    box('Arm_Mao_'+sname, (wrist.x + 0.012*side,-0.15,0.885),
        (0.17,0.14,0.19), BONE, group, bevel=0.015, rotation=(0,0,0.10*side))
    for finger in range(3):
        fx = wrist.x + (finger-1)*0.051 + 0.012*side
        tube('Arm_Dedo_%s_%d'%(sname,finger),
             [(fx,-0.190,0.818),(fx+0.014*side,-0.211,0.761)],
             [0.028,0.018], BONE_LIGHT, group, 5)

# ============================================================
# PERNAS E PES — silhueta robusta, peso nas articulacoes
# ============================================================
for side, sname, group in ((-1,'R',LEG_R),(1,'L',LEG_L)):
    hip = Vector((0.245*side, 0, 0.970))
    knee = Vector((0.292*side, -0.06, 0.535))
    ankle = Vector((0.315*side, -0.025, 0.145))
    ico('Leg_Quadril_'+sname, hip, (0.11,0.105,0.10), BONE_SHADE, group)
    tube('Leg_Femur_'+sname,
         [hip,hip.lerp(knee,0.25),hip.lerp(knee,0.74),knee],
         [0.105,0.083,0.076,0.102], BONE_LIGHT, group)
    ico('Leg_Joelho_'+sname, knee, (0.115,0.11,0.105), BONE, group)
    tube('Leg_Tibia_'+sname,
         [knee,knee.lerp(ankle,0.32),knee.lerp(ankle,0.80),ankle],
         [0.092,0.07,0.058,0.085], BONE_SHADE, group)
    ico('Leg_Tornozelo_'+sname, ankle, (0.086,0.07,0.078), BONE, group)
    # Pes em cunha, na direcao frontal -Y.
    xz_prism('Leg_Pe_'+sname, [
        (ankle.x-0.115,0.16),(ankle.x+0.115,0.16),
        (ankle.x+0.135,0.03),(ankle.x-0.15,0.03)
    ], -0.40, 0.12, BONE_LIGHT, group)

# ============================================================
# CINTURA — couro e tecido vinho desfiado, referencia aprovada
# ============================================================
box('Cloth_Cinto', (0,-0.17,0.985),(0.77,0.27,0.145),LEATHER,TORSO,bevel=0.025)
box('Cloth_Fivela', (0,-0.320,0.985),(0.22,0.06,0.18),GOLD,TORSO,bevel=0.016)
box('Cloth_MioloFivela', (0,-0.358,0.985),(0.12,0.025,0.085),LEATHER,TORSO)

xz_prism('Cloth_Frente_Principal', [
    (-0.370,0.930),(0.340,0.930),
    (0.245,0.545),(0.105,0.620),(-0.045,0.485),(-0.165,0.605),(-0.315,0.495)
], -0.280,-0.20,CLOTH,TORSO)
xz_prism('Cloth_Frente_Sombra', [
    (-0.35,0.900),(-0.115,0.895),(-0.150,0.570),(-0.29,0.505)
], -0.295,-0.278,CLOTH_SHADE,TORSO)
xz_prism('Cloth_Lateral_R', [(-0.385,0.92),(-0.265,0.91),(-0.355,0.615),(-0.465,0.530)],
         0.06,0.13,CLOTH,TORSO)
xz_prism('Cloth_Lateral_L', [(0.265,0.91),(0.395,0.93),(0.43,0.57),(0.305,0.64)],
         0.06,0.13,CLOTH,TORSO)

# ============================================================
# ESPADA — mao direita, lamina simples, sem rig por enquanto
# ============================================================
if SHOW_SWORD:
    # Ponto de empunhadura proximo a mao direita (X negativo).
    box('Sword_Punho',(-0.750,-0.23,0.770),(0.105,0.115,0.30),LEATHER,SWORD,bevel=0.011)
    ico('Sword_Pomo',(-0.750,-0.23,0.946),(0.092,0.095,0.085),IRON_EDGE,SWORD)
    box('Sword_Guarda',(-0.750,-0.23,0.665),(0.405,0.15,0.075),IRON_EDGE,SWORD,bevel=0.012)
    xz_prism('Sword_Lamina', [
        (-0.852,0.628),(-0.635,0.628),(-0.640,0.18),(-0.742,-0.04),(-0.850,0.18)
    ],-0.235,-0.125,STEEL,SWORD)
    tube('Sword_Nervura', [(-0.746,-0.245,0.600),(-0.746,-0.245,0.22)], [0.015,0.007],IRON_EDGE,SWORD,5)

# ============================================================
# ESCUDO — madeira escura com aro metalico, mao esquerda
# ============================================================
if SHOW_SHIELD:
    outer = [(0.855,1.305),(1.035,1.440),(1.295,1.275),
             (1.270,0.910),(1.080,0.690),(0.865,0.925)]
    inner = [(0.925,1.265),(1.045,1.357),(1.220,1.245),
             (1.210,0.940),(1.075,0.790),(0.935,0.965)]
    xz_prism('Shield_Aro',outer,-0.437,-0.290,IRON_EDGE,SHIELD)
    xz_prism('Shield_Madeira',inner,-0.466,-0.435,WOOD,SHIELD)
    xz_prism('Shield_Tira_Madeira',[(1.01,1.33),(1.105,1.34),(1.12,0.84),(1.02,0.84)],
             -0.476,-0.461,WOOD_ALT,SHIELD)
    xz_prism('Shield_Placa_Central',[(1.070,1.220),(1.160,1.096),(1.065,0.965),(0.980,1.095)],
             -0.510,-0.478,IRON,SHIELD)
    for i,(x,z) in enumerate([(0.946,1.20),(1.210,1.175),(1.057,0.804)]):
        ico('Shield_Rebite_%02d'%i,(x,-0.495,z),(0.027,0.014,0.027),IRON_EDGE,SHIELD)

# ============================================================
# ESCALA E PREVIEW — separados da modelagem
# ============================================================
root.scale = (CHARACTER_SCALE,)*3


def point(obj, target):
    direction = Vector(target) - obj.location
    obj.rotation_euler = direction.to_track_quat('-Z','Y').to_euler()

if BUILD_PREVIEW:
    bpy.ops.object.camera_add(location=(4.5,-8.8,4.0))
    camera = bpy.context.object
    camera.name = 'PREVIEW | Camera isometrica'
    point(camera,(0,0,1.07))
    camera.data.type = 'ORTHO'
    camera.data.ortho_scale = 3.15
    bpy.context.scene.camera = camera
    
    for name,loc,energy,size in [
        ('PREVIEW | luz principal',(-3,-5,6),900,4.5),
        ('PREVIEW | luz preenchimento',(4,-2,4),540,5.0),
        ('PREVIEW | contraluz',(1,4,5),700,4.0),
    ]:
        bpy.ops.object.light_add(type='AREA',location=loc)
        light = bpy.context.object
        light.name = name
        light.data.energy = energy
        light.data.size = size
        point(light,(0,0,1.0))

    scene = bpy.context.scene
    if scene.world is None:
        scene.world = bpy.data.worlds.new('Skeleton Preview World')
    scene.world.use_nodes = True
    background = scene.world.node_tree.nodes.get('Background')
    background.inputs['Color'].default_value = (0.075,0.075,0.085,1.0)
    background.inputs['Strength'].default_value = 0.6
    scene.render.resolution_x = 1000
    scene.render.resolution_y = 1200
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = 'PNG'
    scene.render.filepath = '//skeleton_enemy_01.png'

for area in bpy.context.screen.areas:
    if area.type == 'VIEW_3D' and BUILD_PREVIEW:
        area.spaces.active.region_3d.view_perspective = 'CAMERA'

bpy.ops.object.select_all(action='DESELECT')
root.select_set(True)
bpy.context.view_layer.objects.active = root

print('SKELETON ENEMY 01: modelo criado. Sem rig e sem animacao.')
print('Salvar: File > Save As > SkeletonEnemy_01.blend')
print('Render: F12. Grupos separados para rig futuro.')
