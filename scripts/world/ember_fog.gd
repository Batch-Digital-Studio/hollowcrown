class_name EmberFog
extends Node2D
## Ember Fog (Delirium-style). Light the Fog Lantern and an ash fog rolls in around you for 45 s.
## Fogborn monsters keep arriving and grow tougher as the fog deepens; when it lifts, a
## Fog Cache appears with loot that scales with how many you killed inside it.

const DURATION := 45.0
var lit := false
var t := 0.0
var kills := 0
var _spawn := 1.5
var _anim := 0.0

func depth01() -> float:
	return clampf(t / DURATION, 0.0, 1.0)

func _ready() -> void:
	z_index = 2
	add_child(FX.make_light(Color(1.0, 0.7, 0.4), 240.0, 0.9))

func _process(delta: float) -> void:
	_anim += delta
	queue_redraw()
	var g := Game.instance
	if g == null or g.player == null:
		return
	var p := g.player
	if not lit:
		if not p.dead and p.global_position.distance_to(global_position) < 70.0:
			_light(g)
		return
	if p.dead:
		_end(g, false)
		return
	t += delta
	_spawn -= delta
	if _spawn <= 0.0:
		_spawn = 3.0 - depth01() * 1.2
		_spawn_fogborn(g)
	if t >= DURATION:
		_end(g, true)

func _light(g: Game) -> void:
	lit = true
	g.fog = self
	g.hud.show_message("THE EMBER FOG ROLLS IN", "Fogborn hunt you for 45 s. The deeper it gets, the better the cache.")
	FX.sound("portal", null, -2.0, 0.0)
	FX.ring(global_position, 300.0, Color(0.8, 0.7, 0.6), 0.8, 10.0)
	if g.bot:
		print("TEST ember fog lit")

func _spawn_fogborn(g: Game) -> void:
	var ids := ["husk", "cinderling", "rattler", "brute", "rimecaller", "rift_fiend"]
	var n := 1 + int(depth01() * 2.5)
	for i in n:
		var pp := g.player.global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * g.rng.randf_range(420.0, 620.0)
		if g.is_wall(pp):
			continue
		var roll := g.rng.randf()
		var rar := "rare" if roll < 0.03 + depth01() * 0.12 else ("magic" if roll < 0.35 + depth01() * 0.4 else "normal")
		var mods: Array = g._roll_mods(2) if rar == "rare" else (g._roll_mods(1) if rar == "magic" else [])
		var e := g.spawn_enemy(ids[g.rng.randi() % ids.size()], g.area_level() + int(depth01() * 2.0), rar, mods, pp)
		e.aggro = true
		e.max_life *= 1.0 + 0.5 * depth01()
		e.life = e.max_life
		e.set_meta("fog", true)
		FX.burst(pp, Color(0.75, 0.7, 0.65), 14, 160.0, 7.0, 0.5)

func on_kill(e: Enemy) -> void:
	if lit and not is_queued_for_deletion():
		kills += 1

func _end(g: Game, survived: bool) -> void:
	lit = false
	if g.fog == self:
		g.fog = null
	for e in g.enemies.duplicate():
		if e.has_meta("fog"):
			g.enemies.erase(e)
			FX.burst(e.global_position, Color(0.75, 0.7, 0.65), 10, 140.0, 6.0, 0.4)
			e.queue_free()
	if survived:
		g.hud.show_message("THE FOG LIFTS", "%d Fogborn slain." % kills)
		var pos := g.player.global_position + Vector2(0, -60)
		var n := 2 + kills / 6
		for i in n:
			g.drop_item(Loot.make_item(g.area_level() + 2, g.rng, "", 120.0 + kills * 4.0), pos)
		g.drop_currency("ember_shards", int((30 + kills * 4) * (1.0 + g.depth * 0.25)), pos)
		for i in 1 + kills / 12:
			g.drop_currency(CurrencyDB.CRAFTING[g.rng.randi() % CurrencyDB.CRAFTING.size()], 1, pos)
		FX.sound("drop_unique", null, -4.0, 0.0)
		if g.bot:
			print("TEST ember fog cache: kills=%d items=%d" % [kills, n])
	queue_free()

func _draw() -> void:
	if lit:
		return
	var c := Color(1.0, 0.7, 0.4)
	var pulse := 0.6 + 0.4 * sin(_anim * 3.0)
	draw_line(Vector2(0, 0), Vector2(0, -60), Color(0.3, 0.28, 0.25), 4.0)
	draw_rect(Rect2(-12, -84, 24, 26), Color(0.15, 0.13, 0.12))
	draw_circle(Vector2(0, -71), 8, Color(c.r, c.g, c.b, pulse))
	var f := ThemeDB.fallback_font
	var s := "Fog Lantern"
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(f, Vector2(-w / 2, -98), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
	draw_string(f, Vector2(-w / 2, -98), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.78, 0.7))
