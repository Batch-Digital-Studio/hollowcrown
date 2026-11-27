class_name BossBrain
extends RefCounted
## Mechanics for the rotating bosses. Each kit reads differently:
##   rot   - The Rot Mother: bile slams leave poison pools, broods of husks (corpses for Shamans), pool rain in phase 2.
##   frost - The Frostwarden: alternates "get in" rings and "get out" bursts, fans of ice lances, chilling aura in phase 2.
##   pyre  - The Pyre Brute: telegraphed charge that leaves fire; hitting a wall staggers him (takes 50% more damage).
##   grave - The Gravecaller King: shielded while his guard lives, bone-spear bursts, blinks away leaving a blast.
## Phase 2 starts at 50% life. All randomness from Game.rng.

var e: Enemy
var kind := ""
var phase := 1
var cd := {}
var _flip := false
# pyre charge
var charge_t := 0.0
var charge_dir := Vector2.ZERO
var charge_left := 0.0
var charge_wind := 0.0
var _trail := 0.0
var stagger := 0.0
var _charge_hit := false
# grave
var guards: Array = []

func setup(enemy: Enemy) -> void:
	e = enemy
	kind = String(e.def.get("brain", ""))
	cd = {"a": 1.5, "b": 3.0, "c": 6.0, "d": 9.0}
	if kind == "grave":
		cd["c"] = 1.0   # guard first

func g() -> Game:
	return e.game()

func shielded() -> bool:
	for x in guards:
		if is_instance_valid(x) and not x.dead:
			return true
	return false

func taken_mult() -> float:
	var m := 1.0
	if kind == "grave" and shielded():
		m *= 0.1
	if stagger > 0.0:
		m *= 1.5
	return m

func _cool(k: String, p1: float, p2: float) -> void:
	cd[k] = p1 if phase == 1 else p2

func tick(p: Actor, to_p: Vector2, dist: float, delta: float) -> Vector2:
	for k in cd:
		cd[k] -= delta
	if phase == 1 and e.life < e.max_life * 0.5:
		phase = 2
		FX.text(e.global_position, e.def.get("enrage_text", "ENRAGED"), Color(1.0, 0.5, 0.2), 34)
		FX.ring(e.global_position, 420.0, e.def.get("light", Color(1, 0.5, 0.2)), 0.8, 14.0)
		FX.shake(14.0)
		e.stats.add("inc_attack_speed", 20)
		e.stats.add("inc_cast_speed", 20)
	match kind:
		"rot": return _rot(p, to_p, dist)
		"frost": return _frost(p, to_p, dist)
		"pyre": return _pyre(p, to_p, dist, delta)
		"grave": return _grave(p, to_p, dist)
	return Vector2.ZERO

func _hz(shape: String, pos: Vector2, sk_id: String, windup: float) -> Hazard:
	var h := Hazard.make(e, shape, pos, SkillsDB.SKILLS[sk_id], windup)
	g().fx_node.add_child(h)
	return h

func _walk(to_p: Vector2, dist: float, keep: float) -> Vector2:
	return to_p.normalized() if dist > keep else Vector2.ZERO

# ------------------------------------------------------------------ Rot Mother
func _rot(p: Actor, to_p: Vector2, dist: float) -> Vector2:
	if dist < 180.0 and e.can_use("rot_sweep") and cd.a <= 0.0:
		SkillExec.use("rot_sweep", e, p.global_position)
		_cool("a", 2.2, 1.6)
		return Vector2.ZERO
	if cd.b <= 0.0:
		var h := _hz("circle", p.global_position, "rot_slam", 1.3)
		h.r = 150.0
		h.follow = p
		h.lock = 0.5
		var pool: Dictionary = SkillsDB.SKILLS["rot_pool"].duplicate()
		if phase == 2:
			pool.duration = 12.0
		h.pool = pool
		e.busy_time = 0.6
		_cool("b", 3.8, 2.6)
		return Vector2.ZERO
	if cd.c <= 0.0:
		SkillExec.use("rot_spray", e, p.global_position)
		_cool("c", 6.0, 4.0)
		return Vector2.ZERO
	if cd.d <= 0.0:
		var n := 4 if phase == 1 else 6
		for i in n:
			var pos: Vector2 = e.global_position + Vector2.RIGHT.rotated(TAU * i / n) * 140.0
			if not g().is_wall(pos):
				var a := g().spawn_enemy("husk", e.level - 2, "normal", [], pos)
				a.aggro = true
				FX.burst(pos, Color(0.5, 0.95, 0.3), 14, 160.0, 7.0, 0.4)
		FX.text(e.global_position, "The brood rises!", Color(0.55, 1.0, 0.3), 22)
		_cool("d", 14.0, 10.0)
		if phase == 2:
			for i in 4:
				var rp: Vector2 = p.global_position + Vector2.RIGHT.rotated(g().rng.randf() * TAU) * g().rng.randf_range(80.0, 320.0)
				if not g().is_wall(rp):
					var rh := _hz("circle", rp, "rot_slam", 1.4 + i * 0.2)
					rh.r = 110.0
					rh.pool = SkillsDB.SKILLS["rot_pool"]
		return Vector2.ZERO
	return _walk(to_p, dist, 150.0)

# ------------------------------------------------------------------ Frostwarden
func _frost(p: Actor, to_p: Vector2, dist: float) -> Vector2:
	if phase == 2 and dist < 320.0 and p.faction == "player":
		p.chill_time = maxf(p.chill_time, 0.4)
	if dist < 170.0 and e.can_use("frost_sweep") and cd.a <= 0.0:
		SkillExec.use("frost_sweep", e, p.global_position)
		_cool("a", 2.4, 1.8)
		return Vector2.ZERO
	if cd.c <= 0.0:
		_flip = not _flip
		if _flip:
			var h := _hz("ring", e.global_position, "frost_burst", 1.5)
			h.inner = 150.0
			h.r = 460.0
			h.anchor = e
			FX.text(e.global_position, "Come closer...", Color(0.7, 0.9, 1.0), 20)
		else:
			var h2 := _hz("circle", e.global_position, "frost_burst", 1.4)
			h2.r = 280.0
			h2.anchor = e
			FX.text(e.global_position, "Get back!", Color(0.7, 0.9, 1.0), 20)
		e.busy_time = 1.2
		_cool("c", 6.0, 4.5)
		return Vector2.ZERO
	if cd.b <= 0.0:
		var n := 3 if phase == 1 else 5
		var base := to_p.angle()
		for i in n:
			var h3 := _hz("line", e.global_position, "frost_lance_b", 1.0)
			h3.dir = Vector2.RIGHT.rotated(base + deg_to_rad(18.0) * (i - (n - 1) / 2.0))
			h3.length = 850.0
			h3.width = 70.0
			h3.lock = 1.0
		e.busy_time = 0.7
		_cool("b", 4.5, 3.2)
		return Vector2.ZERO
	return _walk(to_p, dist, 140.0)

# ------------------------------------------------------------------ Pyre Brute
func _pyre(p: Actor, to_p: Vector2, dist: float, delta: float) -> Vector2:
	stagger = maxf(0.0, stagger - delta)
	if stagger > 0.0:
		return Vector2.ZERO
	if charge_wind > 0.0:
		charge_wind -= delta
		if charge_wind <= 0.0:
			charge_left = 900.0
			_charge_hit = false
		return Vector2.ZERO
	if charge_left > 0.0:
		var step := 1150.0 * delta
		var nxt := e.global_position + charge_dir * (step + e.radius)
		if g().is_wall(nxt):
			charge_left = 0.0
			stagger = 2.2
			FX.text(e.global_position, "STAGGERED!", Color(1.0, 0.85, 0.4), 28)
			FX.shake(12.0)
			FX.burst(e.global_position, Color(1.0, 0.7, 0.3), 30, 320.0, 8.0, 0.5)
			if phase == 2 and cd.d <= 0.0:
				cd.d = 0.0
			return Vector2.ZERO
		e.global_position += charge_dir * step
		charge_left -= step
		_trail -= step
		if _trail <= 0.0:
			_trail = 90.0
			e.cast_stats = e.stats
			var ge := GroundEffect.new()
			ge.setup(SkillsDB.SKILLS["pyre_trail"], e, e.global_position)
			g().fx_node.add_child(ge)
		if not _charge_hit and p.global_position.distance_to(e.global_position) < e.radius + 30.0:
			_charge_hit = true
			p.take_hit(Damage.roll_hit(SkillsDB.SKILLS["pyre_charge"], e.stats, g().rng), e, charge_dir, 700.0)
		if charge_left <= 0.0 and phase == 2 and cd.a <= 0.0:
			_start_charge(p)   # phase 2: a second charge right away
			cd.a = 6.0
		return Vector2.ZERO
	if dist < 190.0 and cd.c <= 0.0:
		var h := _hz("circle", e.global_position, "pyre_stomp", 0.75)
		h.r = 210.0
		h.anchor = e
		e.busy_time = 0.8
		_cool("c", 3.2, 2.4)
		return Vector2.ZERO
	if cd.b <= 0.0 and dist > 160.0:
		_start_charge(p)
		_cool("b", 6.0, 4.5)
		cd.a = 0.0
		return Vector2.ZERO
	if cd.d <= 0.0:
		var n := 5 if phase == 1 else 8
		for i in n:
			var mp: Vector2 = p.global_position + Vector2.RIGHT.rotated(g().rng.randf() * TAU) * g().rng.randf_range(0.0, 340.0)
			if not g().is_wall(mp):
				var mh := _hz("circle", mp, "pyre_meteor", 1.0 + i * 0.18)
				mh.r = 110.0
		FX.text(e.global_position, "Cinders fall!", Color(1.0, 0.6, 0.25), 22)
		_cool("d", 9.0, 7.0)
		return Vector2.ZERO
	return _walk(to_p, dist, 150.0)

func _start_charge(p: Actor) -> void:
	charge_dir = (p.global_position - e.global_position).normalized()
	charge_wind = 1.0
	var h := _hz("line", e.global_position, "pyre_charge", 1.0)
	h.skill = {"color": Color(1.0, 0.45, 0.15)}   # warning only; the charge itself hits
	h.color = Color(1.0, 0.45, 0.15)
	h.dir = charge_dir
	h.length = 900.0
	h.width = e.radius * 2.0
	FX.sound("windup", e.global_position, -2.0, 0.0)

# ------------------------------------------------------------------ Gravecaller King
func _grave(p: Actor, to_p: Vector2, dist: float) -> Vector2:
	if cd.c <= 0.0 and not shielded():
		guards.clear()
		var n := 4 if phase == 1 else 6
		for i in n:
			var pos: Vector2 = e.global_position + Vector2.RIGHT.rotated(TAU * i / n) * 170.0
			if g().is_wall(pos):
				pos = e.global_position + Vector2.RIGHT.rotated(TAU * i / n) * 80.0
			var gd := g().spawn_enemy("rattler", e.level - 1, "magic", g()._roll_mods(1), pos)
			gd.aggro = true
			guards.append(gd)
			FX.burst(pos, Color(0.75, 0.5, 1.0), 14, 160.0, 7.0, 0.4)
		FX.text(e.global_position, "My guard! (shielded)", Color(0.8, 0.6, 1.0), 22)
		_cool("c", 16.0, 12.0)
		return Vector2.ZERO
	if cd.a <= 0.0:
		SkillExec.use("grave_spears", e, p.global_position)
		if phase == 2:
			e.get_tree().create_timer(0.35, false).timeout.connect(func():
				if is_instance_valid(e) and not e.dead:
					SkillExec.use("grave_spears", e, p.global_position))
		_cool("a", 3.4, 2.6)
		return Vector2.ZERO
	if cd.b <= 0.0 and phase == 2:
		var h := _hz("circle", p.global_position, "grave_rend", 1.5)
		h.r = 140.0
		h.follow = p
		h.lock = 0.5
		_cool("b", 7.0, 6.0)
		return Vector2.ZERO
	if cd.d <= 0.0:
		var old: Vector2 = e.global_position
		var hb := _hz("circle", old, "grave_burst", 0.9)
		hb.r = 190.0
		for t in 40:
			var np: Vector2 = p.global_position + Vector2.RIGHT.rotated(g().rng.randf() * TAU) * g().rng.randf_range(320.0, 480.0)
			if not g().is_wall(np) and g().clear_walk(np, np + Vector2(1, 0), e.radius):
				e.global_position = np
				FX.burst(np, Color(0.75, 0.5, 1.0), 20, 200.0, 7.0, 0.4)
				break
		_cool("d", 9.0, 7.0)
		return Vector2.ZERO
	# keep his distance
	if dist < 260.0:
		return -to_p.normalized() * 0.8
	if dist > 520.0:
		return to_p.normalized()
	return Vector2.ZERO
