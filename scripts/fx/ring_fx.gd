class_name RingFX
extends Node2D

var max_radius := 100.0
var color := Color.WHITE
var duration := 0.35
var width := 6.0
var _t := 0.0

func _ready() -> void:
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = mat
	z_index = 5

func _process(delta: float) -> void:
	_t += delta
	if _t >= duration:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var k := _t / duration
	var r := max_radius * (1.0 - pow(1.0 - k, 3.0))
	var c := color
	c.a = 1.0 - k
	draw_arc(Vector2.ZERO, r, 0, TAU, 64, c, width * (1.0 - k * 0.6), true)
	c.a *= 0.15
	draw_circle(Vector2.ZERO, r, c)
