extends Node
## --ttk: time-to-kill a 3000-life husk dummy with each class's main Rite (shaman also with 4 husks).
var phase := -1
var t := 0.0
var classes := ["magus", "shaman", "oath", "ranger"]
var ci := 0
var dummy: Enemy
var g: Game
func _ready() -> void:
	FX.enabled = false
func _process(delta: float) -> void:
	g = Game.instance
	if g == null or g.player == null or g.state != "play":
		return
	var p := g.player
	p.invulnerable = true
	if phase == -1:
		for e in g.enemies.duplicate():
			g.enemies.erase(e)
			e.queue_free()
		phase = 0
		return
	if phase == 0:
		var c: String = classes[ci]
		p.set_class(c)
		p.class2_id = ""
		p.level = 5
		p.equipment["weapon"] = Loot.starter_weapon(ClassesDB.class_def(c).get("starter_weapon", "rusted_blade"))
		p.recalc_stats(true)
		for a in g.allies.duplicate():
			g.allies.erase(a)
			a.queue_free()
		var off := Vector2(110, 0) if c == "oath" else Vector2(420, 0)
		dummy = g.spawn_enemy("husk", 5, "normal", [], p.global_position + off)
		dummy.max_life = 3000.0
		dummy.life = 3000.0
		dummy.set_physics_process(false)
		if c == "shaman":
			for i in 4:
				SkillExec.spawn_minion(g, p, p.global_position + Vector2(60, 40 * i - 60))
		t = 0.0
		phase = 1
		return
	t += delta
	p.mana = p.max_mana
	var main: String = p.bar[1] if classes[ci] == "shaman" else p.bar[0]
	SkillExec.use(main, p, dummy.global_position)
	if dummy.dead or t > 60.0:
		print("BAL %s level 5: %.1f s to kill 3000 life (%s)" % [classes[ci], t, main])
		ci += 1
		phase = 0 if ci < classes.size() else 9
		if phase == 9:
			get_tree().quit()
