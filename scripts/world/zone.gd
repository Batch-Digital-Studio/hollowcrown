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
var wall_decor := {}
var braziers: Array = []
var chest_cells: Array = []
var theme_tint := Color.WHITE

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
	var tints := [Color(1.0, 0.9, 0.82), Color(0.78, 0.88, 1.05), Color(1.05, 0.78, 0.72), Color(0.8, 1.0, 0.82)]
	theme_tint = tints[(depth - 1) % tints.size()]
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
	_build_chunks()
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
	chest_cells.clear()
	var props := Node2D.new()
	props.name = "Props"
	add_child(props)
	# Floor clutter (drawn in _draw)
	for i in 70:
		var c: Vector2i = floor_cells[rng.randi() % floor_cells.size()]
		var kinds := ["skull", "skull", "skull", "floor_spikes", "floor_spikes", "crate"]
		_deco.append({"cell": c, "kind": kinds[rng.randi() % kinds.size()]})
	# Wall decorations on south-facing wall faces
	var faces: Array = []
	for y in H:
		for x in W:
			if _is_edge_wall(x, y) and is_floor_cell(x, y + 1):
				faces.append(Vector2i(x, y))
	wall_decor.clear()
	for f in faces:
		var r := rng.randf()
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
	for i in 24:
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
					# side/back walls: brick, darker so south faces read as the "front"
					ci.draw_texture_rect(Art.tex("wall_mid"), r, false, tint.darkened(0.45))
				# cap strip where the wall meets the rock above it
				if not is_floor_cell(x, y - 1):
					ci.draw_texture_rect(Art.tex("wall_top_mid"), Rect2(r.position - Vector2(0, CELL), r.size), false, tint.darkened(0.1))
	# soft shadow under wall faces
	for y in range(y0, y1):
		for x in range(x0, x1):
			if is_floor_cell(x, y) and not is_floor_cell(x, y - 1):
				for i in 4:
					ci.draw_rect(Rect2(x * CELL, y * CELL + i * 5, CELL, 5), Color(0, 0, 0, 0.35 - i * 0.08))
	for d in _deco:
		var c: Vector2i = d.cell
		if c.x < x0 or c.x >= x1 or c.y < y0 or c.y >= y1:
			continue
		var p := cell_center(c)
		match d.kind:
			"skull":
				ci.draw_texture_rect(Art.tex("skull"), Rect2(p - Vector2(32, 32), Vector2(64, 64)), false, tint)
			"crate":
				ci.draw_texture_rect(Art.tex("crate"), Rect2(p - Vector2(24, 48), Vector2(48, 66)), false, tint)
			"floor_spikes":
				ci.draw_texture_rect(Art.tex("floor_spikes_anim", 0), Rect2(p - Vector2(32, 32), Vector2(64, 64)), false, tint)
	for b in braziers:
		var bcell := Vector2i(b / CELL)
		if bcell.x < x0 or bcell.x >= x1 or bcell.y < y0 or bcell.y >= y1:
			continue
		ci.draw_circle(b + Vector2(0, 8), 16, Color(0, 0, 0, 0.4))
		ci.draw_circle(b, 14, Color(0.2, 0.16, 0.13))
		ci.draw_circle(b, 10, theme_accent.darkened(0.2))
		ci.draw_circle(b, 5, Color(1, 0.95, 0.7))

func _draw() -> void:
	draw_rect(Rect2(-CELL * 10, -CELL * 10, (W + 20) * CELL, (H + 20) * CELL), Color(0.015, 0.012, 0.02))
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
