class_name WorldDB
extends RefCounted
## The world: regions (three depths each), their biomes, and the home town.
## Depth stays the single progression number; a region is a stretch of depths.
## Past the last region the biomes cycle as "The Hollow Crown" at ever higher levels.

const DEPTHS_PER_REGION := 3

## layout: path (winding corridors + rooms) | open (clearings) | caves (cellular caverns) | rooms (castle halls)
## style:  tiles (the 0x72 dungeon sheet) | proc (procedural pixel tiles from BiomeArt)
const BIOMES := {
	"crypt": {"name": "Crypt", "layout": "path", "style": "tiles", "tint": Color(1.0, 0.9, 0.82), "ambient": Color(0.42, 0.39, 0.46),
		"accent": Color(1.0, 0.5, 0.2), "bg": Color(0.015, 0.012, 0.02), "decor": ["skull", "skull", "floor_spikes", "crate"], "lights": 24},
	"forest": {"name": "Forest", "layout": "open", "style": "proc", "ambient": Color(0.58, 0.62, 0.52),
		"accent": Color(1.0, 0.85, 0.45), "bg": Color(0.05, 0.09, 0.04), "decor": ["flowers", "flowers", "mushroom", "stump", "rock", "grass"], "lights": 14,
		"floor": [Color(0.22, 0.32, 0.14), Color(0.26, 0.37, 0.16), Color(0.18, 0.27, 0.11), Color(0.33, 0.28, 0.17)],
		"wall": [Color(0.09, 0.2, 0.08), Color(0.13, 0.27, 0.1), Color(0.3, 0.2, 0.11)], "wall_kind": "tree"},
	"swamp": {"name": "Swamp", "layout": "open", "style": "proc", "ambient": Color(0.46, 0.52, 0.44),
		"accent": Color(0.6, 1.0, 0.5), "bg": Color(0.03, 0.06, 0.05), "decor": ["reeds", "reeds", "lily", "mushroom", "bones"], "lights": 16,
		"floor": [Color(0.24, 0.22, 0.14), Color(0.2, 0.24, 0.13), Color(0.28, 0.25, 0.16), Color(0.17, 0.2, 0.12)],
		"wall": [Color(0.07, 0.17, 0.16), Color(0.1, 0.24, 0.22), Color(0.2, 0.32, 0.18)], "wall_kind": "water"},
	"cave": {"name": "Cavern", "layout": "caves", "style": "proc", "ambient": Color(0.44, 0.43, 0.52),
		"accent": Color(0.5, 0.8, 1.0), "bg": Color(0.02, 0.02, 0.03), "decor": ["crystal", "rock", "rock", "stalagmite", "bones"], "lights": 18,
		"floor": [Color(0.2, 0.19, 0.2), Color(0.23, 0.21, 0.21), Color(0.17, 0.16, 0.18), Color(0.25, 0.23, 0.22)],
		"wall": [Color(0.33, 0.3, 0.33), Color(0.45, 0.42, 0.44), Color(0.6, 0.57, 0.58)], "wall_kind": "rock"},
	"castle": {"name": "Castle", "layout": "rooms", "style": "tiles", "tint": Color(0.85, 0.88, 1.0), "ambient": Color(0.44, 0.42, 0.5),
		"accent": Color(1.0, 0.7, 0.35), "bg": Color(0.02, 0.02, 0.03), "decor": ["carpet", "carpet", "column", "crate", "skull"], "lights": 30},
	"tundra": {"name": "Frost", "layout": "caves", "style": "proc", "ambient": Color(0.4, 0.45, 0.56),
		"accent": Color(0.6, 0.9, 1.0), "bg": Color(0.05, 0.07, 0.1), "decor": ["snow", "snow", "ice_shard", "rock", "bones"], "lights": 10,
		"floor": [Color(0.5, 0.56, 0.63), Color(0.46, 0.52, 0.6), Color(0.55, 0.6, 0.67), Color(0.42, 0.49, 0.57)],
		"wall": [Color(0.3, 0.45, 0.6), Color(0.45, 0.62, 0.78), Color(0.7, 0.85, 0.95)], "wall_kind": "ice"},
	"volcanic": {"name": "Ashlands", "layout": "caves", "style": "proc", "ambient": Color(0.5, 0.36, 0.32),
		"accent": Color(1.0, 0.45, 0.15), "bg": Color(0.05, 0.015, 0.01), "decor": ["vent", "rock", "rock", "bones", "ember"], "lights": 20,
		"floor": [Color(0.16, 0.13, 0.12), Color(0.2, 0.15, 0.13), Color(0.13, 0.11, 0.1), Color(0.22, 0.17, 0.14)],
		"wall": [Color(0.08, 0.06, 0.06), Color(0.16, 0.12, 0.11), Color(0.9, 0.35, 0.08)], "wall_kind": "basalt"},
	"town": {"name": "Town", "layout": "town", "style": "tiles", "tint": Color(1.0, 0.95, 0.88), "ambient": Color(0.75, 0.7, 0.68),
		"accent": Color(1.0, 0.75, 0.4), "bg": Color(0.03, 0.03, 0.04), "decor": [], "lights": 0},
}

const REGIONS := [
	{"id": "ashfall", "name": "Ashfall Crypt", "biome": "crypt", "pos": Vector2(0.14, 0.62), "blurb": "Where the Regent sealed the dead."},
	{"id": "whisperwood", "name": "Whisperwood", "biome": "forest", "pos": Vector2(0.28, 0.4), "blurb": "Old trees that remember the crown."},
	{"id": "mirefen", "name": "Mirefen", "biome": "swamp", "pos": Vector2(0.42, 0.66), "blurb": "The Rot Mother's bog."},
	{"id": "hollowdeep", "name": "Hollow Deep", "biome": "cave", "pos": Vector2(0.55, 0.38), "blurb": "Caverns lit by crystal."},
	{"id": "duskhold", "name": "Duskhold", "biome": "castle", "pos": Vector2(0.67, 0.58), "blurb": "The Hollow King's fallen keep."},
	{"id": "frostmere", "name": "Frostmere", "biome": "tundra", "pos": Vector2(0.78, 0.3), "blurb": "A frozen lake of old battles."},
	{"id": "cinder", "name": "Cinder Wastes", "biome": "volcanic", "pos": Vector2(0.88, 0.6), "blurb": "Where the ember first fell."},
]
const TOWN_POS := Vector2(0.08, 0.3)
const TOWN_NAME := "Emberhold"

static func region_index(depth: int) -> int:
	return (maxi(1, depth) - 1) / DEPTHS_PER_REGION

static func region_for_depth(depth: int) -> Dictionary:
	return REGIONS[region_index(depth) % REGIONS.size()]

static func biome_for_depth(depth: int) -> Dictionary:
	return BIOMES[region_for_depth(depth).biome]

static func region_start(i: int) -> int:
	return i * DEPTHS_PER_REGION + 1

## e.g. "Whisperwood II" or "The Hollow Crown · Frostmere"
static func zone_name(depth: int) -> String:
	var ri := region_index(depth)
	var r: Dictionary = REGIONS[ri % REGIONS.size()]
	var part := (maxi(1, depth) - 1) % DEPTHS_PER_REGION
	var numeral: String = ["I", "II", "III", "IV"][part]
	if ri >= REGIONS.size():
		return "The Hollow Crown · %s %s" % [r.name, numeral]
	return "%s %s" % [r.name, numeral]
