class_name BloodAltar
extends Node2D
## Blood Altar (Ritual-style). Stand in the circle for a second to begin: monsters you killed
## in this zone rise again, empowered, in three waves. Every risen kill pays Tribute.
## When the rite ends three offerings appear; stand on a pedestal to buy one with Tribute.
## Unspent Tribute stays in your purse for the next altar.

const RADIUS := 360.0
const HOLD := 1.0
var state := "idle"     # idle | rite | offer | done
var wave := 0
var _hold := 0.0
var _t := 0.0
var _next := 0.0
var offers: Array = []  # [{kind, item?, cid?, n?, price, pos, bought, hold}]

func _ready() -> void:
	z_index = -2
	add_child(FX.make_light(Color(1.0, 0.25, 0.25), 320.0, 0.9))

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var g := Game.instance
	if g == null or g.player == null or g.player.dead:
		return
	var p := g.player
	var inside := p.global_position.distance_to(global_position) < RADIUS * 0.35
	match state:
		"idle":
			_hold = (_hold + delta) if inside else maxf(0.0, _hold - delta * 2.0)
			if _hold >= HOLD:
				_begin(g)
		"rite":
			if _alive(g) == 0:
				_next -= delta
				if _next <= 0.0:
					if wave >= 3:
						_end_rite(g)
					else:
						wave += 1
						_next = 1.2
						_spawn(g)
		"offer":
			for o in offers:
				if o.bought:
					continue
				var near: bool = p.global_position.distance_to(global_position + o.pos) < 46.0
				o.hold = (float(o.hold) + delta) if near else 0.0
				if o.hold >= 0.8:
					o.hold = 0.0
					_buy(g, o)

func _alive(g: Game) -> int:
	var n := 0
	for e in g.enemies:
		if e.has_meta("altar") and e.get_meta("altar") == self:
			n += 1
	return n

func _begin(g: Game) -> void:
	state = "rite"
	_next = 0.6
	g.hud.show_message("THE BLOOD ALTAR WAKES", "What you slew here rises again.")
	FX.ring(global_position, RADIUS, Color(1.0, 0.2, 0.2), 0.7, 12.0)
	FX.sound("portal", null, -2.0, 0.0)
	FX.shake(6.0)
	if g.bot:
		print("TEST blood altar begun")

func _spawn(g: Game) -> void:
	var pool: Array = g.recent_kills.duplicate()
	if pool.is_empty():
		pool = ["husk", "cinderling", "rattler"]
	var n := 4 + wave * 2
	for i in n:
		var id: String = pool[g.rng.randi() % pool.size()]
		if EnemiesDB.ENEMIES[id].get("rift", false) and id == "rift_lord":
			id = "rift_brute"
		var p := global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * g.rng.randf_range(RADIUS * 0.45, RADIUS * 0.9)
		if g.is_wall(p):
			p = global_position + Vector2.RIGHT.rotated(g.rng.randf() * TAU) * 100.0
		var rar := "rare" if i == 0 and wave == 3 else "magic"
		var e := g.spawn_enemy(id, g.area_level() + 1, rar, g._roll_mods(2 if rar == "rare" else 1), p)
		e.aggro = true
		e.set_meta("altar", self)
		e.set_meta("tribute", 20 if rar == "rare" else 6)
		FX.burst(p, Color(0.9, 0.15, 0.15), 16, 180.0, 7.0, 0.5)
	g.hud.show_message("RISEN %d / 3" % wave, "")

func _end_rite(g: Game) -> void:
	state = "offer"
	g.hud.show_message("THE RITE IS COMPLETE", "Stand on an offering to buy it with Tribute.")
	FX.sound("levelup", null, -4.0, 0.0)
	var lvl := g.area_level() + 2
	var rare := Loot.make_item(lvl, g.rng, "rare")
	offers.append({"kind": "item", "item": rare, "price": 70, "pos": Vector2(-120, 70), "bought": false, "hold": 0.0})
	if g.rng.randf() < 0.45:
		offers.append({"kind": "item", "item": Loot.make_item(lvl, g.rng, "unique"), "price": 200, "pos": Vector2(0, 110), "bought": false, "hold": 0.0})
	else:
		var keys: Array = CurrencyDB.ESSENCES.keys()
		var eid := CurrencyDB.essence_id(keys[g.rng.randi() % keys.size()], clampi(1 + g.depth / 3, 1, 4))
		offers.append({"kind": "cur", "cid": eid, "n": 1, "price": 90, "pos": Vector2(0, 110), "bought": false, "hold": 0.0})
	var cs: String = CurrencyDB.CRAFTING[g.rng.randi() % CurrencyDB.CRAFTING.size()]
	offers.append({"kind": "cur", "cid": cs, "n": 3, "price": 60, "pos": Vector2(120, 70), "bought": false, "hold": 0.0})
	if g.bot:
		print("TEST blood altar complete, tribute=%d" % int(g.player.currency.get("tribute", 0)))

func _buy(g: Game, o: Dictionary) -> void:
	var p := g.player
	var have := int(p.currency.get("tribute", 0))
	if have < int(o.price):
		FX.text(p.global_position, "Needs %d Tribute (have %d)" % [o.price, have], Color(1.0, 0.45, 0.4), 16)
		return
	p.currency["tribute"] = have - int(o.price)
	o.bought = true
	if o.kind == "item":
		g.drop_item(o.item, global_position + o.pos)
	else:
		g.drop_currency(o.cid, int(o.n), global_position + o.pos)
	FX.sound("drop_rare", null, -4.0, 0.0)
	if g.bot:
		print("TEST blood altar bought ", o.kind)

func _draw() -> void:
	var red := Color(0.85, 0.12, 0.12)
	var a := 0.25 if state == "idle" else 0.6
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 96, Color(red.r, red.g, red.b, a), 4.0, true)
	draw_circle(Vector2.ZERO, RADIUS * 0.35, Color(0.3, 0.02, 0.02, 0.35))
	for i in 7:
		var p := Vector2.RIGHT.rotated(i * TAU / 7.0 + _t * 0.2) * RADIUS * 0.35
		draw_line(p, Vector2.RIGHT.rotated((i + 3) * TAU / 7.0 + _t * 0.2) * RADIUS * 0.35, Color(red.r, red.g, red.b, 0.5), 2.0, true)
		draw_circle(p, 4.0, Color(1.0, 0.7, 0.3, 0.6 + 0.4 * sin(_t * 6.0 + i)))
	draw_rect(Rect2(-22, -40, 44, 40), Color(0.25, 0.05, 0.05))
	draw_rect(Rect2(-26, -46, 52, 8), Color(0.45, 0.1, 0.1))
	var f := ThemeDB.fallback_font
	var title := "Blood Altar" if state == "idle" else ("Blood Rite" if state == "rite" else "Offerings")
	var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string_outline(f, Vector2(-w / 2, -60), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(f, Vector2(-w / 2, -60), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.4, 0.35))
	if state == "idle" and _hold > 0.0:
		draw_arc(Vector2(0, -20), 52, -PI / 2, -PI / 2 + TAU * _hold / HOLD, 40, Color(1.0, 0.4, 0.35), 4.0, true)
	if state == "offer":
		var g := Game.instance
		var have := int(g.player.currency.get("tribute", 0)) if g and g.player else 0
		for o in offers:
			var c := Color(0.5, 0.5, 0.5) if o.bought else (Color(1.0, 0.85, 0.4) if have >= int(o.price) else Color(0.8, 0.35, 0.3))
			draw_circle(o.pos, 30.0, Color(0.2, 0.04, 0.04, 0.8))
			draw_arc(o.pos, 30.0, 0, TAU, 32, c, 2.0, true)
			if o.hold > 0.0:
				draw_arc(o.pos, 36.0, -PI / 2, -PI / 2 + TAU * o.hold / 0.8, 32, Color(1, 1, 1), 3.0, true)
			var label: String = "taken" if o.bought else ((o.item.name if o.kind == "item" else "%dx %s" % [o.n, CurrencyDB.info(o.cid).name]) + "  ·  %d Tribute" % o.price)
			var lc: Color = o.item.color() if o.kind == "item" and not o.bought else c
			var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
			draw_string_outline(f, o.pos + Vector2(-lw / 2, 50), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 4, Color.BLACK)
			draw_string(f, o.pos + Vector2(-lw / 2, 50), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, lc)
