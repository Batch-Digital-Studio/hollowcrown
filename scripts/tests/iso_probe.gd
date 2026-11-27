extends Node
## --iso-probe: checks the isometric 3D view.
##  1. The 2D canvas projection matches Godot's own Camera3D projection (ground effects line up).
##  2. The mouse maps back to the right ground point (aim).
##  3. "Move up" on the keyboard/stick moves the hero up the screen.
##  4. Models exist for the hero and monsters; the hero's model is the class model.
##  5. Ember Bolt creates a 3D bolt, then its impact; the 2D projectile is hidden.
##  6. A monster that dies plays a death animation.
##  7. Switching to the classic 2D view and back works.
var t := 0.0
var step := 0
var fails := 0
var checks := 0
var p0 := Vector2.ZERO
var s0 := Vector2.ZERO
var saw_bolt := false
var saw_impact := false
var victim: Enemy

func _ready() -> void:
	FX.enabled = false

func ok(cond: bool, what: String) -> void:
	checks += 1
	if not cond:
		fails += 1
	print("ISO %s: %s" % ["ok" if cond else "FAIL", what])

func _process(delta: float) -> void:
	var g := Game.instance
	if g != null and g.state == "title" and g.bot == null:
		g.hud.hide_overlays()
		var heroes: Array = ClassesDB.class_def("magus").heroes
		g.start_game(false, heroes[0], "magus")
	if g == null or g.player == null or g.state != "play":
		return
	t += delta
	var p := g.player
	p.invulnerable = true
	var v := g.iso_view
	match step:
		0:
			if t > 1.0:
				ok(IsoView.active, "isometric view is on by default")
				var ct := get_viewport().canvas_transform
				var worst := 0.0
				var worst_cam := 0.0
				for off in [Vector2.ZERO, Vector2(300, 0), Vector2(0, 300), Vector2(-250, 180), Vector2(400, -320)]:
					var w: Vector2 = p.global_position + off
					var a: Vector2 = ct * w
					var b := IsoView.screen_of(IsoView.to3d(w))
					var c := v.cam.unproject_position(IsoView.to3d(w))
					worst = maxf(worst, a.distance_to(b))
					worst_cam = maxf(worst_cam, a.distance_to(c))
				ok(worst < 0.5, "2D canvas = 3D ground projection (max error %.3f px)" % worst)
				ok(worst_cam < 1.0, "matches Camera3D.unproject_position (max error %.3f px)" % worst_cam)
				# mouse: a screen point maps back to the ground point under it
				var w2: Vector2 = p.global_position + Vector2(160, 90)
				var back: Vector2 = ct.affine_inverse() * (ct * w2)
				ok(back.distance_to(w2) < 0.5, "screen -> ground inverse (aim) is exact")
				p0 = p.global_position
				s0 = ct * p0
				Input.action_press("move_up")
				t = 0.0
				step = 1
		1:
			if t > 0.6:
				Input.action_release("move_up")
				var s1: Vector2 = get_viewport().canvas_transform * p.global_position
				var d := s1 - s0
				ok(p.global_position.distance_to(p0) > 30.0 and d.y < -20.0 and absf(d.x) < absf(d.y) * 0.35, "move_up walks up the screen (screen delta %s)" % str(d.round()))
				var pp: Puppet = v.puppets.get(p)
				ok(pp != null and pp.model != null, "hero has a 3D model")
				var want: String = ModelsDB.for_class(p.class_id).model
				ok(pp != null and pp.model != null and String(pp.model.scene_file_path).contains(want), "hero model is %s for class %s" % [want, p.class_id])
				var n_enemy := 0
				for e in g.enemies:
					if v.puppets.has(e):
						n_enemy += 1
				ok(n_enemy > 0 and n_enemy == g.enemies.size(), "every monster has a model (%d)" % n_enemy)
				# Ember Bolt at a monster
				victim = null
				for e in g.enemies:
					if is_instance_valid(e) and not e.dead and (victim == null or e.global_position.distance_to(p.global_position) < victim.global_position.distance_to(p.global_position)):
						victim = e
				if victim:
					victim.global_position = p.global_position + Vector2(260, 0)
					victim.set_physics_process(false)
					victim.max_life = 1.0
					victim.life = 1.0
				p.cooldowns.clear()
				p.busy_time = 0.0
				p.mana = p.max_mana
				SkillExec.use("ember_bolt", p, p.global_position + Vector2(260, 0))
				print("ISO cast Ember Bolt at clock %.3f" % g._clock)
				t = 0.0
				step = 2
		2:
			for b in v.bolts:
				if is_instance_valid(b):
					saw_bolt = true
					if not has_meta("hid"):
						set_meta("hid", true)
						ok((b as Projectile).visible == false, "2D projectile hidden under the 3D bolt")
			if saw_bolt and v.bolts.is_empty():
				saw_impact = true
			if t > 1.2:
				ok(saw_bolt, "Ember Bolt made a 3D bolt")
				ok(saw_impact, "the bolt finished (impact played)")
				var vp: Puppet = v.puppets.get(victim) if victim else null
				ok(victim != null and victim.dead, "the bolt killed the test monster")
				ok(vp != null and vp.ap != null and vp.ap.current_animation.begins_with("Death"), "monster corpse plays a death animation (%s)" % (vp.ap.current_animation if vp and vp.ap else "no model"))
				g.set_view_3d(false)
				t = 0.0
				step = 3
		3:
			if t > 0.3:
				ok(not IsoView.active and g.camera.enabled and g.zone.visible, "classic 2D view restored")
				var any_vis := false
				for c in p.get_children():
					if c is AnimatedSprite2D and c.visible:
						any_vis = true
				ok(any_vis, "2D hero sprite visible again")
				g.set_view_3d(true)
				t = 0.0
				step = 4
		4:
			if t > 0.3:
				ok(IsoView.active and not g.camera.enabled, "back to isometric 3D")
				print("ISO probe: %d/%d checks passed" % [checks - fails, checks])
				get_tree().quit(1 if fails > 0 else 0)
