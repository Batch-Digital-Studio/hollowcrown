class_name Minion
extends Actor
## A raised husk fighting for its owner. Follows, leashes, picks targets near its owner.

var owner_actor: Actor
var kind := "husk"            # husk | hawk | squire | beast
var temporary := 0.0          # >0: dies when it runs out (Grand Rite horde)
var brute := false
var explode := false
var _spr: AnimatedSprite2D
var _mat: ShaderMaterial
var _target: Actor = null
var _retarget := 0.0
var _anim := 0.0
var _offset := Vector2.ZERO

const LEASH := 900.0
const ENGAGE := 520.0

func setup(owner_: Actor, lvl: int, pos: Vector2, temp_seconds: float = 0.0) -> void:
	owner_actor = owner_
	faction = "player"
	level = lvl
	temporary = temp_seconds
	global_position = pos
	display_name = "Husk"
	var os: StatBlock = owner_.stats
	brute = os.get_stat("husk_brute") > 0.0 and kind == "husk"
	explode = os.get_stat("husk_explode") > 0.0
	radius = 24.0 if brute else 18.0
	stats = StatBlock.new()
	var hp := 100.0 * pow(1.12, lvl - 1) * (1.0 + os.get_stat("inc_minion_life") / 100.0) * (2.0 if brute else 1.0)
	stats.add("life_flat", hp)
	stats.add("move_speed_base", 270.0 * (1.0 + os.get_stat("minion_move") / 100.0))
	stats.add("inc_damage", os.get_stat("inc_minion_damage"))
	stats.add("more_damage", (pow(1.1, lvl - 1) - 1.0) * 100.0 + (100.0 if brute else 0.0))
	stats.add("inc_attack_speed", os.get_stat("minion_attack_speed"))
	stats.add("armour", 30.0 * lvl)
	for r in ["res_fire", "res_cold", "res_lightning", "res_chaos"]:
		stats.add(r, 30.0)
	stats.add("life_regen", hp * 0.015)
	if os.get_stat("minion_fire") > 0.0:
		stats.add("conv_physical_to_fire", os.get_stat("minion_fire"))
		stats.add("ignite_chance", 15.0)
	if kind == "hawk":
		hp *= 0.6
		stats = StatBlock.new()
		stats.add("life_flat", hp)
		stats.add("move_speed_base", 430.0)
		stats.add("inc_damage", os.get_stat("inc_minion_damage"))
		stats.add("more_damage", (pow(1.1, lvl - 1) - 1.0) * 100.0)
		stats.add("evade_chance", 50.0)
		stats.add("life_regen", hp * 0.03)
		radius = 14.0
		display_name = "Spirit Hawk"
	if kind == "squire" or kind == "beast":
		var big := kind == "beast"
		hp = 160.0 * pow(1.12, lvl - 1) * (1.0 + os.get_stat("inc_minion_life") / 100.0) * (1.4 if big else 1.0)
		stats = StatBlock.new()
		stats.add("life_flat", hp)
		stats.add("move_speed_base", 300.0 if big else 280.0)
		stats.add("inc_damage", os.get_stat("inc_minion_damage"))
		stats.add("more_damage", (pow(1.1, lvl - 1) - 1.0) * 100.0 + (80.0 if big else 40.0))
		stats.add("armour", 60.0 * lvl)
		stats.add("block_chance", 0.0 if big else 25.0)
		for r in ["res_fire", "res_cold", "res_lightning", "res_chaos"]:
			stats.add(r, 40.0)
		stats.add("life_regen", hp * 0.02)
		if big:
			stats.add("poison_chance", 40.0)
		else:
			stats.add("conv_physical_to_fire", 50.0)
		radius = 22.0 if big else 18.0
		display_name = "Bog Beast" if big else "Sworn Squire"
	if kind == "hawk" and os.get_stat("hawk_fury") > 0.0:
		stats.add("inc_attack_speed", 100.0)
	max_life = hp
	life = hp
	_offset = Vector2.RIGHT.rotated(randf() * TAU) * randf_range(50, 110)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius * 0.7
	shape.shape = c
	add_child(shape)
	if kind == "hawk":
		collision_mask = 0
		var hl := FX.make_light(Color(0.7, 0.9, 1.0), 160.0, 0.7)
		add_child(hl)
		return
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/sprite_fx.gdshader")
	_spr = AnimatedSprite2D.new()
	var sprite_id := "big_zombie" if brute else "zombie"
	if kind == "squire":
		sprite_id = "knight_m"
	elif kind == "beast":
		sprite_id = "swampy"
	_spr.sprite_frames = Art.frames_for(sprite_id)
	var px := 3.0 if brute else (4.5 if kind == "beast" else 4.0)
	_spr.scale = Vector2.ONE * px
	_spr.position = Vector2(0, -(34.0 if brute else 16.0) * px / 2.0 + 4.0)
	_spr.material = _mat
	_spr.play("idle")
	add_child(_spr)
	var l := FX.make_light(Color(0.5, 1.0, 0.5), 140.0, 0.6)
	l.position = Vector2(0, -16)
	add_child(l)
	FX.burst(global_position, Color(0.5, 0.9, 0.4), 18, 160.0, 7.0, 0.5)

func _physics_process(delta: float) -> void:
	if dead:
		return
	tick_common(delta)
	if dead:
		return
	_anim += delta
	if temporary > 0.0:
		temporary -= delta
		if temporary <= 0.0:
			die(null)
			return
	if not is_instance_valid(owner_actor) or owner_actor.dead:
		velocity = Vector2.ZERO
		_update_visuals()
		return
	var g := game()
	var home := owner_actor.global_position + _offset
	if global_position.distance_to(owner_actor.global_position) > LEASH:
		global_position = home
		FX.burst(global_position, Color(0.5, 0.9, 0.4), 10, 120.0, 6.0, 0.4)
	_retarget -= delta
	if _retarget <= 0.0 or _target == null or not is_instance_valid(_target) or _target.dead:
		_retarget = 0.4
		_target = null
		var best := INF
		for e in g.targets_in_circle("player", owner_actor.global_position, ENGAGE):
			var d: float = e.global_position.distance_to(global_position)
			if d < best:
				best = d
				_target = e
	var move := Vector2.ZERO
	if _target:
		var to := _target.global_position - global_position
		facing = to.normalized()
		var sk_id := "hawk_strike" if kind == "hawk" else "minion_claw"
		var reach: float = SkillsDB.SKILLS[sk_id].radius + _target.radius
		if to.length() <= reach:
			cast_stats = stats
			if SkillExec.use(sk_id, self, _target.global_position) and kind == "hawk":
				var mark := 0.10 + owner_actor.stats.get_stat("hawk_mark") / 100.0
				_target.apply_curse(owner_actor, mark, 0.0, 4.0, false)
		elif busy_time <= 0.0:
			move = to.normalized()
	else:
		var to_home := home - global_position
		if to_home.length() > 40.0:
			move = to_home.normalized() * clampf(to_home.length() / 120.0, 0.4, 1.0)
			facing = to_home.normalized()
	# keep minions from stacking
	var sep := Vector2.ZERO
	for o in g.allies:
		if o == self or not is_instance_valid(o):
			continue
		var d: Vector2 = global_position - o.global_position
		var l := d.length()
		if l > 0.1 and l < radius * 2.0:
			sep += d / l * (radius * 2.0 - l)
	velocity = move * move_speed() + sep * 5.0 + knock
	move_and_slide()
	_update_visuals()

func _update_visuals() -> void:
	if _spr == null:
		queue_redraw()
		return
	var anim := "run" if velocity.length() > 25.0 else "idle"
	if _spr.animation != anim and _spr.sprite_frames.has_animation(anim):
		_spr.play(anim)
	_spr.flip_h = facing.x < -0.05
	var tint := Color(0.7, 1.0, 0.75)
	if kind == "squire":
		tint = Color(0.75, 0.85, 1.2, 0.8)
	elif kind == "beast":
		tint = Color(0.9, 1.1, 0.85)
	if temporary > 0.0:
		tint = Color(0.6, 1.2, 0.7, 0.85)
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("flash", 0.6 if hit_flash > 0.0 else 0.0)
	queue_redraw()

func _draw() -> void:
	if kind == "hawk":
		var y := -70.0 + sin(_anim * 6.0) * 6.0
		draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, 12, Color(0, 0, 0, 0.3))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var flap := sin(_anim * 18.0) * 10.0
		var c := Color(0.7, 0.9, 1.0, 0.9)
		var f := 1.0 if facing.x >= 0 else -1.0
		draw_colored_polygon(PackedVector2Array([Vector2(-22 * f, y - flap), Vector2(0, y), Vector2(-6 * f, y + 4)]), c)
		draw_colored_polygon(PackedVector2Array([Vector2(22 * f, y - flap), Vector2(0, y), Vector2(6 * f, y + 4)]), c)
		draw_circle(Vector2(4 * f, y - 2), 6, c.lightened(0.3))
		draw_line(Vector2(9 * f, y - 2), Vector2(14 * f, y), Color(1.0, 0.85, 0.4), 2.0)
		return
	draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_arc(Vector2(0, 2), radius * 1.15, 0, TAU, 20, Color(0.5, 1.0, 0.45, 0.5), 1.5, true)
	if life < max_life:
		var w := radius * 2.0
		draw_rect(Rect2(-w / 2, -radius * 2.6, w, 4), Color(0, 0, 0, 0.7))
		draw_rect(Rect2(-w / 2, -radius * 2.6, w * life / max_life, 4), Color(0.45, 0.9, 0.35))

func _on_hit_fx(dmg: Dictionary, amount: float, crit: bool) -> void:
	FX.burst(global_position, Color(0.5, 0.9, 0.4), 5, 140.0, 5.0)

func die(killer: Actor) -> void:
	if dead:
		return
	if OS.get_environment("HC_DEBUG") != "":
		print("DBG minion died temp=", temporary, " life=", life, "/", max_life, " killer=", killer.display_name if killer else "none", " owner_dead=", not is_instance_valid(owner_actor))
	super.die(killer)
	var g := game()
	g.allies.erase(self)
	Asc.on_minion_died(self)
	if explode and g:
		var s := {"kind": "spell", "base_damage": {"fire": [max_life * 0.08, max_life * 0.12]}, "crit": 5.0, "tags": ["area"], "ignite_chance": 30.0}
		for t in g.targets_in_circle("player", global_position, 110.0):
			t.take_hit(Damage.roll_hit(s, stats, g.rng), owner_actor, t.global_position - global_position, 200.0)
		FX.ring(global_position, 110.0, Color(1.0, 0.5, 0.2), 0.35, 8.0)
		FX.sound("boom", global_position, -10.0)
	FX.burst(global_position, Color(0.4, 0.7, 0.35), 16, 180.0, 7.0, 0.5)
	set_physics_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)
