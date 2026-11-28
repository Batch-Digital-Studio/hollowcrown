class_name Chapter3D
extends Node3D
## The 3D look of Chapter 1 (presentation only): terrain with region textures and height, water,
## thousands of props batched per chunk and culled around the camera, glade lights and fires,
## bridges, caches, arena dressing, ambient wildlife and region moods.

const C1 := "res://assets/chapter1/%s.glb"
const WW := "res://assets/whisperwood/%s.glb"
const TER := "res://assets/chapter1/terrain/%s.png"
const CHUNK_M := 32.0
const SHOW_R := 56.0

## kind -> model path (others resolved by Level3D.path_for / Whisperwood)
const ALIAS := {
	"dead_large": "tree_dead_large", "dead_small": "tree_dead_small",
}
## kinds that do not cast shadows (small ground cover)
const NO_SHADOW := ["grass_1", "grass_2", "fern_1", "fern_2", "flowers_1", "mushroom_plain", "mushroom_ember", "rock_3",
	"reeds_1", "reeds_2", "lily_pads", "bone_A", "skull", "swamp_hummock"]
## Tall things that fade out when they stand between the camera and the hero.
const OCCLUDERS := ["tree_dying_1", "tree_dying_2", "tree_dying_3", "tree_dead_1", "dead_large", "swamp_cypress",
	"swamp_cypress_2", "swamp_snag", "hollow_oak", "tower_ruin", "pillar_great", "crypt", "standing_stone", "rock_2"]
## per-kind scale fix for imported kits (KayKit halloween is sized differently)
const KIND_SCALE := {"gravestone": 0.62, "grave_A": 0.55, "grave_A_destroyed": 0.55, "coffin": 0.62, "crypt": 0.95,
	"tree_dead_large": 1.3, "tree_dead_small": 1.2, "shrine_candles": 0.85, "skull": 0.3, "bone_A": 0.6,
	"barrel_large": 0.5, "crates_stacked": 0.55, "banner_red": 0.7, "rubble_large": 0.3, "rubble_half": 0.35}

static var _mesh_cache := {}
var fade_batches: Array = []   # {chunk, mm, pos, faded}

var zone: Zone
var C: Dictionary
var heights := PackedFloat32Array()
var chunks := {}          # Vector2i -> Node3D
var _cull_t := 0.0
var _batches := {}        # "cx,cz|path" -> {mesh, xforms, shadow}
var water_mat: ShaderMaterial
var cache_nodes := {}     # Vector2 (px) -> Node3D
var fireflies: CPUParticles3D
var mist: CPUParticles3D
var _murk := 0.0

func _w() -> int:
	return Zone.W

# ------------------------------------------------------------------ mesh helpers

static func resolve(kind: String) -> String:
	var k: String = ALIAS.get(kind, kind)
	if ResourceLoader.exists(C1 % k):
		return C1 % k
	if ResourceLoader.exists(WW % k):
		return WW % k
	return Level3D.path_for(k)

## All meshes of a model merged into one ArrayMesh (transforms baked).
static func merged(path: String) -> ArrayMesh:
	if _mesh_cache.has(path):
		return _mesh_cache[path]
	var out := ArrayMesh.new()
	if not ResourceLoader.exists(path):
		_mesh_cache[path] = null
		return null
	var root: Node3D = load(path).instantiate()
	var stack := [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var it: Array = stack.pop_back()
		var n: Node = it[0]
		var xf: Transform3D = it[1]
		if n is Node3D and n != root:
			xf = xf * (n as Node3D).transform
		if n is MeshInstance3D and (n as MeshInstance3D).mesh:
			var mesh: Mesh = (n as MeshInstance3D).mesh
			for s in mesh.get_surface_count():
				var arr: Array = mesh.surface_get_arrays(s)
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				for i in v.size():
					v[i] = xf * v[i]
				arr[Mesh.ARRAY_VERTEX] = v
				if arr[Mesh.ARRAY_NORMAL] != null:
					var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
					for i in nr.size():
						nr[i] = (xf.basis * nr[i]).normalized()
					arr[Mesh.ARRAY_NORMAL] = nr
				arr[Mesh.ARRAY_TANGENT] = null
				arr[Mesh.ARRAY_BONES] = null
				arr[Mesh.ARRAY_WEIGHTS] = null
				out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
				var mat := (n as MeshInstance3D).get_active_material(s)
				out.surface_set_material(out.get_surface_count() - 1, mat)
		for c in n.get_children():
			stack.append([c, xf])
	root.free()
	_mesh_cache[path] = out
	return out

## The same mesh with dither-fade materials (instance colour alpha): used for things that may hide the hero.
static func merged_fade(path: String) -> ArrayMesh:
	var key := path + "|fade"
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var src := merged(path)
	if src == null:
		return null
	var out := src.duplicate() as ArrayMesh
	for s in out.get_surface_count():
		var m := out.surface_get_material(s)
		if m is BaseMaterial3D:
			var d := (m as BaseMaterial3D).duplicate() as BaseMaterial3D
			d.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
			d.vertex_color_use_as_albedo = true
			out.surface_set_material(s, d)
	_mesh_cache[key] = out
	return out

## Fade trees and tall props between the camera and the hero (dithered, so no sorting problems).
func _fade_occluders(delta: float) -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	var hp := IsoView.to3d(g.player.global_position)
	var cam := Vector2(1, 1).normalized()          # towards the camera on the ground (south-east)
	for fb in fade_batches:
		if not (fb.node as Node3D).visible:
			continue
		var pos: PackedVector3Array = fb.pos
		var al: PackedFloat32Array = fb.alpha
		var reach: float = clampf(float(fb.h) * 0.8, 2.0, 9.0)
		var mm: MultiMesh = fb.mm
		for i in pos.size():
			var d := Vector2(pos[i].x - hp.x, pos[i].z - hp.z)
			var along := d.dot(cam)
			var lat := absf(d.cross(cam))
			var want := 0.28 if (along > -1.0 and along < reach and lat < 3.0 + along * 0.15) else 1.0
			if absf(al[i] - want) > 0.01:
				al[i] = move_toward(al[i], want, delta * 3.0)
				mm.set_instance_color(i, Color(1, 1, 1, al[i]))
		fb.alpha = al

func height_at(px: Vector2) -> float:
	var W := Zone.W
	var H := Zone.H
	var fx := clampf(px.x / Zone.CELL - 0.5, 0.0, W - 1.001)
	var fy := clampf(px.y / Zone.CELL - 0.5, 0.0, H - 1.001)
	var x0 := int(fx)
	var y0 := int(fy)
	var tx := fx - x0
	var ty := fy - y0
	var a := lerpf(heights[y0 * W + x0], heights[y0 * W + x0 + 1], tx)
	var b := lerpf(heights[(y0 + 1) * W + x0], heights[(y0 + 1) * W + x0 + 1], tx)
	return lerpf(a, b, ty)

func _chunk(px: Vector2) -> Node3D:
	var k := Vector2i(int(px.x * IsoView.S / CHUNK_M), int(px.y * IsoView.S / CHUNK_M))
	if not chunks.has(k):
		var n := Node3D.new()
		n.name = "chunk_%d_%d" % [k.x, k.y]
		add_child(n)
		chunks[k] = n
	return chunks[k]

func _add(kind: String, xf: Transform3D, px: Vector2) -> void:
	var path := resolve(kind)
	var k := Vector2i(int(px.x * IsoView.S / CHUNK_M), int(px.y * IsoView.S / CHUNK_M))
	var key := "%d,%d|%s" % [k.x, k.y, path]
	if not _batches.has(key):
		_batches[key] = {"path": path, "xforms": [], "shadow": not NO_SHADOW.has(kind), "chunk": k, "px": px, "fade": OCCLUDERS.has(kind)}
	_batches[key].xforms.append(xf)

func _flush() -> void:
	for key in _batches:
		var b: Dictionary = _batches[key]
		var mesh := merged(b.path) if not b.fade else merged_fade(b.path)
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = b.fade
		mm.mesh = mesh
		mm.instance_count = b.xforms.size()
		for i in b.xforms.size():
			mm.set_instance_transform(i, b.xforms[i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if b.shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_chunk(b.px).add_child(mi)
		if b.fade:
			var pos := PackedVector3Array()
			for xf in b.xforms:
				pos.append((xf as Transform3D).origin)
			for i in b.xforms.size():
				mm.set_instance_color(i, Color.WHITE)
			var faded := PackedFloat32Array()
			faded.resize(pos.size())
			faded.fill(1.0)
			fade_batches.append({"node": _chunk(b.px), "mm": mm, "pos": pos, "alpha": faded,
				"h": mesh.get_aabb().size.y * maxf(0.5, (b.xforms[0] as Transform3D).basis.get_scale().y)})
	_batches.clear()

# ------------------------------------------------------------------ build

func build(z: Zone) -> void:
	zone = z
	C = z.chapter
	_heights()
	_terrain()
	_water()
	_props()
	_bridges()
	_glade_fx()
	_caches()
	_waystones()
	_herbs()
	_kettle()
	_shortcuts()
	_ambient()
	_cull(true)

func _heights() -> void:
	var W := Zone.W
	var H := Zone.H
	var hill := FastNoiseLite.new()
	hill.seed = ChapterDB.SEED + 3
	hill.frequency = 0.08
	heights.resize(W * H)
	for y in H:
		for x in W:
			var k := y * W + x
			var h := 0.0
			var wtr: int = C.water[k]
			if zone.grid[k] == 1:
				h = -0.14 if wtr == 1 else 0.0
				if wtr == 2:
					h = -0.9   # under a bridge
			elif wtr == 2:
				h = -0.95
			else:
				var e: int = C.edge[k]
				h = minf(2.2, maxf(0.0, (e - 1) * 0.32)) * (0.75 + 0.5 * (hill.get_noise_2d(x, y) + 1.0) * 0.5)
			heights[k] = h
	for pass_i in 2:
		var out := heights.duplicate()
		for y in range(1, H - 1):
			for x in range(1, W - 1):
				var k := y * W + x
				var s := 0.0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						s += heights[k + dy * W + dx]
				out[k] = s / 9.0
		heights = out
	# walkable land stays level so units stand on it
	for k in W * H:
		if zone.grid[k] == 1 and C.water[k] == 0:
			heights[k] = clampf(heights[k], -0.05, 0.04)

func _img_tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)

func _terrain() -> void:
	var W := Zone.W
	var H := Zone.H
	var splat := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var aux := Image.create(W, H, false, Image.FORMAT_RGBA8)
	var hm := Image.create(W, H, false, Image.FORMAT_RF)
	var arena_c: Vector2 = C.arena.pos / Zone.CELL
	var arena_r: float = C.arena.r_px / Zone.CELL
	var stone_spots: Array = []
	for gl in C.glades:
		if gl.kind in ["shrine", "ruins"]:
			stone_spots.append([gl.pos / Zone.CELL, gl.r_px / Zone.CELL * 0.45])
	for y in H:
		for x in W:
			var k := y * W + x
			var r: int = C.region[k]
			var e: int = C.edge[k]
			splat.set_pixel(x, y, Color(1.0 if r == 0 else 0.0, 1.0 if r == 1 else 0.0, 1.0 if r == 2 else 0.0, 1.0))
			var wet := 1.0 if C.water[k] > 0 else 0.0
			var stone := 0.0
			var cp := Vector2(x, y)
			if cp.distance_to(arena_c) < arena_r - 1.5:
				stone = 1.0
			for s in stone_spots:
				if cp.distance_to(s[0]) < s[1]:
					stone = maxf(stone, 0.7)
			aux.set_pixel(x, y, Color(clampf((e - 0.5) / 3.0, 0.0, 1.0), wet, stone, C.pathm[k] / 255.0))
			hm.set_pixel(x, y, Color(heights[k], 0, 0))
	# soften region borders and the litter / wet masks
	splat.resize(W / 4, H / 4, Image.INTERPOLATE_BILINEAR)   # wide, soft region blends
	splat.resize(W * 2, H * 2, Image.INTERPOLATE_CUBIC)
	aux.resize(W * 2, H * 2, Image.INTERPOLATE_BILINEAR)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://scripts/view3d/shaders/terrain.gdshader")
	mat.set_shader_parameter("splat", _img_tex(splat))
	mat.set_shader_parameter("aux", _img_tex(aux))
	mat.set_shader_parameter("heightmap", _img_tex(hm))
	for t in ["grass", "litter", "mud", "path", "barrow", "stone"]:
		mat.set_shader_parameter("tex_" + t, load(TER % t))
	mat.set_shader_parameter("map_size", Vector2(W * 2.0, H * 2.0))
	var pm := PlaneMesh.new()
	pm.size = Vector2(W * 2.0, H * 2.0)
	pm.subdivide_width = W * 2 - 1
	pm.subdivide_depth = H * 2 - 1
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = mat
	mi.position = Vector3(W, 0, H)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Terrain"
	add_child(mi)

func _water() -> void:
	var W := Zone.W
	var H := Zone.H
	var m := Image.create(W, H, false, Image.FORMAT_L8)
	var swamp := 0
	var n := 0
	for y in H:
		for x in W:
			var k := y * W + x
			var wv: int = C.water[k]
			m.set_pixel(x, y, Color.from_hsv(0, 0, 1.0 if wv == 2 else (0.45 if wv == 1 else 0.0)))
			if wv > 0:
				n += 1
				if C.region[k] == 1:
					swamp += 1
	m.resize(W * 4, H * 4, Image.INTERPOLATE_BILINEAR)
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://scripts/view3d/shaders/water.gdshader")
	water_mat.set_shader_parameter("mask", _img_tex(m))
	water_mat.set_shader_parameter("normal_tex", load(TER % "water_n"))
	water_mat.set_shader_parameter("map_size", Vector2(W * 2.0, H * 2.0))
	var pm := PlaneMesh.new()
	pm.size = Vector2(W * 2.0, H * 2.0)
	pm.subdivide_width = 120
	pm.subdivide_depth = 120
	var mi := MeshInstance3D.new()
	mi.mesh = pm
	mi.material_override = water_mat
	mi.position = Vector3(W, -0.06, H)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.name = "Water"
	mi.visible = OS.get_environment("HC_NOWATER") == ""
	add_child(mi)

func _props() -> void:
	var i := 0
	for p in C.props:
		i += 1
		var kind := String(p[0])
		if kind == "swamp_cypress" and i % 2 == 0:
			kind = "swamp_cypress_2"
		var px := Vector2(float(p[1]), float(p[2]))
		var sc: float = float(p[4]) * float(KIND_SCALE.get(ALIAS.get(kind, kind), 1.0))
		var y := height_at(px)
		if kind == "lily_pads":
			y = -0.05
		var b := Basis(Vector3.UP, deg_to_rad(float(p[3]))).scaled(Vector3.ONE * sc)
		_add(kind, Transform3D(b, IsoView.to3d(px, y)), px)
	_flush()

func _bridges() -> void:
	for br in C.bridges:
		var a: Vector2 = br.a
		var b: Vector2 = br.b
		var mid := (a + b) * 0.5
		var d := (b - a)
		var length := d.length() * IsoView.S
		var node: Node3D = Puppet.scene(C1 % "bridge").instantiate()
		node.position = IsoView.to3d(mid, -0.25)
		node.rotation.y = atan2(d.x, d.y) + PI
		node.scale = Vector3(1.3, 1.0, maxf(1.0, length / 8.0))
		_chunk(mid).add_child(node)

func _omni(px: Vector2, h: float, col: Color, rng: float, energy: float, flicker: bool = false) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = rng
	l.light_energy = energy
	l.position = IsoView.to3d(px, h)
	if flicker:
		l.set_meta("flicker", energy)
	_chunk(px).add_child(l)
	return l

func _fire(px: Vector2, h: float, size: float, e: String = "fire") -> void:
	var f := ElementFx.particles("flame", e, int(14 * size), 0.6, false, 0.7 * size)
	f.position = IsoView.to3d(px, h)
	f.emission_sphere_radius = 0.18 * size
	_chunk(px).add_child(f)
	var em := ElementFx.particles("ember", e, int(8 * size), 1.6, false, 1.0)
	em.position = f.position
	_chunk(px).add_child(em)
	var sm := ElementFx.particles("smoke", e, 6, 2.5, false, size)
	sm.position = f.position + Vector3(0, 0.5, 0)
	_chunk(px).add_child(sm)

func _glade_fx() -> void:
	for gl in C.glades:
		var c: Vector2 = gl.pos
		match String(gl.kind):
			"camp":
				_omni(c + Vector2(32, -32), 0.9, Color(1.0, 0.55, 0.22), 11.0, 3.2, true)
				_fire(c + Vector2(32, -32), 0.2, 1.3)
			"oak":
				_omni(c + Vector2(0, -96), 1.3, Color(1.0, 0.45, 0.12), 12.0, 3.0, true)
				for o in [Vector2(96, 32), Vector2(-128, -32)]:
					_omni(c + o, 0.5, Color(1.0, 0.5, 0.18), 4.5, 1.5, true)
					_add_fireflies(c + o, Color(1.0, 0.7, 0.3))
			"shrine":
				_omni(c + Vector2(0, -32), 1.0, Color(0.5, 0.85, 1.0), 10.0, 2.6, true)
				_add_fireflies(c, Color(0.6, 0.9, 1.0))
			"stones":
				_omni(c, 2.0, Color(0.55, 0.7, 1.0), 9.0, 1.6)
			"lake":
				_add_fireflies(c, Color(0.7, 1.0, 0.6))
			"ruins":
				_omni(c, 1.5, Color(1.0, 0.6, 0.3), 8.0, 1.4, true)
				_fire(c + Vector2(128, 64), 0.1, 0.8)
			"graves":
				_omni(c + Vector2(0, -256), 1.5, Color(0.55, 0.8, 1.0), 10.0, 2.0, true)
			"arena":
				var A: Dictionary = C.arena
				var ac: Vector2 = A.pos
				var r: float = A.r_px - 1.2 * Zone.CELL
				for i in 10:
					var a := TAU * i / 10 + 0.2
					var pp := ac + Vector2(cos(a), sin(a)) * r
					_fire(pp, 6.4, 1.0, "cold")
					if i % 2 == 0:
						_omni(pp, 6.0, Color(0.45, 0.75, 1.0), 12.0, 2.2, true)
				for s in [-1, 1]:
					var bp: Vector2 = ac + Vector2(s * 4.5, -(A.r_px / Zone.CELL) + 4.5) * Zone.CELL
					_fire(bp, 1.45, 0.9)
					_omni(bp, 2.0, Color(1.0, 0.55, 0.2), 9.0, 2.0, true)
				_omni(ac + Vector2(0, -(A.r_px / Zone.CELL - 3.5) * Zone.CELL), 3.5, Color(0.5, 0.8, 1.0), 8.0, 2.0)

func _add_fireflies(px: Vector2, col: Color) -> void:
	var p := CPUParticles3D.new()
	p.amount = 16
	p.lifetime = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 3.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 0.1
	p.initial_velocity_max = 0.4
	p.gravity = Vector3(0, 0.05, 0)
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	q.material = IsoView.glow_material(col)
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 0.0))
	g.add_point(0.3, col)
	g.set_color(g.get_point_count() - 1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	p.position = IsoView.to3d(px, 1.0)
	_chunk(px).add_child(p)

## Hidden caches: a chest model in each pocket with a faint glint so a careful eye finds it.
func _caches() -> void:
	for ch in C.caches:
		var px: Vector2 = ch.pos
		var root := Node3D.new()
		root.position = IsoView.to3d(px)
		var chest: Node3D = Puppet.scene(Level3D.path_for("chest")).instantiate()
		chest.scale = Vector3.ONE * 0.7
		chest.rotation.y = PI * 0.25
		root.add_child(chest)
		var gl := CPUParticles3D.new()
		gl.amount = 6
		gl.lifetime = 1.6
		gl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		gl.emission_sphere_radius = 0.6
		gl.gravity = Vector3(0, 0.3, 0)
		gl.initial_velocity_max = 0.2
		var q := QuadMesh.new()
		q.size = Vector2(0.18, 0.18)
		q.material = IsoView.glow_material(ChapterDB.CACHE_LIGHT)
		gl.mesh = q
		gl.position.y = 0.8
		gl.name = "Glint"
		root.add_child(gl)
		var l := OmniLight3D.new()
		l.light_color = ChapterDB.CACHE_LIGHT
		l.omni_range = 3.0
		l.light_energy = 0.8
		l.position.y = 1.0
		l.name = "Light"
		root.add_child(l)
		_chunk(px).add_child(root)
		cache_nodes[px] = root

## A cache was opened: lid burst, light flare, glint stops.
func open_cache(px: Vector2) -> void:
	var best: Node3D = null
	var bd := 1e9
	for k in cache_nodes:
		var d := (k as Vector2).distance_to(px)
		if d < bd:
			bd = d
			best = cache_nodes[k]
	if best == null or bd > 160.0:
		return
	var gl := best.get_node_or_null("Glint") as CPUParticles3D
	if gl:
		gl.emitting = false
	var l := best.get_node_or_null("Light") as OmniLight3D
	if l:
		var tw := l.create_tween()
		tw.tween_property(l, "light_energy", 6.0, 0.1)
		tw.tween_property(l, "light_energy", 0.0, 1.2)
	ElementFx.impact(self, best.position + Vector3(0, 0.8, 0), "light", 1.0)

func _waystones() -> void:
	for wp in C.waypoints:
		var px: Vector2 = wp
		var n: Node3D = Puppet.scene(C1 % "waystone").instantiate()
		n.position = IsoView.to3d(px)
		_chunk(px).add_child(n)
		_omni(px, 3.0, Color(0.4, 0.75, 1.0), 6.0, 1.6)

func _ambient() -> void:
	fireflies = CPUParticles3D.new()
	fireflies.amount = 40
	fireflies.lifetime = 4.0
	fireflies.preprocess = 4.0
	fireflies.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	fireflies.emission_box_extents = Vector3(16, 1.2, 16)
	fireflies.direction = Vector3.UP
	fireflies.spread = 180.0
	fireflies.initial_velocity_min = 0.05
	fireflies.initial_velocity_max = 0.3
	fireflies.gravity = Vector3.ZERO
	fireflies.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	q.material = IsoView.glow_material(Color(1.0, 0.85, 0.45))
	fireflies.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 1))
	g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0))
	fireflies.color_ramp = g
	add_child(fireflies)
	mist = CPUParticles3D.new()
	mist.amount = 14
	mist.lifetime = 9.0
	mist.preprocess = 9.0
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(18, 0.1, 18)
	mist.direction = Vector3(1, 0, 0.3)
	mist.spread = 30.0
	mist.initial_velocity_min = 0.1
	mist.initial_velocity_max = 0.3
	mist.gravity = Vector3.ZERO
	mist.local_coords = false
	mist.scale_amount_min = 3.0
	mist.scale_amount_max = 6.0
	var mq := QuadMesh.new()
	mq.size = Vector2(1.6, 1.6)
	mq.material = ElementFx.smoke_mat()
	mist.mesh = mq
	var mg := Gradient.new()
	mg.set_color(0, Color(0.7, 0.8, 0.75, 0.0))
	mg.add_point(0.5, Color(0.7, 0.8, 0.75, 0.1))
	mg.set_color(mg.get_point_count() - 1, Color(0.7, 0.8, 0.75, 0.0))
	mist.color_ramp = mg
	add_child(mist)

# ------------------------------------------------------------------ herbs, kettle, shortcuts

var herb_nodes := {}      # Vector2 px -> Node3D
var shortcut_nodes: Array = []

func _herbs() -> void:
	for hb in C.herbs:
		var px: Vector2 = hb.pos
		var h: Dictionary = BrewingDB.HERBS[hb.id]
		var root := Node3D.new()
		root.position = IsoView.to3d(px, height_at(px))
		var m: Node3D = Puppet.scene(resolve(String(h.model))).instantiate()
		m.scale = Vector3.ONE * (1.6 if hb.id == "emberhood" else 1.4)
		m.rotation.y = randf() * TAU
		root.add_child(m)
		var motes := ElementFx.particles("mote", "light", 5, 1.8, false, 0.7)
		var col: Color = h.color
		motes.color_ramp = ElementFx._ramp([Color(col.r, col.g, col.b, 0), col, Color(col.r, col.g, col.b, 0)])
		motes.emission_sphere_radius = 0.35
		motes.position.y = 0.3
		motes.name = "Motes"
		root.add_child(motes)
		_chunk(px).add_child(root)
		herb_nodes[px] = root

func set_herb(px: Vector2, on: bool) -> void:
	var best: Node3D = null
	var bd := 1e9
	for k in herb_nodes:
		var d := (k as Vector2).distance_to(px)
		if d < bd:
			bd = d
			best = herb_nodes[k]
	if best and bd < 40.0:
		var tw := best.create_tween()
		tw.tween_property(best, "scale", Vector3.ONE * (1.0 if on else 0.05), 0.4)
		(best.get_node("Motes") as CPUParticles3D).emitting = on

func _kettle() -> void:
	var px: Vector2 = C.kettle
	var n: Node3D = Puppet.scene(C1 % "cauldron").instantiate()
	n.position = IsoView.to3d(px)
	_chunk(px).add_child(n)
	_fire(px, 0.15, 0.6)
	_omni(px, 1.2, Color(0.55, 1.0, 0.45), 5.0, 1.4, true)
	var steam := ElementFx.particles("smoke", "physical", 8, 2.2, false, 0.7)
	steam.color_ramp = ElementFx._ramp([Color(0.7, 0.95, 0.6, 0), Color(0.7, 0.95, 0.6, 0.35), Color(0.7, 0.95, 0.6, 0)])
	steam.position = IsoView.to3d(px, 1.1)
	_chunk(px).add_child(steam)

func _shortcuts() -> void:
	for i in C.shortcuts.size():
		var sc: Dictionary = C.shortcuts[i]
		var mid: Vector2 = sc.mid
		var dir: Vector2 = sc.dir
		var yaw := atan2(dir.x, dir.y) + PI      # model -Z along the way
		var root := Node3D.new()
		root.position = IsoView.to3d(mid)
		root.rotation.y = yaw
		var ent := {"kind": sc.kind, "root": root}
		match String(sc.kind):
			"drawbridge":
				var span: float = sc.span_px * IsoView.S
				# hinge at the far (lever) end; raised it stands up out of the water
				var hinge := Node3D.new()
				hinge.position = Vector3(0, -0.25, -span * 0.5)
				root.add_child(hinge)
				var br: Node3D = Puppet.scene(C1 % "bridge").instantiate()
				br.scale = Vector3(1.0, 1.0, span / 8.0)
				br.position = Vector3(0, 0, span * 0.5)
				hinge.add_child(br)
				hinge.rotation.x = deg_to_rad(-78.0)
				ent.moving = hinge
			"gate":
				var fr: Node3D = Puppet.scene(C1 % "gate_frame").instantiate()
				fr.rotation.y = PI * 0.5
				root.add_child(fr)
				var bars: Node3D = Puppet.scene(C1 % "gate_bars").instantiate()
				bars.rotation.y = PI * 0.5
				root.add_child(bars)
				ent.moving = bars
			"log":
				# a dead tree standing at the near bank; it falls across the water
				var pivot := Node3D.new()
				pivot.position = Vector3(0, 0, float(sc.span_px) * IsoView.S * 0.5)   # the near bank
				root.add_child(pivot)
				var tree: Node3D = Puppet.scene(resolve("tree_dead_1")).instantiate()
				tree.scale = Vector3.ONE * 1.7
				pivot.add_child(tree)
				ent.moving = pivot
		# lever (or nothing for the log: you push the tree)
		if sc.kind != "log":
			var lp: Vector2 = sc.lever
			var lever := Node3D.new()
			lever.position = IsoView.to3d(lp, height_at(lp))
			lever.add_child(Puppet.scene(C1 % "lever_base").instantiate())
			var handle: Node3D = Puppet.scene(C1 % "lever_handle").instantiate()
			handle.position.y = 0.45
			handle.rotation.x = deg_to_rad(35.0)
			lever.add_child(handle)
			ent.handle = handle
			add_child(lever)
			var l := ElementFx.light(Color(1.0, 0.8, 0.45), 3.0, 0.8)
			l.position.y = 1.2
			lever.add_child(l)
			ent.lever_light = l
		add_child(root)
		shortcut_nodes.append(ent)

func open_shortcut(i: int) -> void:
	if i < 0 or i >= shortcut_nodes.size():
		return
	var ent: Dictionary = shortcut_nodes[i]
	var mv: Node3D = ent.get("moving")
	if ent.has("handle"):
		var ht := (ent.handle as Node3D).create_tween()
		ht.tween_property(ent.handle, "rotation:x", deg_to_rad(-35.0), 0.35)
		(ent.lever_light as OmniLight3D).light_energy = 0.0
	match String(ent.kind):
		"drawbridge":
			var tw := mv.create_tween()
			tw.tween_interval(0.4)
			tw.tween_property(mv, "rotation:x", 0.0, 1.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"gate":
			var tw2 := mv.create_tween()
			tw2.tween_interval(0.3)
			tw2.tween_property(mv, "position:y", 2.9, 1.8).set_trans(Tween.TRANS_SINE)
		"log":
			var tw3 := mv.create_tween()
			tw3.tween_property(mv, "rotation:x", deg_to_rad(-92.0), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var root: Node3D = ent.root
	get_tree().create_timer(1.6).timeout.connect(func():
		ElementFx.ring(self, root.position, 4.0, Color(0.9, 0.85, 0.7, 0.8), 0.5, 0.06)
		var dust := ElementFx.particles("smoke", "physical", 12, 1.4, true, 2.0)
		dust.color_ramp = ElementFx._ramp([Color(0.5, 0.45, 0.4, 0), Color(0.5, 0.45, 0.4, 0.5), Color(0.5, 0.45, 0.4, 0)])
		ElementFx._burst_at(self, dust, root.position + Vector3(0, 0.3, 0), 2.0))

# ------------------------------------------------------------------ per frame

func _cull(force: bool = false) -> void:
	var iv := IsoView.instance
	if iv == null:
		return
	var t := IsoView.to3d(iv._target)
	for k in chunks:
		var c := Vector3((k.x + 0.5) * CHUNK_M, 0, (k.y + 0.5) * CHUNK_M)
		var d := Vector2(c.x - t.x, c.z - t.z).length()
		var n: Node3D = chunks[k]
		var want := d < SHOW_R
		if n.visible != want or force:
			n.visible = want

func _process(delta: float) -> void:
	_cull_t -= delta
	if _cull_t <= 0.0:
		_cull_t = 0.2
		_cull()
	_fade_occluders(delta)
	var iv := IsoView.instance
	if iv == null:
		return
	var t := IsoView.to3d(iv._target)
	var reg := zone.region_at(iv._target)
	fireflies.global_position = t + Vector3(0, 1.0, 0)
	fireflies.emitting = reg != 2
	mist.global_position = t + Vector3(0, 0.2, 0)
	mist.emitting = reg >= 1 and OS.get_environment("HC_NOMIST") == ""
	_murk = lerpf(_murk, 1.0 if reg == 1 else 0.0, minf(1.0, delta))
	water_mat.set_shader_parameter("murk", _murk)
	# fire flicker
	var tm := Time.get_ticks_msec() * 0.001
	for k in chunks:
		var n: Node3D = chunks[k]
		if not n.visible:
			continue
		for ch in n.get_children():
			if ch is OmniLight3D and ch.has_meta("flicker"):
				var base: float = ch.get_meta("flicker")
				ch.light_energy = base * (0.85 + 0.15 * sin(tm * 11.0 + ch.position.x) * sin(tm * 7.3 + ch.position.z))
