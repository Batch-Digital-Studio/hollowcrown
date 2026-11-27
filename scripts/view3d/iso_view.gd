class_name IsoView
extends Node3D
## The fixed isometric 3D presentation. The simulation stays 2D (x, y in pixels); this view
## maps it to 3D (x * S, height, y * S), renders KayKit models behind the 2D canvas, and sets the
## 2D canvas transform to the exact ground-plane projection of the 3D camera. Because the
## camera is orthographic that projection is affine, so 2D ground effects (telegraphs, rings,
## novas, loot beams) land on the 3D floor and mouse aim (get_global_mouse_position) stays correct.
## Presentation only: nothing here writes to the simulation.

const S := 1.0 / 32.0          # 64 px cell = 2 units
const YAW := deg_to_rad(45.0)
const PITCH := deg_to_rad(52.0) # camera elevation
const SIZE := 17.0              # orthographic view height in units
const UPRIGHT := ["Chest", "Reliquary", "BloodAltar", "BoundEmber", "Peddler", "TownNPC", "Pickup", "CurrencyPickup"]

static var active := false
static var instance: IsoView
static var up_x := Vector2(1, 0)    # columns of the "stand upright" matrix for 2D world nodes
static var up_y := Vector2(0, 1)
static var _inv := Transform2D.IDENTITY   # screen direction -> world px direction
static var _R := Vector3.RIGHT
static var _U := Vector3.UP
static var _k := 1.0
static var _T := Vector3.ZERO
static var _center := Vector2.ZERO
static var _glow_mats := {}

var game: Game
var cam: Camera3D
var env: Environment
var sun: DirectionalLight3D
var level: Level3D
var puppets := {}         # Actor -> Puppet
var bolts := {}           # Projectile -> Node3D
var light_pool: Array = []
var ash: CPUParticles3D
var _target := Vector2.ZERO
var _have_target := false
var _sprites_hidden := {}

static func to3d(p: Vector2, h: float = 0.0) -> Vector3:
	return Vector3(p.x * S, h, p.y * S)

## Screen position (canvas pixels) of a 3D point. Valid while the view is active.
static func screen_of(v: Vector3) -> Vector2:
	var d := v - _T
	return _center + _k * Vector2(d.dot(_R), -d.dot(_U))

## A screen-space direction expressed in world px (so "up on screen" moves up on screen).
static func screen_to_world_dir(v: Vector2) -> Vector2:
	return _inv.basis_xform(v) if active else v

## Height of an actor's head in the 3D view (for bars and labels).
static func head_height(a: Actor) -> float:
	if instance and instance.puppets.has(a):
		return (instance.puppets[a] as Puppet).height
	return 2.0

static func glow_material(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if _glow_mats.has(key):
		return _glow_mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_color = c
	m.albedo_texture = FX.glow_tex
	m.no_depth_test = false
	_glow_mats[key] = m
	return m

func _ready() -> void:
	instance = self
	game = get_parent() as Game
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.01, 0.008, 0.015)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.32, 0.3, 0.4)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.05, 0.08)
	env.fog_density = 0.012
	env.glow_enabled = true
	env.glow_intensity = 0.7
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 0.9
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		# Forward+ extras (the Compatibility fallback simply goes without)
		env.ssao_enabled = true
		env.ssao_radius = 1.2
		env.ssao_intensity = 1.6
		env.ssil_enabled = true
		env.glow_intensity = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = Color(0.55, 0.6, 0.85)
	sun.light_energy = 0.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 45.0
	sun.rotation = Vector3(deg_to_rad(-62.0), deg_to_rad(20.0), 0.0)
	add_child(sun)
	cam = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = SIZE
	cam.near = 0.1
	cam.far = 160.0
	add_child(cam)
	for i in 14:
		var l := OmniLight3D.new()
		l.visible = false
		l.shadow_enabled = false
		add_child(l)
		light_pool.append(l)
	ash = CPUParticles3D.new()
	ash.amount = 160
	ash.lifetime = 6.0
	ash.preprocess = 6.0
	ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	ash.emission_box_extents = Vector3(16, 0.5, 16)
	ash.direction = Vector3(0.3, -1, 0.15)
	ash.spread = 25.0
	ash.initial_velocity_min = 0.4
	ash.initial_velocity_max = 0.9
	ash.gravity = Vector3(0.15, -0.25, 0.05)
	ash.scale_amount_min = 0.4
	ash.scale_amount_max = 1.0
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	q.material = glow_material(Color(1.0, 0.6, 0.35, 0.55))
	ash.mesh = q
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.5, 0.2, 0.0))
	g.add_point(0.15, Color(1.0, 0.55, 0.25, 0.8))
	g.add_point(0.6, Color(0.6, 0.55, 0.55, 0.5))
	g.set_color(g.get_point_count() - 1, Color(0.4, 0.4, 0.42, 0.0))
	ash.color_ramp = g
	ash.local_coords = false
	add_child(ash)

## Turn the view on/off (pause menu toggle, --2d flag).
func set_active(on: bool) -> void:
	active = on
	visible = on
	cam.current = on
	game.camera.enabled = not on
	if not on:
		game.camera.make_current()
		get_viewport().canvas_transform = Transform2D.IDENTITY
		_inv = Transform2D.IDENTITY
		PlayerInput.view_inv = Transform2D.IDENTITY
		up_x = Vector2(1, 0)
		up_y = Vector2(0, 1)
		for n in _sprites_hidden:
			if is_instance_valid(n):
				n.visible = true
		_sprites_hidden.clear()
		for ch in _upright_nodes():
			ch.transform = Transform2D(0.0, ch.position)
	if game.zone:
		game.zone.visible = not on
	game.light_root.visible = not on
	game.ambient.visible = not on
	game.world_layer.modulate = Color(0.85, 0.82, 0.88) if on else Color.WHITE
	_have_target = false
	if on:
		_update_camera(0.0)
		_upright()

func center_world() -> Vector2:
	return _target

## Rebuild the 3D level for a new zone.
func build(z: Zone) -> void:
	for a in puppets.keys():
		puppets[a].queue_free()
	puppets.clear()
	for p in bolts.keys():
		bolts[p].queue_free()
	bolts.clear()
	if level:
		level.queue_free()
	level = Level3D.new()
	add_child(level)
	level.build(z)
	z.visible = not active
	var b: Dictionary = z.biome
	var bg: Color = b.get("bg", Color(0.01, 0.01, 0.015))
	env.background_color = bg.darkened(0.3)
	var amb: Color = b.get("ambient", Color(0.42, 0.39, 0.46))
	env.ambient_light_color = amb
	env.ambient_light_energy = 0.55 if z.biome_id in ["crypt", "castle", "cave", "volcanic"] else 0.8
	if z.is_town:
		env.ambient_light_energy = 0.7
	env.fog_light_color = bg.lightened(0.05)
	env.fog_density = 0.014 if z.biome_id == "crypt" else 0.008
	if z.is_slice:   # Whisperwood dusk, from the shared layout
		var md: Dictionary = z.slice.mood
		var fc: Array = md.fog_color
		var am: Array = md.ambient
		var sc: Array = md.sun_color
		env.background_color = Color(fc[0], fc[1], fc[2]).darkened(0.6)
		env.fog_light_color = Color(fc[0], fc[1], fc[2])
		env.fog_density = 0.012
		env.ambient_light_color = Color(am[0], am[1], am[2])
		env.ambient_light_energy = 0.7
		sun.light_color = Color(sc[0], sc[1], sc[2])
		sun.light_energy = 1.1
		sun.rotation = Vector3(deg_to_rad(-float(md.sun_pitch_deg)), deg_to_rad(float(md.sun_yaw_deg)), 0.0)
		_leaves(true)
		_have_target = false
		return
	_leaves(false)
	ash.emitting = z.biome_id in ["crypt", "volcanic"]
	ash.visible = ash.emitting
	sun.light_energy = 0.35 if z.biome_id in ["crypt", "castle", "cave", "volcanic"] else 0.7
	_have_target = false

## Falling leaves around the camera (Whisperwood); reuses the ash emitter's settings.
func _leaves(on: bool) -> void:
	var q := ash.mesh as QuadMesh
	if on:
		q.size = Vector2(0.22, 0.16)
		q.material = _leaf_mat()
		ash.amount = 90
		ash.direction = Vector3(0.6, -1, 0.3)
		ash.initial_velocity_min = 0.6
		ash.initial_velocity_max = 1.2
		ash.angular_velocity_min = -180.0
		ash.angular_velocity_max = 180.0
		ash.emitting = true
		ash.visible = true
	else:
		q.size = Vector2(0.12, 0.12)
		q.material = glow_material(Color(1.0, 0.6, 0.35, 0.55))
		ash.amount = 160

var _leafm: StandardMaterial3D
func _leaf_mat() -> StandardMaterial3D:
	if _leafm == null:
		_leafm = StandardMaterial3D.new()
		_leafm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_leafm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_leafm.vertex_color_use_as_albedo = true
		_leafm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_leafm.albedo_color = Color(0.75, 0.45, 0.18)
	return _leafm

func _process(delta: float) -> void:
	if not active or game == null:
		return
	_update_camera(delta)
	_sync_puppets(delta)
	_sync_bolts(delta)
	_sync_lights()
	_upright()

func _update_camera(delta: float) -> void:
	var want: Vector2 = game.camera.global_position
	if not _have_target:
		_target = want
		_have_target = true
	_target = _target.lerp(want, minf(1.0, delta * 9.0))
	var t3 := to3d(_target)
	var dir := Vector3(sin(YAW) * cos(PITCH), sin(PITCH), cos(YAW) * cos(PITCH))
	cam.global_position = t3 + dir * 60.0
	cam.look_at(t3, Vector3.UP)
	var shake: Vector2 = game.camera.offset
	var vis := get_viewport().get_visible_rect().size
	_k = vis.y / SIZE
	cam.h_offset = shake.x / _k
	cam.v_offset = -shake.y / _k
	_R = cam.global_basis.x
	_U = cam.global_basis.y
	_T = t3 + _R * cam.h_offset + _U * cam.v_offset
	_center = vis * 0.5
	# canvas: world px -> screen px, the exact ground-plane projection of the camera
	var xa := _k * S * Vector2(_R.x, -_U.x)
	var ya := _k * S * Vector2(_R.z, -_U.z)
	var origin := _center - _k * Vector2(_T.dot(_R), -_T.dot(_U))
	var ct := Transform2D(xa, ya, origin)
	get_viewport().canvas_transform = ct
	_inv = Transform2D(xa, ya, Vector2.ZERO).affine_inverse()
	PlayerInput.view_inv = _inv
	# upright: undo the ground projection's linear part (unit scale on screen)
	up_x = _inv.x
	up_y = _inv.y
	ash.global_position = t3 + Vector3(0, 7.0, 0)

# ---------- actors ----------

func _sync_puppets(delta: float) -> void:
	var live := {}
	# every actor in the world, including corpses (dead monsters leave game.enemies but stay
	# in the world until they expire, so their death animation can play out)
	var list: Array = []
	for c in game.world_layer.get_children():
		if c is Actor:
			list.append(c)
	for c in game.allies:
		if is_instance_valid(c) and c.get_parent() != game.world_layer:
			list.append(c)
	for a in list:
		if not is_instance_valid(a) or not a.is_inside_tree():
			continue
		live[a] = true
		var p: Puppet = puppets.get(a)
		if p == null:
			p = _make_puppet(a)
			puppets[a] = p
		_hide_sprites(a)
		# off-screen models stop animating and drawing (cheap on big packs)
		var far: bool = (a.global_position as Vector2).distance_squared_to(_target) > 1250.0 * 1250.0
		p.visible = not far
		if p.ap:
			p.ap.active = not far
		if not far:
			p.update(delta)
	for a in puppets.keys():
		if not live.has(a):
			puppets[a].queue_free()
			puppets.erase(a)

func _make_puppet(a: Actor) -> Puppet:
	var p := Puppet.new()
	add_child(p)
	var def := {}
	var size := 0.85
	if a is Player:
		def = ModelsDB.for_class((a as Player).class_id)
		size = 0.82
	elif a is Enemy:
		var e := a as Enemy
		def = ModelsDB.for_enemy(e.type_id)
		size = clampf(0.55 + e.radius / 40.0, 0.7, 2.6) * float(def.get("scale", 1.0))
		if e.is_boss():
			size = clampf(e.radius / 30.0, 1.8, 2.6)
		if e.rarity == "rare":
			size *= 1.12
	elif a is Minion:
		var m := a as Minion
		if m.kind == "hawk":
			def = {"wisp": true, "color": Color(0.7, 0.9, 1.0)}
		else:
			def = ModelsDB.for_minion(m.kind)
		size = 0.7
	else:
		def = {"prop": Level3D.path_for("pillar_decorated"), "prop_scale": Vector3(0.28, 0.35, 0.28)}
	p.setup(a, def, size)
	return p

## The 2D sprite children of actors are replaced by the 3D models.
func _hide_sprites(a: Actor) -> void:
	for c in a.get_children():
		if (c is AnimatedSprite2D or c is Sprite2D) and c.visible:
			c.visible = false
			_sprites_hidden[c] = true

# ---------- projectiles ----------

func _sync_bolts(delta: float) -> void:
	var live := {}
	for c in game.fx_node.get_children():
		if c is Projectile and not c.is_queued_for_deletion():
			live[c] = true
			var v: Node3D = bolts.get(c)
			if v == null:
				v = SpellFx3D.make_bolt(c)
				add_child(v)
				bolts[c] = v
			c.visible = false
			SpellFx3D.update_bolt(v, c, delta)
	for p in bolts.keys():
		if not live.has(p):
			var v: Node3D = bolts[p]
			bolts.erase(p)
			SpellFx3D.finish_bolt(self, v)

# ---------- lights ----------

## Mirror the 2D lights (torches, braziers, spell flashes, the player's light) as 3D omni lights,
## nearest to the camera first.
func _sync_lights() -> void:
	var cands: Array = []
	var t := _target
	for l in get_tree().get_nodes_in_group("light2d"):
		if not is_instance_valid(l) or not l.enabled or l.energy < 0.03 or not l.is_inside_tree():
			continue
		var d: float = (l.global_position as Vector2).distance_squared_to(t)
		if d > 1400.0 * 1400.0:
			continue
		cands.append([d, l])
	cands.sort_custom(func(a, b): return a[0] < b[0])
	for i in light_pool.size():
		var o: OmniLight3D = light_pool[i]
		if i >= cands.size():
			o.visible = false
			continue
		var l: PointLight2D = cands[i][1]
		o.visible = true
		o.global_position = to3d(l.global_position, 1.8)
		o.light_color = l.color
		o.omni_range = l.texture_scale * 128.0 * S * 0.9
		o.light_energy = l.energy * 1.2
		o.omni_attenuation = 1.4

# ---------- upright 2D props ----------

func _upright_nodes() -> Array:
	var out: Array = []
	for parent in [game.fx_node, game.world_layer]:
		for ch in parent.get_children():
			if ch is Actor or not (ch is Node2D):
				continue
			var sc: Script = ch.get_script()
			if sc and UPRIGHT.has(sc.get_global_name()):
				out.append(ch)
	return out

func _upright() -> void:
	for ch in _upright_nodes():
		ch.transform = Transform2D(up_x, up_y, ch.position)
