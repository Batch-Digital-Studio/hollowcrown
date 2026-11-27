"""Whisperwood playtest, step 1/3: import the shared assets (the same .glb files Godot uses).
Run: py "C:/Users/jason/Documents/HollowcrownUE/ClaudeScripts/s10_import.py"
Imports  ClaudeScripts/whisperwood/*.glb -> /Game/Whisperwood/<name>/
         ClaudeScripts/chars/*.glb       -> /Game/Chars/<name>/  (skeletal + animations)
and creates the effect materials. Report: ClaudeScripts/s10_report.txt
"""
import glob
import os
import traceback

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
rep = []
tools = unreal.AssetToolsHelpers.get_asset_tools()
eal = unreal.EditorAssetLibrary


def log(s):
    rep.append(str(s))


def import_glb(path, dest):
    t = unreal.AssetImportTask()
    t.filename = path
    t.destination_path = dest
    t.automated = True
    t.replace_existing = True
    t.save = True
    tools.import_asset_tasks([t])
    return list(t.imported_object_paths)


try:
    for f in sorted(glob.glob(os.path.join(HERE, "whisperwood", "*.glb"))):
        name = os.path.splitext(os.path.basename(f))[0]
        if eal.does_directory_exist("/Game/Whisperwood/" + name) and name not in ("deer", "crow"):
            log("skip (already imported) " + name)
            continue
        paths = import_glb(f, "/Game/Whisperwood/" + name)
        log("%s: %d assets" % (name, len(paths)))
    for f in sorted(glob.glob(os.path.join(HERE, "chars", "*.glb"))):
        name = os.path.splitext(os.path.basename(f))[0]
        paths = import_glb(f, "/Game/Chars/" + name)
        log("%s: %s" % (name, [p for p in paths if "Anim" in p or "Skeletal" in p]))

    # effect materials: additive unlit glow with a Color parameter, and a dark translucent scorch
    mel = unreal.MaterialEditingLibrary
    def make_mat(name, blend, shading, color_param=True, opacity=None):
        path = "/Game/Hollowcrown/FX/" + name
        if eal.does_asset_exist(path):
            return unreal.load_asset(path)
        m = tools.create_asset(name, "/Game/Hollowcrown/FX", unreal.Material, unreal.MaterialFactoryNew())
        m.set_editor_property("blend_mode", blend)
        m.set_editor_property("shading_model", shading)
        vp = mel.create_material_expression(m, unreal.MaterialExpressionVectorParameter, -400, 0)
        vp.set_editor_property("parameter_name", "Color")
        vp.set_editor_property("default_value", unreal.LinearColor(1, 0.5, 0.15, 1))
        mel.connect_material_property(vp, "", unreal.MaterialProperty.MP_EMISSIVE_COLOR)
        if opacity is not None:
            sp = mel.create_material_expression(m, unreal.MaterialExpressionScalarParameter, -400, 200)
            sp.set_editor_property("parameter_name", "Opacity")
            sp.set_editor_property("default_value", opacity)
            mel.connect_material_property(sp, "", unreal.MaterialProperty.MP_OPACITY)
        mel.recompile_material(m)
        eal.save_asset(path)
        return m

    glow = make_mat("M_HC_Glow", unreal.BlendMode.BLEND_ADDITIVE, unreal.MaterialShadingModel.MSM_UNLIT)
    dark = make_mat("M_HC_Scorch", unreal.BlendMode.BLEND_TRANSLUCENT, unreal.MaterialShadingModel.MSM_UNLIT, opacity=0.7)

    def make_mi(name, parent, color):
        path = "/Game/Hollowcrown/FX/" + name
        if eal.does_asset_exist(path):
            return
        mi = tools.create_asset(name, "/Game/Hollowcrown/FX", unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())
        mel.set_material_instance_parent(mi, parent)
        mel.set_material_instance_vector_parameter_value(mi, "Color", color)
        eal.save_asset(path)

    make_mi("MI_EmberCore", glow, unreal.LinearColor(18.0, 9.0, 3.0, 1))
    make_mi("MI_EmberGlow", glow, unreal.LinearColor(6.0, 1.8, 0.3, 1))
    make_mi("MI_Spark", glow, unreal.LinearColor(10.0, 4.0, 0.8, 1))
    make_mi("MI_Scorch", dark, unreal.LinearColor(0.02, 0.01, 0.0, 1))
    log("materials ok")
except Exception:
    log(traceback.format_exc())

with open(os.path.join(HERE, "s10_report.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(rep))
print("s10 done")
