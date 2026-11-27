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
var inventory: Array = []
var xp := 0
var flask_charges := 3.0
var flask_max := 3
var _dodge_t := 0.0
var _dodge_cd := 0.0
var _dodge_dir := Vector2.ZERO
var _flask_heal := 0.0
var _anim := 0.0
var _glow: Sprite2D
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
	_glow = FX.make_glow(Color(1.0, 0.55, 0.2, 0.55), 150.0)
	_glow.z_index = -1
	add_child(_glow)
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
	return s

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
		queue_redraw()
		return
	if input.dodge and _dodge_cd <= 0.0:
		_dodge_dir = input.move.normalized() if input.move.length() > 0.1 else facing
		_dodge_t = DODGE_TIME
		_dodge_cd = DODGE_CD
		invulnerable = true
		busy_time = 0.0
		FX.flash(global_position, Color(1.0, 0.6, 0.3), 60.0, 0.15)
		return
	if input.flask and flask_charges >= 1.0 and life < max_life:
		flask_charges -= 1.0
		_flask_heal += max_life * 0.6
		FX.ring(global_position, 70.0, Color(1.0, 0.3, 0.35), 0.35)
		FX.burst(global_position, Color(1.0, 0.3, 0.35), 18, 160.0, 7.0, 0.5)
	# Skills (hold to repeat). Lower index wins when several are held.
	for i in bar.size():
		if input.skill_held[i]:
			if SkillExec.use(bar[i], self, input.aim):
				break
	# Movement (slowed while casting/attacking).
	var speed := move_speed() * (0.45 if busy_time > 0.0 else 1.0)
	velocity = input.move.normalized() * speed + knock
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	var bob := sin(_anim * 8.0) * (1.5 if velocity.length() > 10.0 else 0.4)
	var body := status_tint(Color(0.16, 0.14, 0.18))
	if invulnerable:
		body.a = 0.55
	# shadow
	draw_set_transform(Vector2(0, radius * 0.9), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, radius * 1.1, Color(0, 0, 0, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# cloak
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var r := radius * (1.15 if sin(a) > 0.2 else 1.0)
		pts.append(Vector2(cos(a) * r, sin(a) * r * 1.1 + bob))
	draw_colored_polygon(pts, body)
	draw_polyline(pts + PackedVector2Array([pts[0]]), status_tint(Color(0.5, 0.35, 0.25)), 2.0, true)
	# hood + ember heart
	draw_circle(Vector2(0, -radius * 0.55 + bob), radius * 0.62, status_tint(Color(0.1, 0.09, 0.11)))
	var pulse := 0.8 + 0.2 * sin(_anim * 5.0)
	draw_circle(Vector2(0, radius * 0.15 + bob), radius * 0.32 * pulse, Color(1.0, 0.55, 0.2))
	draw_circle(Vector2(0, radius * 0.15 + bob), radius * 0.16, Color(1.0, 0.9, 0.6))
	# eyes look toward aim
	var eye_c := Vector2(0, -radius * 0.55 + bob) + facing * radius * 0.28
	draw_circle(eye_c + facing.orthogonal() * 3.5, 2.0, Color(1.0, 0.8, 0.4))
	draw_circle(eye_c - facing.orthogonal() * 3.5, 2.0, Color(1.0, 0.8, 0.4))
	# weapon
	var wbase := facing * radius * 0.9 + facing.orthogonal() * radius * 0.6
	draw_line(wbase, wbase + facing * radius * 1.5, Color(0.75, 0.72, 0.68), 3.0, true)

func to_save() -> Dictionary:
	var eq := {}
	for s in equipment:
		if equipment[s]:
			eq[s] = equipment[s].to_dict()
	var inv: Array = []
	for it in inventory:
		inv.append(it.to_dict() if it else null)
	return {"level": level, "xp": xp, "equipment": eq, "inventory": inv}

func from_save(d: Dictionary) -> void:
	level = int(d.get("level", 1))
	xp = int(d.get("xp", 0))
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
