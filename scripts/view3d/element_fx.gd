class_name ElementFx
extends RefCounted
## Elemental spell visuals for the isometric 3D view (presentation only).
## Every spell is drawn by its element:
##   fire      flames that lick upward, embers, smoke, scorch, warm light
##   cold      ice crystals and shards, frost mist, ice spikes, frozen ground, cold light
##   lightning forked flickering bolts, sparks, white-blue flashes
##   chaos     void orbs, bubbling poison, dark smoke, sickly green-violet light
##   light     radiant beams, rays, golden motes, a halo ring
## Gameplay never reads anything from here; the 2D simulation decides every hit.

const ELEMENTS := ["fire", "cold", "lightning", "chaos", "light", "physical"]
const PAL := {
	"fire": [Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.45), Color(0.7, 0.12, 0.02)],
	"cold": [Color(0.55, 0.85, 1.0), Color(0.9, 0.97, 1.0), Color(0.2, 0.45, 0.8)],
	"lightning": [Color(0.75, 0.85, 1.0), Color(1.0, 1.0, 0.85), Color(0.45, 0.5, 1.0)],
	"chaos": [Color(0.55, 0.95, 0.3), Color(0.8, 0.45, 1.0), Color(0.12, 0.05, 0.18)],
	"light": [Color(1.0, 0.92, 0.6), Color(1.0, 1.0, 0.92), Color(1.0, 0.75, 0.35)],
	"physical": [Color(0.9, 0.85, 0.8), Color(1, 1, 1), Color(0.4, 0.38, 0.35)],
}

static var _mats := {}
## Readability budget: heavy casting must not bury enemy tells, hazards or the hero.
const MAX_FLASH_LIGHTS := 10
const MAX_IMPACTS_PER_TICK := 6     # full-size impacts per 0.1 s; the rest are drawn small
static var _flash_lights := 0
static var _impact_tick := 0
static var _impacts := 0

## Element of a skill: its "element" field, else the damage type it deals most of.
static func of_skill(s: Dictionary) -> String:
	if s.has("element"):
		return String(s.element)
	var best := "physical"
	var bv := -1.0
	var bd: Dictionary = s.get("base_damage", {})
	for t in bd:
		var v: float = float(bd[t][0]) + float(bd[t][1])
		if v > bv:
			bv = v
			best = "cold" if t == "cold" else String(t)
	return best

## Element from a colour (for effects that only carry a colour).
static func of_color(c: Color) -> String:
	if c.s < 0.25:
		return "light" if c.v > 0.8 else "physical"
	var h := c.h * 360.0
	if h < 45.0 or h > 340.0:
		return "fire"
	if h < 70.0:
		return "light" if c.s < 0.6 else "lightning"
	if h < 160.0:
		return "chaos"
	if h < 235.0:
		return "cold"
	if h < 340.0:
		return "chaos"
	return "fire"

static func col(e: String, i: int = 0) -> Color:
	return PAL.get(e, PAL.physical)[i]

# ------------------------------------------------------------------ materials

static func glow(c: Color) -> StandardMaterial3D:
	return IsoView.glow_material(c)

static func _mat(key: String, make: Callable) -> Material:
	if not _mats.has(key):
		_mats[key] = make.call()
	return _mats[key]

static func smoke_mat() -> StandardMaterial3D:
	return _mat("smoke", func():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = FX.glow_tex
		m.albedo_color = Color(1, 1, 1, 1)
		return m)

static func ice_mat() -> StandardMaterial3D:
	return _mat("ice", func():
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.7, 0.9, 1.0, 0.75)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.metallic = 0.2
		m.roughness = 0.08
		m.emission_enabled = true
		m.emission = Color(0.35, 0.65, 1.0)
		m.emission_energy_multiplier = 0.9
		m.rim_enabled = true
		m.rim = 0.8
		return m)

static func solid_glow(c: Color, energy: float = 3.0) -> StandardMaterial3D:
	return _mat("sg" + c.to_html() + str(energy), func():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = energy
		return m)

static func add_mat(c: Color) -> StandardMaterial3D:
	return _mat("add" + c.to_html(), func():
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = c
		return m)

# ------------------------------------------------------------------ building blocks

static func quad(size: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	mi.material_override = glow(c)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

static func light(c: Color, rng: float, energy: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = c
	l.omni_range = rng
	l.light_energy = energy
	l.shadow_enabled = false
	return l

static func _ramp(stops: Array) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, stops[0])
	for i in range(1, stops.size() - 1):
		g.add_point(float(i) / (stops.size() - 1), stops[i])
	g.set_color(g.get_point_count() - 1, stops[stops.size() - 1])
	return g

static func _curve(a: float, b: float) -> Curve:
	var c := Curve.new()
	c.add_point(Vector2(0, a))
	c.add_point(Vector2(1, b))
	return c

## A particle system: kind = flame | ember | smoke | spark | frost | shard | bubble | mote | ray
static func particles(kind: String, e: String, amount: int, life: float, one_shot: bool, size: float = 1.0) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 0.9 if one_shot else 0.0
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.15 * size
	var q := QuadMesh.new()
	q.size = Vector2(0.3, 0.3) * size
	q.material = glow(Color.WHITE)
	p.mesh = q
	var c0 := col(e, 0)
	var c1 := col(e, 1)
	var c2 := col(e, 2)
	match kind:
		"flame":
			q.size = Vector2(0.55, 0.7) * size
			p.direction = Vector3.UP
			p.spread = 18.0
			p.initial_velocity_min = 1.2
			p.initial_velocity_max = 2.4
			p.gravity = Vector3(0, 1.5, 0)
			p.scale_amount_curve = _curve(1.0, 0.15)
			p.color_ramp = _ramp([Color(1, 0.95, 0.7, 0.0), Color(1, 0.8, 0.35, 1), Color(1, 0.4, 0.08, 0.9), Color(0.5, 0.08, 0.02, 0.0)])
		"ember":
			q.size = Vector2(0.1, 0.1) * size
			p.direction = Vector3.UP
			p.spread = 60.0
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 2.5
			p.gravity = Vector3(0, 0.8, 0)
			p.color_ramp = _ramp([Color(1, 0.9, 0.5, 1), c0, Color(c2.r, c2.g, c2.b, 0)])
		"smoke":
			q.size = Vector2(0.9, 0.9) * size
			q.material = smoke_mat()
			p.direction = Vector3.UP
			p.spread = 30.0
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.8
			p.gravity = Vector3(0, 0.4, 0)
			p.scale_amount_curve = _curve(0.5, 1.6)
			var sc := Color(0.08, 0.06, 0.06) if e != "chaos" else Color(0.16, 0.05, 0.2)
			p.color_ramp = _ramp([Color(sc.r, sc.g, sc.b, 0), Color(sc.r, sc.g, sc.b, 0.55), Color(sc.r, sc.g, sc.b, 0)])
		"spark":
			q.size = Vector2(0.12, 0.12) * size
			p.direction = Vector3.UP
			p.spread = 180.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 7.0
			p.gravity = Vector3(0, -9.0, 0)
			p.color_ramp = _ramp([c1, c0, Color(c2.r, c2.g, c2.b, 0)])
		"frost":
			q.size = Vector2(1.0, 1.0) * size
			q.material = smoke_mat()
			p.direction = Vector3.UP
			p.spread = 90.0
			p.initial_velocity_min = 0.2
			p.initial_velocity_max = 0.7
			p.gravity = Vector3(0, -0.15, 0)
			p.scale_amount_curve = _curve(0.6, 1.5)
			p.color_ramp = _ramp([Color(0.8, 0.95, 1, 0), Color(0.75, 0.92, 1, 0.45), Color(0.6, 0.85, 1, 0)])
		"shard":
			var pm := PrismMesh.new()
			pm.size = Vector3(0.12, 0.38, 0.12) * size
			pm.material = ice_mat()
			p.mesh = pm
			p.direction = Vector3.UP
			p.spread = 70.0
			p.initial_velocity_min = 3.0
			p.initial_velocity_max = 6.5
			p.gravity = Vector3(0, -12.0, 0)
			p.angular_velocity_min = -400.0
			p.angular_velocity_max = 400.0
			p.particle_flag_rotate_y = true
		"bubble":
			var sm := SphereMesh.new()
			sm.radius = 0.09 * size
			sm.height = 0.18 * size
			sm.radial_segments = 8
			sm.rings = 4
			sm.material = add_mat(Color(c0.r, c0.g, c0.b, 0.7))
			p.mesh = sm
			p.direction = Vector3.UP
			p.spread = 25.0
			p.initial_velocity_min = 0.4
			p.initial_velocity_max = 1.0
			p.gravity = Vector3(0, 0.3, 0)
			p.scale_amount_curve = _curve(0.4, 1.3)
		"mote":
			q.size = Vector2(0.14, 0.14) * size
			p.direction = Vector3.UP
			p.spread = 15.0
			p.initial_velocity_min = 0.6
			p.initial_velocity_max = 1.6
			p.gravity = Vector3(0, 0.6, 0)
			p.color_ramp = _ramp([Color(c1.r, c1.g, c1.b, 0), c1, c0, Color(c0.r, c0.g, c0.b, 0)])
	return p

static func _burst_at(parent: Node3D, p: CPUParticles3D, pos: Vector3, free_after: float) -> void:
	p.position = pos
	p.emitting = true
	parent.add_child(p)
	parent.get_tree().create_timer(free_after).timeout.connect(p.queue_free)

static func _fade_free(n: Node3D, t: float, grow: float = 1.0) -> void:
	var tw := n.create_tween()
	if grow != 1.0:
		tw.tween_property(n, "scale", n.scale * grow, t)
	if n is GeometryInstance3D:
		tw.parallel().tween_property(n, "transparency", 1.0, t)
	elif n is Light3D:
		tw.parallel().tween_property(n, "light_energy", 0.0, t)
	tw.tween_callback(n.queue_free)

static func ring(parent: Node3D, pos: Vector3, radius: float, c: Color, t: float, thick: float = 0.08) -> void:
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0 - thick
	tm.outer_radius = 1.0
	tm.rings = 40
	tm.ring_segments = 4
	m.mesh = tm
	m.material_override = add_mat(c)
	m.position = pos + Vector3(0, 0.12, 0)
	m.scale = Vector3(radius * 0.25, 0.2, radius * 0.25)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(m)
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3(radius, 0.2, radius), t).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_property(m, "transparency", 1.0, t)
	tw.tween_callback(m.queue_free)

static func flash_light(parent: Node3D, pos: Vector3, c: Color, rng: float, energy: float, t: float) -> void:
	if _flash_lights >= MAX_FLASH_LIGHTS:
		return
	_flash_lights += 1
	var l := light(c, rng, energy)
	l.tree_exiting.connect(func(): _flash_lights -= 1)
	l.position = pos + Vector3(0, 0.8, 0)
	parent.add_child(l)
	_fade_free(l, t)

## Ice crystals jutting from the ground (nova, eruption, frozen ground).
static func ice_spikes(parent: Node3D, pos: Vector3, radius: float, n: int, life: float) -> void:
	for i in n:
		var a := randf() * TAU
		var d := sqrt(randf()) * radius
		var m := MeshInstance3D.new()
		var pm := PrismMesh.new()
		var h := randf_range(0.5, 1.3) * (1.0 - d / (radius * 1.6))
		pm.size = Vector3(0.28, h, 0.28)
		m.mesh = pm
		m.material_override = ice_mat()
		m.position = pos + Vector3(cos(a) * d, -h, sin(a) * d)
		m.rotation = Vector3(randf_range(-0.35, 0.35), randf() * TAU, randf_range(-0.35, 0.35))
		parent.add_child(m)
		var tw := m.create_tween()
		tw.tween_property(m, "position:y", pos.y + h * 0.35, 0.12).set_ease(Tween.EASE_OUT).set_delay(d / radius * 0.12)
		tw.tween_interval(life)
		tw.tween_property(m, "transparency", 1.0, 0.5)
		tw.tween_callback(m.queue_free)

## A jagged bolt between 3D points; strands > 1 draws a thicker, branching arc.
static func bolt_line(parent: Node3D, pts: Array, e: String, life: float = 0.28, strands: int = 2, jag: float = 0.35) -> void:
	for s in strands:
		var im := ImmediateMesh.new()
		var mi := MeshInstance3D.new()
		mi.mesh = im
		mi.material_override = solid_glow(col(e, 1) if s == 0 else col(e, 0), 6.0 if s == 0 else 3.0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var segs := maxi(3, int(a.distance_to(b) / 0.6))
			for k in segs:
				var p := a.lerp(b, float(k) / segs)
				if k > 0:
					p += Vector3(randf_range(-jag, jag), randf_range(-jag, jag) * 0.6, randf_range(-jag, jag))
				im.surface_add_vertex(p)
		im.surface_add_vertex(pts[pts.size() - 1])
		im.surface_end()
		parent.add_child(mi)
		var tw := mi.create_tween()
		tw.tween_interval(life * 0.5)
		tw.tween_property(mi, "visible", false, 0.0)
		tw.tween_interval(0.04)
		tw.tween_property(mi, "visible", true, 0.0)
		tw.tween_interval(life * 0.4)
		tw.tween_callback(mi.queue_free)
	# glow along the path
	for i in pts.size():
		var g := quad(1.3, col(e, 0))
		g.position = pts[i]
		parent.add_child(g)
		_fade_free(g, life + 0.1, 1.4)

## A solid beam (light lance, fire lance, ice lance) between two points.
static func beam(parent: Node3D, a: Vector3, b: Vector3, e: String, width: float, life: float) -> void:
	var len := a.distance_to(b)
	if len < 0.1:
		return
	var mid := (a + b) * 0.5
	for k in 2:
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = width * (0.25 if k == 0 else 0.8)
		cm.bottom_radius = cm.top_radius
		cm.height = len
		cm.radial_segments = 10
		cm.rings = 1
		mi.mesh = cm
		mi.material_override = add_mat(Color(col(e, 1 if k == 0 else 0), 0.8 if k == 0 else 0.22))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = mid
		mi.look_at_from_position(mid, b, Vector3.UP if absf((b - a).normalized().y) < 0.95 else Vector3.RIGHT)
		mi.rotate_object_local(Vector3.RIGHT, PI / 2.0)
		parent.add_child(mi)
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(1.6, 1.0, 1.6), life * 0.25)
		tw.tween_property(mi, "scale", Vector3(0.05, 1.0, 0.05), life * 0.75)
		tw.parallel().tween_property(mi, "transparency", 1.0, life * 0.75)
		tw.tween_callback(mi.queue_free)
	var n := int(len / 0.9)
	for i in n:
		var p := a.lerp(b, (i + 0.5) / n)
		match e:
			"fire":
				var f := particles("flame", e, 6, 0.5, true, 0.8)
				_burst_at(parent, f, p, 1.0)
			"cold":
				if i % 2 == 0:
					ice_spikes(parent, Vector3(p.x, 0, p.z), 0.6, 2, 0.8)
			"light":
				var m := particles("mote", e, 5, 0.9, true, 1.0)
				_burst_at(parent, m, p, 1.4)
			"chaos":
				var s := particles("smoke", e, 3, 0.9, true, 0.8)
				_burst_at(parent, s, p, 1.4)
	flash_light(parent, mid, col(e, 0), len * 0.6 + 3.0, 3.0, life)

# ------------------------------------------------------------------ spell moments

static func cast_flare(parent: Node3D, pos: Vector3, e: String) -> void:
	var q := quad(0.3, col(e, 0))
	q.position = pos
	parent.add_child(q)
	var tw := q.create_tween()
	tw.tween_property(q, "scale", Vector3.ONE * 3.0, 0.1).set_ease(Tween.EASE_OUT)
	tw.tween_property(q, "scale", Vector3.ONE * 0.4, 0.12)
	tw.parallel().tween_property(q, "transparency", 1.0, 0.12)
	tw.tween_callback(q.queue_free)
	var kind: String = {"fire": "ember", "cold": "frost", "lightning": "spark", "chaos": "bubble", "light": "mote"}.get(e, "spark")
	var p := particles(kind, e, 12, 0.4, true, 0.8)
	p.initial_velocity_max = minf(p.initial_velocity_max, 2.0)
	_burst_at(parent, p, pos, 0.8)

## Projectile visuals by element. Returns the root node (updated by update_bolt).
static func make_bolt(pr: Projectile) -> Node3D:
	var e := of_skill(pr.skill)
	if e == "physical":
		e = of_color(pr.color)
	var root := Node3D.new()
	root.set_meta("element", e)
	root.set_meta("age", 0.0)
	root.set_meta("color", pr.color)
	var r: float = maxf(0.25, pr.radius * IsoView.S)
	var big := String(pr.skill.get("fx3d", "")) == "ember" or pr.user is Player
	match e:
		"cold":
			var core := MeshInstance3D.new()
			var pm := PrismMesh.new()
			pm.size = Vector3(r * 0.9, r * 4.5, r * 0.9)
			core.mesh = pm
			core.material_override = ice_mat()
			core.rotation.x = -PI / 2
			core.name = "Spin"
			root.add_child(core)
			root.add_child(quad(r * 4.0, col(e, 0)))
			var tr := particles("frost", e, 24, 0.6, false, 0.6)
			tr.name = "Trail"
			root.add_child(tr)
		"lightning":
			root.add_child(quad(r * 5.0, col(e, 0)))
			var c := quad(r * 2.0, col(e, 1))
			c.name = "Glow"
			root.add_child(c)
			var tr := particles("spark", e, 30, 0.25, false, 0.7)
			tr.initial_velocity_min = 1.0
			tr.initial_velocity_max = 3.0
			tr.gravity = Vector3.ZERO
			tr.name = "Trail"
			root.add_child(tr)
		"chaos":
			var orb := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = r * 1.2
			sm.height = r * 2.4
			orb.mesh = sm
			orb.material_override = solid_glow(Color(0.12, 0.02, 0.16), 0.4)
			root.add_child(orb)
			var halo := quad(r * 5.0, col(e, 1))
			halo.name = "Glow"
			root.add_child(halo)
			root.add_child(quad(r * 3.0, col(e, 0)))
			var tr := particles("smoke", e, 20, 0.8, false, 0.6)
			tr.name = "Trail"
			root.add_child(tr)
			var bub := particles("bubble", e, 10, 0.7, false, 0.8)
			root.add_child(bub)
		"light":
			root.add_child(quad(r * 6.0, col(e, 2)))
			var c := quad(r * 2.4, col(e, 1))
			c.name = "Glow"
			root.add_child(c)
			var tr := particles("mote", e, 26, 0.7, false, 0.8)
			tr.gravity = Vector3(0, 0.2, 0)
			tr.name = "Trail"
			root.add_child(tr)
		_:   # fire and anything else
			var g := quad(maxf(0.6, r * 4.5), Color(col(e, 0), 0.9))
			g.name = "Glow"
			root.add_child(g)
			root.add_child(quad(maxf(0.25, r * 1.6), Color(1.0, 0.95, 0.85, 1.0)))
			var tr := particles("ember" if e != "fire" else "ember", e, 48, 0.4, false, 1.0)
			tr.emission_sphere_radius = 0.12
			tr.name = "Trail"
			root.add_child(tr)
			if e == "fire":
				var fl := particles("flame", e, 16, 0.25, false, 0.55)
				fl.initial_velocity_min = 0.3
				fl.initial_velocity_max = 0.8
				root.add_child(fl)
	if big:
		root.add_child(light(col(e, 0), 4.5, 2.2))
	root.position = IsoView.to3d(pr.global_position, SpellFx3D.BOLT_H)
	root.scale = Vector3.ONE * 0.3
	return root

static func update_bolt(v: Node3D, pr: Projectile, delta: float) -> void:
	var age: float = v.get_meta("age") + delta
	v.set_meta("age", age)
	var np := IsoView.to3d(pr.global_position, SpellFx3D.BOLT_H)
	var d := np - v.position
	v.position = np
	v.scale = Vector3.ONE * minf(1.0, 0.3 + age * 9.0)
	v.set_meta("fizzle", pr.travel >= pr.max_range - 1.0)
	var spin := v.get_node_or_null("Spin") as Node3D
	if spin and d.length() > 0.001:
		v.look_at(v.position + d, Vector3.UP)
	var g := v.get_node_or_null("Glow") as Node3D
	if g:
		g.scale = Vector3.ONE * (1.0 + 0.15 * sin(age * 40.0))

static func finish_bolt(parent: Node3D, v: Node3D) -> void:
	var e: String = v.get_meta("element", "fire")
	if not v.get_meta("fizzle", false):
		impact(parent, v.position, e, 1.0)
	var trail := v.get_node_or_null("Trail") as CPUParticles3D
	if trail:
		trail.emitting = false
		for ch in v.get_children():
			if ch != trail:
				ch.queue_free()
		v.get_tree().create_timer(0.8).timeout.connect(v.queue_free)
	else:
		v.queue_free()

## A hit: element-specific burst, light, and a lingering mark.
static func impact(parent: Node3D, pos: Vector3, e: String, s: float) -> void:
	var tick := Time.get_ticks_msec() / 100
	if tick != _impact_tick:
		_impact_tick = tick
		_impacts = 0
	_impacts += 1
	if _impacts > MAX_IMPACTS_PER_TICK:   # a flood of hits: keep a small spark only
		_burst_at(parent, particles("spark", e, 6, 0.3, true, 0.6), pos, 0.6)
		return
	var ground := Vector3(pos.x, 0.0, pos.z)
	match e:
		"fire":
			_burst_at(parent, particles("flame", e, 18, 0.6, true, 1.1 * s), pos, 1.2)
			_burst_at(parent, particles("spark", e, 24, 0.6, true, 1.0), pos, 1.0)
			_burst_at(parent, particles("smoke", e, 6, 1.4, true, s), pos + Vector3(0, 0.4, 0), 2.0)
			ring(parent, ground, 2.6 * s, Color(1.0, 0.55, 0.2, 0.9), 0.3)
			flash_light(parent, pos, col(e, 0), 7.0 * s, 4.0, 0.35)
			scorch(parent, ground, 1.6 * s, Color(0.05, 0.02, 0.01, 0.75))
		"cold":
			_burst_at(parent, particles("shard", e, 14, 0.8, true, 1.0 * s), pos, 1.4)
			_burst_at(parent, particles("frost", e, 8, 1.2, true, 1.2 * s), pos, 1.8)
			ice_spikes(parent, ground, 0.9 * s, 5, 0.9)
			ring(parent, ground, 2.2 * s, Color(0.7, 0.92, 1.0, 0.9), 0.35)
			flash_light(parent, pos, col(e, 0), 6.0 * s, 3.0, 0.4)
			scorch(parent, ground, 1.5 * s, Color(0.75, 0.9, 1.0, 0.45))
		"lightning":
			for k in 3:
				var a := randf() * TAU
				bolt_line(parent, [pos, pos + Vector3(cos(a) * 1.4 * s, randf_range(-0.6, 0.4), sin(a) * 1.4 * s)], e, 0.2, 1, 0.25)
			_burst_at(parent, particles("spark", e, 30, 0.45, true, 1.0), pos, 0.9)
			flash_light(parent, pos, Color(0.8, 0.85, 1.0), 8.0 * s, 6.0, 0.18)
			var q := quad(2.5 * s, col(e, 1))
			q.position = pos
			parent.add_child(q)
			_fade_free(q, 0.15, 1.5)
		"chaos":
			_burst_at(parent, particles("bubble", e, 16, 0.9, true, 1.2 * s), pos, 1.4)
			_burst_at(parent, particles("smoke", e, 10, 1.2, true, 1.1 * s), pos, 1.8)
			var q := quad(2.4 * s, col(e, 1))
			q.position = pos
			parent.add_child(q)
			var tw := q.create_tween()   # implode, then puff out
			tw.tween_property(q, "scale", Vector3.ONE * 0.3, 0.12)
			tw.tween_property(q, "scale", Vector3.ONE * 1.6, 0.2)
			tw.parallel().tween_property(q, "transparency", 1.0, 0.2)
			tw.tween_callback(q.queue_free)
			flash_light(parent, pos, col(e, 0), 6.0 * s, 3.0, 0.5)
			scorch(parent, ground, 1.6 * s, Color(0.2, 0.35, 0.05, 0.5))
		"light":
			for k in 8:   # rays
				var a := TAU * k / 8.0
				var r := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.08, 0.08, 1.6 * s)
				r.mesh = bm
				r.material_override = add_mat(Color(1.0, 0.95, 0.7, 0.9))
				r.position = pos + Vector3(cos(a), 0.0, sin(a)) * 0.8 * s
				r.rotation.y = -a + PI / 2
				parent.add_child(r)
				_fade_free(r, 0.3, 1.6)
			_burst_at(parent, particles("mote", e, 22, 1.0, true, 1.0), pos, 1.5)
			ring(parent, ground, 2.4 * s, Color(1.0, 0.9, 0.55, 0.95), 0.4, 0.05)
			flash_light(parent, pos, col(e, 1), 8.0 * s, 5.0, 0.3)
		_:
			_burst_at(parent, particles("spark", e, 16, 0.4, true, 0.8), pos, 0.8)

static func scorch(parent: Node3D, pos: Vector3, size: float, c: Color) -> void:
	var sc := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(size, size)
	sc.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = FX.glow_tex
	sm.albedo_color = c
	sc.material_override = sm
	sc.position = pos + Vector3(0, 0.06, 0)
	sc.rotation.y = randf() * TAU
	parent.add_child(sc)
	var ts := sc.create_tween()
	ts.tween_interval(2.5)
	ts.tween_property(sc, "transparency", 1.0, 2.0)
	ts.tween_callback(sc.queue_free)

## Nova around the caster: fire wave, ice spike ring, storm ring, void pulse, radiant burst.
static func nova(parent: Node3D, pos: Vector3, radius: float, e: String) -> void:
	ring(parent, pos, radius, Color(col(e, 0), 0.95), 0.4, 0.06)
	ring(parent, pos, radius * 0.7, Color(col(e, 1), 0.8), 0.3, 0.04)
	flash_light(parent, pos, col(e, 0), radius * 1.6, 5.0, 0.45)
	var n := int(clampf(radius * 6.0, 10, 40))
	for i in n:
		var a := TAU * i / n
		var p := pos + Vector3(cos(a), 0.0, sin(a)) * radius * randf_range(0.6, 1.0)
		match e:
			"fire":
				if i % 2 == 0:
					_burst_at(parent, particles("flame", e, 5, 0.5, true, 0.9), p, 1.0)
			"cold":
				pass
			"lightning":
				if i % 4 == 0:
					bolt_line(parent, [pos + Vector3(0, 1.0, 0), p + Vector3(0, 0.2, 0)], e, 0.22, 1, 0.3)
			"chaos":
				if i % 3 == 0:
					_burst_at(parent, particles("smoke", e, 3, 1.0, true, 1.0), p, 1.5)
			"light":
				if i % 3 == 0:
					_burst_at(parent, particles("mote", e, 4, 1.0, true, 1.0), p, 1.5)
	if e == "cold":
		ice_spikes(parent, pos, radius, int(radius * 5.0), 0.8)
		_burst_at(parent, particles("frost", e, 18, 1.4, true, radius * 0.5), pos, 2.0)
	elif e == "light":
		beam(parent, pos + Vector3(0, 9, 0), pos, e, 0.35, 0.4)

## Strike from above at a spot: lightning bolt, meteor, ice spear, void tendrils, sunbeam.
static func strike(parent: Node3D, pos: Vector3, radius: float, e: String) -> void:
	match e:
		"lightning":
			bolt_line(parent, [pos + Vector3(randf_range(-1, 1), 14, randf_range(-1, 1)), pos + Vector3(0, 5, 0), pos], e, 0.3, 3, 0.6)
			flash_light(parent, pos, Color(0.8, 0.85, 1.0), radius * 3.0, 8.0, 0.25)
		"light":
			beam(parent, pos + Vector3(0, 14, 0), pos, e, minf(0.45, radius * 0.18), 0.5)
			ring(parent, pos, radius, Color(1.0, 0.9, 0.55, 0.95), 0.45, 0.05)
		"fire":
			beam(parent, pos + Vector3(-4, 12, -4), pos, e, 0.5, 0.25)
		"cold":
			ice_spikes(parent, pos, radius, int(radius * 6.0), 1.2)
		"chaos":
			_burst_at(parent, particles("smoke", e, 16, 1.4, true, radius), pos, 2.0)
	impact(parent, pos + Vector3(0, 0.4, 0), e, clampf(radius / 1.5, 0.8, 2.5))

## A lingering field (Cinderfall, Withering Mire, frozen ground, consecrated ground).
static func field(e: String, radius: float) -> Node3D:
	var root := Node3D.new()
	var area := radius * radius
	match e:
		"fire":
			var f := particles("flame", e, int(clampf(area * 6.0, 12, 70)), 0.7, false, 0.9)
			f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			f.emission_sphere_radius = radius
			f.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			f.emission_ring_axis = Vector3.UP
			f.emission_ring_radius = radius * 0.9
			f.emission_ring_inner_radius = 0.0
			f.emission_ring_height = 0.1
			root.add_child(f)
			var em := particles("ember", e, 30, 1.2, false, 1.0)
			em.emission_sphere_radius = radius
			root.add_child(em)
			root.add_child(light(col(e, 0), radius * 2.2, 2.0))
		"chaos":
			var b := particles("bubble", e, int(clampf(area * 5.0, 10, 50)), 1.0, false, 1.0)
			b.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			b.emission_ring_axis = Vector3.UP
			b.emission_ring_radius = radius * 0.9
			b.emission_ring_inner_radius = 0.0
			b.emission_ring_height = 0.05
			root.add_child(b)
			var sm := particles("smoke", e, 14, 2.0, false, 1.2)
			sm.emission_sphere_radius = radius * 0.8
			root.add_child(sm)
			root.add_child(_disc(radius, Color(0.25, 0.45, 0.05, 0.55)))
			root.add_child(light(col(e, 0), radius * 2.0, 1.4))
		"cold":
			var fr := particles("frost", e, 20, 2.0, false, 1.2)
			fr.emission_sphere_radius = radius * 0.8
			root.add_child(fr)
			root.add_child(_disc(radius, Color(0.75, 0.92, 1.0, 0.5)))
			root.add_child(light(col(e, 0), radius * 2.0, 1.2))
		"light":
			var m := particles("mote", e, int(clampf(area * 4.0, 10, 50)), 1.4, false, 1.0)
			m.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			m.emission_ring_axis = Vector3.UP
			m.emission_ring_radius = radius
			m.emission_ring_inner_radius = 0.0
			m.emission_ring_height = 0.05
			root.add_child(m)
			root.add_child(_disc(radius, Color(1.0, 0.9, 0.55, 0.35)))
			root.add_child(light(col(e, 1), radius * 2.2, 1.6))
		"lightning":
			var s := particles("spark", e, 24, 0.4, false, 0.8)
			s.emission_sphere_radius = radius
			s.initial_velocity_max = 3.0
			root.add_child(s)
			root.add_child(light(col(e, 0), radius * 2.0, 1.4))
		_:
			root.add_child(_disc(radius, Color(0.5, 0.5, 0.5, 0.3)))
	root.set_meta("element", e)
	root.set_meta("radius", radius)
	return root

static func _disc(radius: float, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.2, radius * 2.2)
	mi.mesh = pm
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.albedo_texture = FX.glow_tex
	sm.albedo_color = c
	mi.material_override = sm
	mi.position.y = 0.05
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Lingering field: occasional extra flourishes (lightning crackle, ice spikes) while it lasts.
static func field_tick(parent: Node3D, f: Node3D, delta: float) -> void:
	var e: String = f.get_meta("element")
	var r: float = f.get_meta("radius")
	var t: float = f.get_meta("t", 0.0) + delta
	f.set_meta("t", t)
	if e == "lightning" and randf() < delta * 6.0:
		var a := randf() * TAU
		var p := f.position + Vector3(cos(a) * r * randf(), 0.1, sin(a) * r * randf())
		bolt_line(parent, [p + Vector3(0, 1.6, 0), p], e, 0.15, 1, 0.3)
	elif e == "cold" and randf() < delta * 2.0:
		var a := randf() * TAU
		ice_spikes(parent, f.position + Vector3(cos(a) * r * randf() * 0.8, 0, sin(a) * r * randf() * 0.8), 0.4, 2, 0.6)
