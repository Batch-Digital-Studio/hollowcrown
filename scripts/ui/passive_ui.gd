class_name PassiveUI
extends Control
## The Ember Constellation screen. Drag to pan, wheel to zoom, click to allocate, right-click to refund.

var offset := Vector2.ZERO
var zoom := 0.45
var _drag := false
var _drag_moved := 0.0
var _hover := ""
var _t := 0.0
var _summary_before := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	if visible:
		var p := Game.instance.player
		# centre on this character's entry star, pulled a little toward the middle
		var root: String = PassivesDB.roots_for(p.classes())[0]
		offset = -PassivesDB.nodes()[root].pos * zoom * 0.7
		_summary_before = p.summary(p.equipment)

func _to_screen(p: Vector2) -> Vector2:
	return get_viewport_rect().size / 2.0 + Vector2(0, 40) + offset + p * zoom

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var m := Game.pointer()
	_hover = ""
	var tree := PassivesDB.nodes()
	for id in tree:
		var r := _radius(tree[id].type) * zoom + 4.0
		if _to_screen(tree[id].pos).distance_to(m) <= r:
			_hover = id
	queue_redraw()

func _radius(t: String) -> float:
	match t:
		"start": return 26.0
		"mastery": return 18.0
		"notable": return 20.0
		"keystone": return 28.0
	return 12.0

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var p := Game.instance.player
	if event is InputEventMouseButton:
		get_viewport().set_input_as_handled()
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			zoom = clampf(zoom * 1.1, 0.4, 1.6)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			zoom = clampf(zoom / 1.1, 0.4, 1.6)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_drag = true
				_drag_moved = 0.0
			else:
				_drag = false
				if _drag_moved < 6.0 and _hover != "":
					if p.passives.has(_hover) and PassivesDB.nodes()[_hover].type == "mastery":
						p.cycle_mastery(_hover)
						FX.sound("pickup", null, -6.0, 0.0)
						Game.instance.inv_ui.refresh()
					elif p.allocate(_hover):
						var n: Dictionary = PassivesDB.nodes()[_hover]
						FX.sound("levelup" if n.type == "keystone" else "pickup", null, -6.0 if n.type == "small" else -2.0, 0.0)
						Game.instance.inv_ui.refresh()
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _hover != "":
			if p.refund(_hover):
				FX.sound("hit", null, -10.0)
				Game.instance.inv_ui.refresh()
			elif p.passives.has(_hover) and not p.can_respec():
				FX.text(p.global_position, "Respec needs %d Ember Shards" % p.respec_cost(), Color(1, 0.6, 0.4), 16)
	elif event is InputEventMouseMotion and _drag:
		offset += event.relative
		_drag_moved += event.relative.length()

func _draw() -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	var p := g.player
	var vs := get_viewport_rect().size
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.015, 0.012, 0.025, 1.0))
	# star dust
	for i in 160:
		var h := float((i * 7919) % 1000) / 1000.0
		var h2 := float((i * 104729) % 1000) / 1000.0
		var sp := Vector2(h * vs.x, h2 * vs.y) + offset * 0.15
		draw_circle(Vector2(fposmod(sp.x, vs.x), fposmod(sp.y, vs.y)), 1.0 + h * 1.2, Color(1, 0.9, 0.8, 0.15 + 0.15 * sin(_t * 1.5 + i)))
	var tree := PassivesDB.nodes()
	# links
	for id in tree:
		for l in tree[id].links:
			if id < l:
				var a := _to_screen(tree[id].pos)
				var b := _to_screen(tree[l].pos)
				var lit: bool = p.passives.has(id) and p.passives.has(l)
				var half: bool = p.passives.has(id) or p.passives.has(l)
				var c: Color = tree[l].color if tree[l].type != "start" else tree[id].color
				if lit:
					draw_line(a, b, c, 5.0 * zoom, true)
				elif half:
					draw_line(a, b, Color(c.r, c.g, c.b, 0.45), 3.0 * zoom, true)
				else:
					draw_line(a, b, Color(0.35, 0.33, 0.4, 0.5), 2.0 * zoom, true)
	# nodes
	for id in tree:
		var n: Dictionary = tree[id]
		var c: Color = n.color
		var pos := _to_screen(n.pos)
		var r := _radius(n.type) * zoom
		var alloc: bool = p.passives.has(id)
		var avail: bool = p.can_allocate(id)
		if alloc:
			draw_circle(pos, r * 2.2, Color(c.r, c.g, c.b, 0.12))
		draw_circle(pos, r, Color(0.06, 0.05, 0.08))
		if alloc:
			draw_circle(pos, r * 0.78, c)
			draw_circle(pos, r * 0.35, Color(1, 1, 0.95))
		elif avail:
			draw_circle(pos, r * 0.78, Color(c.r, c.g, c.b, 0.25 + 0.15 * sin(_t * 5.0)))
		var ring := c if (alloc or avail) else Color(0.4, 0.38, 0.42)
		if n.type == "mastery":
			var dm := PackedVector2Array([pos + Vector2(0, -r * 1.3), pos + Vector2(r * 1.3, 0), pos + Vector2(0, r * 1.3), pos + Vector2(-r * 1.3, 0), pos + Vector2(0, -r * 1.3)])
			draw_polyline(dm, ring, 3.0, true)
		if n.type == "keystone":
			var pts := PackedVector2Array()
			for k in 9:
				pts.append(pos + Vector2.RIGHT.rotated(TAU * k / 8.0 + PI / 8.0) * r * 1.15)
			draw_polyline(pts, ring, 3.0, true)
		draw_arc(pos, r, 0, TAU, 32, ring, 2.5 if n.type != "small" else 1.5, true)
		if id == _hover:
			draw_arc(pos, r + 5, 0, TAU, 32, Color(1, 1, 1, 0.8), 2.0, true)
		if (n.type == "notable" and zoom >= 0.4) or n.type == "keystone" or n.type == "start" or (n.type == "mastery" and zoom >= 0.4):
			var label: String = n.name
			if n.type == "mastery" and alloc:
				label = n.options[int(p.masteries.get(id, 0))][0]
			var tw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
			draw_string_outline(f, pos + Vector2(-tw / 2, r + 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
			draw_string(f, pos + Vector2(-tw / 2, r + 18), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c if (alloc or avail) else Color(0.6, 0.58, 0.6))
	# header
	var pts_left := p.passive_points()
	var title := "THE EMBER CONSTELLATION"
	var tw2 := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
	draw_string(f, Vector2(vs.x / 2 - tw2 / 2, 50), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1.0, 0.82, 0.45))
	var sub := ("Ember Points: %d" + ("" if p.respec_cost() == 0 else ("  ·  refund %d shards" % p.respec_cost())) + "     ·     A allocate  ·  X refund  ·  Right stick pan  ·  LB/RB zoom  ·  B close" if PlayerInput.using_pad else "Ember Points: %d" + ("" if p.respec_cost() == 0 else ("  ·  refund %d shards" % p.respec_cost())) + "     ·     Click to allocate  ·  Right-click to refund  ·  Drag to pan  ·  Wheel to zoom  ·  P / Esc to close") % pts_left
	var tw3 := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	draw_string(f, Vector2(vs.x / 2 - tw3 / 2, 78), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.95, 0.75, 0.45) if pts_left > 0 else Color(0.6, 0.58, 0.55))
	# live stat deltas since opening
	var now := p.summary(p.equipment)
	var y := 120.0
	draw_string(f, Vector2(24, y), "Changes this visit", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.7, 0.68, 0.65))
	y += 24
	for k in now:
		var d: float = now[k] - float(_summary_before.get(k, 0.0))
		if absf(d) < 0.05:
			continue
		var txt := "%s  %+.1f" % [k, d] if k.ends_with("DPS") else "%s  %+d" % [k, int(round(d))]
		draw_string(f, Vector2(24, y), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.4, 1.0, 0.5) if d > 0 else Color(1.0, 0.4, 0.4))
		y += 22
	if PlayerInput.using_pad:
		var mp := Game.pointer()
		draw_arc(mp, 11, 0, TAU, 20, Color(1.0, 0.82, 0.45), 2.0, true)
	if _hover != "":
		_tooltip(tree[_hover], p)

func _tooltip(n: Dictionary, p: Player) -> void:
	var f := ThemeDB.fallback_font
	var lines: Array = [[n.name, n.color]]
	lines.append([n.type.capitalize() if n.type != "small" else "Passive", Color(0.6, 0.58, 0.6)])
	for k in n.stats:
		lines.append([PassivesDB.describe(k, n.stats[k]), Color(0.55, 0.7, 1.0)])
	if n.type == "mastery":
		var cur := int(p.masteries.get(_hover, 0))
		for i in n.options.size():
			var o: Array = n.options[i]
			var mark := "> " if p.passives.has(_hover) and i == cur else "   "
			var parts: Array = []
			for k in o[1]:
				parts.append(PassivesDB.describe(k, o[1][k]))
			lines.append([mark + o[0] + ": " + ", ".join(parts), Color(1.0, 0.85, 0.5) if mark != "   " else Color(0.65, 0.65, 0.7)])
	if n.desc != "":
		lines.append([n.desc, Color(0.8, 0.6, 0.35)])
	var w := 0.0
	for l in lines:
		w = maxf(w, f.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	w += 28
	var h := lines.size() * 21 + 16
	var m := Game.pointer() + Vector2(18, 14)
	var vs := get_viewport_rect().size
	m.x = minf(m.x, vs.x - w - 10)
	m.y = minf(m.y, vs.y - h - 10)
	draw_rect(Rect2(m, Vector2(w, h)), Color(0.03, 0.025, 0.04, 0.97))
	draw_rect(Rect2(m, Vector2(w, h)), n.color.darkened(0.2), false, 2.0)
	var y := m.y + 24
	for i in lines.size():
		draw_string(f, Vector2(m.x + 14, y), lines[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 17 if i == 0 else 15, lines[i][1])
		y += 21
