"""Step 3: manual exposure (auto exposure misreads the ortho view), calmer fog, then re-capture.
Run: py "C:/Users/jason/Documents/HollowcrownUE/ClaudeScripts/s03_exposure.py"
"""
import os
import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
BIAS = float(os.environ.get("HC_EXPOSURE_BIAS", "0"))
actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()
out = []
cap = None
for a in actors.get_all_level_actors():
    if isinstance(a, unreal.PostProcessVolume):
        s = a.settings
        s.set_editor_property("override_auto_exposure_method", True)
        s.set_editor_property("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL)
        s.set_editor_property("override_auto_exposure_apply_physical_camera_exposure", True)
        s.set_editor_property("auto_exposure_apply_physical_camera_exposure", False)
        s.set_editor_property("override_auto_exposure_bias", True)
        s.set_editor_property("auto_exposure_bias", BIAS)
        a.settings = s
        out.append("post process: manual exposure, bias %.1f" % BIAS)
    elif isinstance(a, unreal.ExponentialHeightFog):
        a.component.set_fog_density(0.002)
        a.component.set_editor_property("start_distance", 5500.0)
        out.append("fog thinned")
    elif isinstance(a, unreal.SceneCapture2D):
        cap = a

# capture settings follow the level's post process; give the renderer a moment by capturing twice
if cap:
    cc = cap.capture_component2d
    rt = unreal.RenderingLibrary.create_render_target2d(world, 1920, 1080, unreal.TextureRenderTargetFormat.RTF_RGBA8)
    cc.set_editor_property("texture_target", rt)
    cc.capture_scene()
    cc.capture_scene()
    unreal.RenderingLibrary.export_render_target(world, rt, HERE, "capture_ue.png")
    out.append("captured")
unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).save_current_level()
with open(os.path.join(HERE, "s03_report.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(out))
