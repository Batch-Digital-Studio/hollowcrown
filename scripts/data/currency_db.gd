class_name CurrencyDB
extends RefCounted
## Stackable currencies (not inventory items). Effects live in scripts/items/crafting.gd.

const CURRENCY := {
	"ember_shards": {"name": "Ember Shards", "color": Color(1.0, 0.78, 0.3), "desc": "Gold. Spend at the Ashen Peddler; pays for respecs after level 20."},
	"rift_splinter": {"name": "Rift Splinter", "color": Color(0.75, 0.5, 1.0), "desc": "100 Splinters fuse into a Rift Heart."},
	"rift_heart": {"name": "Rift Heart", "color": Color(0.85, 0.55, 1.0), "desc": "Use from the inventory to open the Rift Lord's arena."},
	"kindling_shard": {"name": "Kindling Shard", "color": Color(1.0, 0.55, 0.25), "desc": "Reroll the affixes of a magic item."},
	"coal_ascension": {"name": "Coal of Ascension", "color": Color(1.0, 0.85, 0.4), "desc": "Upgrade a normal item to rare."},
	"ash_salt": {"name": "Ash Salt", "color": Color(0.8, 0.8, 0.8), "desc": "Remove a random affix from an item."},
	"hollow_ember": {"name": "Hollow Ember", "color": Color(0.7, 0.45, 1.0), "desc": "Add a random affix to a rare item (max 6)."},
	"crown_fragment": {"name": "Crown Fragment", "color": Color(1.0, 0.9, 0.55), "desc": "Reroll the values of an item's affixes."},
	"ash_dust": {"name": "Ash Dust", "color": Color(0.6, 0.58, 0.55), "desc": "From shattered items. The Peddler trades it."},
}

## Which currencies can be used on items (in this order in the crafting bar).
const CRAFTING := ["kindling_shard", "coal_ascension", "ash_salt", "hollow_ember", "crown_fragment"]

## Essences (from Bound Embers): ess_<affix>_<tier 1..4>. Turn a normal or magic item
## into a rare with that affix guaranteed, at the essence tier (capped by item level).
const ESSENCES := {
	"life": {"name": "Vigour", "color": Color(0.95, 0.35, 0.35)},
	"added_fire": {"name": "Cinders", "color": Color(1.0, 0.5, 0.2)},
	"added_cold": {"name": "Rime", "color": Color(0.5, 0.8, 1.0)},
	"added_lightning": {"name": "Storms", "color": Color(1.0, 0.95, 0.45)},
	"inc_spell": {"name": "Sorcery", "color": Color(0.7, 0.55, 1.0)},
	"crit_chance": {"name": "the Edge", "color": Color(1.0, 1.0, 1.0)},
	"res_cold": {"name": "the Thaw", "color": Color(0.6, 0.9, 0.95)},
	"move_speed": {"name": "the Wind", "color": Color(0.6, 1.0, 0.7)},
}
const ESSENCE_TIERS := ["Whispering", "Smouldering", "Blazing", "Searing"]

static func essence_id(affix: String, tier: int) -> String:
	return "ess_%s_%d" % [affix, tier]

## [affix, tier] or [] for non-essences.
static func parse_essence(id: String) -> Array:
	if not id.begins_with("ess_"):
		return []
	var t := int(id.substr(id.length() - 1))
	return [id.substr(4, id.length() - 6), t]

static func info(id: String) -> Dictionary:
	if CURRENCY.has(id):
		return CURRENCY[id]
	var e := parse_essence(id)
	if e.is_empty() or not ESSENCES.has(e[0]):
		return {"name": id, "color": Color.GRAY, "desc": ""}
	var d: Dictionary = ESSENCES[e[0]]
	return {"name": "%s Essence of %s" % [ESSENCE_TIERS[e[1] - 1], d.name], "color": d.color,
		"desc": "Normal or magic item becomes rare with a guaranteed '%s' modifier." % ItemsDB.AFFIXES[e[0]].label}

static func is_crafting(id: String) -> bool:
	return CRAFTING.has(id) or id.begins_with("ess_")

## Purse order: fixed currencies first, then essences.
static func ordered(have: Dictionary) -> Array:
	var out: Array = []
	for k in CURRENCY:
		if int(have.get(k, 0)) > 0 or k == "ember_shards":
			out.append(k)
	var ess: Array = []
	for k in have:
		if String(k).begins_with("ess_") and int(have[k]) > 0:
			ess.append(k)
	ess.sort()
	return out + ess
