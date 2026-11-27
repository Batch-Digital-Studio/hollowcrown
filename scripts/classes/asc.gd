class_name Asc
extends RefCounted
## Ascension behaviours. Notables in AscensionsDB set flag stats; the hooks here read them.
## Simulation only (FX calls are presentation and safe to skip in a headless host).
## One instance per Player holds its timers; static helpers serve Actor / skill code.

var last_stand_cd := 0.0
var last_stand_t := 0.0
var nova_cd := 0.0
var still_t := 0.0
var static_t := 0.0
var solar_t := 0.0
var upkeep_t := 0.0

const BURN_GROUND := {"name": "Pyre", "kind": "spell", "behavior": "ground", "base_damage": {"fire": [6, 10]}, "crit": 3.0,
	"radius": 120.0, "duration": 3.0, "tick": 0.4, "ignite_chance": 25.0, "tags": ["area"], "color": Color(1.0, 0.5, 0.2)}

## The player whose ascension applies to this actor's actions (itself, or the owner of a minion/totem).
static func owner_player(a) -> Player:
	if a == null or not is_instance_valid(a):
		return null
	if a is Player:
		return a
	var o = a.get("owner_actor")
	if o != null and is_instance_valid(o) and o is Player:
		return o
	return null

static func ostat(a, stat: String) -> float:
	var p := owner_player(a)
	return p.stats.get_stat(stat) if p else 0.0

# ---------------------------------------------------------------- per-frame (player)

func tick(p: Player, delta: float) -> void:
	last_stand_cd -= delta
	last_stand_t -= delta
	nova_cd -= delta
	still_t = still_t + delta if p.velocity.length() < 25.0 else 0.0
	var s := p.stats
	var g := p.game()
	if g == null:
		return
	if s.get_stat("static_field") > 0.0:
		static_t -= delta
		if static_t <= 0.0:
			static_t = 0.5
			var best: Actor = null
			var bd := 320.0
			for e in g.targets_in_circle("player", p.global_position, 320.0):
				var d: float = e.global_position.distance_to(p.global_position)
				if d < bd:
					bd = d
					best = e
			if best:
				var sk := {"kind": "spell", "base_damage": {"lightning": [2.0 + p.level, 6.0 + p.level * 2.0]}, "crit": 6.0, "tags": [], "shock_chance": 20.0}
				best.take_hit(Damage.roll_hit(sk, p.stats, g.rng), p)
				var lf := LightningFX.new()
				lf.points = [p.global_position + Vector2(0, -30), best.global_position]
				lf.color = Color(1.0, 0.95, 0.5)
				g.fx_node.add_child(lf)
	if s.get_stat("solar_oath") > 0.0 and p.has_buff("oathbreaker"):
		solar_t -= delta
		if solar_t <= 0.0:
			solar_t = 0.5
			for e in g.targets_in_circle("player", p.global_position, 230.0):
				e.ignite_dps = maxf(e.ignite_dps, 6.0 + p.level * 3.0)
				e.ignite_time = maxf(e.ignite_time, 2.0)
			FX.ring(p.global_position, 230.0, Color(1.0, 0.6, 0.2), 0.3, 4.0)
	upkeep_t -= delta
	if upkeep_t <= 0.0:
		upkeep_t = 1.0
		_upkeep(p, g, "squire", int(s.get_stat("squires")))
		_upkeep(p, g, "beast", int(s.get_stat("bog_beast")))

static func _upkeep(p: Player, g: Game, kind: String, want: int) -> void:
	if want <= 0 or p.dead:
		return
	var have := 0
	for a in g.allies:
		if a is Minion and a.kind == kind and a.owner_actor == p:
			have += 1
	for i in want - have:
		var m := Minion.new()
		m.kind = kind
		m.setup(p, p.level, p.global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * 80.0)
		g.world_layer.add_child(m)
		g.allies.append(m)

## Extra damage for Rites cast now (Steady Aim, Eye of the Storm, Pillar of the Crown, Wildfire Heart).
func cast_extra(p: Player, skill_id: String) -> Dictionary:
	var s := p.stats
	var out := {}
	if s.get_stat("steady_aim") > 0.0 and still_t >= 1.0:
		out["more_damage"] = s.get_stat("steady_aim")
	var g := p.game()
	if s.get_stat("eye_storm") > 0.0 and g and g.targets_in_circle("player", p.global_position, 280.0).size() >= 3:
		out["crit_flat"] = s.get_stat("eye_storm")
	if s.get_stat("pillar") > 0.0 and g:
		var n := 0
		for a in g.allies:
			if a is Totem and a.owner_actor == p and a.global_position.distance_to(p.global_position) < 450.0:
				n += 1
		if n >= 2:
			out["more_damage"] = float(out.get("more_damage", 0.0)) + s.get_stat("pillar")
	if s.get_stat("fleetfoot") > 0.0:
		var ms := (s.inc_mult(["inc_move_speed"]) - 1.0) * 100.0
		if ms > 0.0:
			out["more_damage"] = float(out.get("more_damage", 0.0)) + ms
	if s.get_stat("wildfire_heart") > 0.0 and skill_id == "ember_bolt" and p.resources().has("kindling") and float(p.res.kindling) >= p.res_max("kindling"):
		out["ignite_chance"] = 1000.0
	return out

# ---------------------------------------------------------------- damage taken / dealt

## Defensive multiplier for a player-side actor.
static func taken_mult(a: Actor) -> float:
	var g := Game.instance
	if g == null or g.player == null or a.faction != "player":
		return 1.0
	var p := g.player
	var m := 1.0
	var sw := p.stats.get_stat("shieldwall")
	if sw > 0.0 and a.global_position.distance_to(p.global_position) <= 360.0:
		m *= 1.0 - sw / 100.0
	if a == p:
		var bone := p.stats.get_stat("bone_armour")
		if bone > 0.0:
			var n := 0
			for x in g.allies:
				if x is Minion and x.owner_actor == p:
					n += 1
			m *= 1.0 - minf(20.0, n * bone) / 100.0
		if p.asc.last_stand_t > 0.0:
			m *= 0.6
		var tw := p.stats.get_stat("totem_ward")
		if tw > 0.0:
			for x in g.allies:
				if x is Totem and x.owner_actor == p and x.global_position.distance_to(p.global_position) < 320.0:
					m *= 1.0 - tw / 100.0
					break
	return m

## Offensive multiplier for hits from the player's side onto an enemy.
static func dealt_mult(target: Actor, source, result: Dictionary) -> float:
	var p := owner_player(source)
	if p == null or target.faction == "player":
		return 1.0
	var s := p.stats
	var m := 1.0
	if target.frozen_time > 0.0:
		m *= 1.0 + s.get_stat("frozen_taken") / 100.0
	if s.get_stat("withering") > 0.0:
		m *= 1.0 + minf(20.0, target.poisons.size()) / 100.0
	if result.get("trap", false) and s.get_stat("rigged") > 0.0 and target is Enemy and (target.rarity == "rare" or target.rarity == "boss"):
		m *= 1.0 + s.get_stat("rigged") / 100.0
	if s.get_stat("mark_crit") > 0.0 and target.curse_time > 0.0 and not result.get("crit", false):
		if Game.instance.rng.randf() * 100.0 < s.get_stat("mark_crit"):
			result["crit"] = true
			m *= (150.0 + s.get_stat("crit_multi")) / 100.0
	if is_instance_valid(source) and source.get("empower_t") != null and source.empower_t > 0.0:
		m *= 1.0 + source.empower_amt
	return m

## Side effects after a hit has landed (amount > 0).
static func after_hit(target: Actor, source, result: Dictionary, dmg: Dictionary, amount: float) -> void:
	var g := Game.instance
	if g == null:
		return
	# --- the player was hit
	if target is Player:
		var p: Player = target
		if p.stats.get_stat("last_stand") > 0.0 and p.life < p.max_life * 0.3 and p.asc.last_stand_cd <= 0.0 and p.life > 0.0:
			p.asc.last_stand_t = 4.0
			p.asc.last_stand_cd = 30.0
			FX.text(p.global_position, "LAST STAND", Color(0.8, 0.85, 1.0), 24)
			FX.ring(p.global_position, 90.0, Color(0.8, 0.85, 1.0), 0.4, 8.0)
		if source is Actor and is_instance_valid(source) and source.faction != "player":
			if p.stats.get_stat("chill_attackers") > 0.0:
				source.chill_time = maxf(source.chill_time, 2.0)
			if p.stats.get_stat("poison_attackers") > 0.0 and source.poisons.size() < Actor.MAX_POISON:
				source.poisons.append([amount * 0.6 + p.level, Actor.POISON_DURATION])
		return
	# --- the player's side hit an enemy
	var o := owner_player(source)
	if o == null or target.faction == "player":
		return
	var s := o.stats
	if s.get_stat("freeze_below") > 0.0 and target.is_chilled() and target.life > 0.0 and target.life < target.max_life * s.get_stat("freeze_below") / 100.0 and target.frozen_time <= 0.0:
		target.freeze(1.5)
	if s.get_stat("overcharge") > 0.0 and result.get("crit", false) and target.shock_time > 0.0:
		target.shock_mult = 2.0
	if s.get_stat("poison_slow") > 0.0 and not target.poisons.is_empty():
		target.slow_time = maxf(target.slow_time, 0.6)
		target.slow_amt = maxf(target.slow_amt if target.slow_time > 0.0 else 0.0, s.get_stat("poison_slow") / 100.0)
	if s.get_stat("conduit") > 0.0 and target.shock_time > 0.0 and not result.get("arc", false):
		var best: Actor = null
		var bd := 260.0
		for e in g.targets_in_circle("player", target.global_position, 260.0):
			if e != target:
				var d: float = e.global_position.distance_to(target.global_position)
				if d < bd:
					bd = d
					best = e
		if best:
			var arc := {"damage": {"lightning": amount * s.get_stat("conduit") / 100.0}, "crit": false, "ailments": {}, "arc": true}
			best.take_hit(arc, o)
			var lf := LightningFX.new()
			lf.points = [target.global_position, best.global_position]
			lf.color = Color(1.0, 0.95, 0.5)
			g.fx_node.add_child(lf)
	if source is Minion and source.kind != "husk" and s.get_stat("companion_heal") > 0.0:
		o.heal(o.max_life * s.get_stat("companion_heal") / 100.0)

# ---------------------------------------------------------------- deaths

static func on_enemy_died(e: Actor, killer) -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	var p := g.player
	var s := p.stats
	var burning := e.ignite_time > 0.0
	if burning and (s.get_stat("ignite_spread") > 0.0 or s.get_stat("wildfire") > 0.0):
		var n := 0
		var lim := 999 if s.get_stat("wildfire") > 0.0 else int(s.get_stat("ignite_spread"))
		for t in g.targets_in_circle("player", e.global_position, 300.0):
			if t != e and n < lim:
				t.ignite_dps = maxf(t.ignite_dps, e.ignite_dps)
				t.ignite_time = maxf(t.ignite_time, Actor.IGNITE_DURATION)
				FX.burst(t.global_position, Color(1.0, 0.5, 0.2), 8, 120.0, 6.0, 0.4)
				n += 1
	if burning and s.get_stat("burn_ground_death") > 0.0:
		var gfx := GroundEffect.new()
		p.cast_stats = p.stats
		gfx.setup(BURN_GROUND, p, e.global_position)
		g.fx_node.add_child(gfx)
	if burning and s.get_stat("resolve_on_ignite_kill") > 0.0:
		p.gain_res("resolve", s.get_stat("resolve_on_ignite_kill"))
	if burning and s.get_stat("combustion") > 0.0:
		var amt := e.max_life * s.get_stat("combustion") / 100.0
		for t in g.targets_in_circle("player", e.global_position, 170.0):
			if t != e:
				t.take_hit({"damage": {"fire": amt}, "crit": false, "ailments": {"ignite": 20.0}}, p, t.global_position - e.global_position, 160.0)
		FX.ring(e.global_position, 170.0, Color(1.0, 0.5, 0.2), 0.3, 8.0)
		FX.flash(e.global_position, Color(1.0, 0.55, 0.25), 120.0, 0.2)
	if e.frozen_time > 0.0 and s.get_stat("shatter") > 0.0:
		var amt2 := e.max_life * 0.12 + p.level * 3.0
		for t in g.targets_in_circle("player", e.global_position, 190.0):
			if t != e:
				t.take_hit({"damage": {"cold": amt2}, "crit": false, "ailments": {"chill": 100.0}}, p, t.global_position - e.global_position, 160.0)
		FX.burst(e.global_position, Color(0.6, 0.9, 1.0), 36, 380.0, 7.0, 0.5)
		FX.ring(e.global_position, 190.0, Color(0.6, 0.9, 1.0), 0.3, 6.0)
	if killer != null and is_instance_valid(killer) and killer != p and owner_player(killer) == p:
		if s.get_stat("resolve_on_ally_kill") > 0.0:
			p.gain_res("resolve", s.get_stat("resolve_on_ally_kill"))
		if killer is Totem and s.get_stat("totem_spirit") > 0.0:
			p.gain_res("spirit", s.get_stat("totem_spirit"))

## Undying Will: a husk revives once, 4 s after dying.
static func on_minion_died(m: Minion) -> void:
	var p := owner_player(m)
	if p == null or m.kind != "husk" or m.temporary > 0.0 or m.has_meta("revived") or p.stats.get_stat("minion_revive") <= 0.0:
		return
	var pos := m.global_position
	var g := Game.instance
	g.get_tree().create_timer(4.0, false).timeout.connect(func():
		if is_instance_valid(p) and not p.dead and Game.instance == g:
			var nm := SkillExec.spawn_minion(g, p, pos)
			nm.set_meta("revived", true)
			FX.text(pos, "Undying", Color(0.6, 1.0, 0.5), 16))
