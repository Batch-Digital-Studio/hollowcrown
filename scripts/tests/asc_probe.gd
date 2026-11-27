extends Node
## --asc-probe: checks that ascension notables actually change behaviour.
## Each check builds a fresh situation next to the player with dummy enemies.

var t := 0.0
var step := 0
var fails := 0
var g: Game
var p: Player
var e1: Enemy
var mem := {}

func _ready() -> void:
	FX.enabled = false

func check(name: String, ok: bool) -> void:
	print(("  PASS " if ok else "  FAIL ") + name)
	if not ok:
		fails += 1

func asc(id: String, nodes: Array) -> void:
	p.class_id = AscensionsDB.ASC[id]["class"]
	p.asc_trials = 4
	p.ascendancy = id
	p.asc_nodes = nodes.duplicate()
	p.recalc_stats(true)

func kp(id: String, on: bool) -> void:
	if on:
		p.passives[id] = true
	else:
		p.passives.erase(id)
		p.masteries.erase(id)
	p.recalc_stats(true)

func dummy(id: String = "brute", off: Vector2 = Vector2(150, 0), life_mult: float = 30.0) -> Enemy:
	var e := g.spawn_enemy(id, 1, "normal", [], p.global_position + off)
	e.max_life *= life_mult
	e.life = e.max_life
	e.set_physics_process(false)   # stand still, don't fight back
	return e

func clear() -> void:
	for e in g.enemies.duplicate():
		g.enemies.erase(e)
		e.queue_free()
	for a in g.allies.duplicate():
		if a is Minion or a is Totem:
			g.allies.erase(a)
			a.queue_free()

func _process(delta: float) -> void:
	g = Game.instance
	if g == null or g.player == null or g.state != "play":
		return
	t += delta
	p = g.player
	p.invulnerable = false
	match step:
		0:
			if t > 1.0:
				clear()
				step = 1
		1:  # Everburn: ignite stacks to 3x
			asc("pyromancer", [0])
			e1 = dummy()
			var hit := {"damage": {"fire": 40.0}, "crit": false, "ailments": {"ignite": 100.0}}
			e1.take_hit(hit.duplicate(true), p)
			var one := e1.ignite_dps
			e1.take_hit(hit.duplicate(true), p)
			e1.take_hit(hit.duplicate(true), p)
			e1.take_hit(hit.duplicate(true), p)
			check("Everburn stacks ignite to 3x (%.1f -> %.1f)" % [one, e1.ignite_dps], absf(e1.ignite_dps - one * 3.0) < 0.5)
			asc("pyromancer", [])
			var e2 := dummy("brute", Vector2(-150, 0))
			e2.take_hit(hit.duplicate(true), p)
			var one2 := e2.ignite_dps
			e2.take_hit(hit.duplicate(true), p)
			check("without Everburn ignite does not stack", absf(e2.ignite_dps - one2) < 0.5)
			clear()
			step = 2
		2:  # Fire Within: immune to ignite
			asc("pyromancer", [3])
			e1 = dummy("cinderling")
			p.take_hit({"damage": {"fire": 5.0}, "crit": false, "ailments": {"ignite": 100.0}}, e1)
			check("Fire Within: player cannot be ignited", p.ignite_time <= 0.0)
			clear()
			step = 3
		3:  # Absolute Zero + Still Air + Shatter
			asc("rimeweaver", [0, 5])
			e1 = dummy("brute", Vector2(150, 0), 1.0)
			e1.chill_time = 2.0
			e1.life = e1.max_life * 0.5
			e1.take_hit({"damage": {"cold": e1.max_life * 0.45}, "crit": false, "ailments": {}}, p)
			check("Absolute Zero freezes chilled enemy under 30%", e1.frozen_time > 0.0)
			check("frozen enemy cannot move", e1.move_speed() == 0.0)
			var before := e1.life
			e1.take_hit({"damage": {"physical": 1.0}, "crit": false, "ailments": {}}, p)
			mem["frozen_dmg"] = before - e1.life
			clear()
			asc("rimeweaver", [0])
			e1 = dummy("brute", Vector2(150, 0), 1.0)
			e1.chill_time = 2.0
			e1.life = e1.max_life * 0.2
			e1.freeze(1.5)
			var b2 := e1.life
			e1.take_hit({"damage": {"physical": 1.0}, "crit": false, "ailments": {}}, p)
			check("Still Air: frozen enemies take 25%% more (%.3f vs %.3f)" % [mem.frozen_dmg, b2 - e1.life], mem.frozen_dmg > (b2 - e1.life) * 1.2)
			clear()
			step = 4
		4:  # Shieldwall + Last Stand
			asc("ashguard", [])
			e1 = dummy("brute")
			p.life = p.max_life
			p.take_hit({"damage": {"fire": 20.0}, "crit": false, "ailments": {}}, e1)
			var base := p.max_life - p.life
			asc("ashguard", [2])
			p.life = p.max_life
			p.take_hit({"damage": {"fire": 20.0}, "crit": false, "ailments": {}}, e1)
			var sw := p.max_life - p.life
			check("Shieldwall: 12%% less damage (%.2f vs %.2f)" % [sw, base], absf(sw - base * 0.88) < 0.2)
			asc("ashguard", [3])
			p.asc.last_stand_cd = 0.0
			p.life = p.max_life * 0.35
			p.take_hit({"damage": {"fire": p.max_life * 0.1}, "crit": false, "ailments": {}}, e1)
			check("Last Stand triggers under 30%", p.asc.last_stand_t > 0.0)
			p.life = p.max_life
			clear()
			step = 5
		5:  # Stoneblood
			asc("ashguard", [4])
			p.class_id = "oath"
			p.res["resolve"] = 80.0
			var arm := p.defense_stats().get_stat("armour") - p.stats.get_stat("armour")
			check("Stoneblood: +3 armour per Resolve (%.0f)" % arm, (not p.resources().has("resolve")) or absf(arm - 240.0) < 1.0)
			step = 6
			t = 0.0
		6:  # Squires + Bog Beast upkeep
			asc("warlord", [1])
			p.asc.upkeep_t = 0.0
			step = 7
			t = 0.0
		7:
			if t > 0.3:
				var sq := 0
				for a in g.allies:
					if a is Minion and a.kind == "squire":
						sq += 1
				check("Sworn Squires: 2 squires summoned (%d)" % sq, sq == 2)
				clear()
				asc("thornwarden", [0])
				p.asc.upkeep_t = 0.0
				step = 8
				t = 0.0
		8:
			if t > 0.3:
				var bb := 0
				for a in g.allies:
					if a is Minion and a.kind == "beast":
						bb += 1
				check("Bog Beast: one beast companion (%d)" % bb, bb == 1)
				clear()
				step = 9
		9:  # Withering + Virulence + Chaos Bloom
			asc("plaguebringer", [0])
			e1 = dummy()
			for i in 60:
				e1.take_hit({"damage": {"chaos": 5.0}, "crit": false, "ailments": {"poison": 100.0}}, p)
			check("Virulence: more than 40 poison stacks (%d)" % e1.poisons.size(), e1.poisons.size() > 40)
			clear()
			asc("plaguebringer", [])
			e1 = dummy()
			e1.stats.add("res_chaos", 50.0)
			var l0 := e1.life
			e1.take_hit({"damage": {"chaos": 100.0}, "crit": false, "ailments": {}}, p)
			var plain := l0 - e1.life
			asc("plaguebringer", [4])
			l0 = e1.life
			e1.take_hit({"damage": {"chaos": 100.0}, "crit": false, "ailments": {}}, p)
			check("Chaos Bloom ignores 30%% chaos res (%.1f vs %.1f)" % [l0 - e1.life, plain], (l0 - e1.life) > plain * 1.5)
			clear()
			step = 10
		10:  # Skill overrides through skill_def
			asc("trapwright", [3, 4])
			var c0: Dictionary = SkillsDB.SKILLS["caltrops"]
			var c1 := p.skill_def("caltrops")
			check("Cluster Caltrops raises slow (%.2f -> %.2f)" % [c0.slow, c1.slow], c1.slow > c0.slow)
			check("Quick Hands cuts cooldown 30%% (%.1f -> %.1f)" % [c0.cooldown, c1.cooldown], absf(c1.cooldown - c0.cooldown * 0.7) < 0.01)
			asc("pyre_templar", [5])
			check("Solar Oath: Oathbreaker +4 s", absf(p.skill_def("oathbreaker").duration - SkillsDB.SKILLS["oathbreaker"].duration - 4.0) < 0.01)
			step = 11
		11:  # Conduit arcs
			asc("stormcaller", [4])
			e1 = dummy("brute", Vector2(150, 0))
			var e2 := dummy("brute", Vector2(210, 0))
			e1.shock_time = 4.0
			var l2 := e2.life
			e1.take_hit({"damage": {"lightning": 50.0}, "crit": false, "ailments": {}}, p)
			check("Conduit arcs to a neighbour", e2.life < l2)
			clear()
			step = 12
		12:  # Combustion on death
			asc("pyromancer", [2])
			e1 = dummy("brute", Vector2(150, 0), 1.0)
			var e3 := dummy("brute", Vector2(190, 0))
			e1.ignite_time = 3.0
			e1.ignite_dps = 1.0
			var l3 := e3.life
			e1.take_hit({"damage": {"physical": 99999.0}, "crit": false, "ailments": {}}, p)
			check("Combustion: burning enemy explodes on death", e3.life < l3)
			clear()
			asc("pyromancer", [])
			step = 13
		13:  # Constellation keystones and masteries
			var base_life := p.max_life
			var base_ward := p.ward_max
			kp("heart_key2", true)
			check("Ashen Avatar: 40%% of life becomes ward (life %.0f->%.0f, ward %.0f->%.0f)" % [base_life, p.max_life, base_ward, p.ward_max], p.max_life < base_life * 0.65 and p.ward_max > base_ward + base_life * 0.35)
			kp("heart_key2", false)
			kp("steel_key2", true)
			var crits := 0
			for i in 200:
				if Damage.roll_hit({"kind": "spell", "base_damage": {"fire": [5, 5]}, "crit": 100.0}, p.stats, g.rng).crit:
					crits += 1
			check("Unbroken Vow: cannot crit (%d crits)" % crits, crits == 0)
			e1 = dummy()
			p.ward_pool = 0.0
			var l0 := p.life
			p.take_hit({"damage": {"physical": 30.0}, "crit": true, "ailments": {}}, e1)
			var critted := l0 - p.life
			p.life = p.max_life
			p.ward_pool = 0.0
			p.take_hit({"damage": {"physical": 30.0}, "crit": false, "ailments": {}}, e1)
			check("Unbroken Vow: incoming crits are reduced (%.1f vs %.1f)" % [critted, p.max_life - p.life], critted < (p.max_life - p.life))
			kp("steel_key2", false)
			p.life = p.max_life
			var fm := p.flask_max
			kp("heart_mastery", true)
			p.masteries["heart_mastery"] = 0
			p.recalc_stats()
			check("Heart Mastery (flask charges): +1 flask (%d -> %d)" % [fm, p.flask_max], p.flask_max == fm + 1)
			p.cycle_mastery("heart_mastery")
			check("switching the Mastery removes the old effect", p.flask_max == fm and p.stats.get_stat("life_regen_pct") == 1.0)
			kp("heart_mastery", false)
			kp("venom_key", true)
			var l4 := e1.life
			e1.take_hit({"damage": {"physical": 100.0}, "crit": false, "ailments": {"poison": 100.0}}, p)
			var hit_tide := l4 - e1.life
			var pz: float = e1.poisons[0][0] if not e1.poisons.is_empty() else 0.0
			kp("venom_key", false)
			e1.poisons.clear()
			l4 = e1.life
			e1.take_hit({"damage": {"physical": 100.0}, "crit": false, "ailments": {"poison": 100.0}}, p)
			var hit_plain := l4 - e1.life
			var pz2: float = e1.poisons[0][0] if not e1.poisons.is_empty() else 0.0
			check("Tide of Venom: hits 40%% less (%.1f vs %.1f), poison the same (%.1f vs %.1f)" % [hit_tide, hit_plain, pz, pz2], absf(hit_tide - hit_plain * 0.6) < 1.0 and absf(pz - pz2) < 0.01)
			clear()
			kp("rime_key", true)
			p.bar[0] = "ember_bolt"
			p.mana = p.max_mana
			var before := 0
			for c in g.fx_node.get_children():
				if c is Projectile:
					before += 1
			SkillExec.use("ember_bolt", p, p.global_position + Vector2(300, 0))
			mem["proj_before"] = before
			step = 14
			t = 0.0
		14:
			if t > 0.3:
				var n := 0
				for c in g.fx_node.get_children():
					if c is Projectile:
						n += 1
				check("Echo of the Crown: Ember Bolt cast twice (%d projectiles)" % (n - int(mem.proj_before)), n - int(mem.proj_before) >= 2)
				kp("rime_key", false)
				print("ASC FAILURES: %d" % fails)
				get_tree().quit(1 if fails > 0 else 0)
