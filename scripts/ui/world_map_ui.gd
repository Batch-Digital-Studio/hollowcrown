class_name WorldMapUI
extends Control
## The world map: Emberhold and the seven regions. Travel to the start of any region
## you've reached, to your deepest depth, or home. Opens from the Waystone in town or
## the pause menu. Pad: left stick cursor, A travel, B close.

var _t := 0.0
var _rects: Array = []   # {rect, depth, label}
var _hover := -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func toggle() -> void:
	visible = not visible
	get_tree().paused = visible

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var m := Game.pointer()
	_hover = -1
	for i in _rects.size():
		if _rects[i].rect.has_point(m):
			_hover = i
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton and event.pressed):
		return
	get_viewport().set_input_as_handled()
	if event.button_index == MOUSE_BUTTON_RIGHT:
		toggle()
		return
	if event.button_index == MOUSE_BUTTON_LEFT and _hover >= 0:
		var e: Dictionary = _rects[_hover]
		if not e.ok:
			FX.sound("hurt", null, -14.0, 0.0)
			return
		toggle()
		Game.instance.travel_to(int(e.depth))

func _map_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(80, 110, vs.x - 160, vs.y - 230)

func _draw() -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	var f := ThemeDB.fallback_font
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.82))
	var mr := _map_rect()
	# parchment-dark map
	draw_rect(mr, Color(0.11, 0.09, 0.07))
	draw_rect(mr, Color(0.6, 0.45, 0.25), false, 3.0)
	for i in 30:   # faint terrain marks
		var p := mr.position + Vector2(fmod(i * 173.3, mr.size.x), fmod(i * 97.7, mr.size.y))
		draw_arc(p, 30.0 + fmod(i * 13.0, 50.0), 0.3, 2.6, 12, Color(0.3, 0.24, 0.16, 0.4), 2.0)
	_title(f, Vector2(vs.x / 2, 70), "THE HOLLOW REALM", 32, Color(1.0, 0.82, 0.45))
	var you := "You are in %s" % (WorldDB.TOWN_NAME if g.in_town else "Depth %d · %s" % [g.depth, WorldDB.zone_name(g.depth)])
	_title(f, Vector2(vs.x / 2, 96), you + "   ·   deepest: Depth %d" % g.max_depth, 15, Color(0.75, 0.7, 0.62))
	_rects.clear()
	# route line
	var pts: Array = [mr.position + WorldDB.TOWN_POS * mr.size]
	for r in WorldDB.REGIONS:
		pts.append(mr.position + r.pos * mr.size)
	for i in pts.size() - 1:
		var reached := i == 0 or g.max_depth >= WorldDB.region_start(i - 1)
		_dashed(pts[i], pts[i + 1], Color(0.85, 0.65, 0.35, 0.8 if reached else 0.25))
	# town
	_node(f, pts[0], WorldDB.TOWN_NAME, "Home: stash, smelter, peddler", Color(1.0, 0.8, 0.5), 0, true, g.in_town)
	# regions
	for i in WorldDB.REGIONS.size():
		var r: Dictionary = WorldDB.REGIONS[i]
		var start := WorldDB.region_start(i)
		var ok := g.max_depth >= start
		var col: Color = WorldDB.BIOMES[r.biome].accent
		var lvl := 1 + (start - 1) * 3
		var sub := "Depths %d-%d · Area Level %d+  ·  %s" % [start, start + WorldDB.DEPTHS_PER_REGION - 1, lvl, r.blurb] if ok else "Locked: reach Depth %d" % start
		var here := not g.in_town and WorldDB.region_index(g.depth) == i
		_node(f, pts[i + 1], r.name, sub, col if ok else Color(0.35, 0.33, 0.32), start, ok, here)
	# continue button
	var cr := Rect2(vs.x / 2 - 220, mr.end.y + 22, 440, 46)
	var cont_ok := true
	_rects.append({"rect": cr, "depth": g.max_depth, "ok": cont_ok})
	var hov := _hover == _rects.size() - 1
	draw_rect(cr, Color(0.2, 0.14, 0.08) if hov else Color(0.1, 0.08, 0.06))
	draw_rect(cr, Color(1.0, 0.75, 0.4), false, 2.0)
	_title(f, cr.get_center() + Vector2(0, 7), "Continue: Depth %d · %s" % [g.max_depth, WorldDB.zone_name(g.max_depth)], 18, Color(1.0, 0.85, 0.55))
	_title(f, Vector2(vs.x / 2, vs.y - 18), ("A travel   ·   B close" if PlayerInput.using_pad else "Click travel   ·   Right-click / Esc close"), 14, Color(0.6, 0.58, 0.55))

func _node(f: Font, p: Vector2, name: String, sub: String, col: Color, depth: int, ok: bool, here: bool) -> void:
	var r := Rect2(p - Vector2(26, 26), Vector2(52, 52))
	_rects.append({"rect": r.grow(10), "depth": depth, "ok": ok})
	var hov := _hover == _rects.size() - 1
	draw_circle(p, 26.0, Color(0.06, 0.05, 0.05))
	draw_circle(p, 20.0, col.darkened(0.35) if ok else Color(0.15, 0.14, 0.14))
	draw_arc(p, 26.0, 0, TAU, 32, col if ok else Color(0.3, 0.3, 0.3), 3.0 if not hov else 5.0, true)
	if here:
		draw_arc(p, 34.0 + sin(_t * 4.0) * 3.0, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)
	if not ok:
		draw_rect(Rect2(p - Vector2(6, 2), Vector2(12, 10)), Color(0.5, 0.48, 0.45))
		draw_arc(p + Vector2(0, -2), 5.0, PI, TAU, 8, Color(0.5, 0.48, 0.45), 2.0)
	_title(f, p + Vector2(0, 48), name, 17, col if ok else Color(0.5, 0.48, 0.46))
	if hov:
		var w := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		var tr := Rect2(p + Vector2(-w / 2 - 10, 58), Vector2(w + 20, 26))
		draw_rect(tr, Color(0, 0, 0, 0.9))
		draw_rect(tr, col, false, 1.0)
		_title(f, p + Vector2(0, 76), sub, 13, Color(0.9, 0.88, 0.82))

func _dashed(a: Vector2, b: Vector2, c: Color) -> void:
	var d := a.distance_to(b)
	var n := int(d / 18.0)
	for i in n:
		if i % 2 == 0:
			draw_line(a.lerp(b, float(i) / n), a.lerp(b, float(i + 1) / n), c, 3.0)

func _title(f: Font, p: Vector2, s: String, size: int, c: Color) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(f, p - Vector2(w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	draw_string(f, p - Vector2(w / 2, 0), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
