class_name Totem
extends Actor
## A Grim Pillar: a stationary stone column that casts a linked Rite or wards allies.

var owner_actor: Actor
var skill: Dictionary
var linked := ""
var ward := false
var duration := 12.0
var interval := 0.6
var _cast_t := 0.0
var _t := 0.0
var _invuln := 0.0
var _light: PointLight2D
var _cast_stats: StatBlock

func setup(owner_: Actor, s: Dictionary, pos: Vector2, st: StatBlock) -> void:
	owner_actor = owner_
	skill = s
	faction = "player"
	level = owner_.level
	global_position = pos
	radius = 22.0
	display_name = "Grim Pillar"
	ward = s.get("ward", false)
	linked = s.get("linked", "")
	duration = float(s.duration) * st.inc_mult(["inc_totem_duration", "inc_duration"])
	interval = float(s.get("interval", 0.6)) / st.inc_mult(["totem_cast_speed", "inc_cast_speed"])
	stats = StatBlock.new()
	var hp := 120.0 * pow(1.12, level - 1) * st.inc_mult(["inc_totem_life"])
	stats.add("life_flat", hp)
	stats.add("armour", 40.0 * level)
	stats.add("res_fire", 40)
	stats.add("res_cold", 40)
	stats.add("res_lightning", 40)
	max_life = hp
	life = hp
	_invuln = 3.0 if st.get_stat("totem_cast_speed") >= 20.0 else 0.0
	_invuln = maxf(_invuln, Asc.ostat(owner_, "totem_invuln"))
	# Damage for the linked Rite: the owner's stats for that Rite, with totem modifiers.
	if linked != "" and owner_.has_method("stats_for"):
		_cast_stats = owner_.stats_for(linked).duplicate_block()
	else:
		_cast_stats = st.duplicate_block()
	_cast_stats.add("more_damage", float(s.get("totem_more", 0.0)))
	_cast_stats.add("inc_damage", st.get_stat("inc_totem_damage"))

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	if skill.get("banner", false):
		var flag := Art.sprite("wall_banner_red")
		flag.position = Vector2(14, -96)
		add_child(flag)
	else:
		var top := Art.sprite("column_top")
		top.position = Vector2(0, -96)
		add_child(top)
		var mid := Art.sprite("column_mid")
		mid.position = Vector2(0, -32)
		add_child(mid)
	var c: Color = skill.color
	_light = FX.make_light(c, 300.0 if ward else 220.0, 1.0)
	_light.position = Vector2(0, -70)
	add_child(_light)
	FX.burst(global_position, Color(0.6, 0.55, 0.45), 26, 220.0, 9.0, 0.6)
	FX.ring(global_position, 90.0, c, 0.4, 6.0)
	FX.shake(4.0)
	FX.sound("boom", global_position, -12.0)

func _physics_process(delta: float) -> void:
	if dead:
		return
	tick_common(delta)
	_t += delta
	_invuln = maxf(0.0, _invuln - delta)
	invulnerable = _invuln > 0.0
	if _t >= duration or not is_instance_valid(owner_actor):
		die(null)
		return
	var g := game()
	if skill.get("banner", false):
		var rb: float = float(skill.radius) * owner_actor.stats.inc_mult(["inc_area"])
		if is_instance_valid(g.player) and g.player.global_position.distance_to(global_position) <= rb:
			g.player.add_buff("banner", skill.aura, 0.5)
			g.player.gain_res("resolve", 6.0 * delta)
	elif ward:
		var r: float = float(skill.radius) * owner_actor.stats.inc_mult(["inc_area"])
		var allies: Array = [g.player] + g.allies
		for a in allies:
			if is_instance_valid(a) and not a.dead and a.global_position.distance_to(global_position) <= r:
				a.ward_time = 0.3
				a.ward_reduction = float(skill.get("reduction", 15.0)) / 100.0
				a.ward_regen = float(skill.get("regen", 1.0))
	elif linked != "":
		_cast_t -= delta
		if _cast_t <= 0.0:
			var best: Actor = null
			var bd := INF
			for e in g.targets_in_circle("player", global_position, 650.0):
				var d: float = e.global_position.distance_to(global_position)
				if d < bd and g.has_line_of_sight(global_position + Vector2(0, -60), e.global_position):
					bd = d
					best = e
			if best:
				_cast_t = interval
				_fire(best)
	queue_redraw()

func _fire(target: Actor) -> void:
	var s: Dictionary = SkillsDB.SKILLS[linked]
	var origin := global_position + Vector2(0, -90)
	var dir := (target.global_position + Vector2(0, -20) - origin).normalized()
	cast_stats = _cast_stats
	var p := Projectile.new()
	p.setup(s, self, origin, dir)
	game().fx_node.add_child(p)
	if Asc.ostat(self, "totem_link") > 0.0:
		var p2 := Projectile.new()
		p2.setup(s, self, origin, dir.rotated(0.22))
		game().fx_node.add_child(p2)
	FX.flash(origin, skill.color, 30.0, 0.12)

func _draw() -> void:
	var iso := IsoView.active
	if not iso:
		draw_set_transform(Vector2(0, 4), 0.0, Vector2(1.0, 0.4))
		draw_circle(Vector2.ZERO, 34, Color(0, 0, 0, 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var c: Color = skill.color
	var k := 1.0 - _t / duration
	if skill.get("banner", false):
		if not iso:
			draw_line(Vector2(0, 0), Vector2(0, -130), Color(0.45, 0.35, 0.25), 5.0)
			draw_circle(Vector2(0, -132), 5, Color(1.0, 0.8, 0.4))
		var rb: float = float(skill.radius) * owner_actor.stats.inc_mult(["inc_area"]) if is_instance_valid(owner_actor) else 240.0
		draw_arc(Vector2.ZERO, rb, 0, TAU, 64, Color(c.r, c.g, c.b, 0.35), 2.0, true)
		draw_arc(Vector2(0, 4), 24, -PI / 2, -PI / 2 + TAU * k, 24, Color(c.r, c.g, c.b, 0.7), 3.0, true)
		return
	# glowing runes climbing the pillar
	for i in (0 if iso else 3):
		var y := -30.0 - i * 34.0
		var a := 0.35 + 0.35 * sin(_t * 4.0 + i)
		draw_rect(Rect2(-6, y - 6, 12, 12), Color(c.r, c.g, c.b, a))
	draw_arc(Vector2(0, 4), 30, -PI / 2, -PI / 2 + TAU * k, 24, Color(c.r, c.g, c.b, 0.7), 3.0, true)
	if ward:
		var r: float = float(skill.radius) * owner_actor.stats.inc_mult(["inc_area"]) if is_instance_valid(owner_actor) else 200.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(c.r, c.g, c.b, 0.35), 2.0, true)
	if invulnerable:
		draw_arc(Vector2(0, -60), 44, 0, TAU, 24, Color(1, 1, 1, 0.5), 2.0, true)

func _on_hit_fx(dmg: Dictionary, amount: float, crit: bool) -> void:
	FX.burst(global_position + Vector2(0, -50), Color(0.7, 0.65, 0.55), 6, 140.0, 6.0)

func die(killer: Actor) -> void:
	if dead:
		return
	super.die(killer)
	game().allies.erase(self)
	FX.burst(global_position + Vector2(0, -50), Color(0.6, 0.55, 0.45), 30, 240.0, 9.0, 0.6)
	FX.sound("die", global_position, -6.0)
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)
