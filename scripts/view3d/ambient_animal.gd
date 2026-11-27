class_name AmbientAnimal
extends Node3D
## Wildlife for the isometric view (presentation only, never touches the simulation).
## Deer graze and bolt away when the hero comes close; crows peck about and take off.

var kind := "deer"
var home := Vector3.ZERO
var ap: AnimationPlayer
var model: Node3D
var _state := "idle"
var _t := 0.0
var _vel := Vector3.ZERO
var bounds_r := 17.0
var center := Vector3.ZERO

func setup(k: String, pos: Vector3, yaw_deg: float, area_center: Vector3, area_r: float) -> void:
	kind = k
	home = pos
	center = area_center
	bounds_r = area_r
	position = pos
	rotation.y = deg_to_rad(yaw_deg)
	model = (load("res://assets/whisperwood/%s.glb" % k) as PackedScene).instantiate()
	add_child(model)
	model.rotation.y = PI   # the Blender animals face -Z
	ap = model.find_child("AnimationPlayer", true, false)
	for n in ["Graze", "Idle", "Run", "Fly"]:
		if ap and ap.has_animation(n):
			ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
	_play("Graze" if kind == "deer" else "Idle")
	if ap:
		ap.seek(randf() * 2.0)

func _play(n: String, speed: float = 1.0) -> void:
	if ap and ap.has_animation(n):
		ap.speed_scale = speed
		if ap.current_animation != n:
			ap.play(n, 0.2)

func _process(delta: float) -> void:
	var g := Game.instance
	if g == null or g.player == null:
		return
	var hero := IsoView.to3d(g.player.global_position)
	var to_hero := hero - position
	to_hero.y = 0.0
	_t -= delta
	match _state:
		"idle":
			var scare := 7.0 if kind == "deer" else 4.5
			if to_hero.length() < scare:
				_state = "flee"
				_t = 2.6 if kind == "deer" else 4.0
				var away := -to_hero.normalized()
				away = away.rotated(Vector3.UP, randf_range(-0.5, 0.5))
				_vel = away * (7.5 if kind == "deer" else 5.0)
				if kind == "crow":
					_vel.y = 3.2
				_play("Run" if kind == "deer" else "Fly", 1.6 if kind == "deer" else 1.0)
		"flee":
			position += _vel * delta
			if kind == "deer":
				var flat := Vector3(position.x - center.x, 0, position.z - center.z)
				if flat.length() > bounds_r:   # keep deer inside the wood
					_vel = _vel.slide(flat.normalized()) - flat.normalized() * 2.0
			rotation.y = lerp_angle(rotation.y, atan2(_vel.x, _vel.z), minf(1.0, delta * 8.0))
			if _t <= 0.0:
				if kind == "crow":
					_state = "gone"
					visible = false
					_t = randf_range(10.0, 16.0)
				else:
					_state = "idle"
					home = position
					_play("Graze")
		"gone":   # crows come back to their perch later
			if _t <= 0.0 and to_hero.length() > 10.0:
				position = home
				visible = true
				_state = "idle"
				_play("Idle")
