extends SceneTree
## Run: godot --headless --path . -s res://scripts/tests/test_damage.gd

var fails := 0

func check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		print("  PASS ", name)
	else:
		fails += 1
		print("  FAIL ", name, "  ", detail)

func approx(a: float, b: float, eps: float = 0.01) -> bool:
	return absf(a - b) <= eps * maxf(1.0, absf(b))

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	print("Damage engine tests")

	# Flat spell, no mods.
	var skill := {"kind": "spell", "base_damage": {"fire": [100, 100]}, "crit": 0}
	var s := StatBlock.new()
	var r := Damage.roll_hit(skill, s, rng)
	check("base fire", approx(r.damage.fire, 100.0), str(r.damage))

	# Increased stacks additively, more multiplicatively.
	s.add("inc_fire_damage", 50)
	s.add("inc_spell_damage", 50)
	s.add("more_damage", 20)
	s.add("more_damage", 50)
	r = Damage.roll_hit(skill, s, rng)
	check("inc + more", approx(r.damage.fire, 100.0 * 2.0 * 1.2 * 1.5), str(r.damage))

	# Conversion: phys -> fire 50%. Converted part gets phys AND fire increases.
	var atk := {"kind": "attack", "base_damage": {}, "crit": 0, "tags": ["melee"]}
	s = StatBlock.new()
	s.add("weapon_physical_min", 100)
	s.add("weapon_physical_max", 100)
	s.add("conv_physical_to_fire", 50)
	s.add("inc_physical_damage", 100)
	s.add("inc_fire_damage", 100)
	r = Damage.roll_hit(atk, s, rng)
	check("phys part", approx(r.damage.physical, 50.0 * 2.0), str(r.damage))
	check("converted part double-dips", approx(r.damage.fire, 50.0 * 3.0), str(r.damage))
	check("converted gets elemental", true)

	# Over-100% conversion is scaled down.
	s = StatBlock.new()
	s.add("weapon_physical_min", 100)
	s.add("weapon_physical_max", 100)
	s.add("conv_physical_to_fire", 100)
	s.add("conv_physical_to_cold", 100)
	r = Damage.roll_hit(atk, s, rng)
	check("over-cap conversion", approx(r.damage.fire, 50.0) and approx(r.damage.cold, 50.0) and r.damage.physical < 0.01, str(r.damage))

	# Chained conversion: phys -> lightning -> fire; elemental inc applies.
	s = StatBlock.new()
	s.add("weapon_physical_min", 100)
	s.add("weapon_physical_max", 100)
	s.add("conv_physical_to_lightning", 100)
	s.add("conv_lightning_to_fire", 100)
	s.add("inc_lightning_damage", 50)
	s.add("inc_elemental_damage", 50)
	r = Damage.roll_hit(atk, s, rng)
	check("chain conversion", approx(r.damage.fire, 200.0), str(r.damage))

	# Crit always crits at 100% and applies multiplier.
	var critskill := {"kind": "spell", "base_damage": {"cold": [100, 100]}, "crit": 100}
	s = StatBlock.new()
	s.add("crit_multi", 50)
	r = Damage.roll_hit(critskill, s, rng)
	check("crit multi", r.crit and approx(r.damage.cold, 200.0), str(r))
	check("crit forces ailments", r.ailments.chill == 100.0)

	# Mitigation: resist cap.
	var def := StatBlock.new()
	def.add("res_fire", 90)
	var m := Damage.mitigate({"fire": 100.0}, def)
	check("res cap 75", approx(m.fire, 25.0), str(m))

	# Armour vs big and small hits.
	def = StatBlock.new()
	def.add("armour", 500)
	var small := Damage.mitigate({"physical": 20.0}, def)
	var big := Damage.mitigate({"physical": 1000.0}, def)
	check("armour strong vs small", small.physical < 20.0 * 0.2, str(small))
	check("armour weak vs big", big.physical > 1000.0 * 0.85, str(big))

	print("FAILURES: ", fails)
	quit(1 if fails > 0 else 0)
