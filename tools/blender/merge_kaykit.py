"""Merge a KayKit character into one skinned mesh (for engines whose glTF import splits parts).

    python tools/blender/merge_kaykit.py IN.glb OUT.glb --keep a,b,c --anims Idle,Running_A,... [--weapon W.gltf --slot handslot.r]

Parts not in --keep (weapons, hats...) are removed unless their name starts with the model prefix and
contains Arm/Leg/Body/Head. Meshes attached to a bone become rigidly skinned to that bone.
"""
import argparse
import sys

import bpy  # noqa: E402  (bpy before bmesh/mathutils)

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
ap = argparse.ArgumentParser()
ap.add_argument("src")
ap.add_argument("dst")
ap.add_argument("--keep", default="")
ap.add_argument("--anims", default="")
ap.add_argument("--weapon", default="")
ap.add_argument("--slot", default="handslot.r")
a = ap.parse_args(argv)
keep = set(filter(None, a.keep.split(",")))
anims = [s for s in a.anims.split(",") if s]

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=a.src)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
BODY = ("Arm", "Leg", "Body", "Head", "Eyes", "Jaw", "Skull", "Cloak")

if a.weapon:
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=a.weapon)
    for o in set(bpy.data.objects) - before:
        if o.type == "MESH":
            mw = arm.matrix_world @ arm.pose.bones[a.slot].matrix
            o.parent = arm
            o.parent_type = "BONE"
            o.parent_bone = a.slot
            o.matrix_world = mw
            keep.add(o.name)
        elif o.type == "EMPTY":
            pass

meshes = []
for o in list(bpy.data.objects):
    if o.type != "MESH":
        continue
    is_body = o.name.startswith("Skeleton_") or any(k in o.name for k in BODY)
    if not (is_body or o.name in keep):
        bpy.data.objects.remove(o)
        continue
    if o.parent_type == "BONE" or (o.parent and o.parent.type == "EMPTY"):
        bone = o.parent_bone if o.parent_type == "BONE" else None
        if bone is None:   # attached through an empty under a bone
            p = o.parent
            while p and p.parent_type != "BONE":
                p = p.parent
            bone = p.parent_bone if p else a.slot
        mw = o.matrix_world.copy()
        o.parent = arm
        o.parent_type = "OBJECT"
        o.matrix_world = mw
        vg = o.vertex_groups.new(name=bone)
        vg.add([v.index for v in o.data.vertices], 1.0, "REPLACE")
        mod = o.modifiers.new("Armature", "ARMATURE")
        mod.object = arm
    meshes.append(o)

bpy.ops.object.select_all(action="DESELECT")
for o in meshes:
    o.select_set(True)
bpy.context.view_layer.objects.active = meshes[0]
bpy.ops.object.join()
body = bpy.context.active_object
body.name = arm.name.split("_")[0] + "_merged"
for o in list(bpy.data.objects):
    if o.type == "EMPTY":
        bpy.data.objects.remove(o)

# keep only the animations we use
for act in list(bpy.data.actions):
    if anims and not any(act.name == n or act.name.startswith(n + "_") or act.name.endswith("|" + n) for n in anims):
        bpy.data.actions.remove(act)
print("actions kept:", [x.name for x in bpy.data.actions])
if arm.animation_data:
    arm.animation_data.action = None
    for t in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(t)
for act in bpy.data.actions:
    act.use_fake_user = True

bpy.ops.object.select_all(action="DESELECT")
arm.select_set(True)
body.select_set(True)
bpy.ops.export_scene.gltf(filepath=a.dst, use_selection=True, export_format="GLB", export_animations=True,
                          export_animation_mode="ACTIONS", export_yup=True)
print("merged ->", a.dst)
