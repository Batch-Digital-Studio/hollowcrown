class_name SkillExec
extends RefCounted
## Executes a Rite for any actor (player or monster). Behaviour is chosen by skill.behavior.

static func use(skill_id: String, user: Actor, target_pos: Vector2) -> bool:
	if not user.can_use(skill_id):
		return false
	var s: Dictionary = user.skill_def(skill_id) if user.has_method("skill_def") else SkillsDB.SKILLS[skill_id]
	user.cast_stats = user.stats_for(skill_id) if user.has_method("stats_for") else user.stats
	if s.has("spirit_cost") and s.behavior != "raise":
		if float(user.get("spirit")) < float(s.spirit_cost):
			return false
		user.set("spirit", float(user.get("spirit")) - float(s.spirit_cost))
	if s.has("res_cost"):
		if not user.has_method("can_pay") or not user.can_pay(s.res_cost):
			return false
		if s.behavior == "lance" and float(user.res.get("kindling", 0.0)) < 1.0:
			return false
	if s.behavior == "lance" and s.get("tags", []).has("spender") and user.has_method("can_pay") and float(user.res.get("kindling", 0.0)) < 1.0:
		FX.text(user.global_position, "No Kindling", Color(1.0, 0.6, 0.3), 14)
		return false
	if user.has_method("pre_cast"):
		user.pre_cast(skill_id, s)
	if s.has("res_cost"):
		user.pay(s.res_cost)
	user.mana -= float(s.get("cost", 0))
	user.busy_time = user.use_time(s)
	if s.has("cooldown"):
		user.cooldowns[skill_id] = float(s.cooldown)
	var origin := user.global_position
	var dir := (target_pos - origin)
	if dir.length() < 1.0:
		dir = user.facing
	dir = dir.normalized()
	user.facing = dir
	user.last_act = skill_id
	user.last_act_kind = String(s.get("kind", ""))
	user.last_act_behavior = String(s.get("behavior", ""))
	user.last_act_fx = String(s.get("fx3d", ""))
	user.act_serial += 1
	if user.has_method("on_skill_used"):
		user.on_skill_used(s)
	_behave(s, user, origin, dir, target_pos)
	if s.kind == "spell" and is_player(user) and user.stats.get_stat("echo_crown") > 0.0 and not s.has("special_fx") and not ["grand_rite", "cataclysm", "hunters_moon", "blink", "buff", "warcry", "totem", "companion", "raise"].has(s.behavior):
		var cs: StatBlock = user.cast_stats
		user.get_tree().create_timer(0.18, false).timeout.connect(func():
			if is_instance_valid(user) and not user.dead:
				user.cast_stats = cs
				_behave(s, user, user.global_position, dir, target_pos))
	return true

static func _behave(s: Dictionary, user: Actor, origin: Vector2, dir: Vector2, target_pos: Vector2) -> void:
	match s.behavior:
		"projectile": _projectiles(s, user, origin, dir)
		"radial": _radial(s, user, origin)
		"melee_arc": _melee_arc(s, user, origin, dir)
		"nova": _nova(s, user, origin)
		"chain": _chain(s, user, origin, target_pos)
		"ground": _ground(s, user, origin, target_pos)
		"telegraph": _telegraph(s, user, origin)
		"summon": _summon(s, user, origin)
		"raise": _raise(s, user, target_pos)
		"curse": _curse(s, user, origin, target_pos)
		"totem": _totem(s, user, origin, target_pos)
		"beam": _beam(s, user, origin, target_pos)
		"eruption": _eruption(s, user, origin, target_pos)
		"corpse_burst": _corpse_burst(s, user, origin, target_pos)
		"grand_rite": _grand_rite(s, user, origin)
		"blink": _blink(s, user, origin, target_pos)
		"wall": _wall(s, user, origin, target_pos)
		"prison": _prison(s, user, origin, target_pos)
		"lance": _lance(s, user, origin, dir)
		"cataclysm": _cataclysm(s, user)
		"rush": _rush(s, user, origin, target_pos)
		"smite": _smite(s, user, origin, target_pos)
		"fissure": _fissure(s, user, origin, dir)
		"warcry": _warcry(s, user, origin)
		"buff": _buff(s, user, origin)
		"vault": _vault(s, user, origin, dir)
		"rain": _rain(s, user, origin, target_pos)
		"companion": _companion(s, user, origin)
		"hunters_moon": _hunters_moon(s, user, origin)

static func is_player(a: Actor) -> bool:
	return a.faction == "player"

static func _projectiles(s: Dictionary, user: Actor, origin: Vector2, dir: Vector2) -> void:
	var count := 1 + int(user.cast_stats.get_stat("proj_count_add")) + int(s.get("extra_proj", 0))
	var spread := deg_to_rad(float(s.get("spread", 10.0 if count < 4 else 7.0)))
	for i in count:
		var off := (i - (count - 1) / 2.0) * spread
		var p := Projectile.new()
		p.setup(s, user, origin + dir * (user.radius + 4.0), dir.rotated(off))
		user.game().fx_node.add_child(p)
	if is_player(user):
		FX.flash(origin + dir * 24.0, s.color, 40.0, 0.12)
		FX.sound("bolt", null, -11.0)
	else:
		FX.sound("bolt", origin, -16.0)

static func _radial(s: Dictionary, user: Actor, origin: Vector2) -> void:
	var count: int = s.get("count", 12)
	var start := user.game().rng.randf() * TAU
	for i in count:
		var p := Projectile.new()
		var d := Vector2.RIGHT.rotated(start + TAU * i / count)
		p.setup(s, user, origin + d * (user.radius + 4.0), d)
		user.game().fx_node.add_child(p)
	FX.ring(origin, user.radius * 2.5, s.color, 0.3)
	FX.sound("nova", origin, -4.0)

static func _melee_arc(s: Dictionary, user: Actor, origin: Vector2, dir: Vector2) -> void:
	var r: float = s.radius * user.cast_stats.inc_mult(["inc_area"])
	var half := deg_to_rad(float(s.arc_deg) / 2.0)
	var hits := 0
	for t in user.game().targets_in_circle(user.faction, origin, r):
		var to: Vector2 = t.global_position - origin
		if to.length() > 1.0 and absf(dir.angle_to(to)) > half + atan2(t.radius, to.length()):
			continue
		var res := Damage.roll_hit(s, user.cast_stats, user.game().rng)
		t.take_hit(res, user, to, 260.0 if is_player(user) else 120.0)
		hits += 1
		if s.get("brand", 0.0) > 0.0:
			t.brand_time = 6.0
			t.brand_owner = user
			FX.ring(t.global_position, 30.0, Color(1.0, 0.75, 0.3), 0.3)
	FX.sound("slash", null if is_player(user) else origin, -8.0 if is_player(user) else -14.0)
	var fx := SlashFX.new()
	fx.position = origin
	fx.dir = dir
	fx.radius = r
	fx.arc = half * 2.0
	fx.color = s.color
	user.game().fx_node.add_child(fx)
	if hits > 0 and is_player(user):
		FX.hitstop(0.045)
		FX.shake(5.0 + hits)
	if is_player(user) and user.cast_stats.get_stat("oath_fire") > 0.0:
		var wave := {"kind": "attack", "base_damage": {"fire": [10, 16]}, "effectiveness": 80.0, "crit": 5.0, "tags": ["area"], "ignite_chance": 30.0}
		var wpos := origin + dir * r * 0.8
		for t2 in user.game().targets_in_circle(user.faction, wpos, 120.0):
			t2.take_hit(Damage.roll_hit(wave, user.cast_stats, user.game().rng), user, t2.global_position - wpos, 150.0)
		FX.ring(wpos, 120.0, Color(1.0, 0.5, 0.2), 0.3, 8.0)

static func _nova(s: Dictionary, user: Actor, origin: Vector2) -> void:
	var r: float = s.radius * user.cast_stats.inc_mult(["inc_area"])
	var hits := 0
	for t in user.game().targets_in_circle(user.faction, origin, r):
		var res := Damage.roll_hit(s, user.cast_stats, user.game().rng)
		t.take_hit(res, user, t.global_position - origin, 300.0)
		hits += 1
	FX.sound("nova", origin, 0.0)
	FX.event3d("nova", origin, ElementFx.of_skill(s), r)
	FX.ring(origin, r, s.color, 0.4, 10.0)
	FX.burst(origin, s.color, 40, r * 2.2, 8.0, 0.5)
	FX.flash(origin, s.color, r * 0.8, 0.25)
	if is_player(user):
		FX.shake(7.0)
		if hits > 0:
			FX.hitstop(0.05)

static func _chain(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var rng_max: float = s.range
	# First target: closest enemy to the cursor that is within range of the caster.
	var first: Actor = null
	var best := INF
	for t in g.targets_in_circle(user.faction, origin, rng_max):
		var d: float = t.global_position.distance_to(target_pos)
		if d < best:
			best = d
			first = t
	var points: Array = [origin]
	if first == null:
		var end := origin + (target_pos - origin).limit_length(rng_max * 0.6)
		points.append(end)
		_lightning(g, points, s.color)
		return
	var hit := {}
	var cur: Actor = first
	var chains := int(s.get("chains", 0)) + int(user.cast_stats.get_stat("chain_add"))
	var n := 0
	while cur != null:
		points.append(cur.global_position)
		hit[cur] = true
		var res := Damage.roll_hit(s, user.cast_stats, g.rng)
		cur.take_hit(res, user, cur.global_position - points[points.size() - 2], 90.0)
		FX.flash(cur.global_position, s.color, 50.0, 0.15)
		if n >= chains:
			break
		n += 1
		var next: Actor = null
		var nd := INF
		for t in g.targets_in_circle(user.faction, cur.global_position, float(s.chain_range)):
			if hit.has(t) or t.dead:
				continue
			var d: float = t.global_position.distance_to(cur.global_position)
			if d < nd:
				nd = d
				next = t
		cur = next
	_lightning(g, points, s.color)
	if is_player(user):
		FX.shake(3.0 + n)

static func _lightning(g: Game, points: Array, color: Color, element: String = "lightning") -> void:
	FX.sound("zap", points[0], -3.0)
	FX.event3d("chain", points[0], element, 0.0, {"points": points})
	var fx := LightningFX.new()
	fx.points = points
	fx.color = color
	g.fx_node.add_child(fx)

static func _ground(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var pos := origin + (target_pos - origin).limit_length(float(s.get("range", 600.0)))
	FX.sound("ground", pos, 0.0)
	var gfx := GroundEffect.new()
	gfx.setup(s, user, pos)
	user.game().fx_node.add_child(gfx)
	if s.get("trap", false) and user.stats.get_stat("trap_extra") > 0.0:
		var side := (target_pos - origin).normalized().orthogonal()
		for k in int(user.stats.get_stat("trap_extra")):
			var g2 := GroundEffect.new()
			g2.setup(s, user, pos + side * (float(s.radius) * 1.6) * (1.0 if k % 2 == 0 else -1.0))
			user.game().fx_node.add_child(g2)

static func _telegraph(s: Dictionary, user: Actor, origin: Vector2) -> void:
	FX.sound("windup", origin, -2.0, 0.0)
	var t := Telegraph.new()
	t.setup(s, user)
	user.game().fx_node.add_child(t)

static func _summon(s: Dictionary, user: Actor, origin: Vector2) -> void:
	var g := user.game()
	var alive := 0
	for e in g.enemies:
		if e.has_meta("summoner") and e.get_meta("summoner") == user:
			alive += 1
	var n := mini(int(s.count), int(s.get("max_minions", 6)) - alive)
	FX.sound("portal", origin, -6.0, 0.1)
	FX.ring(origin, 90.0, s.color, 0.5, 6.0)
	for i in n:
		var p := origin + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * g.rng.randf_range(50, 110)
		if g.is_wall(p):
			p = origin
		var e := g.spawn_enemy(String(s.minion), user.level, "normal", [], p)
		e.aggro = true
		e.set_meta("summoner", user)
		e.set_meta("minion", true)
		FX.burst(p, s.color, 18, 160.0, 7.0, 0.5)


# ---------------- Bog Shaman ----------------

static func _clamp_target(s: Dictionary, origin: Vector2, target_pos: Vector2) -> Vector2:
	return origin + (target_pos - origin).limit_length(float(s.get("range", 600.0)))

static func owned_minions(g: Game, user: Actor, temporary: bool) -> Array:
	var out: Array = []
	for a in g.allies:
		if a is Minion and a.kind == "husk" and a.owner_actor == user and (a.temporary > 0.0) == temporary:
			out.append(a)
	return out

static func spawn_minion(g: Game, user: Actor, pos: Vector2, temp: float = 0.0) -> Minion:
	if OS.get_environment("HC_DEBUG") != "": print("DBG spawn minion temp=", temp, " t=", Time.get_ticks_msec())
	var m := Minion.new()
	m.setup(user, user.level, pos, temp)
	g.world_layer.add_child(m)
	g.allies.append(m)
	return m

static func _raise(s: Dictionary, user: Actor, target_pos: Vector2) -> void:
	var g := user.game()
	var st := user.cast_stats
	var cap := int(s.max) + int(st.get_stat("minion_max_add"))
	if st.get_stat("husk_brute") > 0.0:
		cap = maxi(1, cap - 2)
	var have := owned_minions(g, user, false)
	var room := cap - have.size()
	if room <= 0:
		# Already at the cap: heal and refresh the existing husks instead
		for m in have:
			m.heal(m.max_life * 0.3)
			FX.burst(m.global_position, Color(0.5, 0.95, 0.4), 8, 120.0, 6.0)
		return
	var corpses: Array = g.corpses_near(target_pos, float(s.radius), room)
	for c in corpses:
		var pos: Vector2 = c.pos
		g.consume_corpse(c)
		spawn_minion(g, user, pos)
		room -= 1
	if corpses.is_empty():
		# No bodies (boss arenas): raise a weaker Ash Husk from the ground instead
		var am := spawn_minion(g, user, user.global_position + (target_pos - user.global_position).limit_length(120.0))
		am.max_life *= 0.6
		am.life = am.max_life
		am.display_name = "Ash Husk"
		am.modulate = Color(0.85, 0.85, 0.85)
	FX.sound("portal", null, -8.0, 0.15)
	FX.ring(target_pos, float(s.radius) * 0.5, s.color, 0.4, 5.0)

static func _curse(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var st := user.cast_stats
	var pos := _clamp_target(s, origin, target_pos)
	var r: float = float(s.radius) * st.inc_mult(["inc_area"])
	var eff := st.inc_mult(["inc_curse_effect"])
	var dur: float = float(s.duration) * st.inc_mult(["inc_duration"])
	for t in g.targets_in_circle(user.faction, pos, r):
		t.apply_curse(user, float(s.curse_taken) / 100.0 * eff, float(s.curse_dot) * eff, dur, st.get_stat("hex_spread") > 0.0)
	FX.ring(pos, r, s.color, 0.5, 8.0)
	FX.burst(pos, s.color, 24, r * 1.5, 7.0, 0.6)
	FX.sound("windup", pos, -8.0, 0.0)

static func _totem(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var st := user.cast_stats
	var pos := _clamp_target(s, origin, target_pos)
	if g.is_wall(pos):
		pos = origin + (target_pos - origin).normalized() * 80.0
		if g.is_wall(pos):
			pos = origin
	var ward: bool = s.get("ward", false)
	var banner: bool = s.get("banner", false)
	var cap := 1 if ward else 1 + int(st.get_stat("totem_max_add"))
	if banner:
		cap = 1 + int(st.get_stat("banner_max_add"))
	var mine: Array = []
	for a in g.allies:
		if a is Totem and a.owner_actor == user and a.ward == ward and bool(a.skill.get("banner", false)) == banner:
			mine.append(a)
	while mine.size() >= cap:
		var oldest: Totem = mine.pop_front()
		oldest.die(null)
	var t := Totem.new()
	t.setup(user, s, pos, st)
	g.world_layer.add_child(t)
	g.allies.append(t)

static func _beam(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var st := user.cast_stats
	var rng_: float = float(s.range)
	var first: Actor = null
	var best := INF
	for t in g.targets_in_circle(user.faction, origin, rng_):
		var d: float = t.global_position.distance_to(target_pos)
		if d < best and g.has_line_of_sight(origin, t.global_position):
			best = d
			first = t
	if first == null:
		return
	var points: Array = [origin + Vector2(0, -20)]
	var cur: Actor = first
	var hit := {}
	var heal := 0.0
	for i in 1 + int(s.get("chains", 0)):
		if cur == null:
			break
		hit[cur] = true
		points.append(cur.global_position + Vector2(0, -16))
		heal += cur.take_hit(Damage.roll_hit(s, st, g.rng), user)
		var nxt: Actor = null
		var nd := INF
		for t in g.targets_in_circle(user.faction, cur.global_position, 260.0):
			if not hit.has(t):
				var d: float = t.global_position.distance_to(cur.global_position)
				if d < nd:
					nd = d
					nxt = t
		cur = nxt
	user.heal(heal * float(s.heal) / 100.0)
	_lightning(g, points, s.color, ElementFx.of_skill(s))
	FX.sound("zap", null, -20.0, 0.2)

static func _eruption(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var pos := _clamp_target(s, origin, target_pos)
	var waves := 2 if float(s.get("twice", 0.0)) > 0.0 else 1
	for i in waves:
		var e := Eruption.new()
		e.setup(s, user, pos, user.cast_stats, i * 0.6)
		g.fx_node.add_child(e)
	FX.sound("windup", pos, -10.0, 0.0)

static func _corpse_burst(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var st := user.cast_stats
	var pos := _clamp_target(s, origin, target_pos)
	var r: float = float(s.radius) * st.inc_mult(["inc_area"])
	var list: Array = g.corpses_near(pos, float(s.search), int(s.corpses))
	if list.is_empty():
		FX.text(user.global_position, "No corpses", Color(0.7, 0.7, 0.7), 16)
		return
	for c in list:
		var cpos: Vector2 = c.pos
		var dmg: float = float(c.life) * float(s.life_pct) / 100.0
		var bs := s.duplicate()
		bs.base_damage = {"fire": [dmg * 0.9, dmg * 1.1]}
		bs.ignite_chance = 30.0
		for t in g.targets_in_circle(user.faction, cpos, r):
			t.take_hit(Damage.roll_hit(bs, st, g.rng), user, t.global_position - cpos, 220.0)
		g.consume_corpse(c)
		FX.ring(cpos, r, s.color, 0.35, 10.0)
		FX.burst(cpos, Color(0.7, 0.15, 0.1), 30, r * 2.4, 9.0, 0.5)
		FX.flash(cpos, s.color, r, 0.25)
	FX.shake(6.0)
	FX.sound("boom", pos, -4.0)
	FX.rumble(0.3, 0.4, 0.2)

static func _grand_rite(s: Dictionary, user: Actor, origin: Vector2) -> void:
	var g := user.game()
	var max_n := int(s.max)
	var hcap := int(user.stats.get_stat("horde_cap"))
	if hcap > 0:
		var have := owned_minions(g, user, true).size()
		max_n = maxi(0, mini(max_n, hcap - have))
	var list: Array = g.corpses_near(origin, float(s.radius), max_n)
	var n := 0
	for c in list:
		var pos: Vector2 = c.pos
		g.consume_corpse(c)
		spawn_minion(g, user, pos, float(s.duration))
		n += 1
	while n < mini(4, max_n):
		spawn_minion(g, user, origin + Vector2.RIGHT.rotated(n * TAU / 4.0) * 90.0, float(s.duration))
		n += 1
	FX.ring(origin, 420.0, s.color, 0.8, 14.0)
	FX.burst(origin, s.color, 60, 500.0, 10.0, 0.8)
	FX.light_flash(origin, s.color, 700.0, 0.8, 2.0)
	FX.text(origin, "GRAND RITE", Color(0.6, 1.0, 0.5), 34)
	FX.shake(12.0)
	FX.sound("portal", null, 2.0, 0.0)
	FX.rumble(0.6, 0.8, 0.6)


# ---------------- Ember Magus ----------------

static func _blink(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var to := (target_pos - origin).limit_length(float(s.range))
	var dest := origin
	var steps := 12
	for i in range(1, steps + 1):
		var p := origin + to * float(i) / steps
		if g.is_wall(p):
			break
		dest = p
	_hit_area(s, user, origin, float(s.radius))
	FX.burst(origin, s.color, 24, 220.0, 7.0, 0.4)
	FX.event3d("blink", origin, ElementFx.of_skill(s), float(s.radius), {"to": dest})
	user.global_position = dest
	FX.flash(dest, s.color, 70.0, 0.2)
	if user.stats.get_stat("thunderstep") > 0.0:
		var bl: Dictionary = SkillsDB.SKILLS["ball_lightning"].duplicate()
		bl.speed = 220.0
		bl.range = 260.0
		for k in 3:
			var pr := Projectile.new()
			user.cast_stats = user.stats
			pr.setup(bl, user, origin, Vector2.RIGHT.rotated(k * TAU / 3.0))
			g.fx_node.add_child(pr)
	FX.sound("dodge", null, -6.0)

static func _hit_area(s: Dictionary, user: Actor, pos: Vector2, r: float) -> void:
	if s.get("base_damage", {}).is_empty():
		return
	var g := user.game()
	for t in g.targets_in_circle(user.faction, pos, r * user.cast_stats.inc_mult(["inc_area"])):
		t.take_hit(Damage.roll_hit(s, user.cast_stats, g.rng), user, t.global_position - pos, 160.0)

static func _wall(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var center := _clamp_target(s, origin, target_pos)
	var perp := (target_pos - origin).normalized().orthogonal()
	var n := int(s.count)
	for i in n:
		var p := center + perp * (i - (n - 1) / 2.0) * float(s.radius) * 1.4
		if g.is_wall(p):
			continue
		var gfx := GroundEffect.new()
		gfx.setup(s, user, p)
		g.fx_node.add_child(gfx)
	FX.sound("ground", center, -4.0)

static func _prison(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var best: Actor = null
	var bd := INF
	for t in g.targets_in_circle(user.faction, origin, float(s.range)):
		var d: float = t.global_position.distance_to(target_pos)
		if d < bd:
			bd = d
			best = t
	if best == null:
		return
	best.take_hit(Damage.roll_hit(s, user.cast_stats, g.rng), user)
	best.chill_time = maxf(best.chill_time, float(s.duration) + 1.0)
	var boss: bool = best is Enemy and best.is_boss()
	if not boss:
		best.root_time = maxf(best.root_time, float(s.duration))
		best.busy_time = maxf(best.busy_time, float(s.duration))
	FX.ring(best.global_position, 70.0, s.color, 0.5, 8.0)
	FX.event3d("prison", best.global_position, ElementFx.of_skill(s), best.radius * 1.6)
	FX.burst(best.global_position, s.color, 30, 200.0, 8.0, 0.6)
	FX.sound("nova", best.global_position, -6.0)

static func _lance(s: Dictionary, user: Actor, origin: Vector2, dir: Vector2) -> void:
	var g := user.game()
	var length := float(s.range)
	for i in range(1, 30):
		if g.is_wall(origin + dir * length * i / 30.0):
			length = length * (i - 1) / 30.0
			break
	var end := origin + dir * length
	var w := float(s.width)
	for t in g.targets_in_circle(user.faction, origin + dir * length / 2.0, length / 2.0 + w):
		var p: Vector2 = t.global_position
		var proj := clampf((p - origin).dot(dir), 0.0, length)
		if p.distance_to(origin + dir * proj) <= w + t.radius:
			t.take_hit(Damage.roll_hit(s, user.cast_stats, g.rng), user, dir, 200.0)
	FX.event3d("lance", origin, ElementFx.of_skill(s), w, {"end": end})
	var fx := LightningFX.new()
	fx.points = [origin, end]
	fx.color = s.color
	g.fx_node.add_child(fx)
	for i in 6:
		FX.flash(origin.lerp(end, i / 5.0), s.color, 60.0, 0.3)
	FX.shake(6.0)
	FX.sound("nova", origin, -2.0)

static func _cataclysm(s: Dictionary, user: Actor) -> void:
	var c := Cataclysm.new()
	c.setup(s, user)
	user.game().fx_node.add_child(c)
	FX.text(user.global_position, "CATACLYSM", Color(1.0, 0.6, 0.25), 34)
	FX.rumble(0.5, 0.7, 0.5)

# ---------------- Oathsworn ----------------

static func _rush(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var to := (target_pos - origin).limit_length(float(s.range))
	if user.has_method("start_dash"):
		user.start_dash(to.normalized(), to.length(), 0.18, func():
			var g := user.game()
			var p := user.global_position
			for t in g.targets_in_circle(user.faction, p, float(s.radius) * user.cast_stats.inc_mult(["inc_area"])):
				t.take_hit(Damage.roll_hit(s, user.cast_stats, g.rng), user, t.global_position - p, 320.0)
				t.root_time = maxf(t.root_time, float(s.root))
			FX.ring(p, float(s.radius), s.color, 0.3, 8.0)
			FX.shake(6.0)
			FX.hitstop(0.05)
			FX.sound("boom", null, -8.0))

static func _fissure(s: Dictionary, user: Actor, origin: Vector2, dir: Vector2) -> void:
	var g := user.game()
	for i in int(s.count):
		var p := origin + dir * (60.0 + i * float(s.spacing))
		if g.is_wall(p):
			break
		var e := Eruption.new()
		e.style = "fissure"
		e.setup(s, user, p, user.cast_stats, i * 0.05)
		e.root = 0.0
		g.fx_node.add_child(e)
	FX.shake(6.0)

static func _warcry(s: Dictionary, user: Actor, origin: Vector2) -> void:
	var g := user.game()
	var r := float(s.radius)
	var n_hit := 0
	for t in g.targets_in_circle(user.faction, origin, r):
		if t is Enemy:
			t._target = user
			t._retarget = 3.0
			t.aggro = true
			n_hit += 1
	var wr := user.stats.get_stat("warcry_resolve")
	if wr > 0.0 and user.has_method("gain_res"):
		user.gain_res("resolve", wr * n_hit)
	var buff: Dictionary = s.buff.duplicate()
	var rally := user.stats.get_stat("rally_speed")
	if rally > 0.0:
		buff["inc_attack_speed"] = float(buff.get("inc_attack_speed", 0.0)) + rally
		for a in g.allies:
			if a is Minion and a.owner_actor == user:
				a.haste_t = float(s.duration)
				a.haste_amt = rally / 100.0
	if user.has_method("add_buff"):
		user.add_buff(s.name, buff, float(s.duration))
	FX.ring(origin, r, s.color, 0.5, 10.0)
	FX.text(origin, s.name.to_upper(), s.color, 22)
	FX.sound("windup", null, -4.0, 0.0)

static func _buff(s: Dictionary, user: Actor, origin: Vector2) -> void:
	var id: String = s.get("special_fx", s.name)
	if user.has_method("add_buff"):
		user.add_buff(id, s.buff, float(s.duration))
	if s.has("heal_pct"):
		user.heal(user.max_life * float(s.heal_pct) / 100.0)
	if s.get("special_fx", "") == "oathbreaker" and user.stats.get_stat("shared_oath") > 0.0:
		for a in user.game().allies:
			if a is Minion and a.owner_actor == user:
				a.empower_t = float(s.duration)
				a.empower_amt = 0.4
				FX.burst(a.global_position, Color(1.0, 0.6, 0.2), 10, 140.0, 6.0, 0.4)
	FX.ring(origin, 90.0, s.color, 0.4, 8.0)
	FX.burst(origin, s.color, 24, 200.0, 7.0, 0.5)
	if s.has("special_fx"):
		FX.text(origin, s.name.to_upper(), s.color, 34)
		FX.shake(10.0)
		FX.rumble(0.5, 0.7, 0.4)
		FX.sound("levelup", null, -2.0, 0.0)
	else:
		FX.sound("flask", null, -6.0)

# ---------------- Hollow Ranger ----------------

static func _vault(s: Dictionary, user: Actor, origin: Vector2, dir: Vector2) -> void:
	if user.has_method("start_dash"):
		user.start_dash(-dir, 220.0, 0.16, func(): pass)
	_projectiles(s, user, origin, dir)

static func _rain(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var center := _clamp_target(s, origin, target_pos)
	var r := float(s.radius) * user.cast_stats.inc_mult(["inc_area"])
	var imp := s.duplicate()
	imp.radius = float(s.impact)
	imp.windup = 0.2
	for i in int(s.count):
		var p := center + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * sqrt(g.rng.randf()) * r
		var e := Eruption.new()
		e.style = "arrow"
		e.setup(imp, user, p, user.cast_stats, i * 0.06)
		e.root = 0.0
		g.fx_node.add_child(e)
	FX.sound("bolt", null, -8.0)

static func _companion(s: Dictionary, user: Actor, origin: Vector2) -> void:
	var g := user.game()
	for a in g.allies.duplicate():
		if a is Minion and a.kind == "hawk" and a.owner_actor == user:
			a.heal(a.max_life)
			FX.burst(a.global_position, s.color, 12, 140.0, 6.0)
			return
	var m := Minion.new()
	m.kind = "hawk"
	m.setup(user, user.level, origin + Vector2(0, -60))
	g.world_layer.add_child(m)
	g.allies.append(m)
	FX.sound("portal", null, -10.0, 0.2)

static func _hunters_moon(s: Dictionary, user: Actor, origin: Vector2) -> void:
	var g := user.game()
	if user.has_method("add_buff"):
		user.add_buff("hunters_moon", s.buff, float(s.duration))
	for e in g.enemies:
		if is_instance_valid(e) and e.global_position.distance_to(origin) < 1300.0:
			e.slow_time = float(s.duration)
			e.slow_amt = 0.5
	FX.ring(origin, 600.0, s.color, 0.8, 12.0)
	FX.light_flash(origin, s.color, 900.0, 1.0, 1.4)
	FX.text(origin, "HUNTER'S MOON", s.color, 34)
	FX.rumble(0.4, 0.4, 0.5)
	FX.sound("portal", null, 0.0, 0.0)

## Strike from the sky at the target after a short delay (Thunderfall, Judgment): hits a circle.
static func _smite(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var g := user.game()
	var pos := _clamp_target(s, origin, target_pos)
	var n := int(s.get("count", 1))
	for i in n:
		var p := pos
		if i > 0:
			p += Vector2.RIGHT.rotated(g.rng.randf() * TAU) * g.rng.randf_range(60.0, float(s.radius) * 1.6)
		var h := Hazard.make(user, "circle", p, s, float(s.get("windup", 0.35)) + i * 0.12)
		h.r = float(s.radius) * user.cast_stats.inc_mult(["inc_area"])
		h.knock = 120.0
		h.set_meta("fx3d", "strike")
		h.set_meta("stats", user.cast_stats)
		g.fx_node.add_child(h)
	FX.sound("windup", pos, -10.0, 0.0)
