class_name HUD
extends CanvasLayer
## Screen-space UI: orbs, skill bar, messages, boss bar, overlays.

var view: HudView
var inventory: InventoryUI
var passives: PassiveUI
var _overlay: Control
var _title: Control
var _vignette: TextureRect

const GOLD := Color(1.0, 0.82, 0.45)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_vignette = TextureRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.texture = _make_vignette()
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(_vignette)
	view = HudView.new()
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(view)
	inventory = InventoryUI.new()
	inventory.set_anchors_preset(Control.PRESET_FULL_RECT)
	inventory.visible = false
	add_child(inventory)
	passives = PassiveUI.new()
	passives.set_anchors_preset(Control.PRESET_FULL_RECT)
	passives.visible = false
	add_child(passives)
	_show_title()

func _make_vignette() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.add_point(0.55, Color(0, 0, 0, 0.0))
	g.set_color(g.get_point_count() - 1, Color(0, 0, 0, 0.78))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.05, 0.5)
	t.width = 256
	t.height = 256
	return t

func show_message(big: String, small: String = "") -> void:
	view.message = big
	view.sub_message = small
	view.message_t = 3.5

# ---------- overlays ----------

func _panel_style(alpha: float = 0.85) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.045, 0.06, alpha)
	sb.border_color = Color(0.6, 0.42, 0.22)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(18)
	return sb

func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(320, 52)
	b.add_theme_font_size_override("font_size", 22)
	var n := _panel_style(0.9)
	var h := _panel_style(0.95)
	h.border_color = GOLD
	h.bg_color = Color(0.14, 0.08, 0.05, 0.95)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_color_override("font_color", Color(0.9, 0.85, 0.78))
	b.add_theme_color_override("font_hover_color", GOLD)
	b.pressed.connect(cb)
	return b

func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l

func _centered_box() -> VBoxContainer:
	var root := CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.add_child(bg)
	holder.add_child(root)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(box)
	add_child(holder)
	_overlay = holder
	return box

func hide_overlays() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	get_tree().paused = false

func _show_title() -> void:
	var box := _centered_box()
	_title = _overlay
	(_overlay.get_child(0) as ColorRect).color = Color(0.02, 0.02, 0.03, 0.97)
	box.add_child(_label("HOLLOWCROWN", 84, GOLD))
	box.add_child(_label("The crown went hollow. The fire went everywhere else.", 20, Color(0.75, 0.68, 0.6)))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 30)
	box.add_child(sp)
	var g := Game.instance
	if g.has_save():
		box.add_child(_button("Continue", func(): _start(true)))
	box.add_child(_button("New Kindled" if g.has_save() else "Begin", func(): _start(false)))
	var sp2 := Control.new()
	sp2.custom_minimum_size = Vector2(0, 20)
	box.add_child(sp2)
	box.add_child(_label(CONTROLS, 16, Color(0.6, 0.58, 0.55)))

const CONTROLS := "WASD move  ·  Mouse aim  ·  LMB Ember Bolt  ·  RMB Ashen Cleave\nQ Rimeburst  ·  E Stormthread  ·  R Cinderfall  ·  Space dodge  ·  1 flask\nI / Tab inventory  ·  P passive tree  ·  Esc pause"

func _start(cont: bool) -> void:
	hide_overlays()
	if not cont:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(Game.SAVE_PATH))
	Game.instance.start_game(cont)

func toggle_pause() -> void:
	if _overlay:
		hide_overlays()
		return
	var box := _centered_box()
	box.add_child(_label("PAUSED", 56, GOLD))
	box.add_child(_button("Resume", hide_overlays))
	box.add_child(_button("Save & Quit", func():
		Game.instance.save_game()
		get_tree().quit()))
	box.add_child(_label(CONTROLS, 16, Color(0.6, 0.58, 0.55)))
	get_tree().paused = true

func show_death() -> void:
	var box := _centered_box()
	(_overlay.get_child(0) as ColorRect).color = Color(0.15, 0.0, 0.0, 0.55)
	box.add_child(_label("YOU HAVE BEEN HOLLOWED", 52, Color(0.9, 0.25, 0.2)))
	box.add_child(_label("Your gear and levels are kept. The zone is reborn.", 18, Color(0.8, 0.7, 0.65)))
	box.add_child(_button("Rise again  (Enter)", func(): Game.instance.respawn()))
