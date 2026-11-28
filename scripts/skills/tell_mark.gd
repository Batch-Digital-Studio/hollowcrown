class_name TellMark
extends Node2D
## A monster's tell: the short warning before a normal attack lands (test chapter). Melee shows the
## arc that will be hit, ranged shows the line the shot will fly, casts show a ring. It fills up as
## the attack comes, so you can read it and step out. Drawn on the ground in both views.

var user: Enemy
var skill: Dictionary
var aim := Vector2.ZERO
var dur := 0.4
var _t := 0.0

func _ready() -> void:
	z_index = 3

func _process(delta: float) -> void:
	_t += delta
	if _t >= dur or not is_instance_valid(user) or user.dead or user.tell_t <= 0.0:
		queue_free()
		return
	global_position = user.global_position
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / dur, 0.0, 1.0)
	var c := Color(1.0, 0.35, 0.2) if not user.rare else Color(1.0, 0.75, 0.25)
	var dir := (aim - global_position).normalized()
	if dir == Vector2.ZERO:
		dir = user.facing
	var b: String = String(skill.get("behavior", ""))
	if b == "melee_arc":
		var r: float = float(skill.get("radius", 50.0)) + user.radius
		var half := deg_to_rad(float(skill.get("arc_deg", 90.0))) * 0.5
		var pts := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			pts.append(Vector2.RIGHT.rotated(dir.angle() - half + 2.0 * half * i / 12.0) * r)
		draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.12 + 0.18 * k))
		var inner := PackedVector2Array([Vector2.ZERO])
		for i in 13:
			inner.append(Vector2.RIGHT.rotated(dir.angle() - half + 2.0 * half * i / 12.0) * r * k)
		draw_colored_polygon(inner, Color(c.r, c.g, c.b, 0.3))
		draw_polyline(pts.slice(1), Color(c.r, c.g, c.b, 0.85), 2.0, true)
	elif b == "projectile":
		var L := 320.0
		var w: float = maxf(10.0, float(skill.get("radius", 10.0)))
		var side := dir.orthogonal() * w
		var poly := PackedVector2Array([side, dir * L + side, dir * L - side, -side])
		draw_colored_polygon(poly, Color(c.r, c.g, c.b, 0.08 + 0.12 * k))
		draw_line(Vector2.ZERO, dir * L * k, Color(c.r, c.g, c.b, 0.8), 2.0, true)
	else:
		var r2 := user.radius * 2.2
		draw_arc(Vector2.ZERO, r2, 0, TAU, 32, Color(c.r, c.g, c.b, 0.8), 2.0, true)
		draw_circle(Vector2.ZERO, r2 * k, Color(c.r, c.g, c.b, 0.18))
