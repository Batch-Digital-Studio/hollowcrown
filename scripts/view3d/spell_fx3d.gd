class_name SpellFx3D
extends RefCounted
## 3D spell visuals for the isometric view. Every projectile gets a glowing bolt at chest height.
## Skills tagged "fx3d": "ember" (Ember Bolt) get the full treatment:
##   cast  - a flare gathers in the caster's hand (Puppet triggers it on the cast event)
##   fly   - a bright core, a light that moves with it, and a trail of embers
##   hit   - a burst of sparks, a shock ring, a flash of real light and a scorch mark that fades
## Presentation only; the 2D projectile still decides hits.

const BOLT_H := 1.15

static func _quad(size: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = IsoView.glow_material(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func _sparks(c: Color, amount: int, life: float, one_shot: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.local_coords = false
	var q := QuadMesh.new()
	q.size = Vector2(0.22, 0.22)
	q.material = IsoView.glow_material(Color.WHITE)
	p.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	g.add_point(0.35, c)
	g.set_color(g.get_point_count() - 1, Color(c.r * 0.6, c.g * 0.2, 0.0, 0.0))
	p.color_ramp = g
	var sc := Curve.new()
	sc.add_point(Vector2(0, 1.0))
	sc.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = sc
	return p

static func make_bolt(pr: Projectile) -> Node3D:
	var root := Node3D.new()
	var c: Color = pr.color
	var ember: bool = String(pr.skill.get("fx3d", "")) == "ember"
	root.set_meta("ember", ember)
	root.set_meta("color", c)
	root.set_meta("age", 0.0)
	var r: float = pr.radius * IsoView.S
	var glow := _quad(maxf(0.6, r * 4.5), Color(c.r, c.g, c.b, 0.9))
	glow.name = "Glow"
	root.add_child(glow)
	var core := _quad(maxf(0.25, r * 1.6), Color(1.0, 0.95, 0.85, 1.0))
	root.add_child(core)
	if ember:
		var trail := _sparks(c, 48, 0.4, false)
		trail.name = "Trail"
		trail.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		trail.emission_sphere_radius = 0.12
		trail.direction = Vector3.UP
		trail.spread = 180.0
		trail.initial_velocity_min = 0.2
		trail.initial_velocity_max = 0.9
		trail.gravity = Vector3(0, 1.2, 0)
		root.add_child(trail)
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.55, 0.2)
		l.omni_range = 4.5
		l.light_energy = 2.2
		root.add_child(l)
	root.position = IsoView.to3d(pr.global_position, BOLT_H)
	root.scale = Vector3.ONE * 0.3
	return root

static func update_bolt(v: Node3D, pr: Projectile, delta: float) -> void:
	var age: float = v.get_meta("age") + delta
	v.set_meta("age", age)
	v.position = IsoView.to3d(pr.global_position, BOLT_H)
	v.scale = Vector3.ONE * minf(1.0, 0.3 + age * 9.0)
	v.set_meta("fizzle", pr.travel >= pr.max_range - 1.0)
	var g := v.get_node_or_null("Glow") as MeshInstance3D
	if g:
		g.scale = Vector3.ONE * (1.0 + 0.12 * sin(age * 40.0))

static func finish_bolt(parent: Node3D, v: Node3D) -> void:
	var pos := v.position
	var c: Color = v.get_meta("color")
	if v.get_meta("ember") and not v.get_meta("fizzle", false):
		impact(parent, pos, c)
	else:
		_puff(parent, pos, c, 0.8 if v.get_meta("ember") else 0.5)
	# let the trail's embers finish drifting before freeing
	var trail := v.get_node_or_null("Trail") as CPUParticles3D
	if trail:
		trail.emitting = false
		for ch in v.get_children():
			if ch != trail:
				ch.queue_free()
		v.get_tree().create_timer(0.5).timeout.connect(v.queue_free)
	else:
		v.queue_free()

static func _puff(parent: Node3D, pos: Vector3, c: Color, size: float) -> void:
	var q := _quad(size, c)
	q.position = pos
	parent.add_child(q)
	var tw := q.create_tween()
	tw.tween_property(q, "scale", Vector3.ONE * 2.0, 0.18)
	tw.parallel().tween_property(q, "transparency", 1.0, 0.18)
	tw.tween_callback(q.queue_free)

## Ember Bolt impact.
static func impact(parent: Node3D, pos: Vector3, c: Color) -> void:
	var sp := _sparks(c, 36, 0.55, true)
	sp.direction = Vector3.UP
	sp.spread = 75.0
	sp.initial_velocity_min = 3.0
	sp.initial_velocity_max = 7.0
	sp.gravity = Vector3(0, -9.0, 0)
	sp.position = pos
	sp.emitting = true
	parent.add_child(sp)
	parent.get_tree().create_timer(1.0).timeout.connect(sp.queue_free)
	var core := _quad(2.4, Color(1.0, 0.75, 0.35, 1.0))
	core.position = pos
	parent.add_child(core)
	var tw := core.create_tween()
	tw.tween_property(core, "scale", Vector3.ONE * 1.6, 0.16)
	tw.parallel().tween_property(core, "transparency", 1.0, 0.22)
	tw.tween_callback(core.queue_free)
	# shock ring on the floor
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.42
	tm.outer_radius = 0.5
	tm.rings = 24
	tm.ring_segments = 6
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.albedo_color = Color(1.0, 0.6, 0.25, 0.9)
	ring.material_override = rm
	ring.position = Vector3(pos.x, 0.12, pos.z)
	ring.scale = Vector3(0.6, 0.15, 0.6)
	parent.add_child(ring)
	var tr := ring.create_tween()
	tr.tween_property(ring, "scale", Vector3(3.2, 0.15, 3.2), 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tr.parallel().tween_property(ring, "transparency", 1.0, 0.3)
	tr.tween_callback(ring.queue_free)
	# a moment of real light
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.25)
	l.omni_range = 7.0
	l.light_energy = 4.0
	l.position = pos + Vector3(0, 0.5, 0)
	parent.add_child(l)
	var tl := l.create_tween()
	tl.tween_property(l, "light_energy", 0.0, 0.35)
	tl.tween_callback(l.queue_free)
	# scorch mark that fades out over a few seconds
	var sc := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1.8, 1.8)
	sc.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = FX.glow_tex
	sm.albedo_color = Color(0.05, 0.02, 0.01, 0.75)
	sc.material_override = sm
	sc.position = Vector3(pos.x, 0.07, pos.z)
	sc.rotation.y = randf() * TAU
	parent.add_child(sc)
	var ts := sc.create_tween()
	ts.tween_interval(2.5)
	ts.tween_property(sc, "transparency", 1.0, 2.0)
	ts.tween_callback(sc.queue_free)

## Flare gathering in the caster's hand at the start of an Ember Bolt cast.
static func cast_flare(parent: Node3D, pos: Vector3, c: Color) -> void:
	var q := _quad(0.3, c)
	q.position = pos
	parent.add_child(q)
	var tw := q.create_tween()
	tw.tween_property(q, "scale", Vector3.ONE * 3.2, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(q, "scale", Vector3.ONE * 0.5, 0.12)
	tw.parallel().tween_property(q, "transparency", 1.0, 0.12)
	tw.tween_callback(q.queue_free)
	var sp := _sparks(c, 14, 0.3, true)
	sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	sp.emission_sphere_radius = 0.5
	sp.initial_velocity_min = 0.5
	sp.initial_velocity_max = 1.5
	sp.gravity = Vector3.ZERO
	sp.position = pos
	sp.emitting = true
	parent.add_child(sp)
	parent.get_tree().create_timer(0.6).timeout.connect(sp.queue_free)
