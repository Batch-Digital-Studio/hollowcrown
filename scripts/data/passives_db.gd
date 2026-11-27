class_name PassivesDB
extends RefCounted
## The Ember Constellation (passive tree). Built from compact branch specs.
## Node spec: [name, type ("small"/"notable"/"keystone"), {stat: value}, desc (optional)]

## Constellation v2: eight regions around a ring. Each region has a spine (small, small,
## notable, small, small, notable), two forks (small, small, notable), a Mastery (allocate,
## then pick one of three effects with A / click) and a keystone at the end of the spine.
## An inner ring links the regions near the centre; an outer ring links their tips.
## Each class enters at its own star on the outer ring; dual-classing adds the second star.
## Node spec: [name, type, {stat: value}, desc (optional)]

const STEP := 92.0

const REGIONS := [
	{"id": "steel", "name": "Steel", "angle": 0.0, "color": Color(0.9, 0.85, 0.75),
		"small": [{"inc_physical_damage": 10}, {"armour": 40}, {"inc_attack_speed": 5}, {"inc_melee_damage": 12}],
		"notables": [["Ashen Arm", "notable", {"inc_physical_damage": 20, "inc_attack_speed": 8}],
			["Iron Skin", "notable", {"armour": 120, "life_flat": 20}],
			["Crushing Blows", "notable", {"inc_melee_damage": 30, "crit_multi": 15}],
			["Shield Discipline", "notable", {"block_chance": 8, "armour": 60}]],
		"mastery": [["Block", {"block_chance": 6}], ["Area", {"inc_area": 15}], ["Armour from shields", {"armour": 100, "inc_armour": 15}]],
		"keystone": ["Blood Rite", "keystone", {"life_leech": 4, "more_life": -15, "more_attack_damage": 25},
			"Attacks leech life and hit far harder, at the cost of maximum Life."],
		"keystone2": ["Unbroken Vow", "keystone", {"no_crit": 1, "crit_immune": 1, "armour": 150},
			"You can't be critically struck, and you can't deal critical strikes."]},
	{"id": "pyre", "name": "Pyre", "angle": 45.0, "color": Color(1.0, 0.5, 0.2),
		"small": [{"inc_fire_damage": 10}, {"inc_ignite_damage": 15}, {"ignite_chance": 4}, {"inc_fire_damage": 10}],
		"notables": [["Pyre Heart", "notable", {"inc_fire_damage": 20, "ignite_chance": 10}],
			["Searing Embers", "notable", {"inc_ignite_damage": 35, "inc_ignite_duration": 20}],
			["Quickened Rites", "notable", {"inc_cast_speed": 12, "inc_spell_damage": 10}],
			["Ember Splinters", "notable", {"proj_count_add": 1, "more_projectile_damage": -15}]],
		"mastery": [["Ignite duration", {"inc_ignite_duration": 40}], ["Burning ground", {"burn_ground_death": 1}], ["Fire penetration", {"fire_pen": 15}]],
		"keystone": ["Kiln-Born", "keystone", {"conv_cold_to_fire": 100, "inc_fire_damage": 25, "res_cold": -20},
			"All your Cold damage becomes Fire. Rimeburst burns."],
		"keystone2": ["Wildfire", "keystone", {"wildfire": 1, "inc_ignite_damage": 20},
			"Ignites spread to every enemy nearby when the burning target dies."]},
	{"id": "rime", "name": "Rime", "angle": 90.0, "color": Color(0.55, 0.85, 1.0),
		"small": [{"inc_cold_damage": 10}, {"chill_chance": 5}, {"inc_cold_damage": 10}, {"res_cold": 8}],
		"notables": [["Deep Winter", "notable", {"inc_cold_damage": 20, "chill_chance": 15}],
			["Wide Frost", "notable", {"inc_area": 14, "inc_cold_damage": 10}],
			["Hoarfrost", "notable", {"inc_chill_effect": 25, "inc_cold_damage": 10}],
			["Glacier Skin", "notable", {"armour": 80, "res_cold": 15}]],
		"mastery": [["Freeze", {"freeze_below": 15}], ["Chill effect", {"inc_chill_effect": 30}], ["Cold shields", {"ember_ward_flat": 40, "res_cold": 15}]],
		"keystone": ["Echo of the Crown", "keystone", {"echo_crown": 1, "more_cast_speed": -25},
			"Spells cast twice. 25% less cast speed."]},
	{"id": "storm", "name": "Storm", "angle": 135.0, "color": Color(1.0, 0.95, 0.5),
		"small": [{"inc_lightning_damage": 10}, {"shock_chance": 5}, {"inc_crit_chance": 12}, {"inc_lightning_damage": 10}],
		"notables": [["Forked Fate", "notable", {"chain_add": 1, "inc_lightning_damage": 10}],
			["Conductive", "notable", {"shock_chance": 15, "inc_crit_chance": 25}],
			["Sharpened Will", "notable", {"inc_crit_chance": 30, "crit_multi": 15}],
			["Static Skin", "notable", {"res_lightning": 15, "inc_cast_speed": 6}]],
		"mastery": [["Chains", {"chain_add": 1}], ["Shock effect", {"inc_shock_effect": 50}], ["Crit multiplier", {"crit_multi": 30}]],
		"keystone": ["Stormcaller's Oath", "keystone", {"chain_add": 2, "shock_chance": 40, "more_damage": -15},
			"Chains twice more and shocks often, but all damage is lower."]},
	{"id": "wind", "name": "Wind", "angle": 180.0, "color": Color(0.7, 1.0, 0.75),
		"small": [{"inc_projectile_damage": 10}, {"evade_chance": 3}, {"inc_move_speed": 3}, {"inc_projectile_speed": 12}],
		"notables": [["Seeker's Mark", "notable", {"inc_projectile_damage": 25, "pierce_add": 1}],
			["Fleetfoot", "notable", {"inc_move_speed": 8, "life_regen": 3}],
			["Windborne", "notable", {"evade_chance": 8, "inc_move_speed": 4}],
			["Hunter's Patience", "notable", {"inc_projectile_damage": 15, "crit_multi": 15}]],
		"mastery": [["Projectile count", {"proj_count_add": 1, "more_projectile_damage": -10}], ["Evasion", {"evade_chance": 12}], ["Movement", {"inc_move_speed": 10}]],
		"keystone": ["Fleetfoot Pact", "keystone", {"fleetfoot": 1, "more_life": -20},
			"Each 1% increased movement speed gives 1% more damage. 20% less life."]},
	{"id": "venom", "name": "Venom", "angle": 225.0, "color": Color(0.55, 0.95, 0.3),
		"small": [{"inc_poison_damage": 12}, {"poison_chance": 4}, {"res_chaos": 7}, {"inc_curse_effect": 6}],
		"notables": [["Rot Blossom", "notable", {"inc_poison_damage": 25, "poison_chance": 10}],
			["Lingering Hex", "notable", {"inc_curse_effect": 15, "inc_duration": 10}],
			["Bog Blood", "notable", {"res_chaos": 20, "life_regen": 3}],
			["Corrosion", "notable", {"chaos_pen": 10, "inc_poison_damage": 15}]],
		"mastery": [["Poison stacks", {"inc_poison_damage": 25, "poison_chance": 15}], ["Curse effect", {"inc_curse_effect": 25}], ["Chaos resistance", {"res_chaos": 25}]],
		"keystone": ["Tide of Venom", "keystone", {"virulence": 1, "hit_less": 40, "poison_chance": 20},
			"Poison stacks without limit. Your hits deal 40% less (poison is unaffected)."]},
	{"id": "grave", "name": "Grave", "angle": 270.0, "color": Color(0.75, 0.6, 1.0),
		"small": [{"inc_minion_damage": 12}, {"inc_minion_life": 12}, {"inc_totem_life": 15}, {"minion_attack_speed": 5}],
		"notables": [["Gravecall", "notable", {"minion_max_add": 1, "inc_minion_damage": 10}],
			["Grim Masonry", "notable", {"inc_totem_damage": 25, "inc_totem_life": 25}],
			["Restless Dead", "notable", {"minion_attack_speed": 12, "minion_move": 15}],
			["Pillar Lore", "notable", {"totem_cast_speed": 12, "inc_totem_duration": 20}]],
		"mastery": [["Minion count", {"minion_max_add": 1}], ["Totem duration", {"inc_totem_duration": 40}], ["Minion life", {"inc_minion_life": 30}]],
		"keystone": ["Pack Leader", "keystone", {"minion_max_add": 2, "totem_max_add": 2, "more_damage": -30},
			"+2 maximum minions and totems. Your own hits deal 30% less."],
		"keystone2": ["Shared Flame", "keystone", {"shared_flame": 50, "inc_area": 10},
			"Your auras, banners and buffs are 50% stronger (allies get them too once co-op lands)."]},
	{"id": "heart", "name": "Heart", "angle": 315.0, "color": Color(1.0, 0.55, 0.6),
		"small": [{"life_flat": 12}, {"res_fire": 6, "res_cold": 6, "res_lightning": 6}, {"mana_flat": 15}, {"inc_life": 4}],
		"notables": [["Ember Ward", "notable", {"res_fire": 12, "res_cold": 12, "res_lightning": 12}],
			["Vigour", "notable", {"inc_life": 10, "life_flat": 15}],
			["Inner Fire", "notable", {"inc_damage": 16}],
			["Clear Mind", "notable", {"mana_flat": 30, "inc_mana_regen": 30}]],
		"mastery": [["Flask charges", {"flask_max_add": 1}], ["Life regeneration", {"life_regen_pct": 1}], ["All resistances", {"res_fire": 10, "res_cold": 10, "res_lightning": 10}]],
		"keystone": ["Hollow Heart", "keystone", {"more_spell_damage": 30, "res_fire": -20, "res_cold": -20, "res_lightning": -20},
			"Spells deal far more damage. Your resistances suffer."],
		"keystone2": ["Ashen Avatar", "keystone", {"no_regen": 1, "ward_from_life": 40},
			"You can't regenerate life. 40% of your life becomes a fast-recharging Ember Ward."]},
]

## Class entry stars on the outer ring, between the regions that suit them.
const STARS := {
	"oath": {"angle": 337.5, "name": "Oathsworn Star"},
	"magus": {"angle": 112.5, "name": "Magus Star"},
	"ranger": {"angle": 202.5, "name": "Ranger Star"},
	"shaman": {"angle": 247.5, "name": "Shaman Star"},
}

const RING_SMALL := {"inc_damage": 5, "life_flat": 6}

static var _nodes := {}

static func roots_for(classes: Array) -> Array:
	var out: Array = []
	for c in classes:
		if STARS.has(c):
			out.append("star_" + c)
	if out.is_empty():
		out.append("start")
	return out

static func is_root(id: String) -> bool:
	return id == "start" or id.begins_with("star_")

## Returns {id: {name, type, stats, desc, pos, links:Array, color, options?}}
static func nodes() -> Dictionary:
	if not _nodes.is_empty():
		return _nodes
	_nodes["start"] = {"name": "Kindled Heart", "type": "start", "stats": {}, "desc": "Where your ember first took (classless characters start here).",
		"pos": Vector2.ZERO, "links": [], "color": Color(1.0, 0.8, 0.4)}
	var n_reg := REGIONS.size()
	for ri in n_reg:
		var r: Dictionary = REGIONS[ri]
		var a := deg_to_rad(float(r.angle))
		var dir := Vector2.RIGHT.rotated(a)
		var side := dir.orthogonal()
		var col: Color = r.color
		var pre: String = r.id
		# inner ring node
		var inner := pre + "_in"
		_add(inner, ["Ember Path", "small", RING_SMALL], dir * STEP * 1.6, col)
		_link("start", inner)
		# spine
		var spine := [
			[r.name, "small", r.small[0]], [r.name, "small", r.small[1]], r.notables[0],
			[r.name, "small", r.small[2]], [r.name, "small", r.small[3]], r.notables[1]]
		var prev := inner
		for i in spine.size():
			var id := "%s_s%d" % [pre, i]
			_add(id, spine[i], dir * STEP * (2.7 + i * 1.05), col)
			_link(prev, id)
			prev = id
		_add(pre + "_key", r.keystone, dir * STEP * 9.4, col)
		_link(prev, pre + "_key")
		# forks off s1 (left) and s3 (right)
		for fk in 2:
			var base := "%s_s%d" % [pre, 1 if fk == 0 else 3]
			var sgn := 1.0 if fk == 0 else -1.0
			var fprev := base
			var bpos: Vector2 = _nodes[base].pos
			var fspec := [[r.name, "small", r.small[(fk * 2) % 4]], [r.name, "small", r.small[(fk * 2 + 1) % 4]], r.notables[2 + fk]]
			for j in 3:
				var fid := "%s_f%d_%d" % [pre, fk, j]
				var fpos := bpos + side * sgn * STEP * (0.95 + j * 0.85) + dir * STEP * 0.35 * j
				_add(fid, fspec[j], fpos, col)
				_link(fprev, fid)
				fprev = fid
			if fk == 1 and r.has("keystone2"):
				var kid := pre + "_key2"
				_add(kid, r.keystone2, _nodes[fprev].pos + side * sgn * STEP * 0.9 + dir * STEP * 0.4, col)
				_link(fprev, kid)
		# mastery beside s4
		var mid := pre + "_mastery"
		var mpos: Vector2 = _nodes[pre + "_s4"].pos + side * STEP * 0.9
		_add(mid, [r.name + " Mastery", "mastery", {}, "Allocate, then choose one effect (A / click again to switch, free)."], mpos, col)
		_nodes[mid]["options"] = r.mastery
		_link(pre + "_s4", mid)
	# inner ring links
	for ri in n_reg:
		var a_id: String = REGIONS[ri].id + "_in"
		var b_id: String = REGIONS[(ri + 1) % n_reg].id + "_in"
		_link(a_id, b_id)
	# outer ring: two travel nodes between each pair of region tips (s5), or a class star in the middle
	for ri in n_reg:
		var r1: Dictionary = REGIONS[ri]
		var r2: Dictionary = REGIONS[(ri + 1) % n_reg]
		var a1 := float(r1.angle)
		var a2 := a1 + 45.0
		var mid_a := a1 + 22.5
		var star_cls := ""
		for c in STARS:
			if absf(fposmod(float(STARS[c].angle) - mid_a, 360.0)) < 0.1:
				star_cls = c
		var ra := STEP * 8.1
		var o1 := "%s_o1" % r1.id
		var o2 := "%s_o2" % r1.id
		_add(o1, ["Starlit Path", "small", RING_SMALL], Vector2.RIGHT.rotated(deg_to_rad(a1 + 11.0)) * ra, r1.color.lerp(r2.color, 0.3))
		_add(o2, ["Starlit Path", "small", RING_SMALL], Vector2.RIGHT.rotated(deg_to_rad(a2 - 11.0)) * ra, r1.color.lerp(r2.color, 0.7))
		_link(r1.id + "_s5", o1)
		_link(o2, r2.id + "_s5")
		if star_cls != "":
			var sid := "star_" + star_cls
			var cdef := ClassesDB.class_def(star_cls)
			_add(sid, [STARS[star_cls].name, "start", {}, "Where the %s enters the Constellation." % cdef.name], Vector2.RIGHT.rotated(deg_to_rad(mid_a)) * ra * 1.04, cdef.color)
			_link(o1, sid)
			_link(sid, o2)
		else:
			_link(o1, o2)
	return _nodes

static func _add(id: String, spec: Array, pos: Vector2, color: Color) -> void:
	_nodes[id] = {"name": spec[0], "type": spec[1], "stats": spec[2], "desc": spec[3] if spec.size() > 3 else "",
		"pos": pos, "links": [], "color": color}

static func _link(a: String, b: String) -> void:
	if not _nodes[a].links.has(b):
		_nodes[a].links.append(b)
	if not _nodes[b].links.has(a):
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
		"poison_chance": return "%d%% chance to Poison" % n
		"minion_max_add": return "+%d maximum husk%s" % [n, "s" if n > 1 else ""]
		"totem_max_add": return "+%d maximum totem%s" % [n, "s" if n > 1 else ""]
		"minion_attack_speed": return "Minions attack %d%% faster" % n
		"minion_move": return "Minions move %d%% faster" % n
		"minion_fire": return "Minions convert %d%% of damage to fire" % n
		"totem_cast_speed": return "Totems cast %d%% faster" % n
		"hex_spread": return "Hexes spread when the cursed enemy dies"
		"husk_brute": return "Husks are twice as strong, 2 fewer maximum"
		"husk_explode": return "Husks explode in fire when they die"
		"block_chance": return "+%d%% chance to Block" % n
		"evade_chance": return "+%d%% chance to Evade" % n
		"fire_pen": return "Fire damage ignores %d%% of resistance" % n
		"chaos_pen": return "Chaos damage ignores %d%% of resistance" % n
		"freeze_below": return "Chilled enemies below %d%% life freeze" % n
		"burn_ground_death": return "Burning enemies leave burning ground on death"
		"flask_max_add": return "+%d maximum flask charge" % n
		"life_regen_pct": return "Regenerate %d%% of Life per second" % n
		"ember_ward_flat": return "+%d to Ember Ward" % n
		"echo_crown": return "Spells cast twice"
		"no_regen": return "You cannot regenerate Life"
		"ward_from_life": return "%d%% of Life becomes a fast-recharging Ember Ward" % n
		"wildfire": return "Ignites spread to all nearby enemies on death"
		"no_crit": return "You cannot deal critical strikes"
		"crit_immune": return "You cannot be critically struck"
		"virulence": return "Poison stacks without limit"
		"hit_less": return "Your hits deal %d%% less damage (poison unaffected)" % n
		"fleetfoot": return "1% more damage per 1% increased movement speed"
		"shared_flame": return "Your auras, banners and buffs are %d%% stronger" % n
	return "%s %s%d" % [stat, sign, n]
