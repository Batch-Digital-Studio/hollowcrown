"""Whisperwood asset kit (original, procedural) for Hollowcrown.

    python tools/blender/whisperwood.py --tex assets/whisperwood --out assets/whisperwood

Builds a dying-forest kit from seeds: trees, a dead tree, bushes, ferns, grass, flowers, plain and
glowing "Emberhood" mushrooms (gathering foreshadow), rocks, a fallen log, a standing stone, the
Hollow Oak landmark, a ground tile, and two animals with animations (crow: Idle/Fly, deer: Graze/Run).
Units: metres, Y-up in glTF (Blender Z-up is converted by the exporter), origin at the base.
Style: grounded but slightly stylized low-poly (flat faceted forms, textured bark/rock/moss).
"""
import argparse
import math
import os
import random

import bpy  # must come before bmesh/mathutils
import bmesh
from mathutils import Matrix, Vector, noise

ARGS = None


# ---------------------------------------------------------------- helpers

def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def material(name, color=(0.5, 0.5, 0.5), tex=None, rough=0.85, emit=None, emit_strength=0.0, metal=0.0):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    if tex:
        img = bpy.data.images.load(os.path.abspath(os.path.join(ARGS.tex, tex)), check_existing=True)
        tn = nt.nodes.new("ShaderNodeTexImage")
        tn.image = img
        # glTF exports base colour texture x factor: multiply via the BSDF colour factor
        nt.links.new(tn.outputs["Color"], bsdf.inputs["Base Color"])
    if emit:
        bsdf.inputs["Emission Color"].default_value = (*emit, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit_strength
    return m


def obj_from_bm(name, bm, mat=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    if mat:
        me.materials.append(mat)
    return ob


def activate(ob):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob


def uv_project(ob, scale=1.0):
    activate(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.02)
    bpy.ops.object.mode_set(mode="OBJECT")
    if scale != 1.0:
        uv = ob.data.uv_layers.active.data
        for d in uv:
            d.uv = d.uv * scale


def join(objs, name):
    objs = [o for o in objs if o]
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    ob = bpy.context.active_object
    ob.name = name
    return ob


def flat(ob):
    for p in ob.data.polygons:
        p.use_smooth = False


def skin_mesh(name, verts, edges, radii, mat, subdiv=1):
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(v) for v in verts], edges, [])
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    sk = ob.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = False
    for i, sv in enumerate(me.skin_vertices[0].data):
        sv.radius = (radii[i], radii[i])
    me.skin_vertices[0].data[0].use_root = True
    if subdiv:
        s = ob.modifiers.new("sub", "SUBSURF")
        s.levels = subdiv
    activate(ob)
    bpy.ops.object.convert(target="MESH")
    ob.data.materials.append(mat)
    return ob


def blob(name, center, radius, rng, mat, squash=0.7, sub=1, jitter=0.18):
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=sub, radius=radius)
    seed = rng.random() * 100
    for v in bm.verts:
        n = noise.noise(v.co * (2.2 / max(radius, 0.1)) + Vector((seed, 0, 0)))
        v.co *= 1.0 + n * jitter * 2 + rng.uniform(-jitter, jitter) * 0.5
        v.co.z *= squash
    ob = obj_from_bm(name, bm, mat)
    ob.location = center
    return ob


def export(ob, path, anim=False):
    activate(ob)
    for c in ob.children_recursive:
        c.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_apply=not anim,
                              export_animations=anim, export_animation_mode="ACTIONS" if anim else "ACTIVE_ACTIONS",
                              export_yup=True)
    print("exported", os.path.basename(path))


def apply_xf(ob):
    activate(ob)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


# ---------------------------------------------------------------- materials

def mats():
    return {
        "bark": material("Bark", (0.85, 0.8, 0.75), "tex_bark.png", 0.95),
        "bark_pale": material("BarkPale", (1.0, 0.95, 0.9), "tex_bark.png", 0.95),
        "rock": material("Rock", (1.0, 1.0, 1.0), "tex_rock.png", 0.9),
        "moss": material("Moss", (1.0, 1.0, 1.0), "tex_moss.png", 1.0),
        "ground": material("Ground", (1.0, 1.0, 1.0), "tex_ground.png", 1.0),
        "leaf": [material("LeafOlive", (0.22, 0.27, 0.10), rough=0.8), material("LeafOchre", (0.50, 0.36, 0.10), rough=0.8),
                 material("LeafRust", (0.48, 0.17, 0.06), rough=0.8), material("LeafDark", (0.12, 0.19, 0.08), rough=0.8)],
        "fern": material("Fern", (0.16, 0.28, 0.08), rough=0.75),
        "grass": material("Grass", (0.30, 0.34, 0.12), rough=0.8),
        "grass_dry": material("GrassDry", (0.52, 0.44, 0.22), rough=0.8),
        "stem": material("Stem", (0.80, 0.74, 0.62), rough=0.7),
        "cap": material("Cap", (0.42, 0.20, 0.10), rough=0.6),
        "cap_glow": material("CapEmber", (0.95, 0.45, 0.12), rough=0.4, emit=(1.0, 0.45, 0.1), emit_strength=6.0),
        "petal": material("Petal", (0.70, 0.75, 0.95), rough=0.6),
        "petal2": material("Petal2", (0.92, 0.88, 0.70), rough=0.6),
        "crystal": material("EmberCrystal", (1.0, 0.5, 0.15), rough=0.2, emit=(1.0, 0.42, 0.08), emit_strength=12.0),
        "feather": material("Feather", (0.04, 0.04, 0.05), rough=0.5),
        "beak": material("Beak", (0.12, 0.10, 0.08), rough=0.5),
        "fur": material("Fur", (0.42, 0.28, 0.17), rough=0.9),
        "fur_light": material("FurLight", (0.75, 0.66, 0.52), rough=0.9),
        "antler": material("Antler", (0.78, 0.72, 0.6), rough=0.7),
    }


# ---------------------------------------------------------------- trees

def branch_skeleton(rng, height, trunk_r, branch_p, max_depth=3, droop=0.05):
    verts, edges, radii = [Vector((0, 0, 0))], [], [trunk_r]
    tips = []

    def grow(parent, d, length, r, depth):
        segs = max(2, int(length / 0.6))
        cur = parent
        for i in range(segs):
            d = (d + Vector((rng.uniform(-0.28, 0.28), rng.uniform(-0.28, 0.28), rng.uniform(-0.05, 0.12) - droop * depth))).normalized()
            verts.append(verts[cur] + d * (length / segs))
            rr = r * (1.0 - 0.6 * (i + 1) / segs)
            radii.append(max(0.03, rr))
            edges.append((cur, len(verts) - 1))
            cur = len(verts) - 1
            if depth < max_depth and i >= (1 if depth else 2) and rng.random() < branch_p:
                side = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.1, 0.8))).normalized()
                grow(cur, (d * 0.35 + side).normalized(), length * rng.uniform(0.4, 0.6), rr * 0.65, depth + 1)
        tips.append(verts[cur])

    lean = Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), 1.0)).normalized()
    grow(0, lean, height, trunk_r, 0)
    for k in range(rng.randint(4, 6)):   # root flare
        a = k / 5.0 * math.tau + rng.uniform(-0.3, 0.3)
        verts.append(Vector((math.cos(a) * trunk_r * 2.2, math.sin(a) * trunk_r * 2.2, -0.08)))
        radii.append(trunk_r * 0.35)
        edges.append((0, len(verts) - 1))
    return verts, edges, radii, tips


def make_tree(seed, M, kind="dying"):
    rng = random.Random(seed)
    if kind == "oak":   # the landmark
        h, r = 8.5, 1.15
        verts, edges, radii, tips = branch_skeleton(rng, h, r, 0.5, 3, 0.03)
    elif kind == "dead":
        h, r = rng.uniform(4.5, 6.0), 0.3
        verts, edges, radii, tips = branch_skeleton(rng, h, r, 0.5, 3, 0.08)
    else:
        h, r = rng.uniform(5.0, 6.8), 0.32
        verts, edges, radii, tips = branch_skeleton(rng, h, r, 0.45, 3, 0.04)
    trunk = skin_mesh(f"trunk_{seed}", verts, edges, radii, M["bark_pale" if kind == "dead" else "bark"])
    uv_project(trunk, scale=h / 1.6)
    parts = [trunk]
    if kind == "dying":
        for t in tips:
            if t.z < h * 0.45 or rng.random() < 0.15:
                continue
            for k in range(rng.randint(1, 3)):
                c = t + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), rng.uniform(-0.1, 0.45)))
                parts.append(blob("leaf", c, rng.uniform(0.55, 1.0), rng, rng.choice(M["leaf"]), 0.62, 2, 0.22))
    if kind == "oak":
        # ember crystals nested between the roots
        for k in range(5):
            a = rng.uniform(0, math.tau)
            bm = bmesh.new()
            bmesh.ops.create_cone(bm, cap_ends=True, segments=5, radius1=0.18, radius2=0.0, depth=rng.uniform(0.7, 1.3))
            c = obj_from_bm("crystal", bm, M["crystal"])
            c.location = (math.cos(a) * 1.3, math.sin(a) * 1.3, 0.35)
            c.rotation_euler = (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0)
            parts.append(c)
        # moss collar
        parts.append(blob("mosscollar", Vector((0, 0, 0.15)), 1.9, rng, M["moss"], 0.18, 2, 0.15))
    ob = join(parts, f"tree_{kind}_{seed}")
    flat(ob)
    return ob


def make_bush(seed, M):
    rng = random.Random(seed)
    parts = []
    for k in range(rng.randint(7, 11)):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(0, 0.7)
        parts.append(blob("b", Vector((math.cos(a) * d, math.sin(a) * d, rng.uniform(0.35, 0.8))), rng.uniform(0.35, 0.6), rng,
                          rng.choice(M["leaf"][:2] + [M["leaf"][3]]), 0.75, 1, 0.2))
    ob = join(parts, f"bush_{seed}")
    flat(ob)
    return ob


def blade(bm, base, direction, length, width, bend, segs=3, pinnae=False):
    """A tapered, bending strip (grass blade / fern frond) added to bm."""
    side = direction.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    prev = None
    for i in range(segs + 1):
        t = i / segs
        p = base + direction * (length * t) + Vector((0, 0, length * 0.55 * math.sin(t * math.pi * 0.5) - bend * t * t * length))
        w = width * (1 - t) + 0.01
        l = bm.verts.new(p - side * w)
        r = bm.verts.new(p + side * w)
        if prev:
            bm.faces.new((prev[0], prev[1], r, l))
            if pinnae and i < segs:   # little side leaves
                tip_l = bm.verts.new(p - side * w * 3.5 + Vector((0, 0, -0.04)))
                tip_r = bm.verts.new(p + side * w * 3.5 + Vector((0, 0, -0.04)))
                bm.faces.new((prev[0], l, tip_l))
                bm.faces.new((prev[1], tip_r, r))
        prev = (l, r)


def make_fern(seed, M):
    rng = random.Random(seed)
    bm = bmesh.new()
    n = rng.randint(7, 10)
    for k in range(n):
        a = k / n * math.tau + rng.uniform(-0.2, 0.2)
        d = Vector((math.cos(a), math.sin(a), 0))
        blade(bm, Vector((0, 0, 0.02)), d, rng.uniform(0.7, 1.0), 0.05, 0.9, 5, pinnae=True)
    ob = obj_from_bm(f"fern_{seed}", bm, M["fern"])
    return ob


def make_grass(seed, M):
    rng = random.Random(seed)
    bm = bmesh.new()
    for k in range(16):
        a = rng.uniform(0, math.tau)
        d = Vector((math.cos(a) * 0.35, math.sin(a) * 0.35, 0)).normalized()
        base = Vector((rng.uniform(-0.12, 0.12), rng.uniform(-0.12, 0.12), 0))
        blade(bm, base, d * 0.3, rng.uniform(0.35, 0.6), 0.025, rng.uniform(0.2, 0.6), 3)
    ob = obj_from_bm(f"grass_{seed}", bm, M["grass"])
    if seed % 2:
        ob.data.materials[0] = M["grass_dry"]
    return ob


def make_mushrooms(seed, M, glow):
    rng = random.Random(seed)
    parts = []
    for k in range(rng.randint(3, 6)):
        x, y = rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3)
        h = rng.uniform(0.12, 0.32) * (1.4 if glow else 1.0)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=7, radius1=0.035, radius2=0.03, depth=h)
        st = obj_from_bm("stem", bm, M["stem"])
        st.location = (x, y, h / 2)
        bm = bmesh.new()
        bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=4, radius=rng.uniform(0.07, 0.13))
        bmesh.ops.delete(bm, geom=[v for v in bm.verts if v.co.z < -0.01], context="VERTS")
        cap = obj_from_bm("cap", bm, M["cap_glow" if glow else "cap"])
        cap.location = (x, y, h)
        cap.scale = (1, 1, 0.6)
        parts += [st, cap]
    ob = join(parts, f"mushroom_{'ember' if glow else 'plain'}_{seed}")
    flat(ob)
    return ob


def make_flowers(seed, M):
    rng = random.Random(seed)
    parts = []
    for k in range(rng.randint(5, 8)):
        x, y = rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35)
        h = rng.uniform(0.18, 0.35)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=False, segments=4, radius1=0.008, radius2=0.006, depth=h)
        s = obj_from_bm("stem", bm, M["grass"])
        s.location = (x, y, h / 2)
        bm = bmesh.new()
        bmesh.ops.create_circle(bm, cap_ends=True, segments=5, radius=0.045)
        f = obj_from_bm("flower", bm, M["petal" if k % 3 else "petal2"])
        f.location = (x, y, h)
        parts += [s, f]
    return join(parts, f"flowers_{seed}")


def make_rock(seed, M, size=1.0, tall=False):
    rng = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=2, radius=size)
    off = rng.random() * 50
    for v in bm.verts:
        n = noise.noise(v.co * 1.3 + Vector((off, 0, 0)))
        v.co *= 1.0 + n * 0.35
        if tall:
            v.co.z *= 2.4
            v.co.x *= 0.6
        else:
            v.co.z *= 0.6
        if v.co.z < 0:
            v.co.z *= 0.3
    # moss on the up-facing faces
    bm.normal_update()
    ob = obj_from_bm(f"{'stone' if tall else 'rock'}_{seed}", bm, M["rock"])
    ob.data.materials.append(M["moss"])
    for p in ob.data.polygons:
        if p.normal.z > 0.75 and p.center.z > 0:
            p.material_index = 1
    uv_project(ob, scale=size * 1.5)
    flat(ob)
    return ob


def make_log(seed, M):
    rng = random.Random(seed)
    verts, edges, radii = [], [], []
    n = 7
    for i in range(n):
        verts.append(Vector((i * 0.65 - 2.0, rng.uniform(-0.08, 0.08), 0.32 + rng.uniform(-0.04, 0.04))))
        radii.append(0.34 * (1 - 0.1 * abs(i - 3) / 3))
        if i:
            edges.append((i - 1, i))
    verts.append(Vector((0.6, 0.0, 0.62)))   # a broken branch stub
    radii.append(0.08)
    edges.append((4, n))
    log = skin_mesh(f"log_{seed}", verts, edges, radii, M["bark"], subdiv=1)
    uv_project(log, scale=3.0)
    m1 = blob("moss", Vector((-0.6, 0, 0.6)), 0.5, rng, M["moss"], 0.25, 1, 0.1)
    m2 = blob("moss", Vector((1.1, 0.05, 0.58)), 0.35, rng, M["moss"], 0.25, 1, 0.1)
    ob = join([log, m1, m2], f"log_{seed}")
    flat(ob)
    return ob


def make_ground(M, size=48.0, tiles=12.0):
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=24, y_segments=24, size=size / 2)
    rng = random.Random(3)
    for v in bm.verts:   # gentle undulation, flat near the middle
        d = v.co.length / (size / 2)
        v.co.z = noise.noise(v.co * 0.08) * 0.35 * d
    ob = obj_from_bm("ground", bm, M["ground"])
    uv_project(ob, scale=1.0)
    # planar UVs instead (tiles across the ground)
    uv = ob.data.uv_layers.active.data
    for loop in ob.data.loops:
        co = ob.data.vertices[loop.vertex_index].co
        uv[loop.index].uv = ((co.x / size + 0.5) * tiles, (co.y / size + 0.5) * tiles)
    return ob


# ---------------------------------------------------------------- animals

def rig(name, bones):
    """bones: [(name, head, tail, parent)] -> armature object"""
    arm = bpy.data.armatures.new(name + "_rig")
    ob = bpy.data.objects.new(name + "_rig", arm)
    bpy.context.collection.objects.link(ob)
    activate(ob)
    bpy.ops.object.mode_set(mode="EDIT")
    eb = {}
    for bn, h, t, p in bones:
        b = arm.edit_bones.new(bn)
        b.head, b.tail = Vector(h), Vector(t)
        if p:
            b.parent = eb[p]
        eb[bn] = b
    bpy.ops.object.mode_set(mode="OBJECT")
    return ob


def bind(parts, arm, name):
    """parts: [(object, bone)] -> one mesh skinned rigidly per part."""
    for ob, bone in parts:
        vg = ob.vertex_groups.new(name=bone)
        vg.add([v.index for v in ob.data.vertices], 1.0, "REPLACE")
    mesh = join([p[0] for p in parts], name)
    flat(mesh)
    mesh.parent = arm
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    return mesh


def keyframes(arm, action_name, frames, loop_len):
    """frames: {frame: {bone: (rx, ry, rz) or ('loc', x, y, z)}}"""
    act = bpy.data.actions.new(action_name)
    arm.animation_data_create()
    arm.animation_data.action = act
    for f, poses in frames.items():
        for bn, val in poses.items():
            pb = arm.pose.bones[bn]
            if val[0] == "loc":
                pb.location = Vector(val[1:])
                pb.keyframe_insert("location", frame=f)
            else:
                pb.rotation_mode = "XYZ"
                pb.rotation_euler = val
                pb.keyframe_insert("rotation_euler", frame=f)
    act.use_fake_user = True
    # stash so the exporter sees every action
    track = arm.animation_data.nla_tracks.new()
    track.name = action_name
    track.strips.new(action_name, 1, act)
    arm.animation_data.action = None
    return act


def make_crow(M):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.13)
    body = obj_from_bm("body", bm, M["feather"])
    body.scale = (1.0, 1.6, 0.9)
    body.location = (0, 0, 0.18)
    apply_xf(body)
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=8, v_segments=6, radius=0.075)
    head = obj_from_bm("head", bm, M["feather"])
    head.location = (0, 0.2, 0.28)
    apply_xf(head)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=4, radius1=0.03, radius2=0.0, depth=0.1)
    beak = obj_from_bm("beak", bm, M["beak"])
    beak.rotation_euler = (-math.pi / 2, 0, 0)
    beak.location = (0, 0.3, 0.27)
    apply_xf(beak)
    tail = obj_from_bm("tail", _quad(0.08, 0.16), M["feather"])
    tail.location = (0, -0.26, 0.17)
    apply_xf(tail)
    wl = obj_from_bm("wingL", _quad(0.32, 0.14), M["feather"])
    wl.location = (-0.2, 0.0, 0.24)
    apply_xf(wl)
    wr = obj_from_bm("wingR", _quad(0.32, 0.14), M["feather"])
    wr.location = (0.2, 0.0, 0.24)
    apply_xf(wr)
    arm = rig("crow", [("root", (0, 0, 0), (0, 0, 0.15), None), ("body", (0, 0, 0.18), (0, 0.15, 0.18), "root"),
                       ("head", (0, 0.18, 0.26), (0, 0.3, 0.28), "body"),
                       ("wing_L", (-0.06, 0, 0.24), (-0.36, 0, 0.24), "body"), ("wing_R", (0.06, 0, 0.24), (0.36, 0, 0.24), "body")])
    mesh = bind([(body, "body"), (head, "head"), (beak, "head"), (tail, "body"), (wl, "wing_L"), (wr, "wing_R")], arm, "crow")
    keyframes(arm, "Idle", {1: {"head": (0, 0, 0), "wing_L": (0, 0.3, 0), "wing_R": (0, -0.3, 0)},
                            12: {"head": (0.35, 0, 0.2)}, 24: {"head": (0, 0, -0.25)}, 36: {"head": (0, 0, 0)}}, 36)
    keyframes(arm, "Fly", {1: {"wing_L": (0, 0.9, 0), "wing_R": (0, -0.9, 0), "body": ("loc", 0, 0, 0)},
                           4: {"wing_L": (0, -0.7, 0), "wing_R": (0, 0.7, 0), "body": ("loc", 0, 0, -0.03)},
                           8: {"wing_L": (0, 0.9, 0), "wing_R": (0, -0.9, 0), "body": ("loc", 0, 0, 0)}}, 8)
    return arm


def _quad(w, d):
    bm = bmesh.new()
    a = bm.verts.new((-w / 2, -d / 2, 0))
    b = bm.verts.new((w / 2, -d / 2, 0))
    c = bm.verts.new((w / 2, d / 2, 0))
    e = bm.verts.new((-w / 2, d / 2, 0))
    bm.faces.new((a, b, c, e))
    return bm


def _limb(name, top, length, r, mat):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=r * 0.7, radius2=r, depth=length)
    ob = obj_from_bm(name, bm, mat)
    ob.location = (top[0], top[1], top[2] - length / 2)
    apply_xf(ob)
    return ob


def make_deer(M):
    rng = random.Random(5)
    body = blob("body", Vector((0, 0, 1.0)), 0.42, rng, M["fur"], 1.0, 1, 0.06)
    body.scale = (0.75, 1.75, 0.8)
    apply_xf(body)
    belly = blob("belly", Vector((0, 0.05, 0.9)), 0.3, rng, M["fur_light"], 1.0, 1, 0.05)
    belly.scale = (0.8, 1.9, 0.6)
    apply_xf(belly)
    neck = _limb("neck", (0, 0.62, 1.55), 0.55, 0.12, M["fur"])
    neck.rotation_euler = (-0.5, 0, 0)
    head = blob("head", Vector((0, 0.95, 1.6)), 0.17, rng, M["fur"], 0.9, 1, 0.05)
    head.scale = (0.8, 1.6, 0.9)
    apply_xf(head)
    ant = []
    for sx in (-1, 1):
        a = _limb("antler", (0.08 * sx, 0.9, 2.05), 0.32, 0.025, M["antler"])
        a.rotation_euler = (0.2, 0.45 * sx, 0)
        ant.append(a)
    legs = {}
    for nm, x, y in (("leg_FL", -0.18, 0.5), ("leg_FR", 0.18, 0.5), ("leg_BL", -0.18, -0.5), ("leg_BR", 0.18, -0.5)):
        legs[nm] = _limb(nm, (x, y, 0.95), 0.95, 0.06, M["fur"])
    tail = blob("tail", Vector((0, -0.75, 1.15)), 0.08, rng, M["fur_light"], 1.0, 1, 0.05)
    bones = [("root", (0, 0, 0), (0, 0, 0.3), None), ("spine", (0, -0.4, 1.0), (0, 0.4, 1.0), "root"),
             ("neck", (0, 0.5, 1.2), (0, 0.8, 1.7), "spine"), ("head", (0, 0.8, 1.7), (0, 1.15, 1.6), "neck")]
    for nm, x, y in (("leg_FL", -0.18, 0.5), ("leg_FR", 0.18, 0.5), ("leg_BL", -0.18, -0.5), ("leg_BR", 0.18, -0.5)):
        bones.append((nm, (x, y, 0.95), (x, y, 0.05), "spine"))
    arm = rig("deer", bones)
    parts = [(body, "spine"), (belly, "spine"), (tail, "spine"), (neck, "neck"), (head, "head")] + [(a, "head") for a in ant]
    parts += [(legs[n], n) for n in legs]
    bind(parts, arm, "deer")
    # Graze: head down to the grass and back up, ear-flick pauses
    keyframes(arm, "Graze", {1: {"neck": (0, 0, 0), "head": (0, 0, 0)}, 20: {"neck": (1.0, 0, 0), "head": (0.4, 0, 0)},
                             50: {"neck": (1.05, 0, 0.05), "head": (0.45, 0, 0)}, 70: {"neck": (0, 0, 0), "head": (0, 0, 0)},
                             90: {"neck": (0, 0, 0.15), "head": (0, 0, 0)}, 110: {"neck": (0, 0, 0), "head": (0, 0, 0)}}, 110)
    sw = 0.7
    keyframes(arm, "Run", {1: {"leg_FL": (sw, 0, 0), "leg_FR": (sw, 0, 0), "leg_BL": (-sw, 0, 0), "leg_BR": (-sw, 0, 0), "spine": ("loc", 0, 0, 0), "neck": (-0.2, 0, 0)},
                           6: {"leg_FL": (-sw, 0, 0), "leg_FR": (-sw, 0, 0), "leg_BL": (sw, 0, 0), "leg_BR": (sw, 0, 0), "spine": ("loc", 0, 0, 0.12)},
                           12: {"leg_FL": (sw, 0, 0), "leg_FR": (sw, 0, 0), "leg_BL": (-sw, 0, 0), "leg_BR": (-sw, 0, 0), "spine": ("loc", 0, 0, 0)}}, 12)
    return arm


# ---------------------------------------------------------------- main

def main():
    global ARGS
    import sys
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--tex", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", default="")
    ARGS = ap.parse_args(argv)
    out = ARGS.out
    jobs = [
        ("tree_dying_1", lambda M: make_tree(11, M)), ("tree_dying_2", lambda M: make_tree(23, M)), ("tree_dying_3", lambda M: make_tree(37, M)),
        ("tree_dead_1", lambda M: make_tree(5, M, "dead")), ("hollow_oak", lambda M: make_tree(101, M, "oak")),
        ("bush_1", lambda M: make_bush(3, M)), ("bush_2", lambda M: make_bush(8, M)),
        ("fern_1", lambda M: make_fern(2, M)), ("fern_2", lambda M: make_fern(9, M)),
        ("grass_1", lambda M: make_grass(2, M)), ("grass_2", lambda M: make_grass(3, M)),
        ("flowers_1", lambda M: make_flowers(4, M)),
        ("mushroom_plain", lambda M: make_mushrooms(6, M, False)), ("mushroom_ember", lambda M: make_mushrooms(7, M, True)),
        ("rock_1", lambda M: make_rock(1, M, 0.8)), ("rock_2", lambda M: make_rock(2, M, 1.3)), ("rock_3", lambda M: make_rock(4, M, 0.5)),
        ("standing_stone", lambda M: make_rock(12, M, 0.55, tall=True)),
        ("log_1", lambda M: make_log(3, M)), ("ground", lambda M: make_ground(M, size=100.0, tiles=26.0)),
    ]
    for name, fn in jobs:
        if ARGS.only and name not in ARGS.only.split(","):
            continue
        reset()
        M = mats()
        ob = fn(M)
        export(ob, os.path.join(out, name + ".glb"))
    for name, fn in [("crow", make_crow), ("deer", make_deer)]:
        if ARGS.only and name not in ARGS.only.split(","):
            continue
        reset()
        M = mats()
        arm = fn(M)
        export(arm, os.path.join(out, name + ".glb"), anim=True)


main()
