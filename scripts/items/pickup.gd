class_name Pickup
extends Node2D
## An item lying on the ground. Walk over it to pick it up.

var item: Item
var filtered := false   # filtered out by the loot filter
var _t := 0.0
var _beam := 0.0
var _vel := Vector2.ZERO
var _glow: Sprite2D
var _label_w := 0.0
var _label_y := -18.0

func setup(it: Item, pos: Vector2, scatter: Vector2) -> void:
	item = it
	position = pos
	_vel = scatter
	z_index = 3

func _ready() -> void:
	add_to_group("interactable")
	if filtered:
		_label_w = ThemeDB.fallback_font.get_string_size(item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		modulate = Color(1, 1, 1, 0.45)
		return
	var c := item.color()
	_glow = FX.make_glow(c, 70.0 if item.rarity in ["rare", "unique"] else 40.0)
	_glow.modulate.a = 0.7
	add_child(_glow)
	# stack labels so several drops in one spot stay readable
	var n := 0
	for o in get_parent().get_children():
		if o != self and o is Pickup and o.position.distance_to(position) < 90.0:
			n += 1
	_label_y = -18.0 - n * 20.0
	_label_w = ThemeDB.fallback_font.get_string_size(item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	match item.rarity:
		"magic": FX.sound("drop_magic", null, -8.0, 0.0)
		"rare": FX.sound("drop_rare", null, -3.0, 0.0)
		"unique":
			FX.sound("drop_unique", null, 0.0, 0.0)
			FX.rumble(0.5, 0.5, 0.5)
	if item.rarity == "unique":
		FX.text(position, "UNIQUE", c, 26)
		FX.shake(4.0)

func _process(delta: float) -> void:
	_t += delta
	position += _vel * delta
	_vel = _vel.move_toward(Vector2.ZERO, 900.0 * delta)
	var g := Game.instance
	var show_h: bool = g != null and bool(g.loot_filter.get("show_hidden", false))
	visible = not filtered or show_h
	queue_redraw()

# --- Interact: click / A to pick up; Auto-loot picks it up when you walk over it ---
func can_interact() -> bool:
	return _t > 0.35 and visible and not is_queued_for_deletion()
func interact_label() -> String:
	return "Pick up " + item.name
func interact_kind() -> String:
	return "loot"
func interact_range() -> float:
	return 90.0
func auto_range() -> float:
	return 42.0
func hover_offset() -> Vector2:
	return Vector2(0, _label_y)
func interact(p: Player) -> void:
	var g := Game.instance
	if p.add_to_inventory(item):
		FX.text(global_position, item.name, item.color(), 18)
		FX.burst(global_position, item.color(), 12, 160.0, 6.0, 0.4)
		FX.sound("pickup", null, -10.0)
		g.on_item_picked(item)
		queue_free()
	else:
		FX.text(p.global_position, "Inventory full", Color(1.0, 0.5, 0.4), 18)

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
	var y := _label_y
	if y < -20.0:
		draw_line(Vector2(0, -8), Vector2(0, y + 5), Color(c.r, c.g, c.b, 0.4), 1.0)
	draw_rect(Rect2(-_label_w / 2 - 5, y - 13, _label_w + 10, 18), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(-_label_w / 2 - 5, y - 13, _label_w + 10, 18), c.darkened(0.3), false, 1.0)
	draw_string(f, Vector2(-_label_w / 2, y), item.name, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
