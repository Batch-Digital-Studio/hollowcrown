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
var brain: BossBrain = null
var rare: RareBrain = null     # Chapter 1 named rares
var _intro_done := false


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
	if def.get("ai", "") == "brain":
		brain = BossBrain.new()
		brain.setup(self)
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
	_build_visuals()

func absorb_hit(amount: float) -> float:
	return rare.absorb(amount) if rare else amount

func damage_taken_mult() -> float:
	var m := super()
	if brain:
		m *= brain.taken_mult()
	return m

func is_boss() -> bool:
	return def.get("boss", false)

func _physics_process(delta: float) -> void:
	if dead:
		return
	tick_common(delta)
	if dead:
		return
	if has_meta("dormant"):
		return
	_anim += delta
	var g := game()
	var pl: Player = g.player
	if pl == null or pl.dead:
		velocity = knock
		move_and_slide()
		queue_redraw()
		return
	var pdist := pl.global_position.distance_to(global_position)
	if not aggro and pdist > AGGRO_RANGE and life >= max_life:
		if ignite_time > 0.0 or hit_flash > 0.0:
			queue_redraw()
		return
	if not aggro:
		var near_ally := false
		for a in g.allies:
			if is_instance_valid(a) and a.global_position.distance_to(global_position) < AGGRO_RANGE * 0.6:
				near_ally = true
				break
		if pdist < AGGRO_RANGE or life < max_life or near_ally:
			aggro = true
			g.alert_pack(self)
	var p: Actor = _pick_target(g, pl, delta)
	var to_p := p.global_position - global_position
	var dist := to_p.length()
	var move := Vector2.ZERO
	if aggro and busy_time <= 0.0:
		facing = to_p.normalized()
		match def.ai:
			"melee": move = _ai_melee(p, to_p, dist)
			"ranged": move = _ai_ranged(p, to_p, dist)
			"boss": move = _ai_boss(p, to_p, dist, delta)
			"brain":
				move = brain.tick(p, to_p, dist, delta)
				_boss_phase = brain.phase
			"summoner": move = _ai_summoner(p, to_p, dist)
			"skirmish": move = _ai_skirmish(p, to_p, dist)
			"hexer": move = _ai_hexer(p, to_p, dist)
		if rare:
			rare.tick(p, dist, delta)
	elif aggro and brain and (brain.charge_left > 0.0 or brain.charge_wind > 0.0 or brain.stagger > 0.0):
		move = brain.tick(p, to_p, dist, delta)
	if aggro and is_boss() and not _intro_done and def.get("brain", "") != "king":
		_intro_done = true
		g.hud.show_message(String(def.name).to_upper(), def.get("intro", ""))
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
	_update_visuals()
	queue_redraw()

var _target: Actor = null
var _retarget := 0.0

## Fight the player, or whichever minion/totem is much closer.
func _pick_target(g: Game, pl: Player, delta: float) -> Actor:
	_retarget -= delta
	if _retarget > 0.0 and _target != null and is_instance_valid(_target) and not _target.dead:
		return _target
	_retarget = 0.6
	_target = pl
	var best := pl.global_position.distance_to(global_position) * 0.75
	for a in g.allies:
		if is_instance_valid(a) and not a.dead and not a.invulnerable:
			var d: float = a.global_position.distance_to(global_position)
			if d < best:
				best = d
				_target = a
	return _target

func _ai_melee(p: Actor, to_p: Vector2, dist: float) -> Vector2:
	var sid: String = def.skills[0]
	if dist <= def.range + p.radius:
		SkillExec.use(sid, self, p.global_position)
		return Vector2.ZERO
	return to_p.normalized()

func _ai_ranged(p: Actor, to_p: Vector2, dist: float) -> Vector2:
	var sid: String = def.skills[0]
	if dist < def.range and game().has_line_of_sight(global_position, p.global_position):
		SkillExec.use(sid, self, p.global_position + p.velocity * 0.25)
	if dist < def.keep_away:
		return -to_p.normalized() * 0.8 + to_p.normalized().orthogonal() * _strafe * 0.5
	if dist > def.range * 0.85:
		return to_p.normalized()
	return to_p.normalized().orthogonal() * _strafe * 0.6

## Melee, but spits its second skill from range (spiders).
func _ai_skirmish(p: Actor, to_p: Vector2, dist: float) -> Vector2:
	var far_sk: String = def.skills[1]
	if dist > 180.0 and dist < 520.0 and can_use(far_sk) and game().has_line_of_sight(global_position, p.global_position):
		SkillExec.use(far_sk, self, p.global_position + p.velocity * 0.2)
		return Vector2.ZERO
	return _ai_melee(p, to_p, dist)

## Ranged caster that also raises the dead (barrow hexers).
func _ai_hexer(p: Actor, to_p: Vector2, dist: float) -> Vector2:
	if dist < def.range and can_use("raise_dead") and game().rng.randf() < 0.3:
		SkillExec.use("raise_dead", self, p.global_position)
		return Vector2.ZERO
	return _ai_ranged(p, to_p, dist)

func _ai_summoner(p: Actor, to_p: Vector2, dist: float) -> Vector2:
	if dist < def.range and can_use("raise_dead"):
		SkillExec.use("raise_dead", self, p.global_position)
		return Vector2.ZERO
	if dist < def.keep_away:
		return -to_p.normalized()
	if dist > def.range * 0.8:
		return to_p.normalized()
	return to_p.normalized().orthogonal() * _strafe * 0.5

func _ai_boss(p: Actor, to_p: Vector2, dist: float, delta: float) -> Vector2:
	if _boss_phase == 1 and life < max_life * 0.5:
		_boss_phase = 2
		stats.add("inc_attack_speed", 30)
		stats.add("inc_cast_speed", 30)
		stats.add("inc_move_speed", 20)
		FX.text(global_position, def.get("enrage_text", "THE CROWN BURNS"), Color(1.0, 0.5, 0.2), 36)
		FX.ring(global_position, 400.0, Color(1.0, 0.4, 0.1), 0.8, 14.0)
		FX.shake(16.0)
	_summon_cd -= delta
	if _summon_cd <= 0.0:
		_summon_cd = 11.0 if _boss_phase == 1 else 8.0
		game().spawn_adds(global_position, 3 if _boss_phase == 1 else 5, level)
	# Rotate through special attacks; sweep when close.
	var sk_sweep: String = def.skills[0]
	var sk_nova: String = def.skills[1]
	var sk_volley: String = def.skills[2]
	if dist < 170.0 and can_use(sk_sweep) and game().rng.randf() < 0.6:
		SkillExec.use(sk_sweep, self, p.global_position)
		return Vector2.ZERO
	_boss_cycle += 1
	if _boss_cycle % 2 == 0 and cooldowns.get(sk_nova, 0.0) <= 0.0 and dist < 300.0:
		SkillExec.use(sk_nova, self, p.global_position)
		cooldowns[sk_nova] = 6.0 if _boss_phase == 1 else 4.0
		return Vector2.ZERO
	if cooldowns.get(sk_volley, 0.0) <= 0.0:
		SkillExec.use(sk_volley, self, p.global_position)
		cooldowns[sk_volley] = 5.0 if _boss_phase == 1 else 3.0
		return Vector2.ZERO
	if dist > 130.0:
		return to_p.normalized() * (1.6 if dist > 380.0 else 1.0)
	return Vector2.ZERO

func die(killer: Actor) -> void:
	if dead:
		return
	if rare:
		rare.on_death()
	super.die(killer)
	var c: Color = def.get("eye", def.get("light", Color(1.0, 0.75, 0.3)))
	FX.burst(global_position, c, 26 if rarity == "normal" else 50, 300.0, 8.0, 0.6)
	FX.burst(global_position, Color(0.4, 0.38, 0.36), 18, 200.0, 10.0, 0.8)
	FX.flash(global_position, c, radius * 3.0, 0.2)
	if rarity != "normal":
		FX.shake(6.0)
	FX.sound("die", global_position, -6.0)
	if is_boss():
		FX.sound("boom", null, 4.0)
		FX.rumble(0.6, 1.0, 0.6)
		FX.shake(20.0)
		FX.hitstop(0.25)
	set_physics_process(false)
	collision_layer = 0
	if _spr:
		_mat.set_shader_parameter("flash", 0.0)
		_spr.stop()
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(self, "rotation", (PI / 2.0) * (-1.0 if facing.x > 0 else 1.0), 0.25)
	if is_boss() or has_meta("minion"):
		tw.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.25)
		tw.chain().tween_callback(queue_free)
	else:
		# leave a corpse for the Shaman; it fades after a while
		tw.tween_property(self, "modulate", Color(0.55, 0.5, 0.5, 0.75), 0.4).set_delay(0.25)
		tw.chain().tween_interval(25.0)
		tw.chain().tween_property(self, "modulate:a", 0.0, 1.0)
		tw.chain().tween_callback(_expire_corpse)
	z_index = -1

func _expire_corpse() -> void:
	var g := game()
	if g:
		for c in g.corpses:
			if c.node == self:
				g.corpses.erase(c)
				break
	queue_free()

func _draw() -> void:
	if dead:
		return
	var iso := IsoView.active   # 3D view: models replace the upright 2D bits; ground rings stay
	if not iso:
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, radius * 1.15, Color(0, 0, 0, 0.5))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ignite_time > 0.0:
		draw_arc(Vector2(0, 2), radius * 1.2, 0, TAU, 24, Color(1, 0.45, 0.1, 0.8), 2.0, true)
	if frozen_time > 0.0 and not iso:
		var h := sprite_height() + 12.0
		var w := radius * 1.25
		var ice := PackedVector2Array([Vector2(-w, 6), Vector2(-w * 1.1, -h * 0.55), Vector2(-w * 0.4, -h - 6), Vector2(w * 0.5, -h), Vector2(w * 1.1, -h * 0.5), Vector2(w, 6)])
		draw_colored_polygon(ice, Color(0.6, 0.85, 1.0, 0.35))
		draw_polyline(ice + PackedVector2Array([ice[0]]), Color(0.85, 0.97, 1.0, 0.9), 2.5, true)
	elif chill_time > 0.0 or frozen_time > 0.0:
		draw_arc(Vector2(0, 2), radius * 1.2, 0, TAU, 24, Color(0.6, 0.9, 1.0, 0.7), 2.0, true)
	if not poisons.is_empty():
		draw_arc(Vector2(0, 2), radius * 1.05, 0, TAU, 24, Color(0.45, 0.95, 0.25, 0.6), 2.0, true)
	if curse_time > 0.0 and iso:
		draw_arc(Vector2.ZERO, radius * 1.5, 0, TAU, 24, Color(0.7, 0.4, 0.95, 0.7), 2.0, true)
	elif curse_time > 0.0:
		var cc := Color(0.7, 0.4, 0.95, 0.8)
		draw_arc(Vector2(0, -sprite_height() - 14), 9, 0, TAU, 12, cc, 2.0, true)
		draw_line(Vector2(-6, -sprite_height() - 14), Vector2(6, -sprite_height() - 14), cc, 2.0)
	if rarity == "rare" or rarity == "magic":
		var c := Color(1.0, 0.8, 0.3, 0.6) if rarity == "rare" else Color(0.45, 0.6, 1.0, 0.5)
		draw_arc(Vector2(0, 2), radius * 1.35, _anim, _anim + PI * 1.5, 24, c, 2.0, true)
	if brain and brain.shielded():
		draw_arc(Vector2(0, 0 if iso else -sprite_height() * 0.45), radius * 1.6, 0, TAU, 48, Color(0.75, 0.5, 1.0, 0.5 + 0.3 * sin(_anim * 6.0)), 5.0, true)
	if brain and brain.stagger > 0.0 and not iso:
		for i in 3:
			var a := _anim * 4.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(a) * 30.0, -sprite_height() - 20.0 + sin(a) * 8.0), 5.0, Color(1.0, 0.9, 0.4))
	if is_boss() and not iso:
		var crown_c := Color(1.0, 0.75, 0.3) if _boss_phase == 1 else Color(1.0, 0.35, 0.1)
		if def.get("rift", false):
			crown_c = Color(0.75, 0.5, 1.0)
		var top := -sprite_height() - 6.0 + sin(_anim * 2.0) * 4.0
		var cpts := PackedVector2Array()
		for i in 9:
			var x := -36.0 + 72.0 * i / 8.0
			cpts.append(Vector2(x, top - (22.0 if i % 2 == 0 else 6.0)))
		draw_polyline(cpts, crown_c, 4.0, true)
		draw_line(Vector2(-36, top), Vector2(36, top), crown_c, 4.0)

# ---------- visuals ----------

var _spr: AnimatedSprite2D
var _mat: ShaderMaterial

func sprite_height() -> float:
	var key := "%s_idle_anim" % def.get("sprite", "zombie")
	return Art.size_of(key).y * float(def.get("px", 4.0))

func _build_visuals() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/sprite_fx.gdshader")
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = Art.frames_for(def.get("sprite", "zombie"))
	var px: float = def.get("px", 4.0) * (1.2 if rarity == "rare" else 1.0)
	_spr.scale = Vector2.ONE * px
	_spr.position = Vector2(0, -sprite_height() * (1.2 if rarity == "rare" else 1.0) / 2.0 + 4.0)
	_spr.material = _mat
	_spr.speed_scale = randf_range(0.85, 1.15)
	_spr.play("idle")
	_spr.frame = randi() % 4
	add_child(_spr)
	if def.has("light") or rarity == "rare" or is_boss():
		var lc: Color = def.get("light", Color(1.0, 0.8, 0.35))
		if rarity == "rare":
			lc = Color(1.0, 0.8, 0.35)
		var l := FX.make_light(lc, 520.0 if is_boss() else (220.0 if rarity == "rare" else 160.0), 1.1 if is_boss() else 0.75)
		l.position = Vector2(0, -20)
		add_child(l)

func _update_visuals() -> void:
	if _spr == null:
		return
	var anim := "run" if velocity.length() > 25.0 else "idle"
	if _spr.animation != anim and _spr.sprite_frames.has_animation(anim):
		_spr.play(anim)
	_spr.flip_h = facing.x < -0.05
	var tint := Color.WHITE
	if is_chilled():
		tint = Color(0.55, 0.8, 1.0)
	elif shock_time > 0.0:
		tint = Color(1.0, 1.0, 0.65)
	if rarity == "magic":
		tint = tint * Color(0.85, 0.9, 1.15)
	if is_boss() and _boss_phase == 2:
		tint = tint * Color(1.25, 0.8, 0.7)
	if def.get("rift", false):
		tint = tint * Color(0.85, 0.6, 1.3)
	if def.has("tint"):
		tint = tint * def.tint
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("flash", 0.75 if hit_flash > 0.0 else 0.0)
	# attack lunge
	var px: float = def.get("px", 4.0) * (1.2 if rarity == "rare" else 1.0)
	var squash := 1.0 + (0.12 if busy_time > 0.0 and fmod(_anim, 0.3) < 0.15 else 0.0)
	_spr.scale = Vector2(px * squash, px / squash)
