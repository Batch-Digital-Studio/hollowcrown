class_name Player
extends Actor

signal leveled_up(level: int)
signal inventory_changed

const INV_SIZE := 40
const DODGE_TIME := 0.22
const DODGE_DIST := 250.0
const DODGE_CD := 0.85

var input := PlayerInput.new()
var bar: Array = SkillsDB.PLAYER_BAR.duplicate()

# ---- class system ----
var class_id := "classic"
var class2_id := ""              # second class (dual-class, level 10)
var class_nodes := {}            # "class_id/branch:index" -> true
var rite_specs := {}             # "skill_id/spec_id" -> ranks
var ascendancy := ""             # AscensionsDB key, chosen at the first Ascension Trial
var asc_nodes: Array = []        # indices of taken notables
var asc_trials := 0              # Ascension Trials completed (each grants 2 points)
var asc := Asc.new()             # runtime state for ascension behaviours (cooldowns, timers)

func asc_points_total() -> int:
	return asc_trials * AscensionsDB.POINTS_PER_TRIAL

func asc_points() -> int:
	return asc_points_total() - asc_nodes.size()

func asc_nodes_list() -> Array:
	if ascendancy == "" or not AscensionsDB.ASC.has(ascendancy):
		return []
	var out: Array = []
	var nodes: Array = AscensionsDB.ASC[ascendancy].nodes
	for i in asc_nodes:
		if int(i) < nodes.size():
			out.append(nodes[int(i)])
	return out

func choose_ascendancy(id: String) -> bool:
	if ascendancy != "" or asc_trials <= 0 or not AscensionsDB.ASC.has(id) or AscensionsDB.ASC[id]["class"] != class_id:
		return false
	ascendancy = id
	FX.text(global_position, "ASCENDED: " + String(AscensionsDB.ASC[id].name).to_upper(), AscensionsDB.ASC[id].color, 28)
	return true

func take_asc(i: int) -> bool:
	if ascendancy == "" or asc_points() <= 0 or asc_nodes.has(i):
		return false
	asc_nodes.append(i)
	recalc_stats()
	return true

func refund_asc(i: int) -> bool:
	if not asc_nodes.has(i) or not can_respec():
		return false
	asc_nodes.erase(i)
	recalc_stats()
	return true
var res := {"spirit": 0.0, "kindling": 0.0, "resolve": 0.0, "focus": 0.0}
var spirit: float:
	get: return res.spirit
	set(v): res.spirit = v
var buffs: Array = []          # [{id, stats, time}]
var currency := {}             # id -> count

func add_currency(id: String, n: int) -> void:
	currency[id] = int(currency.get(id, 0)) + n
	if id == "rift_splinter" and currency.rift_splinter >= 100:
		currency.rift_splinter -= 100
		currency["rift_heart"] = int(currency.get("rift_heart", 0)) + 1
		FX.text(global_position, "RIFT HEART FORMED", Color(0.85, 0.55, 1.0), 26)
		FX.sound("drop_unique", null, -4.0, 0.0)
		if game() and game().hud:
			game().hud.show_message("A RIFT HEART FORMS", "Open it from the inventory to face the Rift Lord.")
	elif id != "ember_shards":
		FX.text(global_position, "+%d %s" % [n, CurrencyDB.info(id).name], CurrencyDB.info(id).color, 15)
var _combat_t := 0.0
var _oath_fx := 0.0
var _dash_cb := Callable()
var _dash_speed := 0.0

## Skill dashes (Shield Rush, Vault Shot) reuse the dodge movement.
func start_dash(dir: Vector2, dist: float, duration: float, on_end: Callable) -> void:
	_dodge_dir = dir.normalized()
	_dodge_t = duration
	_dash_speed = dist / duration
	_dash_cb = on_end
	invulnerable = true
var _special_buffer := 0.0
var _spec_cache := {}
const DUAL_CLASS_LEVEL := 10
const FREE_RESPEC_LEVEL := 20
var equipment := {}
var passives := {"start": true}
var masteries := {}            # mastery node id -> chosen option index
var inventory: Array = []
var xp := 0
var flask_charges := 3.0
var flask_max := 3
var _dodge_t := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector2.ZERO
var _flask_heal := 0.0
var _anim := 0.0
var _light: PointLight2D

func _init() -> void:
	faction = "player"
	radius = 15.0
	display_name = "Kindled"
	inventory.resize(INV_SIZE)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	add_child(shape)
	_build_visuals()
	if equipment.is_empty():
		equipment["weapon"] = Loot.starter_weapon(ClassesDB.class_def(class_id).get("starter_weapon", "rusted_blade"))
	recalc_stats(true)

func build_stats(eq: Dictionary) -> StatBlock:
	var s := StatBlock.new()
	s.add("life_flat", 92 + 12 * level)
	s.add("mana_flat", 48 + 6 * level)
	s.add("move_speed_base", 300.0)
	s.add("mana_regen", 7.0 + 0.4 * level)
	s.add("inc_damage", 2.0 * (level - 1))  # small growth per level
	for slot in eq:
		var it: Item = eq[slot]
		if it:
			s.add_mod_list(it.to_mods())
	var tree := PassivesDB.nodes()
	for id in passives:
		if tree.has(id):
			s.add_mods(tree[id].stats)
			if tree[id].type == "mastery":
				var opts: Array = tree[id].options
				s.add_mods(opts[clampi(int(masteries.get(id, 0)), 0, opts.size() - 1)][1])
	for c in classes():
		s.add_mods(ClassesDB.class_def(c).get("base", {}))
	for b in buffs:
		s.add_mods(b.stats)
	for key in class_nodes:
		var parts: PackedStringArray = key.split("/")
		var n := ClassesDB.node(parts[0], parts[1])
		if not n.is_empty():
			s.add_mods(n.stats)
	for n in asc_nodes_list():
		s.add_mods(n.get("stats", {}))
	return s

# ---------- classes ----------

func classes() -> Array:
	return [class_id] if class2_id == "" else [class_id, class2_id]

func max_spirit() -> float:
	return res_max("spirit")

## Resources this character uses (from its classes).
func resources() -> Array:
	var out: Array = []
	for c in classes():
		var r: String = ClassesDB.class_def(c).get("resource", "")
		if r != "" and not out.has(r):
			out.append(r)
	return out

func res_max(r: String) -> float:
	if not resources().has(r):
		return 0.0
	if r == "kindling":
		return 5.0 + stats.get_stat("kindling_max_add")
	return 100.0

func gain_res(r: String, amount: float) -> void:
	if resources().has(r):
		res[r] = clampf(float(res[r]) + amount, 0.0, res_max(r))

func can_pay(cost: Dictionary) -> bool:
	for r in cost:
		if float(res.get(r, 0.0)) < float(cost[r]) - 0.001:
			return false
	return true

func pay(cost: Dictionary) -> void:
	for r in cost:
		res[r] = maxf(0.0, float(res[r]) - float(cost[r]))

func add_buff(id: String, buff_stats: Dictionary, duration: float) -> void:
	if duration > 1.0:
		duration *= 1.0 + stats.get_stat("inc_buff_duration") / 100.0
	var sf := stats.get_stat("shared_flame")
	if sf > 0.0 and not id.begins_with("aura_noscale"):
		var scaled := {}
		for k in buff_stats:
			var v := float(buff_stats[k])
			scaled[k] = v * (1.0 + sf / 100.0) if v > 0.0 else v
		buff_stats = scaled
	for b in buffs:
		if b.id == id:
			b.time = duration
			return
	buffs.append({"id": id, "stats": buff_stats, "time": duration})
	recalc_stats()

func has_buff(id: String) -> bool:
	for b in buffs:
		if b.id == id:
			return true
	return false

## Called by SkillExec before a Rite resolves: Kindling and Empowered shots.
func pre_cast(skill_id: String, s: Dictionary) -> void:
	_combat_t = 5.0
	var cls: String = s.get("class", "")
	if cls == "magus" and s.kind == "spell" and not ["lance", "cataclysm"].has(s.behavior) and not s.has("res_cost"):
		gain_res("kindling", 1.0)
	var extra := asc.cast_extra(self, skill_id)
	if not extra.is_empty():
		var stx := cast_stats.duplicate_block()
		stx.add_mods(extra)
		cast_stats = stx
	if s.behavior == "lance" and resources().has("kindling"):
		var k: float = res.kindling
		var st := cast_stats.duplicate_block()
		st.add("more_damage", 50.0 * k)
		cast_stats = st
		res.kindling = 0.0
	if cls == "ranger" and resources().has("focus") and res.focus >= 100.0 and not s.has("res_cost") and s.behavior != "buff":
		var st2 := cast_stats.duplicate_block()
		st2.add("inc_crit_chance", 5000.0)
		st2.add("pierce_add", 99.0)
		if stats.get_stat("perfect_focus") > 0.0:
			st2.add("pf_return", 1.0)
		cast_stats = st2
		res.focus -= 50.0
		FX.text(global_position, "EMPOWERED", Color(0.8, 1.0, 0.6), 20)
		FX.ring(global_position, 60.0, Color(0.8, 1.0, 0.6), 0.3)

func on_dealt_hit(_target: Actor, _amount: float) -> void:
	_combat_t = 5.0
	gain_res("resolve", 2.0 * (1.0 + stats.get_stat("resolve_gain") / 100.0))
	gain_res("focus", 2.0 * (1.0 + stats.get_stat("focus_gain") / 100.0))

func take_hit(result: Dictionary, src: Actor, knock_dir: Vector2 = Vector2.ZERO, knock_force: float = 0.0) -> float:
	var dealt := super.take_hit(result, src, knock_dir, knock_force)
	if dealt > 0.0:
		_combat_t = 5.0
		gain_res("resolve", 5.0 * (1.0 + stats.get_stat("resolve_gain") / 100.0))
	return dealt

func on_blocked() -> void:
	gain_res("resolve", 4.0)
	if stats.get_stat("block_nova") > 0.0 and asc.nova_cd <= 0.0:
		asc.nova_cd = 1.0
		var g := game()
		var sk := {"kind": "spell", "base_damage": {"fire": [8.0 + level * 2.0, 14.0 + level * 3.0]}, "crit": 5.0, "tags": ["area"], "ignite_chance": 25.0}
		for t in g.targets_in_circle(faction, global_position, 190.0):
			t.take_hit(Damage.roll_hit(sk, stats, g.rng), self, t.global_position - global_position, 220.0)
		FX.ring(global_position, 190.0, Color(1.0, 0.55, 0.2), 0.3, 10.0)

## Stoneblood: armour from Resolve.
func defense_stats() -> StatBlock:
	var k := stats.get_stat("armour_per_resolve")
	if k <= 0.0 or not resources().has("resolve"):
		return stats
	var b := stats.duplicate_block()
	b.add("armour", float(res.resolve) * k)
	return b

func _tick_class(delta: float) -> void:
	_combat_t -= delta
	if _combat_t <= 0.0 and res.resolve > 0.0:
		res.resolve = maxf(0.0, res.resolve - 4.0 * delta)
	if velocity.length() > 60.0:
		gain_res("focus", 5.0 * delta * (1.0 + stats.get_stat("focus_gain") / 100.0))
	var changed := false
	for i in range(buffs.size() - 1, -1, -1):
		buffs[i].time -= delta
		if buffs[i].time <= 0.0:
			buffs.remove_at(i)
			changed = true
	if changed:
		recalc_stats()
	if has_buff("oathbreaker"):
		_oath_fx -= delta
		if _oath_fx <= 0.0:
			_oath_fx = 0.08
			FX.burst(global_position + Vector2(randf_range(-20, 20), -40), Color(1.0, 0.5, 0.2), 2, 60.0, 6.0, 0.5)

func class_points() -> int:
	return (level - 1) - class_nodes.size()

func rite_points() -> int:
	var used := 0
	for k in rite_specs:
		used += int(rite_specs[k])
	return (level - 1) - used

func can_respec() -> bool:
	return level < FREE_RESPEC_LEVEL

## Rites you can put on the bar: starting Rites of your classes + Rites unlocked in class trees.
func unlocked_rites() -> Array:
	var out: Array = []
	for c in classes():
		for r in ClassesDB.class_def(c).get("starting_rites", []):
			if not out.has(r):
				out.append(r)
	for key in class_nodes:
		var parts: PackedStringArray = key.split("/")
		var n := ClassesDB.node(parts[0], parts[1])
		if n.get("type", "") == "rite" and not out.has(n.rite):
			out.append(n.rite)
	return out

func node_taken(c: String, b: int, i: int) -> bool:
	return class_nodes.has("%s/%d:%d" % [c, b, i])

func can_take_node(c: String, b: int, i: int) -> bool:
	if class_points() <= 0 or node_taken(c, b, i) or not classes().has(c):
		return false
	return i == 0 or node_taken(c, b, i - 1)

func take_node(c: String, b: int, i: int) -> bool:
	if not can_take_node(c, b, i):
		return false
	class_nodes["%s/%d:%d" % [c, b, i]] = true
	_after_build_change()
	return true

func refund_node(c: String, b: int, i: int) -> bool:
	if not can_respec() or not node_taken(c, b, i) or node_taken(c, b, i + 1):
		return false
	var n := ClassesDB.node(c, "%d:%d" % [b, i])
	class_nodes.erase("%s/%d:%d" % [c, b, i])
	if n.get("type", "") == "rite":
		var idx := bar.find(n.rite)
		if idx >= 0:
			bar[idx] = ""
	_after_build_change()
	return true

func spec_rank(skill_id: String, spec_id: String) -> int:
	return int(rite_specs.get("%s/%s" % [skill_id, spec_id], 0))

func add_spec(skill_id: String, spec_id: String) -> bool:
	var specs: Array = ClassesDB.SPECS.get(skill_id, [])
	for sp in specs:
		if sp.id == spec_id and spec_rank(skill_id, spec_id) < int(sp.max) and rite_points() > 0:
			rite_specs["%s/%s" % [skill_id, spec_id]] = spec_rank(skill_id, spec_id) + 1
			_after_build_change()
			return true
	return false

func remove_spec(skill_id: String, spec_id: String) -> bool:
	if not can_respec() or spec_rank(skill_id, spec_id) <= 0:
		return false
	var k := "%s/%s" % [skill_id, spec_id]
	rite_specs[k] = spec_rank(skill_id, spec_id) - 1
	if rite_specs[k] <= 0:
		rite_specs.erase(k)
	_after_build_change()
	return true

func choose_second_class(c: String) -> bool:
	if level < DUAL_CLASS_LEVEL or class2_id != "" or c == class_id or not ClassesDB.class_def(c).get("built", false):
		return false
	class2_id = c
	ensure_roots()
	_after_build_change()
	return true

func _after_build_change() -> void:
	_spec_cache.clear()
	recalc_stats()
	inventory_changed.emit()

## Skill definition with this player's Rite specializations folded in.
func skill_def(skill_id: String) -> Dictionary:
	var base: Dictionary = SkillsDB.SKILLS[skill_id]
	var specs: Array = ClassesDB.SPECS.get(skill_id, [])
	var asc_mods: Array = []
	for n in asc_nodes_list():
		if n.has("skill") and n.skill.has(skill_id):
			asc_mods.append(n.skill[skill_id])
	if specs.is_empty() and asc_mods.is_empty():
		return base
	var s := base.duplicate()
	for sp in specs:
		var r := spec_rank(skill_id, sp.id)
		if r > 0 and sp.has("skill"):
			for k in sp.skill:
				s[k] = float(s.get(k, 0.0)) + float(sp.skill[k]) * r
	for m in asc_mods:
		for k in m:
			if String(k).ends_with("_pct"):
				var real := String(k).trim_suffix("_pct")
				if s.has(real):
					s[real] = float(s[real]) * (1.0 + float(m[k]) / 100.0)
			else:
				s[k] = float(s.get(k, 0.0)) + float(m[k])
	return s

## Stats used when casting this Rite: character stats plus that Rite's specialization.
func stats_for(skill_id: String) -> StatBlock:
	if _spec_cache.has(skill_id):
		return _spec_cache[skill_id]
	var specs: Array = ClassesDB.SPECS.get(skill_id, [])
	var st := stats
	var extra := StatBlock.new()
	var any := false
	for sp in specs:
		var r := spec_rank(skill_id, sp.id)
		if r > 0 and sp.has("stats"):
			for k in sp.stats:
				for i in r:
					extra.add(k, float(sp.stats[k]))
			any = true
	for n in asc_nodes_list():
		if n.has("skill_stats") and n.skill_stats.has(skill_id):
			extra.add_mods(n.skill_stats[skill_id])
			any = true
	if any:
		st = stats.merged_with(extra)
	_spec_cache[skill_id] = st
	return st

func passive_points() -> int:
	var spent := 0
	var roots := PassivesDB.roots_for(classes())
	for id in passives:
		if not roots.has(id):
			spent += 1
	return (level - 1) - spent

## Make sure this character's entry star(s) are allocated (and only those roots).
func ensure_roots() -> void:
	var want := PassivesDB.roots_for(classes())
	for r in want:
		passives[r] = true
	# drop anything no longer connected to a root (e.g. after a class change or old saves)
	var tree := PassivesDB.nodes()
	var seen := {}
	var stack: Array = want.duplicate()
	for r in want:
		seen[r] = true
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for l in tree[cur].links:
			if passives.has(l) and not seen.has(l):
				seen[l] = true
				stack.append(l)
	for id in passives.keys():
		if not seen.has(id):
			passives.erase(id)
			masteries.erase(id)

## Pick the next effect on an allocated Mastery (free).
func cycle_mastery(id: String) -> bool:
	var tree := PassivesDB.nodes()
	if not passives.has(id) or not tree.has(id) or tree[id].type != "mastery":
		return false
	masteries[id] = (int(masteries.get(id, 0)) + 1) % tree[id].options.size()
	recalc_stats()
	return true

func can_allocate(id: String) -> bool:
	if passives.has(id) or passive_points() <= 0:
		return false
	for l in PassivesDB.nodes()[id].links:
		if passives.has(l):
			return true
	return false

func allocate(id: String) -> bool:
	if not can_allocate(id):
		return false
	passives[id] = true
	recalc_stats()
	return true

## Refund only if every other allocated node stays connected to the start.
func can_refund(id: String) -> bool:
	var roots := PassivesDB.roots_for(classes())
	if roots.has(id) or not passives.has(id):
		return false
	var tree := PassivesDB.nodes()
	var seen := {}
	for r in roots:
		seen[r] = true
	var stack: Array = roots.duplicate()
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for l in tree[cur].links:
			if l != id and passives.has(l) and not seen.has(l):
				seen[l] = true
				stack.append(l)
	return seen.size() == passives.size() - 1

func refund(id: String) -> bool:
	if not can_refund(id):
		return false
	passives.erase(id)
	masteries.erase(id)
	recalc_stats()
	return true

static func calc_max_life(s: StatBlock) -> float:
	return maxf(1.0, s.get_stat("life_flat") * s.inc_mult(["inc_life"]) * s.get_stat("more_life"))

## Derived numbers shown on the character sheet and in item comparisons.
func summary(eq: Dictionary) -> Dictionary:
	var s := build_stats(eq)
	var out := {
		"Life": calc_max_life(s),
		"Mana": s.get_stat("mana_flat"),
		"Armour": s.get_stat("armour"),
		"Fire Res": minf(75.0, s.get_stat("res_fire")),
		"Cold Res": minf(75.0, s.get_stat("res_cold")),
		"Lightning Res": minf(75.0, s.get_stat("res_lightning")),
		"Move Speed": s.inc_mult(["inc_move_speed"]) * 100.0,
	}
	var rng := RandomNumberGenerator.new()
	for sid in bar:
		if sid == "":
			continue
		var sk: Dictionary = skill_def(sid)
		if sk.get("base_damage", {}).is_empty() or not ["projectile", "melee_arc", "nova", "chain", "ground", "beam", "eruption"].has(sk.behavior):
			continue
		rng.seed = 12345
		var total := 0.0
		var n := 120
		for i in n:
			total += Damage.total(Damage.roll_hit(sk, s.merged_with(_spec_extra(sid)), rng).damage)
		var avg := total / n
		var speed := s.inc_mult(["inc_attack_speed" if sk.kind == "attack" else "inc_cast_speed"])
		var period := maxf(float(sk.time) / speed, float(sk.get("cooldown", 0.0)))
		if sk.behavior == "ground":
			# ticks for its whole duration, recast on cooldown
			var ticks := float(sk.duration) / float(sk.tick)
			out[sk.name + " DPS"] = avg * ticks / maxf(period, float(sk.duration))
		else:
			out[sk.name + " DPS"] = avg / period
	return out

func _spec_extra(skill_id: String) -> StatBlock:
	var extra := StatBlock.new()
	for sp in ClassesDB.SPECS.get(skill_id, []):
		var r := spec_rank(skill_id, sp.id)
		if r > 0 and sp.has("stats"):
			for k in sp.stats:
				for i in r:
					extra.add(k, float(sp.stats[k]))
	return extra

static func xp_to_next(lvl: int) -> int:
	return int(round(70.0 * pow(lvl, 1.55)))

func recalc_stats(refill: bool = false) -> void:
	var life_frac := life / max_life if max_life > 0.0 else 1.0
	var mana_frac := mana / max_mana if max_mana > 0.0 else 1.0
	stats = build_stats(equipment)
	_spec_cache.clear()
	max_life = calc_max_life(stats)
	max_mana = maxf(0.0, stats.get_stat("mana_flat"))
	ward_max = stats.get_stat("ember_ward_flat") + stats.get_stat("ember_ward_per_level") * level
	var wfl := stats.get_stat("ward_from_life")
	if wfl > 0.0:
		ward_max += max_life * wfl / 100.0
		max_life = maxf(1.0, max_life * (1.0 - wfl / 100.0))
	flask_max = 3 + int(stats.get_stat("flask_max_add"))
	ward_pool = minf(ward_pool, ward_max) if not refill else ward_max
	if refill:
		life = max_life
		mana = max_mana
	else:
		life = clampf(max_life * life_frac, 1.0, max_life)
		mana = clampf(max_mana * mana_frac, 0.0, max_mana)

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		recalc_stats(true)
		FX.ring(global_position, 220.0, Color(1.0, 0.8, 0.35), 0.6, 10.0)
		FX.burst(global_position, Color(1.0, 0.8, 0.35), 50, 420.0, 9.0, 0.8)
		FX.text(global_position, "LEVEL %d" % level, Color(1.0, 0.85, 0.4), 34)
		FX.sound("levelup", null, 0.0, 0.0)
		FX.rumble(0.4, 0.2, 0.35)
		if game() and game().hud:
			var sub := "+1 Ember Point, +1 Class Point, +1 Rite Point"
			if level == DUAL_CLASS_LEVEL and class_id != "classic":
				sub = "Dual-class unlocked: choose a second class in the class screen"
			game().hud.show_message("LEVEL %d" % level, sub)
		leveled_up.emit(level)

func add_flask_charge(amount: float) -> void:
	flask_charges = minf(flask_max, flask_charges + amount)

func _physics_process(delta: float) -> void:
	if dead:
		return
	tick_common(delta)
	_tick_class(delta)
	asc.tick(self, delta)
	_anim += delta
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	mana = minf(max_mana, mana + stats.get_stat("mana_regen") * stats.inc_mult(["inc_mana_regen"]) * delta)
	if _flask_heal > 0.0:
		var h := minf(_flask_heal, max_life * 0.6 * delta / 1.0)
		heal(h)
		_flask_heal -= h
	var to_aim := input.aim - global_position
	if to_aim.length() > 4.0:
		facing = to_aim.normalized()
	# Dodge
	if _dodge_t > 0.0:
		_dodge_t -= delta
		velocity = _dodge_dir * (_dash_speed if _dash_speed > 0.0 else DODGE_DIST / DODGE_TIME)
		move_and_slide()
		if randf() < 0.6:
			FX.burst(global_position, Color(1.0, 0.6, 0.3), 2, 40.0, 7.0, 0.35)
		if _dodge_t <= 0.0:
			invulnerable = false
			if _dash_cb.is_valid():
				var cb := _dash_cb
				_dash_cb = Callable()
				cb.call()
		_update_visuals(delta)
		queue_redraw()
		return
	if input.dodge and _dodge_cd <= 0.0:
		_dodge_dir = input.move.normalized() if input.move.length() > 0.1 else facing
		_dodge_t = DODGE_TIME
		_dash_speed = 0.0
		_dodge_cd = DODGE_CD
		invulnerable = true
		busy_time = 0.0
		FX.flash(global_position, Color(1.0, 0.6, 0.3), 60.0, 0.15)
		FX.sound("dodge", null, -10.0)
		return
	if input.flask and flask_charges >= 1.0 and life < max_life:
		flask_charges -= 1.0
		_flask_heal += max_life * 0.6
		if game():
			game().writ_event("flask")
		FX.sound("flask", null, -3.0)
		FX.ring(global_position, 70.0, Color(1.0, 0.3, 0.35), 0.35)
		FX.burst(global_position, Color(1.0, 0.3, 0.35), 18, 160.0, 7.0, 0.5)
	# Skills (hold to repeat). Lower index wins when several are held.
	var sp: String = ClassesDB.class_def(class_id).get("special", "")
	if input.special and sp != "":
		var ss: Dictionary = SkillsDB.SKILLS[sp]
		var cost: Dictionary = ss.get("res_cost", {"spirit": ss.get("spirit_cost", 0)})
		if not can_pay(cost):
			var r: String = cost.keys()[0]
			FX.text(global_position, "Need %d %s" % [int(cost[r]), r.capitalize()], Color(0.6, 0.9, 0.5), 16)
		elif cooldowns.get(sp, 0.0) > 0.0:
			FX.text(global_position, "%s ready in %.0fs" % [ss.name, cooldowns[sp]], Color(0.8, 0.8, 0.8), 16)
		else:
			_special_buffer = 0.5   # fire as soon as the current cast ends
	if _special_buffer > 0.0:
		_special_buffer -= delta
		if SkillExec.use(sp, self, input.aim):
			_special_buffer = 0.0
	for i in bar.size():
		if bar[i] != "" and input.skill_held[i]:
			if SkillExec.use(bar[i], self, input.aim):
				input.consume(i)
				break
	# Movement (slowed while casting/attacking).
	var speed := move_speed() * (0.45 if busy_time > 0.0 else 1.0)
	velocity = input.move.normalized() * speed + knock
	move_and_slide()
	_update_visuals(delta)
	queue_redraw()

func _draw() -> void:
	# shadow
	draw_set_transform(Vector2(0, radius * 0.7), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius * 1.4, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ignite_time > 0.0:
		draw_arc(Vector2(0, radius * 0.7), radius * 1.5, 0, TAU, 24, Color(1, 0.45, 0.1, 0.7), 2.0, true)

# ---------- visuals ----------

var hero := "knight_m"
var _spr: AnimatedSprite2D
var _wpn: Sprite2D
var _wpn_id := ""
var _mat: ShaderMaterial
var _hit_t := 0.0
var _swing_t := 0.0
var _swing_dir := 1.0
var _lunge := Vector2.ZERO

func _build_visuals() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/sprite_fx.gdshader")
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = Art.frames_for(hero)
	_spr.scale = Vector2.ONE * Art.PX
	_spr.position = Vector2(0, -44)
	_spr.material = _mat
	_spr.play("idle")
	add_child(_spr)
	_wpn = Sprite2D.new()
	_wpn.centered = false
	_wpn.scale = Vector2.ONE * Art.PX * 0.85
	_wpn.material = _mat
	add_child(_wpn)
	_light = FX.make_light(Color(1.0, 0.78, 0.55), 560.0, 1.05)
	_light.position = Vector2(0, -30)
	add_child(_light)
	_refresh_weapon()

func set_hero(h: String) -> void:
	hero = h if Art.HEROES.has(h) else "knight_m"
	if _spr:
		_spr.sprite_frames = Art.frames_for(hero)
		_spr.play("idle")

func _refresh_weapon() -> void:
	var it: Item = equipment.get("weapon")
	var id := ""
	if it:
		id = it.unique_id if Art.WEAPON_SPRITES.has(it.unique_id) else it.base_id
	if id == _wpn_id:
		return
	_wpn_id = id
	_wpn.visible = id != ""
	if id != "":
		var name: String = Art.WEAPON_SPRITES.get(id, "weapon_rusty_sword")
		_wpn.texture = Art.tex(name)
		var sz := Art.size_of(name)
		_wpn.offset = Vector2(-sz.x / 2.0, -sz.y + 4)   # pivot near the grip

## Called by SkillExec when the player uses a Rite.
func on_skill_used(skill: Dictionary) -> void:
	_swing_t = 0.22 if skill.get("kind") == "attack" else 0.14
	_swing_dir = -_swing_dir
	_lunge = facing * (10.0 if skill.get("kind") == "attack" else 4.0)

func _update_visuals(delta: float) -> void:
	if _spr == null:
		return
	_refresh_weapon()
	_hit_t = maxf(0.0, _hit_t - delta)
	_swing_t = maxf(0.0, _swing_t - delta)
	_lunge = _lunge.move_toward(Vector2.ZERO, 120.0 * delta)
	var anim := "idle"
	if _hit_t > 0.0:
		anim = "hit"
	elif velocity.length() > 30.0:
		anim = "run"
	if _spr.animation != anim:
		_spr.play(anim)
	var left := facing.x < -0.05
	_spr.flip_h = left
	_spr.position = Vector2(0, -44) + _lunge
	_spr.scale = Vector2.ONE * Art.PX * (1.3 if has_buff("oathbreaker") else 1.0)
	_spr.modulate.a = 0.55 if invulnerable else 1.0
	# weapon follows aim, swings on attacks
	var hand := Vector2(-14.0 if left else 14.0, -22.0) + _lunge
	_wpn.position = hand
	var base_angle := facing.angle() + PI / 2.0
	var swing := 0.0
	if _swing_t > 0.0:
		var k := 1.0 - _swing_t / 0.22
		swing = lerpf(-1.4, 1.4, k) * _swing_dir
	_wpn.rotation = base_angle + swing
	_wpn.z_index = 1 if facing.y > -0.3 else -1
	# status + flash
	var tint := Color.WHITE
	if is_chilled():
		tint = Color(0.6, 0.85, 1.0)
	elif shock_time > 0.0:
		tint = Color(1.0, 1.0, 0.7)
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("flash", 0.5 if hit_flash > 0.0 else 0.0)

func _on_hit_fx(dmg: Dictionary, amount: float, crit: bool) -> void:
	super._on_hit_fx(dmg, amount, crit)
	_hit_t = 0.15

func to_save() -> Dictionary:
	var eq := {}
	for sl in equipment:
		if equipment[sl]:
			eq[sl] = equipment[sl].to_dict()
	var inv: Array = []
	for it in inventory:
		inv.append(it.to_dict() if it else null)
	return {"level": level, "xp": xp, "equipment": eq, "inventory": inv, "passives": passives.keys(), "hero": hero,
		"class": class_id, "class2": class2_id, "class_nodes": class_nodes.keys(), "rite_specs": rite_specs, "bar": bar,
		"spirit": spirit, "res": res, "currency": currency,
		"ascendancy": ascendancy, "asc_nodes": asc_nodes, "asc_trials": asc_trials, "masteries": masteries}

func from_save(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	hero = d.get("hero", "knight_m")
	class_id = d.get("class", "classic")
	class2_id = d.get("class2", "")
	class_nodes = {}
	for k in d.get("class_nodes", []):
		class_nodes[k] = true
	ascendancy = d.get("ascendancy", "")
	asc_nodes = []
	for i in d.get("asc_nodes", []):
		asc_nodes.append(int(i))
	asc_trials = int(d.get("asc_trials", 0))
	rite_specs = {}
	var rs: Dictionary = d.get("rite_specs", {})
	for k in rs:
		rite_specs[k] = int(rs[k])
	var b: Array = d.get("bar", [])
	if b.size() > 0:
		bar = b.duplicate()
	while bar.size() < SkillsDB.BAR_SIZE:
		bar.append("")
	currency = {}
	var cd: Dictionary = d.get("currency", {})
	for k in cd:
		currency[k] = int(cd[k])
	var rd: Dictionary = d.get("res", {})
	for k in rd:
		res[k] = float(rd[k])
	if d.has("spirit") and not rd.has("spirit"):
		spirit = float(d.spirit)
	passives = {}
	for id in d.get("passives", []):
		if PassivesDB.nodes().has(id):
			passives[id] = true
	masteries = {}
	var md: Dictionary = d.get("masteries", {})
	for k in md:
		masteries[k] = int(md[k])
	ensure_roots()
	equipment.clear()
	var eqd: Dictionary = d.get("equipment", {})
	for sl in eqd:
		equipment[sl] = Item.from_dict(eqd[sl])
	inventory.clear()
	inventory.resize(INV_SIZE)
	var inv: Array = d.get("inventory", [])
	for i in mini(inv.size(), INV_SIZE):
		if inv[i] != null:
			inventory[i] = Item.from_dict(inv[i])

## New character of a class: starting Rites on the bar.
func set_class(c: String) -> void:
	class_id = c
	ensure_roots()
	var start: Array = ClassesDB.class_def(c).get("starting_rites", [])
	bar = []
	for i in SkillsDB.BAR_SIZE:
		bar.append(start[i] if i < start.size() else "")

func add_to_inventory(it: Item) -> bool:
	for i in INV_SIZE:
		if inventory[i] == null:
			inventory[i] = it
			inventory_changed.emit()
			return true
	return false

## Equip from bag index. Rings go to the empty ring slot, else ring1.
func equip_from_bag(idx: int) -> void:
	var it: Item = inventory[idx]
	if it == null:
		return
	if it.req_level() > level:
		FX.text(global_position, "Requires Level %d" % it.req_level(), Color(1, 0.4, 0.4))
		return
	var slot := it.slot_group()
	if slot == "ring":
		slot = "ring1" if equipment.get("ring1") == null else ("ring2" if equipment.get("ring2") == null else "ring1")
	var old: Item = equipment.get(slot)
	equipment[slot] = it
	inventory[idx] = old
	recalc_stats()
	inventory_changed.emit()

func unequip(slot: String) -> void:
	var it: Item = equipment.get(slot)
	if it == null:
		return
	if add_to_inventory(it):
		equipment.erase(slot)
		recalc_stats()
		inventory_changed.emit()

func target_slot_for(it: Item) -> String:
	var s := it.slot_group()
	if s == "ring":
		return "ring1" if equipment.get("ring1") == null else ("ring2" if equipment.get("ring2") == null else "ring1")
	return s
