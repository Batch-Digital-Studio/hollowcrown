"""Whisperwood playtest, step 2/3: build the level from the shared layout (slice_layout.json).
Run: py "C:/Users/jason/Documents/HollowcrownUE/ClaudeScripts/s11_build_level.py"
Level /Game/Hollowcrown/Maps/WhisperwoodClearing. Layout metres (x, z) -> Unreal (x*100, z*100) cm.
Everything the game director moves at play time is placed here up front and found by tag
(Python cannot spawn into the play world reliably, so pools are used).
"""
import json
import math
import os
import traceback

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
L = json.load(open(os.path.join(HERE, "slice_layout.json"), encoding="utf-8"))
rep = []
actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
levels = unreal.get_editor_subsystem(unreal.LevelEditorSubsystem)
eal = unreal.EditorAssetLibrary
MAP = "/Game/Hollowcrown/Maps/WhisperwoodClearing"
HIDE_Z = -5000.0


def log(s):
    rep.append(str(s))


def first_of(folder, cls):
    for p in eal.list_assets(folder, recursive=True, include_folder=False):
        a = unreal.load_asset(p)
        if isinstance(a, cls):
            return a
    return None


def tag(a, *tags):
    a.tags = [unreal.Name(t) for t in tags]


def pos(x, z, h=0.0):
    return unreal.Vector(x * 100.0, z * 100.0, h * 100.0)


def movable_light(cls, loc, color, intensity, radius):
    l = actors.spawn_actor_from_class(cls, loc)
    l.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
    lc = l.get_component_by_class(unreal.PointLightComponent)
    lc.set_light_color(unreal.LinearColor(*color, 1.0))
    lc.set_intensity(intensity)
    lc.set_attenuation_radius(radius)
    lc.set_cast_shadows(False)
    return l


try:
    if eal.does_asset_exist(MAP):
        levels.load_level(MAP)
        for a in actors.get_all_level_actors():
            actors.destroy_actor(a)
    else:
        levels.new_level(MAP)

    meshes = {}
    def mesh(kind):
        if kind not in meshes:
            meshes[kind] = first_of("/Game/Whisperwood/" + kind, unreal.StaticMesh)
        return meshes[kind]

    g = actors.spawn_actor_from_object(mesh("ground"), pos(0, 0))
    g.set_actor_label("Ground")
    n = 0
    for p in L["props"]:
        m = mesh(p["kind"])
        if m is None:
            log("missing mesh " + p["kind"])
            continue
        a = actors.spawn_actor_from_object(m, pos(p["x"], p["z"]))
        a.set_actor_rotation(unreal.Rotator(roll=0, pitch=0, yaw=-p["rot"]), False)
        a.set_actor_scale3d(unreal.Vector(p["scale"], p["scale"], p["scale"]))
        a.set_folder_path("Props")
        n += 1
    log("props placed: %d" % n)

    # light and mood (same numbers as the Godot slice)
    md = L["mood"]
    sun = actors.spawn_actor_from_class(unreal.DirectionalLight, unreal.Vector(0, 0, 800))
    sun.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
    sun.set_actor_rotation(unreal.Rotator(roll=0, pitch=-md["sun_pitch_deg"], yaw=-md["sun_yaw_deg"]), False)
    sun.light_component.set_intensity(6.0)
    sun.light_component.set_light_color(unreal.LinearColor(*md["sun_color"], 1.0))
    sun.light_component.set_atmosphere_sun_light(True)
    actors.spawn_actor_from_class(unreal.SkyAtmosphere, unreal.Vector(0, 0, 0))
    sky = actors.spawn_actor_from_class(unreal.SkyLight, unreal.Vector(0, 0, 500))
    sky.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
    sky.light_component.set_real_time_capture(True)
    sky.light_component.set_intensity(0.8)
    fog = actors.spawn_actor_from_class(unreal.ExponentialHeightFog, unreal.Vector(0, 0, 0))
    fc = md["fog_color"]
    fog.component.set_fog_density(0.02)
    fog.component.set_editor_property("start_distance", 5200.0)
    fog.component.set_fog_inscattering_color(unreal.LinearColor(fc[0], fc[1], fc[2], 1))
    ppv = actors.spawn_actor_from_class(unreal.PostProcessVolume, unreal.Vector(0, 0, 0))
    ppv.set_editor_property("unbound", True)
    s = ppv.settings
    s.set_editor_property("override_auto_exposure_method", True)
    s.set_editor_property("auto_exposure_method", unreal.AutoExposureMethod.AEM_MANUAL)
    s.set_editor_property("override_auto_exposure_apply_physical_camera_exposure", True)
    s.set_editor_property("auto_exposure_apply_physical_camera_exposure", False)
    s.set_editor_property("override_auto_exposure_bias", True)
    s.set_editor_property("auto_exposure_bias", 0.5)
    s.set_editor_property("override_bloom_intensity", True)
    s.set_editor_property("bloom_intensity", 0.8)
    s.set_editor_property("override_vignette_intensity", True)
    s.set_editor_property("vignette_intensity", 0.5)
    ppv.settings = s
    for e in L["ember_lights"]:
        movable_light(unreal.PointLight, pos(e[0], e[1], 0.6), (1.0, 0.5, 0.18), 250.0, 450.0).set_folder_path("Lights")
    lm = L["landmark"]
    movable_light(unreal.PointLight, pos(lm["x"], lm["z"], 1.2), tuple(lm["light"]), 900.0, 1100.0).set_folder_path("Lights")

    # characters and wildlife (found by tag at play time)
    hero_mesh = first_of("/Game/Chars/hero_mage", unreal.SkeletalMesh)
    skel_mesh = first_of("/Game/Chars/skel_minion", unreal.SkeletalMesh)
    deer_mesh = first_of("/Game/Whisperwood/deer", unreal.SkeletalMesh)
    crow_mesh = first_of("/Game/Whisperwood/crow", unreal.SkeletalMesh)
    st = L["player_start"]
    h = actors.spawn_actor_from_object(hero_mesh, pos(st[0], st[1]))
    tag(h, "hc_hero")
    h.set_actor_label("Hero")
    i = 0
    for pk in L["packs"]:
        for k in range(pk["n"]):
            a = math.tau * k / pk["n"]
            sk = actors.spawn_actor_from_object(skel_mesh, pos(pk["x"] + math.cos(a) * 2.2, pk["z"] + math.sin(a) * 2.2))
            tag(sk, "hc_skel", "pack%d" % i)
            sk.set_actor_label("Skeleton_%d_%d" % (i, k))
            sk.set_folder_path("Enemies")
        i += 1
    for d in L["animals"]["deer"]:
        a = actors.spawn_actor_from_object(deer_mesh, pos(d[0], d[1]))
        a.set_actor_rotation(unreal.Rotator(roll=0, pitch=0, yaw=-d[2]), False)
        tag(a, "hc_deer")
        a.set_folder_path("Wildlife")
    for c in L["animals"]["crow"]:
        a = actors.spawn_actor_from_object(crow_mesh, pos(c[0], c[1]))
        a.set_actor_rotation(unreal.Rotator(roll=0, pitch=0, yaw=-c[2]), False)
        tag(a, "hc_crow")
        a.set_folder_path("Wildlife")
    log("characters: hero=%s skel=%s deer=%s crow=%s" % (hero_mesh, skel_mesh, deer_mesh, crow_mesh))

    # effect pools (parked far below the ground)
    sphere = unreal.load_asset("/Engine/BasicShapes/Sphere")
    plane = unreal.load_asset("/Engine/BasicShapes/Plane")
    core_mi = unreal.load_asset("/Game/Hollowcrown/FX/MI_EmberCore")
    glow_mi = unreal.load_asset("/Game/Hollowcrown/FX/MI_EmberGlow")
    spark_mi = unreal.load_asset("/Game/Hollowcrown/FX/MI_Spark")
    scorch_mi = unreal.load_asset("/Game/Hollowcrown/FX/MI_Scorch")

    def pool(mesh_asset, mat, count, tagname, scale):
        for k in range(count):
            a = actors.spawn_actor_from_object(mesh_asset, unreal.Vector(0, 0, HIDE_Z))
            a.static_mesh_component.set_material(0, mat)
            a.static_mesh_component.set_cast_shadow(False)
            a.static_mesh_component.set_collision_enabled(unreal.CollisionEnabled.NO_COLLISION)
            a.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
            a.set_actor_scale3d(unreal.Vector(scale, scale, scale))
            tag(a, tagname)
            a.set_folder_path("FX")

    pool(sphere, core_mi, 10, "hc_bolt", 0.22)
    pool(sphere, glow_mi, 10, "hc_bolthalo", 0.55)
    pool(sphere, spark_mi, 90, "hc_ember", 0.06)
    pool(sphere, glow_mi, 3, "hc_flare", 0.3)
    pool(plane, scorch_mi, 6, "hc_scorch", 1.6)
    for k in range(10):
        l = movable_light(unreal.PointLight, unreal.Vector(0, 0, HIDE_Z), (1.0, 0.55, 0.2), 0.0, 500.0)
        tag(l, "hc_boltlight")
        l.set_folder_path("FX")
    for k in range(16):
        t = actors.spawn_actor_from_class(unreal.TextRenderActor, unreal.Vector(0, 0, HIDE_Z))
        tc = t.text_render
        tc.set_editor_property("horizontal_alignment", unreal.HorizTextAligment.EHTA_CENTER)
        tc.set_world_size(60.0)
        tc.set_text_render_color(unreal.Color(255, 190, 90, 255))
        t.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
        tag(t, "hc_text")
        t.set_folder_path("FX")

    # camera: same isometric view as Godot (45 deg yaw, 52 deg elevation, orthographic, 17 m tall view)
    cam = actors.spawn_actor_from_class(unreal.CameraActor, pos(st[0], st[1]) + unreal.Vector(4000, 4000, 7000))
    cc = cam.camera_component
    cc.set_projection_mode(unreal.CameraProjectionMode.ORTHOGRAPHIC)
    # Unreal keeps the vertical extent by default (Maintain Y-FOV), like Godot's KEEP_HEIGHT: 17 m tall view
    cc.set_ortho_width(1700.0)
    cc.set_editor_property("constrain_aspect_ratio", False)
    cam.set_actor_rotation(unreal.Rotator(roll=0, pitch=-52, yaw=-135), False)
    cam.root_component.set_mobility(unreal.ComponentMobility.MOVABLE)
    tag(cam, "hc_cam")
    cam.set_actor_label("IsoCamera")
    actors.spawn_actor_from_class(unreal.PlayerStart, pos(st[0], st[1], 1.0))
    levels.save_current_level()
    log("level saved " + MAP)
except Exception:
    log(traceback.format_exc())

with open(os.path.join(HERE, "s11_report.txt"), "w", encoding="utf-8") as fh:
    fh.write("\n".join(rep))
print("s11 done")
