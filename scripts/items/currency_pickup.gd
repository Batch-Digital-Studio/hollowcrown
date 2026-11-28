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

func _ready() -> void:
	add_to_group("interactable")

func _process(delta: float) -> void:
	_t += delta
	position += _vel * delta
	_vel = _vel.move_toward(Vector2.ZERO, 900.0 * delta)
	var g := Game.instance
	if g and g.player and not g.player.dead and _t > 0.3 and g.auto_loot:
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

# --- Interact: click / A to pick up (Auto-loot pulls it in as before) ---
func can_interact() -> bool:
	return _t > 0.3 and not is_queued_for_deletion()
func interact_label() -> String:
	return "Pick up %s x%d" % [CurrencyDB.info(id).name, amount]
func interact_kind() -> String:
	return ""          # auto-loot handles currency with its own magnet above
func interact_range() -> float:
	return 90.0
func auto_range() -> float:
	return 0.0
func interact(p: Player) -> void:
	p.add_currency(id, amount)
	FX.sound("pickup", null, -12.0, 0.2)
	queue_free()

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
