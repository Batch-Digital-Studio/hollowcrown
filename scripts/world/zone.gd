class_name Zone
extends Node2D
## Generated zone: winding paths, side caves, rooms and a boss arena at the far end.

const CELL := 64
const W := 90
const H := 70

var grid := PackedByteArray()   # 1 = floor, 0 = solid
var start_cell := Vector2i.ZERO
var boss_cell := Vector2i.ZERO
var floor_cells: Array = []
var rng: RandomNumberGenerator
var theme_floor := Color(0.13, 0.12, 0.13)
var theme_wall := Color(0.07, 0.065, 0.075)
var theme_accent := Color(1.0, 0.5, 0.2)
var _deco: Array = []

func generate(seed_value: int, depth: int) -> void:
	rng = RandomNumberGenerator.new()
	rng.seed = seed_value
	grid.resize(W * H)
	grid.fill(0)
	var themes := [
		[Color(0.19, 0.165, 0.15), Color(0.085, 0.075, 0.08), Color(1.0, 0.5, 0.2)],
		[Color(0.14, 0.17, 0.2), Color(0.06, 0.075, 0.1), Color(0.45, 0.75, 1.0)],
		[Color(0.2, 0.14, 0.12), Color(0.1, 0.055, 0.05), Color(1.0, 0.3, 0.15)],
		[Color(0.14, 0.17, 0.14), Color(0.06, 0.08, 0.065), Color(0.6, 1.0, 0.5)],
	]
	var th: Array = themes[(depth - 1) % themes.size()]
	theme_floor = th[0]
	theme_wall = th[1]
	theme_accent = th[2]
	# Main path west -> east
	start_cell = Vector2i(6, H / 2 + rng.randi_range(-10, 10))
	boss_cell = Vector2i(W - 12, H / 2 + rng.randi_range(-12, 12))
	var path := _walk(start_cell, boss_cell, 2)
	# Rooms along the path
	for i in 7:
		var c: Vector2i = path[rng.randi_range(int(path.size() * 0.1), int(path.size() * 0.85))]
		_carve_circle(c, rng.randi_range(3, 5))
	# Side caves
	for i in 9:
		var c: Vector2i = path[rng.randi_range(0, path.size() - 1)]
		var target := Vector2i(clampi(c.x + rng.randi_range(-18, 18), 3, W - 4), clampi(c.y + rng.randi_range(-20, 20), 3, H - 4))
		var side := _walk(c, target, 1)
		_carve_circle(side[side.size() - 1], rng.randi_range(2, 4))
	_carve_circle(start_cell, 3)
	_carve_circle(boss_cell, 8)
	# Frame
	for x in W:
		_setc(x, 0, 0); _setc(x, 1, 0); _setc(x, H - 1, 0); _setc(x, H - 2, 0)
	for y in H:
		_setc(0, y, 0); _setc(1, y, 0); _setc(W - 1, y, 0); _setc(W - 2, y, 0)
	floor_cells.clear()
	for y in H:
		for x in W:
			if is_floor_cell(x, y):
				floor_cells.append(Vector2i(x, y))
	_build_collision()
	_place_deco()
	queue_redraw()

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
	for i in 70:
		var c: Vector2i = floor_cells[rng.randi() % floor_cells.size()]
		_deco.append({"pos": cell_center(c) + Vector2(rng.randf_range(-24, 24), rng.randf_range(-24, 24)),
			"kind": rng.randi() % 3, "rot": rng.randf() * TAU, "s": rng.randf_range(0.7, 1.4)})
	# Ember braziers give light pools
	for i in 26:
		var c: Vector2i = floor_cells[rng.randi() % floor_cells.size()]
		var g := FX.make_glow(Color(theme_accent.r, theme_accent.g, theme_accent.b, 0.45), rng.randf_range(200, 320))
		g.position = cell_center(c)
		g.z_index = -5
		add_child(g)
		_deco.append({"pos": cell_center(c), "kind": 9, "rot": 0.0, "s": 1.0})

func _hash(x: int, y: int) -> float:
	var h := (x * 374761393 + y * 668265263) & 0x7fffffff
	h = (h ^ (h >> 13)) * 1274126177
	return float(h & 0xffff) / 65535.0

func _draw() -> void:
	draw_rect(Rect2(-CELL * 10, -CELL * 10, (W + 20) * CELL, (H + 20) * CELL), Color(0.02, 0.02, 0.025))
	# Floor pass
	for y in H:
		for x in W:
			if not is_floor_cell(x, y):
				continue
			var r := Rect2(x * CELL, y * CELL, CELL, CELL)
			var n := _hash(x, y)
			var big := _hash(x / 4, y / 4)
			var c := theme_floor.lightened(big * 0.07 + n * 0.03)
			draw_rect(r, c)
			if n > 0.55:
				draw_rect(r.grow(-2), c.darkened(0.07), false, 1.0)
			if n > 0.86:
				draw_line(r.position + Vector2(8 + n * 20, 14), r.position + Vector2(36, 30 + n * 10), c.darkened(0.35), 1.5)
	# Wall pass (drawn after so shadows/lips overlap the floor)
	for y in H:
		for x in W:
			if is_floor_cell(x, y):
				continue
			var r := Rect2(x * CELL, y * CELL, CELL, CELL)
			if not _is_edge_wall(x, y):
				draw_rect(r, Color(0.02, 0.02, 0.025))
				continue
			var n2 := _hash(x + 999, y)
			draw_rect(r, theme_wall.lightened(n2 * 0.05))
			# brick hints on the wall top
			draw_line(r.position + Vector2(0, CELL * 0.5), r.position + Vector2(CELL, CELL * 0.5), theme_wall.darkened(0.4), 1.0)
			if is_floor_cell(x, y + 1):
				# front face of the wall, lit
				var face := Rect2(r.position.x, r.end.y - 18, CELL, 18)
				draw_rect(face, theme_wall.lightened(0.22))
				draw_line(Vector2(r.position.x, r.end.y - 18), Vector2(r.end.x, r.end.y - 18), theme_accent.darkened(0.55), 2.0)
				# soft shadow cast onto the floor below
				for i in 4:
					draw_rect(Rect2(r.position.x, r.end.y + i * 4, CELL, 4), Color(0, 0, 0, 0.32 - i * 0.07))
			if is_floor_cell(x, y - 1):
				draw_line(r.position, Vector2(r.end.x, r.position.y), theme_wall.lightened(0.3), 2.0)
			if is_floor_cell(x - 1, y):
				draw_line(r.position, Vector2(r.position.x, r.end.y), theme_wall.lightened(0.15), 2.0)
			if is_floor_cell(x + 1, y):
				draw_line(Vector2(r.end.x, r.position.y), r.end, theme_wall.lightened(0.15), 2.0)
	for d in _deco:
		var p: Vector2 = d.pos
		match d.kind:
			0:  # bones
				var a: float = d.rot
				draw_line(p - Vector2(cos(a), sin(a)) * 9 * d.s, p + Vector2(cos(a), sin(a)) * 9 * d.s, Color(0.55, 0.52, 0.47, 0.6), 3.0)
			1:  # ash pile
				draw_circle(p, 10 * d.s, Color(0.2, 0.19, 0.2, 0.7))
			2:  # crack
				draw_line(p, p + Vector2(cos(d.rot), sin(d.rot)) * 26 * d.s, Color(0, 0, 0, 0.4), 2.0)
			9:  # brazier
				draw_circle(p, 12, Color(0.15, 0.12, 0.1))
				draw_circle(p, 8, theme_accent)
				draw_circle(p, 4, Color(1, 0.95, 0.7))
	# boss arena ring
	var bc := cell_center(boss_cell)
	draw_arc(bc, CELL * 6.5, 0, TAU, 96, Color(theme_accent.r, theme_accent.g, theme_accent.b, 0.25), 4.0, true)
