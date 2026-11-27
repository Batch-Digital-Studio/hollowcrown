class_name Item
extends RefCounted
## An item instance. Serialisable via to_dict()/from_dict() (save files, co-op sync).

const RARITY_COLORS := {
	"normal": Color(0.85, 0.85, 0.85),
	"magic": Color(0.45, 0.6, 1.0),
	"rare": Color(1.0, 0.88, 0.35),
	"unique": Color(0.95, 0.5, 0.15),
}

var base_id := ""
var rarity := "normal"
var ilvl := 1
var name := ""
var affixes: Array = []   # [{id, tier, value}]   (tier is 1-based, 1 = best available label "T1")
var unique_id := ""
var unique_rolls: Array = []  # rolled values parallel to UNIQUES[...].mods

func base() -> Dictionary:
	return ItemsDB.BASES[base_id]

func slot_group() -> String:
	return base().slot  # weapon/helm/body/gloves/boots/ring/amulet

func color() -> Color:
	return RARITY_COLORS[rarity]

func req_level() -> int:
	if unique_id != "":
		return ItemsDB.UNIQUES[unique_id].req
	return base().get("req", 1)

## Raw (stat, value) pairs before local resolution.
func _raw_mods() -> Array:
	var out: Array = []
	var b := base()
	for k in b.get("implicit", {}):
		out.append([k, float(b.implicit[k])])
	if unique_id != "":
		var u: Dictionary = ItemsDB.UNIQUES[unique_id]
		for i in u.mods.size():
			out.append([u.mods[i][0], float(unique_rolls[i])])
	for a in affixes:
		var def: Dictionary = ItemsDB.AFFIXES[a.id]
		if def.has("range"):
			var t: String = def.range
			var lo: float = round(float(a.value) * def.min_ratio)
			out.append(["__added_%s_min" % t, maxf(1.0, lo)])
			out.append(["__added_%s_max" % t, float(a.value)])
		else:
			out.append([def.stat, float(a.value)])
	return out

## Final mods this item grants the character, with local mods resolved.
func to_mods() -> Array:
	var out: Array = []
	var raw := _raw_mods()
	var b := base()
	var is_weapon := slot_group() == "weapon"
	var local_phys_inc := 0.0
	var local_armour_inc := 0.0
	var flat_armour := float(b.get("armour", 0))
	var wpn := {}  # weapon local added damage
	for m in raw:
		var stat: String = m[0]
		if stat == "inc_local_physical":
			local_phys_inc += m[1]
		elif stat == "inc_local_armour":
			local_armour_inc += m[1]
		elif stat == "armour" and ItemsDB.ARMOUR_SLOTS.has(slot_group()):
			flat_armour += m[1]
		elif stat.begins_with("__added_"):
			var real := stat.substr(2)  # "added_fire_min"
			if is_weapon:
				var key := real.replace("added_", "weapon_")
				wpn[key] = float(wpn.get(key, 0.0)) + m[1]
			else:
				out.append([real, m[1]])
		else:
			out.append(m)
	if is_weapon:
		var p: Array = b.get("phys", [0, 0])
		var mult := 1.0 + local_phys_inc / 100.0
		var pmin := (float(p[0]) + float(wpn.get("weapon_physical_min", 0.0))) * mult
		var pmax := (float(p[1]) + float(wpn.get("weapon_physical_max", 0.0))) * mult
		out.append(["weapon_physical_min", pmin])
		out.append(["weapon_physical_max", pmax])
		for k in wpn:
			if not k.begins_with("weapon_physical"):
				out.append([k, wpn[k]])
	if flat_armour > 0.0:
		out.append(["armour", round(flat_armour * (1.0 + local_armour_inc / 100.0))])
	return out

## Tooltip lines: [[text, Color]]
func tooltip_lines() -> Array:
	var L: Array = []
	var dim := Color(0.6, 0.6, 0.65)
	var mod_c := Color(0.55, 0.7, 1.0)
	L.append([name, color()])
	if rarity == "rare" or rarity == "unique":
		L.append([base().name, color().darkened(0.15)])
	L.append([ItemsDB.SLOT_NAMES.get(slot_group(), slot_group().capitalize()) + "   ·   Item Level %d   ·   Requires Level %d" % [ilvl, req_level()], dim])
	var mods := to_mods()
	if slot_group() == "weapon":
		var d := {}
		for m in mods:
			d[m[0]] = m[1]
		var parts: Array = []
		for t in Damage.TYPES:
			if d.has("weapon_%s_max" % t):
				parts.append([t, int(round(d["weapon_%s_min" % t])), int(round(d["weapon_%s_max" % t]))])
		for p in parts:
			L.append(["%s Damage: %d–%d" % [p[0].capitalize(), p[1], p[2]], Damage.COLORS[p[0]]])
	for m in mods:
		if m[0] == "armour" and ItemsDB.ARMOUR_SLOTS.has(slot_group()):
			L.append(["Armour: %d" % int(m[1]), Color(0.9, 0.9, 0.9)])
	var b := base()
	if b.has("implicit"):
		for k in b.implicit:
			L.append([Item.describe_stat(k, b.implicit[k]), Color(0.8, 0.8, 0.85)])
		L.append(["────────", dim])
	if unique_id != "":
		var u: Dictionary = ItemsDB.UNIQUES[unique_id]
		for i in u.mods.size():
			L.append([u.mods[i][3] % int(unique_rolls[i]), mod_c])
		L.append([u.lore, Color(0.75, 0.55, 0.3)])
	for a in affixes:
		var def: Dictionary = ItemsDB.AFFIXES[a.id]
		var tier_txt := "  (T%d)" % a.tier
		if def.has("range"):
			var lo := maxi(1, int(round(float(a.value) * def.min_ratio)))
			L.append(["Adds %d to %d %s Damage%s" % [lo, int(a.value), def.range.capitalize(), tier_txt], mod_c])
		else:
			L.append([(def.text % int(a.value)) + tier_txt, mod_c])
	return L

static func describe_stat(stat: String, v: float) -> String:
	var n := int(v)
	match stat:
		"res_fire": return "+%d%% to Fire Resistance" % n
		"res_cold": return "+%d%% to Cold Resistance" % n
		"res_lightning": return "+%d%% to Lightning Resistance" % n
		"inc_spell_damage": return "%d%% increased Spell Damage" % n
		"inc_attack_speed": return "%d%% %s Attack Speed" % [absi(n), "increased" if n >= 0 else "reduced"]
		"inc_move_speed": return "%d%% increased Movement Speed" % n
		"mana_flat": return "+%d to maximum Mana" % n
		"inc_damage": return "%d%% increased Damage" % n
		"life_flat": return "+%d to maximum Life" % n
	return "%s: %d" % [stat, n]

func to_dict() -> Dictionary:
	return {"base": base_id, "rarity": rarity, "ilvl": ilvl, "name": name, "affixes": affixes,
		"unique": unique_id, "urolls": unique_rolls}

static func from_dict(d: Dictionary) -> Item:
	var it := Item.new()
	it.base_id = d.base
	it.rarity = d.rarity
	it.ilvl = int(d.ilvl)
	it.name = d.name
	it.affixes = d.affixes
	it.unique_id = d.get("unique", "")
	it.unique_rolls = d.get("urolls", [])
	return it
