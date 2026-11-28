"""Chapter 1 asset kit (original, procedural): swamp and barrow scenery, camp, arena, and creatures.

    /root/bpyenv/bin/python tools/blender/chapter1.py --tex assets/whisperwood --out assets/chapter1 [--only a,b]

Reuses the Whisperwood helpers (materials, blobs, skin meshes, rigs). Same style rules: grounded,
slightly stylized, flat-faceted low poly with procedural textures. Creatures are rigid-part rigs with
actions named like the KayKit characters so the game's Puppet can drive them:
Idle, Running_A, 1H_Melee_Attack_Chop, Spellcast_Shoot, Hit_A, Death_A.
They face Blender +Y (glTF -Z); ModelsDB marks them with "yaw": PI.
"""
import argparse
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
import whisperwood as WW  # noqa: E402  (imports bpy first)
import bmesh  # noqa: E402
import bpy  # noqa: E402
from mathutils import Vector, noise  # noqa: E402

from whisperwood import (_limb, activate, apply_xf, bind, blob, export, flat, join, keyframes, material,  # noqa: E402
                         obj_from_bm, rig, skin_mesh, uv_project)


def mats():
    M = WW.mats()
    M.update({
        "cypress_bark": material("CypressBark", (0.62, 0.58, 0.52), "tex_bark.png", 0.95),
        "hang_moss": material("HangMoss", (0.36, 0.42, 0.3), rough=0.9),
        "swamp_leaf": [material("SwampLeaf", (0.14, 0.2, 0.1), rough=0.8), material("SwampLeaf2", (0.2, 0.24, 0.12), rough=0.8)],
        "reed": material("Reed", (0.36, 0.38, 0.16), rough=0.8),
        "reed_dry": material("ReedDry", (0.55, 0.46, 0.25), rough=0.8),
        "cattail": material("Cattail", (0.28, 0.16, 0.08), rough=0.9),
        "lily": material("Lily", (0.16, 0.3, 0.1), rough=0.45),
        "lily_flower": material("LilyFlower", (0.95, 0.9, 0.85), rough=0.5, emit=(0.9, 0.9, 0.7), emit_strength=0.4),
        "stone": material("Stone", (0.9, 0.9, 0.92), "tex_rock.png", 0.9),
        "stone_dark": material("StoneDark", (0.55, 0.55, 0.6), "tex_rock.png", 0.9),
        "wood": material("Wood", (0.55, 0.4, 0.28), "tex_bark.png", 0.9),
        "plank": material("Plank", (0.42, 0.3, 0.2), rough=0.9),
        "canvas": material("Canvas", (0.62, 0.55, 0.42), rough=0.95),
        "coal": material("Coal", (0.9, 0.3, 0.05), rough=0.6, emit=(1.0, 0.35, 0.05), emit_strength=8.0),
        "rune": material("Rune", (0.4, 0.75, 1.0), rough=0.3, emit=(0.35, 0.7, 1.0), emit_strength=10.0),
        "soul": material("SoulFire", (0.55, 0.85, 1.0), rough=0.3, emit=(0.45, 0.8, 1.0), emit_strength=12.0),
        "iron": material("Iron", (0.25, 0.24, 0.24), rough=0.5, metal=0.8),
        "gold": material("Gold", (0.85, 0.65, 0.25), rough=0.35, metal=1.0),
        # creatures
        "wolf_fur": material("WolfFur", (0.24, 0.22, 0.21), rough=0.95),
        "wolf_fur_light": material("WolfFurLight", (0.5, 0.47, 0.43), rough=0.95),
        "eye_ember": material("EyeEmber", (1.0, 0.5, 0.1), rough=0.3, emit=(1.0, 0.45, 0.1), emit_strength=14.0),
        "eye_green": material("EyeGreen", (0.6, 1.0, 0.3), rough=0.3, emit=(0.5, 1.0, 0.25), emit_strength=14.0),
        "chitin": material("Chitin", (0.12, 0.1, 0.09), rough=0.35),
        "chitin_mark": material("ChitinMark", (0.55, 0.12, 0.05), rough=0.4),
        "toad_skin": material("ToadSkin", (0.26, 0.32, 0.14), rough=0.6),
        "toad_belly": material("ToadBelly", (0.62, 0.58, 0.36), rough=0.6),
        "toad_wart": material("ToadWart", (0.45, 0.62, 0.15), rough=0.5, emit=(0.4, 0.7, 0.1), emit_strength=1.5),
        "thorn_bark": material("ThornBark", (0.5, 0.42, 0.34), "tex_bark.png", 0.95),
    })
    return M


# ---------------------------------------------------------------- swamp

def make_cypress(seed, M):
    rng = random.Random(seed)
    h = rng.uniform(8.0, 10.5)
    verts, edges, radii = [Vector((0, 0, 0))], [], [0.9]
    # buttressed base tapering into a tall trunk
    n = 8
    for i in range(1, n + 1):
        t = i / n
        verts.append(Vector((math.sin(t * 3) * 0.25, math.cos(t * 2) * 0.2, h * t)))
        radii.append(0.9 * (1 - t) ** 2.2 + 0.18)
        edges.append((i - 1, i))
    tips = []
    for k in range(rng.randint(4, 6)):   # crooked horizontal limbs near the top
        base_i = rng.randint(n - 4, n - 1)
        b = verts[base_i]
        a = rng.uniform(0, math.tau)
        L = rng.uniform(1.6, 3.0)
        tip = b + Vector((math.cos(a) * L, math.sin(a) * L, rng.uniform(-0.3, 0.6)))
        verts.append(tip)
        radii.append(0.06)
        edges.append((base_i, len(verts) - 1))
        tips.append(tip)
    trunk = skin_mesh(f"cypress_{seed}", verts, edges, radii, M["cypress_bark"])
    uv_project(trunk, scale=h / 1.6)
    parts = [trunk]
    for r in range(5):   # knee roots around the base
        a = r / 5 * math.tau + rng.uniform(-0.3, 0.3)
        k = blob("knee", Vector((math.cos(a) * 1.4, math.sin(a) * 1.4, 0.15)), 0.22, rng, M["cypress_bark"], 1.8, 1, 0.1)
        parts.append(k)
    for t in tips + [verts[n]]:
        parts.append(blob("leaf", t + Vector((0, 0, 0.3)), rng.uniform(0.8, 1.3), rng, rng.choice(M["swamp_leaf"]), 0.45, 1, 0.25))
        for s in range(rng.randint(3, 6)):   # hanging moss strands
            bm = bmesh.new()
            L = rng.uniform(1.2, 2.6)
            off = Vector((rng.uniform(-0.8, 0.8), rng.uniform(-0.8, 0.8), 0))
            bmesh.ops.create_cone(bm, cap_ends=False, segments=3, radius1=0.02, radius2=0.12, depth=L)
            st = obj_from_bm("moss", bm, M["hang_moss"])
            st.location = t + off - Vector((0, 0, L / 2))
            parts.append(st)
    ob = join(parts, f"swamp_cypress_{seed}")
    flat(ob)
    return ob


def make_snag(seed, M):
    rng = random.Random(seed)
    h = rng.uniform(3.0, 4.5)
    verts = [Vector((0, 0, 0)), Vector((0.1, 0, h * 0.5)), Vector((0.2, 0.1, h))]
    edges = [(0, 1), (1, 2)]
    radii = [0.55, 0.32, 0.18]
    for k in range(3):
        b = rng.randint(1, 2)
        a = rng.uniform(0, math.tau)
        verts.append(verts[b] + Vector((math.cos(a) * 1.2, math.sin(a) * 1.2, rng.uniform(0.2, 0.8))))
        radii.append(0.05)
        edges.append((b, len(verts) - 1))
    ob = skin_mesh(f"snag_{seed}", verts, edges, radii, M["bark_pale"])
    uv_project(ob, scale=2.5)
    parts = [ob, blob("moss", Vector((0, 0, 0.2)), 0.7, rng, M["moss"], 0.3, 1, 0.15)]
    ob = join(parts, f"swamp_snag_{seed}")
    flat(ob)
    return ob


def make_reeds(seed, M):
    rng = random.Random(seed)
    bm = bmesh.new()
    for k in range(22):
        a = rng.uniform(0, math.tau)
        d = Vector((math.cos(a), math.sin(a), 0)) * 0.15
        base = Vector((rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3), 0))
        WW.blade(bm, base, d, rng.uniform(0.9, 1.6), 0.03, rng.uniform(0.0, 0.25), 3)
    ob = obj_from_bm(f"reeds_{seed}", bm, M["reed" if seed % 2 else "reed_dry"])
    parts = [ob]
    for k in range(rng.randint(3, 6)):   # cattail heads
        x, y = rng.uniform(-0.3, 0.3), rng.uniform(-0.3, 0.3)
        h = rng.uniform(1.2, 1.7)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=False, segments=4, radius1=0.01, radius2=0.01, depth=h)
        s = obj_from_bm("stalk", bm, M["reed"])
        s.location = (x, y, h / 2)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=6, radius1=0.045, radius2=0.045, depth=0.22)
        c = obj_from_bm("cat", bm, M["cattail"])
        c.location = (x, y, h + 0.05)
        parts += [s, c]
    return join(parts, f"reeds_{seed}")


def make_lily(seed, M):
    rng = random.Random(seed)
    parts = []
    for k in range(rng.randint(4, 7)):
        bm = bmesh.new()
        r = rng.uniform(0.18, 0.32)
        bmesh.ops.create_circle(bm, cap_ends=True, segments=10, radius=r)
        # notch
        for v in bm.verts:
            if v.co.x > r * 0.8 and abs(v.co.y) < r * 0.3:
                v.co *= 0.4
        p = obj_from_bm("pad", bm, M["lily"])
        p.location = (rng.uniform(-0.7, 0.7), rng.uniform(-0.7, 0.7), 0.02)
        p.rotation_euler = (0, 0, rng.uniform(0, math.tau))
        parts.append(p)
    if seed % 2 == 0:
        f = blob("flower", Vector((0.1, 0.1, 0.08)), 0.08, rng, M["lily_flower"], 0.6, 1, 0.1)
        parts.append(f)
    return join(parts, f"lily_pads_{seed}")


def make_hummock(seed, M):
    rng = random.Random(seed)
    parts = [blob("mound", Vector((0, 0, 0.0)), 0.9, rng, M["moss"], 0.35, 2, 0.12)]
    for k in range(4):
        g = WW.make_grass(seed + k, M)
        g.location = (rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0.2)
        parts.append(g)
    return join(parts, f"swamp_hummock_{seed}")


# ---------------------------------------------------------------- stone and wood

def _box(name, size, loc, mat, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    ob = obj_from_bm(name, bm, mat)
    ob.scale = size
    ob.location = loc
    ob.rotation_euler = rot
    apply_xf(ob)
    return ob


def _cyl(name, r1, r2, h, loc, mat, seg=10, rot=(0, 0, 0)):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r1, radius2=r2, depth=h)
    ob = obj_from_bm(name, bm, mat)
    ob.location = loc
    ob.rotation_euler = rot
    apply_xf(ob)
    return ob


def _chip(ob, rng, amount=0.06):
    """Jitter vertices a little so stone looks hand-cut and worn."""
    for v in ob.data.vertices:
        v.co += Vector((rng.uniform(-amount, amount), rng.uniform(-amount, amount), rng.uniform(-amount, amount) * 0.5))


def make_pillar_ruin(seed, M):
    rng = random.Random(seed)
    h = rng.uniform(1.4, 2.8)
    parts = [_cyl("base", 0.55, 0.55, 0.3, (0, 0, 0.15), M["stone"], 8)]
    z = 0.3
    while z < h:
        seg = min(rng.uniform(0.5, 0.8), h - z + 0.05)
        c = _cyl("drum", 0.36, 0.34, seg, (rng.uniform(-0.03, 0.03), rng.uniform(-0.03, 0.03), z + seg / 2), M["stone"], 10)
        _chip(c, rng, 0.03)
        parts.append(c)
        z += seg
    top = parts[-1]
    for v in top.data.vertices:   # broken, slanted top
        if v.co.z > z - 0.05:
            v.co.z -= rng.uniform(0.0, 0.35)
    parts.append(blob("moss", Vector((0.1, 0, z - 0.2)), 0.3, rng, M["moss"], 0.4, 1, 0.1))
    for k in range(2):
        d = _box("chunk", (0.35, 0.3, 0.25), (rng.uniform(-1, 1), rng.uniform(-1, 1), 0.12), M["stone"], (0, 0, rng.uniform(0, 3)))
        _chip(d, rng, 0.05)
        parts.append(d)
    ob = join(parts, f"pillar_ruin_{seed}")
    uv_project(ob, 1.2)
    flat(ob)
    return ob


def make_pillar_great(seed, M):
    rng = random.Random(seed)
    parts = [_box("plinth", (1.6, 1.6, 0.6), (0, 0, 0.3), M["stone_dark"])]
    parts.append(_cyl("shaft", 0.55, 0.48, 5.0, (0, 0, 3.1), M["stone"], 12))
    parts.append(_box("capital", (1.4, 1.4, 0.45), (0, 0, 5.8), M["stone_dark"]))
    for k in range(4):   # carved bands
        parts.append(_cyl("band", 0.6, 0.6, 0.12, (0, 0, 1.2 + k * 1.1), M["stone_dark"], 12))
    # soul brazier on top
    parts.append(_cyl("bowl", 0.3, 0.55, 0.4, (0, 0, 6.2), M["iron"], 8))
    parts.append(blob("coal", Vector((0, 0, 6.4)), 0.38, rng, M["soul"], 0.4, 1, 0.1))
    for p in parts:
        _chip(p, rng, 0.02)
    ob = join(parts, f"pillar_great_{seed}")
    uv_project(ob, 2.0)
    flat(ob)
    return ob


def make_tower_ruin(seed, M):
    rng = random.Random(seed)
    parts = []
    R = 2.6
    for ring in range(7):
        n = 14
        for k in range(n):
            a = k / n * math.tau + (ring % 2) * 0.22
            # a broken side: fewer blocks towards the front
            front = math.cos(a - 0.8)
            if ring > 1 and front > 0.2 and rng.random() < 0.4 + ring * 0.08:
                continue
            if ring > 4 and rng.random() < 0.4:
                continue
            b = _box("blk", (1.15, 0.55, 0.5), (math.cos(a) * R, math.sin(a) * R, 0.25 + ring * 0.5), M["stone"], (0, 0, a + math.pi / 2))
            _chip(b, rng, 0.04)
            parts.append(b)
    for k in range(6):
        d = _box("rubble", (0.6, 0.5, 0.4), (rng.uniform(-3.5, 3.5) + 2.0, rng.uniform(-3.5, 3.5) + 1.5, 0.2), M["stone"], (rng.uniform(-0.3, 0.3), 0, rng.uniform(0, 3)))
        parts.append(d)
    parts.append(blob("moss", Vector((0, 0, 0.1)), 2.2, rng, M["moss"], 0.12, 2, 0.1))
    ob = join(parts, f"tower_ruin_{seed}")
    uv_project(ob, 1.5)
    flat(ob)
    return ob


def make_throne(seed, M):
    rng = random.Random(seed)
    parts = [_box("dais", (4.5, 3.2, 0.5), (0, 0, 0.25), M["stone_dark"]), _box("dais2", (3.4, 2.4, 0.4), (0, -0.2, 0.7), M["stone"])]
    parts += [_box("seat", (1.8, 1.2, 0.7), (0, -0.3, 1.25), M["stone_dark"]), _box("back", (1.9, 0.45, 3.2), (0, -0.85, 2.5), M["stone_dark"])]
    for s in (-1, 1):
        parts.append(_box("arm", (0.35, 1.2, 0.7), (s * 1.0, -0.3, 1.75), M["stone"]))
        # antler crown on the back
        verts = [Vector((s * 0.5, -0.85, 4.0)), Vector((s * 1.2, -0.85, 4.9)), Vector((s * 1.9, -0.8, 5.3)), Vector((s * 1.0, -0.8, 5.6))]
        edges = [(0, 1), (1, 2), (1, 3)]
        parts.append(skin_mesh("antler", verts, edges, [0.18, 0.12, 0.05, 0.05], M["bark_pale"], 1))
        parts.append(_cyl("candle", 0.08, 0.08, 0.4, (s * 1.8, 0.6, 0.7), M["stem"], 6))
        parts.append(blob("flame", Vector((s * 1.8, 0.6, 0.98)), 0.06, rng, M["soul"], 1.4, 1, 0.05))
    parts.append(blob("rune", Vector((0, -0.6, 3.6)), 0.25, rng, M["soul"], 1.0, 1, 0.05))
    for p in parts:
        _chip(p, rng, 0.02)
    ob = join(parts, f"throne_{seed}")
    uv_project(ob, 1.5)
    flat(ob)
    return ob


def make_brazier(seed, M):
    rng = random.Random(seed)
    parts = [_cyl("foot", 0.4, 0.25, 0.3, (0, 0, 0.15), M["stone_dark"], 8), _cyl("stem", 0.15, 0.15, 0.8, (0, 0, 0.7), M["iron"], 6),
             _cyl("bowl", 0.25, 0.5, 0.35, (0, 0, 1.25), M["iron"], 10), blob("coal", Vector((0, 0, 1.4)), 0.35, rng, M["coal"], 0.35, 1, 0.1)]
    ob = join(parts, f"brazier_{seed}")
    flat(ob)
    return ob


def make_campfire(seed, M):
    rng = random.Random(seed)
    parts = []
    for k in range(9):
        a = k / 9 * math.tau
        r = blob("stone", Vector((math.cos(a) * 0.65, math.sin(a) * 0.65, 0.08)), 0.16, rng, M["stone"], 0.7, 1, 0.15)
        parts.append(r)
    for k in range(4):
        a = k / 4 * math.tau + 0.3
        parts.append(_cyl("log", 0.08, 0.07, 0.9, (math.cos(a) * 0.2, math.sin(a) * 0.2, 0.18), M["wood"], 6, (0.4 * math.sin(a), 0.4 * math.cos(a) + math.pi / 2, a)))
    parts.append(blob("embers", Vector((0, 0, 0.05)), 0.3, rng, M["coal"], 0.3, 1, 0.1))
    ob = join(parts, f"campfire_{seed}")
    flat(ob)
    return ob


def make_tent(seed, M):
    bm = bmesh.new()
    L, Wd, Hh = 2.6, 1.3, 1.5
    v = [bm.verts.new(p) for p in [(-Wd, -L / 2, 0), (Wd, -L / 2, 0), (0, -L / 2, Hh), (-Wd, L / 2, 0), (Wd, L / 2, 0), (0, L / 2, Hh)]]
    bm.faces.new((v[0], v[3], v[5], v[2]))
    bm.faces.new((v[1], v[2], v[5], v[4]))
    bm.faces.new((v[3], v[4], v[5]))   # back closed, front open
    ob = obj_from_bm("canvas", bm, M["canvas"])
    parts = [ob, _cyl("pole", 0.04, 0.04, 1.7, (0, -L / 2 - 0.05, 0.85), M["wood"], 5), _cyl("pole2", 0.04, 0.04, 1.7, (0, L / 2 + 0.05, 0.85), M["wood"], 5),
             _box("bedroll", (0.7, 1.6, 0.15), (0.2, 0.2, 0.08), M["fur"])]
    return join(parts, f"tent_{seed}")


def make_waystone(seed, M):
    rng = random.Random(seed)
    parts = [_box("base", (1.4, 1.4, 0.4), (0, 0, 0.2), M["stone_dark"])]
    s = _box("stone", (0.7, 0.45, 2.4), (0, 0, 1.6), M["stone"])
    for v in s.data.vertices:
        if v.co.z > 2.6:
            v.co.x *= 0.6
    parts.append(s)
    for k in range(4):
        parts.append(_box("rune", (0.18, 0.05, 0.18), (rng.uniform(-0.15, 0.15), -0.24, 1.0 + k * 0.45), M["rune"]))
    parts.append(blob("orb", Vector((0, 0, 3.0)), 0.18, rng, M["rune"], 1.0, 1, 0.05))
    ob = join(parts, f"waystone_{seed}")
    uv_project(ob, 1.0)
    flat(ob)
    return ob


def make_bridge(seed, M):
    """8 m plank bridge along +Y (Godot -Z), 3.4 m wide, with posts and rope rails."""
    rng = random.Random(seed)
    parts = []
    for i in range(20):
        y = -4.0 + i * 0.42
        p = _box("plank", (3.4, 0.36, 0.08), (rng.uniform(-0.05, 0.05), y, 0.32 + math.sin(i / 19 * math.pi) * 0.25), M["plank"], (0, 0, rng.uniform(-0.04, 0.04)))
        parts.append(p)
    for s in (-1, 1):
        parts.append(_box("beam", (0.2, 8.4, 0.2), (s * 1.5, 0, 0.18), M["wood"]))
        for k in range(5):
            y = -4.0 + k * 2.0
            zt = 0.32 + math.sin((k * 2.0 / 8.0) * math.pi) * 0.25
            parts.append(_cyl("post", 0.09, 0.09, 1.6, (s * 1.65, y, zt + 0.2), M["wood"], 6))
        parts.append(_box("rail", (0.06, 8.0, 0.06), (s * 1.65, 0, 1.15), M["wood"]))
    ob = join(parts, f"bridge_{seed}")
    uv_project(ob, 2.0)
    flat(ob)
    return ob


# ---------------------------------------------------------------- creatures

def anims(arm, idle, run, attack, hit, death, cast=None):
    keyframes(arm, "Idle", idle[0], idle[1])
    keyframes(arm, "Running_A", run[0], run[1])
    keyframes(arm, "1H_Melee_Attack_Chop", attack[0], attack[1])
    keyframes(arm, "Hit_A", hit[0], hit[1])
    keyframes(arm, "Death_A", death[0], death[1])
    if cast:
        keyframes(arm, "Spellcast_Shoot", cast[0], cast[1])


def make_wolf(M):
    rng = random.Random(21)
    body = blob("body", Vector((0, 0, 0.75)), 0.32, rng, M["wolf_fur"], 1.0, 1, 0.08)
    body.scale = (0.7, 1.9, 0.75)
    apply_xf(body)
    ruff = blob("ruff", Vector((0, 0.42, 0.85)), 0.3, rng, M["wolf_fur"], 1.0, 1, 0.18)
    belly = blob("belly", Vector((0, 0.0, 0.62)), 0.22, rng, M["wolf_fur_light"], 0.8, 1, 0.05)
    belly.scale = (0.8, 2.0, 0.6)
    apply_xf(belly)
    head = blob("head", Vector((0, 0.78, 0.95)), 0.17, rng, M["wolf_fur"], 0.9, 1, 0.06)
    snout = _cyl("snout", 0.1, 0.06, 0.32, (0, 1.02, 0.9), M["wolf_fur_light"], 6, (math.pi / 2, 0, 0))
    jaw = _cyl("jaw", 0.07, 0.04, 0.26, (0, 0.98, 0.82), M["wolf_fur_light"], 6, (math.pi / 2 + 0.25, 0, 0))
    ears = [_cyl("ear", 0.05, 0.0, 0.16, (s * 0.09, 0.74, 1.12), M["wolf_fur"], 4) for s in (-1, 1)]
    eyes = [blob("eye", Vector((s * 0.08, 0.92, 1.0)), 0.025, rng, M["eye_ember"], 1.0, 1, 0.0) for s in (-1, 1)]
    tail = _cyl("tail", 0.07, 0.03, 0.6, (0, -0.85, 0.75), M["wolf_fur"], 6, (-1.0, 0, 0))
    legs = {}
    for nm, x, y in (("leg_FL", -0.14, 0.42), ("leg_FR", 0.14, 0.42), ("leg_BL", -0.14, -0.45), ("leg_BR", 0.14, -0.45)):
        legs[nm] = _limb(nm, (x, y, 0.7), 0.7, 0.055, M["wolf_fur"])
    bones = [("root", (0, 0, 0), (0, 0, 0.3), None), ("spine", (0, -0.5, 0.75), (0, 0.4, 0.75), "root"),
             ("head", (0, 0.55, 0.9), (0, 1.05, 0.9), "spine"), ("jaw", (0, 0.88, 0.85), (0, 1.1, 0.8), "head"),
             ("tail", (0, -0.6, 0.8), (0, -1.1, 0.6), "spine")]
    for nm, x, y in (("leg_FL", -0.14, 0.42), ("leg_FR", 0.14, 0.42), ("leg_BL", -0.14, -0.45), ("leg_BR", 0.14, -0.45)):
        bones.append((nm, (x, y, 0.7), (x, y, 0.02), "spine"))
    arm = rig("wolf", bones)
    parts = [(body, "spine"), (ruff, "spine"), (belly, "spine"), (head, "head"), (snout, "head"), (jaw, "jaw"), (tail, "tail")]
    parts += [(e, "head") for e in ears + eyes] + [(legs[n], n) for n in legs]
    bind(parts, arm, "wolf")
    sw = 0.8
    anims(arm,
          ({1: {"head": (0, 0, 0), "tail": (0, 0, 0.2), "spine": ("loc", 0, 0, 0)}, 20: {"head": (0.15, 0, 0.25), "tail": (0, 0, -0.2), "spine": ("loc", 0, 0, -0.02)}, 40: {"head": (0, 0, 0), "tail": (0, 0, 0.2), "spine": ("loc", 0, 0, 0)}}, 40),
          ({1: {"leg_FL": (sw, 0, 0), "leg_FR": (sw * 0.6, 0, 0), "leg_BL": (-sw, 0, 0), "leg_BR": (-sw * 0.6, 0, 0), "spine": ("loc", 0, 0, 0.0), "head": (0.1, 0, 0)},
            5: {"leg_FL": (-sw, 0, 0), "leg_FR": (-sw * 0.6, 0, 0), "leg_BL": (sw, 0, 0), "leg_BR": (sw * 0.6, 0, 0), "spine": ("loc", 0, 0, 0.1), "head": (-0.1, 0, 0)},
            10: {"leg_FL": (sw, 0, 0), "leg_FR": (sw * 0.6, 0, 0), "leg_BL": (-sw, 0, 0), "leg_BR": (-sw * 0.6, 0, 0), "spine": ("loc", 0, 0, 0.0), "head": (0.1, 0, 0)}}, 10),
          ({1: {"spine": ("loc", 0, 0, 0), "head": (0, 0, 0), "jaw": (0, 0, 0), "leg_FL": (0, 0, 0), "leg_FR": (0, 0, 0)},
            6: {"spine": ("loc", 0, -0.2, -0.08), "head": (-0.3, 0, 0), "jaw": (0, 0, 0), "leg_FL": (-0.4, 0, 0), "leg_FR": (-0.4, 0, 0)},
            11: {"spine": ("loc", 0, 0.45, 0.15), "head": (0.35, 0, 0), "jaw": (0.6, 0, 0), "leg_FL": (1.0, 0, 0), "leg_FR": (1.0, 0, 0)},
            18: {"spine": ("loc", 0, 0, 0), "head": (0, 0, 0), "jaw": (0, 0, 0), "leg_FL": (0, 0, 0), "leg_FR": (0, 0, 0)}}, 18),
          ({1: {"spine": ("loc", 0, 0, 0), "head": (0, 0, 0)}, 3: {"spine": ("loc", 0, -0.12, 0), "head": (-0.4, 0, 0.3)}, 8: {"spine": ("loc", 0, 0, 0), "head": (0, 0, 0)}}, 8),
          ({1: {"root": (0, 0, 0), "spine": ("loc", 0, 0, 0)}, 10: {"root": (0, 1.45, 0), "spine": ("loc", 0, 0, -0.4)}, 30: {"root": (0, 1.57, 0), "spine": ("loc", 0, 0, -0.45)}}, 30))
    return arm


def make_spider(M):
    rng = random.Random(33)
    abdomen = blob("abd", Vector((0, -0.55, 0.65)), 0.48, rng, M["chitin"], 0.85, 1, 0.08)
    mark = blob("mark", Vector((0, -0.62, 1.03)), 0.2, rng, M["chitin_mark"], 0.25, 1, 0.05)
    thorax = blob("thorax", Vector((0, 0.05, 0.55)), 0.28, rng, M["chitin"], 0.8, 1, 0.06)
    head = blob("head", Vector((0, 0.38, 0.55)), 0.17, rng, M["chitin"], 0.9, 1, 0.05)
    eyes = [blob("eye", Vector((s * 0.07 * (1 + k % 2), 0.52, 0.62 + 0.04 * (k // 2))), 0.03, rng, M["eye_green"], 1.0, 1, 0.0) for s in (-1, 1) for k in range(3)]
    fangs = [_cyl("fang", 0.035, 0.0, 0.2, (s * 0.06, 0.55, 0.42), M["stem"], 4, (0.3, 0, 0)) for s in (-1, 1)]
    bones = [("root", (0, 0, 0), (0, 0, 0.3), None), ("body", (0, -0.2, 0.55), (0, 0.3, 0.55), "root"),
             ("abdomen", (0, -0.2, 0.6), (0, -1.0, 0.7), "body"), ("head", (0, 0.3, 0.55), (0, 0.6, 0.55), "body")]
    parts = [(abdomen, "abdomen"), (mark, "abdomen"), (thorax, "body"), (head, "head")] + [(e, "head") for e in eyes] + [(f, "head") for f in fangs]
    legs = []
    for side in (-1, 1):
        for i in range(4):
            a = (i - 1.5) * 0.45
            dx, dy = math.cos(a) * side, math.sin(a)
            knee = Vector((dx * 0.75, 0.05 + dy * 0.75, 0.95))
            foot = Vector((dx * 1.35, 0.05 + dy * 1.35, 0.0))
            hip = Vector((dx * 0.2, 0.05 + dy * 0.2, 0.55))
            nm = f"leg_{'L' if side < 0 else 'R'}{i}"
            up = skin_mesh(nm + "a", [hip, knee], [(0, 1)], [0.05, 0.04], M["chitin"], 0)
            lo = skin_mesh(nm + "b", [knee, foot], [(0, 1)], [0.04, 0.015], M["chitin"], 0)
            bones.append((nm, tuple(hip), tuple(knee), "body"))
            bones.append((nm + "_lo", tuple(knee), tuple(foot), nm))
            parts += [(up, nm), (lo, nm + "_lo")]
            legs.append(nm)
    arm = rig("spider", bones)
    bind(parts, arm, "spider")

    def gait(phase_a):
        d = {}
        for k, nm in enumerate(legs):
            s = 0.35 if (k % 2 == 0) == phase_a else -0.35
            d[nm] = (0, 0, s)
        return d
    run1 = gait(True)
    run1["body"] = ("loc", 0, 0, 0)
    run2 = gait(False)
    run2["body"] = ("loc", 0, 0, 0.06)
    anims(arm,
          ({1: {"abdomen": (0, 0, 0), "body": ("loc", 0, 0, 0)}, 25: {"abdomen": (0.12, 0, 0), "body": ("loc", 0, 0, -0.03)}, 50: {"abdomen": (0, 0, 0), "body": ("loc", 0, 0, 0)}}, 50),
          ({1: run1, 4: run2, 8: run1}, 8),
          ({1: {"body": (0, 0, 0), "head": (0, 0, 0)}, 6: {"body": (-0.45, 0, 0), "head": (-0.3, 0, 0)}, 10: {"body": (0.25, 0, 0), "head": (0.5, 0, 0)}, 16: {"body": (0, 0, 0), "head": (0, 0, 0)}}, 16),
          ({1: {"body": (0, 0, 0)}, 3: {"body": (-0.25, 0.2, 0)}, 8: {"body": (0, 0, 0)}}, 8),
          ({1: {"root": (0, 0, 0)} | {nm: (0, 0, 0) for nm in legs}, 12: {"root": (3.0, 0, 0)} | {nm: (0, 0, 0.9 if "L" in nm else -0.9) for nm in legs}, 30: {"root": (3.1, 0, 0)} | {nm: (0, 0, 1.1 if "L" in nm else -1.1) for nm in legs}}, 30),
          ({1: {"abdomen": (0, 0, 0)}, 6: {"abdomen": (-0.7, 0, 0)}, 10: {"abdomen": (0.5, 0, 0)}, 16: {"abdomen": (0, 0, 0)}}, 16))
    return arm


def make_toad(M):
    rng = random.Random(44)
    body = blob("body", Vector((0, 0, 0.55)), 0.55, rng, M["toad_skin"], 0.7, 2, 0.1)
    body.scale = (1.15, 1.2, 1.0)
    apply_xf(body)
    belly = blob("belly", Vector((0, 0.25, 0.38)), 0.42, rng, M["toad_belly"], 0.6, 1, 0.05)
    head = blob("head", Vector((0, 0.55, 0.72)), 0.36, rng, M["toad_skin"], 0.55, 1, 0.06)
    head.scale = (1.3, 1.0, 1.0)
    apply_xf(head)
    jaw = blob("jaw", Vector((0, 0.62, 0.55)), 0.3, rng, M["toad_belly"], 0.35, 1, 0.04)
    jaw.scale = (1.3, 1.0, 1.0)
    apply_xf(jaw)
    eyes = [blob("eye", Vector((s * 0.25, 0.6, 0.98)), 0.09, rng, M["eye_ember"], 1.0, 1, 0.0) for s in (-1, 1)]
    warts = [blob("wart", Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.4, 0.3), rng.uniform(0.75, 0.95))), rng.uniform(0.05, 0.1), rng, M["toad_wart"], 0.8, 1, 0.05) for _ in range(10)]
    legs = {}
    for nm, x, y, L in (("leg_FL", -0.45, 0.45, 0.4), ("leg_FR", 0.45, 0.45, 0.4), ("leg_BL", -0.6, -0.35, 0.5), ("leg_BR", 0.6, -0.35, 0.5)):
        legs[nm] = _limb(nm, (x, y, L), L, 0.1, M["toad_skin"])
    bones = [("root", (0, 0, 0), (0, 0, 0.3), None), ("body", (0, -0.3, 0.55), (0, 0.4, 0.6), "root"),
             ("head", (0, 0.4, 0.7), (0, 0.9, 0.75), "body"), ("jaw", (0, 0.45, 0.55), (0, 0.9, 0.5), "head")]
    for nm, x, y, L in (("leg_FL", -0.45, 0.45, 0.4), ("leg_FR", 0.45, 0.45, 0.4), ("leg_BL", -0.6, -0.35, 0.5), ("leg_BR", 0.6, -0.35, 0.5)):
        bones.append((nm, (x, y, L), (x, y, 0.0), "body"))
    arm = rig("toad", bones)
    parts = [(body, "body"), (belly, "body"), (head, "head"), (jaw, "jaw")] + [(e, "head") for e in eyes] + [(w, "body") for w in warts]
    parts += [(legs[n], n) for n in legs]
    bind(parts, arm, "toad")
    anims(arm,
          ({1: {"body": ("loc", 0, 0, 0), "jaw": (0, 0, 0)}, 15: {"body": ("loc", 0, 0, 0.04), "jaw": (0.15, 0, 0)}, 30: {"body": ("loc", 0, 0, 0), "jaw": (0, 0, 0)}}, 30),
          ({1: {"body": ("loc", 0, 0, 0), "leg_BL": (0, 0, 0), "leg_BR": (0, 0, 0)}, 5: {"body": ("loc", 0, 0.1, 0.45), "leg_BL": (-1.0, 0, 0), "leg_BR": (-1.0, 0, 0)}, 10: {"body": ("loc", 0, 0, 0), "leg_BL": (0, 0, 0), "leg_BR": (0, 0, 0)}}, 10),
          ({1: {"body": (0, 0, 0), "jaw": (0, 0, 0)}, 6: {"body": (-0.3, 0, 0), "jaw": (0, 0, 0)}, 10: {"body": (0.25, 0, 0), "jaw": (0.7, 0, 0)}, 16: {"body": (0, 0, 0), "jaw": (0, 0, 0)}}, 16),
          ({1: {"body": (0, 0, 0)}, 3: {"body": (-0.25, 0, 0.2)}, 8: {"body": (0, 0, 0)}}, 8),
          ({1: {"root": (0, 0, 0), "body": ("loc", 0, 0, 0)}, 12: {"root": (0, 3.1, 0), "body": ("loc", 0, 0, 0.6)}, 30: {"root": (0, 3.14, 0), "body": ("loc", 0, 0, 0.55)}}, 30),
          ({1: {"body": ("loc", 0, 0, 0), "head": (0, 0, 0), "jaw": (0, 0, 0)}, 8: {"body": ("loc", 0, 0, 0.1), "head": (-0.4, 0, 0), "jaw": (0.0, 0, 0)},
            12: {"body": ("loc", 0, 0, 0), "head": (0.2, 0, 0), "jaw": (0.9, 0, 0)}, 20: {"body": ("loc", 0, 0, 0), "head": (0, 0, 0), "jaw": (0, 0, 0)}}, 20))
    return arm


def make_thornling(M):
    """A small walking treant: bark body, thorn crown, root legs and club arms."""
    rng = random.Random(55)
    torso = skin_mesh("torso", [Vector((0, 0, 0.9)), Vector((0, 0.05, 1.7)), Vector((0, 0.1, 2.3))], [(0, 1), (1, 2)], [0.42, 0.38, 0.28], M["thorn_bark"], 1)
    uv_project(torso, 2.0)
    crown = []
    for k in range(7):
        a = k / 7 * math.tau
        crown.append(_cyl("thorn", 0.08, 0.0, rng.uniform(0.4, 0.8), (math.cos(a) * 0.22, 0.1 + math.sin(a) * 0.22, 2.55), M["bark_pale"], 4, (math.sin(a) * 0.6, -math.cos(a) * 0.6, 0)))
    crown.append(blob("leaves", Vector((0.15, 0.0, 2.5)), 0.45, rng, M["leaf"][0], 0.6, 1, 0.25))
    eyes = [blob("eye", Vector((s * 0.12, 0.38, 2.1)), 0.05, rng, M["eye_green"], 1.0, 1, 0.0) for s in (-1, 1)]
    arms = {}
    for s, nm in ((-1, "arm_L"), (1, "arm_R")):
        arms[nm] = skin_mesh(nm, [Vector((s * 0.35, 0.05, 2.0)), Vector((s * 0.75, 0.15, 1.4)), Vector((s * 0.8, 0.3, 0.75))], [(0, 1), (1, 2)], [0.14, 0.11, 0.22], M["thorn_bark"], 1)
    legs = {}
    for s, nm in ((-1, "leg_L"), (1, "leg_R")):
        legs[nm] = skin_mesh(nm, [Vector((s * 0.22, 0, 1.0)), Vector((s * 0.28, 0.05, 0.5)), Vector((s * 0.35, 0.15, 0.02))], [(0, 1), (1, 2)], [0.17, 0.14, 0.2], M["thorn_bark"], 1)
    bones = [("root", (0, 0, 0), (0, 0, 0.3), None), ("hips", (0, 0, 0.95), (0, 0, 1.3), "root"), ("chest", (0, 0, 1.3), (0, 0.1, 2.2), "hips"),
             ("arm_L", (-0.35, 0.05, 2.0), (-0.8, 0.3, 0.75), "chest"), ("arm_R", (0.35, 0.05, 2.0), (0.8, 0.3, 0.75), "chest"),
             ("leg_L", (-0.22, 0, 1.0), (-0.35, 0.15, 0.0), "hips"), ("leg_R", (0.22, 0, 1.0), (0.35, 0.15, 0.0), "hips")]
    arm = rig("thornling", bones)
    parts = [(torso, "chest")] + [(c, "chest") for c in crown] + [(e, "chest") for e in eyes] + [(arms[n], n) for n in arms] + [(legs[n], n) for n in legs]
    bind(parts, arm, "thornling")
    anims(arm,
          ({1: {"chest": (0, 0, 0), "arm_L": (0, 0, 0), "arm_R": (0, 0, 0)}, 30: {"chest": (0.06, 0, 0.08), "arm_L": (0.1, 0, 0), "arm_R": (-0.1, 0, 0)}, 60: {"chest": (0, 0, 0), "arm_L": (0, 0, 0), "arm_R": (0, 0, 0)}}, 60),
          ({1: {"leg_L": (0.5, 0, 0), "leg_R": (-0.5, 0, 0), "arm_L": (-0.4, 0, 0), "arm_R": (0.4, 0, 0), "hips": ("loc", 0, 0, 0)},
            8: {"leg_L": (-0.5, 0, 0), "leg_R": (0.5, 0, 0), "arm_L": (0.4, 0, 0), "arm_R": (-0.4, 0, 0), "hips": ("loc", 0, 0, 0.06)},
            16: {"leg_L": (0.5, 0, 0), "leg_R": (-0.5, 0, 0), "arm_L": (-0.4, 0, 0), "arm_R": (0.4, 0, 0), "hips": ("loc", 0, 0, 0)}}, 16),
          ({1: {"chest": (0, 0, 0), "arm_R": (0, 0, 0), "arm_L": (0, 0, 0)}, 10: {"chest": (-0.3, 0, 0.3), "arm_R": (-2.2, 0, 0), "arm_L": (-1.8, 0, 0)},
            15: {"chest": (0.45, 0, -0.1), "arm_R": (0.6, 0, 0), "arm_L": (0.7, 0, 0)}, 26: {"chest": (0, 0, 0), "arm_R": (0, 0, 0), "arm_L": (0, 0, 0)}}, 26),
          ({1: {"chest": (0, 0, 0)}, 3: {"chest": (-0.3, 0, 0.15)}, 8: {"chest": (0, 0, 0)}}, 8),
          ({1: {"root": (0, 0, 0), "chest": (0, 0, 0)}, 18: {"root": (-1.5, 0, 0.2), "chest": (-0.3, 0, 0)}, 40: {"root": (-1.55, 0, 0.2), "chest": (-0.35, 0, 0)}}, 40))
    return arm


# ---------------------------------------------------------------- main

def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    ap = argparse.ArgumentParser()
    ap.add_argument("--tex", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--only", default="")
    WW.ARGS = ap.parse_args(argv)
    out = WW.ARGS.out
    os.makedirs(out, exist_ok=True)
    jobs = [
        ("swamp_cypress", lambda M: make_cypress(7, M)), ("swamp_cypress_2", lambda M: make_cypress(19, M)), ("swamp_snag", lambda M: make_snag(4, M)),
        ("reeds_1", lambda M: make_reeds(1, M)), ("reeds_2", lambda M: make_reeds(2, M)), ("lily_pads", lambda M: make_lily(2, M)),
        ("swamp_hummock", lambda M: make_hummock(5, M)),
        ("pillar_ruin", lambda M: make_pillar_ruin(3, M)), ("pillar_great", lambda M: make_pillar_great(1, M)), ("tower_ruin", lambda M: make_tower_ruin(2, M)),
        ("throne", lambda M: make_throne(1, M)), ("brazier", lambda M: make_brazier(1, M)), ("campfire", lambda M: make_campfire(1, M)),
        ("tent", lambda M: make_tent(1, M)), ("waystone", lambda M: make_waystone(1, M)), ("bridge", lambda M: make_bridge(1, M)),
    ]
    for name, fn in jobs:
        if WW.ARGS.only and name not in WW.ARGS.only.split(","):
            continue
        WW.reset()
        M = mats()
        ob = fn(M)
        export(ob, os.path.join(out, name + ".glb"))
    for name, fn in [("wolf", make_wolf), ("spider", make_spider), ("toad", make_toad), ("thornling", make_thornling)]:
        if WW.ARGS.only and name not in WW.ARGS.only.split(","):
            continue
        WW.reset()
        M = mats()
        arm = fn(M)
        export(arm, os.path.join(out, name + ".glb"), anim=True)


if __name__ == "__main__":
    main()
