class_name BoundEmber
extends Node2D
## A monster sealed in burning crystal. Come close and it breaks free, empowered.
## Kill it for an Essence.

const MOD_FOR := {"added_fire": "emberborn", "added_cold": "rimebound", "res_cold": "rimebound",
	"added_lightning": "stormtouched", "life": "bulwark", "move_speed": "hasted", "crit_chance": "brutal", "inc_spell": "brutal"}

var monster := "husk"
var essence := "life"
var tier := 1
var _t := 0.0

func roll(rng: RandomNumberGenerator, depth: int) -> void:
	var ids := ["husk", "cinderling", "brute", "rattler", "rimecaller"]
	monster = ids[rng.randi() % ids.size()]
	var keys: Array = CurrencyDB.ESSENCES.keys()
	essence = keys[rng.randi() % keys.size()]
	tier = clampi(1 + (depth - 1) / 2 + (1 if rng.randf() < 0.2 else 0), 1, 4)

func _ready() -> void:
	z_index = 1
	add_child(FX.make_light(CurrencyDB.ESSENCES[essence].color, 220.0, 0.9))

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var g := Game.instance
	if g and g.player and not g.player.dead and g.player.global_position.distance_to(global_position) < 170.0:
		_free(g)

func _free(g: Game) -> void:
	var mm: Array = [MOD_FOR[essence]]
	for k in g._roll_mods(2):
		if not mm.has(k) and mm.size() < 2:
			mm.append(k)
	var e := g.spawn_enemy(monster, g.area_level() + tier - 1, "rare", mm, global_position)
	e.aggro = true
	e.max_life *= 1.0 + tier * 0.25
	e.life = e.max_life
	e.set_meta("essence", CurrencyDB.essence_id(essence, tier))
	FX.burst(global_position, CurrencyDB.ESSENCES[essence].color, 40, 300.0, 8.0, 0.6)
	FX.sound("boom", null, -6.0, 0.0)
	FX.shake(6.0)
	FX.text(global_position, "The Bound Ember breaks free!", CurrencyDB.ESSENCES[essence].color, 20)
	if g.bot:
		print("TEST bound ember freed ", e.get_meta("essence"))
	queue_free()

func _draw() -> void:
	var c: Color = CurrencyDB.ESSENCES[essence].color
	var def: Dictionary = EnemiesDB.ENEMIES[monster]
	var tex := Art.tex(def.sprite + "_idle_anim", int(_t * 3.0) % 4)
	if tex:
		var sz := tex.get_size() * Art.PX
		draw_texture_rect(tex, Rect2(Vector2(-sz.x / 2, -sz.y + 6), sz), false, Color(c.r, c.g, c.b, 0.85))
	var pulse := 0.5 + 0.5 * sin(_t * 2.5)
	var pts := PackedVector2Array([Vector2(0, -110), Vector2(48, -60), Vector2(40, 12), Vector2(0, 30), Vector2(-40, 12), Vector2(-48, -60)])
	draw_colored_polygon(pts, Color(c.r, c.g, c.b, 0.18 + 0.1 * pulse))
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(c.r, c.g, c.b, 0.9), 2.5, true)
	draw_line(Vector2(-20, -90), Vector2(10, -30), Color(1, 1, 1, 0.35), 2.0)
	var f := ThemeDB.fallback_font
	var s := "Bound Ember · %s" % CurrencyDB.info(CurrencyDB.essence_id(essence, tier)).name
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string_outline(f, Vector2(-w / 2, -122), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
	draw_string(f, Vector2(-w / 2, -122), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, c)
