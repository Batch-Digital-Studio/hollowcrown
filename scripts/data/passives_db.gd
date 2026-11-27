class_name PassivesDB
extends RefCounted
## The Ember Constellation (passive tree). Built from compact branch specs.
## Node spec: [name, type ("small"/"notable"/"keystone"), {stat: value}, desc (optional)]

const BRANCH_LEN := 96.0

const BRANCHES := [
	{"name": "Pyre", "angle": -30.0, "fork_rot": 90.0, "color": Color(1.0, 0.5, 0.2),
		"chain": [
			["Kindling", "small", {"inc_fire_damage": 10}],
			["Kindling", "small", {"inc_fire_damage": 10}],
			["Pyre Heart", "notable", {"inc_fire_damage": 20, "ignite_chance": 10}],
			["Searing Embers", "small", {"inc_ignite_damage": 20}],
			["Ember Splinters", "notable", {"proj_count_add": 1, "more_projectile_damage": -15}],
			["Kiln-Born", "keystone", {"conv_cold_to_fire": 100, "inc_fire_damage": 25, "res_cold": -20},
				"All your Cold damage becomes Fire. Rimeburst burns."],
		],
		"forks": {1: [["Quick Hands", "small", {"inc_cast_speed": 6}], ["Quickened Rites", "notable", {"inc_cast_speed": 12, "inc_spell_damage": 10}]],
			3: [["Swift Flight", "small", {"inc_projectile_speed": 15}], ["Seeker's Mark", "notable", {"inc_projectile_damage": 25, "pierce_add": 1}]]}},
	{"name": "Storm", "angle": 210.0, "fork_rot": -90.0, "color": Color(0.6, 0.85, 1.0),
		"chain": [
			["Static", "small", {"inc_lightning_damage": 10}],
			["Static", "small", {"inc_lightning_damage": 10}],
			["Forked Fate", "notable", {"chain_add": 1, "inc_lightning_damage": 10}],
			["Rime", "small", {"inc_cold_damage": 12}],
			["Deep Winter", "notable", {"inc_cold_damage": 20, "chill_chance": 20}],
			["Stormcaller's Oath", "keystone", {"chain_add": 2, "shock_chance": 40, "more_damage": -15},
				"Stormthread chains twice more and shocks often, but all damage is lower."],
		],
		"forks": {1: [["Conduit", "small", {"shock_chance": 8}], ["Conductive", "notable", {"shock_chance": 15, "inc_crit_chance": 25}]],
			3: [["Spread", "small", {"inc_area": 8}], ["Wide Frost", "notable", {"inc_area": 16, "inc_cold_damage": 10}]]}},
	{"name": "Steel", "angle": 90.0, "fork_rot": -90.0, "color": Color(0.9, 0.85, 0.75),
		"chain": [
			["Grit", "small", {"inc_physical_damage": 12}],
			["Grit", "small", {"inc_physical_damage": 12}],
			["Ashen Arm", "notable", {"inc_physical_damage": 20, "inc_attack_speed": 8}],
			["Bulwark", "small", {"armour": 40}],
			["Crushing Blows", "notable", {"inc_melee_damage": 30, "crit_multi": 15}],
			["Blood Rite", "keystone", {"life_leech": 4, "more_life": -15, "more_attack_damage": 25},
				"Attacks leech life and hit far harder, at the cost of maximum Life."],
		],
		"forks": {1: [["Tempo", "small", {"inc_attack_speed": 6}], ["Whirling Edge", "notable", {"inc_area": 15, "inc_attack_speed": 6}]],
			3: [["Hardy", "small", {"life_flat": 12}], ["Iron Skin", "notable", {"armour": 90, "life_flat": 20}]]}},
	{"name": "Spirit", "angle": 270.0, "fork_rot": -90.0, "color": Color(0.85, 0.6, 1.0),
		"chain": [
			["Vigour", "small", {"life_flat": 12}],
			["Vigour", "small", {"life_flat": 12}],
			["Ember Ward", "notable", {"res_fire": 12, "res_cold": 12, "res_lightning": 12}],
			["Focus", "small", {"mana_flat": 15, "inc_mana_regen": 15}],
			["Fleetfoot", "notable", {"inc_move_speed": 10, "life_regen": 3}],
			["Hollow Heart", "keystone", {"more_spell_damage": 30, "res_fire": -20, "res_cold": -20, "res_lightning": -20},
				"Spells deal far more damage. Your resistances suffer."],
		],
		"forks": {1: [["Keen", "small", {"inc_crit_chance": 15}], ["Sharpened Will", "notable", {"inc_crit_chance": 30, "crit_multi": 15}]],
			3: [["Ardour", "small", {"inc_damage": 8}], ["Inner Fire", "notable", {"inc_damage": 18}]]}},
]

static var _nodes := {}

## Returns {id: {name, type, stats, desc, pos, links:Array, color}}
static func nodes() -> Dictionary:
	if not _nodes.is_empty():
		return _nodes
	_nodes["start"] = {"name": "Kindled Heart", "type": "start", "stats": {}, "desc": "Where your ember first took.",
		"pos": Vector2.ZERO, "links": [], "color": Color(1.0, 0.8, 0.4)}
	for bi in BRANCHES.size():
		var b: Dictionary = BRANCHES[bi]
		var dir: Vector2 = Vector2.RIGHT.rotated(deg_to_rad(float(b.angle)))
		var side: Vector2 = dir.rotated(deg_to_rad(float(b.fork_rot)))
		var prev := "start"
		for i in b.chain.size():
			var id := "b%d_%d" % [bi, i]
			var spec: Array = b.chain[i]
			var pos: Vector2 = dir * BRANCH_LEN * (i + 1.3)
			_add(id, spec, pos, b.color)
			_link(prev, id)
			prev = id
			if b.forks.has(i):
				var fprev := id
				var forks: Array = b.forks[i]
				for j in forks.size():
					var fid := "%s_f%d" % [id, j]
					var fpos: Vector2 = pos + side * BRANCH_LEN * 0.95 * (j + 1) + dir * BRANCH_LEN * 0.25 * j
					_add(fid, forks[j], fpos, b.color)
					_link(fprev, fid)
					fprev = fid
	return _nodes

static func _add(id: String, spec: Array, pos: Vector2, color: Color) -> void:
	_nodes[id] = {"name": spec[0], "type": spec[1], "stats": spec[2], "desc": spec[3] if spec.size() > 3 else "",
		"pos": pos, "links": [], "color": color}

static func _link(a: String, b: String) -> void:
	_nodes[a].links.append(b)
	_nodes[b].links.append(a)

static func describe(stat: String, v: float) -> String:
	var n := int(v)
	var sign := "+" if n >= 0 else ""
	if stat.begins_with("more_"):
		var what := stat.substr(5).replace("_", " ").capitalize()
		return "%d%% %s %s" % [absi(n), "more" if n >= 0 else "less", what]
	if stat.begins_with("conv_"):
		var parts := stat.substr(5).split("_to_")
		return "%d%% of %s Damage Converted to %s" % [n, parts[0].capitalize(), parts[1].capitalize()]
	if stat.begins_with("inc_"):
		return "%d%% increased %s" % [n, stat.substr(4).replace("_", " ").capitalize()]
	if stat.begins_with("res_"):
		return "%s%d%% to %s Resistance" % [sign, n, stat.substr(4).capitalize()]
	match stat:
		"life_flat": return "%s%d to maximum Life" % [sign, n]
		"mana_flat": return "%s%d to maximum Mana" % [sign, n]
		"armour": return "+%d to Armour" % n
		"crit_multi": return "+%d%% to Critical Strike Multiplier" % n
		"proj_count_add": return "+%d Projectile" % n
		"chain_add": return "Chains +%d times" % n
		"pierce_add": return "Projectiles Pierce %d additional enemy" % n
		"life_leech": return "%d%% of Damage Leeched as Life" % n
		"life_regen": return "Regenerate %d Life per second" % n
		"ignite_chance": return "%d%% chance to Ignite" % n
		"chill_chance": return "%d%% chance to Chill" % n
		"shock_chance": return "%d%% chance to Shock" % n
	return "%s %s%d" % [stat, sign, n]
