"""Chapter 1 terrain textures (original, procedural, tileable).

    python tools/blender/terrain_textures.py assets/chapter1/terrain

grass  : forest floor with grass tufts, moss and fallen leaves (Whisperwood)
litter : deep leaf litter and roots, the floor under the tree walls
mud    : wet dark peat with algae streaks (Mirefen)
path   : packed dirt and pebbles (the route)
barrow : pale dead grass over grey earth (Barrow Hills)
stone  : worn flagstones (arena, ruins)
water_n: a tileable normal map for the water shader
"""
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from textures import colorize, noise, save  # noqa: E402


def blades(n, rng, density, length=6):
    """Short dark-light strokes like grass blades (tileable)."""
    img = np.zeros((n, n))
    cnt = int(n * n * density)
    xs = rng.integers(0, n, cnt)
    ys = rng.integers(0, n, cnt)
    ang = rng.normal(-np.pi / 2, 0.35, cnt)
    for k in range(length):
        px = (xs + np.round(np.cos(ang) * k)).astype(int) % n
        py = (ys + np.round(np.sin(ang) * k)).astype(int) % n
        img[py, px] = np.maximum(img[py, px], 1.0 - k / length * 0.5)
    return img


def grass(n, rng):
    base = 0.6 * noise(n, rng, 2.1) + 0.4 * noise(n, rng, 1.0)
    col = colorize(base, [(0, (0.13, 0.17, 0.06)), (0.5, (0.24, 0.30, 0.10)), (1, (0.36, 0.40, 0.15))])
    b = blades(n, rng, 0.07)[..., None]
    bc = colorize(noise(n, rng, 1.6), [(0, (0.32, 0.40, 0.12)), (1, (0.52, 0.52, 0.20))])
    col = col * (1 - b * 0.7) + bc * b * 0.7
    dirt = np.clip((noise(n, rng, 2.4) - 0.72) * 4, 0, 1)[..., None]
    col = col * (1 - dirt) + colorize(noise(n, rng, 1.2), [(0, (0.14, 0.10, 0.07)), (1, (0.26, 0.19, 0.12))]) * dirt
    leaves = (noise(n, rng, 1.0) > 0.9)[..., None]
    lc = colorize(noise(n, rng, 1.4), [(0, (0.45, 0.20, 0.06)), (1, (0.60, 0.40, 0.12))])
    return col * (1 - leaves * 0.75) + lc * leaves * 0.75


def litter(n, rng):
    base = noise(n, rng, 1.2)
    col = colorize(base, [(0, (0.08, 0.05, 0.03)), (0.5, (0.22, 0.12, 0.05)), (1, (0.36, 0.22, 0.09))])
    roots = (np.abs(noise(n, rng, 2.2, aniso=(3.0, 0.4)) - 0.5) < 0.02)[..., None]
    return col * (1 - roots * 0.6) + np.array([0.2, 0.15, 0.1]) * roots * 0.6


def mud(n, rng):
    base = 0.45 * noise(n, rng, 1.6) + 0.35 * noise(n, rng, 0.9) + 0.2 * noise(n, rng, 2.4)
    col = colorize(base, [(0, (0.05, 0.05, 0.03)), (0.6, (0.13, 0.12, 0.07)), (1, (0.20, 0.19, 0.11))])
    algae = np.clip((noise(n, rng, 2.0, aniso=(1.0, 2.5)) - 0.55) * 3, 0, 1)[..., None]
    col = col * (1 - algae) + np.array([0.16, 0.22, 0.07]) * algae
    puddle = np.clip((noise(n, rng, 2.6) - 0.68) * 6, 0, 1)[..., None]
    return col * (1 - puddle * 0.5)


def path(n, rng):
    base = 0.6 * noise(n, rng, 1.8) + 0.4 * noise(n, rng, 0.7)
    col = colorize(base, [(0, (0.17, 0.12, 0.08)), (0.5, (0.30, 0.22, 0.14)), (1, (0.42, 0.33, 0.22))])
    pebbles = (noise(n, rng, 0.4) > 0.8)[..., None]
    return col * (1 - pebbles * 0.6) + np.array([0.45, 0.42, 0.38]) * pebbles * 0.6


def barrow(n, rng):
    base = noise(n, rng, 1.9)
    col = colorize(base, [(0, (0.15, 0.14, 0.12)), (0.5, (0.26, 0.25, 0.21)), (1, (0.36, 0.34, 0.28))])
    b = blades(n, rng, 0.04)[..., None]
    bc = colorize(noise(n, rng, 1.6), [(0, (0.42, 0.40, 0.30)), (1, (0.60, 0.55, 0.40))])
    return col * (1 - b * 0.6) + bc * b * 0.6


def stone(n, rng):
    t = 0.5 * noise(n, rng, 2.0) + 0.5 * noise(n, rng, 0.9)
    col = colorize(t, [(0, (0.20, 0.20, 0.21)), (1, (0.42, 0.40, 0.38))])
    yy, xx = np.mgrid[0:n, 0:n]
    tile = n // 4
    off = ((yy // tile) % 2) * (tile // 2)
    grout = (((xx + off) % tile) < 3) | ((yy % tile) < 3)
    return col * (1 - grout[..., None] * 0.6)


def water_normal(n, rng):
    h = 0.6 * noise(n, rng, 2.2) + 0.4 * noise(n, rng, 1.5)
    gy, gx = np.gradient(h * 6.0)
    nz = np.ones_like(h)
    v = np.stack([-gx, -gy, nz], -1)
    v /= np.linalg.norm(v, axis=-1, keepdims=True)
    return v * 0.5 + 0.5


if __name__ == "__main__":
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    rng = np.random.default_rng(1127)
    for name, fn in [("grass", grass), ("litter", litter), ("mud", mud), ("path", path), ("barrow", barrow), ("stone", stone), ("water_n", water_normal)]:
        save(fn(512, rng), f"{out}/{name}.png")
        print("wrote", name)
