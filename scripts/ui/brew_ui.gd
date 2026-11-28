class_name BrewUI
extends Control
## The Herbalist's Kettle: brew from gathered herbs. Every recipe shows its cost, what you have,
## and exactly what it does before you brew. Pad: D-pad / stick up-down to choose, A brew, B close.
## Mouse: click a recipe to brew it, right-click or Esc to close.

var sel := 0
var _rects: Array = []
var _t := 0.0
var _stick_cd := 0.0
var _msg := ""
var _msg_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func open() -> void:
	visible = true
	_t = 0.0
	sel = clampi(sel, 0, BrewingDB.RECIPES.size() - 1)
	get_tree().paused = true

func close() -> void:
	visible = false
	get_tree().paused = false

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_msg_t -= delta
	_stick_cd -= delta
	var n := BrewingDB.RECIPES.size()
	if Input.is_action_just_pressed("ui_down") or (_stick_cd <= 0.0 and Input.get_axis("move_up", "move_down") > 0.6):
		sel = (sel + 1) % n
		_stick_cd = 0.22
	elif Input.is_action_just_pressed("ui_up") or (_stick_cd <= 0.0 and Input.get_axis("move_up", "move_down") < -0.6):
		sel = (sel - 1 + n) % n
		_stick_cd = 0.22
	if _t > 0.2 and (Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("pad_click")):
		brew(sel)
	elif Input.is_action_just_pressed("pad_close") or Input.is_action_just_pressed("ui_cancel"):
		close()
	var m := Game.pointer()
	for i in _rects.size():
		if _rects[i].has_point(m) and not PlayerInput.using_pad:
			sel = i
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventMouseButton and event.pressed):
		return
	get_viewport().set_input_as_handled()
	if event.button_index == MOUSE_BUTTON_RIGHT:
		close()
	elif event.button_index == MOUSE_BUTTON_LEFT:
		for i in _rects.size():
			if _rects[i].has_point(Game.pointer()):
				brew(i)

## Brew recipe i if you can. Returns true when brewed.
func brew(i: int) -> bool:
	var p := Game.instance.player
	var r: Dictionary = BrewingDB.RECIPES[i]
	var rank := int(p.brews.get(r.id, 0))
	if r.kind != "tonic" and rank >= int(r.ranks):
		_say("Already at its best.")
		return false
	var cost := BrewingDB.cost_of(r, rank)
	if not BrewingDB.can_afford(p, cost):
		_say("Not enough herbs: needs %s." % BrewingDB.cost_text(cost))
		FX.sound("hurt", null, -14.0, 0.0)
		return false
	for h in cost:
		p.currency[h] = int(p.currency[h]) - int(cost[h])
	if r.kind == "tonic":
		p.tonic_id = r.id
		p.tonic_t = BrewingDB.TONIC_TIME
	else:
		p.brews[r.id] = rank + 1
	p.recalc_stats()
	FX.sound("levelup", null, -8.0, 0.0)
	_say("Brewed %s." % r.name)
	return true

func _say(s: String) -> void:
	_msg = s
	_msg_t = 2.5

func _txt(f: Font, pos: Vector2, s: String, size: int, c: Color, center: bool = false) -> void:
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var at := pos - Vector2(w / 2 if center else 0.0, 0)
	draw_string_outline(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.9))
	draw_string(f, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)

func _draw() -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	var p := g.player
	var f := ThemeDB.fallback_font
	var vs := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, vs), Color(0, 0, 0, 0.7))
	var pw := minf(820.0, vs.x - 80.0)
	var pr := Rect2(vs.x / 2 - pw / 2, 90, pw, vs.y - 170)
	draw_rect(pr, Color(0.08, 0.07, 0.06, 0.97))
	draw_rect(pr, Color(0.55, 0.75, 0.4), false, 2.0)
	_txt(f, Vector2(vs.x / 2, pr.position.y + 40), "THE HERBALIST'S KETTLE", 28, Color(0.7, 0.95, 0.55), true)
	# herbs you have, with where they grow
	var hx := pr.position.x + 30
	var hy := pr.position.y + 78
	for hid in BrewingDB.HERBS:
		var h: Dictionary = BrewingDB.HERBS[hid]
		_txt(f, Vector2(hx, hy), "%s  %d" % [h.name, int(p.currency.get(hid, 0))], 17, h.color)
		_txt(f, Vector2(hx, hy + 18), ChapterDB.REGIONS[int(h.region)].name, 12, Color(0.6, 0.58, 0.55))
		hx += pw / 3.0
	_rects.clear()
	var y := pr.position.y + 112
	var rh := 80.0
	for i in BrewingDB.RECIPES.size():
		var r: Dictionary = BrewingDB.RECIPES[i]
		var rank := int(p.brews.get(r.id, 0))
		var done: bool = r.kind != "tonic" and rank >= int(r.ranks)
		var cost := BrewingDB.cost_of(r, rank)
		var ok := not done and BrewingDB.can_afford(p, cost)
		var rr := Rect2(pr.position.x + 20, y, pw - 40, rh - 6)
		_rects.append(rr)
		var on := i == sel
		draw_rect(rr, Color(0.2, 0.17, 0.1) if on else Color(0.12, 0.1, 0.08))
		draw_rect(rr, Color(0.9, 0.8, 0.45) if on else Color(0.35, 0.3, 0.22), false, 2.0 if on else 1.0)
		var title: String = r.name
		if r.kind != "tonic":
			title += "   (%d / %d)" % [rank, int(r.ranks)]
		elif p.tonic_id == r.id and p.tonic_t > 0.0:
			title += "   (active %d:%02d)" % [int(p.tonic_t) / 60, int(p.tonic_t) % 60]
		_txt(f, rr.position + Vector2(14, 24), title, 18, Color(1.0, 0.88, 0.55) if not done else Color(0.6, 0.6, 0.55))
		var kind_txt: String = {"upgrade": "Permanent", "tonic": "Tonic · one at a time", "philter": "Permanent · rare"}[r.kind]
		_txt(f, Vector2(rr.end.x - 14 - f.get_string_size(kind_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x, rr.position.y + 22), kind_txt, 13, Color(0.6, 0.75, 0.55))
		_txt(f, rr.position + Vector2(14, 46), r.desc, 14, Color(0.82, 0.8, 0.75))
		var ct := "Done" if done else "Needs " + BrewingDB.cost_text(cost)
		_txt(f, rr.position + Vector2(14, 66), ct, 14, Color(0.55, 0.9, 0.5) if ok else Color(0.85, 0.45, 0.35))
		y += rh
	if _msg_t > 0.0:
		_txt(f, Vector2(vs.x / 2, pr.end.y - 50), _msg, 18, Color(1.0, 0.9, 0.6), true)
	var hint := "D-pad: choose   A: brew   B: close" if PlayerInput.using_pad else "Click: brew   Right-click / Esc: close"
	_txt(f, Vector2(vs.x / 2, pr.end.y - 18), hint, 14, Color(0.65, 0.62, 0.58), true)
