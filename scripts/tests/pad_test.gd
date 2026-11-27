extends Node
## Automated Xbox-controller test (--pad-test). Injects real joypad events and checks
## that menus, movement, skills, dodge, inventory, passive tree and pause all respond.

var t := 0.0
var step := 0
var fails := 0
var x0 := 0.0
var mana0 := 0.0
var g: Game

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	FX.enabled = false   # no hit-stop: keeps the test's clock in step with the game

func btn(b: int, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	e.pressed = pressed
	e.device = 0
	Input.parse_input_event(e)

func tap(b: int) -> void:
	btn(b, true)
	await get_tree().process_frame
	await get_tree().process_frame
	btn(b, false)

func axis(a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	e.device = 0
	Input.parse_input_event(e)

func check(name: String, ok: bool) -> void:
	print(("  PASS " if ok else "  FAIL ") + name)
	if not ok:
		fails += 1

func _process(delta: float) -> void:
	t += delta / maxf(Engine.time_scale, 0.04)
	g = Game.instance
	match step:
		0:
			if t > 0.50:
				tap(JOY_BUTTON_A)   # "Begin" on the title screen
				step = 1
		1:
			if t > 1.00:
				tap(JOY_BUTTON_A)   # first class: Bog Shaman
				step = 2
		2:
			if t > 1.50:
				tap(JOY_BUTTON_A)   # first look
				step = 3
		3:
			if t > 2.20:
				check("title -> class -> look with A starts a Bog Shaman", g.state == "play" and g.player != null and g.player.class_id == "shaman")
				check("controller mode detected", PlayerInput.using_pad)
				x0 = g.player.global_position.x
				axis(JOY_AXIS_LEFT_X, 1.0)
				step = 4
		4:
			if t > 3.00:
				axis(JOY_AXIS_LEFT_X, 0.0)
				check("left stick moves the player (%.0f px)" % (g.player.global_position.x - x0), absf(g.player.global_position.x - x0) > 60.0)
				g.player.mana = g.player.max_mana
				mana0 = g.player.mana
				tap(JOY_BUTTON_A)   # slot 2 = Bone Spear
				step = 5
		5:
			if t > 3.50:
				check("A casts Bone Spear (mana %.0f -> %.0f)" % [mana0, g.player.mana], g.player.mana < mana0 - 1.0)
				g.player.mana = g.player.max_mana
				g.player.spirit = 100.0
				mana0 = g.player.mana
				axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)   # slot 1 = Raise Husk (no corpses: spends 20 Spirit)
				step = 6
		6:
			if t > 4.05:
				axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
				step = 60
		60:
			if t > 4.35:
				check("RT casts Raise Husk (%d husk)" % g.allies.size(), g.allies.size() >= 1)
				g.player.spirit = 100.0
				var n := g.allies.size()
				x0 = float(n)
				btn(JOY_BUTTON_LEFT_SHOULDER, true)
				btn(JOY_BUTTON_RIGHT_SHOULDER, true)
				step = 7
		7:
			if t > 4.80:
				btn(JOY_BUTTON_LEFT_SHOULDER, false)
				btn(JOY_BUTTON_RIGHT_SHOULDER, false)
				step = 70
		70:
			if t > 5.20:
				check("LB+RB chord fires Grand Rite (Spirit spent, horde raised: %d allies)" % g.allies.size(), g.player.spirit < 10.0 and g.allies.size() >= 3)
				mana0 = g.player.flask_charges
				g.player.life = g.player.max_life * 0.4
				tap(JOY_BUTTON_LEFT_SHOULDER)
				step = 8
		8:
			if t > 5.80:
				check("LB alone drinks the flask", g.player.flask_charges < mana0)
				g.player.life = g.player.max_life
				axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
				step = 9
		9:
			if t > 5.95:
				check("LT dodges (dead=%s)" % g.player.dead, g.player.invulnerable or g.player._dodge_cd > 0.0)
				axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
				step = 10
		10:
			if t > 6.10:
				tap(JOY_BUTTON_BACK)
				step = 11
		11:
			if t > 6.50:
				check("View opens inventory", g.inv_ui.visible)
				tap(JOY_BUTTON_B)
				step = 12
		12:
			if t > 6.90:
				check("B closes inventory", not g.inv_ui.visible)
				tap(JOY_BUTTON_DPAD_UP)
				step = 13
		13:
			if t > 7.30:
				check("D-pad up opens passive tree (paused)", g.hud.passives.visible and get_tree().paused)
				tap(JOY_BUTTON_B)
				step = 14
		14:
			if t > 7.70:
				check("B closes passive tree", not g.hud.passives.visible and not get_tree().paused)
				tap(JOY_BUTTON_DPAD_DOWN)
				step = 15
		15:
			if t > 8.10:
				check("D-pad down opens class screen (paused)", g.hud.class_ui.visible and get_tree().paused)
				tap(JOY_BUTTON_B)
				step = 16
		16:
			if t > 8.50:
				check("B closes class screen", not g.hud.class_ui.visible and not get_tree().paused)
				tap(JOY_BUTTON_START)
				step = 17
		17:
			if t > 8.90:
				check("Menu opens pause", get_tree().paused)
				tap(JOY_BUTTON_START)
				step = 18
		18:
			if t > 9.30:
				check("Menu closes pause", not get_tree().paused)
				print("PAD FAILURES: ", fails)
				get_tree().quit(1 if fails > 0 else 0)
