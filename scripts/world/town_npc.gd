class_name TownNPC
extends Node2D
## Emberhold's services. Like the Peddler: open the inventory beside them to use them.
##   stash    - the Ember Vault: shared storage (3 tabs x 48)
##   salvager - Grimm the Smelter: destroys bag items up to a rarity, for Ash Dust
##   waypoint - the Waystone: step on it to open the world map

const RANGE := 170.0
var kind := "stash"
var _t := 0.0
var _spr: AnimatedSprite2D

const INFO := {
	"stash": {"name": "Ember Vault", "hint": "trade items with your stash"},
	"salvager": {"name": "Grimm the Smelter", "hint": "salvage gear in bulk"},
	"waypoint": {"name": "Waystone", "hint": "step on it for the world map"},
}

func _ready() -> void:
	z_index = 2
	match kind:
		"stash":
			_spr = AnimatedSprite2D.new()
			_spr.sprite_frames = Art.prop_frames("chest_full_open_anim", 1.0)
			_spr.scale = Vector2.ONE * Art.PX * 1.4
			_spr.position = Vector2(0, -26)
			_spr.modulate = Color(1.0, 0.85, 0.6)
			add_child(_spr)
		"salvager":
			_spr = AnimatedSprite2D.new()
			_spr.sprite_frames = Art.frames_for("lizard_m")
			_spr.scale = Vector2.ONE * Art.PX
			_spr.position = Vector2(0, -28)
			_spr.play("idle")
			add_child(_spr)
	add_child(FX.make_light(Color(1.0, 0.75, 0.45) if kind != "waypoint" else Color(0.6, 0.8, 1.0), 300.0, 1.0))

func near(p: Node2D) -> bool:
	return p != null and is_instance_valid(p) and p.global_position.distance_to(global_position) < (70.0 if kind == "waypoint" else RANGE)

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	if kind == "waypoint":
		var c := Color(0.6, 0.8, 1.0)
		draw_circle(Vector2.ZERO, 56.0, Color(0.1, 0.15, 0.25, 0.6))
		draw_arc(Vector2.ZERO, 56.0, 0, TAU, 48, Color(c.r, c.g, c.b, 0.5 + 0.3 * sin(_t * 3.0)), 3.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(-9, -70), Vector2(0, -82), Vector2(9, -70), Vector2(14, 0)]), Color(0.25, 0.27, 0.35))
		draw_line(Vector2(0, -70), Vector2(0, -14), Color(c.r, c.g, c.b, 0.7 + 0.3 * sin(_t * 4.0)), 3.0)
	var f := ThemeDB.fallback_font
	var nm: String = String(INFO[kind].name)
	var w := f.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string_outline(f, Vector2(-w / 2, -96), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(f, Vector2(-w / 2, -96), nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.8, 0.5))
	var g := Game.instance
	if g and near(g.player) and kind != "waypoint":
		var h: String = ("View: " if PlayerInput.using_pad else "I: ") + String(INFO[kind].hint)
		var w2 := f.get_string_size(h, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string_outline(f, Vector2(-w2 / 2, 24), h, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
		draw_string(f, Vector2(-w2 / 2, 24), h, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.85, 0.7, 0.6 + 0.4 * sin(_t * 4.0)))

## A portal in town back to the depth you came from (stand in it for a second).
class ReturnPortal extends Node2D:
	var _t := 0.0
	var _hold := 0.0
	func _ready() -> void:
		z_index = 1
		add_child(FX.make_light(Color(0.7, 0.5, 1.0), 280.0, 1.0))
	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()
		var g := Game.instance
		if g == null or g.player == null:
			return
		if g.player.global_position.distance_to(global_position) < 64.0:
			_hold += delta
			if _hold >= 1.0:
				_hold = -99.0
				g.leave_town(g.depth)
		else:
			_hold = maxf(0.0, _hold - delta * 2.0)
	func _draw() -> void:
		var c := Color(0.7, 0.5, 1.0)
		draw_circle(Vector2.ZERO, 44.0, Color(0.2, 0.1, 0.3, 0.6))
		draw_arc(Vector2.ZERO, 44.0 + sin(_t * 3.0) * 4.0, 0, TAU, 48, c, 4.0, true)
		if _hold > 0.0:
			draw_arc(Vector2.ZERO, 64.0, -PI / 2, -PI / 2 + TAU * _hold, 40, Color(0.9, 0.8, 1.0), 4.0, true)
		var g := Game.instance
		var f := ThemeDB.fallback_font
		var s := "Return to Depth %d · %s (stand here)" % [g.depth, WorldDB.zone_name(g.depth)] if g else ""
		var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string_outline(f, Vector2(-w / 2, -64), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
		draw_string(f, Vector2(-w / 2, -64), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.75, 1.0))
