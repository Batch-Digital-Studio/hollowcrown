# Whisperwood Clearing: Godot vs Unreal playtest

The same small forest in both engines, built from the same files:
- **Assets**: original, made by Blender scripts (`tools/blender/whisperwood.py`, `textures.py`): trees, dead tree,
  Hollow Oak landmark with ember crystals, bushes, ferns, grass, flowers, plain and glowing Emberhood mushrooms,
  rocks, mossy log, standing stones, ground, deer (Graze/Run), crow (Idle/Fly).
- **Layout**: `assets/whisperwood/slice_layout.json` from `tools/slice/make_layout.py` (seeded). Every prop,
  collider, skeleton pack and animal is in the same place in both engines.
- **Hero and monsters**: KayKit Mage and Skeleton (placeholders until our own models).
- **Camera**: the same isometric view (45 deg yaw, 52 deg elevation, orthographic, 17 m tall view).
- **Gameplay**: move, aim, Ember Bolt (cast flare, glowing bolt with ember trail and light, impact sparks, flash,
  scorch), 11 skeletons in 3 packs that chase and strike, a new wave 6 s after the clearing is empty,
  deer that bolt and crows that fly off when you come close.

## Play the Godot side
1. Open the project in Godot 4.7.2 and press F5 (first import takes a minute or two: new models).
2. On the title screen choose **Playtest: Whisperwood Clearing**. Your real save is never touched.
3. Controller: left stick move, right stick aim (auto-target when released), **RT** Ember Bolt.
   Mouse/keyboard: WASD, mouse aim, left click.
4. The frame rate and frame time are shown top-left.

## Play the Unreal side
1. Open **HollowcrownUE** (Documents) in Unreal 5.8.4.
2. Open the console: the **Cmd** box at the bottom of the editor (or the ` key) and paste:
   `py "C:/Users/jason/Documents/HollowcrownUE/ClaudeScripts/s12_play.py"`
   It opens the WhisperwoodClearing level and presses Play. Click into the game view once.
3. Same controls as Godot. **Esc** stops. To play again, press the up arrow in the console box, then Enter.
4. Unreal's own `stat fps` and `stat unit` readouts are on (right side).

## What is the same, and what is not (read before judging)
- Same: assets, layout, camera, hero, monsters, spell look and timing, lights per mushroom and at the oak, dusk sun direction.
- **Lighting engines differ on purpose**: Godot Forward+ (SSAO, SSIL, glow, fog) vs Unreal Lumen (dynamic global
  illumination), virtual shadow maps and bloom. That is the comparison.
- **Unreal gameplay runs in Python inside the editor** (this PC can't compile Unreal C++: no Visual Studio).
  It is a stand-in, not how a shipped Unreal game would be built, and Python costs some frame time (the "Game" line
  in `stat unit`). Godot's gameplay is the real game code.
- **Unreal effects are simple shapes + lights**, not Niagara particles. A real Unreal port would use Niagara and
  look better. Godot's effects are the game's own.
- The Unreal editor caps Play at 60 fps; compare the **GPU time** in `stat unit` with Godot's ms, not the fps.
- Gamepad in Unreal reads Unreal's standard Xbox keys (Gamepad_LeftX, RightTrigger...). Mouse/keyboard were tested;
  the controller was **not** tested by me (no pad here).
- Models: the deer and crow are rigid low-poly (no skin deformation); the KayKit hero and skeletons are stand-ins.

## Rebuild after changes
- Assets: `python tools/blender/whisperwood.py --tex assets/whisperwood --out assets/whisperwood` (Blender 5 as a Python module).
- Layout: `python tools/slice/make_layout.py assets/whisperwood/slice_layout.json`, copy it to `HollowcrownUE/ClaudeScripts/`.
- Unreal: in the console run `s10_import.py` (assets) then `s11_build_level.py` (level), then `s12_play.py`.
- Godot check: `godot --headless --path . --fixed-fps 60 -- --slice-probe` (9 checks).
