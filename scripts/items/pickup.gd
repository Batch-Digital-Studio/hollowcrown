class_name Pickup
extends Node2D
## An item lying on the ground. Walk over it to pick it up.

var item: Item
var _t := 0.0
var _beam := 0.0
var _vel := Vector2.ZERO
var _glow: Sprite2D
var _label_w := 0.0

func setup(it: Item, pos: Vector2, scatter: Vector2) -> void:
	item = it
	position = pos
	_vel = scatter
	z_index = 3

func _ready() -> void:
	var c := item.color()
	_glow = FX.make_glow(c, 70.0 if item.rarity in ["rare", "unique"] else 40.0)
	_glow.modulate.a = 0.7
	add_child(_glow)
	_label_w = ThemeDB.fallback_font.get_string_size(item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	if item.rarity == "unique":
		FX.text(position, "UNIQUE", c, 26)
		FX.shake(4.0)

func _process(delta: float) -> void:
	_t += delta
	position += _vel * delta
	_vel = _vel.move_toward(Vector2.ZERO, 900.0 * delta)
	var g := Game.instance
	if g and g.player and not g.player.dead and _t > 0.35:
		if g.player.global_position.distance_to(global_position) < 42.0:
			if g.player.add_to_inventory(item):
				FX.text(global_position, item.name, item.color(), 18)
				FX.burst(global_position, item.color(), 12, 160.0, 6.0, 0.4)
				g.on_item_picked(item)
				queue_free()
				return
	queue_redraw()

func _draw() -> void:
	var c := item.color()
	var pop := minf(1.0, _t * 4.0)
	if item.rarity in ["rare", "unique"]:
		var bc := c
		bc.a = 0.25 + 0.1 * sin(_t * 4.0)
		draw_rect(Rect2(-4, -220, 8, 220), bc)
		bc.a *= 0.5
		draw_rect(Rect2(-10, -160, 20, 160), bc)
	var s := 7.0 * pop
	var pts := PackedVector2Array([Vector2(0, -s * 1.4), Vector2(s, 0), Vector2(0, s * 1.4), Vector2(-s, 0)])
	draw_colored_polygon(pts, c)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.5, true)
	var f := ThemeDB.fallback_font
	var y := -18.0
	draw_rect(Rect2(-_label_w / 2 - 5, y - 13, _label_w + 10, 18), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(-_label_w / 2 - 5, y - 13, _label_w + 10, 18), c.darkened(0.3), false, 1.0)
	draw_string(f, Vector2(-_label_w / 2, y), item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
