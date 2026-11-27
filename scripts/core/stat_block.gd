class_name StatBlock
extends RefCounted
## Aggregates modifiers from many sources (base, items, passives, buffs).
##
## Naming convention:
##   "more_*"  -> multiplicative: each mod multiplies by (1 + v/100). get() returns the product.
##   anything else -> additive: get() returns the sum.
## Examples: "life_flat", "inc_fire_damage", "more_damage", "conv_physical_to_fire".

var _sum: Dictionary = {}
var _prod: Dictionary = {}

func clear() -> void:
	_sum.clear()
	_prod.clear()

func add(stat: String, value: float) -> void:
	if stat.begins_with("more_"):
		_prod[stat] = float(_prod.get(stat, 1.0)) * (1.0 + value / 100.0)
	else:
		_sum[stat] = float(_sum.get(stat, 0.0)) + value

func add_mods(mods: Dictionary) -> void:
	for k in mods:
		add(k, float(mods[k]))

func add_mod_list(mods: Array) -> void:
	# Array of [stat, value] pairs (items use this so the same stat can appear twice).
	for m in mods:
		add(m[0], float(m[1]))

func get_stat(stat: String) -> float:
	if stat.begins_with("more_"):
		return float(_prod.get(stat, 1.0))
	return float(_sum.get(stat, 0.0))

## Convenience: "increased" multiplier from several additive inc stats.
func inc_mult(stats: Array) -> float:
	var total := 0.0
	for s in stats:
		total += get_stat(s)
	return maxf(0.0, 1.0 + total / 100.0)

## Convenience: product of several more stats.
func more_mult(stats: Array) -> float:
	var total := 1.0
	for s in stats:
		total *= get_stat(s)
	return total

func duplicate_block() -> StatBlock:
	var b := StatBlock.new()
	b._sum = _sum.duplicate()
	b._prod = _prod.duplicate()
	return b

func merged_with(other: StatBlock) -> StatBlock:
	var b := duplicate_block()
	for k in other._sum:
		b._sum[k] = float(b._sum.get(k, 0.0)) + float(other._sum[k])
	for k in other._prod:
		b._prod[k] = float(b._prod.get(k, 1.0)) * float(other._prod[k])
	return b
