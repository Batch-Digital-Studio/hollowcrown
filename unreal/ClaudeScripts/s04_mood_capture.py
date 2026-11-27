"""Step 4: dusk mood for the dying forest, look through IsoCamera, capture capture_ue.png.
Run: py "C:/Users/jason/Documents/HollowcrownUE/ClaudeScripts/s04_mood_capture.py"
"""
import os
import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
cam = cap = None
for a in actors.get_all_level_actors():
    if isinstance(a, unreal.DirectionalLight):
        a.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
        a.set_actor_rotation(unreal.Rotator(roll=0, pitch=-25, yaw=30), False)
        a.light_component.set_intensity(8.0)
        a.light_component.set_light_color(unreal.LinearColor(1.0, 0.72, 0.5))
    elif isinstance(a, unreal.SkyLight):
        a.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
        a.light_component.recapture_sky()
    elif isinstance(a, unreal.ExponentialHeightFog):
        a.component.set_fog_density(0.006)
        a.component.set_editor_property("start_distance", 5000.0)
    elif a.get_actor_label() == "IsoCamera":
        cam = a
    elif isinstance(a, unreal.SceneCapture2D):
        cap = a
unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).pilot_level_actor(cam)
cc = cap.capture_component2d
rt = unreal.RenderingLibrary.create_render_target2d(world, 1920, 1080, unreal.TextureRenderTargetFormat.RTF_RGBA8)
cc.set_editor_property("texture_target", rt)
cc.capture_scene()
unreal.RenderingLibrary.export_render_target(world, rt, HERE, "capture_ue.png")
unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).save_current_level()
print("s04 done")
