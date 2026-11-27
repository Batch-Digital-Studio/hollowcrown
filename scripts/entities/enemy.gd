class_name Enemy
extends Actor

var type_id := ""
var def: Dictionary
var rarity := "normal"     # normal / magic / rare / boss
var mods: Array = []       # monster mod ids
var aggro := false
var _think := 0.0
var _anim := 0.0
var _strafe := 1.0
var _boss_phase := 1
var _boss_cycle := 0
var _summon_cd := 8.0
var _aura: Sprite2D

const AGGRO_RANGE := 620.0

func setup(id: String, lvl: int, rar: String, mod_ids: Array) -> void:
	type_id = id
	def = EnemiesDB.ENEMIES[id]
	level = lvl
	rarity = rar
	mods = mod_ids
	radius = def.radius * (1.25 if rarity == "rare" else 1.0)
	display_name = def.name
	stats = StatBlock.new()
	var life_scale := pow(1.16, lvl - 1)
	stats.add("life_flat", def.life * life_scale)
	stats.add("move_speed_base", def.speed)
	stats.add_mods(def.get("stats", {}))
	stats.add("more_damage", (pow(1.12, lvl - 1) - 1.0) * 100.0)
	if rarity == "magic":
		stats.add("more_life", 60)
		stats.add("more_damage", 15)
	elif rarity == "rare":
		stats.add("more_life", 220)
		stats.add("more_damage", 35)
	for m in mods:
		stats.add_mods(EnemiesDB.MONSTER_MODS[m].stats)
	max_life = stats.get_stat("life_flat") * stats.get_stat("more_life")
	life = max_life
	if mods.size() > 0:
		var names: Array = []
		for m in mods:
			names.append(EnemiesDB.MONSTER_MODS[m].label)
		display_name = ", ".join(names) + " " + def.name if rarity == "rare" else def.name

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius * 0.8
	shape.shape = c
	add_child(shape)
	_strafe = 1.0 if game().rng.randf() < 0.5 else -1.0
	if rarity == "rare" or rarity == "magic" or def.get("boss", false):
		var col := Color(1.0, 0.8, 0.3, 0.5) if rarity == "rare" else Color(0.4, 0.55, 1.0, 0.4)
		if def.get("boss", false):
			col = Color(1.0, 0.45, 0.15, 0.6)
		_aura = FX.make_glow(col, radius * 4.0)
		_aura.z_index = -1
		add_child(_aura)

func is_boss() -> bool:
	return def.get("boss", false)

func _physics_process(delta: float) -> void:
	if dead:
		return
	tick_common(delta)
	if dead:
		return
	_anim += delta
	var g := game()
	var p: Player = g.player
	if p == null or p.dead:
		velocity = knock
		move_and_slide()
		queue_redraw()
		return
	var to_p := p.global_position - global_position
	var dist := to_p.length()
	if not aggro and dist > AGGRO_RANGE and life >= max_life:
		if ignite_time > 0.0 or hit_flash > 0.0:
			queue_redraw()
		return
	if not aggro and (dist < AGGRO_RANGE or life < max_life):
		aggro = true
		g.alert_pack(self)
	var move := Vector2.ZERO
	if aggro and busy_time <= 0.0:
		facing = to_p.normalized()
		match def.ai:
			"melee": move = _ai_melee(p, to_p, dist)
			"ranged": move = _ai_ranged(p, to_p, dist)
			"boss": move = _ai_boss(p, to_p, dist, delta)
	# separation from other monsters
	var sep := Vector2.ZERO
	for o in g.enemies_near(global_position, radius * 2.2):
		if o == self:
			continue
		var d: Vector2 = global_position - o.global_position
		var l := d.length()
		if l > 0.1:
			sep += d / l * (radius * 2.2 - l)
	velocity = move * move_speed() + sep * 6.0 + knock
	move_and_slide()
	queue_redraw()

func _ai_melee(p: Player, to_p: Vector2, dist: float) -> Vector2:
	var sid: String = def.skills[0]
	if dist <= def.range + p.radius:
		SkillExec.use(sid, self, p.global_position)
		return Vector2.ZERO
	return to_p.normalized()

func _ai_ranged(p: Player, to_p: Vector2, dist: float) -> Vector2:
	var sid: String = def.skills[0]
	if dist < def.range and game().has_line_of_sight(global_position, p.global_position):
		SkillExec.use(sid, self, p.global_position + p.velocity * 0.25)
	if dist < def.keep_away:
		return -to_p.normalized() * 0.8 + to_p.normalized().orthogonal() * _strafe * 0.5
	if dist > def.range * 0.85:
		return to_p.normalized()
	return to_p.normalized().orthogonal() * _strafe * 0.6

func _ai_boss(p: Player, to_p: Vector2, dist: float, delta: float) -> Vector2:
	if _boss_phase == 1 and life < max_life * 0.5:
		_boss_phase = 2
		stats.add("inc_attack_speed", 30)
		stats.add("inc_cast_speed", 30)
		stats.add("inc_move_speed", 20)
		FX.text(global_position, "THE CROWN BURNS", Color(1.0, 0.5, 0.2), 36)
		FX.ring(global_position, 400.0, Color(1.0, 0.4, 0.1), 0.8, 14.0)
		FX.shake(16.0)
	_summon_cd -= delta
	if _summon_cd <= 0.0:
		_summon_cd = 11.0 if _boss_phase == 1 else 8.0
		game().spawn_adds(global_position, 3 if _boss_phase == 1 else 5, level)
	# Rotate through special attacks; sweep when close.
	if dist < 170.0 and can_use("regent_sweep") and game().rng.randf() < 0.6:
		SkillExec.use("regent_sweep", self, p.global_position)
		return Vector2.ZERO
	_boss_cycle += 1
	if _boss_cycle % 2 == 0 and cooldowns.get("regent_nova", 0.0) <= 0.0 and dist < 300.0:
		SkillExec.use("regent_nova", self, p.global_position)
		cooldowns["regent_nova"] = 6.0 if _boss_phase == 1 else 4.0
		return Vector2.ZERO
	if cooldowns.get("regent_volley", 0.0) <= 0.0:
		SkillExec.use("regent_volley", self, p.global_position)
		cooldowns["regent_volley"] = 5.0 if _boss_phase == 1 else 3.0
		return Vector2.ZERO
	if dist > 130.0:
		return to_p.normalized() * (1.6 if dist > 380.0 else 1.0)
	return Vector2.ZERO

func die(killer: Actor) -> void:
	if dead:
		return
	super.die(killer)
	var c: Color = def.eye
	FX.burst(global_position, c, 26 if rarity == "normal" else 50, 300.0, 8.0, 0.6)
	FX.burst(global_position, Color(0.4, 0.38, 0.36), 18, 200.0, 10.0, 0.8)
	FX.flash(global_position, c, radius * 3.0, 0.2)
	if rarity != "normal":
		FX.shake(6.0)
	FX.sound("die", global_position, -6.0)
	if is_boss():
		FX.sound("boom", null, 4.0)
		FX.shake(20.0)
		FX.hitstop(0.25)
	set_physics_process(false)
	collision_layer = 0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.35)
	tw.tween_callback(queue_free)

func _draw() -> void:
	var col := status_tint(def.color)
	var eye: Color = def.eye
	var t := _anim
	# shadow
	draw_set_transform(Vector2(0, radius * 0.85), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match type_id:
		"husk":
			var bob := sin(t * 9.0) * 1.5
			draw_circle(Vector2(0, bob), radius, col)
			draw_circle(Vector2(0, -radius * 0.5 + bob), radius * 0.6, col.darkened(0.2))
			for i in 3:
				var a := -0.6 + i * 0.6
				draw_line(Vector2(cos(a), sin(a)) * radius * 0.6 + Vector2(0, bob), Vector2(cos(a), sin(a)) * radius * 1.1 + Vector2(0, bob), col.darkened(0.45), 2.0)
			draw_circle(Vector2(-4, -radius * 0.55 + bob) + facing * 3, 2.5, eye)
			draw_circle(Vector2(4, -radius * 0.55 + bob) + facing * 3, 2.5, eye)
		"cinderling":
			var hover := sin(t * 5.0) * 4.0
			var pts := PackedVector2Array([Vector2(0, -radius * 1.5), Vector2(radius, 0), Vector2(0, radius), Vector2(-radius, 0)])
			for i in pts.size():
				pts[i] += Vector2(0, hover - 6)
			draw_colored_polygon(pts, col)
			draw_circle(Vector2(0, hover - 6), radius * 0.45, eye.lerp(Color.WHITE, 0.3 + 0.2 * sin(t * 12.0)))
		"brute":
			var sway := sin(t * 4.0) * 2.0
			var rect := Rect2(-radius, -radius * 1.1 + sway, radius * 2, radius * 2)
			draw_rect(rect, col)
			draw_rect(Rect2(-radius * 1.25, -radius * 0.9 + sway, radius * 0.45, radius * 1.3), col.darkened(0.25))
			draw_rect(Rect2(radius * 0.8, -radius * 0.9 + sway, radius * 0.45, radius * 1.3), col.darkened(0.25))
			draw_rect(rect, col.darkened(0.5), false, 2.0)
			draw_circle(Vector2(-7, -radius * 0.5 + sway) + facing * 4, 3.5, eye)
			draw_circle(Vector2(7, -radius * 0.5 + sway) + facing * 4, 3.5, eye)
		"regent":
			var breathe := 1.0 + 0.03 * sin(t * 3.0)
			draw_circle(Vector2.ZERO, radius * breathe, col)
			draw_circle(Vector2(0, -radius * 0.4), radius * 0.62, col.darkened(0.3))
			# the hollow crown
			var crown_c := Color(1.0, 0.7, 0.25) if _boss_phase == 1 else Color(1.0, 0.35, 0.1)
			var base_y := -radius * 0.95
			var cpts := PackedVector2Array()
			for i in 9:
				var x := -radius * 0.7 + radius * 1.4 * i / 8.0
				var y := base_y - (radius * 0.45 if i % 2 == 0 else radius * 0.15)
				cpts.append(Vector2(x, y))
			draw_polyline(cpts, crown_c, 4.0, true)
			draw_line(Vector2(-radius * 0.7, base_y), Vector2(radius * 0.7, base_y), crown_c, 4.0)
			draw_circle(Vector2(-10, -radius * 0.45) + facing * 6, 5.0, eye)
			draw_circle(Vector2(10, -radius * 0.45) + facing * 6, 5.0, eye)
			draw_arc(Vector2.ZERO, radius * 1.2, t, t + PI * 0.6, 24, crown_c.darkened(0.2), 3.0, true)
			draw_arc(Vector2.ZERO, radius * 1.2, t + PI, t + PI * 1.6, 24, crown_c.darkened(0.2), 3.0, true)
	if ignite_time > 0.0:
		draw_arc(Vector2.ZERO, radius * 1.15, 0, TAU, 24, Color(1, 0.45, 0.1, 0.6), 2.0, true)
	# life bar
	if life < max_life and not is_boss():
		var w := maxf(36.0, radius * 2.4)
		var y := -radius * 1.9
		draw_rect(Rect2(-w / 2 - 1, y - 1, w + 2, 6), Color(0, 0, 0, 0.8))
		var bar_c := Color(0.85, 0.15, 0.12)
		if rarity == "rare":
			bar_c = Color(0.95, 0.7, 0.2)
		elif rarity == "magic":
			bar_c = Color(0.35, 0.5, 1.0)
		draw_rect(Rect2(-w / 2, y, w * life / max_life, 4), bar_c)
	if rarity == "rare":
		var f := ThemeDB.fallback_font
		var s := display_name
		var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string_outline(f, Vector2(-tw / 2, -radius * 2.2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
		draw_string(f, Vector2(-tw / 2, -radius * 2.2), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.85, 0.4))
