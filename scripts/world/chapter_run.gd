class_name ChapterRun
extends Node
## Runs Chapter 1 inside Game (simulation side): spawns the packs, rares, hidden caches and the boss,
## tracks waystones (respawn points), region entry banners and the boss arena seal.

var g: Game
var zone: Zone
var region := -1
var waystone := 0                 # index of the last waystone touched
var found := {}                   # waystone index -> true
var caches_found := 0
var boss_state := "idle"          # idle / sealed / dead
var gate: StaticBody2D
var arena: Dictionary
var _region_t := 0.0
var _complete_t := -1.0

func setup(game: Game) -> void:
	g = game
	zone = g.zone
	arena = zone.chapter.arena

func area_level() -> int:
	var r := zone.region_at(g.player.global_position) if g.player else 0
	return ChapterDB.AREA_LEVEL[clampi(r, 0, 2)]

func spawn_world() -> void:
	var C: Dictionary = zone.chapter
	for pk in C.packs:
		_spawn_pack(pk)
	for ch in C.caches:
		var c := Chest.new()
		c.position = ch.pos
		c.hidden_cache = true
		g.world_layer.add_child(c)
	_spawn_boss()
	found[0] = true

func _spawn_pack(pk: Dictionary) -> void:
	var lvl: int = ChapterDB.AREA_LEVEL[int(pk.region)]
	var ids: Array = pk.ids
	var n := ids.size() + (2 if pk.get("big", false) else 0)
	var pid := g.rng.randi()
	var members: Array = []
	for i in n:
		var id: String = ids[i % ids.size()]
		var off := Vector2.RIGHT.rotated(TAU * i / float(n) + g.rng.randf()) * g.rng.randf_range(40.0, 110.0)
		var pos: Vector2 = pk.pos + off
		if zone.is_wall_at(pos):
			pos = pk.pos
		var rar := "normal"
		if i == 0 and pk.rare:
			rar = "rare"
		elif i == 0 and pk.magic:
			rar = "magic"
		var mods: Array = []
		if rar == "magic":
			mods = [EnemiesDB.MONSTER_MODS.keys()[g.rng.randi() % EnemiesDB.MONSTER_MODS.size()]]
		var e := g.spawn_enemy(id, lvl, rar, mods, pos)
		if rar == "rare":
			e.rare = RareBrain.roll(e, g.rng)
			e.max_life = e.stats.get_stat("life_flat") * e.stats.get_stat("more_life")   # abilities can add life
			e.life = e.max_life
		members.append(e)
	g.pack_members[pid] = members
	for m in members:
		g.packs[m] = pid

func _spawn_boss() -> void:
	var pos: Vector2 = arena.pos + Vector2(0, -arena.r_px * 0.45)
	var b := g.spawn_enemy("hollow_king", ChapterDB.AREA_LEVEL[2] + 2, "boss", [], pos)
	b.facing = Vector2(0, 1)
	b.set_meta("dormant", true)
	g.boss = b

## Called every frame from Game while the chapter is playing.
func tick(delta: float) -> void:
	var p := g.player
	if p == null or p.dead:
		return
	# region banner
	_region_t -= delta
	if _region_t <= 0.0:
		_region_t = 0.5
		var r := zone.region_at(p.global_position)
		if r != region:
			if region >= 0 or r == 0:
				var R: Dictionary = ChapterDB.REGIONS[r]
				g.hud.show_message(String(R.name), "%s  ·  Area Level %d" % [R.sub, ChapterDB.AREA_LEVEL[r]])
			region = r
	# waystones: touching one makes it your respawn point
	var wps: Array = zone.chapter.waypoints
	for i in wps.size():
		if not found.has(i) and p.global_position.distance_to(wps[i]) < 130.0:
			found[i] = true
			waystone = i
			FX.text(p.global_position, "Waystone attuned", Color(0.5, 0.85, 1.0), 22)
			FX.event3d("nova", wps[i], "light", 120.0)
			FX.sound("pickup", null, -4.0, 0.0)
			p.life = p.max_life
			p.flask_charges = p.flask_max
	# boss arena
	if boss_state == "idle":
		if p.global_position.distance_to(arena.pos) < arena.r_px - 160.0:
			_seal_arena()
	elif boss_state == "sealed":
		if g.boss == null or not is_instance_valid(g.boss) or g.boss.dead:
			_boss_down()
	if _complete_t > 0.0:
		_complete_t -= delta
		if _complete_t <= 0.0:
			g.hud.show_message("CHAPTER I COMPLETE", "The Hollow Crown is broken  ·  Caches found: %d / %d" % [caches_found, zone.chapter.caches.size()])

func _seal_arena() -> void:
	boss_state = "sealed"
	var b: Enemy = g.boss
	# a wall of soulfire closes the way back
	gate = StaticBody2D.new()
	gate.collision_layer = 1
	gate.collision_mask = 0
	var a: Vector2 = arena.gate_a
	var c: Vector2 = arena.gate_b
	for i in 9:
		var cs := CollisionShape2D.new()
		var circ := CircleShape2D.new()
		circ.radius = 70.0
		cs.shape = circ
		cs.position = a.lerp(c, i / 8.0)
		gate.add_child(cs)
	g.add_child(gate)
	FX.event3d("gate", arena.gate_mid, "cold", 0.0, {"a": a, "b": c, "on": true})
	if b and is_instance_valid(b):
		b.remove_meta("dormant")
		b.aggro = true
		b.busy_time = 2.4       # rises from the throne
		b.invulnerable = true
		g.get_tree().create_timer(2.4, false).timeout.connect(func():
			if is_instance_valid(b):
				b.invulnerable = false)
	g.hud.show_boss_intro(String(b.def.name).to_upper(), String(b.def.get("title", "")))
	FX.shake(18.0)
	FX.rumble(0.7, 0.9, 0.8)
	FX.sound("boom", null, 2.0)
	FX.event3d("boss_rise", b.global_position, "cold", 300.0)

func _boss_down() -> void:
	boss_state = "dead"
	if gate and is_instance_valid(gate):
		gate.queue_free()
	FX.event3d("gate", arena.gate_mid, "cold", 0.0, {"on": false})
	_complete_t = 3.5
	# a shower of loot and the crown
	for i in 6:
		var it := Loot.make_item(ChapterDB.AREA_LEVEL[2] + 3, g.rng, "", 300.0)
		g.drop_item(it, arena.pos + Vector2.RIGHT.rotated(TAU * i / 6.0) * 90.0)

func cache_opened(pos: Vector2) -> void:
	caches_found += 1
	g.hud.show_message("Hidden Cache", "%d of %d found" % [caches_found, zone.chapter.caches.size()])
	FX.event3d("cache", pos, "light", 0.0)

func respawn_point() -> Vector2:
	var wps: Array = zone.chapter.waypoints
	return wps[clampi(waystone, 0, wps.size() - 1)]
