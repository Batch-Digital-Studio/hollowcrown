class_name WorldOverlay
extends Node2D
## Unlit world-space overlay: enemy life bars and rare monster names stay readable in the dark.
## In the isometric 3D view it draws in screen space above each model's head.

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var g := Game.instance
	if g == null:
		return
	var f := ThemeDB.fallback_font
	var cam := g.view_center()
	var iso := IsoView.active
	if iso:
		draw_set_transform_matrix(get_canvas_transform().affine_inverse())
	for e in g.enemies:
		if not is_instance_valid(e) or e.dead or e.is_boss():
			continue
		if e.global_position.distance_to(cam) > 1400.0:
			continue
		var x: float = e.global_position.x
		var top: float = e.global_position.y - e.sprite_height() - 10.0
		if iso:
			var head := IsoView.screen_of(IsoView.to3d(e.global_position, IsoView.head_height(e)))
			x = head.x
			top = head.y - 8.0
		if e.life < e.max_life:
			var w := maxf(40.0, e.radius * 2.4)
			var bar_c := Color(0.85, 0.15, 0.12)
			if e.rarity == "rare":
				bar_c = Color(0.95, 0.7, 0.2)
			elif e.rarity == "magic":
				bar_c = Color(0.35, 0.5, 1.0)
			var r := Rect2(x - w / 2, top, w, 5)
			draw_rect(r.grow(1), Color(0, 0, 0, 0.85))
			draw_rect(Rect2(r.position, Vector2(w * e.life / e.max_life, 5)), bar_c)
		if e.rarity == "rare":
			var s: String = e.display_name
			var tw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
			var pos := Vector2(x - tw / 2, top - 8)
			draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.9))
			draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.85, 0.4))
	if iso:
		# minion life bars (the 2D versions are hidden in this view)
		for m in g.allies:
			if not is_instance_valid(m) or not (m is Minion) or m.dead or m.life >= m.max_life:
				continue
			var hp := IsoView.screen_of(IsoView.to3d(m.global_position, IsoView.head_height(m)))
			var w := 34.0
			draw_rect(Rect2(hp.x - w / 2, hp.y - 6, w, 4), Color(0, 0, 0, 0.7))
			draw_rect(Rect2(hp.x - w / 2, hp.y - 6, w * m.life / m.max_life, 4), Color(0.45, 0.9, 0.35))
