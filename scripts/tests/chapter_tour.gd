extends Node
## Screenshot tour of Chapter 1 (--chapter --tour): visits places in turn and fights a little.
## Pair with --shots=DIR --shot-times=... to capture each stop.
var t := 0.0
var stop := -1
const STOPS := [
	["camp", 0.0], ["oak", 0.0], ["route_forest", 0.18], ["bridge", -1.0], ["shrine", 0.0], ["lake", 0.0],
	["swamp_route", 0.58], ["ruins", 0.0], ["graves", 0.0], ["cache", 0.0], ["arena", 0.0], ["boss", 0.0],
	["rare", 0.0], ["boss_fight", 0.0], ["boss_p3", 0.0],
]
const EVERY := 4.0

var stops: Array = []

func _ready() -> void:
	var only := OS.get_environment("HC_TOUR")
	for st in STOPS:
		if only == "" or only.split(",").has(st[0]):
			stops.append(st)

func _process(delta: float) -> void:
	t += delta
	var g := Game.instance
	if g == null or g.player == null or g.zone == null or not g.zone.is_chapter:
		return
	g.player.invulnerable = true
	g.player.mana = 9999.0
	var want := int(t / EVERY)
	if want != stop and want < stops.size():
		stop = want
		var C: Dictionary = g.zone.chapter
		var s: String = stops[stop][0]
		var pos := g.player.global_position
		match s:
			"camp": pos = C.glades[0].pos + Vector2(0, 160)
			"oak": pos = C.glades[1].pos + Vector2(0, 120)
			"shrine": pos = C.glades[3].pos + Vector2(0, 160)
			"lake": pos = C.glades[4].pos + Vector2(-200, 160)
			"ruins": pos = C.glades[5].pos + Vector2(0, 180)
			"graves": pos = C.glades[6].pos + Vector2(0, 200)
			"arena": pos = C.arena.pos + Vector2(0, C.arena.r_px * 0.5)
			"boss": pos = C.arena.pos + Vector2(0, C.arena.r_px * 0.2)
			"bridge":
				var b: Dictionary = C.bridges[0]
				pos = (b.a + b.b) * 0.5
			"cache": pos = C.caches[0].pos + Vector2(0, 200)
			"rare":
				for e in g.enemies:
					if e.rarity == "rare" and e.rare and not e.dead:
						pos = e.global_position + Vector2(0, 260)
						break
			"boss_fight":
				pos = C.arena.pos + Vector2(0, -C.arena.r_px * 0.15)
			"boss_p3":
				pos = C.arena.pos + Vector2(0, C.arena.r_px * 0.25)
				if g.boss and not g.boss.dead:
					g.boss.life = g.boss.max_life * 0.38
			_:
				var r: PackedVector2Array = C.route
				pos = r[int(float(stops[stop][1]) * (r.size() - 1))]
		g.player.global_position = pos
		g.camera.global_position = pos
		g.camera.reset_smoothing()
		g.iso_view._have_target = false
		print("TOUR ", s, " at ", pos)
	# fight: cast a spell at the nearest monster every 0.6 s
	if fmod(t, 0.6) < delta and stop >= 0 and OS.get_environment("HC_NOCAST") == "":
		var best: Enemy = null
		var bd := 900.0
		for e in g.enemies:
			if not e.dead and e.global_position.distance_to(g.player.global_position) < bd:
				bd = e.global_position.distance_to(g.player.global_position)
				best = e
		if best:
			best.aggro = true
			var spells := ["ember_bolt", "frost_nova", "arc_spark", "void_orb", "radiant_lance", "thunderfall", "judgment", "withering_mire", "frost_lance", "sunburst", "cinder_field", "soul_rend"]
			var sid: String = spells[int(t / 0.6) % spells.size()]
			g.player.busy_time = 0.0
			g.player.cooldowns.clear()
			SkillExec.use(sid, g.player, best.global_position)
	if t > EVERY * stops.size() + 1.0:
		get_tree().quit()
