class_name LightningFX
extends Node2D

var points: Array = []
var color := Color.YELLOW
var _t := 0.0
var _jag: Array = []
const DUR := 0.22

func _ready() -> void:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	z_index = 9
	_regen()

func _regen() -> void:
	_jag.clear()
	for i in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var seg := PackedVector2Array()
		var n := maxi(3, int(a.distance_to(b) / 22.0))
		var perp := (b - a).orthogonal().normalized()
		for j in n + 1:
			var p := a.lerp(b, float(j) / n)
			if j > 0 and j < n:
				p += perp * randf_range(-14.0, 14.0)
			seg.append(p)
		_jag.append(seg)

func _process(delta: float) -> void:
	_t += delta
	if _t >= DUR:
		queue_free()
		return
	if int(_t * 60.0) % 3 == 0:
		_regen()
	queue_redraw()

func _draw() -> void:
	var k := 1.0 - _t / DUR
	for seg in _jag:
		var c := color
		c.a = 0.35 * k
		draw_polyline(seg, c, 12.0, true)
		c.a = k
		draw_polyline(seg, c, 4.0, true)
		draw_polyline(seg, Color(1, 1, 1, k), 1.5, true)
