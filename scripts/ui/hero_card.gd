class_name HeroCard
extends Button
## Animated hero portrait button for the character select screen.

var hero := ""
var _t := 0.0

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var sf := Art.frames_for(hero)
	var active := is_hovered() or has_focus()
	var anim := "run" if active else "idle"
	var n := sf.get_frame_count(anim)
	var tex := sf.get_frame_texture(anim, int(_t * (12.0 if anim == "run" else 7.0)) % n)
	var s := 5.0
	var sz := tex.get_size() * s
	var pos := Vector2(size.x / 2 - sz.x / 2, size.y - sz.y - 44)
	draw_texture_rect(tex, Rect2(pos, sz), false)
	var f := ThemeDB.fallback_font
	var label: String = Art.HERO_NAMES[hero]
	var w := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18).x
	draw_string(f, Vector2(size.x / 2 - w / 2, size.y - 16), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18,
		Color(1.0, 0.82, 0.45) if active else Color(0.85, 0.8, 0.75))
