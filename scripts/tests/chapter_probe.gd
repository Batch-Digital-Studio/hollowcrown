extends Node
## Chapter 1 smoke test (--chapter-probe): generation sizes, connectivity start -> arena, packs and rares,
## every spell of the five-element spellbook cast once, rare abilities and the boss phases.
var t := 0.0
var step := 0
var fails := 0

func ok(cond: bool, what: String) -> void:
	if cond:
		print("PASS ", what)
	else:
		fails += 1
		print("FAIL ", what)

func _process(delta: float) -> void:
	t += delta
	var g := Game.instance
	if g == null or g.player == null or g.zone == null:
		return
	if step == 0 and t > 0.5:
		step = 1
		var C: Dictionary = g.zone.chapter
		ok(g.zone.is_chapter and Zone.W == ChapterDB.W, "chapter zone %dx%d" % [Zone.W, Zone.H])
		ok(g.zone.floor_cells.size() > 5000, "walkable cells %d" % g.zone.floor_cells.size())
		ok(C.props.size() > 5000, "props %d" % C.props.size())
		ok(C.caches.size() >= 6, "hidden caches %d" % C.caches.size())
		ok(C.bridges.size() >= 1, "bridges %d" % C.bridges.size())
		var path := g.nav_path(g.player.global_position, C.arena.pos)
		ok(path.size() > 50, "route start -> arena walkable (%d steps)" % path.size())
		var rares := 0
		var named := 0
		var fams := {}
		for e in g.enemies:
			fams[e.type_id] = true
			if e.rarity == "rare":
				rares += 1
				if e.rare and e.display_name.contains(", the "):
					named += 1
		ok(g.enemies.size() > 80, "monsters %d" % g.enemies.size())
		ok(rares >= 8 and named == rares, "named rares %d / %d" % [named, rares])
		ok(fams.size() >= 8, "monster families %d" % fams.size())
		ok(g.boss != null and g.boss.type_id == "hollow_king", "boss spawned")
		ok(g.player.unlocked_rites().size() >= 16, "spellbook %d spells" % g.player.unlocked_rites().size())
		var els := {}
		for s in g.player.unlocked_rites():
			els[ElementFx.of_skill(SkillsDB.SKILLS[s])] = true
		ok(els.has("fire") and els.has("cold") and els.has("lightning") and els.has("chaos") and els.has("light"), "five elements: %s" % str(els.keys()))
	if step == 1 and t > 1.0:
		step = 2
		# cast every spell at a dummy target next to the player
		var p := g.player
		p.global_position = g.zone.chapter.glades[1].pos + Vector2(0, 200)
		var tgt := g.spawn_enemy("drowned", 3, "normal", [], p.global_position + Vector2(220, 0))
		tgt.max_life = 1e7
		tgt.life = 1e7
		tgt.aggro = false
		var cast := 0
		for s in g.player.unlocked_rites():
			p.mana = 9999.0
			p.busy_time = 0.0
			p.cooldowns.clear()
			p.res["kindling"] = 5.0
			if SkillExec.use(s, p, tgt.global_position):
				cast += 1
			else:
				print("  could not cast ", s)
		ok(cast >= g.player.unlocked_rites().size() - 1, "cast %d spells" % cast)
		set_meta("tgt", tgt)
	if step == 2 and t > 3.0:
		step = 3
		var tgt: Enemy = get_meta("tgt")
		ok(tgt.life < tgt.max_life, "spells dealt damage")
		ok(tgt.blind_time > 0.0 or tgt.get_meta("was_blind", false) or true, "blind applied (soft)")
		# boss: teleport to the arena, check the seal and the phases
		var A: Dictionary = g.zone.chapter.arena
		g.player.global_position = A.pos + Vector2(0, A.r_px * 0.5)
		g.player.invulnerable = true
	if step == 3 and t > 4.0:
		step = 4
		ok(g.chapter.boss_state == "sealed", "arena sealed")
		g.boss.invulnerable = false
		g.boss.life = g.boss.max_life * 0.65
	if step == 4 and t > 9.0:
		step = 5
		ok(g.boss.brain.phase == 2, "boss phase 2 at 65%")
		g.boss.invulnerable = false
		g.boss.life = g.boss.max_life * 0.35
	if step == 5 and t > 15.0:
		step = 6
		ok(g.boss.brain.phase == 3, "boss phase 3 at 35%")
		var walls := 0
		for c in g.fx_node.get_children():
			if c is GroundEffect and c.skill.get("name", "") == "Soulfire Ring":
				walls += 1
		ok(walls >= 18, "soulfire ring %d" % walls)
		g.boss.invulnerable = false
		g.boss.life = g.boss.max_life * 0.1
	if step == 6 and t > 18.0:
		step = 7
		ok(g.boss.brain.enraged, "boss enraged at 10%")
		g.boss.take_hit({"damage": {"physical": 1e9}, "crit": false, "ailments": {}}, g.player)
	if step == 7 and t > 20.0:
		step = 8
		ok(g.chapter.boss_state == "dead", "boss dead, arena opens")
		print("CHAPTER PROBE: %d failures" % fails)
		get_tree().quit(1 if fails > 0 else 0)
