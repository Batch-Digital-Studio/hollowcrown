class_name Portal
extends Node2D
## Appears when the boss falls. Step in to descend.

signal entered
var _t := 0.0
var _used := false
var _hold := 0.0
const HOLD := 1.0

func _ready() -> void:
	var g := FX.make_glow(Color(0.6, 0.4, 1.0, 0.8), 220.0)
	add_child(g)
	z_index = 2
	FX.ring(global_position, 160.0, Color(0.7, 0.5, 1.0), 0.6, 10.0)
	FX.sound("portal", null, 0.0, 0.0)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var g := Game.instance
	if not _used and _t > 1.0 and g.player and not g.player.dead:
		# stand in the portal for a moment to go through (no accidental descents while looting)
		if g.player.global_position.distance_to(global_position) < 64.0:
			_hold += delta
			if _hold >= HOLD:
				_used = true
				entered.emit()
		else:
			_hold = maxf(0.0, _hold - delta * 2.0)

func _draw() -> void:
	var grow := minf(1.0, _t * 1.5)
	for i in 5:
		var r := (26.0 + i * 9.0) * grow
		var a := _t * (2.0 - i * 0.3) * (1 if i % 2 == 0 else -1)
		draw_arc(Vector2.ZERO, r, a, a + PI * 1.3, 32, Color(0.7, 0.5, 1.0, 0.9 - i * 0.15), 3.0, true)
	draw_circle(Vector2.ZERO, 22.0 * grow, Color(0.15, 0.05, 0.3, 0.9))
	draw_circle(Vector2.ZERO, 10.0 * grow, Color(0.85, 0.75, 1.0, 0.8))
	if _hold > 0.0 and not _used:
		draw_arc(Vector2.ZERO, 70.0, -PI / 2, -PI / 2 + TAU * _hold / HOLD, 40, Color(0.9, 0.8, 1.0), 4.0, true)
	var f := ThemeDB.fallback_font
	var s := "Descend (stand here)"
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(f, Vector2(-w / 2, -84), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
	draw_string(f, Vector2(-w / 2, -84), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.75, 1.0))
