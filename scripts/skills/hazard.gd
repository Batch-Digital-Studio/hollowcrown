class_name Hazard
extends Node2D
## A telegraphed boss attack you can read and dodge.
## Shapes: "circle" (get out), "ring" (get IN: safe inside `inner`), "line" (sidestep).
## Optionally follows a target until `lock` seconds before it fires, and can leave a pool.

var shape := "circle"
var r := 120.0
var inner := 0.0
var length := 700.0
var width := 80.0
var dir := Vector2.RIGHT
var windup := 1.0
var lock := 0.4                 # stop following this long before impact
var follow: Node2D = null
var anchor: Node2D = null       # line hazards: start at this node (the boss)
var skill: Dictionary = {}
var user: Actor
var pool: Dictionary = {}       # ground effect skill left behind
var color := Color(1.0, 0.4, 0.2)
var knock := 380.0
var _t := 0.0

static func make(u: Actor, shp: String, pos: Vector2, sk: Dictionary, wu: float) -> Hazard:
	var h := Hazard.new()
	h.user = u
	h.shape = shp
	h.global_position = pos
	h.skill = sk
	h.windup = wu
	h.color = sk.get("color", Color(1.0, 0.4, 0.2))
	h.z_index = 0
	return h

func hits(p: Vector2) -> bool:
	var d := p - global_position
	match shape:
		"ring":
			return d.length() >= inner and d.length() <= r
		"line":
			var loc := d.rotated(-dir.angle())
			return loc.x >= 0.0 and loc.x <= length and absf(loc.y) <= width * 0.5
		_:
			return d.length() <= r

func _physics_process(delta: float) -> void:
	if not is_instance_valid(user) or user.dead:
		queue_free()
		return
	_t += delta
	if _t < windup - lock:
		if anchor and is_instance_valid(anchor):
			global_position = anchor.global_position
		if follow and is_instance_valid(follow):
			if shape == "line":
				dir = (follow.global_position - global_position).normalized()
			else:
				global_position = follow.global_position
	queue_redraw()
	if _t >= windup:
		_fire()

func _fire() -> void:
	var g := Game.instance
	if not skill.get("base_damage", {}).is_empty():
		var reach := r if shape != "line" else length + width
		for t in g.targets_in_circle(user.faction, global_position, reach):
			if hits(t.global_position):
				var res := Damage.roll_hit(skill, user.stats, g.rng)
				t.take_hit(res, user, t.global_position - global_position, knock)
	match shape:
		"line":
			for i in 6:
				FX.burst(global_position + dir * length * (i + 0.5) / 6.0, color, 10, 220.0, 7.0, 0.4)
		"ring":
			FX.ring(global_position, r, color, 0.4, 14.0)
			FX.burst(global_position, color, 30, r * 2.0, 8.0, 0.5)
		_:
			FX.ring(global_position, r, color, 0.35, 10.0)
			FX.burst(global_position, color, 26, r * 2.2, 8.0, 0.45)
	FX.sound("boom", global_position, -4.0)
	FX.shake(6.0)
	if not pool.is_empty():
		user.cast_stats = user.stats
		var ge := GroundEffect.new()
		ge.setup(pool, user, global_position)
		g.fx_node.add_child(ge)
	queue_free()

func _draw() -> void:
	var k := clampf(_t / windup, 0.0, 1.0)
	var c := color
	match shape:
		"ring":
			# danger band between inner and r; the inside is safe
			draw_arc(Vector2.ZERO, (inner + r) * 0.5, 0, TAU, 72, Color(c.r, c.g, c.b, 0.14), r - inner, true)
			draw_arc(Vector2.ZERO, inner + (r - inner) * (1.0 - k), 0, TAU, 72, Color(c.r, c.g, c.b, 0.9), 3.0, true)
			draw_arc(Vector2.ZERO, r, 0, TAU, 72, Color(c.r, c.g, c.b, 0.9), 3.0, true)
			draw_arc(Vector2.ZERO, inner, 0, TAU, 48, Color(0.6, 1.0, 0.6, 0.9), 3.0, true)
		"line":
			var rect_pts := PackedVector2Array([Vector2(0, -width / 2), Vector2(length, -width / 2), Vector2(length, width / 2), Vector2(0, width / 2)])
			var rot := Transform2D(dir.angle(), Vector2.ZERO)
			draw_colored_polygon(rot * rect_pts, Color(c.r, c.g, c.b, 0.14))
			var filled := PackedVector2Array([Vector2(0, -width / 2), Vector2(length * k, -width / 2), Vector2(length * k, width / 2), Vector2(0, width / 2)])
			draw_colored_polygon(rot * filled, Color(c.r, c.g, c.b, 0.3))
			draw_polyline(rot * (rect_pts + PackedVector2Array([rect_pts[0]])), Color(c.r, c.g, c.b, 0.9), 2.5, true)
		_:
			draw_circle(Vector2.ZERO, r, Color(c.r, c.g, c.b, 0.13))
			draw_circle(Vector2.ZERO, r * k, Color(c.r, c.g, c.b, 0.3))
			draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(c.r, c.g, c.b, 0.9), 3.0, true)
