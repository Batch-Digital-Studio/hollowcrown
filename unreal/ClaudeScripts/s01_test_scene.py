"""Hollowcrown Unreal side-by-side, step 1: a test level matching the Godot view.

Run from the Unreal console (Output Log > Cmd):  py "C:/Users/jason/Documents/HollowcrownUE/ClaudeScripts/s01_test_scene.py"

- New level /Game/Hollowcrown/Maps/SideBySide
- Imports the .glb files next to this script (same files the Godot side uses)
- Ground, sun, sky light, height fog; Lumen is already the project default
- Orthographic camera matching Godot: 45 deg yaw, 52 deg elevation, 17 m view height
- Saves a 1920x1080 screenshot to Saved/Screenshots/WindowsEditor/side_by_side_ue.png
Writes a report to ClaudeScripts/s01_report.txt.
"""
import glob
import math
import os

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
report = []


def log(s):
    report.append(str(s))
    unreal.log("[Hollowcrown] " + str(s))


def import_glb(path, dest):
    task = unreal.AssetImportTask()
    task.filename = path
    task.destination_path = dest
    task.automated = True
    task.replace_existing = True
    task.save = True
    unreal.AssetToolsHelpers.get_asset_tools().import_asset_tasks([task])
    paths = list(task.imported_object_paths)
    log("imported %s -> %s" % (os.path.basename(path), paths))
    return paths


actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
levels = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
MAP = "/Game/Hollowcrown/Maps/SideBySide"
if unreal.EditorAssetLibrary.does_asset_exist(MAP):
    levels.load_level(MAP)
    for a in actors.get_all_level_actors():
        actors.destroy_actor(a)
else:
    levels.new_level(MAP)
log("level " + MAP)

# ground: engine plane, 60 m square, dark earth
plane = unreal.load_asset("/Engine/BasicShapes/Plane")
g = actors.spawn_actor_from_object(plane, unreal.Vector(0, 0, 0))
g.set_actor_scale3d(unreal.Vector(60, 60, 1))
g.set_actor_label("Ground")

# lighting: low cool sun + sky light + fog (dying forest dusk)
# note: unreal.Rotator positional order is (roll, pitch, yaw); use keywords
sun = actors.spawn_actor_from_class(unreal.DirectionalLight, unreal.Vector(0, 0, 500), unreal.Rotator(roll=0, pitch=-25, yaw=30))
sun.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)   # the project has static lighting off
sun.light_component.set_intensity(8.0)
sun.light_component.set_light_color(unreal.LinearColor(0.75, 0.8, 1.0))
sun.light_component.set_atmosphere_sun_light(True)
actors.spawn_actor_from_class(unreal.SkyAtmosphere, unreal.Vector(0, 0, 0))
sky = actors.spawn_actor_from_class(unreal.SkyLight, unreal.Vector(0, 0, 300))
sky.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
sky.light_component.set_real_time_capture(True)
fog = actors.spawn_actor_from_class(unreal.ExponentialHeightFog, unreal.Vector(0, 0, 0))
fog.component.set_fog_density(0.006)
fog.component.set_editor_property("start_distance", 5000.0)
actors.spawn_actor_from_class(unreal.PostProcessVolume, unreal.Vector(0, 0, 0)).set_editor_property("unbound", True)

# assets: every .glb next to this script, in a row
x = -600.0
for f in sorted(glob.glob(os.path.join(HERE, "*.glb"))):
    for p in import_glb(f, "/Game/Hollowcrown/Imported"):
        asset = unreal.load_asset(p)
        if isinstance(asset, (unreal.StaticMesh, unreal.SkeletalMesh)):
            a = actors.spawn_actor_from_object(asset, unreal.Vector(x, 0, 0))
            a.set_actor_scale3d(unreal.Vector(100, 100, 100) if a.get_actor_bounds(False)[1].z < 20 else unreal.Vector(1, 1, 1))
            log("placed %s at x=%d, bounds %s" % (p, x, a.get_actor_bounds(False)[1]))
            x += 400.0
            break

# camera matching Godot (Godot y-up -> Unreal z-up; 1 Godot unit = 1 m = 100 cm)
yaw, pitch = math.radians(45), math.radians(52)
d = unreal.Vector(math.sin(yaw) * math.cos(pitch), math.cos(yaw) * math.cos(pitch), math.sin(pitch))
target = unreal.Vector(0, 0, 0)
cam = actors.spawn_actor_from_class(unreal.CameraActor, target + d * 6000.0)
cam.set_actor_rotation(unreal.MathLibrary.find_look_at_rotation(cam.get_actor_location(), target), False)
cc = cam.camera_component
cc.set_projection_mode(unreal.CameraProjectionMode.ORTHOGRAPHIC)
cc.set_ortho_width(1700.0 * 16.0 / 9.0)
cc.set_editor_property("aspect_ratio", 16.0 / 9.0)
cam.set_actor_label("IsoCamera")
log("camera at %s rot %s" % (cam.get_actor_location(), cam.get_actor_rotation()))

levels.save_current_level()
unreal.AutomationLibrary.take_high_res_screenshot(1920, 1080, "side_by_side_ue.png", cam)
log("screenshot requested")
with open(os.path.join(HERE, "s01_report.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(report))
