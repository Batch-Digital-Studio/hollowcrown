class_name Rift
extends Node2D
## Hollow Rift: a spreading violet tear. Kills inside widen it; idle and it shrinks.
## lord mode (from a Rift Heart): the Rift Lord waits inside and the rift holds open.

var radius := 200.0
var max_radius := 760.0
var age := 0.0
var last_kill := 0.0
var lord_mode := false
var closing := false
var _spawn_t := 0.0
var _light: PointLight2D
var _tint: Node2D
var _lord: Enemy

const LIFETIME := 60.0

func _ready() -> void:
	z_index = -2
	_tint = Node2D.new()
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_tint.material = m
	_tint.draw.connect(func(): _tint.draw_circle(Vector2.ZERO, radius, Color(0.78, 0.6, 1.0)))
	add_child(_tint)
	_light = FX.make_light(Color(0.7, 0.45, 1.0), radius * 1.4, 1.1)
	_light.position = global_position
	Game.instance.light_root.add_child(_light)
	FX.ring(global_position, radius, Color(0.75, 0.5, 1.0), 0.6, 12.0)
	FX.sound("portal", null, 0.0, 0.0)
	FX.shake(8.0)
	FX.rumble(0.4, 0.6, 0.4)
	if lord_mode:
		radius = 520.0
		var g := Game.instance
		_lord = g.spawn_enemy("rift_lord", g.area_level() + 4, "boss", [], global_position + Vector2(0, -160))
		_lord.aggro = true
		_lord.set_meta("rift", self)
		g.hud.show_message("THE HAND THAT WORE THE CROWN", "The Rift Lord awakens.")
	else:
		Game.instance.hud.show_message("A HOLLOW RIFT OPENS", "Kill to widen it. Idle and it closes.")

func notify_kill() -> void:
	last_kill = age
	radius = minf(max_radius, radius + 16.0)

func contains(p: Vector2) -> bool:
	return p.distance_to(global_position) <= radius

func _process(delta: float) -> void:
	var g := Game.instance
	if g == null:
		return
	age += delta
	if not lord_mode and not closing and age >= 45.0 and age - delta < 45.0:
		g.writ_event("rift45")
	if closing:
		radius -= 600.0 * delta
		if radius <= 10.0:
			_light.queue_free()
			queue_free()
			return
	else:
		if lord_mode:
			if not is_instance_valid(_lord) or _lord.dead:
				_close()
		else:
			radius = minf(max_radius, radius + 22.0 * delta)
			if age - last_kill > 3.5:
				radius -= 70.0 * delta
			if radius < 120.0 or age > LIFETIME:
				_close()
		_spawn_t -= delta
		var cap := 8 if lord_mode else 26
		if _spawn_t <= 0.0 and _alive() < cap:
			_spawn_t = 0.9 if lord_mode else 0.45
			_spawn_wave(g)
	_light.texture_scale = radius * 1.4 / 128.0
	_tint.queue_redraw()
	queue_redraw()
	if randf() < 0.8:
		var a := randf() * TAU
		FX.burst(global_position + Vector2.RIGHT.rotated(a) * radius, Color(0.75, 0.5, 1.0), 2, 60.0, 6.0, 0.6)

func _alive() -> int:
	var n := 0
	for e in Game.instance.enemies:
		if e.has_meta("rift") and e.get_meta("rift") == self:
			n += 1
	return n

func _spawn_wave(g: Game) -> void:
	for i in g.rng.randi_range(1, 3):
		var p := global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * g.rng.randf_range(radius * 0.55, radius * 0.95)
		if g.is_wall(p):
			continue
		var r := g.rng.randf()
		var id := "rift_fiend" if r < 0.55 else ("rift_maw" if r < 0.88 else "rift_brute")
		var rar := "normal"
		var mods: Array = []
		if g.rng.randf() < 0.05:
			rar = "rare"
			mods = g._roll_mods(2)
		elif g.rng.randf() < 0.15:
			rar = "magic"
			mods = g._roll_mods(1)
		var e := g.spawn_enemy(id, g.area_level() + 1, rar, mods, p)
		e.aggro = true
		e.set_meta("rift", self)
		FX.burst(p, Color(0.75, 0.5, 1.0), 14, 160.0, 7.0, 0.4)

func _close() -> void:
	closing = true
	var g := Game.instance
	for e in g.enemies.duplicate():
		if e.has_meta("rift") and e.get_meta("rift") == self and not e.is_boss():
			FX.burst(e.global_position, Color(0.75, 0.5, 1.0), 12, 200.0, 7.0, 0.4)
			g.enemies.erase(e)
			e.queue_free()
	g.hud.show_message("THE RIFT CLOSES", "")
	FX.sound("portal", null, -4.0, 0.0)
	g.on_rift_closed(self)

func _draw() -> void:
	var c := Color(0.75, 0.5, 1.0)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 96, Color(c.r, c.g, c.b, 0.85), 5.0, true)
	draw_arc(Vector2.ZERO, radius - 10.0, 0, TAU, 96, Color(c.r, c.g, c.b, 0.3), 12.0, true)
	if not lord_mode and not closing:
		var k := clampf(1.0 - (age - last_kill) / 3.5, 0.0, 1.0)
		draw_arc(Vector2.ZERO, radius + 14.0, -PI / 2, -PI / 2 + TAU * k, 48, Color(1, 1, 1, 0.5), 3.0, true)

class Seal extends Node2D:
	## The cracked hand of the Hollow King. Walk up to it to open a rift.
	var _t := 0.0
	func _ready() -> void:
		z_index = 2
		var l := FX.make_light(Color(0.7, 0.45, 1.0), 260.0, 1.0)
		add_child(l)
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		var g := Game.instance
		if g and g.player and not g.player.dead and g.player.global_position.distance_to(global_position) < 90.0:
			var r := Rift.new()
			r.global_position = global_position
			g.fx_node.add_child(r)
			queue_free()
	func _draw() -> void:
		var c := Color(0.75, 0.5, 1.0)
		var pulse := 0.6 + 0.4 * sin(_t * 3.0)
		draw_circle(Vector2(0, 4), 34, Color(0.1, 0.05, 0.15, 0.6))
		# palm and five crooked fingers
		draw_circle(Vector2(0, -20), 16, Color(0.25, 0.18, 0.35))
		for i in 5:
			var a := -PI / 2 + (i - 2) * 0.38
			var base := Vector2(0, -20) + Vector2.RIGHT.rotated(a) * 12
			var tip := base + Vector2.RIGHT.rotated(a + sin(_t * 2.0 + i) * 0.1) * (26 if i != 0 else 18)
			draw_line(base, tip, Color(0.3, 0.22, 0.42), 6.0, true)
			draw_circle(tip, 3, Color(c.r, c.g, c.b, pulse))
		draw_arc(Vector2(0, -20), 30, 0, TAU, 24, Color(c.r, c.g, c.b, 0.5 * pulse), 2.0, true)
		var f := ThemeDB.fallback_font
		var s := "Rift Seal"
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string_outline(f, Vector2(-w / 2, -64), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(f, Vector2(-w / 2, -64), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, c)
