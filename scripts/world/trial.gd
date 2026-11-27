class_name Trial
extends Node2D
## Ascension Trial: a golden ring, three waves and a champion. Clearing it grants
## 2 Ascension Points. Appears after the Regent on depths 5, 10, 15 and 20.

const RADIUS := 520.0
var wave := 0
var done := false
var _t := 0.0
var _next := 1.2
var _light: PointLight2D

func _ready() -> void:
	z_index = -2
	_light = FX.make_light(Color(1.0, 0.85, 0.45), RADIUS * 1.3, 0.9)
	add_child(_light)
	var g := Game.instance
	g.hud.show_message("ASCENSION TRIAL", "Survive three waves and the champion.")
	FX.ring(global_position, RADIUS, Color(1.0, 0.85, 0.45), 0.7, 14.0)
	FX.sound("portal", null, 0.0, 0.0)
	FX.shake(8.0)

func _alive() -> int:
	var n := 0
	for e in Game.instance.enemies:
		if e.has_meta("trial") and e.get_meta("trial") == self:
			n += 1
	return n

func _process(delta: float) -> void:
	var g := Game.instance
	if g == null or done:
		return
	_t += delta
	queue_redraw()
	if g.player.dead:
		return
	if _alive() == 0:
		_next -= delta
		if _next <= 0.0:
			if wave >= 4:
				_finish(g)
				return
			wave += 1
			_next = 1.5
			_spawn(g)

func _spawn(g: Game) -> void:
	var lvl := g.area_level() + 1
	var ids := ["husk", "cinderling", "rattler", "brute", "rimecaller", "rift_fiend"]
	if wave == 4:
		var c := g.spawn_enemy("rift_brute", lvl + 2, "rare", g._roll_mods(3), global_position + Vector2(0, -RADIUS * 0.5))
		c.max_life *= 3.0
		c.life = c.max_life
		c.aggro = true
		c.set_meta("trial", self)
		g.hud.show_message("THE CHAMPION", "")
		return
	g.hud.show_message("WAVE %d / 3" % wave, "")
	if g.bot:
		print("TRIAL wave ", wave)
	for i in 5 + wave * 2:
		var p := global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * g.rng.randf_range(RADIUS * 0.5, RADIUS * 0.9)
		if g.is_wall(p):
			p = global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * 120.0
		var rar := "rare" if i < wave else ("magic" if i < wave * 2 + 1 else "normal")
		var mm: Array = g._roll_mods(2) if rar == "rare" else (g._roll_mods(1) if rar == "magic" else [])
		var e := g.spawn_enemy(ids[g.rng.randi() % ids.size()], lvl, rar, mm, p)
		e.aggro = true
		e.set_meta("trial", self)
		FX.burst(p, Color(1.0, 0.85, 0.45), 12, 160.0, 6.0, 0.4)

func _finish(g: Game) -> void:
	done = true
	g.player.asc_trials += 1
	var sub := "+2 Ascension Points. Open the class screen (%s)." % ("D-pad Down" if PlayerInput.using_pad else "K")
	if g.player.ascendancy == "":
		sub = "+2 Ascension Points. Choose your Ascension in the class screen (%s)." % ("D-pad Down" if PlayerInput.using_pad else "K")
	g.hud.show_message("ASCENSION TRIAL COMPLETE", sub)
	FX.sound("levelup", null, 0.0, 0.0)
	FX.light_flash(global_position, Color(1.0, 0.85, 0.45), 900.0, 1.0, 1.5)
	g.drop_currency("ember_shards", int(120 * (1.0 + g.depth * 0.25)), global_position)
	g.drop_item(Loot.make_item(g.area_level() + 2, g.rng, "rare"), global_position)
	g.save_game()
	print("TRIAL complete: asc_trials=%d" % g.player.asc_trials)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 1.0)
	tw.tween_callback(queue_free)

func _draw() -> void:
	var c := Color(1.0, 0.85, 0.45)
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 96, Color(c.r, c.g, c.b, 0.8), 5.0, true)
	for i in 12:
		var a := _t * 0.3 + i * TAU / 12.0
		draw_circle(Vector2.RIGHT.rotated(a) * RADIUS, 6.0, c)

class Seal extends Node2D:
	## Golden crown seal: walk onto it to begin the trial.
	var _t := 0.0
	func _ready() -> void:
		z_index = 2
		add_child(FX.make_light(Color(1.0, 0.85, 0.45), 300.0, 1.1))
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		var g := Game.instance
		if g and g.player and not g.player.dead and g.player.global_position.distance_to(global_position) < 80.0:
			var tr := Trial.new()
			tr.global_position = global_position
			g.fx_node.add_child(tr)
			queue_free()
	func _draw() -> void:
		var c := Color(1.0, 0.85, 0.45)
		var pulse := 0.6 + 0.4 * sin(_t * 3.0)
		draw_circle(Vector2(0, 4), 36, Color(0.15, 0.1, 0.03, 0.6))
		if IsoView.active:   # 3D view: stand the marker up
			draw_set_transform_matrix(Transform2D(IsoView.up_x, IsoView.up_y, Vector2.ZERO))
		var pts := PackedVector2Array([Vector2(-26, 0), Vector2(-26, -26), Vector2(-13, -12), Vector2(0, -34), Vector2(13, -12), Vector2(26, -26), Vector2(26, 0)])
		draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.35 + 0.3 * pulse))
		draw_polyline(pts + PackedVector2Array([pts[0]]), c, 2.5, true)
		draw_arc(Vector2(0, -14), 44, 0, TAU, 32, Color(c.r, c.g, c.b, 0.5 * pulse), 2.0, true)
		var f := ThemeDB.fallback_font
		var s := "Ascension Trial"
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string_outline(f, Vector2(-w / 2, -66), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		draw_string(f, Vector2(-w / 2, -66), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, c)
