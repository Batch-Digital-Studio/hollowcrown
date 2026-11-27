class_name Portal
extends Node2D
## Appears when the boss falls. Step in to descend.

signal entered
var _t := 0.0
var _used := false

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
		if g.player.global_position.distance_to(global_position) < 48.0:
			_used = true
			entered.emit()

func _draw() -> void:
	var grow := minf(1.0, _t * 1.5)
	for i in 5:
		var r := (26.0 + i * 9.0) * grow
		var a := _t * (2.0 - i * 0.3) * (1 if i % 2 == 0 else -1)
		draw_arc(Vector2.ZERO, r, a, a + PI * 1.3, 32, Color(0.7, 0.5, 1.0, 0.9 - i * 0.15), 3.0, true)
	draw_circle(Vector2.ZERO, 22.0 * grow, Color(0.15, 0.05, 0.3, 0.9))
	draw_circle(Vector2.ZERO, 10.0 * grow, Color(0.85, 0.75, 1.0, 0.8))
