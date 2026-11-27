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
