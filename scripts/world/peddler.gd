class_name Peddler
extends Node2D
## The Ashen Peddler. Stands near each zone's start. Open the inventory beside him to trade.

const RANGE := 190.0
const OFFERS := [  # currency for Ash Dust
	{"id": "kindling_shard", "dust": 4},
	{"id": "ash_salt", "dust": 8},
	{"id": "coal_ascension", "dust": 12},
	{"id": "hollow_ember", "dust": 25},
	{"id": "crown_fragment", "dust": 30},
]

var stock: Array = []   # Items (null once sold)
var _t := 0.0

static func price(it: Item) -> int:
	var base: float = {"normal": 6.0, "magic": 18.0, "rare": 60.0, "unique": 220.0}.get(it.rarity, 10.0)
	return int(base * (1.0 + it.ilvl * 0.12))

static func sell_value(it: Item) -> int:
	return maxi(1, int(price(it) * 0.2))

func _ready() -> void:
	z_index = 2
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = Art.prop_frames("goblin_idle_anim", 6.0)
	spr.scale = Vector2.ONE * Art.PX
	spr.position = Vector2(0, -24)
	spr.play()
	add_child(spr)
	var l := FX.make_light(Color(1.0, 0.7, 0.4), 260.0, 0.9)
	add_child(l)
	restock()

func restock() -> void:
	var g := Game.instance
	stock.clear()
	for i in 6:
		var rar := "rare" if i < 2 else "magic"
		stock.append(Loot.make_item(g.area_level() + 1, g.rng, rar))

func near(p: Node2D) -> bool:
	return p != null and p.global_position.distance_to(global_position) < RANGE

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var f := ThemeDB.fallback_font
	var s := "Ashen Peddler"
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	draw_string_outline(f, Vector2(-w / 2, -66), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color.BLACK)
	draw_string(f, Vector2(-w / 2, -66), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.75, 0.4))
	var g := Game.instance
	if g and near(g.player):
		var h := "View: trade" if PlayerInput.using_pad else "I: trade"
		var w2 := f.get_string_size(h, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string_outline(f, Vector2(-w2 / 2, 18), h, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
		draw_string(f, Vector2(-w2 / 2, 18), h, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.9, 0.85, 0.7, 0.6 + 0.4 * sin(_t * 4.0)))
