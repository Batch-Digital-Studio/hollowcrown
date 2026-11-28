class_name RareBrain
extends RefCounted
## Chapter 1 rare monsters: a name ("Grimfang, the Hungering") and two abilities from
## ChapterDB.RARE_ABILITIES that they actually use in the fight. Simulation only (Game.rng);
## the 3D view reads `abilities` to draw the aura.

var e: Enemy
var abilities: Array = []
var cd := {}
var shield := 0.0          # soulwarded: absorbs damage
var _tick := 0.0

static func roll(enemy: Enemy, rng: RandomNumberGenerator) -> RareBrain:
	var b := RareBrain.new()
	b.e = enemy
	var keys: Array = ChapterDB.RARE_ABILITIES.keys()
	# region flavour: some abilities fit some families better
	var pool := keys.duplicate()
	while b.abilities.size() < 2 and not pool.is_empty():
		var k: String = pool[rng.randi() % pool.size()]
		pool.erase(k)
		b.abilities.append(k)
	for a in b.abilities:
		var d: Dictionary = ChapterDB.RARE_ABILITIES[a]
		enemy.stats.add_mods(d.get("stats", {}))
		b.cd[a] = rng.randf_range(1.0, 3.0)
	var first: String = ChapterDB.RARE_FIRST[rng.randi() % ChapterDB.RARE_FIRST.size()]
	var title: String = ChapterDB.RARE_TITLE[rng.randi() % ChapterDB.RARE_TITLE.size()]
	enemy.display_name = "%s, the %s" % [first, title]
	enemy.set_meta("rare_desc", " · ".join(b.abilities.map(func(a): return ChapterDB.RARE_ABILITIES[a].label)))
	return b

func aura_color() -> Color:
	return ChapterDB.RARE_ABILITIES[abilities[0]].aura if not abilities.is_empty() else Color(1.0, 0.8, 0.3)

func has(a: String) -> bool:
	return abilities.has(a)

## Absorb part of a hit with the soul ward. Returns the remaining amount.
func absorb(amount: float) -> float:
	if shield <= 0.0:
		return amount
	var take := minf(shield, amount)
	shield -= take
	if shield <= 0.0:
		FX.text(e.global_position, "Ward broken", Color(0.95, 0.95, 1.0), 18)
	return amount - take

func tick(p: Actor, dist: float, delta: float) -> void:
	var g := e.game()
	for k in cd:
		cd[k] -= delta
	_tick -= delta
	# Infernal: burning aura around it, every half second
	if has("infernal") and _tick <= 0.0:
		_tick = 0.5
		for t in g.targets_in_circle(e.faction, e.global_position, 170.0):
			t.take_hit(Damage.roll_hit(SkillsDB.SKILLS["rare_burn"], e.stats, g.rng), e)
	if dist > 900.0:
		return
	for a in abilities:
		if cd[a] > 0.0:
			continue
		var d: Dictionary = ChapterDB.RARE_ABILITIES[a]
		match a:
			"stormcaller":
				for i in 3:
					var pos: Vector2 = p.global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * g.rng.randf_range(0.0, 140.0)
					var h := Hazard.make(e, "circle", pos, SkillsDB.SKILLS["rare_strike"], 0.9 + i * 0.25)
					h.r = 80.0
					h.set_meta("fx3d", "strike")
					g.fx_node.add_child(h)
				FX.text(e.global_position, "Stormcaller!", d.aura, 16)
			"frostbound":
				if dist < 260.0:
					var h := Hazard.make(e, "circle", e.global_position, SkillsDB.SKILLS["rare_nova"], 0.8)
					h.r = 220.0
					h.anchor = e
					h.set_meta("fx3d", "nova")
					g.fx_node.add_child(h)
				else:
					continue
			"vile":
				e.cast_stats = e.stats
				var ge := GroundEffect.new()
				ge.setup(SkillsDB.SKILLS["rare_pool"], e, p.global_position)
				g.fx_node.add_child(ge)
			"warcaller":
				for o in g.enemies_near(e.global_position, 500.0):
					if o != e and not o.dead:
						o.stats.add("inc_attack_speed", 15)
						o.stats.add("inc_move_speed", 15)
						o.stats.add("more_damage", 10)
						o.aggro = true
				FX.ring(e.global_position, 500.0, d.aura, 0.6, 10.0)
				FX.text(e.global_position, "Warcry!", d.aura, 18)
			"broodmother":
				var n := 0
				for o in g.enemies_near(e.global_position, 700.0):
					if o.type_id == e.type_id:
						n += 1
				if n < 8:
					for i in 2:
						var pos: Vector2 = e.global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * 90.0
						if not g.is_wall(pos):
							var m := g.spawn_enemy(e.type_id, maxi(1, e.level - 1), "normal", [], pos)
							m.aggro = true
							FX.burst(pos, d.aura, 14, 160.0, 7.0, 0.4)
			"blinker":
				if dist > 160.0:
					var dest: Vector2 = p.global_position + (e.global_position - p.global_position).normalized().rotated(g.rng.randf_range(-1.2, 1.2)) * 90.0
					if not g.is_wall(dest):
						FX.burst(e.global_position, d.aura, 20, 200.0, 7.0, 0.4)
						e.global_position = dest
						FX.burst(dest, d.aura, 20, 200.0, 7.0, 0.4)
						FX.sound("blink", dest, -6.0)
				else:
					continue
			"soulwarded":
				shield = e.max_life * 0.25
				FX.ring(e.global_position, e.radius * 2.0, d.aura, 0.5, 8.0)
				FX.text(e.global_position, "Soulward", d.aura, 16)
			_:
				continue
		cd[a] = float(d.cd) * g.rng.randf_range(0.85, 1.15)

func on_death() -> void:
	if has("volatile"):
		var g := e.game()
		var h := Hazard.make(e, "circle", e.global_position, SkillsDB.SKILLS["rare_blast"], 1.1)
		h.r = 170.0
		h.set_meta("fx3d", "nova")
		h.set_meta("keep", true)
		g.fx_node.add_child(h)
		FX.text(e.global_position, "It's going to blow!", Color(1.0, 0.6, 0.25), 18)
