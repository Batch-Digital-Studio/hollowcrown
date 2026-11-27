"""Contact sheet: import .glb files and render them in a grid at the game's camera angle.
    python tools/blender/preview.py OUT.png a.glb b.glb ...
"""
import math
import sys

import bpy
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
out, files = argv[0], argv[1:]
bpy.ops.wm.read_factory_settings(use_empty=True)
cols = math.ceil(math.sqrt(len(files) * 1.6))
spacing = 7.0
for i, f in enumerate(files):
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=f)
    new = [o for o in bpy.data.objects if o not in before and o.parent is None]
    r, c = divmod(i, cols)
    for o in new:
        o.location += Vector(((c - cols / 2) * spacing, -(r - 1) * spacing, 0))
scn = bpy.context.scene
bpy.ops.mesh.primitive_plane_add(size=200)
g = bpy.context.active_object
m = bpy.data.materials.new("g")
m.use_nodes = True
m.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (0.1, 0.09, 0.07, 1)
g.data.materials.append(m)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
cam.data.type = "ORTHO"
cam.data.ortho_scale = cols * spacing * 1.05
yaw, pitch = math.radians(45), math.radians(52)
d = Vector((math.sin(yaw) * math.cos(pitch), -math.cos(yaw) * math.cos(pitch), math.sin(pitch)))
rows = math.ceil(len(files) / cols)
center = Vector((-spacing * 0.5, -(rows / 2 - 1.5) * spacing, 1.5))
cam.location = center + d * 80
cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
scn.collection.objects.link(cam)
scn.camera = cam
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sun.data.energy = 3.5
sun.data.color = (1.0, 0.85, 0.7)
sun.rotation_euler = (math.radians(55), 0, math.radians(-30))
scn.collection.objects.link(sun)
scn.world = bpy.data.worlds.new("w")
scn.world.color = (0.08, 0.08, 0.1)
scn.render.engine = "CYCLES"
scn.cycles.samples = 16
scn.cycles.device = "CPU"
scn.render.resolution_x, scn.render.resolution_y = 1400, 900
scn.render.filepath = out
bpy.ops.render.render(write_still=True)
