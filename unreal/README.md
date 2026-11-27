# Unreal side-by-side (test only)

Jason's decision (2026-11-27): a small Unreal Engine test next to the Godot game before any migration.
Project on his PC: `C:\Users\jason\Documents\HollowcrownUE` (UE 5.8.4, Blank, Blueprint, Lumen, Desktop/Maximum).

Scripts in `ClaudeScripts/` run from the Unreal console (Output Log > Cmd), one at a time, visibly:
`py "C:/Users/jason/Documents/HollowcrownUE/ClaudeScripts/<script>.py"`

- `s01_test_scene.py`: level /Game/Hollowcrown/Maps/SideBySide, ground, sun/sky/fog, imports the .glb files next to it, iso camera (45 deg yaw, 52 deg elevation, ortho, 17 m view height like Godot)
- `s02_capture.py`, `s03_exposure.py`: scene-capture experiments (scene captures render Lumen dark; use the viewport instead)
- `s04_mood_capture.py`: dusk light, pilots the viewport through IsoCamera

Lessons: `unreal.Rotator` positional order is (roll, pitch, yaw), so use keywords; spawned lights must be Movable
(the project has static lighting off); the KayKit Mage .glb imports as separate parts (needs a combine-meshes option).
