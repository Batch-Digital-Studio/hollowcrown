class_name FloatText
extends Node2D

var _label: Label
var _t := 0.0
var _life := 0.8
var _vel := Vector2(0, -90)
var _pop := false
var _sc := 1.0

func setup(s: String, color: Color, size: int, pop: bool) -> void:
	_pop = pop
	_label = Label.new()
	_label.text = s
	_label.add_theme_font_size_override("font_size", size)
	_label.add_theme_color_override("font_color", color)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_label.add_theme_constant_override("outline_size", 5)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(160, 40)
	_label.position = Vector2(-80, -20)
	add_child(_label)
	z_index = 50
	_vel.x = randf_range(-40, 40)
	if pop:
		_life = 1.0
		_sc = 1.6

func _process(delta: float) -> void:
	_t += delta
	_vel.y += 120.0 * delta
	if _pop:
		_sc = lerpf(_sc, 1.0, minf(1.0, delta * 12.0))
	if IsoView.active:
		# isometric view: rise straight up the screen and stay upright
		position += IsoView.screen_to_world_dir(_vel) * delta
		transform = Transform2D(IsoView.up_x * _sc, IsoView.up_y * _sc, position)
	else:
		position += _vel * delta
		scale = Vector2.ONE * _sc
	modulate.a = clampf(1.0 - (_t - _life * 0.6) / (_life * 0.4), 0.0, 1.0)
	if _t >= _life:
		queue_free()
