class_name CurrencyPickup
extends Node2D
## A stack of currency on the ground. Drifts to the player when close.

var id := "ember_shards"
var amount := 1
var _t := 0.0
var _vel := Vector2.ZERO

func setup(cid: String, n: int, pos: Vector2, scatter: Vector2) -> void:
	id = cid
	amount = n
	position = pos
	_vel = scatter
	z_index = 3

func _process(delta: float) -> void:
	_t += delta
	position += _vel * delta
	_vel = _vel.move_toward(Vector2.ZERO, 900.0 * delta)
	var g := Game.instance
	if g and g.player and not g.player.dead and _t > 0.3:
		var to := g.player.global_position - global_position
		var d := to.length()
		if d < 170.0:
			position += to.normalized() * minf(d, (420.0 + (170.0 - d) * 4.0) * delta)
		if d < 30.0:
			g.player.add_currency(id, amount)
			FX.sound("pickup", null, -12.0, 0.2)
			queue_free()
			return
	queue_redraw()

func _draw() -> void:
	var c: Color = CurrencyDB.info(id).color
	var bob := sin(_t * 5.0) * 2.0
	if id == "ember_shards":
		var tex := Art.tex("coin_anim", int(_t * 8.0) % 4)
		draw_texture_rect(tex, Rect2(Vector2(-12, -12 + bob), Vector2(24, 24)), false)
	else:
		var pts := PackedVector2Array([Vector2(0, -10 + bob), Vector2(7, bob), Vector2(0, 10 + bob), Vector2(-7, bob)])
		draw_colored_polygon(pts, c)
		draw_polyline(pts + PackedVector2Array([pts[0]]), Color.WHITE, 1.0, true)
	if amount > 1:
		draw_string(ThemeDB.fallback_font, Vector2(9, -6), "x%d" % amount, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, c)
