class_name Actor
extends CharacterBody2D
## Shared base for players and monsters: life/mana, stats, ailments, hit handling.

signal died(actor: Actor)

var faction := "enemy"
var stats := StatBlock.new()
var level := 1
var radius := 16.0
var life := 1.0
var max_life := 1.0
var mana := 0.0
var max_mana := 0.0
var dead := false
var invulnerable := false
var display_name := ""

# Ailments
var ignite_dps := 0.0
var ignite_time := 0.0
var chill_time := 0.0
var shock_time := 0.0
var _ignite_tick := 0.0
var _ignite_fx := 0.0

var knock := Vector2.ZERO
var hit_flash := 0.0
var facing := Vector2.RIGHT
var busy_time := 0.0   # time until the actor can act again (attack/cast animation lock)
var cooldowns := {}

const CHILL_SLOW := 0.3
const SHOCK_TAKEN := 1.25
const IGNITE_DPS_RATIO := 0.35
const IGNITE_DURATION := 4.0

func game() -> Game:
	return Game.instance

func is_chilled() -> bool:
	return chill_time > 0.0

func move_speed() -> float:
	var base := float(stats.get_stat("move_speed_base"))
	var m := stats.inc_mult(["inc_move_speed"])
	if is_chilled():
		m *= 1.0 - CHILL_SLOW
	return base * m

func action_speed(kind: String) -> float:
	var stat := "inc_attack_speed" if kind == "attack" else "inc_cast_speed"
	var s := stats.inc_mult([stat])
	if is_chilled():
		s *= 1.0 - CHILL_SLOW
	return maxf(0.2, s)

func use_time(skill: Dictionary) -> float:
	return float(skill.time) / action_speed(skill.get("kind", "spell"))

func damage_taken_mult() -> float:
	return SHOCK_TAKEN if shock_time > 0.0 else 1.0

## Apply a rolled hit. Returns life actually lost.
func take_hit(result: Dictionary, src: Actor, knock_dir: Vector2 = Vector2.ZERO, knock_force: float = 0.0) -> float:
	if dead or invulnerable:
		return 0.0
	var source: Actor = src if is_instance_valid(src) else null
	var dmg := Damage.mitigate(result.damage, stats, damage_taken_mult())
	var amount := Damage.total(dmg)
	if amount <= 0.0:
		return 0.0
	life -= amount
	hit_flash = 0.08
	knock += knock_dir.normalized() * knock_force
	# Ailments
	var rng := game().rng
	var ail: Dictionary = result.get("ailments", {})
	if dmg.get("fire", 0.0) > 0.0 and rng.randf() * 100.0 < ail.get("ignite", 0.0):
		var dps: float = dmg.fire * IGNITE_DPS_RATIO * (1.0 + (source.stats.get_stat("inc_ignite_damage") if source else 0.0) / 100.0)
		if dps >= ignite_dps or ignite_time < 1.0:
			ignite_dps = dps
		ignite_time = IGNITE_DURATION
	if dmg.get("cold", 0.0) > 0.0 and rng.randf() * 100.0 < ail.get("chill", 0.0):
		chill_time = 2.0
	if dmg.get("lightning", 0.0) > 0.0 and rng.randf() * 100.0 < ail.get("shock", 0.0):
		shock_time = 4.0
	# Leech / life on hit for the attacker
	if source and not source.dead:
		var gain := source.stats.get_stat("life_on_hit") + amount * source.stats.get_stat("life_leech") / 100.0
		if gain > 0.0:
			source.heal(gain)
	_on_hit_fx(dmg, amount, result.get("crit", false))
	if faction == "player":
		FX.sound("hurt", null, -4.0)
	else:
		FX.sound("crit" if result.get("crit", false) else "hit", global_position, -2.0 if result.get("crit", false) else -7.0)
	if life <= 0.0:
		life = 0.0
		die(source)
	return amount

func take_dot(amount: float) -> void:
	if dead or invulnerable:
		return
	life -= amount
	if life <= 0.0:
		life = 0.0
		die(null)

func heal(amount: float) -> void:
	if dead:
		return
	life = minf(max_life, life + amount)

func _on_hit_fx(dmg: Dictionary, amount: float, crit: bool) -> void:
	var c: Color = Damage.COLORS[Damage.dominant(dmg)]
	if faction == "player":
		c = Color(1.0, 0.3, 0.3)
	FX.number(global_position, amount, c, crit)
	FX.burst(global_position, c, 6 if not crit else 14, 180.0 if not crit else 320.0, 5.0)

func die(_killer: Actor) -> void:
	if dead:
		return
	dead = true
	died.emit(self)

func tick_common(delta: float) -> void:
	busy_time = maxf(0.0, busy_time - delta)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, cooldowns[k] - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	chill_time = maxf(0.0, chill_time - delta)
	shock_time = maxf(0.0, shock_time - delta)
	if ignite_time > 0.0:
		ignite_time -= delta
		take_dot(ignite_dps * delta)
		_ignite_tick += delta
		_ignite_fx -= delta
		if _ignite_fx <= 0.0:
			_ignite_fx = 0.12
			FX.burst(global_position + Vector2(randf_range(-radius, radius), randf_range(-radius, 0)), Color(1, 0.45, 0.1), 2, 60.0, 5.0, 0.5)
		if _ignite_tick >= 0.5:
			_ignite_tick = 0.0
			if faction != "player":
				FX.number(global_position, ignite_dps * 0.5, Color(1.0, 0.55, 0.2).darkened(0.1), false)
		if ignite_time <= 0.0:
			ignite_dps = 0.0
	# regen
	var regen := stats.get_stat("life_regen")
	if regen > 0.0 and not dead:
		heal(regen * delta)
	knock = knock.move_toward(Vector2.ZERO, 2200.0 * delta)

## Tint for status, used by subclasses when drawing.
func status_tint(base: Color) -> Color:
	var c := base
	if is_chilled():
		c = c.lerp(Color(0.55, 0.85, 1.0), 0.45)
	if shock_time > 0.0:
		c = c.lerp(Color(1.0, 0.95, 0.5), 0.25)
	if hit_flash > 0.0:
		c = c.lerp(Color.WHITE, clampf(0.55 * 16.0 / radius, 0.15, 0.6))
	return c

func can_use(skill_id: String) -> bool:
	var s: Dictionary = SkillsDB.SKILLS[skill_id]
	return busy_time <= 0.0 and cooldowns.get(skill_id, 0.0) <= 0.0 and mana >= float(s.get("cost", 0))
