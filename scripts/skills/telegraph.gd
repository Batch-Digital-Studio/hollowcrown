class_name Telegraph
extends Node2D
## Wind-up warning circle; fires its hit when full. Dodgeable.

var skill: Dictionary
var user: Actor
var radius := 100.0
var windup := 0.8
var _t := 0.0

func setup(s: Dictionary, u: Actor) -> void:
	skill = s
	user = u
	radius = float(s.radius)
	windup = float(s.get("windup", 0.8))
	global_position = u.global_position
	z_index = 0

func _physics_process(delta: float) -> void:
	if not is_instance_valid(user) or user.dead:
		queue_free()
		return
	global_position = user.global_position
	_t += delta
	queue_redraw()
	if _t >= windup:
		var g := Game.instance
		for t in g.targets_in_circle(user.faction, global_position, radius):
			var res := Damage.roll_hit(skill, user.stats, g.rng)
			t.take_hit(res, user, t.global_position - global_position, 420.0)
		FX.ring(global_position, radius, skill.color, 0.4, 12.0)
		FX.event3d("slam", global_position, ElementFx.of_skill(skill), radius)
		FX.burst(global_position, skill.color, 40, radius * 2.5, 9.0, 0.5)
		FX.shake(10.0)
		FX.sound("boom", global_position, 0.0)
		FX.rumble(0.3, 0.6, 0.25)
		queue_free()

func _draw() -> void:
	var k := _t / windup
	var c: Color = skill.color
	c.a = 0.12
	draw_circle(Vector2.ZERO, radius, c)
	c.a = 0.35
	draw_circle(Vector2.ZERO, radius * k, c)
	c.a = 0.9
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, c, 3.0, true)
