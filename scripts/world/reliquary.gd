class_name Reliquary
extends Node2D
## Strongbox-style chest showing up to four modifiers. Stand beside it for a second to open:
## read the mods first, walk away if you don't like them. No button needed (pad friendly).

const MODS := {
	"ambushed": {"label": "Ambushed", "desc": "guardian waves", "color": Color(1.0, 0.45, 0.35)},
	"gilded": {"label": "Gilded", "desc": "+2 rares", "color": Color(1.0, 0.85, 0.35)},
	"volatile": {"label": "Volatile", "desc": "explodes after 3 s", "color": Color(1.0, 0.6, 0.2)},
	"cursed": {"label": "Cursed", "desc": "rare guardians", "color": Color(0.75, 0.45, 1.0)},
	"echoing": {"label": "Echoing", "desc": "opens twice", "color": Color(0.5, 0.85, 1.0)},
	"arcane": {"label": "Arcane", "desc": "jewellery only", "color": Color(0.45, 0.6, 1.0)},
}
const HOLD := 1.0

var mods: Array = []
var opened := false
var _hold := 0.0
var _fuse := -1.0
var _echo_t := -1.0
var _wave_t := -1.0
var _t := 0.0
var _spr: AnimatedSprite2D

func roll(rng: RandomNumberGenerator, depth: int) -> void:
	var n := rng.randi_range(1, clampi(1 + depth / 2, 1, 4))
	var keys: Array = MODS.keys()
	while mods.size() < n:
		var k: String = keys[rng.randi() % keys.size()]
		if not mods.has(k):
			mods.append(k)

func _ready() -> void:
	z_index = 1
	_spr = AnimatedSprite2D.new()
	var sf := Art.prop_frames("chest_full_open_anim", 10.0)
	sf.set_animation_loop("default", false)
	_spr.sprite_frames = sf
	_spr.scale = Vector2.ONE * Art.PX * 1.25
	_spr.position = Vector2(0, -24)
	_spr.modulate = Color(1.0, 0.8, 1.0)
	add_child(_spr)
	add_child(FX.make_light(Color(0.9, 0.6, 1.0), 200.0, 0.8))

func _process(delta: float) -> void:
	_t += delta
	var g := Game.instance
	if g == null or g.player == null:
		return
	if _fuse > 0.0:
		_fuse -= delta
		if _fuse <= 0.0:
			_explode(g)
	if _wave_t > 0.0:
		_wave_t -= delta
		if _wave_t <= 0.0:
			_guardians(g, 5)
	if _echo_t > 0.0:
		_echo_t -= delta
		if _echo_t <= 0.0:
			opened = false
			_spr.frame = 0
			_spr.stop()
			FX.text(global_position, "The Reliquary echoes...", Color(0.5, 0.85, 1.0), 18)
	if not opened:
		var near := not g.player.dead and g.player.global_position.distance_to(global_position) < 85.0
		_hold = (_hold + delta) if near else maxf(0.0, _hold - delta * 2.0)
		if _hold >= HOLD:
			open(g)
	queue_redraw()

func open(g: Game) -> void:
	opened = true
	_hold = 0.0
	_spr.play()
	FX.sound("drop_unique", null, -6.0, 0.0)
	FX.burst(global_position, Color(0.9, 0.6, 1.0), 34, 280.0, 7.0, 0.6)
	FX.shake(5.0)
	var lvl := g.area_level() + 1
	var n := 2 + mods.size()
	for i in n:
		g.drop_item(_loot(g, lvl, "", 60.0 + 50.0 * mods.size()), global_position + Vector2(0, 10))
	if mods.has("gilded"):
		for i in 2:
			g.drop_item(_loot(g, lvl, "rare", 0.0), global_position + Vector2(0, 10))
	for i in 1 + mods.size() / 2:
		g.drop_currency(CurrencyDB.CRAFTING[g.rng.randi() % CurrencyDB.CRAFTING.size()], 1, global_position)
	g.drop_currency("ember_shards", int(20 * (1 + mods.size()) * (1.0 + g.depth * 0.25)), global_position)
	if mods.has("ambushed"):
		_guardians(g, 6)
		_wave_t = 4.0
	elif mods.has("cursed"):
		_guardians(g, 2)
	if mods.has("volatile"):
		_fuse = 3.0
		FX.text(global_position, "VOLATILE! RUN!", Color(1.0, 0.5, 0.2), 24)
	if mods.has("echoing"):
		mods.erase("echoing")
		_echo_t = 6.0
	g.writ_event("reliquary")
	if g.bot:
		print("TEST reliquary opened ", mods)

func _loot(g: Game, lvl: int, rar: String, bonus: float) -> Item:
	var it := Loot.make_item(lvl, g.rng, rar, bonus)
	if mods.has("arcane"):
		for k in 40:
			if it.slot_group() == "ring" or it.slot_group() == "amulet":
				break
			it = Loot.make_item(lvl, g.rng, rar, bonus)
	return it

func _guardians(g: Game, n: int) -> void:
	var cursed := mods.has("cursed")
	var ids := ["husk", "cinderling", "rattler", "brute"]
	for i in n:
		var p := global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * g.rng.randf_range(140, 260)
		if g.is_wall(p):
			p = global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * 90.0
		var n_rare := 1 if g.depth <= 1 else 2
		var rar := "rare" if cursed and i < n_rare else ("magic" if cursed else "normal")
		var mm: Array = g._roll_mods(2) if rar == "rare" else (g._roll_mods(1) if rar == "magic" else [])
		var e := g.spawn_enemy(ids[g.rng.randi() % ids.size()], g.area_level() + (1 if g.depth > 1 else 0), rar, mm, p)
		e.aggro = true
		FX.burst(p, Color(0.9, 0.6, 1.0), 12, 160.0, 6.0, 0.4)

func _explode(g: Game) -> void:
	FX.ring(global_position, 240.0, Color(1.0, 0.55, 0.2), 0.5, 14.0)
	FX.burst(global_position, Color(1.0, 0.6, 0.2), 60, 420.0, 9.0, 0.7)
	FX.sound("boom", null, 0.0, 0.0)
	FX.shake(12.0)
	var p := g.player
	if not p.dead and p.global_position.distance_to(global_position) < 240.0:
		var dmg := p.max_life * 0.45 * (1.0 + g.depth * 0.05)
		p.take_hit({"damage": {"fire": dmg, "physical": dmg * 0.5}, "crit": false, "ailments": {}}, null, (p.global_position - global_position).normalized(), 500.0)
	for e in g.enemies.duplicate():
		if e.global_position.distance_to(global_position) < 240.0:
			e.take_hit({"damage": {"fire": 9999.0}, "crit": false, "ailments": {}}, p)

func _draw() -> void:
	var f := ThemeDB.fallback_font
	var y := -78.0
	var title := "Reliquary" if not opened else ""
	if title != "":
		var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		draw_string_outline(f, Vector2(-w / 2, y - mods.size() * 15), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
		draw_string(f, Vector2(-w / 2, y - mods.size() * 15), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.7, 1.0))
		for i in mods.size():
			var m: Dictionary = MODS[mods[i]]
			var s := "%s: %s" % [m.label, m.desc]
			var w2 := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			var yy := y - (mods.size() - 1 - i) * 15 + 2
			draw_string_outline(f, Vector2(-w2 / 2, yy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
			draw_string(f, Vector2(-w2 / 2, yy), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, m.color)
		if _hold > 0.0:
			draw_arc(Vector2(0, -20), 46, -PI / 2, -PI / 2 + TAU * (_hold / HOLD), 40, Color(0.9, 0.7, 1.0), 4.0, true)
	if _fuse > 0.0:
		var k := 1.0 - _fuse / 3.0
		draw_arc(Vector2.ZERO, 240.0, 0, TAU, 64, Color(1.0, 0.5, 0.2, 0.3 + 0.5 * k), 3.0, true)
		draw_circle(Vector2.ZERO, 240.0 * k, Color(1.0, 0.45, 0.15, 0.12))
