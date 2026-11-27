class_name Damage
extends RefCounted
## Hit calculation. Pure logic, no nodes, so it can run on a co-op host and in tests.

const TYPES := ["physical", "lightning", "cold", "fire", "chaos"]  # conversion order
const ELEMENTAL := ["lightning", "cold", "fire"]
const RES_CAP := 75.0

## skill: Dictionary from SkillsDB (base_damage, kind, tags, crit, effectiveness, conversion...)
## stats: attacker's final StatBlock (includes skill-level and support mods merged in)
## Returns { "damage": {type: amount}, "crit": bool, "ailments": {ignite/chill/shock: chance%} }
static func roll_hit(skill: Dictionary, stats: StatBlock, rng: RandomNumberGenerator) -> Dictionary:
	var kind: String = skill.get("kind", "spell")  # "spell" or "attack"
	var tags: Array = skill.get("tags", [])
	var eff: float = float(skill.get("effectiveness", 100.0)) / 100.0

	# 1. Base damage per type.
	var base := {}
	for t in TYPES:
		base[t] = 0.0
	var bd: Dictionary = skill.get("base_damage", {})
	for t in bd:
		base[t] += rng.randf_range(bd[t][0], bd[t][1])
	if kind == "attack":
		# Weapon damage (local) is the main source for attacks.
		for t in TYPES:
			var lo := stats.get_stat("weapon_%s_min" % t)
			var hi := stats.get_stat("weapon_%s_max" % t)
			if hi > 0.0:
				base[t] += rng.randf_range(lo, maxf(lo, hi))
	# Global added damage, scaled by skill effectiveness.
	for t in TYPES:
		var lo := stats.get_stat("added_%s_min" % t)
		var hi := stats.get_stat("added_%s_max" % t)
		if hi > 0.0:
			base[t] += rng.randf_range(lo, maxf(lo, hi)) * eff

	# 2. Conversion. Chunks remember every type they have been, for "increased" scaling.
	var chunks: Array = []  # [{amount, type, history:Array}]
	for t in TYPES:
		if base[t] > 0.0:
			chunks.append({"amount": base[t], "type": t, "history": [t]})
	var skill_conv: Dictionary = skill.get("conversion", {})
	for i in TYPES.size():
		var from: String = TYPES[i]
		var conv := {}
		var total := 0.0
		for j in range(i + 1, TYPES.size()):
			var to: String = TYPES[j]
			var key := "%s_to_%s" % [from, to]
			var pct := stats.get_stat("conv_" + key) + float(skill_conv.get(key, 0.0))
			if pct > 0.0:
				conv[to] = pct
				total += pct
		if total <= 0.0:
			continue
		var scale := 1.0 if total <= 100.0 else 100.0 / total
		var next_chunks: Array = []
		for c in chunks:
			if c.type != from:
				next_chunks.append(c)
				continue
			var remaining: float = c.amount
			for to in conv:
				var part: float = c.amount * conv[to] * scale / 100.0
				remaining -= part
				var hist: Array = c.history.duplicate()
				if not hist.has(to):
					hist.append(to)
				next_chunks.append({"amount": part, "type": to, "history": hist})
			if remaining > 0.0001:
				next_chunks.append({"amount": remaining, "type": from, "history": c.history})
		chunks = next_chunks

	# 3. Increased / more.
	var generic_inc := ["inc_damage", "inc_%s_damage" % kind]
	for tg in tags:
		generic_inc.append("inc_%s_damage" % tg)
	var generic_more := ["more_damage", "more_%s_damage" % kind]
	for tg in tags:
		generic_more.append("more_%s_damage" % tg)
	var out := {}
	for t in TYPES:
		out[t] = 0.0
	for c in chunks:
		var incs: Array = generic_inc.duplicate()
		var mores: Array = generic_more.duplicate()
		var any_elem := false
		for h in c.history:
			incs.append("inc_%s_damage" % h)
			mores.append("more_%s_damage" % h)
			if ELEMENTAL.has(h):
				any_elem = true
		if any_elem:
			incs.append("inc_elemental_damage")
			mores.append("more_elemental_damage")
		out[c.type] += c.amount * stats.inc_mult(incs) * stats.more_mult(mores)

	# 4. Crit.
	var crit_chance: float = float(skill.get("crit", 5.0)) * stats.inc_mult(["inc_crit_chance"]) + stats.get_stat("crit_flat")
	crit_chance = clampf(crit_chance, 0.0, 100.0)
	var crit := rng.randf() * 100.0 < crit_chance
	if crit:
		var multi := (150.0 + stats.get_stat("crit_multi")) / 100.0
		for t in out:
			out[t] *= multi

	# 5. Ailment chances (crits always apply elemental ailments of the types dealt).
	var ail := {
		"ignite": stats.get_stat("ignite_chance") + float(skill.get("ignite_chance", 0.0)),
		"chill": stats.get_stat("chill_chance") + float(skill.get("chill_chance", 0.0)),
		"shock": stats.get_stat("shock_chance") + float(skill.get("shock_chance", 0.0)),
		"poison": stats.get_stat("poison_chance") + float(skill.get("poison_chance", 0.0)),
	}
	if crit:
		for a in ["ignite", "chill", "shock"]:
			ail[a] = 100.0
	return {"damage": out, "crit": crit, "ailments": ail, "trap": skill.get("trap", false)}

## Defender-side mitigation. Returns {type: amount} after armour/resists/shock.
static func mitigate(dmg: Dictionary, defender: StatBlock, damage_taken_mult: float = 1.0, pen: Dictionary = {}) -> Dictionary:
	var out := {}
	for t in dmg:
		var amt: float = dmg[t]
		if amt <= 0.0:
			continue
		if t == "physical":
			var armour := defender.get_stat("armour") * defender.inc_mult(["inc_armour"])
			if armour > 0.0:
				amt *= 1.0 - armour / (armour + 5.0 * amt)  # big hits pierce armour
		else:
			var res := minf(defender.get_stat("res_" + t), RES_CAP) - float(pen.get(t, 0.0))
			amt *= 1.0 - res / 100.0
		out[t] = amt * damage_taken_mult
	return out

static func total(dmg: Dictionary) -> float:
	var s := 0.0
	for t in dmg:
		s += dmg[t]
	return s

## Which type dealt the most (used for hit colour).
static func dominant(dmg: Dictionary) -> String:
	var best := "physical"
	var best_v := -1.0
	for t in dmg:
		if dmg[t] > best_v:
			best_v = dmg[t]
			best = t
	return best

const COLORS := {
	"physical": Color(0.92, 0.88, 0.82),
	"fire": Color(1.0, 0.45, 0.12),
	"cold": Color(0.45, 0.8, 1.0),
	"lightning": Color(1.0, 0.92, 0.3),
	"chaos": Color(0.75, 0.3, 1.0),
}
