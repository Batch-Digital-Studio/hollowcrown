extends Node
var t := 0.0
var done := false
func _process(delta: float) -> void:
	t += delta
	var g := Game.instance
	if g == null or g.player == null:
		return
	if t > 1.0 and not done:
		done = true
		var p := g.player
		p.level = 10
		p.class_nodes["shaman/2:0"] = true
		p.recalc_stats(true)
		p.bar[2] = "spirit_totem"
		print("unlocked: ", p.unlocked_rites(), " can_use=", p.can_use("spirit_totem"), " mana=", p.mana)
		var ok := SkillExec.use("spirit_totem", p, p.global_position + Vector2(120, 0))
		print("use returned ", ok, " allies=", g.allies.size())
	if t > 2.0:
		var n := 0
		for a in g.allies:
			if a is Totem:
				n += 1
				print("totem alive life=", a.life, " dur=", a.duration, " t=", a._t, " pos=", a.global_position)
		print("totems=", n)
		get_tree().quit()
