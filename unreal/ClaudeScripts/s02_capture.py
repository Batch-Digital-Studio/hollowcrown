"""Step 2: remove the split Mage parts, look through IsoCamera, and capture an orthographic image.

Run: py "C:/Users/jason/Documents/HollowcrownUE/ClaudeScripts/s02_capture.py"
Output: ClaudeScripts/capture_ue.png and s02_report.txt
"""
import os
import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
out = []
actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world()

cam = None
for a in actors.get_all_level_actors():
    label = a.get_actor_label()
    if label.startswith("Mage") or label.startswith("SceneCapture"):
        actors.destroy_actor(a)
    elif label == "IsoCamera":
        cam = a
out.append("camera found: %s" % (cam is not None))

# look through the camera in the editor viewport
unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).pilot_level_actor(cam)

# orthographic scene capture from the same transform
cap = actors.spawn_actor_from_class(unreal.SceneCapture2D, cam.get_actor_location(), cam.get_actor_rotation())
cap.set_actor_label("SceneCaptureIso")
cc = cap.capture_component2d
cc.set_editor_property("projection_type", unreal.CameraProjectionMode.ORTHOGRAPHIC)
cc.set_editor_property("ortho_width", 1700.0 * 16.0 / 9.0)
cc.set_editor_property("capture_source", unreal.SceneCaptureSource.SCS_FINAL_COLOR_LDR)
cc.set_editor_property("capture_every_frame", False)
rt = unreal.RenderingLibrary.create_render_target2d(world, 1920, 1080, unreal.TextureRenderTargetFormat.RTF_RGBA8)
cc.set_editor_property("texture_target", rt)
cc.capture_scene()
unreal.RenderingLibrary.export_render_target(world, rt, HERE, "capture_ue.png")
out.append("exported capture_ue.png")
with open(os.path.join(HERE, "s02_report.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(out))
