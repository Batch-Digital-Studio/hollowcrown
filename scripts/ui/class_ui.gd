class_name ClassUI
extends Control
## Class screen (K / D-pad Down): class skill tree, Rite specializations and the skill bar.
## Mouse or controller cursor: click = take / add / select, right-click = refund.

var _t := 0.0
var _hover := {}          # what's under the cursor: {kind, ...}
var _selected_rite := ""
var _rects: Array = []    # [{rect, kind, ...}] rebuilt every draw
var _class_tab := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

func toggle() -> void:
	visible = not visible
	get_tree().paused = visible
	_selected_rite = ""

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	var m := Game.pointer()
	_hover = {}
	for r in _rects:
		if r.rect.has_point(m):
			_hover = r
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var p := Game.instance.player
	if p == null or _hover.is_empty():
		return
	var h := _hover
	if event.button_index == MOUSE_BUTTON_LEFT:
		match h.kind:
			"node":
				if p.take_node(h.cls, h.b, h.i):
					FX.sound("pickup", null, -4.0, 0.0)
			"spec":
				if p.add_spec(h.skill, h.spec):
					FX.sound("pickup", null, -6.0, 0.1)
			"rite":
				_selected_rite = h.skill if _selected_rite != h.skill else ""
			"slot":
				if _selected_rite != "":
					var old := p.bar.find(_selected_rite)
					if old >= 0:
						p.bar[old] = p.bar[h.slot]
					p.bar[h.slot] = _selected_rite
					_selected_rite = ""
					FX.sound("pickup", null, -6.0, 0.0)
					Game.instance.inv_ui.refresh()
			"class2":
				if p.choose_second_class(h.cls):
					FX.sound("levelup", null, -2.0, 0.0)
			"tab":
				_class_tab = h.idx
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		match h.kind:
			"node":
				if not p.refund_node(h.cls, h.b, h.i) and not p.can_respec():
					FX.text(p.global_position, "Respecs cost Ember Shards after level 20 (coming soon)", Color(1, 0.6, 0.4), 16)
			"spec":
				p.remove_spec(h.skill, h.spec)
			"slot":
				p.bar[h.slot] = ""

func _draw() -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	var p := g.player
	var vs := get_viewport_rect().size
	var f := ThemeDB.fallback_font
	_rects.clear()
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0.03, 0.03, 0.04, 0.97))
	var cls := p.classes()
	_class_tab = clampi(_class_tab, 0, cls.size() - 1)
	var cid: String = cls[_class_tab]
	var cdef := ClassesDB.class_def(cid)
	var gold := Color(1.0, 0.82, 0.45)
	_txt(f, Vector2(40, 48), "CLASS  ·  " + String(cdef.name).to_upper(), 28, gold)
	var info := "Class Points %d    ·    Rite Points %d    ·    %s" % [p.class_points(), p.rite_points(),
		"Respecs free until level %d" % Player.FREE_RESPEC_LEVEL if p.can_respec() else "Respecs need Ember Shards"]
	_txt(f, Vector2(40, 78), info, 16, Color(0.95, 0.75, 0.45) if p.class_points() + p.rite_points() > 0 else Color(0.65, 0.62, 0.6))
	var help := "A take / add / select   ·   X refund   ·   B close" if PlayerInput.using_pad else "Click take / add / select   ·   Right-click refund   ·   K / Esc close"
	_txt(f, Vector2(vs.x - 40 - f.get_string_size(help, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x, 48), help, 15, Color(0.6, 0.58, 0.55))
	# class tabs (dual-class)
	if cls.size() > 1:
		for i in cls.size():
			var r := Rect2(40 + i * 200, 92, 190, 30)
			_rects.append({"rect": r, "kind": "tab", "idx": i})
			draw_rect(r, Color(0.15, 0.12, 0.1) if i == _class_tab else Color(0.07, 0.06, 0.07))
			_txt(f, r.position + Vector2(10, 21), ClassesDB.class_def(cls[i]).name, 15, gold if i == _class_tab else Color(0.7, 0.7, 0.7))
	# ---- class tree: three branch columns ----
	var branches: Array = cdef.get("branches", [])
	if branches.is_empty():
		_txt(f, Vector2(40, 160), "The classic Kindled has no class tree.", 18, Color(0.8, 0.8, 0.8))
		_txt(f, Vector2(40, 188), "Start a New Kindled and pick the Bog Shaman to try the class system.", 16, Color(0.65, 0.62, 0.6))
	var col_w := 245.0
	for bi in branches.size():
		var br: Dictionary = branches[bi]
		var x := 40.0 + bi * (col_w + 14.0)
		_txt(f, Vector2(x, 150), br.name, 20, br.color)
		for ni in br.nodes.size():
			var n: Dictionary = br.nodes[ni]
			var r := Rect2(x, 166 + ni * 64, col_w, 54)
			var taken := p.node_taken(cid, bi, ni)
			var avail := p.can_take_node(cid, bi, ni)
			_rects.append({"rect": r, "kind": "node", "cls": cid, "b": bi, "i": ni, "node": n})
			var bg := Color(0.07, 0.065, 0.075)
			if taken:
				bg = Color(br.color.r * 0.25, br.color.g * 0.25, br.color.b * 0.25)
			draw_rect(r, bg)
			var border: Color = br.color if taken else (br.color.darkened(0.2) if avail else Color(0.25, 0.24, 0.26))
			if avail:
				border.a = 0.6 + 0.4 * sin(_t * 5.0)
			draw_rect(r, border, false, 3.0 if n.type == "notable" else (2.0 if n.type == "rite" else 1.0))
			if ni > 0:
				draw_line(Vector2(x + col_w / 2, r.position.y - 10), Vector2(x + col_w / 2, r.position.y), border, 2.0)
			var title: String = n.name
			if n.type == "rite":
				title = "Rite: " + title
			_txt(f, r.position + Vector2(10, 22), title, 15, Color(1, 1, 1) if taken else Color(0.8, 0.78, 0.75))
			_txt(f, r.position + Vector2(10, 43), _node_line(n), 12, Color(0.6, 0.75, 0.95) if taken else Color(0.5, 0.5, 0.55))
	# second class
	if p.level >= Player.DUAL_CLASS_LEVEL and p.class2_id == "" and p.class_id != "classic":
		var y := 700.0
		_txt(f, Vector2(40, y), "Choose your second class:", 16, gold)
		var any := false
		var x2 := 260.0
		for c in ClassesDB.CLASSES:
			var d: Dictionary = ClassesDB.CLASSES[c]
			if c == p.class_id or c == "classic":
				continue
			var r := Rect2(x2, y - 20, 170, 30)
			var ok: bool = d.get("built", false)
			_rects.append({"rect": r, "kind": "class2" if ok else "none", "cls": c})
			draw_rect(r, Color(0.08, 0.07, 0.08))
			draw_rect(r, d.color if ok else Color(0.3, 0.3, 0.3), false, 1.0)
			_txt(f, r.position + Vector2(8, 21), d.name + ("" if ok else " (stage B)"), 13, Color(0.9, 0.9, 0.9) if ok else Color(0.5, 0.5, 0.5))
			x2 += 180
			any = any or ok
	# ---- Rites + specializations ----
	var rx := 830.0
	_txt(f, Vector2(rx, 150), "Rites and specializations", 20, gold)
	var y0 := 166.0
	var rites: Array = p.unlocked_rites()
	for ri in rites.size():
		var sid: String = rites[ri]
		var sk: Dictionary = SkillsDB.SKILLS[sid]
		var rr := Rect2(rx, y0 + ri * 52, 200, 46)
		_rects.append({"rect": rr, "kind": "rite", "skill": sid})
		var sel := _selected_rite == sid
		draw_rect(rr, Color(0.14, 0.11, 0.08) if sel else Color(0.07, 0.065, 0.075))
		draw_rect(rr, gold if sel else Color(0.35, 0.3, 0.25), false, 2.0 if sel else 1.0)
		draw_circle(rr.position + Vector2(16, 23), 8, sk.color)
		_txt(f, rr.position + Vector2(32, 20), sk.name, 15, Color(1, 1, 1))
		var on_bar := p.bar.find(sid)
		_txt(f, rr.position + Vector2(32, 38), ("On bar: " + PlayerInput.labels()[on_bar]) if on_bar >= 0 else "Select, then pick a slot", 11, Color(0.6, 0.58, 0.55))
		var sx := rx + 210
		for sp in ClassesDB.SPECS.get(sid, []):
			var rank := p.spec_rank(sid, sp.id)
			var sr := Rect2(sx, rr.position.y, 98, 46)
			_rects.append({"rect": sr, "kind": "spec", "skill": sid, "spec": sp.id, "def": sp})
			draw_rect(sr, Color(0.1, 0.16, 0.1) if rank > 0 else Color(0.06, 0.06, 0.07))
			var full := rank >= int(sp.max)
			draw_rect(sr, Color(0.55, 0.9, 0.45) if rank > 0 else Color(0.25, 0.25, 0.27), false, 2.0 if full else 1.0)
			_txt(f, sr.position + Vector2(6, 18), _short(sp.name, 13), 12, Color(0.9, 0.9, 0.9))
			_txt(f, sr.position + Vector2(6, 37), "%d / %d" % [rank, int(sp.max)], 12, Color(0.55, 0.9, 0.45) if rank > 0 else Color(0.55, 0.55, 0.55))
			sx += 104
	# ---- skill bar ----
	var by := vs.y - 110
	_txt(f, Vector2(rx, by - 14), "Skill bar" + ("  ·  pick a slot for " + SkillsDB.SKILLS[_selected_rite].name if _selected_rite != "" else ""), 16, gold)
	for i in p.bar.size():
		var r := Rect2(rx + i * 84, by, 76, 76)
		_rects.append({"rect": r, "kind": "slot", "slot": i})
		draw_rect(r, Color(0.07, 0.065, 0.075))
		draw_rect(r, gold if _selected_rite != "" else Color(0.45, 0.35, 0.22), false, 2.0)
		var sid2: String = p.bar[i]
		if sid2 != "":
			var sk2: Dictionary = SkillsDB.SKILLS[sid2]
			draw_circle(r.get_center() + Vector2(0, 4), 16, sk2.color)
			_txt(f, Vector2(r.position.x + 4, r.end.y - 6), _short(sk2.name, 11), 11, Color(0.9, 0.9, 0.9))
		_txt(f, r.position + Vector2(6, 16), PlayerInput.labels()[i], 13, Color(0.85, 0.85, 0.85))
	if cdef.has("special"):
		var spk: Dictionary = SkillsDB.SKILLS[cdef.special]
		_txt(f, Vector2(rx + 6 * 84 + 10, by + 30), "Special: " + spk.name, 15, Color(0.6, 1.0, 0.5))
		_txt(f, Vector2(rx + 6 * 84 + 10, by + 52), ("LB + RB" if PlayerInput.using_pad else "T") + "  ·  %d Spirit" % int(spk.get("spirit_cost", 0)), 13, Color(0.65, 0.62, 0.6))
	if PlayerInput.using_pad:
		var mp := Game.pointer()
		draw_arc(mp, 10, 0, TAU, 20, gold, 2.0, true)
	if not _hover.is_empty():
		_tooltip(_hover)

func _node_line(n: Dictionary) -> String:
	if n.type == "rite":
		return _short(SkillsDB.SKILLS[n.rite].get("desc", ""), 34)
	if n.has("desc"):
		return _short(n.desc, 34)
	var parts: Array = []
	for k in n.stats:
		parts.append(PassivesDB.describe(k, n.stats[k]))
	return _short(", ".join(parts), 34)

func _short(s: String, n: int) -> String:
	return s if s.length() <= n else s.substr(0, n - 1) + "…"

func _tooltip(h: Dictionary) -> void:
	var lines: Array = []
	match h.kind:
		"node":
			var n: Dictionary = h.node
			lines.append([n.name, Color(1.0, 0.82, 0.45)])
			if n.type == "rite":
				var sk: Dictionary = SkillsDB.SKILLS[n.rite]
				lines.append(["Unlocks the Rite " + sk.name, Color(0.6, 1.0, 0.5)])
				lines.append([sk.get("desc", ""), Color(0.8, 0.78, 0.75)])
			else:
				if n.has("desc"):
					lines.append([n.desc, Color(0.8, 0.78, 0.75)])
				for k in n.stats:
					lines.append([PassivesDB.describe(k, n.stats[k]), Color(0.55, 0.7, 1.0)])
		"spec":
			var sp: Dictionary = h.def
			lines.append([sp.name + "  (%d ranks)" % int(sp.max), Color(0.6, 1.0, 0.5)])
			if sp.has("desc"):
				lines.append([sp.desc, Color(0.8, 0.78, 0.75)])
			for k in sp.get("stats", {}):
				lines.append([PassivesDB.describe(k, sp.stats[k]) + " per rank", Color(0.55, 0.7, 1.0)])
			for k in sp.get("skill", {}):
				lines.append(["+%s %s per rank" % [str(sp.skill[k]), k], Color(0.55, 0.7, 1.0)])
		"rite":
			var sk: Dictionary = SkillsDB.SKILLS[h.skill]
			lines.append([sk.name, Color(1.0, 0.82, 0.45)])
			lines.append([sk.get("desc", ""), Color(0.8, 0.78, 0.75)])
			lines.append(["Mana %d%s" % [int(sk.get("cost", 0)), ("  ·  Cooldown %.1fs" % float(sk.cooldown)) if sk.has("cooldown") else ""], Color(0.6, 0.6, 0.65)])
		_:
			return
	var f := ThemeDB.fallback_font
	var w := 0.0
	for l in lines:
		w = maxf(w, f.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	w += 28
	var hgt := lines.size() * 21 + 16
	var vs := get_viewport_rect().size
	var m := Game.pointer() + Vector2(18, 16)
	m.x = minf(m.x, vs.x - w - 10)
	m.y = minf(m.y, vs.y - hgt - 10)
	draw_rect(Rect2(m, Vector2(w, hgt)), Color(0.03, 0.025, 0.035, 0.98))
	draw_rect(Rect2(m, Vector2(w, hgt)), Color(0.6, 0.45, 0.25), false, 2.0)
	var y := m.y + 24
	for l in lines:
		_txt(f, Vector2(m.x + 14, y), l[0], 15, l[1])
		y += 21

func _txt(f: Font, pos: Vector2, s: String, size: int, c: Color) -> void:
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
