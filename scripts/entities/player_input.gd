class_name PlayerInput
extends RefCounted
## Intent source for a player. Local players read devices; in co-op a remote
## player's PlayerInput will be filled from network packets instead.

var move := Vector2.ZERO
var aim := Vector2.ZERO          # world position
var skill_held := [false, false, false, false, false]
var dodge := false
var flask := false

const SKILL_ACTIONS := ["skill_1", "skill_2", "skill_3", "skill_4", "skill_5"]

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
	_key("inventory", [KEY_I, KEY_TAB])
	_key("pause", [KEY_ESCAPE])
	_key("passives", [KEY_P])
	_key("respawn", [KEY_ENTER])
	_mouse("skill_1", MOUSE_BUTTON_LEFT)
	_mouse("skill_2", MOUSE_BUTTON_RIGHT)

static func _key(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var e := InputEventKey.new()
		e.physical_keycode = k
		InputMap.action_add_event(action, e)

static func _mouse(action: String, button: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventMouseButton.new()
	e.button_index = button
	InputMap.action_add_event(action, e)

## Poll local devices. ui_blocking: true while the cursor is over a UI panel.
func poll_local(world_mouse: Vector2, ui_blocking: bool) -> void:
	move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	aim = world_mouse
	for i in SKILL_ACTIONS.size():
		skill_held[i] = Input.is_action_pressed(SKILL_ACTIONS[i]) and not (ui_blocking and i < 2)
	dodge = Input.is_action_just_pressed("dodge")
	flask = Input.is_action_just_pressed("flask")
