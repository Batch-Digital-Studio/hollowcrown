class_name Minimap
extends RefCounted
## Fog-of-war minimap. Reveals cells near the player into an Image.

var img: Image
var tex: ImageTexture
var zone: Zone
var revealed := PackedByteArray()
var _dirty := false
var _t := 0.0
const REVEAL := 7

func reset(z: Zone) -> void:
	zone = z
	img = Image.create(Zone.W, Zone.H, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	revealed.resize(Zone.W * Zone.H)
	revealed.fill(0)
	tex = ImageTexture.create_from_image(img)

func update(player_pos: Vector2, delta: float) -> void:
	if zone == null:
		return
	_t += delta
	if _t < 0.2:
		return
	_t = 0.0
	var c := Vector2i(player_pos / Zone.CELL)
	for y in range(c.y - REVEAL, c.y + REVEAL + 1):
		for x in range(c.x - REVEAL, c.x + REVEAL + 1):
			if x < 0 or y < 0 or x >= Zone.W or y >= Zone.H:
				continue
			if Vector2(x - c.x, y - c.y).length() > REVEAL:
				continue
			var i := y * Zone.W + x
			if revealed[i] == 1:
				continue
			revealed[i] = 1
			_dirty = true
			if zone.is_floor_cell(x, y):
				img.set_pixel(x, y, Color(0.55, 0.5, 0.45, 0.75))
			else:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if zone.is_floor_cell(x + d.x, y + d.y):
						img.set_pixel(x, y, Color(0.9, 0.7, 0.4, 0.9))
						break
	if _dirty:
		tex.update(img)
		_dirty = false

func is_revealed(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= Zone.W or cell.y >= Zone.H:
		return false
	return revealed[cell.y * Zone.W + cell.x] == 1
