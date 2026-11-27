class_name PlayerInput
extends RefCounted
## Intent source for a player. Local players read devices; in co-op a remote
## player's PlayerInput will be filled from network packets instead.
##
## Xbox controller layout (Jason plays on controller; every feature must work on it):
##   Left stick move · Right stick aim (auto-targets nearest foe when released)
##   Rite slots: RT, A, X, B, Y, RB (keyboard LMB, RMB, Q, E, R, F)
##   LB + RB together = class Special (keyboard T) · LT dodge · LB flask
##   View inventory · Menu pause · D-pad Up passive tree · D-pad Down class screen

var move := Vector2.ZERO
var aim := Vector2.ZERO          # world position
var skill_held := [false, false, false, false, false, false]
var special := false
var dodge := false
var flask := false
var _buffered := [0, 0, 0, 0, 0, 0]
var _lb_at := -1
var _rb_at := -1
var _chord_lock := false
const CHORD_MS := 110   # msec timestamp of the last tap per skill
const BUFFER_MS := 300

static var using_pad := false    # last input came from a controller
static var view_inv := Transform2D.IDENTITY   # screen dir -> world dir (isometric view)
static var ignore_mouse_until := 0  # ms: mouse motion caused by the pad cursor warping the OS pointer
const SYNTHETIC := -77              # device id of mouse clicks the pad cursor generates

const SKILL_ACTIONS := ["skill_1", "skill_2", "skill_3", "skill_4", "skill_5", "skill_6"]
const KEY_LABELS := ["LMB", "RMB", "Q", "E", "R", "F"]
const PAD_LABELS := ["RT", "A", "X", "B", "Y", "RB"]
const DEADZONE := 0.22

static func setup_input_map() -> void:
	_key("move_up", [KEY_W, KEY_UP])
	_key("move_down", [KEY_S, KEY_DOWN])
	_key("move_left", [KEY_A, KEY_LEFT])
	_key("move_right", [KEY_D, KEY_RIGHT])
	_key("dodge", [KEY_SPACE])
	_key("flask", [KEY_1])
	_key("skill_3", [KEY_Q])
	_key("skill_4", [KEY_E])
	_key("skill_5", [KEY_R])
	_key("skill_6", [KEY_F])
	_key("special", [KEY_T])
	_key("class_screen", [KEY_K])
	_key("inventory", [KEY_I, KEY_TAB])
	_key("pause", [KEY_ESCAPE])
	_key("passives", [KEY_P])
	_key("loadout", [KEY_X])
	_key("town", [KEY_H])
	_key("respawn", [KEY_ENTER])
	_mouse("skill_1", MOUSE_BUTTON_LEFT)
	_mouse("skill_2", MOUSE_BUTTON_RIGHT)
	# --- Xbox controller ---
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_axis("skill_1", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_button("skill_2", JOY_BUTTON_A)
	_button("skill_3", JOY_BUTTON_X)
	_button("skill_4", JOY_BUTTON_B)
	_button("skill_5", JOY_BUTTON_Y)
	_button("pad_rb", JOY_BUTTON_RIGHT_SHOULDER)
	_button("pad_lb", JOY_BUTTON_LEFT_SHOULDER)
	_axis("dodge", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_button("class_screen", JOY_BUTTON_DPAD_DOWN)
	_button("inventory", JOY_BUTTON_BACK)
	_button("pause", JOY_BUTTON_START)
	_button("passives", JOY_BUTTON_DPAD_UP)
	_button("loadout", JOY_BUTTON_DPAD_LEFT)
	_button("loadout", JOY_BUTTON_DPAD_RIGHT)
	_button("respawn", JOY_BUTTON_START)
	# menu-only actions (inventory / passive tree with the virtual cursor)
	_button("pad_click", JOY_BUTTON_A)
	_button("pad_alt_click", JOY_BUTTON_X)
	_button("pad_close", JOY_BUTTON_B)
	_button("pad_zoom_in", JOY_BUTTON_RIGHT_SHOULDER)
	_button("pad_zoom_out", JOY_BUTTON_LEFT_SHOULDER)
	# Godot's built-in UI actions: make sure buttons/menus are fully navigable on pad
	_button("ui_accept", JOY_BUTTON_A)
	_button("ui_cancel", JOY_BUTTON_B)
	_button("ui_up", JOY_BUTTON_DPAD_UP)
	_button("ui_down", JOY_BUTTON_DPAD_DOWN)
	_button("ui_left", JOY_BUTTON_DPAD_LEFT)
	_button("ui_right", JOY_BUTTON_DPAD_RIGHT)
	_axis("ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_axis("ui_down", JOY_AXIS_LEFT_Y, 1.0)
	_axis("ui_left", JOY_AXIS_LEFT_X, -1.0)
	_axis("ui_right", JOY_AXIS_LEFT_X, 1.0)
	for a in ["move_left", "move_right", "move_up", "move_down", "aim_left", "aim_right", "aim_up", "aim_down"]:
		InputMap.action_set_deadzone(a, DEADZONE)
	InputMap.action_set_deadzone("skill_1", 0.35)
	InputMap.action_set_deadzone("dodge", 0.35)

static func _ensure(action: String) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)

static func _key(action: String, keys: Array) -> void:
	_ensure(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)

static func _mouse(action: String, button: int) -> void:
	_ensure(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)

static func _button(action: String, button: int) -> void:
	_ensure(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	e.device = -1   # any controller
	InputMap.action_add_event(action, e)

static func _axis(action: String, axis: int, dir: float) -> void:
	_ensure(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = dir
	e.device = -1
	InputMap.action_add_event(action, e)

## Called from Game._input so the HUD shows the right button labels and aiming mode.
static func note_event(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		using_pad = true
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.4:
		using_pad = true
	elif event is InputEventMouseMotion and event.relative.length() > 3.0:
		if Time.get_ticks_msec() > ignore_mouse_until:
			using_pad = false
	elif event is InputEventMouseButton:
		if event.device != SYNTHETIC:
			using_pad = false
	elif event is InputEventKey:
		using_pad = false

static func labels() -> Array:
	return PAD_LABELS if using_pad else KEY_LABELS

## Poll local devices.
## ui_blocking: a menu is under the cursor / open (skills that share the click are suppressed).
func poll_local(world_mouse: Vector2, ui_blocking: bool, me: Actor = null) -> void:
	move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move.length() > 0.001:
		move = view_inv.basis_xform(move).normalized() * move.length()   # screen-relative movement
	if using_pad and me != null:
		aim = _pad_aim(me)
	else:
		aim = world_mouse
	var now := int(Game.instance._clock * 1000.0) if Game.instance else Time.get_ticks_msec()
	for i in SKILL_ACTIONS.size():
		var blocked := ui_blocking and (using_pad or i < 2)
		if Input.is_action_just_pressed(SKILL_ACTIONS[i]) and not blocked:
			_buffered[i] = now
		var buffered: bool = now - int(_buffered[i]) < BUFFER_MS
		skill_held[i] = (Input.is_action_pressed(SKILL_ACTIONS[i]) or buffered) and not blocked
	dodge = Input.is_action_just_pressed("dodge")
	flask = Input.is_action_just_pressed("flask")
	special = Input.is_action_just_pressed("special") and not ui_blocking
	# LB / RB: LB = flask, RB = slot 6, both together = Special.
	if Input.is_action_just_pressed("pad_lb"):
		_lb_at = now
	if Input.is_action_just_pressed("pad_rb"):
		_rb_at = now
	var lb := Input.is_action_pressed("pad_lb")
	var rb := Input.is_action_pressed("pad_rb")
	if not lb and not rb:
		_chord_lock = false
	if not _chord_lock and _lb_at >= 0 and _rb_at >= 0 and absi(_lb_at - _rb_at) <= CHORD_MS:
		special = not ui_blocking
		_chord_lock = true
		_lb_at = -1
		_rb_at = -1
	if not _chord_lock and _lb_at >= 0 and now - _lb_at > CHORD_MS:
		flask = true
		_lb_at = -1
	if _rb_at >= 0 and now - _rb_at > CHORD_MS:
		_rb_at = -1
	if rb and not _chord_lock and _rb_at < 0 and not ui_blocking:
		skill_held[5] = true

## A buffered tap was used; don't fire it twice.
func consume(i: int) -> void:
	_buffered[i] = 0

## Right stick aims; released stick auto-targets the best nearby enemy (console-ARPG style).
func _pad_aim(me: Actor) -> Vector2:
	var rs := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	var origin := me.global_position
	if rs.length() > 0.3:
		return origin + view_inv.basis_xform(rs).normalized() * 360.0
	var g := me.game()
	var dir := move.normalized() if move.length() > 0.2 else me.facing
	var best: Actor = null
	var best_score := INF
	if g:
		for e in g.targets_in_circle(me.faction, origin, 760.0):
			var to: Vector2 = e.global_position - origin
			var d := to.length()
			if d > 1.0 and not g.has_line_of_sight(origin, e.global_position):
				continue
			var ang := absf(dir.angle_to(to)) if d > 1.0 else 0.0
			var score := d * (1.0 + ang * 0.9)   # prefer enemies in the direction you're facing
			if score < best_score:
				best_score = score
				best = e
	if best:
		return best.global_position
	return origin + dir * 300.0
