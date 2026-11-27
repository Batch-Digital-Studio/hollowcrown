"""Hollowcrown procedural textures (original): tileable bark, forest floor, rock, moss.

    python tools/blender/textures.py OUTDIR [--seed N]

Each texture is filtered random noise (FFT, so it tiles seamlessly), shaped and coloured with numpy.
"""
import sys

import numpy as np
from PIL import Image


def noise(n, rng, falloff, aniso=(1.0, 1.0)):
    """Tileable fractal noise in [0,1]. falloff ~ 1.5-3 (higher = smoother)."""
    f = np.fft.fftfreq(n)
    fx, fy = np.meshgrid(f * aniso[0], f * aniso[1])
    r = np.sqrt(fx * fx + fy * fy)
    r[0, 0] = 1.0
    spec = (rng.normal(size=(n, n)) + 1j * rng.normal(size=(n, n))) / (r ** falloff)
    spec[0, 0] = 0
    img = np.real(np.fft.ifft2(spec))
    img -= img.min()
    return img / img.max()


def colorize(t, stops):
    """t in [0,1] -> RGB using [(pos, (r,g,b)), ...]."""
    out = np.zeros(t.shape + (3,))
    pos = [p for p, _ in stops]
    for c in range(3):
        out[..., c] = np.interp(t, pos, [col[c] for _, col in stops])
    return out


def save(arr, path):
    Image.fromarray(np.clip(arr * 255, 0, 255).astype(np.uint8)).save(path)


def bark(n, rng):
    long_ = noise(n, rng, 1.6, aniso=(0.25, 5.0))       # vertical fibres
    knots = noise(n, rng, 2.6)
    fine = noise(n, rng, 1.0, aniso=(0.5, 3.0))
    t = 0.6 * long_ + 0.2 * knots + 0.2 * fine
    t = np.clip((t - 0.25) / 0.6, 0, 1)
    grooves = (long_ < 0.32) * 0.35
    col = colorize(t, [(0, (0.10, 0.07, 0.05)), (0.5, (0.24, 0.17, 0.12)), (1, (0.40, 0.31, 0.22))])
    return col * (1 - grooves[..., None])


def ground(n, rng):
    base = 0.65 * noise(n, rng, 2.0) + 0.35 * noise(n, rng, 0.9)
    moss = noise(n, rng, 2.8)
    litter = noise(n, rng, 1.1)
    col = colorize(base, [(0, (0.10, 0.08, 0.06)), (0.6, (0.20, 0.15, 0.10)), (1, (0.28, 0.22, 0.15))])
    m = np.clip((moss - 0.5) * 3.0, 0, 1)[..., None]
    col = col * (1 - m) + colorize(moss, [(0, (0.12, 0.17, 0.07)), (1, (0.24, 0.30, 0.10))]) * m
    leaves = (litter > 0.82)[..., None]
    leaf_col = colorize(noise(n, rng, 1.5), [(0, (0.42, 0.18, 0.06)), (0.5, (0.55, 0.32, 0.10)), (1, (0.35, 0.28, 0.10))])
    return col * (1 - leaves * 0.8) + leaf_col * leaves * 0.8


def rock(n, rng):
    t = 0.5 * noise(n, rng, 2.2) + 0.3 * noise(n, rng, 1.3) + 0.2 * noise(n, rng, 0.8)
    col = colorize(t, [(0, (0.18, 0.18, 0.19)), (0.5, (0.33, 0.32, 0.31)), (1, (0.52, 0.50, 0.47))])
    lichen = np.clip((noise(n, rng, 2.5) - 0.62) * 4, 0, 1)[..., None]
    return col * (1 - lichen) + np.array([0.36, 0.40, 0.18]) * lichen


def moss(n, rng):
    t = 0.6 * noise(n, rng, 1.8) + 0.4 * noise(n, rng, 0.9)
    return colorize(t, [(0, (0.08, 0.13, 0.05)), (0.5, (0.17, 0.25, 0.08)), (1, (0.30, 0.36, 0.12))])


if __name__ == "__main__":
    out = sys.argv[1]
    seed = int(sys.argv[sys.argv.index("--seed") + 1]) if "--seed" in sys.argv else 7
    rng = np.random.default_rng(seed)
    for name, fn in [("bark", bark), ("ground", ground), ("rock", rock), ("moss", moss)]:
        save(fn(512, rng), f"{out}/tex_{name}.png")
        print("wrote", name)
