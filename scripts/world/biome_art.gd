class_name BiomeArt
extends RefCounted
## Procedural 16x16 pixel tiles for biomes the 0x72 dungeon sheet doesn't cover
## (forest, swamp, cave, frost, ashlands). Drawn at Art.PX like the rest of the art,
## so they sit in the same pixel grid. Deterministic: same biome -> same tiles.

static var _cache := {}

static func floor_tex(biome_id: String, variant: int) -> Texture2D:
	var key := "%s_f%d" % [biome_id, variant]
	if not _cache.has(key):
		_cache[key] = _make_floor(biome_id, variant)
	return _cache[key]

static func face_tex(biome_id: String, variant: int = 0) -> Texture2D:
	var key := "%s_w%d" % [biome_id, variant]
	if not _cache.has(key):
		_cache[key] = _make_face(biome_id, variant)
	return _cache[key]

static func top_tex(biome_id: String, variant: int = 0) -> Texture2D:
	var key := "%s_t%d" % [biome_id, variant]
	if not _cache.has(key):
		_cache[key] = _make_top(biome_id, variant)
	return _cache[key]

static func _rng(biome_id: String, salt: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(biome_id) + salt * 7919
	return r

static func _jit(c: Color, r: RandomNumberGenerator, amt: float) -> Color:
	var k := r.randf_range(-amt, amt)
	return Color(clampf(c.r + k, 0, 1), clampf(c.g + k, 0, 1), clampf(c.b + k * 0.8, 0, 1))

static func _tex(img: Image) -> Texture2D:
	return ImageTexture.create_from_image(img)

static func _make_floor(id: String, v: int) -> Texture2D:
	var b: Dictionary = WorldDB.BIOMES[id]
	var pal: Array = b.floor
	var r := _rng(id, v + 1)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var base: Color = pal[v % 3]
	for y in 16:
		for x in 16:
			img.set_pixel(x, y, _jit(base, r, 0.025))
	match id:
		"forest":
			if v == 3:   # dirt path
				for y in 16:
					for x in 16:
						img.set_pixel(x, y, _jit(pal[3], r, 0.03))
			for i in 14:   # grass blades
				var x := r.randi_range(0, 15)
				var y := r.randi_range(1, 15)
				var c: Color = pal[1].lightened(0.25) if r.randf() < 0.5 else pal[2].darkened(0.2)
				img.set_pixel(x, y, c)
				img.set_pixel(x, y - 1, c.darkened(0.1))
			if v == 2 and r.randf() < 0.9:   # a flower
				var fx := r.randi_range(2, 13)
				var fy := r.randi_range(2, 13)
				var fc: Color = [Color(0.95, 0.85, 0.3), Color(0.9, 0.4, 0.5), Color(0.75, 0.7, 1.0)][r.randi() % 3]
				for o in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
					img.set_pixelv(Vector2i(fx, fy) + o, fc)
				img.set_pixel(fx, fy, Color(1, 0.95, 0.6))
		"swamp":
			for i in 3:   # puddles
				var cx := r.randi_range(2, 13)
				var cy := r.randi_range(2, 13)
				for y in range(cy - 1, cy + 2):
					for x in range(cx - 2, cx + 2):
						if x >= 0 and x < 16 and y >= 0 and y < 16 and r.randf() < 0.8:
							img.set_pixel(x, y, Color(0.12, 0.17, 0.14))
				img.set_pixel(clampi(cx - 1, 0, 15), cy - 1, Color(0.35, 0.45, 0.38))
			for i in 6:
				img.set_pixel(r.randi_range(0, 15), r.randi_range(0, 15), pal[1].lightened(0.2))
		"cave":
			for i in 10:   # pebbles
				var x := r.randi_range(0, 14)
				var y := r.randi_range(0, 14)
				img.set_pixel(x, y, base.lightened(0.18))
				img.set_pixel(x + 1, y + 1, base.darkened(0.3))
			if v == 1:   # crack
				var x := r.randi_range(3, 12)
				for y in 16:
					if r.randf() < 0.75:
						img.set_pixel(clampi(x, 0, 15), y, base.darkened(0.45))
					x += r.randi_range(-1, 1)
		"tundra":
			for i in 8:
				img.set_pixel(r.randi_range(0, 15), r.randi_range(0, 15), Color(1, 1, 1))
			for i in 6:
				img.set_pixel(r.randi_range(0, 15), r.randi_range(0, 15), base.darkened(0.12))
			if v == 2:   # wind drift
				var y0 := r.randi_range(3, 12)
				for x in 16:
					img.set_pixel(x, clampi(y0 + int(sin(x * 0.7) * 1.5), 0, 15), base.lightened(0.12))
		"volcanic":
			for i in 8:
				img.set_pixel(r.randi_range(0, 15), r.randi_range(0, 15), base.lightened(0.12))
			if v == 1:   # ember cracks
				var x := r.randi_range(2, 13)
				var y := 0
				while y < 16:
					img.set_pixel(clampi(x, 0, 15), y, Color(1.0, 0.45, 0.1) if r.randf() < 0.6 else Color(0.6, 0.18, 0.05))
					x += r.randi_range(-1, 1)
					y += 1
	return _tex(img)

## The front face of a wall (seen from below).
static func _make_face(id: String, v: int) -> Texture2D:
	var b: Dictionary = WorldDB.BIOMES[id]
	var w: Array = b.wall
	var r := _rng(id, 50 + v)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	match String(b.wall_kind):
		"tree":
			for y in 16:
				for x in 16:
					var c: Color = w[0] if y < 7 else Color(0, 0, 0, 0)
					if y < 7:
						c = _jit(w[1] if r.randf() < 0.5 else w[0], r, 0.03)
					img.set_pixel(x, y, c)
			# trunks
			for t in [3 + r.randi_range(0, 2), 10 + r.randi_range(0, 2)]:
				for y in range(5, 16):
					for x in range(t, t + 3):
						img.set_pixel(clampi(x, 0, 15), y, _jit(w[2], r, 0.04).darkened(0.1 if x == t else 0.0))
			for y in range(7, 16):
				for x in 16:
					if img.get_pixel(x, y).a == 0.0:
						img.set_pixel(x, y, Color(0.06, 0.1, 0.05))
		"water":
			for y in 16:
				for x in 16:
					img.set_pixel(x, y, _jit(w[0] if y > 3 else w[2], r, 0.02))
			for i in 4:
				var y := r.randi_range(5, 14)
				var x0 := r.randi_range(0, 10)
				for x in range(x0, x0 + 4):
					img.set_pixel(x, y, w[1].lightened(0.15))
		"rock", "basalt", "ice":
			for y in 16:
				for x in 16:
					var c: Color = w[1] if y < 3 else w[0]
					if (y + (x / 5) * 2) % 6 == 0:
						c = c.darkened(0.25)   # strata
					img.set_pixel(x, y, _jit(c, r, 0.03))
			for x in 16:
				img.set_pixel(x, 0, w[2] if b.wall_kind != "basalt" else w[1].lightened(0.2))
			if b.wall_kind == "basalt":
				var x := r.randi_range(3, 12)
				for y in range(3, 16):
					img.set_pixel(clampi(x, 0, 15), y, w[2])
					x += r.randi_range(-1, 1)
			if b.wall_kind == "ice":
				for i in 5:
					img.set_pixel(r.randi_range(1, 14), r.randi_range(2, 14), Color(1, 1, 1, 0.9))
	return _tex(img)

## Wall tops / interior solid near the edge (canopy, water, rock tops).
static func _make_top(id: String, v: int) -> Texture2D:
	var b: Dictionary = WorldDB.BIOMES[id]
	var w: Array = b.wall
	var r := _rng(id, 90 + v)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var c: Color = w[0]
			match String(b.wall_kind):
				"tree":
					c = w[1] if r.randf() < 0.45 else w[0]
					if r.randf() < 0.06:
						c = w[1].lightened(0.2)
				"water":
					c = w[0] if r.randf() < 0.8 else w[1]
				_:
					c = (w[0] if r.randf() < 0.7 else w[1]).darkened(0.55)
			img.set_pixel(x, y, _jit(c, r, 0.02))
	if b.wall_kind == "water":
		for i in 3:
			var y := r.randi_range(2, 13)
			var x0 := r.randi_range(0, 11)
			for x in range(x0, x0 + 4):
				img.set_pixel(x, y, w[1].lightened(0.2))
	return _tex(img)
