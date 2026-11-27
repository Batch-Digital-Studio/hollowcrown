class_name HudView
extends Control

var message := ""
var sub_message := ""
var message_t := 0.0
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	message_t = maxf(0.0, message_t - delta)
	queue_redraw()

func _draw() -> void:
	var g := Game.instance
	if g == null or g.player == null or g.state == "title":
		return
	var p := g.player
	var vs := get_viewport_rect().size
	var f := ThemeDB.fallback_font
	# Orbs
	_orb(Vector2(110, vs.y - 110), 78.0, p.life / p.max_life, Color(0.75, 0.08, 0.1), "%d / %d" % [int(ceil(p.life)), int(p.max_life)])
	_orb(Vector2(vs.x - 110, vs.y - 110), 78.0, p.mana / maxf(1.0, p.max_mana), Color(0.15, 0.3, 0.85), "%d / %d" % [int(p.mana), int(p.max_mana)])
	# Flask
	var fx := Vector2(220, vs.y - 92)
	draw_rect(Rect2(fx.x, fx.y, 38, 70), Color(0.05, 0.04, 0.05, 0.85))
	var fill := p.flask_charges / float(p.flask_max)
	draw_rect(Rect2(fx.x + 4, fx.y + 4 + 62 * (1.0 - fill), 30, 62 * fill), Color(0.5, 0.08, 0.12))
	draw_texture_rect(Art.tex("flask_big_red"), Rect2(fx.x + 3, fx.y + 19, 32, 32), false, Color(1, 1, 1, 0.45 + 0.55 * minf(1.0, p.flask_charges)))
	draw_rect(Rect2(fx.x, fx.y, 38, 70), Color(0.6, 0.42, 0.22), false, 2.0)
	_pad_glyph(f, Vector2(fx.x + 19, fx.y + 84), "LB" if PlayerInput.using_pad else "1")
	_text(f, Vector2(fx.x + 19, fx.y - 6), "%d" % int(p.flask_charges), 14, Color(1, 0.6, 0.6))
	# Skill bar
	var n := p.bar.size()
	var size := 66.0
	var gap := 8.0
	var total := n * size + (n - 1) * gap
	var x0 := vs.x / 2.0 - total / 2.0
	var y0 := vs.y - size - 26.0
	for i in n:
		var sid: String = p.bar[i]
		var r := Rect2(x0 + i * (size + gap), y0, size, size)
		draw_rect(r, Color(0.05, 0.045, 0.06, 0.92))
		if sid == "":
			draw_rect(r, Color(0.3, 0.28, 0.26), false, 1.0)
			_pad_glyph(f, Vector2(r.position.x + 13, r.position.y + 13), PlayerInput.labels()[i])
			continue
		var s: Dictionary = SkillsDB.SKILLS[sid]
		_skill_icon(r, sid, s)
		var cd: float = p.cooldowns.get(sid, 0.0)
		if cd > 0.0:
			var k := cd / float(s.get("cooldown", 1.0))
			draw_rect(Rect2(r.position.x, r.position.y + r.size.y * (1.0 - k), r.size.x, r.size.y * k), Color(0, 0, 0, 0.65))
			_text(f, r.get_center() + Vector2(0, 8), "%.1f" % cd, 18, Color.WHITE)
		if p.mana < float(s.get("cost", 0)):
			draw_rect(r, Color(0.1, 0.15, 0.6, 0.45))
		var held: bool = p.input.skill_held[i]
		draw_rect(r, Color(1.0, 0.82, 0.45) if held else Color(0.55, 0.4, 0.22), false, 2.0)
		_pad_glyph(f, Vector2(r.position.x + 13, r.position.y + 13), PlayerInput.labels()[i])
	# Class resources (Spirit, Kindling, Resolve, Focus) + Special
	var rx := x0 + total + 18.0
	var RES_COL := {"spirit": Color(0.45, 0.9, 0.35), "kindling": Color(1.0, 0.55, 0.2), "resolve": Color(1.0, 0.8, 0.4), "focus": Color(0.7, 1.0, 0.85)}
	for rname in p.resources():
		var mx := p.res_max(rname)
		var sr := Rect2(rx, y0 - 4, 16, size + 8)
		draw_rect(sr, Color(0.03, 0.03, 0.03, 0.9))
		var fr: float = clampf(float(p.res[rname]) / maxf(1.0, mx), 0.0, 1.0)
		var rc: Color = RES_COL.get(rname, Color.WHITE)
		if rname == "kindling":
			for k in int(mx):
				var cy := sr.end.y - 8 - k * (sr.size.y - 10) / maxf(1.0, mx - 1.0)
				draw_circle(Vector2(sr.get_center().x, cy), 6, rc if k < int(p.res.kindling) else Color(0.2, 0.15, 0.1))
		else:
			draw_rect(Rect2(rx + 2, sr.end.y - 2 - (sr.size.y - 4) * fr, 12, (sr.size.y - 4) * fr), rc)
		if rname == "focus" and p.res.focus >= 100.0:
			draw_rect(sr.grow(2), Color(0.8, 1.0, 0.6, 0.5 + 0.5 * sin(_t * 8.0)), false, 2.0)
		else:
			draw_rect(sr, rc.darkened(0.4), false, 1.5)
		rx += 24.0
	var spid: String = ClassesDB.class_def(p.class_id).get("special", "")
	if spid != "":
		var ss: Dictionary = SkillsDB.SKILLS[spid]
		var cost: Dictionary = ss.get("res_cost", {"spirit": ss.get("spirit_cost", 100)})
		var ready: bool = p.can_pay(cost) and p.cooldowns.get(spid, 0.0) <= 0.0
		var a := 0.6 + 0.4 * sin(_t * 5.0) if ready else 0.5
		var rn: String = cost.keys()[0]
		_text_left(f, Vector2(rx + 4, y0 + 22), ss.name, 14, Color(0.6, 1.0, 0.5, a) if ready else Color(0.5, 0.55, 0.5, a))
		var cdtxt := ("  ·  %.0fs" % p.cooldowns[spid]) if p.cooldowns.get(spid, 0.0) > 0.0 else ""
		_text_left(f, Vector2(rx + 4, y0 + 42), ("LB+RB" if PlayerInput.using_pad else "T") + "  %d / %d %s%s" % [int(p.res.get(rn, 0)), int(cost[rn]), rn.capitalize(), cdtxt], 12, Color(0.7, 0.7, 0.7))
	if p.ward_max > 0.0:
		var wr := Rect2(110 - 78, vs.y - 110 - 78 - 16, 156, 8)
		draw_rect(wr, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(wr.position, Vector2(wr.size.x * p.ward_pool / p.ward_max, 8)), Color(0.5, 0.75, 1.0))
		_text(f, wr.get_center() + Vector2(0, -6), "Ember Ward %d" % int(p.ward_pool), 11, Color(0.7, 0.85, 1.0))
	if p.class_points() > 0 or p.rite_points() > 0:
		var a2 := 0.6 + 0.4 * sin(_t * 4.0)
		_text(f, Vector2(vs.x / 2.0, y0 - 52), "%s: %d Class, %d Rite point(s) to spend" % ["D-pad ↓" if PlayerInput.using_pad else "K", p.class_points(), p.rite_points()], 15, Color(0.6, 1.0, 0.5, a2))
	# XP bar
	var need := Player.xp_to_next(p.level)
	var xw := total + 140.0
	var xr := Rect2(vs.x / 2.0 - xw / 2.0, vs.y - 14, xw, 7)
	draw_rect(xr, Color(0, 0, 0, 0.8))
	draw_rect(Rect2(xr.position, Vector2(xr.size.x * float(p.xp) / need, xr.size.y)), Color(0.9, 0.7, 0.3))
	_text(f, Vector2(vs.x / 2.0, y0 - 10), "Level %d" % p.level, 15, Color(0.85, 0.78, 0.6))
	# Zone label
	_text_left(f, Vector2(24, 36), g.zone_title(), 20, Color(1.0, 0.82, 0.45))
	if g.fog and is_instance_valid(g.fog) and g.fog.lit:
		var vs0 := get_viewport_rect().size
		var k: float = g.fog.depth01()
		draw_rect(Rect2(Vector2.ZERO, vs0), Color(0.55, 0.5, 0.46, 0.10 + 0.16 * k))
		for i0 in 5:
			var rr := vs0.length() * (0.55 + i0 * 0.08)
			draw_arc(vs0 / 2.0, rr, 0, TAU, 48, Color(0.5, 0.46, 0.42, 0.06 + 0.05 * k), 120.0)
		var ft := "Ember Fog  %ds  ·  %d slain" % [int(ceil(EmberFog.DURATION - g.fog.t)), g.fog.kills]
		_text_left(f, Vector2(vs0.x / 2 - 110, 120), ft, 18, Color(0.9, 0.82, 0.72))
	if g.in_town:
		_text_left(f, Vector2(24, 60), "Safe haven   ·   H / pause menu: town   ·   Waystone: world map", 14, Color(0.7, 0.68, 0.65))
	else:
		_text_left(f, Vector2(24, 60), "Area Level %d   ·   Slain %d   ·   Remaining %d" % [g.area_level(), g.kills, g.enemies.size()], 14, Color(0.7, 0.68, 0.65))
	if g.writ:
		var wc := Color(0.5, 0.95, 0.6) if g.writ.done else (Color(0.8, 0.4, 0.35) if g.writ.failed else Color(0.95, 0.8, 0.5))
		_text_left(f, Vector2(24, 84), g.writ.text(), 14, wc)
	_text_left(f, Vector2(vs.x - Zone.W * 3.0 - 20, 40), "View — Inventory   ·   D-pad ↑ — Tree" if PlayerInput.using_pad else "I / Tab — Inventory   ·   P — Tree", 14, Color(0.6, 0.58, 0.55))
	if p.passive_points() > 0:
		var a := 0.6 + 0.4 * sin(_t * 4.0)
		_text(f, Vector2(vs.x / 2.0, y0 - 34), "%s — %d unspent Ember Point%s" % ["D-pad ↑" if PlayerInput.using_pad else "P", p.passive_points(), "s" if p.passive_points() > 1 else ""], 16, Color(1.0, 0.75, 0.35, a))
	# Minimap
	if g.minimap.tex and not g.inv_ui.visible:
		var ms := 3.0
		var mr := Rect2(vs.x - Zone.W * ms - 20, 56, Zone.W * ms, Zone.H * ms)
		draw_rect(mr.grow(4), Color(0.02, 0.02, 0.03, 0.55))
		draw_texture_rect(g.minimap.tex, mr, false)
		draw_rect(mr.grow(4), Color(0.6, 0.42, 0.22, 0.8), false, 1.5)
		var pp := mr.position + p.global_position / Zone.CELL * ms
		draw_circle(pp, 4.0, Color(1.0, 0.85, 0.4))
		if g.boss and is_instance_valid(g.boss) and not g.boss.dead:
			var bc := Vector2i(g.boss.global_position / Zone.CELL)
			if g.minimap.is_revealed(bc) or g.zone and bc == g.zone.boss_cell:
				var bp := mr.position + g.boss.global_position / Zone.CELL * ms
				draw_circle(bp, 6.0, Color(1.0, 0.35, 0.1, 0.4 + 0.3 * sin(_t * 4.0)))
				draw_circle(bp, 3.0, Color(1.0, 0.45, 0.15))
		for e in g.enemies:
			if e.rarity == "rare" and g.minimap.is_revealed(Vector2i(e.global_position / Zone.CELL)):
				draw_circle(mr.position + e.global_position / Zone.CELL * ms, 2.5, Color(1.0, 0.85, 0.3))
		for c in g.fx_node.get_children():
			if c is Portal:
				draw_circle(mr.position + c.global_position / Zone.CELL * ms, 5.0, Color(0.7, 0.5, 1.0))
	# Boss bar
	if g.boss and is_instance_valid(g.boss) and not g.boss.dead and g.boss.aggro:
		var bw := 640.0
		var br := Rect2(vs.x / 2 - bw / 2, 34, bw, 18)
		draw_rect(br.grow(3), Color(0, 0, 0, 0.85))
		var bc: Color = g.boss.def.get("light", Color(0.8, 0.3, 0.1)).darkened(0.25)
		draw_rect(Rect2(br.position, Vector2(bw * g.boss.life / g.boss.max_life, 18)), bc)
		draw_rect(Rect2(br.position + Vector2(bw * 0.5 - 1, 0), Vector2(2, 18)), Color(1, 1, 1, 0.5))   # phase 2 mark
		draw_rect(br.grow(3), Color(1.0, 0.7, 0.3), false, 2.0)
		var title := String(g.boss.def.name).to_upper()
		if g.boss.brain and g.boss.brain.shielded():
			title += "  ·  SHIELDED (kill his guard)"
		elif g.boss.brain and g.boss.brain.stagger > 0.0:
			title += "  ·  STAGGERED"
		_text(f, Vector2(vs.x / 2, 26), title, 18, Color(1.0, 0.78, 0.4))
	# Message
	if message_t > 0.0:
		var a := minf(1.0, message_t) * minf(1.0, (3.5 - message_t) * 3.0)
		_text(f, Vector2(vs.x / 2, vs.y * 0.28), message, 46, Color(1.0, 0.82, 0.45, a))
		if sub_message != "":
			_text(f, Vector2(vs.x / 2, vs.y * 0.28 + 40), sub_message, 20, Color(0.85, 0.8, 0.75, a))

func _orb(c: Vector2, r: float, frac: float, col: Color, label: String) -> void:
	frac = clampf(frac, 0.0, 1.0)
	draw_circle(c, r + 6, Color(0.03, 0.03, 0.04, 0.95))
	draw_circle(c, r, col.darkened(0.8))
	# liquid: draw horizontal slices below the fill line
	var top := c.y + r - 2.0 * r * frac
	var step := 3.0
	var y := top
	while y < c.y + r:
		var dy := y - c.y
		var hw := sqrt(maxf(0.0, r * r - dy * dy))
		var wave := sin(_t * 3.0 + y * 0.05) * 2.0 if y - top < 6 else 0.0
		draw_rect(Rect2(c.x - hw, y + wave, hw * 2, step + 0.5), col.lerp(col.darkened(0.5), (y - top) / (2 * r)))
		y += step
	draw_circle(c + Vector2(-r * 0.35, -r * 0.4), r * 0.25, Color(1, 1, 1, 0.08))
	draw_arc(c, r + 3, 0, TAU, 64, Color(0.6, 0.42, 0.22), 3.0, true)
	_text(ThemeDB.fallback_font, c + Vector2(0, 6), label, 15, Color.WHITE)

func _skill_icon(r: Rect2, sid: String, s: Dictionary) -> void:
	var c: Color = s.color
	var m := r.get_center()
	match s.behavior:
		"projectile":
			draw_line(m + Vector2(-18, 14), m + Vector2(10, -10), c.darkened(0.2), 6.0, true)
			draw_circle(m + Vector2(12, -12), 9, c)
			draw_circle(m + Vector2(12, -12), 4, Color(1, 1, 0.9))
		"melee_arc":
			draw_arc(m + Vector2(-8, 10), 26, -PI * 0.9, -PI * 0.1, 16, c, 5.0, true)
			draw_line(m + Vector2(-14, 14), m + Vector2(14, -14), Color(0.8, 0.78, 0.75), 4.0, true)
		"nova":
			for i in 3:
				draw_arc(m, 8 + i * 8, 0, TAU, 24, Color(c.r, c.g, c.b, 1.0 - i * 0.25), 3.0, true)
		"chain":
			var pts := PackedVector2Array([m + Vector2(-20, 14), m + Vector2(-6, -2), m + Vector2(2, 8), m + Vector2(20, -16)])
			draw_polyline(pts, c, 4.0, true)
			for pt in pts:
				draw_circle(pt, 3, Color.WHITE)
		"blink", "rush", "vault":
			draw_line(m + Vector2(-18, 10), m + Vector2(14, -8), c, 4.0, true)
			draw_circle(m + Vector2(16, -9), 6, c.lightened(0.3))
			draw_circle(m + Vector2(-18, 10), 3, c)
		"wall", "fissure":
			for k in 4:
				draw_rect(Rect2(m + Vector2(-18 + k * 10, -10 + (k % 2) * 6), Vector2(7, 18)), c)
		"prison":
			draw_rect(Rect2(m - Vector2(13, 13), Vector2(26, 26)), c, false, 3.0)
			draw_line(m - Vector2(13, 13), m + Vector2(13, 13), c, 2.0)
		"lance":
			draw_line(m + Vector2(-20, 0), m + Vector2(20, 0), c, 6.0)
			draw_line(m + Vector2(-20, 0), m + Vector2(20, 0), Color(1, 1, 0.8), 2.0)
		"warcry":
			for k in 3:
				draw_arc(m + Vector2(-10, 0), 8 + k * 7, -0.8, 0.8, 10, c, 2.5, true)
		"buff", "hunters_moon", "cataclysm":
			draw_circle(m, 14, Color(c.r, c.g, c.b, 0.4))
			draw_arc(m, 14, 0, TAU, 20, c, 3.0, true)
			draw_line(m + Vector2(0, 8), m + Vector2(0, -8), c, 3.0)
			draw_line(m + Vector2(-6, -2), m + Vector2(0, -8), c, 3.0)
			draw_line(m + Vector2(6, -2), m + Vector2(0, -8), c, 3.0)
		"rain":
			for k in 4:
				draw_line(m + Vector2(-14 + k * 9, -16), m + Vector2(-18 + k * 9, 14), c, 2.0)
		"companion":
			draw_colored_polygon(PackedVector2Array([m + Vector2(-20, -6), m, m + Vector2(-4, 6)]), c)
			draw_colored_polygon(PackedVector2Array([m + Vector2(20, -6), m, m + Vector2(4, 6)]), c)
		"raise", "grand_rite":
			draw_circle(m + Vector2(0, -6), 10, c)
			draw_rect(Rect2(m + Vector2(-12, 4), Vector2(24, 14)), c.darkened(0.4))
			draw_line(m + Vector2(-16, 20), m + Vector2(16, 20), c, 3.0)
		"curse":
			draw_arc(m, 16, 0, TAU, 20, c, 3.0, true)
			draw_line(m + Vector2(-11, 0), m + Vector2(11, 0), c, 3.0)
			draw_line(m + Vector2(0, -11), m + Vector2(0, 11), c, 3.0)
		"totem":
			draw_rect(Rect2(m + Vector2(-8, -20), Vector2(16, 40)), Color(0.5, 0.48, 0.42))
			draw_rect(Rect2(m + Vector2(-4, -8), Vector2(8, 8)), c)
		"beam":
			draw_line(m + Vector2(-20, 14), m + Vector2(18, -14), c, 4.0, true)
			draw_circle(m + Vector2(18, -14), 6, c.lightened(0.3))
		"eruption":
			for k in 4:
				draw_line(m + Vector2(-15 + k * 10, 20), m + Vector2(-12 + k * 10 + sin(k) * 4, -14 + (k % 2) * 6), c, 4.0, true)
		"corpse_burst":
			draw_circle(m, 12, c)
			for k in 8:
				draw_line(m, m + Vector2.RIGHT.rotated(k * TAU / 8.0) * 22, c.lightened(0.2), 2.0)
		"ground":
			draw_circle(m + Vector2(0, 8), 20, Color(c.r, c.g, c.b, 0.35))
			for i in 5:
				var x := -16 + i * 8
				draw_line(m + Vector2(x + 6, -20), m + Vector2(x, 4), c, 3.0, true)

const PAD_COLORS := {"A": Color(0.35, 0.8, 0.3), "B": Color(0.9, 0.25, 0.2), "X": Color(0.25, 0.5, 0.95), "Y": Color(0.95, 0.8, 0.2)}

## Button glyph: coloured circle for face buttons, plain text otherwise.
func _pad_glyph(f: Font, c: Vector2, label: String) -> void:
	if PAD_COLORS.has(label):
		draw_circle(c, 10, Color(0.05, 0.05, 0.06))
		draw_circle(c, 8.5, PAD_COLORS[label])
		_text(f, c + Vector2(0, 5), label, 13, Color.WHITE)
	elif label in ["RB", "LB", "RT", "LT"]:
		draw_rect(Rect2(c - Vector2(14, 8), Vector2(28, 16)), Color(0.15, 0.15, 0.17))
		draw_rect(Rect2(c - Vector2(14, 8), Vector2(28, 16)), Color(0.6, 0.6, 0.65), false, 1.0)
		_text(f, c + Vector2(0, 5), label, 11, Color.WHITE)
	else:
		_text(f, c + Vector2(0, 4), label, 12, Color(0.9, 0.9, 0.9))

func _text(f: Font, pos: Vector2, s: String, size: int, c: Color) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string_outline(f, Vector2(pos.x - w / 2, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, c.a * 0.9))
	draw_string(f, Vector2(pos.x - w / 2, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func _text_left(f: Font, pos: Vector2, s: String, size: int, c: Color) -> void:
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.9))
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
