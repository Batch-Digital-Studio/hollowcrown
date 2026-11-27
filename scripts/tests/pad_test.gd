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
			if t > 0.5:
				tap(JOY_BUTTON_A)   # "Begin" on the title screen
				step = 1
		1:
			if t > 1.2:
				tap(JOY_BUTTON_A)   # first hero card
				step = 2
		2:
			if t > 2.0:
				check("title + hero select with A starts the game", g.state == "play" and g.player != null)
				check("controller mode detected", PlayerInput.using_pad)
				x0 = g.player.global_position.x
				axis(JOY_AXIS_LEFT_X, 1.0)
				step = 3
		3:
			if t > 3.0:
				axis(JOY_AXIS_LEFT_X, 0.0)
				check("left stick moves the player (%.0f px)" % (g.player.global_position.x - x0), absf(g.player.global_position.x - x0) > 60.0 or g.player.velocity.length() > 0.0)
				mana0 = g.player.mana
				g.player.mana = g.player.max_mana
				mana0 = g.player.mana
				btn(JOY_BUTTON_A, true)
				step = 4
		4:
			if t > 3.6:
				btn(JOY_BUTTON_A, false)
				check("A casts Ember Bolt (mana %.0f -> %.0f)" % [mana0, g.player.mana], g.player.mana < mana0 - 1.0)
				g.player.mana = g.player.max_mana
				mana0 = g.player.mana
				axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)
				step = 5
		5:
			if t > 4.2:
				axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
				check("RT casts Ember Bolt", g.player.mana < mana0 - 1.0)
				g.player.mana = g.player.max_mana
				mana0 = g.player.mana
				tap(JOY_BUTTON_B)
				step = 6
		6:
			if t > 4.6:
				check("B casts Rimeburst (cooldown started)", g.player.cooldowns.get("frost_nova", 0.0) > 0.0)
				axis(JOY_AXIS_TRIGGER_LEFT, 1.0)
				step = 7
		7:
			if t > 4.75:
				check("LT dodges (invulnerable)", g.player.invulnerable or g.player._dodge_cd > 0.0)
				axis(JOY_AXIS_TRIGGER_LEFT, 0.0)
				step = 8
		8:
			if t > 5.6:
				tap(JOY_BUTTON_BACK)
				step = 9
		9:
			if t > 6.0:
				check("View opens inventory", g.inv_ui.visible)
				tap(JOY_BUTTON_B)
				step = 10
		10:
			if t > 6.4:
				check("B closes inventory", not g.inv_ui.visible)
				tap(JOY_BUTTON_DPAD_UP)
				step = 11
		11:
			if t > 6.8:
				check("D-pad up opens passive tree (game paused)", g.hud.passives.visible and get_tree().paused)
				tap(JOY_BUTTON_B)
				step = 12
		12:
			if t > 7.2:
				check("B closes passive tree and unpauses", not g.hud.passives.visible and not get_tree().paused)
				tap(JOY_BUTTON_START)
				step = 13
		13:
			if t > 7.6:
				check("Menu opens pause", get_tree().paused)
				tap(JOY_BUTTON_START)
				step = 14
		14:
			if t > 8.0:
				check("Menu closes pause", not get_tree().paused)
				print("PAD FAILURES: ", fails)
				get_tree().quit(1 if fails > 0 else 0)
