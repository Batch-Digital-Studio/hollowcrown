class_name SkillExec
extends RefCounted
## Executes a Rite for any actor (player or monster). Behaviour is chosen by skill.behavior.

static func use(skill_id: String, user: Actor, target_pos: Vector2) -> bool:
	if not user.can_use(skill_id):
		return false
	var s: Dictionary = SkillsDB.SKILLS[skill_id]
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
	match s.behavior:
		"projectile": _projectiles(s, user, origin, dir)
		"radial": _radial(s, user, origin)
		"melee_arc": _melee_arc(s, user, origin, dir)
		"nova": _nova(s, user, origin)
		"chain": _chain(s, user, origin, target_pos)
		"ground": _ground(s, user, origin, target_pos)
		"telegraph": _telegraph(s, user, origin)
	return true

static func is_player(a: Actor) -> bool:
	return a.faction == "player"

static func _projectiles(s: Dictionary, user: Actor, origin: Vector2, dir: Vector2) -> void:
	var count := 1 + int(user.stats.get_stat("proj_count_add"))
	var spread := deg_to_rad(10.0)
	for i in count:
		var off := (i - (count - 1) / 2.0) * spread
		var p := Projectile.new()
		p.setup(s, user, origin + dir * (user.radius + 4.0), dir.rotated(off))
		user.game().world_layer.add_child(p)
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
		user.game().world_layer.add_child(p)
	FX.ring(origin, user.radius * 2.5, s.color, 0.3)
	FX.sound("nova", origin, -4.0)

static func _melee_arc(s: Dictionary, user: Actor, origin: Vector2, dir: Vector2) -> void:
	var r: float = s.radius * user.stats.inc_mult(["inc_area"])
	var half := deg_to_rad(float(s.arc_deg) / 2.0)
	var hits := 0
	for t in user.game().targets_in_circle(user.faction, origin, r):
		var to: Vector2 = t.global_position - origin
		if to.length() > 1.0 and absf(dir.angle_to(to)) > half + atan2(t.radius, to.length()):
			continue
		var res := Damage.roll_hit(s, user.stats, user.game().rng)
		t.take_hit(res, user, to, 260.0 if is_player(user) else 120.0)
		hits += 1
	FX.sound("slash", null if is_player(user) else origin, -8.0 if is_player(user) else -14.0)
	var fx := SlashFX.new()
	fx.position = origin
	fx.dir = dir
	fx.radius = r
	fx.arc = half * 2.0
	fx.color = s.color
	user.game().world_layer.add_child(fx)
	if hits > 0 and is_player(user):
		FX.hitstop(0.045)
		FX.shake(5.0 + hits)

static func _nova(s: Dictionary, user: Actor, origin: Vector2) -> void:
	var r: float = s.radius * user.stats.inc_mult(["inc_area"])
	var hits := 0
	for t in user.game().targets_in_circle(user.faction, origin, r):
		var res := Damage.roll_hit(s, user.stats, user.game().rng)
		t.take_hit(res, user, t.global_position - origin, 300.0)
		hits += 1
	FX.sound("nova", origin, 0.0)
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
	var chains := int(s.get("chains", 0)) + int(user.stats.get_stat("chain_add"))
	var n := 0
	while cur != null:
		points.append(cur.global_position)
		hit[cur] = true
		var res := Damage.roll_hit(s, user.stats, g.rng)
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

static func _lightning(g: Game, points: Array, color: Color) -> void:
	FX.sound("zap", points[0], -3.0)
	var fx := LightningFX.new()
	fx.points = points
	fx.color = color
	g.world_layer.add_child(fx)

static func _ground(s: Dictionary, user: Actor, origin: Vector2, target_pos: Vector2) -> void:
	var pos := origin + (target_pos - origin).limit_length(float(s.get("range", 600.0)))
	FX.sound("ground", pos, 0.0)
	var gfx := GroundEffect.new()
	gfx.setup(s, user, pos)
	user.game().world_layer.add_child(gfx)

static func _telegraph(s: Dictionary, user: Actor, origin: Vector2) -> void:
	FX.sound("windup", origin, -2.0, 0.0)
	var t := Telegraph.new()
	t.setup(s, user)
	user.game().world_layer.add_child(t)
