class_name SpellView3D
extends Node3D
## Element visuals for the isometric view (presentation only):
##  - spell events from the simulation (FX.spell_event): novas, chains, lances, strikes, slams, fissures...
##  - lingering ground fields (GroundEffect) drawn as fire / blight / frost / radiance / sparks
##  - ailments on every actor: burning, frozen, chilled, shocked, poisoned, blinded
##  - rare monster auras and the Hollow King's soulfire and crown
##  - Chapter 1 region moods (fog, sun, ambient) blended as you walk

var iv: IsoView
var fields := {}        # GroundEffect -> Node3D
var status := {}        # Actor -> {root, parts}
var gate_fx: Node3D

func setup(view: IsoView) -> void:
	iv = view
	FX.spell_event.connect(_on_event)

func _p(pos: Vector2, h: float = 0.0) -> Vector3:
	return IsoView.to3d(pos, h)

# ------------------------------------------------------------------ events

func _on_event(kind: String, pos: Vector2, e: String, radius: float, extra: Dictionary) -> void:
	if not iv.active:
		return
	var r := radius * IsoView.S
	match kind:
		"nova":
			ElementFx.nova(self, _p(pos), maxf(1.0, r), e)
		"chain":
			var pts: Array = []
			for q in extra.get("points", []):
				pts.append(_p(q, 1.1))
			if pts.size() >= 2:
				if e == "chaos":
					for i in pts.size() - 1:
						ElementFx.beam(self, pts[i], pts[i + 1], e, 0.12, 0.35)
					for i in range(1, pts.size()):
						ElementFx.impact(self, pts[i], e, 0.6)
				else:
					ElementFx.bolt_line(self, pts, e, 0.3, 3, 0.4)
					for i in range(1, pts.size()):
						ElementFx.impact(self, pts[i], e, 0.7)
		"lance":
			var a := _p(pos, 1.1)
			var b := _p(extra.get("end", pos), 1.1)
			ElementFx.beam(self, a, b, e, maxf(0.25, r * 0.35), 0.45)
			ElementFx.impact(self, b, e, 1.1)
			ElementFx.cast_flare(self, a, e)
		"prison":
			ElementFx.ice_spikes(self, _p(pos), maxf(0.8, r), 14, 2.6)
			ElementFx.impact(self, _p(pos, 0.8), "cold", 1.0)
		"blink":
			ElementFx.impact(self, _p(pos, 0.9), e, 0.9)
			ElementFx.impact(self, _p(extra.get("to", pos), 0.9), e, 0.9)
		"strike":
			ElementFx.strike(self, _p(pos), maxf(0.8, r), e)
		"slam":
			_slam(_p(pos), maxf(1.0, r), e)
		"spin":
			ElementFx.ring(self, _p(pos), maxf(1.0, r), Color(0.75, 0.9, 1.0, 0.95), 0.35, 0.12)
			_slam(_p(pos), maxf(1.0, r) * 0.6, "cold")
		"fissure":
			var d: Vector2 = extra.get("dir", Vector2.RIGHT)
			var L: float = float(extra.get("length", 600.0))
			_fissure(pos, d, L, radius, e)
		"rime_ring":
			ElementFx.nova(self, _p(pos), maxf(1.0, float(extra.get("inner", 0.0)) * IsoView.S + 6.0), "cold")
			ElementFx.ice_spikes(self, _p(pos), maxf(1.0, r), int(r * 4.0), 1.0)
		"summon":
			ElementFx.impact(self, _p(pos, 0.3), e, 1.0)
			ElementFx.ice_spikes(self, _p(pos), 1.2, 6, 0.8)
		"boss_rise":
			ElementFx.nova(self, _p(pos), 6.0, "cold")
			ElementFx.strike(self, _p(pos), 2.5, "lightning")
		"leap":
			ElementFx.impact(self, _p(pos, 0.5), "cold", 2.0)
			var to: Vector2 = extra.get("to", pos)
			get_tree().create_timer(0.5).timeout.connect(func():
				_slam(_p(to), 5.0, "cold")
				ElementFx.nova(self, _p(to), 8.0, "cold"))
		"gate":
			_gate(extra)
		"cache":
			ElementFx.nova(self, _p(pos), 2.0, "light")
			var c3 := _chapter3d()
			if c3:
				c3.open_cache(pos)
		"impact":
			ElementFx.impact(self, _p(pos, 0.6), e, maxf(0.6, r * 0.5))
		# 2D effects translated to 3D while the view is on (FX.iso3d)
		"burst", "rise":
			var c: Color = extra.color
			var p := CPUParticles3D.new()
			p.amount = clampi(int(extra.count), 4, 40)
			p.lifetime = float(extra.life) * 1.4
			p.one_shot = true
			p.explosiveness = 0.95 if kind == "burst" else 0.5
			p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			p.emission_sphere_radius = 0.2 if kind == "burst" else maxf(0.15, radius * IsoView.S)
			p.direction = Vector3.UP
			p.spread = 180.0 if kind == "burst" else 25.0
			var sp := (radius * IsoView.S) if kind == "burst" else 1.2
			p.initial_velocity_min = sp * 0.3
			p.initial_velocity_max = sp
			p.damping_min = sp * 0.8
			p.damping_max = sp * 1.6
			p.gravity = Vector3(0, -2.0, 0) if kind == "burst" else Vector3(0, -float(extra.gravity) * IsoView.S * 0.6, 0)
			var q := QuadMesh.new()
			var qs := clampf(float(extra.size) * 0.03, 0.08, 0.5)
			q.size = Vector2(qs, qs)
			q.material = IsoView.glow_material(Color.WHITE)
			p.mesh = q
			p.color_ramp = ElementFx._ramp([c.lightened(0.4), c, Color(c.r, c.g, c.b, 0.0)])
			ElementFx._burst_at(self, p, _p(pos, 0.8), p.lifetime + 0.3)
		"spark":
			var a3 := _p(pos, 0.9)
			var d3 := Vector3(randf_range(-1, 1), randf_range(-0.4, 0.4), randf_range(-1, 1)).normalized() * radius * IsoView.S * 0.5
			ElementFx.bolt_line(self, [a3 - d3, a3 + d3], "lightning", 0.15, 1, 0.1)
		"ring":
			var cc: Color = extra.color
			ElementFx.ring(self, _p(pos), maxf(0.4, r), Color(cc.r, cc.g, cc.b, 0.85), float(extra.duration), 0.06)
		"flash":
			var fc: Color = extra.color
			var q2 := ElementFx.quad(maxf(0.5, r * 1.2), fc)
			q2.position = _p(pos, 0.9)
			add_child(q2)
			ElementFx._fade_free(q2, float(extra.duration) + 0.05, 1.3)
			if radius >= 60.0:
				ElementFx.flash_light(self, _p(pos), fc, r * 2.2, 2.0, float(extra.duration) + 0.1)

func _chapter3d() -> Chapter3D:
	if iv.level:
		return iv.level.get_node_or_null("Chapter3D") as Chapter3D
	return null

## A heavy ground slam: dust, rocks, cracked ground, shockwave.
func _slam(pos: Vector3, r: float, e: String) -> void:
	ElementFx.ring(self, pos, r * 1.2, Color(0.85, 0.8, 0.72, 0.9), 0.35, 0.1)
	var dust := ElementFx.particles("smoke", "physical", 14, 1.2, true, r * 0.5)
	dust.color_ramp = ElementFx._ramp([Color(0.45, 0.4, 0.35, 0), Color(0.45, 0.4, 0.35, 0.5), Color(0.45, 0.4, 0.35, 0)])
	ElementFx._burst_at(self, dust, pos + Vector3(0, 0.3, 0), 2.0)
	var rocks := ElementFx.particles("shard", "physical", 12, 0.9, true, 1.4)
	var pm := PrismMesh.new()
	pm.size = Vector3(0.18, 0.18, 0.18)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.32, 0.3, 0.28)
	pm.material = rm
	rocks.mesh = pm
	ElementFx._burst_at(self, rocks, pos + Vector3(0, 0.2, 0), 1.5)
	ElementFx.scorch(self, pos, r * 2.0, Color(0.06, 0.05, 0.04, 0.7))
	if e == "cold":
		ElementFx.ice_spikes(self, pos, r * 0.8, int(r * 3.0), 0.7)
	ElementFx.flash_light(self, pos, ElementFx.col(e, 0), r * 3.0, 3.0, 0.3)

func _fissure(start: Vector2, dir: Vector2, length: float, width: float, e: String) -> void:
	var n := int(length / 60.0)
	for i in n:
		var p := start + dir * (i + 0.5) * length / n
		var t := float(i) / n
		get_tree().create_timer(t * 0.35).timeout.connect(func():
			var p3 := _p(p)
			ElementFx.ice_spikes(self, p3, width * IsoView.S * 0.5, 3, 0.7)
			ElementFx.scorch(self, p3, width * IsoView.S * 1.3, Color(0.04, 0.05, 0.07, 0.75))
			if i % 3 == 0:
				ElementFx.impact(self, p3 + Vector3(0, 0.3, 0), e, 0.7))

## The soulfire wall that seals the boss arena.
func _gate(extra: Dictionary) -> void:
	if not extra.get("on", false):
		if gate_fx and is_instance_valid(gate_fx):
			for c in gate_fx.get_children():
				if c is CPUParticles3D:
					c.emitting = false
			get_tree().create_timer(2.0).timeout.connect(gate_fx.queue_free)
		return
	gate_fx = Node3D.new()
	add_child(gate_fx)
	var a: Vector2 = extra.a
	var b: Vector2 = extra.b
	for i in 9:
		var p := a.lerp(b, i / 8.0)
		var f := ElementFx.particles("flame", "cold", 18, 0.9, false, 1.6)
		f.position = _p(p, 0.2)
		f.emission_sphere_radius = 0.7
		f.color_ramp = ElementFx._ramp([Color(0.8, 0.95, 1, 0), Color(0.6, 0.85, 1, 1), Color(0.3, 0.5, 1.0, 0.8), Color(0.1, 0.15, 0.4, 0)])
		gate_fx.add_child(f)
		if i % 3 == 1:
			var l := ElementFx.light(Color(0.5, 0.8, 1.0), 7.0, 2.5)
			l.position = _p(p, 1.5)
			gate_fx.add_child(l)

# ------------------------------------------------------------------ fields

func _sync_fields(delta: float) -> void:
	var live := {}
	for c in iv.game.fx_node.get_children():
		if c is GroundEffect and not c.is_queued_for_deletion():
			live[c] = true
			c.visible = false   # the 3D field replaces the flat circle
			var f: Node3D = fields.get(c)
			if f == null:
				var e := ElementFx.of_skill(c.skill)
				f = ElementFx.field(e, c.radius * IsoView.S)
				f.position = IsoView.to3d(c.global_position, 0.05)
				add_child(f)
				fields[c] = f
			ElementFx.field_tick(self, f, delta)
	for g in fields.keys():
		if not live.has(g):
			var f: Node3D = fields[g]
			fields.erase(g)
			for ch in f.get_children():
				if ch is CPUParticles3D:
					ch.emitting = false
				elif ch is GeometryInstance3D or ch is Light3D:
					ElementFx._fade_free(ch, 0.6)
			get_tree().create_timer(2.5).timeout.connect(f.queue_free)

# ------------------------------------------------------------------ ailments, auras

func _part(st: Dictionary, key: String, make: Callable) -> Node3D:
	if not st.parts.has(key):
		var n: Node3D = make.call()
		st.root.add_child(n)
		st.parts[key] = n
	return st.parts[key]

static func _on(n: Node3D, on: bool) -> void:
	if n is CPUParticles3D:
		(n as CPUParticles3D).emitting = on
	else:
		n.visible = on

func _ice_shell(h: float, w: float) -> Node3D:
	var root := Node3D.new()
	for i in 9:
		var m := MeshInstance3D.new()
		var pm := PrismMesh.new()
		var hh := h * randf_range(0.45, 0.95)
		pm.size = Vector3(w * 0.55, hh, w * 0.55)
		m.mesh = pm
		m.material_override = ElementFx.ice_mat()
		var a := TAU * i / 9.0
		m.position = Vector3(cos(a) * w * 0.5, hh * 0.5, sin(a) * w * 0.5)
		m.rotation = Vector3(sin(a) * 0.25, randf() * TAU, -cos(a) * 0.25)
		root.add_child(m)
	return root

func _aura_ring(c: Color, r: float) -> Node3D:
	var root := Node3D.new()
	var m := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r * 0.9
	tm.outer_radius = r
	tm.rings = 48
	tm.ring_segments = 4
	m.mesh = tm
	m.material_override = ElementFx.add_mat(Color(c.r, c.g, c.b, 0.85))
	m.scale = Vector3(1, 0.05, 1)
	m.position.y = 0.06
	m.name = "Ring"
	root.add_child(m)
	var motes := ElementFx.particles("mote", "light", 16, 1.6, false, 1.0)
	motes.color_ramp = ElementFx._ramp([Color(c.r, c.g, c.b, 0), c, Color(c.r, c.g, c.b, 0)])
	motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	motes.emission_ring_axis = Vector3.UP
	motes.emission_ring_radius = r
	motes.emission_ring_inner_radius = r * 0.8
	motes.emission_ring_height = 0.05
	motes.local_coords = true
	root.add_child(motes)
	var l := ElementFx.light(c, r * 3.0, 1.4)
	l.position.y = 1.2
	root.add_child(l)
	return root

func _crown(r: float) -> Node3D:
	var root := Node3D.new()
	for i in 7:
		var m := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.12, 0.45 if i % 2 == 0 else 0.3, 0.12)
		m.mesh = pm
		m.material_override = ElementFx.solid_glow(Color(0.55, 0.85, 1.0), 4.0)
		var a := TAU * i / 7.0
		m.position = Vector3(cos(a) * r, 0, sin(a) * r)
		m.rotation = Vector3(sin(a) * 0.3, 0, -cos(a) * 0.3)
		root.add_child(m)
	var l := ElementFx.light(Color(0.5, 0.8, 1.0), 6.0, 2.0)
	root.add_child(l)
	return root

func _sync_status(delta: float) -> void:
	var live := {}
	for a in iv.puppets:
		var pup: Puppet = iv.puppets[a]
		if not is_instance_valid(a) or not pup.visible:
			continue
		var actor := a as Actor
		var en := actor as Enemy
		var want: bool = not actor.dead and (actor.ignite_time > 0.0 or actor.frozen_time > 0.0 or actor.chill_time > 0.0 \
			or actor.shock_time > 0.0 or not actor.poisons.is_empty() or actor.blind_time > 0.0 \
			or (en != null and (en.rare != null or (en.is_boss() and en.def.get("brain", "") == "king"))))
		if not want and not status.has(actor):
			continue
		live[actor] = true
		var st: Dictionary = status.get(actor, {})
		if st.is_empty():
			var root := Node3D.new()
			add_child(root)
			st = {"root": root, "parts": {}, "t": 0.0}
			status[actor] = st
		var root: Node3D = st.root
		root.position = pup.position
		var h := pup.height
		var w := maxf(0.6, actor.radius * IsoView.S * 1.2)
		st.t += delta
		# Burning: flames lick up the body
		var burn := _part(st, "burn", func():
			var f := ElementFx.particles("flame", "fire", 22, 0.55, false, 0.9)
			f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			f.emission_box_extents = Vector3(w * 0.4, h * 0.35, w * 0.4)
			f.position.y = h * 0.4
			return f)
		_on(burn, actor.ignite_time > 0.0 and not actor.dead)
		# Frozen: encased in ice
		var ice := _part(st, "frozen", func(): return _ice_shell(h * 1.05, w))
		_on(ice, actor.frozen_time > 0.0 and not actor.dead)
		# Chilled: frost breath around the legs
		var chill := _part(st, "chill", func():
			var f := ElementFx.particles("frost", "cold", 8, 1.4, false, 0.8)
			f.position.y = 0.3
			f.emission_sphere_radius = w * 0.5
			return f)
		_on(chill, (actor.chill_time > 0.0 or actor.frozen_time > 0.0) and not actor.dead)
		# Shocked: arcs crawl over the body
		var shock := _part(st, "shock", func():
			var f := ElementFx.particles("spark", "lightning", 14, 0.25, false, 0.7)
			f.position.y = h * 0.5
			f.emission_sphere_radius = w * 0.5
			f.initial_velocity_min = 0.5
			f.initial_velocity_max = 2.0
			f.gravity = Vector3.ZERO
			return f)
		var shocked := actor.shock_time > 0.0 and not actor.dead
		_on(shock, shocked)
		if shocked and randf() < delta * 5.0:
			var a1 := root.position + Vector3(randf_range(-w, w) * 0.5, h * randf_range(0.2, 0.9), randf_range(-w, w) * 0.5)
			ElementFx.bolt_line(self, [a1, a1 + Vector3(randf_range(-0.6, 0.6), randf_range(-0.5, 0.5), randf_range(-0.6, 0.6))], "lightning", 0.12, 1, 0.12)
		# Poisoned: bubbles and drips
		var poison := _part(st, "poison", func():
			var f := ElementFx.particles("bubble", "chaos", 10, 0.9, false, 0.8)
			f.position.y = h * 0.6
			f.emission_sphere_radius = w * 0.45
			f.gravity = Vector3(0, -1.2, 0)
			return f)
		_on(poison, not actor.poisons.is_empty() and not actor.dead)
		# Blinded: golden motes circle the head
		var blind := _part(st, "blind", func():
			var f := ElementFx.particles("mote", "light", 10, 0.8, false, 1.0)
			f.position.y = h * 0.95
			f.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
			f.emission_ring_axis = Vector3.UP
			f.emission_ring_radius = w * 0.45
			f.emission_ring_inner_radius = w * 0.35
			f.emission_ring_height = 0.05
			return f)
		_on(blind, actor.blind_time > 0.0 and not actor.dead)
		# Rares: an aura in the colour of their first ability
		if en and en.rare:
			var aura := _part(st, "aura", func(): return _aura_ring(en.rare.aura_color(), w * 1.25))
			_on(aura, not actor.dead)
			var ring := aura.get_node_or_null("Ring") as Node3D
			if ring:
				ring.rotation.y += delta * 0.8
				var sh: float = en.rare.shield
				ring.scale = Vector3(1, 0.05, 1) * (1.0 + (0.25 if sh > 0.0 else 0.0) + 0.05 * sin(st.t * 4.0))
			if en.rare.has("infernal") and not actor.dead:
				var inf := _part(st, "infernal", func():
					var f := ElementFx.field("fire", 170.0 * IsoView.S * 0.55)
					return f)
				_on(inf, true)
		# The Hollow King: soulfire on his shoulders, a floating crown
		if en and en.is_boss() and en.def.get("brain", "") == "king":
			var sf := _part(st, "soulfire", func():
				var f := ElementFx.particles("flame", "cold", 40, 0.8, false, 1.6)
				f.color_ramp = ElementFx._ramp([Color(0.8, 0.95, 1, 0), Color(0.6, 0.85, 1, 1), Color(0.3, 0.5, 1.0, 0.8), Color(0.1, 0.15, 0.4, 0)])
				f.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
				f.emission_box_extents = Vector3(w * 0.45, 0.2, w * 0.25)
				f.position.y = h * 0.78
				return f)
			_on(sf, not actor.dead)
			var cr := _part(st, "crown", func(): return _crown(w * 0.28))
			cr.position.y = h * 1.02 + sin(st.t * 2.0) * 0.06
			cr.rotation.y += delta * 0.6
			_on(cr, not actor.dead)
			var dark := _part(st, "ground", func(): return _aura_ring(Color(0.45, 0.75, 1.0), w * 1.6))
			_on(dark, not actor.dead)
	for a in status.keys():
		if not live.has(a):
			var st: Dictionary = status[a]
			status.erase(a)
			for n in st.parts.values():
				_on(n, false)
			get_tree().create_timer(1.5).timeout.connect(st.root.queue_free)

# ------------------------------------------------------------------ region mood (Chapter 1)

var _mood_k := 0.0
func _mood(delta: float) -> void:
	var z: Zone = iv.game.zone
	if z == null or not z.is_chapter:
		return
	var R: Dictionary = ChapterDB.REGIONS[z.region_at(iv._target)]
	var k := minf(1.0, delta * 0.8)
	var fog: Color = R.fog
	iv.env.fog_light_color = iv.env.fog_light_color.lerp(fog, k)
	iv.env.background_color = iv.env.background_color.lerp(fog.darkened(0.65), k)
	iv.env.ambient_light_color = iv.env.ambient_light_color.lerp(R.ambient, k)
	iv.sun.light_color = iv.sun.light_color.lerp(R.sun, k)
	iv.sun.light_energy = lerpf(iv.sun.light_energy, float(R.get("sun_energy", 1.2)), k)
	var want_fog := 0.0055 if R.id == "mirefen" else (0.0045 if R.id == "barrow" else 0.0035)
	iv.env.fog_density = lerpf(iv.env.fog_density, want_fog, k)

func update(delta: float) -> void:
	FX.iso3d = true
	for c in iv.game.fx_node.get_children():
		if c is LightningFX:
			c.visible = false   # chains are drawn in 3D from their spell event
		elif c is Hazard and c.has_meta("stats") and c.user is Player:
			c.visible = false   # your own sky strikes need no warning circle
	_sync_fields(delta)
	_sync_status(delta)
	_mood(delta)
