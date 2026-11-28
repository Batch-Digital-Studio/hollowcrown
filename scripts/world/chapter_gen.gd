class_name ChapterGen
extends RefCounted
## Builds Chapter 1 into a Zone from ChapterDB: walkable land around a winding route, a river with a
## bridge, swamp lakes, glades, hidden side trails, props (with colliders), monster packs, rares,
## caches and the boss arena. Deterministic from ChapterDB.SEED (simulation data; no global randf).
##
## Output in zone.chapter:
##   region / water / pathm : PackedByteArray per cell (region 0..2, water 0 none 1 shallow 2 deep, path 0..255)
##   props   : [[kind, x_px, y_px, rot_deg, scale, tint_idx]]   drawn by Level3D
##   packs   : [{pos, region, ids:[...], rare:bool, magic:bool}]
##   caches  : [{pos, hidden:true}]
##   glades  : [{pos, r_px, kind, name}]
##   bridges : [{pos, dir}]     (river crossings on the route)
##   arena   : {pos, r_px, gate:[a, b]}
##   waypoints: [pos]
##   route   : PackedVector2Array of the smoothed route (px), route_t per point

var z: Zone
var rng: RandomNumberGenerator
var noise: FastNoiseLite
var noise2: FastNoiseLite
var W := 0
var H := 0
var route: Array = []        # cell-space Vector2 samples
var route_t: Array = []
var grid := PackedByteArray()
var dist := PackedFloat32Array()
var tnear := PackedFloat32Array()
var region := PackedByteArray()
var water := PackedByteArray()
var pathm := PackedByteArray()
var edge := PackedByteArray()    # distance (cells) from walkable land, 0 = walkable, 255 = far
var no_props := PackedByteArray() # glade centres kept clear for dressing
var props: Array = []
var blockers: Array = []
var bridges: Array = []
var branch_ends: Array = []
var shortcuts: Array = []

const STAMP := 24

static func build(zone: Zone) -> void:
	var g := ChapterGen.new()
	g.z = zone
	g.run()

func idx(x: int, y: int) -> int:
	return y * W + x

func inb(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < W and y < H

func run() -> void:
	W = ChapterDB.W
	H = ChapterDB.H
	Zone.W = W
	Zone.H = H
	rng = RandomNumberGenerator.new()
	rng.seed = ChapterDB.SEED
	z.rng = rng
	noise = FastNoiseLite.new()
	noise.seed = ChapterDB.SEED
	noise.frequency = 0.045
	noise2 = FastNoiseLite.new()
	noise2.seed = ChapterDB.SEED + 7
	noise2.frequency = 0.07
	grid.resize(W * H)
	grid.fill(0)
	region.resize(W * H)
	region.fill(0)
	water.resize(W * H)
	water.fill(0)
	pathm.resize(W * H)
	pathm.fill(0)
	no_props.resize(W * H)
	no_props.fill(0)
	dist.resize(W * H)
	dist.fill(999.0)
	tnear.resize(W * H)
	tnear.fill(0.0)
	_route()
	_stamp_route()
	_carve_land()
	_open_areas()
	_glades()
	_branches()
	_river()
	_lakes()
	_shortcuts()
	z.start_cell = Vector2i(ChapterDB.SPINE[0])
	z.grid = grid
	z._keep_reachable()
	grid = z.grid
	_shallows()
	_edges()
	_path_mask()
	_dress_glades()
	_walls()
	_scatter()
	_blockers()
	var herbs := _herbs()
	var packs := _packs()
	var arena := _arena()
	var caches: Array = []
	for b in branch_ends:
		caches.append({"pos": _px(b), "hidden": true})
	var wps: Array = []
	for i in ChapterDB.WAYPOINTS:
		wps.append(_px(_glade_center(i)) + Vector2(70, 40))
	var glades: Array = []
	for gl in ChapterDB.GLADES:
		glades.append({"pos": _px(_glade_center(int(gl.at))), "r_px": float(gl.r) * Zone.CELL, "kind": gl.kind, "name": gl.name, "region": region[idx(int(_glade_center(int(gl.at)).x), int(_glade_center(int(gl.at)).y))]})
	var rpx := PackedVector2Array()
	for p in route:
		rpx.append(_px(p))
	z.boss_cell = Vector2i(_glade_center(ChapterDB.SPINE.size() - 1))
	z.chapter = {
		"region": region, "water": water, "pathm": pathm, "edge": edge,
		"props": props, "blockers": blockers, "packs": packs, "caches": caches, "glades": glades,
		"bridges": bridges, "arena": arena, "waypoints": wps, "route": rpx, "route_t": route_t,
		"herbs": herbs, "shortcuts": shortcuts, "kettle": _px(_glade_center(0) + ChapterDB.KETTLE_OFFSET),
	}

func _px(c: Vector2) -> Vector2:
	return (c + Vector2(0.5, 0.5)) * Zone.CELL

# ------------------------------------------------------------------ route

static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)

static func smooth(pts: Array, step: float) -> Array:
	var out: Array = []
	for i in pts.size() - 1:
		var p0: Vector2 = pts[maxi(0, i - 1)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(pts.size() - 1, i + 2)]
		var n := maxi(2, int(p1.distance_to(p2) / step))
		for k in n:
			out.append(_catmull(p0, p1, p2, p3, float(k) / n))
	out.append(pts[pts.size() - 1])
	return out

func _route() -> void:
	route = smooth(ChapterDB.SPINE, 0.8)
	var total := 0.0
	var acc: Array = [0.0]
	for i in range(1, route.size()):
		total += route[i].distance_to(route[i - 1])
		acc.append(total)
	route_t.clear()
	for a in acc:
		route_t.append(a / total)

func _route_at(t: float) -> int:
	for i in route_t.size():
		if route_t[i] >= t:
			return i
	return route.size() - 1

func _glade_center(spine_i: int) -> Vector2:
	return ChapterDB.SPINE[spine_i]

func _stamp_route() -> void:
	for i in route.size():
		var p: Vector2 = route[i]
		var t: float = route_t[i]
		for y in range(int(p.y) - STAMP, int(p.y) + STAMP + 1):
			for x in range(int(p.x) - STAMP, int(p.x) + STAMP + 1):
				if not inb(x, y):
					continue
				var d := p.distance_to(Vector2(x, y))
				var k := idx(x, y)
				if d < dist[k]:
					dist[k] = d
					tnear[k] = t
	for k in W * H:
		region[k] = ChapterDB.region_of_t(tnear[k])

func _half_width(x: int, y: int) -> float:
	var r: Dictionary = ChapterDB.REGIONS[region[idx(x, y)]]
	var hw: Array = r.half_width
	var n := (noise.get_noise_2d(x, y) + 1.0) * 0.5
	return lerpf(hw[0], hw[1], n)

func _carve_land() -> void:
	for y in H:
		for x in W:
			var k := idx(x, y)
			var edge_n := noise2.get_noise_2d(x * 2.0, y * 2.0) * 1.6
			if dist[k] < _half_width(x, y) + edge_n and x > 2 and y > 2 and x < W - 3 and y < H - 3:
				grid[k] = 1

func _disc(c: Vector2, r: float, rough: float = 1.4) -> void:
	for y in range(int(c.y - r - 3), int(c.y + r + 4)):
		for x in range(int(c.x - r - 3), int(c.x + r + 4)):
			if not inb(x, y) or x < 3 or y < 3 or x > W - 4 or y > H - 4:
				continue
			var d := c.distance_to(Vector2(x, y))
			if d < r + noise2.get_noise_2d(x * 3.0, y * 3.0) * rough:
				grid[idx(x, y)] = 1

func _open_areas() -> void:
	for oa in ChapterDB.OPEN_AREAS:
		var c := _glade_center(int(oa[0]))
		var r: float = float(oa[1])
		_disc(c, r * 0.75, 2.0)
		for k in 3:   # lobes make it irregular, not a circle
			var a := rng.randf() * TAU
			_disc(c + Vector2(cos(a), sin(a)) * r * 0.45, r * rng.randf_range(0.45, 0.6), 2.0)

func _glades() -> void:
	for gl in ChapterDB.GLADES:
		var c := _glade_center(int(gl.at))
		_disc(c, float(gl.r), 0.4 if gl.kind == "arena" else 1.6)
		var keep := float(gl.r) * (0.55 if gl.kind != "arena" else 0.95)
		for y in range(int(c.y - keep), int(c.y + keep + 1)):
			for x in range(int(c.x - keep), int(c.x + keep + 1)):
				if inb(x, y) and c.distance_to(Vector2(x, y)) <= keep:
					no_props[idx(x, y)] = 1

func _branches() -> void:
	for b in ChapterDB.BRANCHES:
		var i := _route_at(float(b[0]))
		var p: Vector2 = route[i]
		var fwd: Vector2 = (route[mini(i + 2, route.size() - 1)] - route[maxi(i - 2, 0)]).normalized()
		var side := fwd.orthogonal() * float(b[1])
		var dir := side.rotated(rng.randf_range(-0.35, 0.35))
		var cur := p
		var length := float(b[2])
		var pts: Array = []
		var step := 0.0
		while step < length:
			cur += dir
			dir = dir.rotated(rng.randf_range(-0.22, 0.22)).lerp(side, 0.08).normalized()
			step += 1.0
			pts.append(cur)
		var end: Vector2 = pts[pts.size() - 1]
		if not inb(int(end.x), int(end.y)) or end.x < 8 or end.y < 8 or end.x > W - 9 or end.y > H - 9:
			continue
		var too_close := false
		for q in route:
			if (q as Vector2).distance_to(end) < 14.0:
				too_close = true
				break
		if too_close:
			continue
		for q in pts:
			_disc(q, 2.2, 0.6)
		_disc(end, 4.5, 1.0)
		branch_ends.append(end)
		for y in range(int(end.y) - 2, int(end.y) + 3):
			for x in range(int(end.x) - 2, int(end.x) + 3):
				if inb(x, y):
					no_props[idx(x, y)] = 1

func _river() -> void:
	var rv := smooth(ChapterDB.RIVER, 0.5)
	for p in rv:
		var hw: float = ChapterDB.RIVER_HALF + noise.get_noise_2d(p.x * 3.0, p.y * 3.0) * 0.8
		for y in range(int(p.y - hw - 1), int(p.y + hw + 2)):
			for x in range(int(p.x - hw - 1), int(p.x + hw + 2)):
				if inb(x, y) and p.distance_to(Vector2(x, y)) <= hw:
					water[idx(x, y)] = 2
	# Bridges: where the route crosses deep water, keep a strip walkable.
	var crossing := false
	var start := Vector2.ZERO
	for i in route.size():
		var c: Vector2 = route[i]
		var wet := water[idx(int(round(c.x)), int(round(c.y)))] == 2
		if wet and not crossing:
			crossing = true
			start = c
		elif not wet and crossing:
			crossing = false
			var dirc := (c - start).normalized()
			var a := start - dirc * 1.5
			var b := c + dirc * 1.5
			# the deck covers the whole wet span plus the banks, so it never ends in the water
			bridges.append({"a": _px(start - dirc * 3.5), "b": _px(c + dirc * 3.5)})
			for k in 12:
				var q := a.lerp(b, k / 11.0)
				for y in range(int(q.y) - 2, int(q.y) + 3):
					for x in range(int(q.x) - 2, int(q.x) + 3):
						if inb(x, y) and q.distance_to(Vector2(x, y)) <= 1.1:
							water[idx(x, y)] = 3   # bridge deck: walkable over water
	for k in W * H:
		if water[k] == 2:
			grid[k] = 0
		elif water[k] == 3:
			grid[k] = 1
			water[k] = 2

func _lakes() -> void:
	var lake := FastNoiseLite.new()
	lake.seed = ChapterDB.SEED + 31
	lake.frequency = 0.06
	for y in H:
		for x in W:
			var k := idx(x, y)
			if region[k] != 1 or grid[k] == 0 or dist[k] < 3.2 or no_props[k] == 1:
				continue
			if lake.get_noise_2d(x, y) > 0.22:
				water[k] = 2
				grid[k] = 0
	# Stillwater: a round lake in its glade with a ring of land
	for gl in ChapterDB.GLADES:
		if gl.kind == "lake":
			var c := _glade_center(int(gl.at)) + Vector2(4, -3)
			for y in range(int(c.y) - 7, int(c.y) + 8):
				for x in range(int(c.x) - 7, int(c.x) + 8):
					if inb(x, y) and c.distance_to(Vector2(x, y)) < 5.5 + noise2.get_noise_2d(x * 3.0, y * 3.0):
						water[idx(x, y)] = 2
						grid[idx(x, y)] = 0

func _shallows() -> void:
	var out := water.duplicate()
	for y in H:
		for x in W:
			var k := idx(x, y)
			if grid[k] != 1 or water[k] == 2:
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					if inb(x + dx, y + dy) and water[idx(x + dx, y + dy)] == 2 and grid[idx(x + dx, y + dy)] == 0:
						out[k] = 1
	# deep water that is not under any walkable neighbour region still renders; fine
	water = out

## BFS distance from walkable land (0 on land).
func _edges() -> void:
	edge.resize(W * H)
	edge.fill(255)
	var q: Array = []
	for k in W * H:
		if grid[k] == 1:
			edge[k] = 0
			q.append(k)
	var head := 0
	while head < q.size():
		var k: int = q[head]
		head += 1
		var e := edge[k]
		if e >= 12:
			continue
		var x := k % W
		var y := k / W
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if inb(nx, ny) and edge[idx(nx, ny)] == 255:
				edge[idx(nx, ny)] = e + 1
				q.append(idx(nx, ny))

func _path_mask() -> void:
	for k in W * H:
		var d := dist[k]
		if d < 2.4:
			pathm[k] = int(clampf((2.4 - d) / 1.4, 0.0, 1.0) * 255.0)

# ------------------------------------------------------------------ props

func _pick(list: Array) -> String:
	var total := 0
	for e in list:
		total += int(e[1])
	var r := rng.randi() % total
	for e in list:
		r -= int(e[1])
		if r < 0:
			return String(e[0])
	return String(list[0][0])

func _prop(kind: String, c: Vector2, scale: float = 1.0, rot: float = -1.0, block: float = 0.0) -> void:
	var p := _px(c)
	props.append([kind, p.x, p.y, rng.randf() * 360.0 if rot < 0.0 else rot, scale])
	if block > 0.0:
		blockers.append([p.x, p.y, block * scale * 32.0])

## Camera looks from the south-east: a tree with open ground to its north-west would hide the fight.
func _camera_side(x: int, y: int) -> bool:
	for k in range(1, 6):
		if inb(x - k, y - k) and grid[idx(x - k, y - k)] == 1:
			return true
	return false

func _walls() -> void:
	for y in H:
		for x in W:
			var k := idx(x, y)
			var e := edge[k]
			if e == 0 or e > 9 or water[k] == 2:
				continue
			var reg: Dictionary = ChapterDB.REGIONS[region[k]]
			var chance := 0.55 if e <= 2 else (0.42 if e <= 5 else 0.3)
			if rng.randf() > chance:
				continue
			var c := Vector2(x, y) + Vector2(rng.randf_range(-0.4, 0.4), rng.randf_range(-0.4, 0.4))
			if _camera_side(x, y) and e <= 4:
				_prop(_pick(reg.wall_low), c, rng.randf_range(0.8, 1.2))
			else:
				_prop(_pick(reg.wall), c, rng.randf_range(0.85, 1.2))

func _scatter() -> void:
	for y in H:
		for x in W:
			var k := idx(x, y)
			if grid[k] != 1 or no_props[k] == 1 or water[k] == 2:
				continue
			var reg: Dictionary = ChapterDB.REGIONS[region[k]]
			var n := 2 if dist[k] > 2.0 else (1 if rng.randf() < 0.3 else 0)
			if water[k] == 1:
				n = 1
			for i in n:
				var c := Vector2(x, y) + Vector2(rng.randf_range(-0.5, 0.5), rng.randf_range(-0.5, 0.5))
				var kind := _pick(reg.scatter)
				if water[k] == 1:
					kind = "reeds_1" if rng.randf() < 0.6 else "lily_pads"
				_prop(kind, c, rng.randf_range(1.1, 1.8) if kind.begins_with("grass") else rng.randf_range(0.8, 1.3))

func _blockers() -> void:
	for y in H:
		for x in W:
			var k := idx(x, y)
			if grid[k] != 1 or no_props[k] == 1 or water[k] != 0 or dist[k] < 3.0:
				continue
			if rng.randf() > 0.028:
				continue
			var reg: Dictionary = ChapterDB.REGIONS[region[k]]
			var tot := 0
			for b in reg.blockers:
				tot += int(b[1])
			var r := rng.randi() % tot
			for b in reg.blockers:
				r -= int(b[1])
				if r < 0:
					var kind := String(b[0])
					var sc := rng.randf_range(0.85, 1.2)
					var c := Vector2(x, y) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3))
					_prop(kind, c, sc, -1.0, float(b[2]))
					if kind == "log_1":
						var p := _px(c)
						var rot := deg_to_rad(float(props[props.size() - 1][3]))
						for o in [-1.4, 0.0, 1.4]:
							blockers.append([p.x + cos(rot) * o * 32.0, p.y - sin(rot) * o * 32.0, 0.45 * 32.0])
					break

func _ring(kind: String, c: Vector2, r: float, n: int, block: float, sc: float = 1.0, face_in: bool = false) -> void:
	for i in n:
		var a := TAU * i / n + 0.2
		var p := c + Vector2(cos(a), sin(a)) * r
		var rot := -1.0
		if face_in:
			rot = rad_to_deg(-a) - 90.0
		_prop(kind, p, sc * rng.randf_range(0.92, 1.08), rot, block)

func _dress_glades() -> void:
	for gl in ChapterDB.GLADES:
		var c := _glade_center(int(gl.at))
		match String(gl.kind):
			"camp":
				_prop("campfire", c + Vector2(1, -1), 1.0)
				_prop("tent", c + Vector2(-3, -4), 1.0, 30.0, 1.2)
				_prop("barrel_large", c + Vector2(3.5, -3.0), 1.0, -1.0, 0.4)
				_prop("crates_stacked", c + Vector2(4.5, -1.5), 0.9, 15.0, 0.6)
				_prop("banner_red", c + Vector2(-5, 0), 1.0, 90.0)
				_prop("log_1", c + Vector2(-0.5, 2.2), 0.7, 10.0)
			"oak":
				_prop("hollow_oak", c + Vector2(0, -3), 1.25, 200.0, 1.6)
				_ring("standing_stone", c + Vector2(0, -3), 7.0, 6, 0.5, 1.1)
				_prop("mushroom_ember", c + Vector2(3, 1), 1.3)
				_prop("mushroom_ember", c + Vector2(-4, -1), 1.2)
			"stones":
				_ring("standing_stone", c, 5.5, 8, 0.5, 1.3)
				_prop("rock_2", c, 0.8, -1.0, 0.9)
			"shrine":
				_ring("pillar_ruin", c, 5.0, 6, 0.55, 1.1)
				_prop("shrine_candles", c + Vector2(0, -1), 1.4, 180.0, 0.6)
				for i in 5:
					_prop("lily_pads", c + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6)), 1.2)
			"lake":
				_prop("swamp_snag", c + Vector2(-6, 4), 1.2, -1.0, 0.6)
			"ruins":
				_prop("tower_ruin", c + Vector2(-2, -3), 1.0, 20.0, 2.0)
				_ring("pillar_ruin", c + Vector2(1, 1), 6.0, 5, 0.55)
				_prop("rubble_large", c + Vector2(4, 2), 1.0, -1.0, 0.8)
				_prop("rubble_half", c + Vector2(-5, 3), 1.0)
			"graves":
				for gy in range(-2, 3):
					for gx in range(-3, 4):
						if (gx + gy) % 2 == 0 and absi(gx) + absi(gy) > 1:
							_prop("gravestone" if (gx * 7 + gy) % 3 else "grave_A", c + Vector2(gx * 2.4, gy * 2.2), 1.0, 180.0, 0.45)
				_prop("crypt", c + Vector2(0, -8), 1.0, 180.0, 2.6)
			"arena":
				pass   # dressed by _arena

func _arena() -> Dictionary:
	var gl: Dictionary = ChapterDB.GLADES[ChapterDB.GLADES.size() - 1]
	var c := _glade_center(int(gl.at))
	var r := float(gl.r)
	# ring of great pillars and braziers; throne at the far (north) side
	_ring("pillar_great", c, r - 1.2, 10, 0.75, 1.0)
	_prop("throne", c + Vector2(0, -r + 3.5), 1.0, 0.0, 1.4)
	for s in [-1, 1]:
		_prop("brazier", c + Vector2(s * 4.5, -r + 4.5), 1.0, 0.0, 0.5)
	# entrance: where the route comes in
	var ent := Vector2.ZERO
	for i in range(route.size() - 1, 0, -1):
		if (route[i] as Vector2).distance_to(c) > r + 0.5:
			ent = route[i]
			break
	var dir := (ent - c).normalized()
	var gate_mid := c + dir * (r + 0.5)
	var side := dir.orthogonal()
	return {"pos": _px(c), "r_px": r * Zone.CELL, "gate_a": _px(gate_mid + side * 6.0), "gate_b": _px(gate_mid - side * 6.0), "gate_mid": _px(gate_mid), "dir": dir}

# ------------------------------------------------------------------ shortcuts and herbs

func _shortcuts() -> void:
	for sc in ChapterDB.SHORTCUTS:
		var a: Vector2 = _nearest_land(sc.a, sc.b)
		var b: Vector2 = _nearest_land(sc.b, sc.a)
		var n := int(a.distance_to(b))
		for i in n + 1:
			var q := a.lerp(b, float(i) / n)
			for y in range(int(q.y) - 2, int(q.y) + 3):
				for x in range(int(q.x) - 2, int(q.x) + 3):
					if inb(x, y) and q.distance_to(Vector2(x, y)) <= 1.9:
						grid[idx(x, y)] = 1
						no_props[idx(x, y)] = 1
		# a small landing at each end
		_disc(a, 2.5, 0.3)
		_disc(b, 2.5, 0.3)
		var mid := (a + b) * 0.5
		var dir := (b - a).normalized()
		# the obstacle sits where the way crosses water (drawbridge, log), else in the middle (gate)
		if sc.kind != "gate":
			var wet: Array = []
			for i in n + 1:
				var q := a.lerp(b, float(i) / n)
				if water[idx(int(q.x), int(q.y))] == 2:
					wet.append(q)
			if not wet.is_empty():
				mid = (wet[0] + wet[wet.size() - 1]) * 0.5
		var span := 6.0
		if sc.kind != "gate":
			var wet_n := 0
			for i in n + 1:
				var q := a.lerp(b, float(i) / n)
				if water[idx(int(q.x), int(q.y))] == 2:
					wet_n += 1
			span = maxf(6.0, wet_n + 3.0)
		var lever_at: Vector2 = (a if sc.lever == "a" else b)
		lever_at += dir.orthogonal() * 2.0 + (dir if sc.lever == "a" else -dir) * 1.0
		shortcuts.append({"kind": sc.kind, "name": sc.name, "a": _px(a), "b": _px(b), "mid": _px(mid), "dir": dir,
			"span_px": span * Zone.CELL, "lever": _px(lever_at), "lever_side": sc.lever})

## The walkable cell nearest to p (searching outward), preferring the side away from `other`.
func _nearest_land(p: Vector2, other: Vector2) -> Vector2:
	for r in range(0, 26):
		var best := Vector2(-1, -1)
		var bd := 1e9
		for y in range(int(p.y) - r, int(p.y) + r + 1):
			for x in range(int(p.x) - r, int(p.x) + r + 1):
				if inb(x, y) and grid[idx(x, y)] == 1 and water[idx(x, y)] != 2:
					var d := Vector2(x, y).distance_to(p) + Vector2(x, y).distance_to(other) * 0.1
					if d < bd:
						bd = d
						best = Vector2(x, y)
		if best.x >= 0:
			return best
	return p

func _herbs() -> Array:
	var out: Array = []
	var taken := {}
	for hid in BrewingDB.HERBS:
		var reg: int = BrewingDB.HERBS[hid].region
		var placed := 0
		var tries := 0
		while placed < BrewingDB.HERBS_PER_REGION and tries < 4000:
			tries += 1
			var x := rng.randi_range(4, W - 5)
			var y := rng.randi_range(4, H - 5)
			var k := idx(x, y)
			if grid[k] != 1 or region[k] != reg or water[k] == 2 or no_props[k] == 1:
				continue
			if dist[k] < 3.0 or edge_near(x, y) > 3:
				continue
			# bogbloom likes the water's edge
			if hid == "bogbloom" and water[k] != 1 and rng.randf() < 0.7:
				continue
			var key := Vector2i(x / 4, y / 4)
			if taken.has(key):
				continue
			taken[key] = true
			out.append({"id": hid, "pos": _px(Vector2(x, y) + Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)))})
			placed += 1
	# a guaranteed patch near the camp so the trade is found early
	var camp := _glade_center(0)
	for i in 3:
		out.append({"id": "emberhood", "pos": _px(camp + Vector2(-7 + i * 1.6, -5 - (i % 2)))})
	return out

## Distance in cells to the nearest non-walkable cell (small radius); herbs like the edges of clearings.
func edge_near(x: int, y: int) -> int:
	for r in range(1, 9):
		for d in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
			if not inb(x + d.x, y + d.y) or grid[idx(x + d.x, y + d.y)] == 0:
				return r
	return 9

# ------------------------------------------------------------------ monsters

func _packs() -> Array:
	var out: Array = []
	var since := 0.0
	var n_pack := 0
	var end_t := ChapterDB.REGION_END[2] - 0.05
	for i in range(1, route.size()):
		since += (route[i] as Vector2).distance_to(route[i - 1])
		var t: float = route_t[i]
		if t < 0.05 or t > end_t:
			continue
		if since < ChapterDB.PACK_SPACING:
			continue
		since = rng.randf_range(-4.0, 2.0)
		var fwd: Vector2 = (route[mini(i + 2, route.size() - 1)] - route[maxi(i - 2, 0)]).normalized()
		var off := fwd.orthogonal() * rng.randf_range(-4.0, 4.0)
		var c: Vector2 = route[i] + off
		if not z.is_floor_cell(int(c.x), int(c.y)):
			c = route[i]
		n_pack += 1
		out.append(_pack_at(c, ChapterDB.region_of_t(t), n_pack % ChapterDB.RARE_EVERY == 0))
	# glades (not camp, not arena) get a bigger pack; side caches: a guard half the time
	for gl in ChapterDB.GLADES:
		if gl.kind in ["camp", "arena"]:
			continue
		var c := _glade_center(int(gl.at)) + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))
		var pk := _pack_at(c, region[idx(int(c.x), int(c.y))], true)
		pk.big = true
		out.append(pk)
	for b in branch_ends:
		if rng.randf() < 0.55:
			out.append(_pack_at(b + Vector2(0, 1.5), region[idx(int(b.x), int(b.y))], true))
	return out

func _pack_at(c: Vector2, reg: int, rare: bool) -> Dictionary:
	var R: Dictionary = ChapterDB.REGIONS[reg]
	var id := _pick(R.monsters)
	var n := rng.randi_range(3, 5)
	if id in ["thornling", "marsh_wisp", "barrow_hexer"]:
		n = rng.randi_range(2, 3)
	elif id == "dusk_wolf":
		n = rng.randi_range(4, 6)
	var ids: Array = []
	for k in n:
		ids.append(id if rng.randf() < 0.75 else _pick(R.monsters))
	return {"pos": _px(c), "region": reg, "ids": ids, "rare": rare, "magic": not rare and rng.randf() < 0.45, "big": false}
