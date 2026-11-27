class_name InventoryUI
extends Control
## Inventory, equipment paper-doll, character sheet and item tooltips with comparison.

const PANEL_W := 540.0
const PANEL_H := 740.0
const CELL := 60.0
const COLS := 8
const SLOT_RECTS := {
	"weapon": Rect2(36, 70, 80, 150),
	"helm": Rect2(230, 60, 80, 80),
	"amulet": Rect2(335, 80, 50, 50),
	"body": Rect2(220, 150, 100, 140),
	"ring1": Rect2(150, 205, 50, 50),
	"ring2": Rect2(345, 205, 50, 50),
	"gloves": Rect2(100, 270, 80, 80),
	"boots": Rect2(360, 270, 80, 80),
}
const BAG_ORIGIN := Vector2(30, 385)

var _summary := {}
var _hover_item: Item = null
var _hover_slot := ""
var _hover_bag := -1
var _compare_cache := {}
var _shatter_idx := -1
var _purse_rects := {}     # currency id -> Rect2
var craft_sel := ""         # currency held on the cursor
var _shop_rects := []       # [Rect2, kind, index]
var filter_open := false     # left panel shows the loot filter
var stash_tab := 0
var _hover_stash := -1
var _npc_rects := []          # [Rect2, action, value]
var _salvage_pending := ""
var _salvage_t := 0

const RARITY_ORDER := ["normal", "magic", "rare", "unique"]

## What the left-hand panel shows: shop / stash / salvage / filter / sheet.
func npc_mode() -> String:
	var g := Game.instance
	if g == null or g.player == null:
		return ""
	if filter_open:
		return "filter"
	if shop_open():
		return "shop"
	if g.town_npc("stash"):
		return "stash"
	if g.town_npc("salvager"):
		return "salvage"
	return ""

func _filter_btn() -> Rect2:
	return Rect2(panel_rect().position + Vector2(PANEL_W - 140, 16), Vector2(124, 30))

func _stash_rect(i: int) -> Rect2:
	var sr := sheet_rect()
	return Rect2(sr.position.x + 10 + (i % 8) * 40, sr.position.y + 92 + (i / 8) * 40, 37, 37)

func shop_open() -> bool:
	var g := Game.instance
	return g != null and g.peddler != null and is_instance_valid(g.peddler) and g.peddler.near(g.player)

func _shop_item_rect(i: int) -> Rect2:
	var sr := sheet_rect()
	return Rect2(sr.position.x + 24 + (i % 3) * 104, sr.position.y + 60 + (i / 3) * 96, 64, 64)
var _shatter_t := 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func toggle() -> void:
	visible = not visible
	craft_sel = ""
	if visible:
		refresh()

func refresh() -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	_summary = g.player.summary(g.player.equipment)
	_compare_cache.clear()
	queue_redraw()

func panel_rect() -> Rect2:
	var vs := get_viewport_rect().size
	return Rect2(vs.x - PANEL_W - 20, 70, PANEL_W, PANEL_H)

func sheet_rect() -> Rect2:
	return Rect2(20, 90, 340, 460)

func mouse_over_panel() -> bool:
	var m := Game.pointer()
	return panel_rect().has_point(m) or sheet_rect().has_point(m) or Rect2(sheet_rect().position.x, sheet_rect().end.y, sheet_rect().size.x, 330).has_point(m)

func _bag_rect(i: int) -> Rect2:
	var p := panel_rect().position + BAG_ORIGIN
	return Rect2(p.x + (i % COLS) * CELL, p.y + (i / COLS) * CELL, CELL - 4, CELL - 4)

func _slot_rect(slot: String) -> Rect2:
	var r: Rect2 = SLOT_RECTS[slot]
	return Rect2(panel_rect().position + r.position, r.size)

func _process(_delta: float) -> void:
	if not visible:
		return
	var m := Game.pointer()
	var g := Game.instance
	_hover_item = null
	_hover_slot = ""
	_hover_bag = -1
	if g and g.player:
		for i in Player.INV_SIZE:
			if _bag_rect(i).has_point(m):
				_hover_bag = i
				_hover_item = g.player.inventory[i]
		_hover_stash = -1
		if npc_mode() == "stash":
			for i in Game.STASH_SLOTS:
				if _stash_rect(i).has_point(m):
					_hover_stash = i
					_hover_item = g.stash[stash_tab * Game.STASH_SLOTS + i]
		if shop_open() and not filter_open:
			var st: Array = g.peddler.stock
			for i in st.size():
				if st[i] and _shop_item_rect(i).has_point(m):
					_hover_item = st[i]
		for s in SLOT_RECTS:
			if _slot_rect(s).has_point(m):
				_hover_slot = s
				_hover_item = g.player.equipment.get(s)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed:
		if not mouse_over_panel():
			return
		get_viewport().set_input_as_handled()
		var p := Game.instance.player
		var mpos := Game.pointer()
		if event.button_index == MOUSE_BUTTON_RIGHT and craft_sel != "":
			craft_sel = ""
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			for cid in _purse_rects:
				if _purse_rects[cid].has_point(mpos) and cid == "rift_heart":
					toggle()
					Game.instance.open_rift_heart()
					return
				if _purse_rects[cid].has_point(mpos) and CurrencyDB.is_crafting(cid):
					craft_sel = "" if craft_sel == cid else cid
					return
			if craft_sel != "":
				_try_craft(p)
				return
			if _filter_btn().has_point(mpos):
				filter_open = not filter_open
				return
			for e in _npc_rects:
				if e[0].has_point(mpos):
					_npc_action(p, e[1], e[2])
					return
			var mode := npc_mode()
			if mode == "shop" and _shop_click(p, mpos):
				return
			if mode == "stash" and _hover_stash >= 0:
				var si := stash_tab * Game.STASH_SLOTS + _hover_stash
				var sit: Item = Game.instance.stash[si]
				if sit and p.add_to_inventory(sit):
					Game.instance.stash[si] = null
					refresh()
				elif sit:
					FX.text(p.global_position, "Bag is full", Color(1.0, 0.5, 0.4), 16)
				return
			if mode == "stash" and _hover_bag >= 0 and p.inventory[_hover_bag]:
				if _to_stash(p.inventory[_hover_bag]):
					p.inventory[_hover_bag] = null
					refresh()
				else:
					FX.text(p.global_position, "Stash is full", Color(1.0, 0.5, 0.4), 16)
				return
			if _hover_bag >= 0 and p.inventory[_hover_bag]:
				p.equip_from_bag(_hover_bag)
				refresh()
			elif _hover_slot != "" and p.equipment.get(_hover_slot):
				p.unequip(_hover_slot)
				refresh()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if _hover_bag >= 0 and p.inventory[_hover_bag]:
				var now := Time.get_ticks_msec()
				if _shatter_idx == _hover_bag and now - _shatter_t < 2000:
					var it: Item = p.inventory[_hover_bag]
					p.inventory[_hover_bag] = null
					FX.text(p.global_position, "Shattered " + it.name, Color(0.7, 0.7, 0.7), 16)
					p.add_currency("ash_dust", {"normal": 1, "magic": 3, "rare": 8, "unique": 20}.get(it.rarity, 1))
					if shop_open():
						p.add_currency("ember_shards", Peddler.sell_value(it))
						FX.text(p.global_position + Vector2(0, -24), "+%d shards" % Peddler.sell_value(it), Color(1.0, 0.78, 0.3), 16)
					FX.sound("die", null, -6.0)
					_shatter_idx = -1
					refresh()
				else:
					_shatter_idx = _hover_bag
					_shatter_t = now

func _try_craft(p: Player) -> void:
	var it: Item = _hover_item
	if it == null:
		return
	if int(p.currency.get(craft_sel, 0)) <= 0:
		craft_sel = ""
		return
	var why := Crafting.apply(craft_sel, it, Game.instance.rng)
	if why != "":
		FX.text(p.global_position, why, Color(1.0, 0.5, 0.4), 16)
		FX.sound("hurt", null, -14.0, 0.0)
		return
	p.currency[craft_sel] -= 1
	FX.text(p.global_position, CurrencyDB.info(craft_sel).name + ": " + it.name, CurrencyDB.info(craft_sel).color, 18)
	FX.sound("drop_rare", null, -8.0, 0.1)
	if int(p.currency[craft_sel]) <= 0:
		craft_sel = ""
	p.recalc_stats()
	_compare_cache.clear()
	refresh()
	Game.instance.save_game()

func _draw() -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	var p := g.player
	var f := ThemeDB.fallback_font
	var pr := panel_rect()
	_box(pr)
	_t(f, pr.position + Vector2(PANEL_W / 2, 36), "INVENTORY", 22, Color(1.0, 0.82, 0.45), true)
	for s in SLOT_RECTS:
		var r := _slot_rect(s)
		var it: Item = p.equipment.get(s)
		_cell(r, it, s == _hover_slot)
		if it == null:
			_t(f, r.get_center() + Vector2(0, 5), ItemsDB.SLOT_NAMES[s], 12, Color(0.4, 0.38, 0.36), true)
	for i in Player.INV_SIZE:
		_cell(_bag_rect(i), p.inventory[i], i == _hover_bag)
	var hint := "A: equip / unequip   ·   X twice: shatter   ·   B: close" if PlayerInput.using_pad else "Click: equip / unequip   ·   Right-click twice: shatter"
	_t(f, pr.position + Vector2(PANEL_W / 2, PANEL_H - 22), hint, 13, Color(0.55, 0.53, 0.5), true)
	if _shatter_idx >= 0 and Time.get_ticks_msec() - _shatter_t < 2000:
		var sr0 := _bag_rect(_shatter_idx)
		draw_rect(sr0.grow(3), Color(1.0, 0.3, 0.2), false, 3.0)
		_t(f, sr0.position + Vector2(sr0.size.x / 2, -6), "Again to shatter", 13, Color(1.0, 0.45, 0.35), true)
	# Character sheet / shop
	var sr := sheet_rect()
	_box(sr)
	_npc_rects.clear()
	match npc_mode():
		"shop": _draw_shop(p, sr, f)
		"stash": _draw_stash(p, sr, f)
		"salvage": _draw_salvage(p, sr, f)
		"filter": _draw_filter(sr, f)
		_: _draw_sheet(sr, f)
	var fb := _filter_btn()
	draw_rect(fb, Color(0.18, 0.14, 0.09) if filter_open or fb.has_point(Game.pointer()) else Color(0.09, 0.08, 0.07))
	draw_rect(fb, Color(1.0, 0.75, 0.4), false, 1.5)
	_t(f, fb.get_center() + Vector2(0, 5), "Loot Filter" + (" ✓" if filter_open else ""), 13, Color(1.0, 0.85, 0.55), true)
	_draw_purse(p, sr, f)
	if _hover_item:
		_tooltip(_hover_item)
	if craft_sel != "":
		var mp2 := Game.pointer()
		var cc2: Color = CurrencyDB.info(craft_sel).color
		draw_colored_polygon(PackedVector2Array([mp2 + Vector2(14, 4), mp2 + Vector2(21, 12), mp2 + Vector2(14, 20), mp2 + Vector2(7, 12)]), cc2)
	if PlayerInput.using_pad:
		var mp := Game.pointer()
		draw_circle(mp, 9, Color(1.0, 0.82, 0.45, 0.35))
		draw_arc(mp, 9, 0, TAU, 20, Color(1.0, 0.82, 0.45), 2.0, true)


func _draw_sheet(sr: Rect2, f: Font) -> void:
	_t(f, sr.position + Vector2(20, 34), "THE KINDLED  ·  Level %d" % Game.instance.player.level, 18, Color(1.0, 0.82, 0.45), false)
	var y := sr.position.y + 66
	for k in _summary:
		var v: float = _summary[k]
		var txt := _fmt(k, v)
		var col := Color(0.85, 0.82, 0.78)
		if k.ends_with("DPS"):
			col = Color(1.0, 0.7, 0.4)
		_t(f, Vector2(sr.position.x + 20, y), k, 15, Color(0.65, 0.62, 0.6), false)
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
		_t(f, Vector2(sr.end.x - 20 - w, y), txt, 15, col, false)
		y += 26

func _draw_shop(p: Player, sr: Rect2, f: Font) -> void:
	var pd: Peddler = Game.instance.peddler
	_t(f, sr.position + Vector2(20, 34), "ASHEN PEDDLER", 18, Color(1.0, 0.75, 0.4), false)
	_shop_rects.clear()
	var shards := int(p.currency.get("ember_shards", 0))
	for i in pd.stock.size():
		var r := _shop_item_rect(i)
		var it: Item = pd.stock[i]
		_cell(r, it, it != null and it == _hover_item)
		if it:
			var pr := Peddler.price(it)
			_t(f, r.position + Vector2(r.size.x / 2, r.size.y + 16), "%d shards" % pr, 12, Color(1.0, 0.78, 0.3) if shards >= pr else Color(0.6, 0.35, 0.3), true)
			_shop_rects.append([r, "item", i])
		else:
			_t(f, r.get_center() + Vector2(0, 5), "sold", 12, Color(0.4, 0.38, 0.36), true)
	var y := sr.position.y + 290
	_t(f, Vector2(sr.position.x + 20, y), "Trade Ash Dust", 14, Color(0.75, 0.72, 0.68), false)
	var dust := int(p.currency.get("ash_dust", 0))
	var mp := Game.pointer()
	for k in Peddler.OFFERS.size():
		var o: Dictionary = Peddler.OFFERS[k]
		var rr := Rect2(sr.position.x + 16, y + 10 + k * 26, sr.size.x - 32, 24)
		if rr.has_point(mp):
			draw_rect(rr, Color(1, 1, 1, 0.07))
		var cc: Color = CurrencyDB.info(o.id).color
		_t(f, rr.position + Vector2(8, 17), CurrencyDB.info(o.id).name, 13, cc, false)
		var cs := "%d dust" % o.dust
		_t(f, Vector2(rr.end.x - 8 - f.get_string_size(cs, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, rr.position.y + 17), cs, 13, Color(0.75, 0.73, 0.7) if dust >= o.dust else Color(0.5, 0.35, 0.3), false)
		_shop_rects.append([rr, "offer", k])
	_t(f, Vector2(sr.position.x + 20, sr.end.y - 14), "%s buys  ·  shatter here to sell" % ("A" if PlayerInput.using_pad else "Click"), 12, Color(0.6, 0.58, 0.55), false)

func _to_stash(it: Item) -> bool:
	var g := Game.instance
	var order: Array = []
	for t in Game.STASH_TABS:
		order.append((stash_tab + t) % Game.STASH_TABS)
	for t in order:
		for i in Game.STASH_SLOTS:
			if g.stash[t * Game.STASH_SLOTS + i] == null:
				g.stash[t * Game.STASH_SLOTS + i] = it
				return true
	return false

func _btn(r: Rect2, label: String, action: String, value, on: bool, f: Font, col: Color = Color(1.0, 0.85, 0.55)) -> void:
	_npc_rects.append([r, action, value])
	var hov := r.has_point(Game.pointer())
	draw_rect(r, Color(0.2, 0.15, 0.09) if on or hov else Color(0.08, 0.07, 0.07))
	draw_rect(r, col if on or hov else col.darkened(0.5), false, 2.0 if on else 1.0)
	_t(f, r.position + Vector2(10, r.size.y / 2 + 5), label, 14, col if on or hov else Color(0.7, 0.68, 0.64), false)

func _draw_stash(_p: Player, sr: Rect2, f: Font) -> void:
	var g := Game.instance
	_t(f, sr.position + Vector2(20, 34), "EMBER VAULT", 18, Color(1.0, 0.82, 0.45), false)
	for t in Game.STASH_TABS:
		var n := 0
		for i in Game.STASH_SLOTS:
			if g.stash[t * Game.STASH_SLOTS + i]:
				n += 1
		_btn(Rect2(sr.position.x + 10 + t * 108, sr.position.y + 48, 102, 34), "Tab %d  (%d)" % [t + 1, n], "tab", t, t == stash_tab, f)
	for i in Game.STASH_SLOTS:
		var it: Item = g.stash[stash_tab * Game.STASH_SLOTS + i]
		_cell(_stash_rect(i), it, i == _hover_stash)
	_t(f, Vector2(sr.position.x + 20, sr.end.y - 40), ("A" if PlayerInput.using_pad else "Click") + " a stash item: to your bag", 12, Color(0.6, 0.58, 0.55), false)
	_t(f, Vector2(sr.position.x + 20, sr.end.y - 20), ("A" if PlayerInput.using_pad else "Click") + " a bag item: into the stash", 12, Color(0.6, 0.58, 0.55), false)

func _salvage_count(p: Player, upto: String) -> int:
	var lim := RARITY_ORDER.find(upto)
	var n := 0
	for it in p.inventory:
		if it and RARITY_ORDER.find(it.rarity) <= lim:
			n += 1
	return n

func _draw_salvage(p: Player, sr: Rect2, f: Font) -> void:
	_t(f, sr.position + Vector2(20, 34), "GRIMM THE SMELTER", 18, Color(1.0, 0.82, 0.45), false)
	_t(f, sr.position + Vector2(20, 58), "Melts gear in your bag into Ash Dust.", 13, Color(0.7, 0.68, 0.64), false)
	_t(f, sr.position + Vector2(20, 76), "Equipped items and the stash are safe.", 13, Color(0.7, 0.68, 0.64), false)
	var labels := {"normal": "Common", "magic": "Magic and below", "rare": "Rare and below", "unique": "Everything (incl. Unique)"}
	var y := sr.position.y + 100
	for r in RARITY_ORDER:
		var n := _salvage_count(p, r)
		var pend: bool = _salvage_pending == r and Time.get_ticks_msec() - _salvage_t < 3000
		var lab: String = ("PRESS AGAIN: melt %d items" % n) if pend else ("%s   (%d)" % [labels[r], n])
		_btn(Rect2(sr.position.x + 14, y, sr.size.x - 28, 46), lab, "salvage", r, pend, f, Color(1.0, 0.5, 0.35) if pend else Item.RARITY_COLORS[r])
		y += 56
	_t(f, Vector2(sr.position.x + 20, sr.end.y - 20), "Two presses to confirm.", 12, Color(0.6, 0.58, 0.55), false)

func _draw_filter(sr: Rect2, f: Font) -> void:
	var lf: Dictionary = Game.instance.loot_filter
	_t(f, sr.position + Vector2(20, 34), "LOOT FILTER", 18, Color(1.0, 0.82, 0.45), false)
	_t(f, sr.position + Vector2(20, 56), "Hidden drops stay invisible and aren't picked up.", 12, Color(0.7, 0.68, 0.64), false)
	var y := sr.position.y + 72
	for r in LootFilter.RARITIES:
		_btn(Rect2(sr.position.x + 14, y, sr.size.x - 28, 34), ("☑ " if lf.get(r, true) else "☐ ") + "Show " + LootFilter.RARITY_NAMES[r], "filter", r, bool(lf.get(r, true)), f, Item.RARITY_COLORS[r])
		y += 40
	y += 8
	for c in LootFilter.CATEGORIES:
		_btn(Rect2(sr.position.x + 14, y, sr.size.x - 28, 34), ("☑ " if lf.get(c, true) else "☐ ") + LootFilter.CATEGORY_NAMES[c], "filter", c, bool(lf.get(c, true)), f)
		y += 40
	y += 8
	_btn(Rect2(sr.position.x + 14, y, sr.size.x - 28, 34), ("☑ " if lf.get("show_hidden", false) else "☐ ") + "Show hidden drops (dimmed)", "filter", "show_hidden", bool(lf.get("show_hidden", false)), f)
	_t(f, Vector2(sr.position.x + 20, sr.end.y - 20), "Uniques ignore the category toggles.", 12, Color(0.6, 0.58, 0.55), false)

func _npc_action(p: Player, action: String, value) -> void:
	var g := Game.instance
	match action:
		"tab":
			stash_tab = int(value)
		"filter":
			g.loot_filter[value] = not bool(g.loot_filter.get(value, true))
			g.save_game()
		"salvage":
			var now := Time.get_ticks_msec()
			if _salvage_pending == value and now - _salvage_t < 3000:
				var lim := RARITY_ORDER.find(value)
				var n := 0
				var dust := 0
				for i in p.inventory.size():
					var it: Item = p.inventory[i]
					if it and RARITY_ORDER.find(it.rarity) <= lim:
						dust += {"normal": 1, "magic": 3, "rare": 8, "unique": 20}.get(it.rarity, 1)
						p.inventory[i] = null
						n += 1
				if dust > 0:
					p.add_currency("ash_dust", dust)
				FX.text(p.global_position, "Melted %d items  (+%d Ash Dust)" % [n, dust], Color(1.0, 0.6, 0.35), 18)
				FX.sound("die", null, -4.0)
				_salvage_pending = ""
				refresh()
				g.save_game()
			else:
				_salvage_pending = value
				_salvage_t = now

func _shop_click(p: Player, mpos: Vector2) -> bool:
	var pd: Peddler = Game.instance.peddler
	for e in _shop_rects:
		if not e[0].has_point(mpos):
			continue
		if e[1] == "item":
			var it: Item = pd.stock[e[2]]
			var pr := Peddler.price(it)
			if int(p.currency.get("ember_shards", 0)) < pr:
				FX.text(p.global_position, "Not enough shards", Color(1.0, 0.5, 0.4), 16)
			elif not p.add_to_inventory(it):
				FX.text(p.global_position, "Bag is full", Color(1.0, 0.5, 0.4), 16)
			else:
				p.currency.ember_shards -= pr
				pd.stock[e[2]] = null
				FX.sound("pickup", null, -6.0, 0.0)
				refresh()
		else:
			var o: Dictionary = Peddler.OFFERS[e[2]]
			if int(p.currency.get("ash_dust", 0)) < o.dust:
				FX.text(p.global_position, "Not enough Ash Dust", Color(1.0, 0.5, 0.4), 16)
			else:
				p.currency.ash_dust -= o.dust
				p.add_currency(o.id, 1)
				FX.sound("pickup", null, -6.0, 0.0)
		return true
	return false

func _draw_purse(p: Player, sr: Rect2, f: Font) -> void:
	# Currency purse
	var cy := sr.end.y + 30
	var nrows := (CurrencyDB.ordered(p.currency).size() + 1) / 2
	_box(Rect2(sr.position.x, sr.end.y + 10, sr.size.x, maxf(196.0, 70.0 + nrows * 21)))
	_t(f, Vector2(sr.position.x + 20, cy + 10), "PURSE", 16, Color(1.0, 0.82, 0.45), false)
	var row := 0
	_purse_rects.clear()
	var colw := (sr.size.x - 30) / 2.0
	for cid in CurrencyDB.ordered(p.currency):
		var n := int(p.currency.get(cid, 0))
		var cc: Color = CurrencyDB.info(cid).color
		var x0 := sr.position.x + 15 + (row % 2) * colw
		var yy := cy + 38 + (row / 2) * 21
		var rr := Rect2(x0, yy - 15, colw - 6, 20)
		_purse_rects[cid] = rr
		var craftable: bool = CurrencyDB.is_crafting(cid) or cid == "rift_heart"
		if craft_sel == cid:
			draw_rect(rr, Color(cc.r, cc.g, cc.b, 0.25))
			draw_rect(rr, cc, false, 2.0)
		elif craftable and rr.has_point(Game.pointer()):
			draw_rect(rr, Color(1, 1, 1, 0.06))
		draw_circle(Vector2(x0 + 10, yy - 5), 5, cc)
		var nm: String = CurrencyDB.info(cid).name
		if cid.begins_with("ess_"):
			var pe := CurrencyDB.parse_essence(cid)
			nm = "%s %s" % [CurrencyDB.ESSENCE_TIERS[pe[1] - 1].substr(0, 5) + ".", CurrencyDB.ESSENCES[pe[0]].name.trim_prefix("the ")]
		_t(f, Vector2(x0 + 20, yy), nm, 12, cc, false)
		var ns := str(n)
		_t(f, Vector2(rr.end.x - 6 - f.get_string_size(ns, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, yy), ns, 13, Color(0.9, 0.9, 0.9), false)
		row += 1
	var hint2 := ""
	if craft_sel != "":
		hint2 = "%s: %s  ·  %s cancels" % [CurrencyDB.info(craft_sel).name, CurrencyDB.info(craft_sel).desc, "B" if PlayerInput.using_pad else "Right-click"]
	else:
		hint2 = "%s a crafting currency, then an item" % ("A on" if PlayerInput.using_pad else "Click")
		if int(p.currency.get("rift_heart", 0)) > 0:
			hint2 = "Select the Rift Heart to face the Rift Lord"
	_t(f, Vector2(sr.position.x + 20, maxf(sr.end.y + 192, cy + 50 + nrows * 21)), hint2, 12, Color(0.6, 0.58, 0.55), false)

func _fmt(k: String, v: float) -> String:
	if k.ends_with("Res"):
		return "%d%%" % int(v)
	if k == "Move Speed":
		return "%d%%" % int(round(v))
	if k.ends_with("DPS"):
		return "%.1f" % v
	return "%d" % int(round(v))

func _box(r: Rect2) -> void:
	draw_rect(r, Color(0.04, 0.035, 0.05, 0.94))
	draw_rect(r, Color(0.6, 0.42, 0.22), false, 2.0)
	draw_rect(r.grow(-6), Color(0.35, 0.25, 0.14, 0.6), false, 1.0)

func _cell(r: Rect2, it: Item, hover: bool) -> void:
	draw_rect(r, Color(0.08, 0.075, 0.09))
	if it:
		var c := it.color()
		draw_rect(r, Color(c.r, c.g, c.b, 0.12))
		_icon(r, it)
		if it.req_level() > Game.instance.player.level:
			draw_rect(r, Color(0.6, 0.05, 0.05, 0.35))
		draw_rect(r, c.darkened(0.2), false, 2.0)
	else:
		draw_rect(r, Color(0.22, 0.2, 0.2), false, 1.0)
	if hover:
		draw_rect(r.grow(2), Color(1, 0.9, 0.6), false, 2.0)

func _icon(r: Rect2, it: Item) -> void:
	var c := it.color()
	var m := r.get_center()
	var s := minf(r.size.x, r.size.y) * 0.32
	if it.slot_group() == "weapon":
		var wid: String = it.unique_id if Art.WEAPON_SPRITES.has(it.unique_id) else it.base_id
		var name: String = Art.WEAPON_SPRITES.get(wid, "weapon_rusty_sword")
		var sz := Art.size_of(name)
		var k := minf((r.size.x - 10) / sz.x, (r.size.y - 10) / sz.y)
		k = floorf(k) if k >= 3.0 else k
		var dr := Rect2(m - sz * k / 2.0, sz * k)
		draw_texture_rect(Art.tex(name), dr, false)
		return
	match it.slot_group():
		"weapon":
			var wand := it.base_id.contains("wand")
			var maul := it.base_id.contains("maul")
			draw_line(m + Vector2(-s, s * 1.6), m + Vector2(s * 0.6, -s * 1.6), Color(0.8, 0.78, 0.74), 4.0 if not maul else 6.0, true)
			if wand:
				draw_circle(m + Vector2(s * 0.6, -s * 1.6), 6, c)
			elif maul:
				draw_rect(Rect2(m + Vector2(s * 0.1, -s * 2.1), Vector2(s * 1.1, s * 0.9)), c.darkened(0.3))
			else:
				draw_line(m + Vector2(-s * 0.9, s * 0.6), m + Vector2(s * 0.1, s * 1.0), c, 4.0)
		"helm":
			draw_arc(m + Vector2(0, s * 0.3), s, PI, TAU, 16, c, 5.0, true)
			draw_line(m + Vector2(-s, s * 0.3), m + Vector2(s, s * 0.3), c, 4.0)
		"body":
			draw_rect(Rect2(m - Vector2(s * 0.8, s * 1.1), Vector2(s * 1.6, s * 2.2)), c.darkened(0.4))
			draw_rect(Rect2(m - Vector2(s * 0.8, s * 1.1), Vector2(s * 1.6, s * 2.2)), c, false, 2.0)
		"gloves":
			draw_rect(Rect2(m - Vector2(s * 0.6, s * 0.5), Vector2(s * 1.2, s * 1.3)), c.darkened(0.3))
			for i in 4:
				draw_line(m + Vector2(-s * 0.5 + i * s * 0.33, -s * 0.5), m + Vector2(-s * 0.5 + i * s * 0.33, -s * 1.1), c, 3.0)
		"boots":
			draw_rect(Rect2(m - Vector2(s * 0.4, s * 1.0), Vector2(s * 0.7, s * 1.5)), c.darkened(0.3))
			draw_rect(Rect2(m + Vector2(-s * 0.4, s * 0.3), Vector2(s * 1.3, s * 0.5)), c.darkened(0.3))
		"ring":
			draw_arc(m, s * 0.8, 0, TAU, 24, c, 4.0, true)
			draw_circle(m + Vector2(0, -s * 0.8), 4, Color.WHITE)
		"amulet":
			draw_arc(m + Vector2(0, -s * 0.4), s * 0.9, 0.2, PI - 0.2, 16, Color(0.7, 0.65, 0.5), 2.0, true)
			draw_circle(m + Vector2(0, s * 0.5), s * 0.45, c)

func _tooltip(it: Item) -> void:
	var f := ThemeDB.fallback_font
	var lines: Array = it.tooltip_lines()
	# Comparison with what is equipped in that slot (bag items only)
	if _hover_bag >= 0:
		var deltas := _compare(it)
		if deltas.size() > 0:
			lines.append(["────────", Color(0.4, 0.4, 0.45)])
			lines.append(["If equipped:", Color(0.7, 0.7, 0.7)])
			for d in deltas:
				lines.append(d)
		if it.req_level() > Game.instance.player.level:
			lines.append(["Requires Level %d" % it.req_level(), Color(1, 0.35, 0.35)])
	var w := 0.0
	for l in lines:
		w = maxf(w, f.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	w += 30
	var h := lines.size() * 21 + 20
	var m := Game.pointer()
	var pos := m + Vector2(-w - 18, 10)
	if pos.x < 10:
		pos.x = m.x + 18
	var vs := get_viewport_rect().size
	pos.y = clampf(pos.y, 10, vs.y - h - 10)
	var r := Rect2(pos, Vector2(w, h))
	draw_rect(r, Color(0.03, 0.025, 0.035, 0.97))
	draw_rect(r, it.color().darkened(0.2), false, 2.0)
	var y := pos.y + 26
	for i in lines.size():
		var l: Array = lines[i]
		var size := 18 if i == 0 else 15
		var tw := f.get_string_size(l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		draw_string(f, Vector2(pos.x + w / 2 - tw / 2, y), l[0], HORIZONTAL_ALIGNMENT_LEFT, -1, size, l[1])
		y += 21

func _compare(it: Item) -> Array:
	if _compare_cache.has(it):
		return _compare_cache[it]
	var p := Game.instance.player
	var eq: Dictionary = p.equipment.duplicate()
	eq[p.target_slot_for(it)] = it
	var after := p.summary(eq)
	var out: Array = []
	for k in after:
		var a: float = after[k]
		var b: float = _summary.get(k, 0.0)
		var d := a - b
		var thresh := 0.05 if k.ends_with("DPS") else 0.5
		if absf(d) < thresh:
			continue
		var txt := ""
		if k.ends_with("DPS"):
			var pct := (d / maxf(0.01, b)) * 100.0
			txt = "%s %+.1f  (%+d%%)" % [k, d, int(round(pct))]
		else:
			txt = "%s %+d" % [k, int(round(d))]
		out.append([txt, Color(0.4, 1.0, 0.5) if d > 0 else Color(1.0, 0.4, 0.4)])
	_compare_cache[it] = out
	return out

func _t(f: Font, pos: Vector2, s: String, size: int, c: Color, centered: bool) -> void:
	var x := pos.x
	if centered:
		x -= f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2
	draw_string(f, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
