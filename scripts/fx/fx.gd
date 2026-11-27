extends Node
## Presentation-only effects. Gameplay code calls these; nothing here affects simulation.
## In co-op, clients can trigger these from replicated events.

var world: Node2D           # unlit effects layer (set by game.gd)
var light_root: Node2D      # lights live in the lit world canvas
var light_tex: Texture2D
var camera: Camera2D
var enabled := true

var _shake := 0.0
var _hitstop_until := 0.0
var glow_tex: Texture2D
var sfx: Sfx
var soft_tex: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	glow_tex = _make_radial(64, 2.2)
	soft_tex = _make_radial(16, 1.0)
	light_tex = _make_radial(256, 1.0)
	sfx = Sfx.new()
	add_child(sfx)

func _make_radial(size: int, falloff: float) -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CUBIC
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = size
	t.height = size
	return t

## A PointLight2D for the lit world. radius in world px.
func make_light(color: Color, radius: float, energy: float = 1.0) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.texture_scale = radius / 128.0
	l.color = color
	l.energy = energy
	l.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	return l

## Short burst of real light (explosions, crits, level up).
func light_flash(pos: Vector2, color: Color, radius: float = 220.0, duration: float = 0.25, energy: float = 1.6) -> void:
	if not light_root:
		return
	var l := make_light(color, radius, energy)
	l.position = pos
	light_root.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, duration)
	tw.tween_callback(l.queue_free)

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if _hitstop_until > 0.0 and now >= _hitstop_until:
		_hitstop_until = 0.0
		Engine.time_scale = 1.0
	if camera:
		_shake = maxf(0.0, _shake - delta * 60.0)
		var s := minf(_shake, 18.0)
		camera.offset = Vector2(randf_range(-s, s), randf_range(-s, s))

func sound(name: String, world_pos = null, vol: float = 0.0, pitch_var: float = 0.08) -> void:
	if sfx and enabled:
		sfx.play(name, vol, pitch_var, world_pos)

## Controller rumble (only when playing on a pad).
func rumble(weak: float, strong: float, seconds: float) -> void:
	if not PlayerInput.using_pad:
		return
	for d in Input.get_connected_joypads():
		Input.start_joy_vibration(d, clampf(weak, 0, 1), clampf(strong, 0, 1), seconds)

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)

func hitstop(seconds: float) -> void:
	if not enabled:
		return
	Engine.time_scale = 0.04
	_hitstop_until = maxf(_hitstop_until, Time.get_ticks_msec() / 1000.0 + seconds)

func number(pos: Vector2, amount: float, color: Color, crit: bool = false) -> void:
	if not world:
		return
	var n := FloatText.new()
	n.setup(str(int(round(amount))) + ("!" if crit else ""), color, 30 if crit else 20, crit)
	n.position = pos + Vector2(randf_range(-26, 26), randf_range(-40, -18))
	world.add_child(n)

func text(pos: Vector2, s: String, color: Color, size: int = 22) -> void:
	if not world:
		return
	var n := FloatText.new()
	n.setup(s, color, size, true)
	n.position = pos + Vector2(0, -40)
	world.add_child(n)

func burst(pos: Vector2, color: Color, count: int = 14, speed: float = 260.0, size: float = 6.0, life: float = 0.45) -> void:
	if not world:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.one_shot = true
	p.emitting = false
	p.amount = count
	p.lifetime = life
	p.explosiveness = 1.0
	p.texture = soft_tex
	p.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 2.0
	p.scale_amount_min = size / 16.0 * 0.6
	p.scale_amount_max = size / 16.0 * 1.4
	var ramp := Gradient.new()
	ramp.set_color(0, color.lightened(0.4))
	ramp.set_color(1, Color(color.r, color.g, color.b, 0.0))
	p.color_ramp = ramp
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	p.material = mat
	world.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.2, false).timeout.connect(p.queue_free)

func ring(pos: Vector2, radius: float, color: Color, duration: float = 0.35, width: float = 6.0) -> void:
	if not world:
		return
	var r := RingFX.new()
	r.position = pos
	r.max_radius = radius
	r.color = color
	r.duration = duration
	r.width = width
	world.add_child(r)

func flash(pos: Vector2, color: Color, radius: float = 90.0, duration: float = 0.2) -> void:
	if not world:
		return
	var s := Sprite2D.new()
	s.texture = glow_tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.position = pos
	s.modulate = color
	s.scale = Vector2.ONE * radius / 32.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	world.add_child(s)
	var tw := s.create_tween()
	tw.tween_property(s, "modulate:a", 0.0, duration)
	tw.tween_callback(s.queue_free)
	if radius >= 60.0:
		light_flash(pos, color, radius * 2.2, duration + 0.1, 1.2)

## Additive glow sprite to attach under an entity.
func make_glow(color: Color, radius: float) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = glow_tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	s.modulate = color
	s.scale = Vector2.ONE * radius / 32.0
	var mat := CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	s.material = mat
	return s
