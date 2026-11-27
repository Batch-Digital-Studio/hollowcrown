extends Node
## --menu-probe: blocking menus own the input.
## Holding move or a skill across opening/closing the inventory, pause menu, passive tree,
## class screen and world map must not move the hero, cast, or replay when the menu closes.
## A fresh press afterwards must work again. Controller: the left stick moves the menu
## cursor, not the hero.
var t := 0.0
var step := 0
var fails := 0
var checks := 0
var p0 := Vector2.ZERO
var serial0 := 0
var cur0 := Vector2.ZERO
var menus := ["inventory", "pause", "passives", "class", "world_map"]
var mi := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	FX.enabled = false

func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
	print("MENU %s: %s" % ["ok" if c else "FAIL", what])

func _open(g: Game, m: String) -> void:
	match m:
		"inventory": g.inv_ui.toggle()
		"pause": g.hud.toggle_pause()
		"passives": g.hud.passives.toggle()
		"class": g.hud.class_ui.toggle()
		"world_map": g.hud.show_world_map()

func _close(g: Game, m: String) -> void:
	match m:
		"inventory": g.inv_ui.toggle()
		"pause": g.hud.hide_overlays()
		"passives": g.hud.passives.toggle()
		"class": g.hud.class_ui.toggle()
		"world_map": g.hud.world_map.toggle()

func _is_open(g: Game, m: String) -> bool:
	match m:
		"inventory": return g.inv_ui.visible
		"passives": return g.hud.passives.visible
		"class": return g.hud.class_ui.visible
		"world_map": return g.hud.world_map.visible
	return get_tree().paused

func _process(delta: float) -> void:
	var g := Game.instance
	if g != null and g.state == "title":
		g.hud.hide_overlays()
		g.start_game(false, ClassesDB.class_def("magus").heroes[0], "magus")
		return
	if g == null or g.player == null or g.state != "play":
		return
	t += delta
	var p := g.player
	p.invulnerable = true
	var m: String = menus[mini(mi, menus.size() - 1)]
	match step:
		0:   # clear the area, start walking
			if t > 0.8:
				for e in g.enemies.duplicate():
					g.enemies.erase(e)
					e.queue_free()
				Input.action_press("move_right")
				t = 0.0
				step = 1
		1:   # mid-walk: open the menu while still holding move
			if t > 0.3:
				ok(p.velocity.length() > 50.0, "[%s] hero walking before the menu opens" % m)
				_open(g, m)
				Input.action_press("skill_1")      # click/attack while the menu is up
				serial0 = p.act_serial
				t = 0.0
				step = 2
		2:
			if t > 0.15 and p0 == Vector2.ZERO:
				p0 = p.global_position
			if t > 0.8:
				ok(_is_open(g, m), "[%s] menu is open" % m)
				ok(p.global_position.distance_to(p0) < 3.0, "[%s] hero stays put while held move + menu open (moved %.1f px)" % [m, p.global_position.distance_to(p0)])
				ok(p.act_serial == serial0, "[%s] no Rite fires from clicks while the menu is open" % m)
				_close(g, m)   # close while move and skill are still held
				p0 = p.global_position
				t = 0.0
				step = 3
		3:
			if t > 0.6:
				ok(not _is_open(g, m), "[%s] menu closed" % m)
				ok(p.global_position.distance_to(p0) < 3.0 and p.act_serial == serial0, "[%s] held input does not replay after closing (moved %.1f px)" % [m, p.global_position.distance_to(p0)])
				Input.action_release("move_right")
				Input.action_release("skill_1")
				t = 0.0
				step = 4
		4:
			if t > 0.2:
				p0 = p.global_position
				Input.action_press("move_left")   # a fresh deliberate input
				t = 0.0
				step = 5
		5:
			if t > 0.4:
				ok(p.global_position.distance_to(p0) > 40.0, "[%s] a fresh press moves the hero again" % m)
				Input.action_release("move_left")
				p0 = Vector2.ZERO
				mi += 1
				t = 0.0
				step = 0 if mi < menus.size() else 6
		6:   # controller: left stick in the inventory drives the cursor only
			if t > 0.3:
				PlayerInput.using_pad = true
				g.inv_ui.toggle()
				cur0 = g.pad_cursor
				p0 = p.global_position
				var e := InputEventJoypadMotion.new()
				e.axis = JOY_AXIS_LEFT_X
				e.axis_value = 1.0
				e.device = 0
				Input.parse_input_event(e)
				t = 0.0
				step = 7
		7:
			if t > 0.5:
				ok(g.pad_cursor.distance_to(cur0) > 100.0, "[pad] left stick moves the menu cursor")
				ok(p.global_position.distance_to(p0) < 3.0, "[pad] ...but not the hero (moved %.1f px)" % p.global_position.distance_to(p0))
				var e := InputEventJoypadMotion.new()
				e.axis = JOY_AXIS_LEFT_X
				e.axis_value = 0.0
				e.device = 0
				Input.parse_input_event(e)
				g.inv_ui.toggle()
				print("MENU probe: %d/%d checks passed" % [checks - fails, checks])
				get_tree().quit(1 if fails > 0 else 0)
