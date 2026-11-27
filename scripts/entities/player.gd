class_name Player
extends Actor

signal leveled_up(level: int)
signal inventory_changed

const INV_SIZE := 40
const DODGE_TIME := 0.22
const DODGE_DIST := 250.0
const DODGE_CD := 0.85

var input := PlayerInput.new()
var bar: Array = SkillsDB.PLAYER_BAR.duplicate()
var equipment := {}
var passives := {"start": true}
var inventory: Array = []
var xp := 0
var flask_charges := 3.0
var flask_max := 3
var _dodge_t := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector2.ZERO
var _flask_heal := 0.0
var _anim := 0.0
var _light: PointLight2D

func _init() -> void:
	faction = "player"
	radius = 15.0
	display_name = "Kindled"
	inventory.resize(INV_SIZE)

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = radius
	shape.shape = c
	add_child(shape)
	_build_visuals()
	if equipment.is_empty():
		equipment["weapon"] = Loot.starter_weapon()
	recalc_stats(true)

func build_stats(eq: Dictionary) -> StatBlock:
	var s := StatBlock.new()
	s.add("life_flat", 92 + 12 * level)
	s.add("mana_flat", 48 + 6 * level)
	s.add("move_speed_base", 300.0)
	s.add("mana_regen", 7.0 + 0.4 * level)
	s.add("inc_damage", 2.0 * (level - 1))  # small growth per level
	for slot in eq:
		var it: Item = eq[slot]
		if it:
			s.add_mod_list(it.to_mods())
	var tree := PassivesDB.nodes()
	for id in passives:
		if tree.has(id):
			s.add_mods(tree[id].stats)
	return s

func passive_points() -> int:
	return (level - 1) - (passives.size() - 1)

func can_allocate(id: String) -> bool:
	if passives.has(id) or passive_points() <= 0:
		return false
	for l in PassivesDB.nodes()[id].links:
		if passives.has(l):
			return true
	return false

func allocate(id: String) -> bool:
	if not can_allocate(id):
		return false
	passives[id] = true
	recalc_stats()
	return true

## Refund only if every other allocated node stays connected to the start.
func can_refund(id: String) -> bool:
	if id == "start" or not passives.has(id):
		return false
	var tree := PassivesDB.nodes()
	var seen := {"start": true}
	var stack := ["start"]
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		for l in tree[cur].links:
			if l != id and passives.has(l) and not seen.has(l):
				seen[l] = true
				stack.append(l)
	return seen.size() == passives.size() - 1

func refund(id: String) -> bool:
	if not can_refund(id):
		return false
	passives.erase(id)
	recalc_stats()
	return true

static func calc_max_life(s: StatBlock) -> float:
	return maxf(1.0, s.get_stat("life_flat") * s.inc_mult(["inc_life"]) * s.get_stat("more_life"))

## Derived numbers shown on the character sheet and in item comparisons.
func summary(eq: Dictionary) -> Dictionary:
	var s := build_stats(eq)
	var out := {
		"Life": calc_max_life(s),
		"Mana": s.get_stat("mana_flat"),
		"Armour": s.get_stat("armour"),
		"Fire Res": minf(75.0, s.get_stat("res_fire")),
		"Cold Res": minf(75.0, s.get_stat("res_cold")),
		"Lightning Res": minf(75.0, s.get_stat("res_lightning")),
		"Move Speed": s.inc_mult(["inc_move_speed"]) * 100.0,
	}
	var rng := RandomNumberGenerator.new()
	for sid in bar:
		var sk: Dictionary = SkillsDB.SKILLS[sid]
		rng.seed = 12345
		var total := 0.0
		var n := 120
		for i in n:
			total += Damage.total(Damage.roll_hit(sk, s, rng).damage)
		var avg := total / n
		var speed := s.inc_mult(["inc_attack_speed" if sk.kind == "attack" else "inc_cast_speed"])
		var period := maxf(float(sk.time) / speed, float(sk.get("cooldown", 0.0)))
		if sk.behavior == "ground":
			# ticks for its whole duration, recast on cooldown
			var ticks := float(sk.duration) / float(sk.tick)
			out[sk.name + " DPS"] = avg * ticks / maxf(period, float(sk.duration))
		else:
			out[sk.name + " DPS"] = avg / period
	return out

static func xp_to_next(lvl: int) -> int:
	return int(round(70.0 * pow(lvl, 1.55)))

func recalc_stats(refill: bool = false) -> void:
	var life_frac := life / max_life if max_life > 0.0 else 1.0
	var mana_frac := mana / max_mana if max_mana > 0.0 else 1.0
	stats = build_stats(equipment)
	max_life = calc_max_life(stats)
	max_mana = maxf(0.0, stats.get_stat("mana_flat"))
	if refill:
		life = max_life
		mana = max_mana
	else:
		life = clampf(max_life * life_frac, 1.0, max_life)
		mana = clampf(max_mana * mana_frac, 0.0, max_mana)

func gain_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		recalc_stats(true)
		FX.ring(global_position, 220.0, Color(1.0, 0.8, 0.35), 0.6, 10.0)
		FX.burst(global_position, Color(1.0, 0.8, 0.35), 50, 420.0, 9.0, 0.8)
		FX.text(global_position, "LEVEL %d" % level, Color(1.0, 0.85, 0.4), 34)
		FX.sound("levelup", null, 0.0, 0.0)
		FX.rumble(0.4, 0.2, 0.35)
		if game() and game().hud:
			game().hud.show_message("LEVEL %d" % level, "+1 Ember Point · press P to open the Constellation")
		leveled_up.emit(level)

func add_flask_charge(amount: float) -> void:
	flask_charges = minf(flask_max, flask_charges + amount)

func _physics_process(delta: float) -> void:
	if dead:
		return
	tick_common(delta)
	_anim += delta
	_dodge_cd = maxf(0.0, _dodge_cd - delta)
	mana = minf(max_mana, mana + stats.get_stat("mana_regen") * stats.inc_mult(["inc_mana_regen"]) * delta)
	if _flask_heal > 0.0:
		var h := minf(_flask_heal, max_life * 0.6 * delta / 1.0)
		heal(h)
		_flask_heal -= h
	var to_aim := input.aim - global_position
	if to_aim.length() > 4.0:
		facing = to_aim.normalized()
	# Dodge
	if _dodge_t > 0.0:
		_dodge_t -= delta
		velocity = _dodge_dir * (DODGE_DIST / DODGE_TIME)
		move_and_slide()
		if randf() < 0.6:
			FX.burst(global_position, Color(1.0, 0.6, 0.3), 2, 40.0, 7.0, 0.35)
		if _dodge_t <= 0.0:
			invulnerable = false
		_update_visuals(delta)
		queue_redraw()
		return
	if input.dodge and _dodge_cd <= 0.0:
		_dodge_dir = input.move.normalized() if input.move.length() > 0.1 else facing
		_dodge_t = DODGE_TIME
		_dodge_cd = DODGE_CD
		invulnerable = true
		busy_time = 0.0
		FX.flash(global_position, Color(1.0, 0.6, 0.3), 60.0, 0.15)
		FX.sound("dodge", null, -10.0)
		return
	if input.flask and flask_charges >= 1.0 and life < max_life:
		flask_charges -= 1.0
		_flask_heal += max_life * 0.6
		FX.sound("flask", null, -3.0)
		FX.ring(global_position, 70.0, Color(1.0, 0.3, 0.35), 0.35)
		FX.burst(global_position, Color(1.0, 0.3, 0.35), 18, 160.0, 7.0, 0.5)
	# Skills (hold to repeat). Lower index wins when several are held.
	for i in bar.size():
		if input.skill_held[i]:
			if SkillExec.use(bar[i], self, input.aim):
				input.consume(i)
				break
	# Movement (slowed while casting/attacking).
	var speed := move_speed() * (0.45 if busy_time > 0.0 else 1.0)
	velocity = input.move.normalized() * speed + knock
	move_and_slide()
	_update_visuals(delta)
	queue_redraw()

func _draw() -> void:
	# shadow
	draw_set_transform(Vector2(0, radius * 0.7), 0.0, Vector2(1.0, 0.38))
	draw_circle(Vector2.ZERO, radius * 1.4, Color(0, 0, 0, 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if ignite_time > 0.0:
		draw_arc(Vector2(0, radius * 0.7), radius * 1.5, 0, TAU, 24, Color(1, 0.45, 0.1, 0.7), 2.0, true)

# ---------- visuals ----------

var hero := "knight_m"
var _spr: AnimatedSprite2D
var _wpn: Sprite2D
var _wpn_id := ""
var _mat: ShaderMaterial
var _hit_t := 0.0
var _swing_t := 0.0
var _swing_dir := 1.0
var _lunge := Vector2.ZERO

func _build_visuals() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://assets/shaders/sprite_fx.gdshader")
	_spr = AnimatedSprite2D.new()
	_spr.sprite_frames = Art.frames_for(hero)
	_spr.scale = Vector2.ONE * Art.PX
	_spr.position = Vector2(0, -44)
	_spr.material = _mat
	_spr.play("idle")
	add_child(_spr)
	_wpn = Sprite2D.new()
	_wpn.centered = false
	_wpn.scale = Vector2.ONE * Art.PX * 0.85
	_wpn.material = _mat
	add_child(_wpn)
	_light = FX.make_light(Color(1.0, 0.78, 0.55), 560.0, 1.05)
	_light.position = Vector2(0, -30)
	add_child(_light)
	_refresh_weapon()

func set_hero(h: String) -> void:
	hero = h if Art.HEROES.has(h) else "knight_m"
	if _spr:
		_spr.sprite_frames = Art.frames_for(hero)
		_spr.play("idle")

func _refresh_weapon() -> void:
	var it: Item = equipment.get("weapon")
	var id := ""
	if it:
		id = it.unique_id if Art.WEAPON_SPRITES.has(it.unique_id) else it.base_id
	if id == _wpn_id:
		return
	_wpn_id = id
	_wpn.visible = id != ""
	if id != "":
		var name: String = Art.WEAPON_SPRITES.get(id, "weapon_rusty_sword")
		_wpn.texture = Art.tex(name)
		var sz := Art.size_of(name)
		_wpn.offset = Vector2(-sz.x / 2.0, -sz.y + 4)   # pivot near the grip

## Called by SkillExec when the player uses a Rite.
func on_skill_used(skill: Dictionary) -> void:
	_swing_t = 0.22 if skill.get("kind") == "attack" else 0.14
	_swing_dir = -_swing_dir
	_lunge = facing * (10.0 if skill.get("kind") == "attack" else 4.0)

func _update_visuals(delta: float) -> void:
	if _spr == null:
		return
	_refresh_weapon()
	_hit_t = maxf(0.0, _hit_t - delta)
	_swing_t = maxf(0.0, _swing_t - delta)
	_lunge = _lunge.move_toward(Vector2.ZERO, 120.0 * delta)
	var anim := "idle"
	if _hit_t > 0.0:
		anim = "hit"
	elif velocity.length() > 30.0:
		anim = "run"
	if _spr.animation != anim:
		_spr.play(anim)
	var left := facing.x < -0.05
	_spr.flip_h = left
	_spr.position = Vector2(0, -44) + _lunge
	_spr.modulate.a = 0.55 if invulnerable else 1.0
	# weapon follows aim, swings on attacks
	var hand := Vector2(-14.0 if left else 14.0, -22.0) + _lunge
	_wpn.position = hand
	var base_angle := facing.angle() + PI / 2.0
	var swing := 0.0
	if _swing_t > 0.0:
		var k := 1.0 - _swing_t / 0.22
		swing = lerpf(-1.4, 1.4, k) * _swing_dir
	_wpn.rotation = base_angle + swing
	_wpn.z_index = 1 if facing.y > -0.3 else -1
	# status + flash
	var tint := Color.WHITE
	if is_chilled():
		tint = Color(0.6, 0.85, 1.0)
	elif shock_time > 0.0:
		tint = Color(1.0, 1.0, 0.7)
	_mat.set_shader_parameter("tint", tint)
	_mat.set_shader_parameter("flash", 0.5 if hit_flash > 0.0 else 0.0)

func _on_hit_fx(dmg: Dictionary, amount: float, crit: bool) -> void:
	super._on_hit_fx(dmg, amount, crit)
	_hit_t = 0.15

func to_save() -> Dictionary:
	var eq := {}
	for s in equipment:
		if equipment[s]:
			eq[s] = equipment[s].to_dict()
	var inv: Array = []
	for it in inventory:
		inv.append(it.to_dict() if it else null)
	return {"level": level, "xp": xp, "equipment": eq, "inventory": inv, "passives": passives.keys(), "hero": hero}

func from_save(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
	hero = d.get("hero", "knight_m")
	passives = {"start": true}
	for id in d.get("passives", []):
		if PassivesDB.nodes().has(id):
			passives[id] = true
	equipment.clear()
	var eq: Dictionary = d.get("equipment", {})
	for s in eq:
		equipment[s] = Item.from_dict(eq[s])
	inventory.clear()
	inventory.resize(INV_SIZE)
	var inv: Array = d.get("inventory", [])
	for i in mini(inv.size(), INV_SIZE):
		if inv[i] != null:
			inventory[i] = Item.from_dict(inv[i])

func add_to_inventory(it: Item) -> bool:
	for i in INV_SIZE:
		if inventory[i] == null:
			inventory[i] = it
			inventory_changed.emit()
			return true
	return false

## Equip from bag index. Rings go to the empty ring slot, else ring1.
func equip_from_bag(idx: int) -> void:
	var it: Item = inventory[idx]
	if it == null:
		return
	if it.req_level() > level:
		FX.text(global_position, "Requires Level %d" % it.req_level(), Color(1, 0.4, 0.4))
		return
	var slot := it.slot_group()
	if slot == "ring":
		slot = "ring1" if equipment.get("ring1") == null else ("ring2" if equipment.get("ring2") == null else "ring1")
	var old: Item = equipment.get(slot)
	equipment[slot] = it
	inventory[idx] = old
	recalc_stats()
	inventory_changed.emit()

func unequip(slot: String) -> void:
	var it: Item = equipment.get(slot)
	if it == null:
		return
	if add_to_inventory(it):
		equipment.erase(slot)
		recalc_stats()
		inventory_changed.emit()

func target_slot_for(it: Item) -> String:
	var s := it.slot_group()
	if s == "ring":
		return "ring1" if equipment.get("ring1") == null else ("ring2" if equipment.get("ring2") == null else "ring1")
	return s
