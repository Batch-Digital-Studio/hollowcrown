# Hollowcrown: notes for Claude sessions

Jason's long-term co-op ARPG project ("a marathon, not a sprint"). He wants PoE-style build depth,
to eventually play co-op with friends, and owns everything (no expansion fees).

## Start of every session
1. Read `docs/DESIGN.md` and `docs/ROADMAP.md`.
2. Run the tests (see README). Keep them passing.
3. At the end: update ROADMAP.md checkboxes and add a dated line to `docs/CHANGELOG.md`.

## Rules
- Engine: Godot **4.7.2**, GL Compatibility renderer. Jason runs it on Windows (NVIDIA).
- Keep simulation (stats, damage, AI, loot rolls) separate from presentation (FX autoload) so
  co-op (host-authoritative) can be added without a rewrite. Players read intents from `PlayerInput`.
- All randomness for gameplay uses `Game.rng` or a passed RNG, never global `randf()` (FX may use randf).
- Content is data: `scripts/data/*.gd`. Prefer adding data over adding code paths.
- Don't touch Maelana's repos (maelana-nightingale-site, mae-bots). This repo is separate.
- Jason values accuracy: flag anything unverified, and don't claim something works without running it.
- Godot binary in the cloud workspace: download `Godot_v4.7.2-stable_linux.x86_64.zip` from the godotengine/godot
  GitHub releases. Screenshots: `xvfb-run ... --rendering-driver opengl3 -- --autoplay --shots=DIR --shot-times=...`
