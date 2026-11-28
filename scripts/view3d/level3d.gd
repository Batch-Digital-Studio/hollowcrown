class_name Level3D
extends Node3D
## Builds the 3D look of a Zone from its cell grid: KayKit floor tiles, edge walls, props,
## torches and a region landmark. Presentation only; collision stays in the 2D Zone.
## One map cell (64 px) = 2 units = one KayKit small floor tile.

const DUN := "res://assets/kaykit/dungeon/%s.glb"
const HAL := "res://assets/kaykit/halloween/%s.gltf"
const CH := 8                    # cells per render chunk (lights are picked per chunk)
const WALL_H := 0.72             # back walls: 4 units * 0.72
const FRONT_H := 0.16            # camera-side walls are cut down so they never hide the fight

## Per-biome look: floor tile weights, colour multiplied over the KayKit texture, wall style.
const LOOKS := {
	"crypt":    {"floor": {"floor_tile_small": 30, "floor_tile_small_broken_A": 4, "floor_tile_small_broken_B": 4, "floor_tile_small_decorated": 1}, "tint": Color(0.92, 0.86, 0.82), "walls": "stone", "wall_tint": Color(0.8, 0.76, 0.74)},
	"castle":   {"floor": {"floor_tile_small": 24, "floor_tile_small_decorated": 1, "floor_tile_small_broken_A": 3}, "tint": Color(0.85, 0.88, 1.0), "walls": "stone", "wall_tint": Color(0.85, 0.87, 0.95)},
	"town":     {"floor": {"floor_tile_small": 1}, "tint": Color(0.82, 0.76, 0.7), "walls": "stone", "wall_tint": Color(1.0, 0.95, 0.9)},
	"forest":   {"floor": {"floor_dirt_small_A": 4, "floor_dirt_small_B": 3, "floor_tile_small_weeds_A": 3, "floor_tile_small_weeds_B": 3}, "tint": Color(0.55, 0.75, 0.42), "walls": "trees", "wall_tint": Color(0.55, 0.7, 0.45)},
	"swamp":    {"floor": {"floor_dirt_small_A": 4, "floor_dirt_small_B": 4, "floor_tile_small_weeds_B": 2}, "tint": Color(0.5, 0.6, 0.42), "walls": "trees", "wall_tint": Color(0.45, 0.6, 0.5)},
	"cave":     {"floor": {"floor_dirt_small_A": 5, "floor_dirt_small_B": 5, "floor_tile_small_broken_B": 1}, "tint": Color(0.62, 0.6, 0.7), "walls": "stone", "wall_tint": Color(0.55, 0.52, 0.6)},
	"tundra":   {"floor": {"floor_dirt_small_A": 5, "floor_tile_small_broken_A": 2, "floor_tile_small": 2}, "tint": Color(0.85, 0.95, 1.1), "walls": "stone", "wall_tint": Color(0.75, 0.9, 1.05)},
	"volcanic": {"floor": {"floor_dirt_small_A": 5, "floor_dirt_small_B": 4, "floor_tile_small_broken_B": 2}, "tint": Color(0.5, 0.38, 0.35), "walls": "stone", "wall_tint": Color(0.42, 0.32, 0.3)},
}

## zone deco kind -> [model path, scale, y offset]
const PROPS := {
	"skull": ["skull", 0.45], "bones": ["ribcage", 0.9], "crate": ["box_small", 0.9], "column": ["pillar", 0.55],
	"rock": ["rubble_half", 0.32], "stalagmite": ["rubble_half", 0.3], "stump": ["tree_dead_small", 0.7],
	"mushroom": ["bone_A", 1.0], "ember": ["candle_triple", 1.0], "vent": ["rubble_half", 0.25],
}

static var _mesh_cache := {}
var _batches := {}      # "chunk|path|tint" -> {mesh, xforms, mat}
var zone: Zone
var look: Dictionary
var torches: Array = []  # OmniLight3D

static func path_for(name: String) -> String:
	if ResourceLoader.exists(DUN % name):
		return DUN % name
	return HAL % name

## First mesh of a model file and its transform inside the file.
static func mesh_of(path: String) -> Array:
	if not _mesh_cache.has(path):
		var root: Node3D = load(path).instantiate()
		var found := [null, Transform3D.IDENTITY]
		var stack := [[root, Transform3D.IDENTITY]]
		while not stack.is_empty():
			var it: Array = stack.pop_back()
			var n: Node = it[0]
			var xf: Transform3D = it[1]
			if n is Node3D and n != root:
				xf = xf * (n as Node3D).transform
			if n is MeshInstance3D:
				found = [(n as MeshInstance3D).mesh, xf]
				break
			for c in n.get_children():
				stack.append([c, xf])
		root.free()
		_mesh_cache[path] = found
	return _mesh_cache[path]

func _h(x: int, y: int, salt: int = 0) -> float:
	var v := (x * 73856093) ^ (y * 19349663) ^ (salt * 83492791)
	return float(absi(v) % 10007) / 10007.0

func _add(name: String, xf: Transform3D, tint: Color = Color.WHITE) -> void:
	var path := path_for(name)
	var cx := int(floor(xf.origin.x / 2.0)) / CH
	var cz := int(floor(xf.origin.z / 2.0)) / CH
	var key := "%d,%d|%s|%s" % [cx, cz, path, tint.to_html()]
	if not _batches.has(key):
		var m: Array = mesh_of(path)
		_batches[key] = {"mesh": m[0], "local": m[1], "xforms": [], "tint": tint}
	_batches[key].xforms.append(xf)

const WW := "res://assets/whisperwood/%s.glb"

## Whisperwood Clearing playtest: everything placed from the shared layout (same file Unreal reads).
func build_slice(z: Zone) -> void:
	zone = z
	var L: Dictionary = z.slice
	var c := IsoView.to3d(Zone.SLICE_CENTER)
	_add_ww("ground", Transform3D(Basis(), c))
	for p in L.props:
		var b := Basis(Vector3.UP, deg_to_rad(float(p.rot))).scaled(Vector3.ONE * float(p.scale))
		_add_ww(String(p.kind), Transform3D(b, c + Vector3(float(p.x), 0, float(p.z))))
	for e in L.ember_lights:   # Emberhood mushrooms glow
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.5, 0.18)
		l.omni_range = 4.5
		l.light_energy = 1.6
		l.position = c + Vector3(float(e[0]), 0.6, float(e[1]))
		add_child(l)
		torches.append(l)
		var ff := _fireflies(Color(1.0, 0.7, 0.3))
		ff.position = l.position
		add_child(ff)
	var lm: Dictionary = L.landmark
	var ol := OmniLight3D.new()
	ol.light_color = Color(1.0, 0.45, 0.12)
	ol.omni_range = 11.0
	ol.light_energy = 3.0
	ol.position = c + Vector3(float(lm.x), 1.2, float(lm.z))
	add_child(ol)
	torches.append(ol)
	for a in L.animals.deer:
		_animal("deer", c + Vector3(float(a[0]), 0, float(a[1])), float(a[2]), c, float(L.walk_radius_m))
	for a in L.animals.crow:
		_animal("crow", c + Vector3(float(a[0]), 0, float(a[1])), float(a[2]), c, float(L.walk_radius_m))
	_flush()

func _add_ww(kind: String, xf: Transform3D) -> void:
	var path := WW % kind
	var cx := int(floor(xf.origin.x / 2.0)) / CH
	var cz := int(floor(xf.origin.z / 2.0)) / CH
	var key := "%d,%d|%s" % [cx, cz, path]
	if not _batches.has(key):
		var m: Array = mesh_of(path)
		_batches[key] = {"mesh": m[0], "local": m[1], "xforms": [], "tint": Color.WHITE}
	_batches[key].xforms.append(xf)

func _animal(kind: String, pos: Vector3, yaw: float, center: Vector3, r: float) -> void:
	var a := AmbientAnimal.new()
	add_child(a)
	a.setup(kind, pos, yaw, center, r)

func _fireflies(col: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 10
	p.lifetime = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.6
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
	return p

func build(z: Zone) -> void:
	zone = z
	if z.is_chapter:
		var c3 := Chapter3D.new()
		c3.name = "Chapter3D"
		add_child(c3)
		c3.build(z)
		return
	if z.is_slice:
		build_slice(z)
		return
	look = LOOKS.get(z.biome_id, LOOKS.crypt)
	var floor_w: Dictionary = look.floor
	var total := 0
	for k in floor_w:
		total += int(floor_w[k])
	var ftint: Color = look.tint
	var wtint: Color = look.wall_tint
	var trees: bool = look.walls == "trees"
	for y in Zone.H:
		for x in Zone.W:
			if not z.is_floor_cell(x, y):
				if trees and _near_floor(x, y):
					_tree(x, y, wtint)
				continue
			# floor
			var r := int(_h(x, y) * total)
			var pick := "floor_tile_small"
			for k in floor_w:
				r -= int(floor_w[k])
				if r < 0:
					pick = k
					break
			var rot := float(int(_h(x, y, 5) * 4)) * PI * 0.5
			_add(pick, Transform3D(Basis(Vector3.UP, rot), Vector3(x * 2 + 1, 0, y * 2 + 1)), ftint)
			if trees:
				continue
			# walls along edges that touch solid cells
			_edge_walls(x, y, wtint)
	_props(wtint)
	for b in z.braziers:   # the 2D brazier lights are mirrored by IsoView; give them a body
		var bp: Vector2 = b if b is Vector2 else z.cell_center(b)
		_add("lantern_standing", Transform3D(Basis().scaled(Vector3.ONE * 1.5), IsoView.to3d(bp)))
	_landmark()
	_flush()

func _near_floor(x: int, y: int) -> bool:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if zone.is_floor_cell(x + dx, y + dy):
				return true
	return false

func _tree(x: int, y: int, tint: Color) -> void:
	if _h(x, y, 9) < 0.45:
		return
	var n: String = ["tree_dead_large", "tree_dead_medium", "tree_dead_small"][int(_h(x, y, 3) * 3)]
	var s := 0.8 + _h(x, y, 4) * 0.4
	# trees nearer the camera than the floor next to them stay short so they don't hide the player
	var front := zone.is_floor_cell(x - 1, y) or zone.is_floor_cell(x, y - 1) or zone.is_floor_cell(x - 1, y - 1)
	var sy := s * (0.45 if front else 1.0)
	_add(n, Transform3D(Basis(Vector3.UP, _h(x, y, 6) * TAU).scaled(Vector3(s, sy, s)), Vector3(x * 2 + 1, 0, y * 2 + 1)), tint)

func _edge_walls(x: int, y: int, tint: Color) -> void:
	var back := Vector3(1, WALL_H, 1)
	var front := Vector3(1, FRONT_H, 1)
	var x0 := x * 2.0
	var z0 := y * 2.0
	var n := not zone.is_floor_cell(x, y - 1)
	var s := not zone.is_floor_cell(x, y + 1)
	var w := not zone.is_floor_cell(x - 1, y)
	var e := not zone.is_floor_cell(x + 1, y)
	var rot90 := Basis(Vector3.UP, PI * 0.5)
	if n:
		_add("wall_half", Transform3D(Basis().scaled(back), Vector3(x0, 0, z0 - 0.5)), tint)
		if _h(x, y, 11) < 0.12:
			_torch(Vector3(x0 + 1, 2.1, z0), Basis())
		elif _h(x, y, 12) < 0.08 and zone.biome_id in ["crypt", "castle"]:
			_add("banner_patternA_red", Transform3D(Basis().scaled(Vector3(0.8, 0.7, 0.8)), Vector3(x0 + 1, 0, z0 - 0.4)))
	if s:
		_add("wall_half", Transform3D(Basis().scaled(front), Vector3(x0, 0, z0 + 2.5)), tint)
	if w:
		_add("wall_half", Transform3D(rot90.scaled(back), Vector3(x0 - 0.5, 0, z0 + 2)), tint)
		if _h(x, y, 13) < 0.12:
			_torch(Vector3(x0, 2.1, z0 + 1), rot90)
	if e:
		_add("wall_half", Transform3D(rot90.scaled(front), Vector3(x0 + 2.5, 0, z0 + 2)), tint)
	# outer corners: fill the 1x1 gap where two walls meet
	var corners := [[n and w, Vector3(x0 - 1, 0, z0 - 1), false], [n and e, Vector3(x0 + 2, 0, z0 - 1), true],
		[s and w, Vector3(x0 - 1, 0, z0 + 2), true], [s and e, Vector3(x0 + 2, 0, z0 + 2), true]]
	for c in corners:
		if c[0]:
			var h := FRONT_H if c[2] else WALL_H
			_add("wall_half", Transform3D(Basis().scaled(Vector3(0.5, h, 1)), c[1] + Vector3(0, 0, 0.5)), tint)

func _torch(pos: Vector3, b: Basis) -> void:
	if torches.size() >= 40:
		return
	var mi := MeshInstance3D.new()
	var m: Array = mesh_of(path_for("torch_mounted"))
	mi.mesh = m[0]
	mi.transform = Transform3D(b, pos)
	add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.62, 0.3)
	l.omni_range = 7.0
	l.omni_attenuation = 1.2
	l.light_energy = 1.4
	l.position = pos + b * Vector3(0, 0.6, 0.9)
	add_child(l)
	torches.append(l)
	var fl := CPUParticles3D.new()
	fl.amount = 10
	fl.lifetime = 0.5
	fl.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fl.emission_sphere_radius = 0.06
	fl.direction = Vector3.UP
	fl.spread = 15.0
	fl.initial_velocity_min = 0.6
	fl.initial_velocity_max = 1.1
	fl.gravity = Vector3(0, 0.5, 0)
	fl.scale_amount_min = 0.6
	fl.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.18)
	q.material = IsoView.glow_material(Color(1.0, 0.55, 0.15))
	fl.mesh = q
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 0.9, 0.6, 1))
	grad.set_color(1, Color(1, 0.3, 0.05, 0))
	fl.color_ramp = grad
	fl.position = pos + b * Vector3(0, 0.75, 0.35)
	add_child(fl)

## Scatter props: the zone's own deco list, plus extra crypt dressing near walls.
func _props(wtint: Color) -> void:
	for d in zone._deco:
		var c: Vector2i = d.cell
		var kind: String = d.kind
		if not PROPS.has(kind):
			continue
		var p: Array = PROPS[kind]
		var s: float = p[1]
		var pos := Vector3(c.x * 2 + 1 + (_h(c.x, c.y, 21) - 0.5), 0, c.y * 2 + 1 + (_h(c.x, c.y, 22) - 0.5))
		_add(p[0], Transform3D(Basis(Vector3.UP, _h(c.x, c.y, 23) * TAU).scaled(Vector3.ONE * s), pos), Color(0.9, 0.88, 0.85))
	if zone.biome_id != "crypt":
		return
	# Ashfall Crypt dressing: coffins, candles and bones tucked against the back walls
	for y in Zone.H:
		for x in Zone.W:
			if not zone.is_floor_cell(x, y):
				continue
			var nwall := not zone.is_floor_cell(x, y - 1)
			var wwall := not zone.is_floor_cell(x - 1, y)
			if not (nwall or wwall):
				continue
			var r := _h(x, y, 31)
			var base := Vector3(x * 2 + 1, 0, y * 2 + 1)
			var inward := Vector3(0, 0, -0.45) if nwall else Vector3(-0.45, 0, 0)
			var yaw := 0.0 if nwall else PI * 0.5
			if r < 0.035:
				_add("coffin_decorated", Transform3D(Basis(Vector3.UP, yaw + PI * 0.5).scaled(Vector3.ONE * 0.5), base + inward * 0.9))
			elif r < 0.07:
				_add("skull_candle", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.5), base + inward * 1.2))
				_candle_light(base + inward * 1.2 + Vector3(0, 0.8, 0))
			elif r < 0.12:
				_add(["bone_A", "bone_B", "bone_C", "ribcage"][int(_h(x, y, 32) * 4)], Transform3D(Basis(Vector3.UP, _h(x, y, 33) * TAU).scaled(Vector3.ONE * 0.8), base + inward + Vector3(0, 0.05, 0)))
			elif r < 0.15:
				_add("gravestone", Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3.ONE * 0.6), base + inward * 1.3))

func _candle_light(pos: Vector3) -> void:
	if torches.size() >= 40:
		return
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.4)
	l.omni_range = 3.5
	l.light_energy = 0.9
	l.position = pos
	add_child(l)
	torches.append(l)

## A landmark per region. Ashfall Crypt: a mausoleum looming behind the Regent's arena,
## and a candle shrine where you arrive.
func _landmark() -> void:
	if zone.biome_id != "crypt":
		return
	var b := zone.boss_cell
	var y := b.y
	while y > 0 and zone.is_floor_cell(b.x, y):
		y -= 1
	_add("crypt", Transform3D(Basis().scaled(Vector3.ONE * 0.8), Vector3(b.x * 2 + 1, 0, (y - 2) * 2 + 1)), Color(0.75, 0.72, 0.8))
	var l := OmniLight3D.new()
	l.light_color = Color(0.75, 0.5, 1.0)
	l.omni_range = 9.0
	l.light_energy = 1.6
	l.position = Vector3(b.x * 2 + 1, 3.0, y * 2 + 1)
	add_child(l)
	torches.append(l)
	var s := zone.start_cell
	for dir in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]:
		var c: Vector2i = s + dir * 2
		if zone.is_floor_cell(c.x, c.y) and zone.is_floor_cell(c.x + dir.x, c.y + dir.y) == false:
			_add("shrine_candles", Transform3D(Basis().scaled(Vector3.ONE * 0.9), Vector3(c.x * 2 + 1, 0, c.y * 2 + 1)))
			_candle_light(Vector3(c.x * 2 + 1, 1.6, c.y * 2 + 1))
			break

func _flush() -> void:
	for key in _batches:
		var b: Dictionary = _batches[key]
		if b.mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = b.mesh
		mm.instance_count = b.xforms.size()
		for i in b.xforms.size():
			mm.set_instance_transform(i, b.xforms[i] * b.local)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var t: Color = b.tint
		if t != Color.WHITE:
			var src: Material = (b.mesh as Mesh).surface_get_material(0)
			if src is StandardMaterial3D:
				var m: StandardMaterial3D = src.duplicate()
				m.albedo_color = t
				mmi.material_override = m
		add_child(mmi)
	_batches.clear()

## Torches flicker (presentation randomness is fine here).
func _process(_delta: float) -> void:
	var t := Time.get_ticks_msec() * 0.001
	var c := IsoView.to3d(IsoView.instance.center_world()) if IsoView.instance else Vector3.ZERO
	for i in torches.size():
		var l: OmniLight3D = torches[i]
		l.visible = l.position.distance_squared_to(c) < 26.0 * 26.0   # only nearby torches cost anything
		if not l.visible:
			continue
		var base: float = l.get_meta("base") if l.has_meta("base") else l.light_energy
		if not l.has_meta("base"):
			l.set_meta("base", base)
		l.light_energy = base * (0.85 + 0.15 * sin(t * 9.0 + i * 1.7) + randf_range(-0.05, 0.05))
