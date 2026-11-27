class_name GroundEffect
extends Node2D
## Persistent damaging area (Cinderfall).

var skill: Dictionary
var user: Actor
var user_stats: StatBlock
var faction := ""
var radius := 100.0
var duration := 4.0
var tick := 0.25
var _t := 0.0
var _tick_t := 0.0
var _ember_t := 0.0

func setup(s: Dictionary, u: Actor, pos: Vector2) -> void:
	skill = s
	user = u
	user_stats = u.cast_stats if u.cast_stats != null else u.stats
	faction = u.faction
	position = pos
	radius = float(s.radius) * user_stats.inc_mult(["inc_area"])
	duration = float(s.duration) * user_stats.inc_mult(["inc_duration"])
	tick = float(s.tick)
	z_index = 1

func _ready() -> void:
	var glow := FX.make_glow(skill.color, radius * 1.4)
	glow.modulate.a = 0.5
	add_child(glow)
	FX.ring(position, radius, skill.color, 0.35, 8.0)

func _physics_process(delta: float) -> void:
	_t += delta
	if float(skill.get("follow", 0.0)) > 0.0 and is_instance_valid(user):
		position = position.move_toward(user.global_position, 260.0 * delta)
	_tick_t += delta
	_ember_t -= delta
	if _ember_t <= 0.0:
		_ember_t = 0.05
		var p := position + Vector2.RIGHT.rotated(randf() * TAU) * randf() * radius
		FX.burst(p, skill.color, 3, 90.0, 7.0, 0.6)
	if _tick_t >= tick:
		_tick_t -= tick
		var g := Game.instance
		if g:
			if not skill.get("base_damage", {}).is_empty():
				for t in g.targets_in_circle(faction, position, radius):
					var res := Damage.roll_hit(skill, user_stats, g.rng)
					t.take_hit(res, user if is_instance_valid(user) else null)
					if skill.has("slow"):
						t.slow_time = maxf(t.slow_time, 0.5)
						t.slow_amt = float(skill.slow)
			if skill.has("aura") and is_instance_valid(user) and user.has_method("add_buff"):
				if user.global_position.distance_to(position) <= radius:
					user.add_buff("aura_" + skill.name, skill.aura, 0.5)
	if _t >= duration:
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.3)
		tw.tween_callback(queue_free)
		set_physics_process(false)
	queue_redraw()

func _draw() -> void:
	var c: Color = skill.color
	c.a = 0.16 + 0.05 * sin(_t * 9.0)
	draw_circle(Vector2.ZERO, radius, c)
	c.a = 0.6
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, c, 3.0, true)
