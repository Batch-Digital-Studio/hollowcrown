"""Whisperwood playtest, step 3/3: press Play and run the game director.
Run: py "C:/Users/jason/Documents/HollowcrownUE/ClaudeScripts/s12_play.py"
(Starts Play-In-Editor; press Esc to stop. Run it again to play again.)

Same rules as the Godot slice, written in Python because this project cannot compile C++:
  Left stick / WASD move (screen-relative)   Right stick / mouse aim (auto-target on pad)
  RT / left mouse cast Ember Bolt            skeleton packs chase and strike, waves return
Unverified on first run: Unreal's Python API is checked as the director starts; problems go to
ClaudeScripts/s12_log.txt.
"""
import json
import math
import os
import random
import time
import traceback

import unreal

HERE = os.path.dirname(os.path.abspath(__file__))
L = json.load(open(os.path.join(HERE, "slice_layout.json"), encoding="utf-8"))
LOG = os.path.join(HERE, "s12_log.txt")
YAW_OFFSET = float(os.environ.get("HC_YAW_OFFSET", "90"))   # glTF +Z forward -> Unreal yaw
CAM_DIR = unreal.Vector(math.cos(math.radians(52)) * math.cos(math.radians(45)),
                        math.cos(math.radians(52)) * math.sin(math.radians(45)), math.sin(math.radians(52)))
RIGHT = unreal.Vector(0.7071, -0.7071, 0)      # screen right on the ground
UP = unreal.Vector(-0.7071, -0.7071, 0)        # screen up on the ground
HIDE = unreal.Vector(0, 0, -5000)
BLOCKERS = [(b[0] * 100.0, b[1] * 100.0, b[2] * 100.0) for b in L["blockers"]]
WALK_R = L["walk_radius_m"] * 100.0


def log(*a):
    with open(LOG, "a", encoding="utf-8") as fh:
        fh.write(" ".join(str(x) for x in a) + "\n")


open(LOG, "w").close()
log("s12 start", time.ctime())


def key(name):
    k = unreal.Key()
    k.set_editor_property("key_name", name)
    return k


KEYS = {n: key(n) for n in ["W", "A", "S", "D", "LeftMouseButton", "Gamepad_RightTrigger", "Gamepad_FaceButton_Bottom",
                             "Gamepad_LeftX", "Gamepad_LeftY", "Gamepad_RightX", "Gamepad_RightY", "Gamepad_RightTriggerAxis"]}


def anims_in(folder):
    out = {}
    for p in unreal.EditorAssetLibrary.list_assets(folder, recursive=True, include_folder=False):
        a = unreal.load_asset(p)
        if isinstance(a, unreal.AnimSequence):
            out[a.get_name()] = a
    return out


def pick(anims, name):
    for k, v in anims.items():
        if k == name or k.endswith("_" + name) or k.endswith(name):
            return v
    return None


ANIM = {"hero": anims_in("/Game/Chars/hero_mage"), "skel": anims_in("/Game/Chars/skel_minion"),
        "deer": anims_in("/Game/Whisperwood/deer"), "crow": anims_in("/Game/Whisperwood/crow")}
log("anims", {k: sorted(v.keys()) for k, v in ANIM.items()})


def push_out(p, r):
    """Keep a ground position out of tree/rock colliders and inside the clearing."""
    for bx, by, br in BLOCKERS:
        dx, dy = p.x - bx, p.y - by
        d = math.hypot(dx, dy)
        m = br + r
        if 0.01 < d < m:
            p.x = bx + dx / d * m
            p.y = by + dy / d * m
    d = math.hypot(p.x, p.y)
    if d > WALK_R:
        p.x *= WALK_R / d
        p.y *= WALK_R / d
    return p


class Unit:
    def __init__(self, actor, kind, hp):
        self.a = actor
        self.kind = kind
        self.comp = actor.skeletal_mesh_component
        self.hp = self.max_hp = hp
        self.home = actor.get_actor_location()
        self.cur = ""
        self.lock = 0.0
        self.cool = 0.0
        self.dead = False
        self.dead_t = 0.0
        self.aggro = False
        self.yaw = 0.0
        self.pending_hit = -1.0

    def play(self, name, loop=True, rate=1.0, force=False):
        if self.cur == name and not force:
            return
        a = pick(ANIM[self.kind], name)
        if a is None:
            return
        self.cur = name
        self.comp.play_animation(a, loop)
        self.comp.set_play_rate(rate)

    def face(self, dx, dy, dt, snap=False):
        if abs(dx) + abs(dy) < 1e-3:
            return
        want = math.degrees(math.atan2(dy, dx)) + YAW_OFFSET
        diff = (want - self.yaw + 540.0) % 360.0 - 180.0
        self.yaw += diff if snap else diff * min(1.0, dt * 14.0)
        self.a.set_actor_rotation(unreal.Rotator(roll=0, pitch=0, yaw=self.yaw), False)

    @property
    def loc(self):
        return self.a.get_actor_location()


class Director:
    def __init__(self):
        self.started = False
        self.world = None
        self.handle = None
        self.t = 0.0
        self.kills = 0

    # ------------------------------------------------------------ setup
    def setup(self, world):
        self.world = world
        gs = unreal.GameplayStatics
        tagged = lambda t: list(gs.get_all_actors_with_tag(world, t))
        self.pc = gs.get_player_controller(world, 0)
        pawn = self.pc.get_controlled_pawn()
        if pawn:   # the default fly-camera pawn would also react to WASD: remove it
            pawn.disable_input(self.pc)
            for fn in ("destroy_actor", "k2_destroy_actor"):
                if hasattr(pawn, fn):
                    getattr(pawn, fn)()
                    break
        self.pc.set_editor_property("show_mouse_cursor", True)
        self.cam = tagged("hc_cam")[0]
        self.cam.camera_component.set_ortho_width(1700.0)   # 17 m view height, same as Godot
        self.pc.set_view_target_with_blend(self.cam, 0.0)
        self.hero = Unit(tagged("hc_hero")[0], "hero", 104.0)
        self.start = self.hero.loc
        self.skels = [Unit(a, "skel", 32.0) for a in tagged("hc_skel")]
        for s in self.skels:
            s.play("Idle_Combat")
        self.deer = [Unit(a, "deer", 1) for a in tagged("hc_deer")]
        self.crows = [Unit(a, "crow", 1) for a in tagged("hc_crow")]
        for d in self.deer:
            d.play("Graze")
            d.state, d.vel, d.timer = "idle", unreal.Vector(0, 0, 0), 0.0
            d.yaw = d.a.get_actor_rotation().yaw
        for c in self.crows:
            c.play("Idle")
            c.state, c.vel, c.timer = "idle", unreal.Vector(0, 0, 0), 0.0
            c.yaw = c.a.get_actor_rotation().yaw
        self.bolts = [{"a": a, "on": False} for a in tagged("hc_bolt")]
        halos = tagged("hc_bolthalo")
        lights = tagged("hc_boltlight")
        for i, b in enumerate(self.bolts):
            b["halo"] = halos[i]
            b["light"] = lights[i]
        self.embers = [{"a": a, "life": 0.0, "v": unreal.Vector(0, 0, 0), "g": 0.0} for a in tagged("hc_ember")]
        self.flares = [{"a": a, "life": 0.0} for a in tagged("hc_flare")]
        self.scorch = [{"a": a, "life": 0.0} for a in tagged("hc_scorch")]
        self.texts = [{"a": a, "life": 0.0, "v": 0.0} for a in tagged("hc_text")]
        self.flashes = []
        self.hero.play("Idle")
        self.respawn_t = -1.0
        self.wave_t = -1.0
        unreal.SystemLibrary.execute_console_command(world, "stat fps")
        unreal.SystemLibrary.execute_console_command(world, "stat unit")
        log("setup ok: skels", len(self.skels), "bolts", len(self.bolts), "embers", len(self.embers), "deer", len(self.deer), "crows", len(self.crows))

    # ------------------------------------------------------------ input
    def down(self, n):
        return self.pc.is_input_key_down(KEYS[n])

    def axis(self, n):
        return self.pc.get_input_analog_key_state(KEYS[n])

    def mouse_ground(self):
        r = self.pc.deproject_mouse_position_to_world()
        if isinstance(r, tuple) and len(r) >= 2:
            loc, d = r[-2], r[-1]
            if hasattr(loc, "z") and abs(d.z) > 1e-3:
                t = -loc.z / d.z
                return unreal.Vector(loc.x + d.x * t, loc.y + d.y * t, 0)
        return None

    # ------------------------------------------------------------ effects
    def ember(self, p, v, life, grav=-200.0):
        for e in self.embers:
            if e["life"] <= 0:
                e["life"], e["max"], e["v"], e["g"] = life, life, v, grav
                e["a"].set_actor_location(p, False, True)
                return

    def text(self, p, s):
        for t in self.texts:
            if t["life"] <= 0:
                t["life"] = 0.8
                t["a"].text_render.set_text(str(s))
                t["a"].set_actor_location(p + unreal.Vector(0, 0, 220), False, True)
                t["a"].set_actor_rotation(unreal.Rotator(roll=0, pitch=52, yaw=45), False)
                return

    def impact(self, p):
        for k in range(18):
            a = random.uniform(0, math.tau)
            sp = random.uniform(250, 650)
            self.ember(p, unreal.Vector(math.cos(a) * sp, math.sin(a) * sp, random.uniform(200, 650)), random.uniform(0.35, 0.6), -1400.0)
        for s in self.scorch:
            if s["life"] <= 0:
                s["life"] = 4.5
                s["a"].set_actor_location(unreal.Vector(p.x, p.y, 3), False, True)
                s["a"].set_actor_rotation(unreal.Rotator(roll=0, pitch=0, yaw=random.uniform(0, 360)), False)
                break
        for b in self.bolts:   # borrow an idle bolt light as the flash
            if not b["on"] and b["light"] not in [f[0] for f in self.flashes]:
                b["light"].set_actor_location(p + unreal.Vector(0, 0, 60), False, True)
                self.flashes.append([b["light"], 0.35])
                break

    def cast(self, aim):
        h = self.hero
        d = aim - h.loc
        d.z = 0
        if d.length() < 1:
            return
        d = d.normal()
        h.face(d.x, d.y, 0, snap=True)
        h.play("Spellcast_Shoot", loop=False, rate=1.6, force=True)
        h.lock = 0.42
        h.cool = 0.42
        hand = h.loc + d * 60 + unreal.Vector(0, 0, 120)
        for f in self.flares:
            if f["life"] <= 0:
                f["life"] = 0.22
                f["a"].set_actor_location(hand, False, True)
                break
        for b in self.bolts:
            if not b["on"]:
                b.update({"on": True, "p": hand, "v": d * 2560.0, "trav": 0.0, "age": 0.0})
                b["light"].point_light_component.set_intensity(900.0)
                return

    # ------------------------------------------------------------ tick
    def tick(self, dt):
        dt = min(dt, 0.05)
        self.t += dt
        h = self.hero
        # hero
        if h.dead:
            h.dead_t -= dt
            if h.dead_t <= 0:
                h.dead = False
                h.hp = h.max_hp
                h.a.set_actor_location(self.start, False, True)
                h.play("Idle", force=True)
        else:
            mx = self.axis("Gamepad_LeftX") + (1.0 if self.down("D") else 0) - (1.0 if self.down("A") else 0)
            my = self.axis("Gamepad_LeftY") + (1.0 if self.down("W") else 0) - (1.0 if self.down("S") else 0)
            mv = RIGHT * mx + UP * my
            mlen = min(1.0, mv.length())
            h.cool -= dt
            h.lock -= dt
            if mlen > 0.15 and h.lock <= 0:
                p = push_out(h.loc + mv.normal() * 650.0 * mlen * dt, 35.0)
                h.a.set_actor_location(p, False, True)
                h.face(mv.x, mv.y, dt)
                h.play("Running_A", rate=1.0 * mlen + 0.3)
            elif h.lock <= 0:
                h.play("Idle")
            # aim and cast
            rx, ry = self.axis("Gamepad_RightX"), self.axis("Gamepad_RightY")
            aim = None
            if abs(rx) + abs(ry) > 0.3:
                aim = h.loc + (RIGHT * rx + UP * ry) * 600.0
            pad_cast = self.down("Gamepad_RightTrigger") or self.axis("Gamepad_RightTriggerAxis") > 0.4
            if aim is None and pad_cast:
                best, bd = None, 1300.0
                for s in self.skels:
                    if not s.dead:
                        dd = (s.loc - h.loc).length()
                        if dd < bd:
                            best, bd = s, dd
                aim = best.loc if best else h.loc + unreal.Vector(math.cos(math.radians(h.yaw - YAW_OFFSET)), math.sin(math.radians(h.yaw - YAW_OFFSET)), 0) * 600
            if aim is None and self.down("LeftMouseButton"):
                aim = self.mouse_ground()
            if aim is not None and (pad_cast or self.down("LeftMouseButton")) and h.cool <= 0:
                self.cast(aim)
        # bolts
        for b in self.bolts:
            if not b["on"]:
                continue
            step = b["v"] * dt
            b["p"] = b["p"] + step
            b["trav"] += step.length()
            b["age"] += dt
            grow = min(1.0, 0.3 + b["age"] * 9.0)
            b["a"].set_actor_location(b["p"], False, True)
            b["a"].set_actor_scale3d(unreal.Vector(0.22, 0.22, 0.22) * grow)
            b["halo"].set_actor_location(b["p"], False, True)
            b["halo"].set_actor_scale3d(unreal.Vector(0.55, 0.55, 0.55) * grow * (1.0 + 0.12 * math.sin(b["age"] * 40)))
            b["light"].set_actor_location(b["p"], False, True)
            for k in range(2):
                self.ember(b["p"] + unreal.Vector(random.uniform(-10, 10), random.uniform(-10, 10), random.uniform(-10, 10)),
                           unreal.Vector(random.uniform(-40, 40), random.uniform(-40, 40), random.uniform(20, 90)), 0.4, 120.0)
            hit = None
            for s in self.skels:
                if not s.dead:
                    sp = s.loc + unreal.Vector(0, 0, 100)
                    if (sp - b["p"]).length() < 85.0:
                        hit = s
                        break
            if hit or b["trav"] > 2800.0:
                b["on"] = False
                for part in ("a", "halo", "light"):
                    b[part].set_actor_location(HIDE, False, True)
                b["light"].point_light_component.set_intensity(0.0)
                if hit:
                    self.impact(b["p"])
                    dmg = random.randint(11, 18)
                    hit.hp -= dmg
                    hit.aggro = True
                    self.text(hit.loc, dmg)
                    if hit.hp <= 0:
                        hit.dead = True
                        hit.dead_t = 4.0
                        hit.play("Death_C_Skeletons", loop=False, force=True)
                        self.kills += 1
                    else:
                        hit.play("Hit_A", loop=False, rate=1.6, force=True)
                        hit.lock = 0.3
        # skeletons
        alive = 0
        for s in self.skels:
            if s.dead:
                if s.dead_t > 0:
                    s.dead_t -= dt
                    if s.dead_t <= 0:
                        s.a.set_actor_location(HIDE, False, True)
                continue
            alive += 1
            s.lock -= dt
            s.cool -= dt
            to = h.loc - s.loc
            to.z = 0
            dist = to.length()
            if dist < 1000 or s.aggro:
                s.aggro = True
            if s.pending_hit > 0:
                s.pending_hit -= dt
                if s.pending_hit <= 0 and dist < 190 and not h.dead:
                    dmg = random.randint(3, 5)
                    h.hp -= dmg
                    self.text(h.loc, "-%d" % dmg)
                    if h.hp <= 0:
                        h.dead = True
                        h.dead_t = 3.0
                        h.play("Death_A", loop=False, force=True)
                    elif h.lock <= 0:
                        h.play("Hit_A", loop=False, rate=1.6, force=True)
                        h.lock = 0.25
            if s.lock > 0 or h.dead or not s.aggro:
                if s.lock <= 0:
                    s.play("Idle_Combat")
                continue
            if dist > 150:
                step = to.normal() * 520.0 * dt
                for o in self.skels:   # keep a little space between skeletons
                    if o is not s and not o.dead:
                        dd = s.loc - o.loc
                        dd.z = 0
                        if 0.1 < dd.length() < 120:
                            step = step + dd.normal() * 200.0 * dt
                s.a.set_actor_location(push_out(s.loc + step, 35.0), False, True)
                s.face(to.x, to.y, dt)
                s.play("Running_A")
            elif s.cool <= 0:
                s.face(to.x, to.y, dt, snap=True)
                s.play("1H_Melee_Attack_Chop", loop=False, rate=1.4, force=True)
                s.cool = 1.1
                s.lock = 0.6
                s.pending_hit = 0.35
        if alive == 0:
            if self.wave_t < 0:
                self.wave_t = L.get("respawn_s", 6.0)
            self.wave_t -= dt
            if self.wave_t <= 0:
                self.wave_t = -1
                for s in self.skels:
                    s.dead, s.hp, s.aggro = False, s.max_hp, False
                    s.a.set_actor_location(s.home, False, True)
                    s.play("Idle_Combat", force=True)
        # wildlife
        for d in self.deer:
            self.animal(d, dt, 700.0, 750.0, "Graze", "Run")
        for c in self.crows:
            self.animal(c, dt, 450.0, 500.0, "Idle", "Fly")
        # effects
        for e in self.embers:
            if e["life"] > 0:
                e["life"] -= dt
                e["v"].z += e["g"] * dt
                e["a"].set_actor_location(e["a"].get_actor_location() + e["v"] * dt, False, True)
                k = max(0.0, e["life"] / e["max"])
                e["a"].set_actor_scale3d(unreal.Vector(0.06, 0.06, 0.06) * (0.3 + k))
                if e["life"] <= 0:
                    e["a"].set_actor_location(HIDE, False, True)
        for f in self.flares:
            if f["life"] > 0:
                f["life"] -= dt
                k = f["life"] / 0.22
                f["a"].set_actor_scale3d(unreal.Vector(1, 1, 1) * (0.9 * math.sin(k * math.pi) + 0.05))
                if f["life"] <= 0:
                    f["a"].set_actor_location(HIDE, False, True)
        for s in self.scorch:
            if s["life"] > 0:
                s["life"] -= dt
                k = min(1.0, s["life"] / 2.0)
                s["a"].set_actor_scale3d(unreal.Vector(1.6, 1.6, 1.6) * (0.6 + 0.4 * k))
                if s["life"] <= 0:
                    s["a"].set_actor_location(HIDE, False, True)
        for fl in list(self.flashes):
            fl[1] -= dt
            fl[0].point_light_component.set_intensity(max(0.0, fl[1] / 0.35) * 1800.0)
            if fl[1] <= 0:
                fl[0].set_actor_location(HIDE, False, True)
                self.flashes.remove(fl)
        for t in self.texts:
            if t["life"] > 0:
                t["life"] -= dt
                t["a"].set_actor_location(t["a"].get_actor_location() + unreal.Vector(0, 0, 140 * dt), False, True)
                if t["life"] <= 0:
                    t["a"].set_actor_location(HIDE, False, True)
        # camera follows the hero (same offset as Godot)
        self.cam.set_actor_location(h.loc + CAM_DIR * 6000.0, False, True)
        # HUD
        sl = unreal.SystemLibrary
        sl.print_string(self.world, "Life %d / %d    Slain %d    Skeletons left %d" % (max(0, h.hp), h.max_hp, self.kills, alive), True, False, unreal.LinearColor(1, 0.85, 0.5, 1), 0.0)
        sl.print_string(self.world, "Whisperwood Clearing playtest  ·  Unreal %s  ·  Lumen" % unreal.SystemLibrary.get_engine_version().split("-")[0], True, False, unreal.LinearColor(0.8, 0.8, 0.8, 1), 0.0)
        sl.print_string(self.world, "Move: left stick / WASD   Aim: right stick / mouse   Ember Bolt: RT / left click   Stop: Esc", True, False, unreal.LinearColor(0.6, 0.6, 0.6, 1), 0.0)

    def animal(self, u, dt, scare, speed, idle, run):
        to = self.hero.loc - u.loc
        to.z = 0
        if u.state == "idle":
            if to.length() < scare:
                u.state = "flee"
                u.timer = 2.6 if u.kind == "deer" else 4.0
                away = (to * -1).normal()
                a = random.uniform(-0.5, 0.5)
                away = unreal.Vector(away.x * math.cos(a) - away.y * math.sin(a), away.x * math.sin(a) + away.y * math.cos(a), 0)
                u.vel = away * speed
                if u.kind == "crow":
                    u.vel.z = 320.0
                u.play(run, rate=1.6 if u.kind == "deer" else 1.0)
        elif u.state == "flee":
            u.timer -= dt
            p = u.loc + u.vel * dt
            if u.kind == "deer":
                p = push_out(p, 60.0)
            u.a.set_actor_location(p, False, True)
            u.face(u.vel.x, u.vel.y, dt)
            if u.timer <= 0:
                if u.kind == "crow":
                    u.state, u.timer = "gone", random.uniform(10, 16)
                    u.a.set_actor_location(HIDE, False, True)
                else:
                    u.state = "idle"
                    u.play(idle)
        elif u.state == "gone":
            u.timer -= dt
            if u.timer <= 0 and (self.hero.loc - u.home).length() > 1000:
                u.a.set_actor_location(u.home, False, True)
                u.state = "idle"
                u.play(idle)

    # ------------------------------------------------------------ slate hook
    def on_tick(self, dt):
        try:
            world = unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_game_world()
            if world is None:
                if self.started:
                    log("play stopped; director off. kills", self.kills)
                    unreal.unregister_slate_post_tick_callback(self.handle)
                return
            if not self.started:
                self.started = True
                self.setup(world)
            self.tick(dt)
        except Exception:
            log(traceback.format_exc())
            unreal.unregister_slate_post_tick_callback(self.handle)


try:
    if "WhisperwoodClearing" not in unreal.get_editor_subsystem(unreal.UnrealEditorSubsystem).get_editor_world().get_path_name():
        unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).load_level("/Game/Hollowcrown/Maps/WhisperwoodClearing")
    director = Director()
    director.handle = unreal.register_slate_post_tick_callback(director.on_tick)
    unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).editor_request_begin_play()
    log("play requested")
except Exception:
    log(traceback.format_exc())
print("s12: playing (Esc stops)")
