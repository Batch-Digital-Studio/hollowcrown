class_name Eruption
extends Node2D
## Swampcall: a warning ring, then tentacles burst from the ground, hit and root.

var skill: Dictionary
var user: Actor
var st: StatBlock
var radius := 140.0
var windup := 0.45
var root := 1.5
var _t := 0.0
var _fired := false
var _tentacles: Array = []
var style := "tentacle"    # tentacle | fissure | arrow | meteor

func setup(s: Dictionary, u: Actor, pos: Vector2, stats: StatBlock, delay: float = 0.0) -> void:
	skill = s
	user = u
	st = stats
	position = pos
	radius = float(s.radius) * stats.inc_mult(["inc_area"])
	windup = float(s.get("windup", 0.45)) + delay
	root = float(s.get("root", 1.5))
	z_index = 2
	for i in 7:
		var a := TAU * i / 7.0 + randf() * 0.5
		_tentacles.append([Vector2.RIGHT.rotated(a) * randf_range(0.15, 0.8) * radius, randf_range(50, 90), randf() * TAU])

func _process(delta: float) -> void:
	_t += delta
	if not _fired and _t >= windup:
		_fired = true
		var g := Game.instance
		if g:
			for t in g.targets_in_circle(user.faction if is_instance_valid(user) else "player", position, radius):
				t.take_hit(Damage.roll_hit(skill, st, g.rng), user if is_instance_valid(user) else null, t.global_position - position, 60.0)
				t.root_time = maxf(t.root_time, root)
		var bc: Color = Color(0.3, 0.5, 0.25) if style == "tentacle" else skill.color
		FX.burst(position, bc, 30 if style != "arrow" else 8, radius * 2.0, 9.0, 0.5)
		if style == "tentacle" or style == "meteor":
			FX.shake(5.0)
			FX.sound("boom", position, -8.0 if style == "tentacle" else -12.0)
			FX.rumble(0.2, 0.3, 0.15)
		elif style == "fissure":
			FX.sound("hit", position, -8.0)
	if _t >= windup + 0.9:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var c: Color = skill.color
	if style == "arrow":
		if not _fired:
			var k0 := _t / windup
			draw_line(Vector2(-30, -260) * (1.0 - k0), Vector2(-24, -210) * (1.0 - k0) + Vector2(0, 8), Color(0.9, 0.85, 0.7, 0.9), 3.0)
			draw_circle(Vector2.ZERO, radius * 0.3, Color(0, 0, 0, 0.25))
		else:
			draw_line(Vector2(-3, -26), Vector2(0, 0), Color(0.55, 0.42, 0.3), 3.0)
		return
	if style == "meteor":
		if not _fired:
			var k1 := _t / windup
			draw_circle(Vector2.ZERO, radius, Color(c.r, c.g, c.b, 0.12))
			draw_arc(Vector2.ZERO, radius * k1, 0, TAU, 32, Color(c.r, c.g, c.b, 0.6), 2.0, true)
			draw_circle(Vector2(0, -400) * (1.0 - k1), 10.0, c.lightened(0.3))
		else:
			var e1 := _t - windup
			draw_circle(Vector2.ZERO, radius * clampf(1.0 - e1 * 2.0, 0.0, 1.0), Color(c.r, c.g, c.b, 0.35))
		return
	if style == "fissure":
		if _fired:
			var e2 := clampf((_t - windup) * 3.0, 0.0, 1.0)
			var a := 1.0 - clampf((_t - windup - 0.4) * 2.0, 0.0, 1.0)
			draw_line(Vector2(-radius * e2, -4), Vector2(radius * e2, 4), Color(0.1, 0.05, 0.03, a), 10.0)
			draw_line(Vector2(-radius * e2, -4), Vector2(radius * e2, 4), Color(1.0, 0.5, 0.2, a), 3.0)
		return
	if not _fired:
		var k := _t / windup
		draw_circle(Vector2.ZERO, radius, Color(0.1, 0.2, 0.08, 0.35))
		draw_arc(Vector2.ZERO, radius * k, 0, TAU, 48, Color(c.r, c.g, c.b, 0.8), 3.0, true)
		draw_arc(Vector2.ZERO, radius, 0, TAU, 48, Color(c.r, c.g, c.b, 0.4), 2.0, true)
		return
	var e := _t - windup
	var grow := clampf(e * 6.0, 0.0, 1.0) * clampf((0.9 - e) * 3.0, 0.0, 1.0)
	draw_circle(Vector2.ZERO, radius * 0.9, Color(0.08, 0.14, 0.06, 0.5 * grow))
	for tt in _tentacles:
		var base: Vector2 = tt[0]
		var h: float = tt[1] * grow
		var pts := PackedVector2Array()
		for j in 8:
			var f := j / 7.0
			pts.append(base + Vector2(sin(_t * 9.0 + tt[2] + f * 3.0) * 10.0 * f, -h * f))
		draw_polyline(pts, Color(0.18, 0.35, 0.16), 12.0 * (1.0 - 0.3), true)
		draw_polyline(pts, Color(0.35, 0.65, 0.3), 5.0, true)
		draw_circle(pts[pts.size() - 1], 4.0, Color(0.6, 0.9, 0.5))
