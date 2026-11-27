"""Whisperwood Clearing: the shared playtest layout used by both the Godot and Unreal slices.

    python tools/slice/make_layout.py assets/whisperwood/slice_layout.json

Coordinates are metres on the ground plane: x to the east, z to the south (Godot's +z; Unreal +Y),
centre (0, 0). Seeded, so both engines always get the identical forest.
"""
import json
import math
import random
import sys

R_PLAY = 18.0          # walkable radius
rng = random.Random(1127)

PATH = [(0.0, 17.0), (2.5, 10.0), (-1.5, 3.0), (1.5, -4.0), (0.0, -9.5)]
OAK = (0.0, -15.0)


def dist_seg(p, a, b):
    ax, az = a
    bx, bz = b
    px, pz = p
    dx, dz = bx - ax, bz - az
    t = max(0.0, min(1.0, ((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz)))
    return math.hypot(px - (ax + t * dx), pz - (az + t * dz))


def path_dist(p):
    return min(dist_seg(p, PATH[i], PATH[i + 1]) for i in range(len(PATH) - 1))


props, blockers = [], []
occupied = []   # (x, z, r) for spacing


def free(x, z, r, path_clear=2.4):
    if path_dist((x, z)) < path_clear + r:
        return False
    if math.hypot(x - OAK[0], z - OAK[1]) < 7.5 + r:
        return False
    return all(math.hypot(x - ox, z - oz) > r + orr for ox, oz, orr in occupied)


def place(kind, x, z, r_space, block=0.0, scale=1.0, rot=None):
    props.append({"kind": kind, "x": round(x, 2), "z": round(z, 2), "rot": round(rng.uniform(0, 360) if rot is None else rot, 1), "scale": round(scale, 2)})
    occupied.append((x, z, r_space))
    if block > 0:
        blockers.append([round(x, 2), round(z, 2), round(block * scale, 2)])


# landmark + stone ring
place("hollow_oak", OAK[0], OAK[1], 3.0, block=1.6, rot=200)
for k in range(6):
    a = k / 6 * math.tau + 0.3
    place("standing_stone", OAK[0] + math.cos(a) * 6.0, OAK[1] + math.sin(a) * 6.0 * 0.8, 0.8, block=0.5, scale=rng.uniform(0.9, 1.25))

# forest wall: two rings of trees just outside the walkable area (camera-side ones are dead/lower)
for ring_r, n in ((R_PLAY + 2.5, 34), (R_PLAY + 6.0, 40)):
    for k in range(n):
        a = k / n * math.tau + rng.uniform(-0.05, 0.05)
        x, z = math.cos(a) * ring_r, math.sin(a) * ring_r
        if path_dist((x, z)) < 3.0 and z > 0:   # keep the southern entrance open
            continue
        camera_side = x + z > 8.0
        kind = rng.choice(["tree_dead_1", "bush_1", "bush_2"]) if camera_side else rng.choice(["tree_dying_1", "tree_dying_2", "tree_dying_3", "tree_dying_1", "tree_dead_1"])
        place(kind, x, z, 1.2, block=0.7 if kind.startswith("tree") else 0.0, scale=rng.uniform(0.85, 1.15))

# a few groves inside, away from the path and the camera-side half
# far side of the clearing only (the camera looks from the south-east), clear of the path
for gx, gz in ((-12.5, -5.0), (11.5, -11.0)):
    for k in range(3):
        x, z = gx + rng.uniform(-2.5, 2.5), gz + rng.uniform(-2.5, 2.5)
        if free(x, z, 1.6):
            place(rng.choice(["tree_dying_1", "tree_dying_2", "tree_dying_3"]), x, z, 1.6, block=0.7, scale=rng.uniform(0.85, 1.1))

# rocks and a fallen log
for kind, n, rs, blk in (("rock_2", 4, 1.6, 1.1), ("rock_1", 6, 1.0, 0.7), ("rock_3", 8, 0.6, 0.0), ("log_1", 2, 2.4, 0.0)):
    for k in range(n):
        for tries in range(40):
            a, d = rng.uniform(0, math.tau), rng.uniform(4, R_PLAY - 1.5)
            x, z = math.cos(a) * d, math.sin(a) * d
            if free(x, z, rs):
                place(kind, x, z, rs, block=blk)
                if kind == "log_1":   # logs block along their length: three circles
                    rot = math.radians(props[-1]["rot"])
                    blockers.extend([[round(x + math.cos(rot) * o, 2), round(z - math.sin(rot) * o, 2), 0.45] for o in (-1.4, 0.0, 1.4)])
                break

# undergrowth (no collision)
for kind, n, rs in (("fern_1", 26, 0.6), ("fern_2", 20, 0.6), ("grass_1", 60, 0.35), ("grass_2", 50, 0.35), ("flowers_1", 18, 0.4),
                    ("bush_1", 8, 0.9), ("bush_2", 8, 0.9), ("mushroom_plain", 14, 0.4)):
    for k in range(n):
        for tries in range(30):
            a, d = rng.uniform(0, math.tau), rng.uniform(2.0, R_PLAY + 1.0)
            x, z = math.cos(a) * d, math.sin(a) * d
            if free(x, z, rs, path_clear=1.3):
                place(kind, x, z, rs, scale=rng.uniform(0.8, 1.25))
                break

# Emberhood mushrooms: glowing, a future gathering node (one by the path, the rest off it)
ember = []
for x, z in ((3.8, 6.0), (-6.5, -9.0), (8.5, 3.5), (-4.0, 14.0)):
    place("mushroom_ember", x, z, 0.5, scale=1.2)
    ember.append([x, z])

layout = {
    "name": "Whisperwood Clearing",
    "size_m": 48.0,
    "walk_radius_m": R_PLAY,
    "player_start": [0.0, 15.5],
    "path": PATH,
    "landmark": {"kind": "hollow_oak", "x": OAK[0], "z": OAK[1], "light": [1.0, 0.45, 0.12]},
    "ember_lights": ember,
    "props": props,
    "blockers": blockers,
    "packs": [
        {"x": -6.0, "z": 4.0, "n": 3},
        {"x": 8.0, "z": -3.0, "n": 4},
        {"x": -3.0, "z": -8.5, "n": 4},
    ],
    "respawn_s": 6.0,
    "animals": {
        "deer": [[11.0, 9.0, 220], [-12.0, -5.0, 40]],
        "crow": [[OAK[0] + 4.5, OAK[1] + 3.0, 0], [OAK[0] - 5.0, OAK[1] + 2.0, 90], [6.0, 2.0, 180], [-8.0, 8.0, 270], [-2.0, -5.0, 30]],
    },
    "mood": {"sun_color": [1.0, 0.68, 0.42], "sun_pitch_deg": 28, "sun_yaw_deg": 205, "fog_color": [0.32, 0.26, 0.22], "ambient": [0.36, 0.33, 0.38]},
}
json.dump(layout, open(sys.argv[1], "w"), indent=1)
print("props", len(props), "blockers", len(blockers))
