class_name InventoryUI
extends Control
## Inventory, equipment paper-doll, character sheet and item tooltips with comparison.

const PANEL_W := 540.0
const PANEL_H := 740.0
const CELL := 60.0
const COLS := 8
const SLOT_RECTS := {
	"weapon": Rect2(36, 70, 80, 150),
	"helm": Rect2(230, 60, 80, 80),
	"amulet": Rect2(335, 80, 50, 50),
	"body": Rect2(220, 150, 100, 140),
	"ring1": Rect2(150, 205, 50, 50),
	"ring2": Rect2(345, 205, 50, 50),
	"gloves": Rect2(100, 270, 80, 80),
	"boots": Rect2(360, 270, 80, 80),
}
const BAG_ORIGIN := Vector2(30, 385)

var _summary := {}
var _hover_item: Item = null
var _hover_slot := ""
var _hover_bag := -1
var _compare_cache := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func toggle() -> void:
	visible = not visible
	if visible:
		refresh()

func refresh() -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	_summary = g.player.summary(g.player.equipment)
	_compare_cache.clear()
	queue_redraw()

func panel_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(vs.x - PANEL_W - 20, 70, PANEL_W, PANEL_H)

func sheet_rect() -> Rect2:
	return Rect2(20, 90, 340, 460)

func mouse_over_panel() -> bool:
	var m := get_viewport().get_mouse_position()
	return panel_rect().has_point(m) or sheet_rect().has_point(m)

func _bag_rect(i: int) -> Rect2:
	var p := panel_rect().position + BAG_ORIGIN
	return Rect2(p.x + (i % COLS) * CELL, p.y + (i / COLS) * CELL, CELL - 4, CELL - 4)

func _slot_rect(slot: String) -> Rect2:
	var r: Rect2 = SLOT_RECTS[slot]
	return Rect2(panel_rect().position + r.position, r.size)

func _process(_delta: float) -> void:
	if not visible:
		return
	var m := get_viewport().get_mouse_position()
	var g := Game.instance
	_hover_item = null
	_hover_slot = ""
	_hover_bag = -1
	if g and g.player:
		for i in Player.INV_SIZE:
			if _bag_rect(i).has_point(m):
				_hover_bag = i
				_hover_item = g.player.inventory[i]
		for s in SLOT_RECTS:
			if _slot_rect(s).has_point(m):
				_hover_slot = s
				_hover_item = g.player.equipment.get(s)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if not mouse_over_panel():
			return
		get_viewport().set_input_as_handled()
		var p := Game.instance.player
		if event.button_index == MOUSE_BUTTON_LEFT:
			if _hover_bag >= 0 and p.inventory[_hover_bag]:
				p.equip_from_bag(_hover_bag)
				refresh()
			elif _hover_slot != "" and p.equipment.get(_hover_slot):
				p.unequip(_hover_slot)
				refresh()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _hover_bag >= 0 and p.inventory[_hover_bag]:
				var it: Item = p.inventory[_hover_bag]
				p.inventory[_hover_bag] = null
				FX.text(p.global_position, "Shattered " + it.name, Color(0.7, 0.7, 0.7), 16)
				refresh()

func _draw() -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	var p := g.player
	var f := ThemeDB.fallback_font
	var pr := panel_rect()
	_box(pr)
	_t(f, pr.position + Vector2(PANEL_W / 2, 36), "INVENTORY", 22, Color(1.0, 0.82, 0.45), true)
	for s in SLOT_RECTS:
		var r := _slot_rect(s)
		var it: Item = p.equipment.get(s)
		_cell(r, it, s == _hover_slot)
		if it == null:
			_t(f, r.get_center() + Vector2(0, 5), ItemsDB.SLOT_NAMES[s], 12, Color(0.4, 0.38, 0.36), true)
	for i in Player.INV_SIZE:
		_cell(_bag_rect(i), p.inventory[i], i == _hover_bag)
	_t(f, pr.position + Vector2(PANEL_W / 2, PANEL_H - 22), "Click: equip / unequip    ·    Right-click: shatter", 13, Color(0.55, 0.53, 0.5), true)
	# Character sheet
	var sr := sheet_rect()
	_box(sr)
	_t(f, sr.position + Vector2(20, 34), "THE KINDLED  ·  Level %d" % p.level, 18, Color(1.0, 0.82, 0.45), false)
	var y := sr.position.y + 66
	for k in _summary:
		var v: float = _summary[k]
		var txt := _fmt(k, v)
		var col := Color(0.85, 0.82, 0.78)
		if k.ends_with("DPS"):
			col = Color(1.0, 0.7, 0.4)
		_t(f, Vector2(sr.position.x + 20, y), k, 15, Color(0.65, 0.62, 0.6), false)
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_t(f, Vector2(sr.end.x - 20 - w, y), txt, 15, col, false)
		y += 26
	if _hover_item:
		_tooltip(_hover_item)

func _fmt(k: String, v: float) -> String:
	if k.ends_with("Res"):
		return "%d%%" % int(v)
	if k == "Move Speed":
		return "%d%%" % int(round(v))
	if k.ends_with("DPS"):
		return "%.1f" % v
	return "%d" % int(round(v))

func _box(r: Rect2) -> void:
	draw_rect(r, Color(0.04, 0.035, 0.05, 0.94))
	draw_rect(r, Color(0.6, 0.42, 0.22), false, 2.0)
	draw_rect(r.grow(-6), Color(0.35, 0.25, 0.14, 0.6), false, 1.0)

func _cell(r: Rect2, it: Item, hover: bool) -> void:
	draw_rect(r, Color(0.08, 0.075, 0.09))
	if it:
		var c := it.color()
		draw_rect(r, Color(c.r, c.g, c.b, 0.12))
		_icon(r, it)
		if it.req_level() > Game.instance.player.level:
			draw_rect(r, Color(0.6, 0.05, 0.05, 0.35))
		draw_rect(r, c.darkened(0.2), false, 2.0)
	else:
		draw_rect(r, Color(0.22, 0.2, 0.2), false, 1.0)
	if hover:
		draw_rect(r.grow(2), Color(1, 0.9, 0.6), false, 2.0)

func _icon(r: Rect2, it: Item) -> void:
	var c := it.color()
	var m := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.32
	match it.slot_group():
		"weapon":
			var wand := it.base_id.contains("wand")
			var maul := it.base_id.contains("maul")
			draw_line(m + Vector2(-s, s * 1.6), m + Vector2(s * 0.6, -s * 1.6), Color(0.8, 0.78, 0.74), 4.0 if not maul else 6.0, true)
			if wand:
				draw_circle(m + Vector2(s * 0.6, -s * 1.6), 6, c)
			elif maul:
				draw_rect(Rect2(m + Vector2(s * 0.1, -s * 2.1), Vector2(s * 1.1, s * 0.9)), c.darkened(0.3))
			else:
				draw_line(m + Vector2(-s * 0.9, s * 0.6), m + Vector2(s * 0.1, s * 1.0), c, 4.0)
		"helm":
			draw_arc(m + Vector2(0, s * 0.3), s, PI, TAU, 16, c, 5.0, true)
			draw_line(m + Vector2(-s, s * 0.3), m + Vector2(s, s * 0.3), c, 4.0)
		"body":
			draw_rect(Rect2(m - Vector2(s * 0.8, s * 1.1), Vector2(s * 1.6, s * 2.2)), c.darkened(0.4))
			draw_rect(Rect2(m - Vector2(s * 0.8, s * 1.1), Vector2(s * 1.6, s * 2.2)), c, false, 2.0)
		"gloves":
			draw_rect(Rect2(m - Vector2(s * 0.6, s * 0.5), Vector2(s * 1.2, s * 1.3)), c.darkened(0.3))
			for i in 4:
				draw_line(m + Vector2(-s * 0.5 + i * s * 0.33, -s * 0.5), m + Vector2(-s * 0.5 + i * s * 0.33, -s * 1.1), c, 3.0)
		"boots":
			draw_rect(Rect2(m - Vector2(s * 0.4, s * 1.0), Vector2(s * 0.7, s * 1.5)), c.darkened(0.3))
			draw_rect(Rect2(m + Vector2(-s * 0.4, s * 0.3), Vector2(s * 1.3, s * 0.5)), c.darkened(0.3))
		"ring":
			draw_arc(m, s * 0.8, 0, TAU, 24, c, 4.0, true)
			draw_circle(m + Vector2(0, -s * 0.8), 4, Color.WHITE)
		"amulet":
			draw_arc(m + Vector2(0, -s * 0.4), s * 0.9, 0.2, PI - 0.2, 16, Color(0.7, 0.65, 0.5), 2.0, true)
			draw_circle(m + Vector2(0, s * 0.5), s * 0.45, c)

func _tooltip(it: Item) -> void:
	var f := ThemeDB.fallback_font
	var lines: Array = it.tooltip_lines()
	# Comparison with what is equipped in that slot (bag items only)
	if _hover_bag >= 0:
		var deltas := _compare(it)
		if deltas.size() > 0:
			lines.append(["────────", Color(0.4, 0.4, 0.45)])
			lines.append(["If equipped:", Color(0.7, 0.7, 0.7)])
			for d in deltas:
				lines.append(d)
		if it.req_level() > Game.instance.player.level:
			lines.append(["Requires Level %d" % it.req_level(), Color(1, 0.35, 0.35)])
	var w := 0.0
	for l in lines:
		w = maxf(w, f.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	w += 30
	var h := lines.size() * 21 + 20
	var m := get_viewport().get_mouse_position()
	var pos := m + Vector2(-w - 18, 10)
	if pos.x < 10:
		pos.x = m.x + 18
	var vs := get_viewport_rect().size
	pos.y = clampf(pos.y, 10, vs.y - h - 10)
	var r := Rect2(pos, Vector2(w, h))
	draw_rect(r, Color(0.03, 0.025, 0.035, 0.97))
	draw_rect(r, it.color().darkened(0.2), false, 2.0)
	var y := pos.y + 26
	for i in lines.size():
		var l: Array = lines[i]
		var size := 18 if i == 0 else 15
		var tw := f.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(f, Vector2(pos.x + w / 2 - tw / 2, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size, l[1])
		y += 21

func _compare(it: Item) -> Array:
	if _compare_cache.has(it):
		return _compare_cache[it]
	var p := Game.instance.player
	var eq: Dictionary = p.equipment.duplicate()
	eq[p.target_slot_for(it)] = it
	var after := p.summary(eq)
	var out: Array = []
	for k in after:
		var a: float = after[k]
		var b: float = _summary.get(k, 0.0)
		var d := a - b
		var thresh := 0.05 if k.ends_with("DPS") else 0.5
		if absf(d) < thresh:
			continue
		var txt := ""
		if k.ends_with("DPS"):
			var pct := (d / maxf(0.01, b)) * 100.0
			txt = "%s %+.1f  (%+d%%)" % [k, d, int(round(pct))]
		else:
			txt = "%s %+d" % [k, int(round(d))]
		out.append([txt, Color(0.4, 1.0, 0.5) if d > 0 else Color(1.0, 0.4, 0.4)])
	_compare_cache[it] = out
	return out

func _t(f: Font, pos: Vector2, s: String, size: int, c: Color, centered: bool) -> void:
	var x := pos.x
	if centered:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2
	draw_string(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
