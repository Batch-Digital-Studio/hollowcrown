class_name BrewingDB
extends RefCounted
## Herbalism, the first trade (test chapter). Herbs grow in one region each; you gather them (A / click,
## or Auto-gather) and brew at the Herbalist's Kettle in the camp. Herbs are stored in the purse like
## currency, so the purse shows where each comes from and what it brews.
##
## Near-term: Steeped Flask (stronger flask), tonics (one active, 3 minutes).
## Longer-term: the Wardstone Philter needs herbs from all three regions and is worth a trip back.

const HERBS := {
	"emberhood": {"name": "Emberhood", "color": Color(1.0, 0.55, 0.25), "model": "mushroom_ember", "region": 0, "regrow": 180.0,
		"desc": "A warm-capped mushroom that grows where embers fell. Found in the Whisperwood. Brews: Steeped Flask, Ember Tonic, Wardstone Philter."},
	"bogbloom": {"name": "Bogbloom", "color": Color(0.5, 0.8, 1.0), "model": "bogbloom", "region": 1, "regrow": 180.0,
		"desc": "Pale bells that glow at the water's edge. Found in Mirefen. Brews: Rime Tonic, Storm Tonic, Wardstone Philter."},
	"gravemoss": {"name": "Gravemoss", "color": Color(0.75, 0.9, 0.65), "model": "gravemoss", "region": 2, "regrow": 180.0,
		"desc": "Moss that feeds on old graves; its spores glow. Found in the Barrow Hills. Brews: Gravewine, Storm Tonic, Wardstone Philter."},
}
const HERBS_PER_REGION := 22
const GATHER_TIME := 0.6        # seconds the hero kneels to gather
const TONIC_TIME := 180.0

## kind: "upgrade" (permanent for this character, ranks), "tonic" (timed, one at a time), "philter" (permanent, once)
const RECIPES := [
	{"id": "steeped_flask", "name": "Steeped Flask", "kind": "upgrade", "ranks": 3,
		"cost": [{"emberhood": 3}, {"emberhood": 5}, {"emberhood": 8}],
		"mods": {"flask_heal_inc": 25}, "desc": "Your flask heals 25% more (per rank)."},
	{"id": "ember_tonic", "name": "Ember Tonic", "kind": "tonic", "cost": {"emberhood": 3},
		"mods": {"inc_fire_damage": 30, "ignite_chance": 10}, "desc": "3 min: 30% more fire damage, 10% chance to ignite."},
	{"id": "rime_tonic", "name": "Rime Tonic", "kind": "tonic", "cost": {"bogbloom": 3},
		"mods": {"inc_cold_damage": 30, "chill_chance": 20}, "desc": "3 min: 30% more cold damage, 20% chance to chill."},
	{"id": "storm_tonic", "name": "Storm Tonic", "kind": "tonic", "cost": {"bogbloom": 2, "gravemoss": 2},
		"mods": {"inc_lightning_damage": 30, "shock_chance": 15}, "desc": "3 min: 30% more lightning damage, 15% chance to shock."},
	{"id": "gravewine", "name": "Gravewine", "kind": "tonic", "cost": {"gravemoss": 3},
		"mods": {"inc_chaos_damage": 25, "inc_light_damage": 25, "res_chaos": 20}, "desc": "3 min: 25% more chaos and light damage, +20% chaos resistance."},
	{"id": "wardstone_philter", "name": "Wardstone Philter", "kind": "philter", "ranks": 1,
		"cost": [{"emberhood": 6, "bogbloom": 6, "gravemoss": 6}],
		"mods": {"flask_max_add": 1, "res_fire": 10, "res_cold": 10, "res_lightning": 10},
		"desc": "Permanent: +1 flask charge and +10% fire, cold and lightning resistance."},
]

static func recipe(id: String) -> Dictionary:
	for r in RECIPES:
		if r.id == id:
			return r
	return {}

## The cost of the next brew (ranks get dearer).
static func cost_of(r: Dictionary, rank: int) -> Dictionary:
	if r.kind == "tonic":
		return r.cost
	var costs: Array = r.cost
	return costs[mini(rank, costs.size() - 1)]

static func can_afford(p: Player, cost: Dictionary) -> bool:
	for h in cost:
		if int(p.currency.get(h, 0)) < int(cost[h]):
			return false
	return true

static func cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for h in cost:
		parts.append("%d %s" % [cost[h], HERBS[h].name])
	return ", ".join(parts)
