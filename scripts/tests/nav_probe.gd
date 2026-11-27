extends Node
## --nav-probe: a husk with no straight line to its target must path around the wall and hit it.
var t := 0.0
var m: Minion
var d: Enemy
var l0 := 0.0
var tries := 0
func _ready():
	FX.enabled = false
func _process(delta):
	var g := Game.instance
	if g == null or g.player == null or g.state != "play":
		return
	t += delta
	var p := g.player
	p.invulnerable = true
	if m == null and t > 0.5:
		for e in g.enemies.duplicate():
			g.enemies.erase(e)
			e.queue_free()
		# find two floor cells 4-6 cells apart with no straight walk and a short grid path
		for k in 4000:
			var a: Vector2i = g.zone.floor_cells[g.rng.randi() % g.zone.floor_cells.size()]
			var b: Vector2i = a + Vector2i(g.rng.randi_range(-6, 6), g.rng.randi_range(-6, 6))
			var pa := g.zone.cell_center(a)
			var pb := g.zone.cell_center(b)
			if g.is_wall(pb) or pa.distance_to(pb) < 250.0 or g.clear_walk(pa, pb, 16.0):
				continue
			var path := g.nav_path(pa, pb)
			if path.size() < 2 or path.size() > 14:
				continue
			p.global_position = pa
			m = SkillExec.spawn_minion(g, p, pa)
			d = g.spawn_enemy("husk", 1, "normal", [], pb)
			d.max_life = 5000.0
			d.life = 5000.0
			d.set_physics_process(false)
			l0 = d.life
			print("NAV setup: straight line blocked, grid path %d cells, distance %.0f" % [path.size(), pa.distance_to(pb)])
			break
		if m == null:
			print("NAV FAIL no test spot")
			get_tree().quit(1)
		return
	if m and t > 8.5:
		var ok := d.life < l0
		print(("NAV PASS" if ok else "NAV FAIL") + " husk reached and hit the target behind the wall (dmg %.0f)" % (l0 - d.life))
		get_tree().quit(0 if ok else 1)
