class_name Projectile
extends Node2D

var skill: Dictionary
var user: Actor
var user_stats: StatBlock
var faction := ""
var vel := Vector2.ZERO
var radius := 10.0
var travel := 0.0
var max_range := 800.0
var pierce := 0
var hit := {}
var color := Color.WHITE
var _trail: Array = []
var _glow: Sprite2D
var _zap_t := 0.0

func setup(s: Dictionary, u: Actor, pos: Vector2, dir: Vector2) -> void:
	skill = s
	user = u
	user_stats = u.cast_stats if u.cast_stats != null else u.stats
	faction = u.faction
	position = pos
	var speed: float = s.get("speed", 600.0) * (u.cast_stats if u.cast_stats != null else u.stats).inc_mult(["inc_projectile_speed"])
	vel = dir * speed
	radius = s.get("radius", 10.0)
	max_range = s.get("range", 800.0)
	pierce = int(user_stats.get_stat("pierce_add")) + int(s.get("pierce", 0))
	color = s.color
	z_index = 8

func _ready() -> void:
	_glow = FX.make_glow(color, radius * 4.0)
	add_child(_glow)

func _physics_process(delta: float) -> void:
	var g := Game.instance
	if g == null:
		queue_free()
		return
	var step := vel * delta
	position += step
	travel += step.length()
	_trail.push_front(position)
	if _trail.size() > 8:
		_trail.pop_back()
	queue_redraw()
	if travel > max_range or g.is_wall(position):
		_pop()
		return
	if skill.has("zap_interval"):
		_zap_t -= delta
		if _zap_t <= 0.0:
			_zap_t = float(skill.zap_interval)
			var pts: Array = []
			for t in g.targets_in_circle(faction, position, float(skill.zap_radius)):
				t.take_hit(Damage.roll_hit(skill, user_stats, g.rng), user if is_instance_valid(user) else null)
				pts.append(t.global_position)
				if pts.size() >= 3:
					break
			for p2 in pts:
				var lf := LightningFX.new()
				lf.points = [position, p2]
				lf.color = color
				g.fx_node.add_child(lf)
	for t in g.targets_in_circle(faction, position, radius):
		if hit.has(t):
			continue
		hit[t] = true
		var res := Damage.roll_hit(skill, user_stats, g.rng)
		if skill.has("vs_chilled") and t.is_chilled():
			for k in res.damage:
				res.damage[k] *= 1.0 + float(skill.vs_chilled) / 100.0
		var src_ok := user if is_instance_valid(user) else null
		t.take_hit(res, src_ok, vel, 110.0)
		if skill.has("root"):
			t.root_time = maxf(t.root_time, float(skill.root))
		if skill.has("pull") and src_ok:
			t.knock = (src_ok.global_position - t.global_position).normalized() * 1100.0
		if skill.has("vines"):
			var vs := {"kind": "attack", "base_damage": {"chaos": [3, 6]}, "radius": 70.0, "windup": 0.05, "root": 0.6, "color": Color(0.45, 0.8, 0.35), "crit": 5.0, "tags": []}
			var e := Eruption.new()
			e.setup(vs, src_ok if src_ok else t, position, user_stats)
			g.fx_node.add_child(e)
		if skill.has("hawk_mark") or user_stats.get_stat("hawk_mark") > 0.0:
			pass
		if skill.has("splash"):
			var sr: float = float(skill.splash) * user_stats.inc_mult(["inc_area"])
			for o in g.targets_in_circle(faction, position, sr):
				if o != t:
					o.take_hit(Damage.roll_hit(skill, user_stats, g.rng), user if is_instance_valid(user) else null, o.global_position - position, 60.0)
			FX.ring(position, sr, color, 0.3, 5.0)
		if faction == "player":
			FX.shake(2.0)
		if pierce <= 0:
			_pop()
			return
		pierce -= 1

func _pop() -> void:
	FX.burst(position, color, 10, 200.0, 6.0, 0.3)
	FX.flash(position, color, radius * 5.0, 0.15)
	queue_free()

func _draw() -> void:
	if skill.get("arrow", false):
		var d := vel.normalized()
		draw_line(-d * 26.0, d * 6.0, Color(0.55, 0.42, 0.3), 3.0, true)
		draw_line(d * 2.0, d * 10.0, color.lightened(0.4), 4.0, true)
		draw_line(-d * 26.0 + d.orthogonal() * 5.0, -d * 18.0, Color(0.9, 0.9, 0.85), 2.0)
		draw_line(-d * 26.0 - d.orthogonal() * 5.0, -d * 18.0, Color(0.9, 0.9, 0.85), 2.0)
		return
	for i in range(_trail.size() - 1, 0, -1):
		var a: Vector2 = _trail[i] - position
		var b: Vector2 = _trail[i - 1] - position
		var k := 1.0 - float(i) / _trail.size()
		var c := color
		c.a = k * 0.8
		draw_line(a, b, c, radius * 1.6 * k, true)
	draw_circle(Vector2.ZERO, radius, color.lightened(0.3))
	draw_circle(Vector2.ZERO, radius * 0.55, Color(1, 1, 0.95))
