class_name Zone
extends Node2D
## Generated zone: winding paths, side caves, rooms and a boss arena at the far end.

const CELL := 64
static var W := 90
static var H := 70

var grid := PackedByteArray()   # 1 = floor, 0 = solid
var start_cell := Vector2i.ZERO
var boss_cell := Vector2i.ZERO
var floor_cells: Array = []
var rng: RandomNumberGenerator
var theme_floor := Color(0.13, 0.12, 0.13)
var theme_wall := Color(0.07, 0.065, 0.075)
var theme_accent := Color(1.0, 0.5, 0.2)
var _deco: Array = []
var wall_decor := {}
var braziers: Array = []
var chest_cells: Array = []
var theme_tint := Color.WHITE

var biome_id := "crypt"
var biome: Dictionary = {}
var is_town := false
var is_slice := false
var is_chapter := false
var chapter: Dictionary = {}   # ChapterGen output (region/water/props/packs/...)
var slice: Dictionary = {}
const SLICE_CENTER := Vector2(45 * 64, 35 * 64)   # px; the layout's (0, 0)
var town_spots := {}   # town: name -> cell (stash, salvager, peddler, waypoint, portal)

func generate(seed_value: int, depth: int, biome_override: String = "") -> void:
	W = 90
	H = 70
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	grid.resize(W * H)
	grid.fill(0)
	biome_id = biome_override if biome_override != "" else String(WorldDB.region_for_depth(depth).biome)
	biome = WorldDB.BIOMES[biome_id]
	is_town = biome_id == "town"
	theme_tint = biome.get("tint", Color.WHITE)
	theme_accent = biome.accent
	match String(biome.layout):
		"open": _gen_open()
		"caves": _gen_caves()
		"rooms": _gen_rooms()
		"town": _gen_town()
		_: _gen_path()
	# Frame
	for x in W:
		_setc(x, 0, 0); _setc(x, 1, 0); _setc(x, H - 1, 0); _setc(x, H - 2, 0)
	for y in H:
		_setc(0, y, 0); _setc(1, y, 0); _setc(W - 1, y, 0); _setc(W - 2, y, 0)
	_keep_reachable()
	floor_cells.clear()
	for y in H:
		for x in W:
			if is_floor_cell(x, y):
				floor_cells.append(Vector2i(x, y))
	_build_collision()
	_place_deco()
	if is_town:
		braziers.clear()
		chest_cells.clear()
	_build_chunks()
	queue_redraw()

## Playtest slice: the fixed Whisperwood Clearing shared with the Unreal test (metres -> px: x * 32).
static func slice_px(x: float, z: float) -> Vector2:
	return SLICE_CENTER + Vector2(x, z) * 32.0

func generate_slice(layout: Dictionary) -> void:
	W = 90
	H = 70
	is_slice = true
	slice = layout
	rng = RandomNumberGenerator.new()
	rng.seed = 1127
	grid.resize(W * H)
	grid.fill(0)
	biome_id = "forest"
	biome = WorldDB.BIOMES[biome_id]
	is_town = false
	theme_tint = Color.WHITE
	theme_accent = biome.accent
	var r_px: float = float(layout.walk_radius_m) * 32.0 + 40.0
	for y in H:
		for x in W:
			if cell_center(Vector2i(x, y)).distance_to(SLICE_CENTER) < r_px:
				_setc(x, y, 1)
	var ps: Array = layout.player_start
	start_cell = Vector2i(slice_px(ps[0], ps[1]) / CELL)
	var lm: Dictionary = layout.landmark
	boss_cell = Vector2i(slice_px(lm.x, lm.z) / CELL)
	floor_cells.clear()
	for y in H:
		for x in W:
			if is_floor_cell(x, y):
				floor_cells.append(Vector2i(x, y))
	_build_collision()
	var body := StaticBody2D.new()   # trees, rocks, logs, stones: round colliders
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for b in layout.blockers:
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = float(b[2]) * 32.0
		cs.shape = c
		cs.position = slice_px(b[0], b[1])
		body.add_child(cs)
	_deco.clear()
	braziers.clear()
	chest_cells.clear()
	_build_chunks()
	queue_redraw()

## Chapter 1: one large open map (ChapterDB / ChapterGen).
func generate_chapter() -> void:
	is_chapter = true
	is_town = false
	biome_id = "forest"
	biome = WorldDB.BIOMES[biome_id]
	theme_tint = Color.WHITE
	theme_accent = biome.accent
	ChapterGen.build(self)
	floor_cells.clear()
	for y in H:
		for x in W:
			if is_floor_cell(x, y):
				floor_cells.append(Vector2i(x, y))
	_build_collision()
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for b in chapter.blockers:
		var cs := CollisionShape2D.new()
		var c := CircleShape2D.new()
		c.radius = float(b[2])
		cs.shape = c
		cs.position = Vector2(float(b[0]), float(b[1]))
		body.add_child(cs)
	_deco.clear()
	braziers.clear()
	chest_cells.clear()
	_build_chunks()
	queue_redraw()

## Chapter: region index (0 forest, 1 swamp, 2 barrow) at a world position.
func region_at(pos: Vector2) -> int:
	if not is_chapter:
		return 0
	var x := clampi(int(pos.x / CELL), 0, W - 1)
	var y := clampi(int(pos.y / CELL), 0, H - 1)
	return chapter.region[y * W + x]

# ---------------------------------------------------------------- layouts

## Winding corridor west -> east with rooms and side caves (the original crypt).
func _gen_path() -> void:
	start_cell = Vector2i(6, H / 2 + rng.randi_range(-10, 10))
	boss_cell = Vector2i(W - 12, H / 2 + rng.randi_range(-12, 12))
	var path := _walk(start_cell, boss_cell, 2)
	for i in 7:
		var c: Vector2i = path[rng.randi_range(int(path.size() * 0.1), int(path.size() * 0.85))]
		_carve_circle(c, rng.randi_range(3, 5))
	for i in 9:
		var c: Vector2i = path[rng.randi_range(0, path.size() - 1)]
		var target := Vector2i(clampi(c.x + rng.randi_range(-18, 18), 3, W - 4), clampi(c.y + rng.randi_range(-20, 20), 3, H - 4))
		var side := _walk(c, target, 1)
		_carve_circle(side[side.size() - 1], rng.randi_range(2, 4))
	_carve_circle(start_cell, 3)
	_carve_circle(boss_cell, 8)

## Forest / swamp: wide clearings joined by broad trails, with tree clumps or pools inside.
func _gen_open() -> void:
	start_cell = Vector2i(7, H / 2 + rng.randi_range(-12, 12))
	boss_cell = Vector2i(W - 13, H / 2 + rng.randi_range(-14, 14))
	var path := _walk(start_cell, boss_cell, 3)
	for i in 11:
		var c: Vector2i = path[rng.randi_range(0, path.size() - 1)]
		var off := Vector2i(rng.randi_range(-10, 10), rng.randi_range(-12, 12))
		var cc := Vector2i(clampi(c.x + off.x, 8, W - 9), clampi(c.y + off.y, 8, H - 9))
		_walk(c, cc, 2)
		_carve_circle(cc, rng.randi_range(5, 8))
	for i in 5:
		var c: Vector2i = path[rng.randi_range(0, path.size() - 1)]
		_carve_circle(c, rng.randi_range(4, 6))
	# clumps inside the clearings (trees / pools), never on the main trail
	var on_path := {}
	for c in path:
		for oy in range(-2, 3):
			for ox in range(-2, 3):
				on_path[c + Vector2i(ox, oy)] = true
	for i in 220:
		var c := Vector2i(rng.randi_range(4, W - 5), rng.randi_range(4, H - 5))
		if not is_floor_cell(c.x, c.y) or on_path.has(c) or Vector2(c - start_cell).length() < 6 or Vector2(c - boss_cell).length() < 11:
			continue
		var rr := rng.randi_range(0, 2)
		for oy in range(-rr, rr + 1):
			for ox in range(-rr, rr + 1):
				if not on_path.has(c + Vector2i(ox, oy)) and rng.randf() < 0.85:
					_setc(c.x + ox, c.y + oy, 0)
	_carve_circle(start_cell, 4)
	_carve_circle(boss_cell, 9)

## Caverns: cellular automata, then a guaranteed passage start -> boss.
func _gen_caves() -> void:
	for y in range(2, H - 2):
		for x in range(2, W - 2):
			_setc(x, y, 1 if rng.randf() < 0.53 else 0)
	for it in 5:
		var nxt := grid.duplicate()
		for y in range(2, H - 2):
			for x in range(2, W - 2):
				var walls := 0
				for oy in range(-1, 2):
					for ox in range(-1, 2):
						if not is_floor_cell(x + ox, y + oy):
							walls += 1
				nxt[y * W + x] = 0 if walls >= 5 else 1
		grid = nxt
	start_cell = Vector2i(7, H / 2 + rng.randi_range(-12, 12))
	boss_cell = Vector2i(W - 13, H / 2 + rng.randi_range(-14, 14))
	_walk(start_cell, boss_cell, 1)
	for i in 4:
		var mid := Vector2i(rng.randi_range(15, W - 16), rng.randi_range(10, H - 11))
		_walk(start_cell if i % 2 == 0 else boss_cell, mid, 1)
	_carve_circle(start_cell, 4)
	_carve_circle(boss_cell, 9)

## Castle: halls and chambers joined by corridors, a throne room for the boss.
func _gen_rooms() -> void:
	var rooms: Array = []
	start_cell = Vector2i(7, H / 2 + rng.randi_range(-10, 10))
	boss_cell = Vector2i(W - 13, H / 2 + rng.randi_range(-12, 12))
	rooms.append(Rect2i(start_cell - Vector2i(4, 3), Vector2i(9, 7)))
	for t in 300:
		if rooms.size() >= 16:
			break
		var w := rng.randi_range(7, 14)
		var h := rng.randi_range(6, 10)
		var r := Rect2i(rng.randi_range(4, W - w - 18), rng.randi_range(4, H - h - 4), w, h)
		var ok := true
		for o in rooms:
			if r.grow(2).intersects(o):
				ok = false
				break
		if ok:
			rooms.append(r)
	rooms.append(Rect2i(boss_cell - Vector2i(9, 9), Vector2i(19, 19)))
	rooms.sort_custom(func(a, b): return a.position.x < b.position.x)
	for r in rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				_setc(x, y, 1)
	for i in rooms.size() - 1:
		var a: Vector2i = rooms[i].get_center()
		var b: Vector2i = rooms[i + 1].get_center()
		if i + 2 < rooms.size() and rng.randf() < 0.35:
			_corridor(a, Vector2i(rooms[i + 2].get_center()))
		_corridor(a, b)

func _corridor(a: Vector2i, b: Vector2i) -> void:
	var x := a.x
	var y := a.y
	while x != b.x:
		_setc(x, y, 1); _setc(x, y + 1, 1)
		x += signi(b.x - x)
	while y != b.y:
		_setc(x, y, 1); _setc(x + 1, y, 1)
		y += signi(b.y - y)

## Emberhold: a walled square with the town's services around it.
func _gen_town() -> void:
	var r := Rect2i(26, 26, 21, 15)
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_setc(x, y, 1)
	start_cell = Vector2i(36, 34)
	boss_cell = Vector2i(36, 28)
	town_spots = {"stash": Vector2i(30, 29), "salvager": Vector2i(42, 29), "peddler": Vector2i(30, 37),
		"waypoint": Vector2i(42, 37), "portal": Vector2i(36, 28), "fountain": Vector2i(36, 32)}

## Anything not reachable from the start becomes rock (no sealed pockets).
func _keep_reachable() -> void:
	if not is_floor_cell(start_cell.x, start_cell.y):
		_carve_circle(start_cell, 3)
	var seen := PackedByteArray()
	seen.resize(W * H)
	var stack: Array = [start_cell]
	seen[start_cell.y * W + start_cell.x] = 1
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= W or n.y >= H:
				continue
			if seen[n.y * W + n.x] == 0 and is_floor_cell(n.x, n.y):
				seen[n.y * W + n.x] = 1
				stack.append(n)
	for i in W * H:
		if seen[i] == 0:
			grid[i] = 0

func _walk(from: Vector2i, to: Vector2i, brush: int) -> Array:
	var out: Array = []
	var p := from
	var guard := 0
	while p != to and guard < 4000:
		guard += 1
		out.append(p)
		_carve_circle(p, brush)
		var d := to - p
		var step := Vector2i.ZERO
		if rng.randf() < 0.62:
			if absi(d.x) > absi(d.y) or (absi(d.x) == absi(d.y) and rng.randf() < 0.5):
				step.x = signi(d.x)
			else:
				step.y = signi(d.y)
		else:
			var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
			step = dirs[rng.randi() % 4]
		p = Vector2i(clampi(p.x + step.x, 3, W - 4), clampi(p.y + step.y, 3, H - 4))
	out.append(to)
	return out

func _carve_circle(c: Vector2i, r: int) -> void:
	for y in range(c.y - r, c.y + r + 1):
		for x in range(c.x - r, c.x + r + 1):
			if Vector2(x - c.x, y - c.y).length() <= r + 0.35:
				_setc(x, y, 1)

func _setc(x: int, y: int, v: int) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		grid[y * W + x] = v

func is_floor_cell(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= W or y >= H:
		return false
	return grid[y * W + x] == 1

func is_wall_at(pos: Vector2) -> bool:
	return not is_floor_cell(int(floor(pos.x / CELL)), int(floor(pos.y / CELL)))

func cell_center(c: Vector2i) -> Vector2:
	return Vector2((c.x + 0.5) * CELL, (c.y + 0.5) * CELL)

func _is_edge_wall(x: int, y: int) -> bool:
	if is_floor_cell(x, y):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if is_floor_cell(x + dx, y + dy):
				return true
	return false

func _build_collision() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for y in H:
		var x := 0
		while x < W:
			if _is_edge_wall(x, y):
				var x0 := x
				while x < W and _is_edge_wall(x, y):
					x += 1
				var cs := CollisionShape2D.new()
				var r := RectangleShape2D.new()
				r.size = Vector2((x - x0) * CELL, CELL)
				cs.shape = r
				cs.position = Vector2((x0 + (x - x0) / 2.0) * CELL, (y + 0.5) * CELL)
				body.add_child(cs)
			else:
				x += 1

func _place_deco() -> void:
	_deco.clear()
	chest_cells.clear()
	var props := Node2D.new()
	props.name = "Props"
	add_child(props)
	# Floor clutter (drawn in _draw)
	var kinds: Array = biome.get("decor", ["skull"])
	if is_town:
		kinds = []
		for c in [Vector2i(27, 27), Vector2i(45, 27), Vector2i(27, 39), Vector2i(45, 39)]:
			_deco.append({"cell": c, "kind": "column", "v": 0.5})
		for c in [Vector2i(33, 39), Vector2i(39, 39), Vector2i(28, 33), Vector2i(44, 33)]:
			_deco.append({"cell": c, "kind": "crate", "v": 0.5})
		_deco.append({"cell": town_spots.fountain, "kind": "town_fountain", "v": 0.5})
		_deco.append({"cell": Vector2i(36, 35), "kind": "carpet", "v": 0.9})
	for i in (0 if is_town else (110 if biome.style == "proc" else 70)):
		var c: Vector2i = floor_cells[rng.randi() % floor_cells.size()]
		_deco.append({"cell": c, "kind": kinds[rng.randi() % kinds.size()], "v": rng.randf()})
	# Wall decorations on south-facing wall faces
	var faces: Array = []
	for y in H:
		for x in W:
			if _is_edge_wall(x, y) and is_floor_cell(x, y + 1):
				faces.append(Vector2i(x, y))
	wall_decor.clear()
	if biome.style != "tiles":
		faces.clear()
	for f in faces:
		var r := rng.randf()
		if is_town:
			r *= 0.25   # banners everywhere in town
		if r < 0.07:
			wall_decor[f] = ["wall_banner_red", "wall_banner_blue", "wall_banner_green", "wall_banner_yellow"][rng.randi() % 4]
		elif r < 0.10:
			wall_decor[f] = "wall_hole_1" if rng.randf() < 0.5 else "wall_hole_2"
		elif r < 0.115:
			wall_decor[f] = "fountain"
			var color := "blue" if theme_accent.b > theme_accent.r else "red"
			for part in ["mid", "basin"]:
				var a := AnimatedSprite2D.new()
				a.sprite_frames = Art.prop_frames("wall_fountain_%s_%s_anim" % [part, color], 6.0)
				a.scale = Vector2.ONE * Art.PX
				a.centered = false
				a.position = Vector2(f.x * CELL, (f.y + (0 if part == "mid" else 1)) * CELL)
				a.play()
				props.add_child(a)
	# Braziers: light pools
	braziers.clear()
	for i in int(biome.get("lights", 24)):
		var c: Vector2i = floor_cells[rng.randi() % floor_cells.size()]
		braziers.append(cell_center(c))
	# Treasure chests: off the main path, away from start
	for i in 5:
		for t in 40:
			var c: Vector2i = floor_cells[rng.randi() % floor_cells.size()]
			if Vector2(c - start_cell).length() > 12 and Vector2(c - boss_cell).length() > 9:
				chest_cells.append(c)
				break

func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xffff) / 65535.0

func draw_cells(ci: CanvasItem, x0: int, y0: int, x1: int, y1: int) -> void:
	if biome.style == "proc":
		_draw_cells_proc(ci, x0, y0, x1, y1)
	else:
		_draw_cells_tiles(ci, x0, y0, x1, y1)
	_draw_deco(ci, x0, y0, x1, y1)

func _draw_cells_tiles(ci: CanvasItem, x0: int, y0: int, x1: int, y1: int) -> void:
	var tint := theme_tint
	var floors := ["floor_1", "floor_1", "floor_1", "floor_1", "floor_2", "floor_3", "floor_4", "floor_5", "floor_6", "floor_7", "floor_8"]
	for y in range(y0, y1):
		for x in range(x0, x1):
			var r := Rect2(x * CELL, y * CELL, CELL, CELL)
			if is_floor_cell(x, y):
				var n := _hash(x, y)
				var name: String = floors[int(n * 997) % floors.size()] if n > 0.55 else "floor_1"
				ci.draw_texture_rect(Art.tex(name), r, false, tint)
			elif _is_edge_wall(x, y):
				if is_floor_cell(x, y + 1):
					var deco: String = wall_decor.get(Vector2i(x, y), "")
					var face := "wall_mid"
					if deco.begins_with("wall_banner") or deco.begins_with("wall_hole"):
						face = deco
					if deco == "fountain":
						continue
					ci.draw_texture_rect(Art.tex(face), r, false, tint)
				else:
					ci.draw_texture_rect(Art.tex("wall_mid"), r, false, tint.darkened(0.45))
				if not is_floor_cell(x, y - 1):
					ci.draw_texture_rect(Art.tex("wall_top_mid"), Rect2(r.position - Vector2(0, CELL), r.size), false, tint.darkened(0.1))
	_draw_shadows(ci, x0, y0, x1, y1)

func _near_floor(x: int, y: int, d: int) -> bool:
	for oy in range(-d, d + 1):
		for ox in range(-d, d + 1):
			if is_floor_cell(x + ox, y + oy):
				return true
	return false

func _draw_cells_proc(ci: CanvasItem, x0: int, y0: int, x1: int, y1: int) -> void:
	var lush: bool = biome.wall_kind == "tree" or biome.wall_kind == "water"
	for y in range(y0, y1):
		for x in range(x0, x1):
			var r := Rect2(x * CELL, y * CELL, CELL, CELL)
			var n := _hash(x, y)
			if is_floor_cell(x, y):
				var v := 0 if n < 0.45 else (1 if n < 0.8 else (2 if n < 0.985 else 3))
				ci.draw_texture_rect(BiomeArt.floor_tex(biome_id, v), r, false)
			elif is_floor_cell(x, y + 1):
				ci.draw_texture_rect(BiomeArt.face_tex(biome_id, int(n * 3.0)), r, false)
			elif _near_floor(x, y, 2 if lush else 1):
				ci.draw_texture_rect(BiomeArt.top_tex(biome_id, int(n * 3.0)), r, false, Color(1, 1, 1) if _near_floor(x, y, 1) else Color(0.7, 0.7, 0.7))
	# tree canopies overhang the trail edges
	if biome.wall_kind == "tree":
		for y in range(y0, y1):
			for x in range(x0, x1):
				if not is_floor_cell(x, y) and is_floor_cell(x, y + 1) and _hash(x + 7, y) > 0.35:
					var c := cell_center(Vector2i(x, y)) + Vector2(0, -10)
					var w: Array = biome.wall
					ci.draw_circle(c + Vector2(0, -6), CELL * 0.62, Color(w[0]).darkened(0.2))
					ci.draw_circle(c + Vector2(-8, -14), CELL * 0.45, w[1])
					ci.draw_circle(c + Vector2(10, -18), CELL * 0.3, Color(w[1]).lightened(0.12))
	_draw_shadows(ci, x0, y0, x1, y1)

func _draw_shadows(ci: CanvasItem, x0: int, y0: int, x1: int, y1: int) -> void:
	for y in range(y0, y1):
		for x in range(x0, x1):
			if is_floor_cell(x, y) and not is_floor_cell(x, y - 1):
				for i in 4:
					ci.draw_rect(Rect2(x * CELL, y * CELL + i * 5, CELL, 5), Color(0, 0, 0, 0.35 - i * 0.08))

func _draw_deco(ci: CanvasItem, x0: int, y0: int, x1: int, y1: int) -> void:
	var tint := theme_tint
	var acc := theme_accent
	for d in _deco:
		var c: Vector2i = d.cell
		if c.x < x0 or c.x >= x1 or c.y < y0 or c.y >= y1:
			continue
		var p := cell_center(c) + Vector2((_hash(c.x, c.y + 3) - 0.5) * 30.0, (_hash(c.x + 3, c.y) - 0.5) * 30.0)
		var v: float = d.get("v", 0.5)
		match d.kind:
			"skull":
				ci.draw_texture_rect(Art.tex("skull"), Rect2(p - Vector2(32, 32), Vector2(64, 64)), false, tint)
			"crate":
				ci.draw_texture_rect(Art.tex("crate"), Rect2(p - Vector2(24, 48), Vector2(48, 66)), false, tint)
			"floor_spikes":
				ci.draw_texture_rect(Art.tex("floor_spikes_anim", 0), Rect2(p - Vector2(32, 32), Vector2(64, 64)), false, tint)
			"column":
				ci.draw_texture_rect(Art.tex("column_mid"), Rect2(p - Vector2(32, 64), Vector2(64, 64)), false, tint)
				ci.draw_texture_rect(Art.tex("column_top"), Rect2(p - Vector2(32, 128), Vector2(64, 64)), false, tint)
			"carpet":
				var len := 2 + int(v * 3.0)
				ci.draw_rect(Rect2(cell_center(c) - Vector2(CELL * 0.35, CELL * 0.5), Vector2(CELL * 0.7, CELL * len)), Color(0.45, 0.08, 0.08, 0.85))
				ci.draw_rect(Rect2(cell_center(c) - Vector2(CELL * 0.35, CELL * 0.5), Vector2(CELL * 0.7, CELL * len)), Color(0.85, 0.65, 0.25, 0.8), false, 3.0)
			"town_fountain":
				var fc := cell_center(c)
				ci.draw_circle(fc + Vector2(0, 10), 78.0, Color(0, 0, 0, 0.35))
				ci.draw_circle(fc, 74.0, Color(0.38, 0.34, 0.33))
				ci.draw_circle(fc, 62.0, Color(0.15, 0.32, 0.45))
				ci.draw_arc(fc, 50.0, 0.4, 2.2, 16, Color(0.55, 0.8, 0.95, 0.6), 3.0)
				ci.draw_circle(fc, 16.0, Color(0.45, 0.42, 0.4))
				ci.draw_circle(fc + Vector2(0, -8), 7.0, Color(0.7, 0.9, 1.0))
			"flowers":
				for i in 4:
					var fp := p + Vector2(cos(i * 1.7 + v * 6.0), sin(i * 2.3 + v * 6.0)) * 14.0
					ci.draw_circle(fp, 4.0, [Color(0.95, 0.85, 0.3), Color(0.9, 0.4, 0.5), Color(0.75, 0.7, 1.0)][int(v * 3.0) % 3])
					ci.draw_circle(fp, 1.5, Color(1, 1, 0.8))
			"grass":
				for i in 6:
					var gx := (i - 2.5) * 6.0
					ci.draw_line(p + Vector2(gx, 6), p + Vector2(gx + sin(i) * 4.0, -10 - (i % 3) * 4.0), Color(0.35, 0.55, 0.2), 3.0)
			"mushroom":
				var mc := acc if biome_id == "swamp" else Color(0.85, 0.25, 0.2)
				ci.draw_rect(Rect2(p + Vector2(-3, -10), Vector2(6, 14)), Color(0.85, 0.8, 0.7))
				ci.draw_circle(p + Vector2(0, -12), 11.0, mc)
				ci.draw_circle(p + Vector2(-4, -15), 2.5, Color(1, 1, 0.9))
			"stump":
				ci.draw_circle(p + Vector2(0, 4), 16.0, Color(0, 0, 0, 0.3))
				ci.draw_rect(Rect2(p + Vector2(-14, -10), Vector2(28, 16)), Color(0.35, 0.23, 0.13))
				ci.draw_circle(p + Vector2(0, -10), 14.0, Color(0.55, 0.4, 0.25))
				ci.draw_arc(p + Vector2(0, -10), 8.0, 0, TAU, 16, Color(0.4, 0.28, 0.16), 2.0)
			"rock":
				var rc: Color = biome.get("wall", [Color(0.3, 0.3, 0.3), Color(0.4, 0.4, 0.4), Color(0.5, 0.5, 0.5)])[1]
				ci.draw_circle(p + Vector2(0, 6), 18.0, Color(0, 0, 0, 0.3))
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-18, 6), p + Vector2(-12, -12), p + Vector2(6, -16), p + Vector2(18, 0), p + Vector2(12, 8)]), rc)
				ci.draw_line(p + Vector2(-12, -12), p + Vector2(6, -16), Color(rc).lightened(0.3), 3.0)
			"reeds":
				for i in 5:
					var rx := (i - 2) * 7.0
					ci.draw_line(p + Vector2(rx, 8), p + Vector2(rx + 2, -26 - i % 2 * 8), Color(0.35, 0.45, 0.22), 3.0)
					ci.draw_rect(Rect2(p + Vector2(rx - 1, -30 - i % 2 * 8), Vector2(5, 10)), Color(0.4, 0.27, 0.15))
			"lily":
				ci.draw_circle(p, 16.0, Color(0.1, 0.18, 0.16))
				ci.draw_circle(p + Vector2(-4, -2), 9.0, Color(0.3, 0.55, 0.25))
				ci.draw_circle(p + Vector2(7, 3), 3.0, Color(0.95, 0.75, 0.85))
			"bones":
				ci.draw_line(p + Vector2(-14, -4), p + Vector2(14, 4), Color(0.85, 0.82, 0.72), 5.0)
				ci.draw_line(p + Vector2(-10, 8), p + Vector2(8, -8), Color(0.78, 0.75, 0.66), 4.0)
			"crystal":
				ci.draw_circle(p, 22.0, Color(acc.r, acc.g, acc.b, 0.15))
				for i in 3:
					var bx := (i - 1) * 9.0
					var hgt: float = 26.0 + i * 6.0 - abs(i - 1) * 10.0
					ci.draw_colored_polygon(PackedVector2Array([p + Vector2(bx - 5, 4), p + Vector2(bx, -hgt), p + Vector2(bx + 5, 4)]), acc.lerp(Color.WHITE, 0.2))
					ci.draw_line(p + Vector2(bx, -hgt), p + Vector2(bx - 3, 2), Color(1, 1, 1, 0.7), 1.5)
			"stalagmite":
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-12, 8), p + Vector2(-2, -34), p + Vector2(12, 8)]), Color(biome.wall[1]))
				ci.draw_line(p + Vector2(-2, -34), p + Vector2(-8, 6), Color(biome.wall[2]).darkened(0.1), 2.0)
			"snow":
				ci.draw_circle(p + Vector2(0, 2), 16.0, Color(0.9, 0.94, 1.0))
				ci.draw_circle(p + Vector2(-8, -2), 10.0, Color(1, 1, 1))
			"ice_shard":
				ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-8, 6), p + Vector2(0, -30), p + Vector2(9, 6)]), Color(0.65, 0.88, 1.0, 0.9))
				ci.draw_line(p + Vector2(0, -30), p + Vector2(-3, 4), Color(1, 1, 1), 2.0)
			"vent":
				ci.draw_circle(p, 18.0, Color(0.05, 0.03, 0.03))
				ci.draw_circle(p, 10.0, Color(1.0, 0.4, 0.08, 0.7 + 0.3 * v))
				ci.draw_circle(p, 5.0, Color(1.0, 0.85, 0.4))
			"ember":
				for i in 5:
					ci.draw_circle(p + Vector2(cos(i * 1.3 + v * 9.0), sin(i * 2.1)) * 16.0, 2.5, Color(1.0, 0.55, 0.15))
	for b in braziers:
		var bcell := Vector2i(b / CELL)
		if bcell.x < x0 or bcell.x >= x1 or bcell.y < y0 or bcell.y >= y1:
			continue
		match biome_id:
			"forest":   # lantern post
				ci.draw_rect(Rect2(b + Vector2(-3, -40), Vector2(6, 46)), Color(0.3, 0.2, 0.12))
				ci.draw_rect(Rect2(b + Vector2(-9, -56), Vector2(18, 18)), Color(0.15, 0.12, 0.08))
				ci.draw_rect(Rect2(b + Vector2(-6, -53), Vector2(12, 12)), Color(1.0, 0.85, 0.5))
			"swamp":   # glowing toadstools
				for i in 3:
					var sp: Vector2 = b + Vector2((i - 1) * 14.0, i % 2 * 6.0)
					ci.draw_rect(Rect2(sp + Vector2(-2, -10), Vector2(4, 12)), Color(0.8, 0.85, 0.7))
					ci.draw_circle(sp + Vector2(0, -12), 8.0, acc)
			"cave", "tundra":   # crystal cluster
				for i in 3:
					var bx := (i - 1) * 10.0
					ci.draw_colored_polygon(PackedVector2Array([b + Vector2(bx - 6, 6), b + Vector2(bx, -34 + abs(i - 1) * 12.0), b + Vector2(bx + 6, 6)]), acc)
			"volcanic":   # lava pool
				ci.draw_circle(b, 26.0, Color(0.15, 0.04, 0.02))
				ci.draw_circle(b, 20.0, Color(1.0, 0.35, 0.05))
				ci.draw_circle(b + Vector2(-5, -3), 9.0, Color(1.0, 0.75, 0.3))
			_:
				ci.draw_circle(b + Vector2(0, 8), 16, Color(0, 0, 0, 0.4))
				ci.draw_circle(b, 14, Color(0.2, 0.16, 0.13))
				ci.draw_circle(b, 10, theme_accent.darkened(0.2))
				ci.draw_circle(b, 5, Color(1, 0.95, 0.7))

func _draw() -> void:
	draw_rect(Rect2(-CELL * 10, -CELL * 10, (W + 20) * CELL, (H + 20) * CELL), biome.get("bg", Color(0.015, 0.012, 0.02)))
	if not is_town:
		var bc := cell_center(boss_cell)
		draw_arc(bc, CELL * 6.5, 0, TAU, 96, Color(theme_accent.r, theme_accent.g, theme_accent.b, 0.35), 4.0, true)

const CHUNK := 10

func _build_chunks() -> void:
	for cy in range(0, H, CHUNK):
		for cx in range(0, W, CHUNK):
			var ch := ZoneChunk.new()
			ch.zone = self
			ch.r = Rect2i(cx, cy, mini(CHUNK, W - cx), mini(CHUNK, H - cy))
			add_child(ch)
