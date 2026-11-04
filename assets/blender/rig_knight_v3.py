import bpy

RIG_NAME = "Knight_Rig"
ANIMATION_NAMES = ("idle-loop", "walk-loop", "attack")
AXES = {"x": 0, "y": 1, "z": 2}

SIDED_MAP = {
    "Boot_Foot": "foot",
    "Boot_Shaft": "shin",
    "Knee_Guard": "shin",
    "Knee_Band": "shin",
    "Thigh": "thigh",
    "Upper_Arm": "upper_arm",
    "Pauldron": "upper_arm",
    "Pauldron_Trim": "upper_arm",
    "Forearm": "forearm",
    "Elbow_Band": "forearm",
    "Wrist_Band": "forearm",
    "Hand": "hand",
}

HEAD_PARTS = ("Ear", "Eye", "Eyebrow")

CENTER_MAP = {
    "Cape": "cape",
    "Body": "spine",
    "Breastplate": "spine",
    "Chest_Star": "spine",
    "Waist_Guard": "hips",
    "Waist_Trim": "hips",
    "Belt": "hips",
    "Buckle": "hips",
    "Buckle_Center": "hips",
    "Neck": "head",
    "Head": "head",
    "Scarf": "head",
}


def bone_for(name):
    if name.startswith("Hair_"):
        return "head"
    if name.startswith("Sword_"):
        return "sword.R"
    if name.startswith("Shield_"):
        return "forearm.L"
    if name in CENTER_MAP:
        return CENTER_MAP[name]
    if name.endswith("_L") or name.endswith("_R"):
        base = name[:-2]
        side = name[-1]
        if base in HEAD_PARTS:
            return "head"
        if base in SIDED_MAP:
            return SIDED_MAP[base] + "." + side
    return None


def remove_old_rig(root):
    old = bpy.data.objects.get(RIG_NAME)
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        for modifier in list(obj.modifiers):
            if modifier.type == "ARMATURE":
                obj.modifiers.remove(modifier)
        for group in list(obj.vertex_groups):
            obj.vertex_groups.remove(group)
        if old and obj.parent == old:
            obj.parent = root
    if old:
        bpy.data.objects.remove(old)
    for armature_data in list(bpy.data.armatures):
        if armature_data.users == 0:
            bpy.data.armatures.remove(armature_data)
    for action in list(bpy.data.actions):
        if action.name.split(".")[0] in ANIMATION_NAMES:
            bpy.data.actions.remove(action)


def build_armature(root):
    bpy.ops.object.armature_add(location=(0, 0, 0))
    armature = bpy.context.active_object
    armature.name = RIG_NAME
    armature.data.name = "Knight_Armature"
    armature.parent = root
    armature.show_in_front = True

    bpy.ops.object.mode_set(mode="EDIT")
    edit_bones = armature.data.edit_bones
    for bone in list(edit_bones):
        edit_bones.remove(bone)

    definitions = [
        ("hips", (0, 0, 2.3), (0, 0, 2.7), None),
        ("spine", (0, 0, 2.7), (0, 0, 3.8), "hips"),
        ("head", (0, 0, 3.8), (0, 0, 5.5), "spine"),
        ("cape", (0, 0.34, 3.85), (0, 0.34, 4.25), "spine"),
    ]
    for side, sx in (("L", 1), ("R", -1)):
        definitions += [
            ("upper_arm." + side, (sx * 0.9, 0, 3.85), (sx * 0.95, -0.02, 3.05), "spine"),
            ("forearm." + side, (sx * 0.95, -0.02, 3.05), (sx * 1.08, -0.04, 2.55), "upper_arm." + side),
            ("hand." + side, (sx * 1.08, -0.04, 2.55), (sx * 1.09, -0.04, 2.2), "forearm." + side),
            ("thigh." + side, (sx * 0.37, 0, 2.3), (sx * 0.37, 0, 1.3), "hips"),
            ("shin." + side, (sx * 0.37, 0, 1.3), (sx * 0.37, 0, 0.3), "thigh." + side),
            ("foot." + side, (sx * 0.37, 0, 0.3), (sx * 0.37, -0.5, 0.08), "shin." + side),
        ]

    definitions.append(("sword.R", (-1.11, -0.13, 2.45), (-1.18, -0.14, 0.4), "hand.R"))

    for name, head, tail, parent in definitions:
        bone = edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        if parent:
            bone.parent = edit_bones[parent]

    bpy.ops.object.mode_set(mode="OBJECT")
    return armature


def bind_parts(armature):
    unmatched = []
    for obj in bpy.data.objects:
        if obj.type != "MESH":
            continue
        bone_name = bone_for(obj.name)
        if bone_name is None or bone_name not in armature.data.bones:
            unmatched.append(obj.name)
            continue
        group = obj.vertex_groups.new(name=bone_name)
        group.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
        modifier = obj.modifiers.new("Armature", "ARMATURE")
        modifier.object = armature
        obj.parent = armature
    return unmatched


def reset_pose(armature):
    for pose_bone in armature.pose.bones:
        pose_bone.rotation_mode = "XYZ"
        pose_bone.rotation_euler = (0, 0, 0)
        pose_bone.location = (0, 0, 0)


def key_channels(armature, data_path, channels):
    keyed = set()
    for bone_name, axes in channels.items():
        pose_bone = armature.pose.bones[bone_name]
        for axis_name, frames in axes.items():
            axis = AXES[axis_name]
            for frame, value in frames.items():
                getattr(pose_bone, data_path)[axis] = value
                pose_bone.keyframe_insert(data_path, index=axis, frame=frame)
            keyed.add((bone_name, axis))
    return keyed


def make_action(armature, name, rotation, location=None):
    reset_pose(armature)
    action = bpy.data.actions.new(name)
    action.use_fake_user = True
    if armature.animation_data is None:
        armature.animation_data_create()
    armature.animation_data.action = action

    keyed_rotation = key_channels(armature, "rotation_euler", rotation)
    keyed_location = key_channels(armature, "location", location or {})

    for pose_bone in armature.pose.bones:
        for axis in range(3):
            if (pose_bone.name, axis) not in keyed_rotation:
                pose_bone.rotation_euler[axis] = 0.0
                pose_bone.keyframe_insert("rotation_euler", index=axis, frame=1)
    hips = armature.pose.bones["hips"]
    for axis in range(3):
        if ("hips", axis) not in keyed_location:
            hips.location[axis] = 0.0
            hips.keyframe_insert("location", index=axis, frame=1)
    return action


def level_foot(thigh, shin):
    return {frame: -(thigh[frame] + shin[frame]) for frame in thigh}


def create_animations(armature):
    idle = make_action(
        armature,
        "idle-loop",
        {
            "spine": {"x": {1: 0.0, 25: 0.04, 49: 0.0}},
            "head": {"x": {1: 0.0, 25: -0.03, 49: 0.0}},
            "upper_arm.L": {"x": {1: -0.15, 25: -0.17, 49: -0.15}},
            "forearm.L": {"x": {1: -0.5, 25: -0.52, 49: -0.5}},
            "upper_arm.R": {"x": {1: 0.0, 25: 0.03, 49: 0.0}},
            "forearm.R": {"x": {1: -0.25, 25: -0.28, 49: -0.25}},
        },
        {"hips": {"y": {1: 0.0, 25: -0.03, 49: 0.0}}},
    )

    thigh_l = {1: -0.55, 7: 0.0, 13: 0.55, 19: 0.0, 25: -0.55}
    thigh_r = {1: 0.55, 7: 0.0, 13: -0.55, 19: 0.0, 25: 0.55}
    shin_l = {1: 0.05, 7: 0.15, 13: 0.35, 19: 0.9, 25: 0.05}
    shin_r = {1: 0.35, 7: 0.9, 13: 0.05, 19: 0.15, 25: 0.35}
    make_action(
        armature,
        "walk-loop",
        {
            "thigh.L": {"x": thigh_l},
            "thigh.R": {"x": thigh_r},
            "shin.L": {"x": shin_l},
            "shin.R": {"x": shin_r},
            "foot.L": {"x": level_foot(thigh_l, shin_l)},
            "foot.R": {"x": level_foot(thigh_r, shin_r)},
            "upper_arm.R": {"x": {1: -0.6, 13: 0.4, 25: -0.6}},
            "forearm.R": {"x": {1: -0.55, 13: -0.15, 25: -0.55}},
            "hand.R": {"x": {1: -0.15, 13: 0.1, 25: -0.15}},
            "upper_arm.L": {"x": {1: 0.05, 13: -0.35, 25: 0.05}},
            "forearm.L": {"x": {1: -0.45, 13: -0.55, 25: -0.45}},
            "spine": {
                "x": {1: 0.06, 13: 0.06, 25: 0.06},
                "y": {1: 0.22, 13: -0.22, 25: 0.22},
            },
            "head": {
                "x": {1: -0.06, 13: -0.06, 25: -0.06},
                "y": {1: -0.12, 13: 0.12, 25: -0.12},
            },
            "hips": {"y": {1: -0.1, 13: 0.1, 25: -0.1}},
        },
        {"hips": {"y": {1: -0.1, 7: 0.05, 13: -0.1, 19: 0.05, 25: -0.1}}},
    )

    frames = (1, 6, 11, 14, 18, 24, 30)

    def on(*values):
        return dict(zip(frames, values))

    attack_thigh_l = on(0.0, 0.1, -0.6, -0.62, -0.6, -0.25, 0.0)
    attack_thigh_r = on(0.0, -0.1, 0.45, 0.46, 0.45, 0.2, 0.0)
    attack_shin_l = on(0.0, 0.0, 0.3, 0.3, 0.3, 0.15, 0.0)
    attack_shin_r = on(0.0, 0.0, 0.1, 0.1, 0.1, 0.05, 0.0)
    make_action(
        armature,
        "attack",
        {
            "upper_arm.R": {"x": on(0.0, 0.7, -0.95, -1.05, -0.95, -0.4, 0.0)},
            "forearm.R": {"x": on(-0.25, -1.2, -0.25, -0.25, -0.25, -0.5, -0.25)},
            "hand.R": {"x": on(0.0, -0.4, -0.1, -0.15, -0.1, 0.2, 0.0)},
            "sword.R": {"x": on(0.0, -0.4, -0.3, -0.45, -0.3, 0.15, 0.0)},
            "upper_arm.L": {"x": on(-0.15, -0.3, -0.1, -0.12, -0.1, -0.15, -0.15)},
            "forearm.L": {"x": on(-0.5, -0.6, -0.5, -0.5, -0.5, -0.5, -0.5)},
            "spine": {
                "x": on(0.0, -0.1, 0.18, 0.2, 0.18, 0.08, 0.0),
                "y": on(0.0, -0.5, 0.4, 0.45, 0.35, 0.1, 0.0),
            },
            "head": {
                "x": on(0.0, 0.0, -0.1, -0.1, -0.1, 0.0, 0.0),
                "y": on(0.0, 0.3, -0.25, -0.28, -0.2, -0.05, 0.0),
            },
            "hips": {"y": on(0.0, -0.15, 0.12, 0.14, 0.12, 0.03, 0.0)},
            "thigh.L": {"x": attack_thigh_l},
            "thigh.R": {"x": attack_thigh_r},
            "shin.L": {"x": attack_shin_l},
            "shin.R": {"x": attack_shin_r},
            "foot.L": {"x": level_foot(attack_thigh_l, attack_shin_l)},
            "foot.R": {"x": level_foot(attack_thigh_r, attack_shin_r)},
        },
        {
            "hips": {
                "y": on(0.0, 0.0, -0.15, -0.15, -0.15, -0.05, 0.0),
                "z": on(0.0, -0.1, 0.3, 0.32, 0.3, 0.1, 0.0),
            }
        },
    )

    reset_pose(armature)
    armature.animation_data.action = idle
    try:
        armature.animation_data.action_slot = idle.slots[0]
    except (AttributeError, IndexError):
        pass


def rig_knight():
    root = bpy.data.objects.get("Knight")
    if root is None:
        raise RuntimeError("Run low_poly_knight_silhouette.py first")
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    remove_old_rig(root)
    armature = build_armature(root)
    unmatched = bind_parts(armature)
    create_animations(armature)
    bpy.context.scene.frame_set(1)
    print("Rig created with", len(armature.data.bones), "bones")
    if unmatched:
        print("Parts without a bone:", unmatched)


rig_knight()
