class_name Actor
extends CharacterBody2D
## Shared base for players and monsters: life/mana, stats, ailments, hit handling.

signal died(actor: Actor)

var faction := "enemy"
var stats := StatBlock.new()
var level := 1
var radius := 16.0
var life := 1.0
var max_life := 1.0
var mana := 0.0
var max_mana := 0.0
var dead := false
var invulnerable := false
var display_name := ""

# Ailments
var ignite_dps := 0.0
var ignite_time := 0.0
var chill_time := 0.0
var shock_time := 0.0
var _ignite_tick := 0.0
var _ignite_fx := 0.0

var knock := Vector2.ZERO
var hit_flash := 0.0
var facing := Vector2.RIGHT
var busy_time := 0.0   # time until the actor can act again (attack/cast animation lock)
var cooldowns := {}
var cast_stats: StatBlock      # stats used for the Rite being cast (base stats + that Rite's specialization)

# Poison / curse / root / ward
var poisons: Array = []        # [[dps, time_left], ...]
var curse_time := 0.0
var curse_taken := 0.0         # extra damage taken while cursed (fraction)
var curse_dot := 0.0           # chaos damage per second
var curse_spread := false
var curse_src: Actor = null
var root_time := 0.0
var slow_time := 0.0
var slow_amt := 0.0
var ward_pool := 0.0           # Ember Ward: absorbs damage before life
var ward_max := 0.0
var _ward_delay := 0.0
var brand_time := 0.0
var brand_hits := 0
var brand_owner: Actor = null
var _evade_acc := 0.0
# Ascension-driven states
var frozen_time := 0.0
var chill_mult := 1.0          # Winter's Grasp
var shock_mult := 1.0          # Overcharge
var empower_t := 0.0           # Shared Oath: more damage while > 0
var empower_amt := 0.0
var haste_t := 0.0             # Rallying Cry on minions
var haste_amt := 0.0
var ignite_stacks := 1
var ignite_base := 0.0
var ward_time := 0.0
var ward_reduction := 0.0
var ward_regen := 0.0
var _poison_fx := 0.0
const POISON_DURATION := 2.0
const POISON_RATIO := 0.3      # of physical + chaos hit, per second
const MAX_POISON := 40

const CHILL_SLOW := 0.3
const SHOCK_TAKEN := 1.25
const IGNITE_DPS_RATIO := 0.35
const IGNITE_DURATION := 4.0

func game() -> Game:
	return Game.instance

func is_chilled() -> bool:
	return chill_time > 0.0

func freeze(seconds: float) -> void:
	frozen_time = seconds
	busy_time = maxf(busy_time, seconds)
	FX.text(global_position, "Frozen", Color(0.6, 0.9, 1.0), 15)
	FX.burst(global_position, Color(0.7, 0.95, 1.0), 14, 140.0, 6.0, 0.4)

## Stats used to mitigate incoming hits (Player adds Stoneblood armour).
func defense_stats() -> StatBlock:
	return stats

func move_speed() -> float:
	var base := float(stats.get_stat("move_speed_base"))
	var m := stats.inc_mult(["inc_move_speed"])
	if frozen_time > 0.0:
		return 0.0
	if is_chilled():
		m *= 1.0 - minf(0.6, CHILL_SLOW * chill_mult)
	if root_time > 0.0:
		m *= 0.15
	if slow_time > 0.0:
		m *= 1.0 - slow_amt
	return base * m

func action_speed(kind: String) -> float:
	var stat := "inc_attack_speed" if kind == "attack" else "inc_cast_speed"
	var s := stats.inc_mult([stat])
	if kind != "attack":
		s *= stats.get_stat("more_cast_speed")
	if haste_t > 0.0:
		s *= 1.0 + haste_amt
	if is_chilled():
		s *= 1.0 - minf(0.6, CHILL_SLOW * chill_mult)
	return maxf(0.2, s)

func use_time(skill: Dictionary) -> float:
	return float(skill.time) / action_speed(skill.get("kind", "spell"))

func damage_taken_mult() -> float:
	var m := (1.0 + (SHOCK_TAKEN - 1.0) * shock_mult) if shock_time > 0.0 else 1.0
	if curse_time > 0.0:
		m *= 1.0 + curse_taken
	if ward_time > 0.0:
		m *= 1.0 - ward_reduction
	return m

func poison_dps() -> float:
	var t := 0.0
	for p in poisons:
		t += p[0]
	return t

func apply_curse(src: Actor, taken: float, dot: float, duration: float, spread: bool) -> void:
	curse_src = src
	curse_taken = maxf(curse_taken if curse_time > 0.0 else 0.0, taken)
	curse_dot = maxf(curse_dot if curse_time > 0.0 else 0.0, dot)
	curse_time = maxf(curse_time, duration)
	curse_spread = curse_spread or spread

## Apply a rolled hit. Returns life actually lost.
func take_hit(result: Dictionary, src: Actor, knock_dir: Vector2 = Vector2.ZERO, knock_force: float = 0.0) -> float:
	if dead or invulnerable:
		return 0.0
	var source: Actor = src if is_instance_valid(src) else null
	# Block (shields/stances) and evasion (entropy-based so it can't streak)
	var block := minf(stats.get_stat("block_chance"), 60.0 + stats.get_stat("block_cap_add"))
	if block > 0.0 and game().rng.randf() * 100.0 < block:
		FX.text(global_position, "Block", Color(0.8, 0.85, 1.0), 16)
		if stats.get_stat("block_heal") > 0.0:
			heal(max_life * stats.get_stat("block_heal") / 100.0)
		FX.sound("hit", global_position, -14.0, 0.3)
		if has_method("on_blocked"):
			call("on_blocked")
		return 0.0
	var evade := minf(stats.get_stat("evade_chance"), 75.0)
	if evade > 0.0:
		_evade_acc += evade
		if _evade_acc >= 100.0:
			_evade_acc -= 100.0
			FX.text(global_position, "Evade", Color(0.7, 1.0, 0.85), 16)
			return 0.0
	var pen := {}
	var po := Asc.owner_player(source)
	if po and faction != "player":
		for pt in ["fire", "cold", "lightning", "chaos"]:
			var pv := po.stats.get_stat(pt + "_pen")
			if pv > 0.0:
				pen[pt] = pv
	# Unbroken Vow: crits land as normal hits
	if result.get("crit", false) and stats.get_stat("crit_immune") > 0.0:
		var cm := (150.0 + (source.stats.get_stat("crit_multi") if source else 0.0)) / 100.0
		result = result.duplicate(true)
		for k in result.damage:
			result.damage[k] /= cm
		result.crit = false
	var dmg := Damage.mitigate(result.damage, defense_stats(), damage_taken_mult() * Asc.taken_mult(self) * Asc.dealt_mult(self, source, result), pen)
	var amount := Damage.total(dmg)
	if amount <= 0.0:
		return 0.0
	if po and faction != "player" and po.stats.get_stat("hit_less") > 0.0:
		amount *= 1.0 - po.stats.get_stat("hit_less") / 100.0
	if ward_pool > 0.0:
		var absorbed := minf(ward_pool, amount)
		ward_pool -= absorbed
		amount -= absorbed
		FX.burst(global_position, Color(0.5, 0.75, 1.0), 4, 120.0, 5.0)
	_ward_delay = 1.0 if stats.get_stat("ward_from_life") > 0.0 else 3.0
	if source and source.has_method("on_dealt_hit"):
		source.on_dealt_hit(self, amount)
	# Judgment Brand: the brander's third hit detonates it
	if brand_time > 0.0 and source != null and source == brand_owner:
		brand_hits += 1
		if brand_hits >= 3:
			brand_time = 0.0
			brand_hits = 0
			var bs := {"kind": "attack", "base_damage": {"fire": [12, 20]}, "effectiveness": 150.0, "crit": 5.0, "tags": ["area"], "ignite_chance": 40.0}
			for t in game().targets_in_circle(source.faction, global_position, 150.0):
				t.take_hit(Damage.roll_hit(bs, source.stats, game().rng), source, t.global_position - global_position, 220.0)
			FX.ring(global_position, 150.0, Color(1.0, 0.75, 0.3), 0.35, 10.0)
			FX.flash(global_position, Color(1.0, 0.7, 0.3), 120.0, 0.25)
			if source.stats.get_stat("brand_ground") > 0.0:
				var gfx := GroundEffect.new()
				source.cast_stats = source.stats
				gfx.setup(Asc.BURN_GROUND, source, global_position)
				game().fx_node.add_child(gfx)
			FX.sound("boom", global_position, -6.0)
	if amount <= 0.0:
		return 0.0
	life -= amount
	hit_flash = 0.08
	knock += knock_dir.normalized() * knock_force
	# Ailments
	var rng := game().rng
	var ail: Dictionary = result.get("ailments", {})
	var os: StatBlock = po.stats if po and faction != "player" else null
	if dmg.get("fire", 0.0) > 0.0 and rng.randf() * 100.0 < ail.get("ignite", 0.0) and stats.get_stat("ignite_immune") <= 0.0:
		var dps: float = dmg.fire * IGNITE_DPS_RATIO * (1.0 + (source.stats.get_stat("inc_ignite_damage") if source else 0.0) / 100.0)
		if os and os.get_stat("holy_brand") > 0.0 and brand_time > 0.0:
			dps *= 1.0 + os.get_stat("holy_brand") / 100.0
		var max_stacks := int(os.get_stat("ignite_stacks")) if os else 0
		if max_stacks > 1 and ignite_time > 0.0:
			# Everburn: each stack burns at the strongest single ignite seen
			ignite_stacks = mini(ignite_stacks + 1, max_stacks)
			ignite_base = maxf(ignite_base, dps)
			ignite_dps = ignite_base * ignite_stacks
		elif dps >= ignite_dps or ignite_time < 1.0:
			ignite_dps = dps
			ignite_base = dps
			ignite_stacks = 1
		ignite_time = IGNITE_DURATION * (1.0 + (os.get_stat("inc_ignite_duration") / 100.0 if os else 0.0))
	if dmg.get("cold", 0.0) > 0.0 and rng.randf() * 100.0 < ail.get("chill", 0.0):
		chill_time = 2.0
		chill_mult = 1.0 + (os.get_stat("inc_chill_effect") / 100.0 if os else 0.0)
	if dmg.get("lightning", 0.0) > 0.0 and rng.randf() * 100.0 < ail.get("shock", 0.0):
		shock_time = 4.0
		shock_mult = 2.0 if os and os.get_stat("overcharge") > 0.0 and result.get("crit", false) else maxf(1.0, shock_mult)
		if os and os.get_stat("inc_shock_effect") > 0.0:
			shock_mult = maxf(shock_mult, 1.0 + os.get_stat("inc_shock_effect") / 100.0)
	var pc: float = dmg.get("physical", 0.0) + dmg.get("chaos", 0.0)
	if pc > 0.0 and rng.randf() * 100.0 < ail.get("poison", 0.0):
		var inc := 1.0 + (source.stats.get_stat("inc_poison_damage") if source else 0.0) / 100.0
		var resist := 1.0 - minf(stats.get_stat("res_chaos"), Damage.RES_CAP) / 100.0
		var cap := 200 if os and os.get_stat("virulence") > 0.0 else MAX_POISON
		while poisons.size() >= cap:
			poisons.pop_front()
		poisons.append([pc * POISON_RATIO * inc * resist, POISON_DURATION])
	# Leech / life on hit for the attacker
	if source and not source.dead:
		var gain := source.stats.get_stat("life_on_hit") + amount * source.stats.get_stat("life_leech") / 100.0
		if gain > 0.0:
			source.heal(gain)
	Asc.after_hit(self, source, result, dmg, amount)
	_on_hit_fx(dmg, amount, result.get("crit", false))
	if faction == "player":
		FX.sound("hurt", null, -4.0)
		FX.rumble(0.25, 0.35 if amount > max_life * 0.15 else 0.1, 0.12)
	else:
		FX.sound("crit" if result.get("crit", false) else "hit", global_position, -2.0 if result.get("crit", false) else -7.0)
	if life <= 0.0:
		life = 0.0
		die(source)
	return amount

func take_dot(amount: float) -> void:
	if dead or invulnerable:
		return
	life -= amount
	if life <= 0.0:
		life = 0.0
		die(null)

func heal(amount: float) -> void:
	if dead:
		return
	life = minf(max_life, life + amount)

func _on_hit_fx(dmg: Dictionary, amount: float, crit: bool) -> void:
	var c: Color = Damage.COLORS[Damage.dominant(dmg)]
	if faction == "player":
		c = Color(1.0, 0.3, 0.3)
	FX.number(global_position, amount, c, crit)
	FX.burst(global_position, c, 6 if not crit else 14, 180.0 if not crit else 320.0, 5.0)

func die(_killer: Actor) -> void:
	if dead:
		return
	dead = true
	if faction != "player":
		Asc.on_enemy_died(self, _killer)
	if curse_spread and curse_time > 0.0 and game():
		for t in game().targets_in_circle("player" if faction != "player" else "enemy", global_position, 200.0):
			if t != self and t.curse_time <= 0.0:
				t.apply_curse(curse_src, curse_taken, curse_dot, 4.0, true)
				FX.ring(t.global_position, 40.0, Color(0.7, 0.4, 0.95), 0.4)
	died.emit(self)

func tick_common(delta: float) -> void:
	busy_time = maxf(0.0, busy_time - delta)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, cooldowns[k] - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	chill_time = maxf(0.0, chill_time - delta)
	shock_time = maxf(0.0, shock_time - delta)
	frozen_time = maxf(0.0, frozen_time - delta)
	empower_t = maxf(0.0, empower_t - delta)
	haste_t = maxf(0.0, haste_t - delta)
	if shock_time <= 0.0:
		shock_mult = 1.0
	if ignite_time > 0.0:
		ignite_time -= delta
		take_dot(ignite_dps * delta)
		_ignite_tick += delta
		_ignite_fx -= delta
		if _ignite_fx <= 0.0:
			_ignite_fx = 0.12
			FX.burst(global_position + Vector2(randf_range(-radius, radius), randf_range(-radius, 0)), Color(1, 0.45, 0.1), 2, 60.0, 5.0, 0.5)
		if _ignite_tick >= 0.5:
			_ignite_tick = 0.0
			if faction != "player":
				FX.number(global_position, ignite_dps * 0.5, Color(1.0, 0.55, 0.2).darkened(0.1), false)
		if ignite_time <= 0.0:
			ignite_dps = 0.0
			ignite_stacks = 1
			ignite_base = 0.0
	# regen
	var regen := stats.get_stat("life_regen") + max_life * stats.get_stat("life_regen_pct") / 100.0
	if regen > 0.0 and not dead and stats.get_stat("no_regen") <= 0.0:
		heal(regen * delta)
	knock = knock.move_toward(Vector2.ZERO, 2200.0 * delta)
	root_time = maxf(0.0, root_time - delta)
	slow_time = maxf(0.0, slow_time - delta)
	brand_time = maxf(0.0, brand_time - delta)
	if ward_max > 0.0:
		_ward_delay -= delta
		if _ward_delay <= 0.0 and ward_pool < ward_max:
			ward_pool = minf(ward_max, ward_pool + ward_max * (0.6 if stats.get_stat("ward_from_life") > 0.0 else 0.25) * delta)
	if ward_time > 0.0:
		ward_time -= delta
		heal(max_life * ward_regen / 100.0 * delta)
	if not poisons.is_empty():
		var dps := 0.0
		for i in range(poisons.size() - 1, -1, -1):
			dps += poisons[i][0]
			poisons[i][1] -= delta
			if poisons[i][1] <= 0.0:
				poisons.remove_at(i)
		take_dot(dps * delta)
		_poison_fx -= delta
		if _poison_fx <= 0.0:
			_poison_fx = 0.5
			FX.burst(global_position + Vector2(0, -radius), Color(0.5, 0.95, 0.3), 3, 50.0, 5.0, 0.5)
			if faction != "player":
				FX.number(global_position, dps * 0.5, Color(0.55, 0.95, 0.35), false)
	if curse_time > 0.0:
		curse_time -= delta
		take_dot(curse_dot * max_life * delta * 0.25 + curse_dot * 20.0 * delta)

## Tint for status, used by subclasses when drawing.
func status_tint(base: Color) -> Color:
	var c := base
	if is_chilled():
		c = c.lerp(Color(0.55, 0.85, 1.0), 0.45)
	if frozen_time > 0.0:
		c = c.lerp(Color(0.8, 0.95, 1.0), 0.7)
	if shock_time > 0.0:
		c = c.lerp(Color(1.0, 0.95, 0.5), 0.25)
	if not poisons.is_empty():
		c = c.lerp(Color(0.5, 0.95, 0.35), 0.3)
	if hit_flash > 0.0:
		c = c.lerp(Color.WHITE, clampf(0.55 * 16.0 / radius, 0.15, 0.6))
	return c

func can_use(skill_id: String) -> bool:
	var s: Dictionary = SkillsDB.SKILLS[skill_id]
	return busy_time <= 0.0 and cooldowns.get(skill_id, 0.0) <= 0.0 and mana >= float(s.get("cost", 0))
