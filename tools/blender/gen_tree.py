"""Hollowcrown procedural tree generator (original asset, Blender Python).

Builds a gnarled, low-poly "dying wood" tree from a seed: a recursive branch skeleton turned
into a mesh with Blender's Skin modifier, plus faceted leaf clumps. Exports one .glb per seed.

Run (Blender as a Python module or blender --background --python):
    python tools/blender/gen_tree.py --out assets/gen/trees --seeds 1 2 3 [--render preview.png]

Recipe is fully determined by the seed; re-running reproduces the same meshes.
"""
import argparse
import math
import random
import sys

import bpy
import bmesh
from mathutils import Vector, Matrix


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, rough=0.9):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    return m


def build_skeleton(rng, height):
    """Returns verts, edges, radii for a branching trunk."""
    verts, edges, radii = [Vector((0, 0, 0))], [], [0.32]
    lean = Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 1.0)).normalized()

    def grow(parent, direction, length, radius, depth):
        segs = max(2, int(length / 0.45))
        cur = parent
        d = direction.copy()
        for i in range(segs):
            # gnarl: wander a little each segment, slight droop on thin limbs
            d = (d + Vector((rng.uniform(-0.35, 0.35), rng.uniform(-0.35, 0.35), rng.uniform(-0.1, 0.15) - 0.05 * depth))).normalized()
            p = verts[cur] + d * (length / segs)
            verts.append(p)
            r = radius * (1.0 - 0.55 * (i + 1) / segs)
            radii.append(max(0.035, r))
            edges.append((cur, len(verts) - 1))
            cur = len(verts) - 1
            if depth < 3 and i >= 1 and rng.random() < (0.55 if depth == 0 else 0.4):
                side = Vector((rng.uniform(-1, 1), rng.uniform(-1, 1), rng.uniform(0.2, 0.9))).normalized()
                grow(cur, (d * 0.4 + side).normalized(), length * rng.uniform(0.45, 0.65), r * 0.7, depth + 1)
        return cur

    grow(0, lean, height, 0.32, 0)
    # root flare: a few short roots
    for k in range(rng.randint(3, 5)):
        a = k / 4.0 * math.tau + rng.uniform(-0.4, 0.4)
        p = Vector((math.cos(a) * 0.55, math.sin(a) * 0.55, -0.05))
        verts.append(p)
        radii.append(0.08)
        edges.append((0, len(verts) - 1))
    return verts, edges, radii


def make_tree(seed, autumn):
    rng = random.Random(seed)
    height = rng.uniform(2.6, 3.6)
    verts, edges, radii = build_skeleton(rng, height)
    me = bpy.data.meshes.new(f"trunk_{seed}")
    me.from_pydata([tuple(v) for v in verts], edges, [])
    ob = bpy.data.objects.new(f"tree_{seed}", me)
    bpy.context.collection.objects.link(ob)
    sk = ob.modifiers.new("skin", "SKIN")
    sk.use_smooth_shade = False
    for i, sv in enumerate(me.skin_vertices[0].data):
        sv.radius = (radii[i], radii[i])
    me.skin_vertices[0].data[0].use_root = True
    sub = ob.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    bpy.context.view_layer.objects.active = ob
    ob.select_set(True)
    bpy.ops.object.convert(target="MESH")
    ob.data.materials.append(mat("Bark", (0.16, 0.11, 0.08)))

    # leaf clumps on the outer branch tips (sparse: a dying wood, not a lush one)
    tips = [verts[e[1]] for e in edges if all(e[1] != f[0] for f in edges) and verts[e[1]].z > height * 0.45]
    leaf_cols = [(0.18, 0.28, 0.1), (0.24, 0.32, 0.12), (0.45, 0.3, 0.08), (0.5, 0.18, 0.06)] if autumn else [(0.14, 0.26, 0.1), (0.18, 0.32, 0.12), (0.22, 0.3, 0.1)]
    mats = [mat(f"Leaf{i}_{'a' if autumn else 'g'}", c, 0.8) for i, c in enumerate(leaf_cols)]
    clumps = []
    for t in tips:
        if rng.random() < 0.25:
            continue
        bm = bmesh.new()
        bmesh.ops.create_icosphere(bm, subdivisions=1, radius=rng.uniform(0.45, 0.75))
        for v in bm.verts:   # lumpy, flattened clumps
            v.co *= rng.uniform(0.8, 1.2)
            v.co.z *= 0.65
        lm = bpy.data.meshes.new("leaf")
        bm.to_mesh(lm)
        bm.free()
        lo = bpy.data.objects.new("leaf", lm)
        lo.location = t + Vector((0, 0, 0.15))
        lo.rotation_euler = (rng.uniform(0, 0.4), rng.uniform(0, 0.4), rng.uniform(0, math.tau))
        lm.materials.append(rng.choice(mats))
        bpy.context.collection.objects.link(lo)
        clumps.append(lo)
    # join into one object, origin at the root (floor contact), 1 unit = 1 m
    bpy.ops.object.select_all(action="DESELECT")
    for o in clumps + [ob]:
        o.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.join()
    return ob


def export(ob, path):
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=path, use_selection=True, export_format="GLB", export_apply=True)


def render_preview(objs, path):
    """Orthographic render at roughly the game's camera angle (45 deg yaw, 52 deg elevation)."""
    scn = bpy.context.scene
    for i, o in enumerate(objs):
        o.location.x = (i - (len(objs) - 1) / 2) * 5.5
    bpy.ops.mesh.primitive_plane_add(size=30)
    bpy.context.active_object.data.materials.append(mat("Ground", (0.12, 0.13, 0.08)))
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 20
    yaw, pitch = math.radians(45), math.radians(52)
    d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
    cam.location = Vector((0, 0, 2.5)) + d * 30
    cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    scn.collection.objects.link(cam)
    scn.camera = cam
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = (math.radians(50), 0, math.radians(30))
    scn.collection.objects.link(sun)
    scn.world = bpy.data.worlds.new("w")
    scn.world.use_nodes = True
    scn.world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.07, 1)
    scn.render.engine = "CYCLES"
    scn.cycles.samples = 24
    scn.cycles.device = "CPU"
    scn.render.resolution_x, scn.render.resolution_y = 960, 540
    scn.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", required=True)
    ap.add_argument("--seeds", type=int, nargs="+", default=[1])
    ap.add_argument("--autumn", action="store_true")
    ap.add_argument("--render", default="")
    a = ap.parse_args(argv)
    clear()
    made = []
    for s in a.seeds:
        t = make_tree(s, a.autumn)
        export(t, f"{a.out}/tree_{'autumn' if a.autumn else 'dying'}_{s}.glb")
        made.append(t)
        print("exported seed", s, "verts", len(t.data.vertices))
    if a.render:
        render_preview(made, a.render)
