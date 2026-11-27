class_name SlashFX
extends Node2D

var dir := Vector2.RIGHT
var radius := 100.0
var arc := PI
var color := Color.WHITE
var _t := 0.0
const DUR := 0.18

func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	z_index = 9

func _process(delta: float) -> void:
	_t += delta
	if _t >= DUR:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := _t / DUR
	var a0 := dir.angle() - arc / 2.0
	var sweep := arc * minf(1.0, k * 2.2)
	var c := color
	c.a = 1.0 - k
	for i in 4:
		var rr := radius * (0.55 + 0.15 * i)
		var cc := c
		cc.a *= 0.35 + 0.18 * i
		draw_arc(Vector2.ZERO, rr, a0, a0 + sweep, 32, cc, 10.0 - i * 2.0, true)
	# leading edge
	var edge := Vector2.RIGHT.rotated(a0 + sweep)
	draw_line(edge * radius * 0.35, edge * radius * 1.05, Color(1, 1, 1, c.a), 4.0, true)
