class_name Puppet
extends Node3D
## A 3D stand-in for one Actor in the isometric view. Reads the actor's state every frame
## (position, facing, velocity, busy_time, hit_flash, dead, act_serial) and picks animations.
## Presentation only: it never writes to the actor.

const LOOPS := ["Idle", "Idle_B", "Idle_Combat", "Running_A", "Running_B", "Running_C", "Walking_A", "Spellcasting", "2H_Melee_Idle", "Blocking"]

static var _scenes := {}

var actor: Actor
var model: Node3D
var ap: AnimationPlayer
var height := 2.0
var tint := Color.WHITE
var kind := "model"        # model / wisp / totem
var _cur := ""
var _lock := 0.0           # a one-shot (attack, hit) is playing
var _serial := 0
var _last_flash := 0.0
var _died := false
var _yaw := 0.0
var _meshes: Array = []
var _mat_flash: StandardMaterial3D
var _overlay_state := -1
var _is_skeleton := false
var _wisp: MeshInstance3D

static func scene(path: String) -> PackedScene:
	if not _scenes.has(path):
		_scenes[path] = load(path)
	return _scenes[path]

func setup(a: Actor, def: Dictionary, size: float) -> void:
	actor = a
	_serial = a.act_serial
	tint = def.get("tint", Color.WHITE)
	if def.get("wisp", false):
		kind = "wisp"
		_build_wisp(def.get("color", Color(0.7, 0.9, 1.0)))
		height = 2.2
		return
	if def.has("prop"):
		kind = "totem"
		var p: Node3D = scene(def.prop).instantiate()
		p.scale = def.get("prop_scale", Vector3.ONE)
		add_child(p)
		_collect(p)
		height = 2.0
		return
	var path: String = ModelsDB.CHAR_DIR + String(def.model) + ".glb"
	_is_skeleton = String(def.model).begins_with("Skeleton")
	model = scene(path).instantiate()
	add_child(model)
	model.scale = Vector3.ONE * size
	height = 2.3 * size
	var show: Array = def.get("show", [])
	_collect(model)
	for m in _meshes:
		var n := String(m.name)
		var body := n.begins_with("Skeleton_") or ["Arm", "Leg", "Body", "Head", "Eyes", "Jaw", "Skull"].any(func(k): return n.contains(k))
		m.visible = body or show.has(n)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if def.has("weapon"):
		_attach("handslot_r", ModelsDB.WEAPON_DIR + "Skeleton_%s.gltf" % def.weapon)
	if def.has("shield"):
		_attach("handslot_l", ModelsDB.WEAPON_DIR + "Skeleton_%s.gltf" % def.shield)
	ap = model.find_child("AnimationPlayer", true, false)
	if ap:
		for n in LOOPS:
			if ap.has_animation(n):
				ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_play("Idle", 0.0)
		ap.seek(randf() * 1.5)   # FX randomness is fine: presentation only

func _attach(slot: String, path: String) -> void:
	var at := model.find_child(slot, true, false)
	if at == null or not ResourceLoader.exists(path):
		return
	var w: Node3D = scene(path).instantiate()
	at.add_child(w)
	_collect(w)

func _collect(n: Node) -> void:
	if n is MeshInstance3D:
		_meshes.append(n)
	for c in n.get_children():
		_collect(c)

func _build_wisp(c: Color) -> void:
	_wisp = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	_wisp.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	_wisp.material_override = m
	add_child(_wisp)
	var l := OmniLight3D.new()
	l.light_color = c
	l.omni_range = 3.0
	l.light_energy = 0.8
	_wisp.add_child(l)

## Animation name with fallbacks (adventurers and skeletons have slightly different sets).
func _pick(names: Array) -> String:
	for n in names:
		if ap.has_animation(n):
			return n
	return "Idle"

func _play(n: String, blend: float = 0.12, speed: float = 1.0) -> void:
	if ap == null:
		return
	ap.speed_scale = speed
	if _cur == n and ap.is_playing():
		return
	_cur = n
	ap.play(n, blend)

func _attack_anim() -> String:
	var k := actor.last_act_kind
	var b := actor.last_act_behavior
	if b in ["raise", "totem", "companion"]:
		return _pick(["Spellcast_Summon", "Spellcast_Raise"])
	if b in ["buff", "warcry", "rally", "banner"]:
		return _pick(["Cheer", "Spellcast_Raise"])
	if b in ["nova", "ground", "grand_rite", "cataclysm"]:
		return _pick(["Spellcast_Long", "Spellcast_Shoot"])
	if k == "spell":
		return _pick(["Spellcast_Shoot", "1H_Ranged_Shoot"])
	if b == "projectile" or b == "split" or b == "rain":
		return _pick(["2H_Ranged_Shoot", "1H_Ranged_Shoot"])
	var showing_2h := false
	for m in _meshes:
		if m.visible and String(m.name).begins_with("2H_") and not String(m.name).contains("Crossbow"):
			showing_2h = true
	var opts := ["2H_Melee_Attack_Chop", "2H_Melee_Attack_Slice"] if showing_2h else ["1H_Melee_Attack_Chop", "1H_Melee_Attack_Slice_Diagonal", "1H_Melee_Attack_Slice_Horizontal"]
	return _pick([opts[actor.act_serial % opts.size()], "1H_Melee_Attack_Chop"])

func update(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	position = IsoView.to3d(actor.global_position)
	if kind == "wisp":
		_wisp.position.y = 1.9 + sin(Time.get_ticks_msec() * 0.006) * 0.15
		return
	# facing
	var f := actor.facing
	if f.length() > 0.1:
		var want := atan2(f.x, f.y)
		_yaw = lerp_angle(_yaw, want, minf(1.0, delta * 16.0))
	rotation.y = _yaw
	_update_overlay()
	if ap == null:
		return
	if actor.dead:
		if not _died:
			_died = true
			_play(_pick(["Death_C_Skeletons", "Death_A"]) if _is_skeleton else _pick(["Death_A", "Death_B"]), 0.08)
		return
	if _died:   # revived (player respawn)
		_died = false
		_cur = ""
	ap.speed_scale = 0.0 if actor.frozen_time > 0.0 else ap.speed_scale
	if actor.frozen_time > 0.0:
		return
	_lock = maxf(0.0, _lock - delta)
	if actor.act_serial != _serial:
		_serial = actor.act_serial
		if actor.last_act_fx == "ember" and get_parent() is Node3D:
			var fwd := Vector3(actor.facing.x, 0, actor.facing.y).normalized()
			_yaw = atan2(fwd.x, fwd.z)
			SpellFx3D.cast_flare(get_parent(), position + fwd * 0.55 * model.scale.x + Vector3(0, 1.3 * model.scale.x, 0), Color(1.0, 0.55, 0.2))
		var n := _attack_anim()
		var busy := maxf(0.12, actor.busy_time)
		var length := ap.get_animation(n).length
		# fit the swing into the action time, but keep it readable
		var spd := clampf(length * 0.7 / busy, 0.9, 3.2)
		_cur = ""
		_play(n, 0.05, spd)
		_lock = length * 0.7 / spd
		return
	if actor.hit_flash > _last_flash + 0.01 and _lock <= 0.0 and actor.radius < 50.0:
		_play(_pick(["Hit_A", "Hit_B"]), 0.05, 1.6)
		_cur = ""
		_lock = 0.25
	_last_flash = actor.hit_flash
	if _lock > 0.0:
		return
	var v := actor.velocity.length()
	if v > 25.0:
		# run cycle speed follows move speed (base run ~ 220 px/s)
		_play(_pick(["Running_A"]), 0.15, clampf(v / 230.0, 0.6, 1.8) / maxf(0.6, model.scale.x))
	else:
		_play(_pick(["Idle_Combat", "Idle"]) if _is_skeleton else "Idle", 0.2, 1.0)

## Status colour over the model: the monster's own tint and freeze/chill/shock recolour the
## materials (cached per colour); a hit adds a short bright overlay.
static var _tinted := {}
var _tint_key := ""

static func _tinted_mat(src: Material, c: Color) -> Material:
	if not (src is StandardMaterial3D):
		return null
	var key := "%d|%s" % [src.get_instance_id(), c.to_html()]
	if not _tinted.has(key):
		var m: StandardMaterial3D = src.duplicate()
		m.albedo_color = (src as StandardMaterial3D).albedo_color * c
		_tinted[key] = m
	return _tinted[key]

func _update_overlay() -> void:
	var c := tint
	if actor.frozen_time > 0.0:
		c = c * Color(0.55, 0.8, 1.35)
	elif actor.chill_time > 0.0:
		c = c * Color(0.8, 0.92, 1.15)
	elif actor.shock_time > 0.0:
		c = c * Color(1.15, 1.15, 0.75)
	var key := c.to_html()
	if key != _tint_key:
		_tint_key = key
		for m in _meshes:
			var mi := m as MeshInstance3D
			if c == Color.WHITE or mi.mesh == null:
				mi.material_override = null
			else:
				mi.material_override = _tinted_mat(mi.mesh.surface_get_material(0), c)
	var flash := 2 if actor.hit_flash > 0.0 and not actor.dead else 0
	if flash == _overlay_state:
		return
	_overlay_state = flash
	if flash == 2 and _mat_flash == null:
		_mat_flash = StandardMaterial3D.new()
		_mat_flash.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat_flash.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_flash.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat_flash.albedo_color = Color(1.0, 0.85, 0.75, 0.45)
	for m in _meshes:
		m.material_overlay = _mat_flash if flash == 2 else null
